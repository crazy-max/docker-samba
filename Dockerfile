# syntax=docker/dockerfile:1

ARG ALPINE_VERSION=3.18
ARG S6_VERSION=2.2.0.3

ARG SAMBA_VERSION=4.18.5
ARG WSDD2_VERSION=e37443ac4c757dbf14167ec3f754ebe88244ad4b

FROM --platform=${BUILDPLATFORM} crazymax/alpine-s6:${ALPINE_VERSION}-${S6_VERSION} AS wsdd2-src
RUN apk --update --no-cache add git
WORKDIR /src
RUN git init . && git remote add origin "https://github.com/Netgear/wsdd2.git"
ARG WSDD2_VERSION
RUN git fetch origin "${WSDD2_VERSION}" && git checkout -q FETCH_HEAD

# TODO: do cross-compilation in this stage to build wsdd2
FROM crazymax/alpine-s6:${ALPINE_VERSION}-${S6_VERSION} AS wsdd2
RUN apk --update --no-cache add linux-headers gcc make musl-dev
WORKDIR /src
COPY --from=wsdd2-src /src /src
RUN make DESTDIR=/dist install

FROM crazymax/alpine-s6:${ALPINE_VERSION}-${S6_VERSION}
ARG SAMBA_VERSION
RUN apk --update --no-cache add \
    bash \
    coreutils \
    jq \
    samba=${SAMBA_VERSION}-r0 \
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
