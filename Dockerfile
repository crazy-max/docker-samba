# syntax=docker/dockerfile:1

ARG ALPINE_VERSION=3.24

ARG SAMBA_VERSION=4.23.8
ARG SAMBA_REVISION=r0

ARG WSDD2_VERSION=0098d86d2998cff056ec19e734e17bf99d5314ae

FROM --platform=${BUILDPLATFORM} alpine:${ALPINE_VERSION} AS wsdd2-src
WORKDIR /src
ARG WSDD2_VERSION
ADD "https://github.com/crazy-max/wsdd2.git#${WSDD2_VERSION}" .

# TODO: do cross-compilation in this stage to build wsdd2
FROM alpine:${ALPINE_VERSION} AS wsdd2
RUN apk --update --no-cache add linux-headers gcc make musl-dev
WORKDIR /src
COPY --from=wsdd2-src /src /src
RUN make DESTDIR=/dist install

FROM alpine:${ALPINE_VERSION}
ARG SAMBA_VERSION
ARG SAMBA_REVISION
RUN apk --update --no-cache add \
    avahi \
    bash \
    coreutils \
    jq \
    s6-overlay \
    samba=${SAMBA_VERSION}-${SAMBA_REVISION} \
    shadow \
    tzdata \
    yq \
  && sed -i 's/^#*enable-dbus=.*/enable-dbus=no/' /etc/avahi/avahi-daemon.conf \
  && rm -f /etc/avahi/services/* \
  && rm -rf /tmp/*

COPY --from=wsdd2 /dist/usr/sbin/wsdd2 /usr/bin/
COPY rootfs /
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_STAGE2_HOOK=/etc/s6-overlay/scripts/runtime-bundles

EXPOSE 445 5353/udp 3702/tcp 3702/udp 5355/tcp 5355/udp
VOLUME [ "/data" ]
ENTRYPOINT [ "/init" ]

HEALTHCHECK --interval=30s --timeout=10s \
  CMD ["sh", "/usr/local/bin/healthcheck"]
