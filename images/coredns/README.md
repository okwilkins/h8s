# Image: CoreDNS

This Dockerfile builds CoreDNS with the [coredns-blocklist plugin](https://github.com/relekang/coredns-blocklist) integrated.

## Available Build Arguments

|       Argument      | Default Value |                   Description                   |
|:-------------------:|:-------------:|:-----------------------------------------------:|
|   `GO_IMAGE_TAG`    | `1.24-alpine` |       Full Go image tag for compilation         |
|  `COREDNS_VERSION`  |    `1.12.1`   |             CoreDNS version to build            |
| `BLOCKLIST_VERSION` |    `1.12.1`   |         coredns-blocklist plugin version        |
| `GOOS`              | `linux`       | Target OS to build the binary for               |
| `GOARCH`            | `amd64`       | Target CPU architecture to build the binary for |

**NOTE**: `COREDNS_VERSION` and `BLOCKLIST_VERSION` should be matching.

