# SearXNG

[SearXNG](https://github.com/searxng/searxng) uses Exa Auto for web searches and Wikipedia/Wikidata for infoboxes. GitHub and Hacker News have separate search tabs. Kagi supplies autocomplete without an API key.

## Page Descriptions

The Exa plugin generates query-relevant page summaries. It adds latency and [costs $0.01 for ten summaries](https://exa.ai/docs/admin/pricing), on top of search charges. Failures leave the original descriptions intact. AI summaries can contain mistakes.

Disable **Exa page summaries** in SearXNG Preferences to opt out.

