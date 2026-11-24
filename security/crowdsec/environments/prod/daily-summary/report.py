import json
import os
import sqlite3
import sys
from collections import Counter, defaultdict
from contextlib import closing
from datetime import UTC, datetime, timedelta
from http.client import HTTPException
from urllib.error import HTTPError
from urllib.request import Request, urlopen


DATABASE = "file:/data/crowdsec.db?mode=ro"
ALERTMANAGER = "http://prometheus-stack-kube-prom-alertmanager.monitoring.svc.cluster.local:9093/api/v2/alerts"
DAY = timedelta(days=1)


def quantity(count, unit):
    return f"{count:,} {unit}{'' if count == 1 else 's'}"


def local_summary(db, day):
    previous_day = day - DAY
    rows = db.execute(
        """
        SELECT d.created_at < :day, substr(d.created_at, 12, 2), d.value,
               a.source_as_number, a.source_as_name
        FROM decisions AS d
        LEFT JOIN alerts AS a ON a.id = d.alert_decisions
        WHERE d.origin = 'crowdsec' AND d.scenario = 'crowdsecurity/http-probing'
          AND d.type = 'ban' AND d.scope = 'Ip' AND d.simulated = 0
          AND d.created_at >= :previous AND d.created_at < :end
        """,
        {"previous": previous_day.isoformat(), "day": day.isoformat(), "end": (day + DAY).isoformat()},
    )
    previous = 0
    by_ip = Counter()
    by_hour = [0] * 24
    network_ips = defaultdict(set)
    network_names = {}
    for is_previous_day, hour, ip, asn, name in rows:
        if is_previous_day:
            previous += 1
            continue
        by_ip[ip] += 1
        by_hour[int(hour)] += 1
        name = " ".join((name or "").split())
        network = f"AS{asn}" if asn and asn != "0" else name
        if network:
            network_ips[network].add(ip)
            if name:
                network_names[network] = name

    if not by_ip:
        return []

    bans = by_ip.total()
    if bans > previous:
        trend = "📈 Up from"
    elif bans < previous:
        trend = "📉 Down from"
    else:
        trend = "↔️ Unchanged from"
    repeats = sum(n > 1 for n in by_ip.values())
    repeat_line = f"🔁 Repeat IPs: {repeats:,}"
    if repeats:
        repeat_line += f" (most bans for one IP: {max(by_ip.values()):,})"
    peak = by_hour.index(max(by_hour))
    lines = [
        f"🛡 CrowdSec daily summary · {day:%d %b %Y} (UTC)",
        "",
        f"{quantity(bans, 'local scanner ban')} across {quantity(len(by_ip), 'distinct IP')}",
        f"{trend} {previous:,} on {previous_day:%d %b}",
        repeat_line,
        f"🕘 Busiest hour: {peak:02}:00–{(peak + 1) % 24:02}:00 UTC ({quantity(by_hour[peak], 'ban')})",
    ]
    if network_ips:
        top = min(network_ips, key=lambda key: (-len(network_ips[key]), key))
        ips = quantity(len(network_ips[top]), "distinct IP")
        lines.append(f"🌐 Top known source network: {network_names.get(top, top)} ({ips})")
    return lines


def cloudflare_blocks(day):
    account = os.getenv("CLOUDFLARE_ACCOUNT_ID")
    token = os.getenv("CLOUDFLARE_ANALYTICS_TOKEN")
    if not account or not token:
        print("Cloudflare analytics credentials unavailable", file=sys.stderr)
        return None

    query = f"""
        SELECT SUM(_sample_interval * double1) FROM h8s_crowdsec
        WHERE timestamp >= toDateTime('{day} 00:00:00', 'Etc/UTC')
          AND timestamp < toDateTime('{day + DAY} 00:00:00', 'Etc/UTC')
          AND blob1 = 'dropped' AND blob4 = 'ban'
        FORMAT TabSeparated
    """
    request = Request(
        f"https://api.cloudflare.com/client/v4/accounts/{account}/analytics_engine/sql",
        data=query.encode(),
        headers={"Content-Type": "text/plain"},
    )
    request.add_unredirected_header("Authorization", f"Bearer {token}")
    try:
        with urlopen(request, timeout=10) as response:
            return round(float(response.read()))
    except (OSError, HTTPException, ValueError, OverflowError) as error:
        reason = f"HTTP {error.code}" if isinstance(error, HTTPError) else type(error).__name__
        print(f"Cloudflare analytics unavailable: {reason}", file=sys.stderr)
        return None


def report(now):
    day = now.astimezone(UTC).date() - DAY
    with closing(sqlite3.connect(DATABASE, uri=True)) as db:
        lines = local_summary(db, day)
    if not lines:
        print(f"{day} UTC: no local scanner bans")
        return

    blocks = cloudflare_blocks(day)
    estimate = "unavailable" if blocks is None else f"~{quantity(blocks, 'request')}"
    lines.append(f"🚫 Cloudflare blocks (all ban sources): {estimate}")
    summary = "\n".join(lines)
    alert = {
        "labels": {
            "alertname": "CrowdSecDailySummary",
            "namespace": "crowdsec",
            "severity": "info",
            "report_date": day.isoformat(),
        },
        "annotations": {"summary": summary},
        "startsAt": now.isoformat(),
        "endsAt": (now + timedelta(hours=1)).isoformat(),
    }
    request = Request(
        ALERTMANAGER,
        data=json.dumps([alert]).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urlopen(request, timeout=15):
        print(summary)


if __name__ == "__main__":
    report(datetime.now(UTC))
