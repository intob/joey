## Thanks to https://github.com/chemidy/smallest-secured-golang-docker-image

############################
# STEP 1 build the webserver & Tor
############################
FROM golang:alpine as builder

ENV TOR_VERSION="0.4.8.9"
ENV TOR_URL="https://dist.torproject.org/tor-${TOR_VERSION}.tar.gz"
ENV TOR_SIG_URL="https://dist.torproject.org/tor-${TOR_VERSION}.tar.gz.asc"
ENV TOR_KEY="0x6AFEE6D49E92B601"
ENV TOR_PREFIX /usr/local/tor

ENV USER=appuser
ENV UID=10001

# Install stuff
RUN apk update && apk --no-cache add \
        git \
        ca-certificates \
        tzdata \
        bash \
        build-base \
        curl \
        gnupg \
        libevent-dev \
        libressl-dev \
        linux-headers \
        zlib-dev

# Update certs
RUN update-ca-certificates

# See https://stackoverflow.com/a/55757473/12429735
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    "${USER}"

WORKDIR $GOPATH/src/joeyinnes/

# Copy everything
COPY . .

# Build the webserver
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' -a \
    -o /go/bin/joeyinnes .


# Get Tor

RUN mkdir -p "${TOR_PREFIX}"
WORKDIR ${TOR_PREFIX}

RUN set -eux; \
    \
    curl -LO "${TOR_URL}"; \
    curl -LO "${TOR_SIG_URL}" ; \
    \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --keyserver keyserver.ubuntu.com --recv-keys "${TOR_KEY}"; \
    gpg --fingerprint "${TOR_KEY}"; \
    gpg --verify "tor-${TOR_VERSION}.tar.gz.asc"; \
    command -v gpgconf && gpgconf --kill all || :; \
    \
    mkdir -p src; \
    tar xzf tor-${TOR_VERSION}.tar.gz -C src --strip-components=1; \
    rm tor-${TOR_VERSION}.tar.gz tor-${TOR_VERSION}.tar.gz.asc

RUN set -eux; \
    \
    cd ${TOR_PREFIX}/src; \
    ./configure \
        --prefix=${TOR_PREFIX} \
        --sysconfdir=/etc \
        --disable-asciidoc \
        --mandir=${TOR_PREFIX}/man \
        --infodir=${TOR_PREFIX}/info \
        --localstatedir=/var \
        --enable-static-tor \
        --with-libevent-dir=/usr/lib \
        --with-openssl-dir=/usr/lib \
        --with-zlib-dir=/lib; \
    make && make install; \
    \
    scanelf -R --nobanner -F '%F' ${TOR_PREFIX}/bin/ | xargs strip

############################
# STEP 2 build a small image
############################
FROM scratch

COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group
COPY --from=builder /usr/local/tor/bin/tor /usr/bin/tor
COPY --from=builder /go/bin/joeyinnes /go/bin/joeyinnes

ADD entry.sh /
CMD ./entry.sh