ARG GO_VERSION=1.24

FROM golang:${GO_VERSION}-alpine AS common

RUN apk add --no-cache git


FROM common AS git

ARG COREDNS_VERSION=1.12.1
WORKDIR /coredns
RUN git clone --depth 1 --branch v${COREDNS_VERSION} https://github.com/coredns/coredns.git .


FROM common AS builder

ARG BLOCKLIST_VERSION=1.12.1

WORKDIR /coredns
# RUN go get github.com/relekang/coredns-blocklist@v${BLOCKLIST_VERSION}

COPY --from=git /coredns /coredns
COPY ./plugin.cfg ./plugin.cfg

RUN go mod edit -require=github.com/relekang/coredns-blocklist@v${BLOCKLIST_VERSION}
RUN go generate
RUN go mod tidy


RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -trimpath \
    -ldflags='-w -s -extldflags "-static"' \
    -a \
    -installsuffix cgo \
    -o coredns \
    .


FROM scratch

COPY --from=builder /coredns/coredns /coredns
ENTRYPOINT ["/coredns"]
