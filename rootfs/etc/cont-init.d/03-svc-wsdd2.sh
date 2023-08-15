#!/usr/bin/with-contenv sh
# shellcheck shell=sh

: "${SAMBA_WORKGROUP=WORKGROUP}"
: "${WSDD2_ENABLE=0}"
: "${WSDD2_HOSTNAME=}"
: "${WSDD2_NETBIOS_NAME=}"
: "${WSDD2_INTERFACE=}"

if [ "$WSDD2_ENABLE" != "1" ]; then
  exit 0
fi

mkdir -p /etc/services.d/wsdd2

wsdd2Args="-G ${SAMBA_WORKGROUP} -W"
if [ -n "${WSDD2_HOSTNAME}" ]; then
  wsdd2Args="${wsdd2Args} -H ${WSDD2_HOSTNAME}"
fi
if [ -n "${WSDD2_NETBIOS_NAME}" ]; then
  wsdd2Args="${wsdd2Args} -N ${WSDD2_NETBIOS_NAME}"
fi
if [ -n "${WSDD2_INTERFACE}" ]; then
  wsdd2Args="${wsdd2Args} -i ${WSDD2_INTERFACE}"
fi

cat > /etc/services.d/wsdd2/run <<EOL
#!/usr/bin/execlineb -P
with-contenv
exec /usr/bin/wsdd2 ${wsdd2Args}
EOL
chmod +x /etc/services.d/wsdd2/run
