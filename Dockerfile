FROM --platform=$BUILDPLATFORM golang:1.27.3 AS go_builder
WORKDIR /go/src/github.com/percona/percona-backup-mongodb

ARG GIT_COMMIT
ARG GIT_BRANCH
ARG BUILD_TIME
ARG TARGETARCH
ARG CGO_ENABLED=1

RUN if [ "$TARGETARCH" = "amd64" ]; then \
        export PKG=gcc-x86-64-linux-gnu; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        export PKG=gcc-aarch64-linux-gnu; \
    fi && \
    dpkg --add-architecture $TARGETARCH && \
    apt-get update && apt-get install -y libkrb5-dev:$TARGETARCH $PKG

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN if [ "$TARGETARCH" = "amd64" ]; then \
        export CC=x86_64-linux-gnu-gcc; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        export CC=aarch64-linux-gnu-gcc; \
    fi && \
    export CGO_ENABLED=$CGO_ENABLED && \
    make build-all

FROM percona/percona-backup-mongodb:2.17.0

USER root

RUN microdnf upgrade -y ca-certificates expat xz-libs && \
    microdnf clean all && \
    rm -rf /var/cache/yum

COPY --from=go_builder /go/src/github.com/percona/percona-backup-mongodb/bin/pbm /usr/bin/pbm
COPY --from=go_builder /go/src/github.com/percona/percona-backup-mongodb/bin/pbm-agent /usr/bin/pbm-agent
COPY --from=go_builder /go/src/github.com/percona/percona-backup-mongodb/bin/pbm-speed-test /usr/bin/pbm-speed-test
COPY --from=go_builder /go/src/github.com/percona/percona-backup-mongodb/bin/pbm-agent-entrypoint /usr/bin/pbm-agent-entrypoint

USER 1001
