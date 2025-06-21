# syntax=docker/dockerfile:1

ARG ALPINE_VERSION=3.22
ARG S6_VERSION=2.2.0.3

ARG SAMBA_VERSION=4.21.4
ARG WSDD2_VERSION=b676d8ac8f1aef792cb0761fb68a0a589ded3207

FROM --platform=${BUILDPLATFORM} crazymax/alpine-s6:${ALPINE_VERSION}-${S6_VERSION} AS wsdd2-src
WORKDIR /src
ARG WSDD2_VERSION
ADD "https://github.com/Netgear/wsdd2.git#${WSDD2_VERSION}" .

# TODO: do cross-compilation in this stage to build wsdd2
FROM crazymax/alpine-s6:${ALPINE_VERSION}-${S6_VERSION} AS wsdd2
RUN apk --update --no-cache add linux-headers gcc make musl-dev patch
WORKDIR /src
COPY --from=wsdd2-src /src /src
COPY patches/wsdd2 /tmp/wsdd2-patches
RUN patch -p1 < /tmp/wsdd2-patches/0001-fix-msghdr-initialization.patch
RUN make DESTDIR=/dist install

FROM crazymax/alpine-s6:${ALPINE_VERSION}-${S6_VERSION}
ARG SAMBA_VERSION
RUN apk --update --no-cache add \
    bash \
    coreutils \
    jq \
    samba=${SAMBA_VERSION}-r4 \
    shadow \
    tzdata \
    yq \
  && rm -rf /tmp/*

COPY --from=wsdd2 /dist/usr/sbin/wsdd2 /usr/bin/
COPY rootfs /

EXPOSE 445 3702/tcp 3702/udp 5355/tcp 5355/udp
VOLUME [ "/data" ]
ENTRYPOINT [ "/init" ]

HEALTHCHECK --interval=30s --timeout=10s \
  CMD smbclient -L \\localhost -U % -m SMB3
