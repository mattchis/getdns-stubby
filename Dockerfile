FROM debian:10.10-slim as stubby

ARG GETDNS_VERSION="1.7.0"
ENV GETDNS_VERSION=${GETDNS_VERSION}

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        check \
        cmake \
        dirmngr \
        git \
        gpg \
        gpg-agent \
        libev-dev \
        libevent-dev \
        libssl-dev \
        libuv1-dev \
        libyaml-dev \
    && rm -rf \
        /tmp/* \
        /var/tmp/* \
        /var/lib/apt/lists/*

WORKDIR /tmp

RUN git clone --recurse-submodules https://github.com/getdnsapi/getdns.git getdns \
    && cd getdns \
    && git checkout tags/v${GETDNS_VERSION} \
    && git verify-tag v${GETDNS_VERSION} \
    && cmake -DUSE_LIBIDN2=OFF -DENABLE_STUB_ONLY=ON -DBUILD_STUBBY=ON . \
    && make \
    && make install \
    && strip -s /usr/local/bin/getdns_server_mon \
    && strip -s /usr/local/bin/stubby \
    && strip -s /usr/local/lib/libgetdns.so.10

FROM debian:10.10-slim

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        # dns-root-data \
        gosu \
        libyaml-0-2 \
    && c_rehash \
    && rm -rf \
        /tmp/* \
        /var/tmp/* \
        /var/lib/apt/lists/*

COPY --from=stubby /usr/local/lib/libgetdns.so.10 /usr/local/lib/
COPY --from=stubby /usr/local/bin/stubby /bin/
COPY --from=stubby /usr/local/bin/getdns_server_mon /bin/
COPY --from=stubby /tmp/getdns/stubby/stubby.yml.example /usr/local/etc/stubby/stubby.yml

RUN adduser --system --no-create-home stubby

WORKDIR /
COPY docker-entrypoint.sh .
RUN chmod +x docker-entrypoint.sh

EXPOSE 53/tcp
EXPOSE 53/udp

# HEALTHCHECK CMD ["/bin/getdns_server_mon", "-M", "-t", "@127.0.0.1", "lookup", "google.com"]

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["stubby"]