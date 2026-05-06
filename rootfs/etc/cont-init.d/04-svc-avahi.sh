#!/usr/bin/with-contenv sh
# shellcheck shell=sh

: "${AVAHI_ENABLE=0}"
: "${AVAHI_INTERFACES=}"
: "${AVAHI_MODEL=RackMac}"
: "${AVAHI_ADISK_NAME=}"

if [ "$AVAHI_ENABLE" != "1" ]; then
  exit 0
fi

xml_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

sed_escape() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

avahiModel=$(xml_escape "${AVAHI_MODEL}")
avahiAdiskName=$(xml_escape "${AVAHI_ADISK_NAME}")
avahiInterfaces=$(sed_escape "${AVAHI_INTERFACES}")

if [ -n "${AVAHI_INTERFACES}" ]; then
  sed -i "s/^#*allow-interfaces=.*/allow-interfaces=${avahiInterfaces}/" /etc/avahi/avahi-daemon.conf
fi

mkdir -p /etc/avahi/services
cat > /etc/avahi/services/samba.service <<EOL
<?xml version="1.0" standalone="no"?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h</name>
  <service>
    <type>_smb._tcp</type>
    <port>445</port>
  </service>
  <service>
    <type>_device-info._tcp</type>
    <port>0</port>
    <txt-record>model=${avahiModel}</txt-record>
  </service>
EOL

if [ -n "${AVAHI_ADISK_NAME}" ]; then
  cat >> /etc/avahi/services/samba.service <<EOL
  <service>
    <type>_adisk._tcp</type>
    <port>9</port>
    <txt-record>sys=waMa=0,adVF=0x100</txt-record>
    <txt-record>dk0=adVN=${avahiAdiskName},adVF=0x82</txt-record>
  </service>
EOL
fi

cat >> /etc/avahi/services/samba.service <<EOL
</service-group>
EOL

mkdir -p /etc/services.d/avahi

cat > /etc/services.d/avahi/run <<EOL
#!/usr/bin/execlineb -P
with-contenv
exec /usr/sbin/avahi-daemon --no-rlimits
EOL
chmod +x /etc/services.d/avahi/run
