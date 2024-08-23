#!/usr/bin/with-contenv bash
# shellcheck shell=bash

TZ=${TZ:-UTC}
CONFIG_FILE=${CONFIG_FILE:-/data/config.yml}

SAMBA_WORKGROUP=${SAMBA_WORKGROUP:-WORKGROUP}
SAMBA_SERVER_STRING=${SAMBA_SERVER_STRING:-Docker Samba Server}
SAMBA_LOG_LEVEL=${SAMBA_LOG_LEVEL:-0}
SAMBA_FOLLOW_SYMLINKS=${SAMBA_FOLLOW_SYMLINKS:-yes}
SAMBA_WIDE_LINKS=${SAMBA_WIDE_LINKS:-yes}
SAMBA_HOSTS_ALLOW=${SAMBA_HOSTS_ALLOW:-127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16}
#SAMBA_INTERFACES=${SAMBA_INTERFACES:-eth0}

# https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html#VFSOBJECTS
# https://wiki.samba.org/index.php/Configure_Samba_to_Work_Better_with_Mac_OS_X
SAMBA_GLOBAL_VFS_OBJECTS=${SAMBA_GLOBAL_VFS_OBJECTS:-catia fruit streams_xattr}

echo "Setting timezone to ${TZ}"
ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime
echo "${TZ}" > /etc/timezone

echo "Initializing files and folders"
mkdir -p /data/cache /data/lib

# fixes regression keeping improper symlinks
# https://github.com/crazy-max/docker-samba/issues/48
if [ -L "/data/lib/lib" ]; then
  rm -f /data/lib/lib
fi
if [ -L "/data/cache/cache" ]; then
  rm -f /data/cache/cache
fi

if [ ! -L /var/lib/samba ]; then
  if [ -z "$(ls -A /data/lib)" ]; then
    cp -r /var/lib/samba/* /data/lib/
  fi
  rm -rf /var/lib/samba
  ln -sf /data/lib /var/lib/samba
fi
if [ ! -L /var/cache/samba ]; then
  rm -rf /var/cache/samba
  ln -sf /data/cache /var/cache/samba
fi

echo "Setting global configuration"
  cat > /etc/samba/smb.conf <<EOL
[global]
workgroup = ${SAMBA_WORKGROUP}
server string = ${SAMBA_SERVER_STRING}
server role = standalone server
server services = -dns, -nbt
server signing = default
server multi channel support = yes

log level = ${SAMBA_LOG_LEVEL}
;log file = /usr/local/samba/var/log.%m
;max log size = 50

hosts allow = ${SAMBA_HOSTS_ALLOW}
hosts deny = 0.0.0.0/0

security = user
guest account = nobody
pam password change = yes
map to guest = bad user
usershare allow guests = yes

create mask = 0664
force create mode = 0664
directory mask = 0775
force directory mode = 0775
follow symlinks = ${SAMBA_FOLLOW_SYMLINKS}
wide links = ${SAMBA_WIDE_LINKS}
unix extensions = no

printing = bsd
printcap name = /dev/null
disable spoolss = yes
disable netbios = yes
smb ports = 445

client ipc min protocol = default
client ipc max protocol = default

;wins support = yes
;wins server = w.x.y.z
;wins proxy = yes
dns proxy = no
socket options = TCP_NODELAY
strict locking = no
local master = no

winbind scan trusted domains = yes

; "setting vfs objects in a share will *overwrite* this global"
vfs objects = ${SAMBA_GLOBAL_VFS_OBJECTS}

; fruit options
fruit:metadata = stream
fruit:nfs_aces = no
fruit:model = MacSamba
fruit:veto_appledouble = no
fruit:posix_rename = yes
fruit:zero_file_id = yes
fruit:wipe_intentionally_left_blank_rfork = yes
fruit:delete_empty_adfiles = yes
fruit:time machine = yes

EOL

if [ -n "${SAMBA_INTERFACES}" ]; then
  cat >> /etc/samba/smb.conf <<EOL
interfaces = ${SAMBA_INTERFACES}
bind interfaces only = yes

EOL
fi

if [[ "$(yq --output-format=json e '(.. | select(tag == "!!str")) |= envsubst' "${CONFIG_FILE}" 2>/dev/null | jq '.auth')" != "null" ]]; then
  for auth in $(yq -j e '(.. | select(tag == "!!str")) |= envsubst' "${CONFIG_FILE}" 2>/dev/null | jq -r '.auth[] | @base64'); do
    _jq() {
      echo "${auth}" | base64 --decode | jq -r "${1}"
    }
    password=$(_jq '.password')
    if [[ "$password" = "null" ]] && [[ -f "$(_jq '.password_file')" ]]; then
      password=$(cat "$(_jq '.password_file')")
    fi
    echo "Creating user $(_jq '.user')/$(_jq '.group') ($(_jq '.uid'):$(_jq '.gid'))"
    id -g "$(_jq '.gid')" &>/dev/null || id -gn "$(_jq '.group')" &>/dev/null || addgroup -g "$(_jq '.gid')" -S "$(_jq '.group')"
    id -u "$(_jq '.uid')" &>/dev/null || id -un "$(_jq '.user')" &>/dev/null || adduser -u "$(_jq '.uid')" -G "$(_jq '.group')" "$(_jq '.user')" -SHD
    echo -e "$password\n$password" | smbpasswd -a -s "$(_jq '.user')"
    unset password
  done
fi

if [[ "$(yq --output-format=json e '(.. | select(tag == "!!str")) |= envsubst' "${CONFIG_FILE}" 2>/dev/null | jq '.global')" != "null" ]]; then
  for global in $(yq --output-format=json e '(.. | select(tag == "!!str")) |= envsubst' "${CONFIG_FILE}" 2>/dev/null | jq -r '.global[] | @base64'); do
  echo "Add global option: $(echo "$global" | base64 --decode)"
  cat >> /etc/samba/smb.conf <<EOL
$(echo "$global" | base64 --decode)
EOL
  done
fi

if [[ "$(yq --output-format=json e '(.. | select(tag == "!!str")) |= envsubst' "${CONFIG_FILE}" 2>/dev/null | jq '.share')" != "null" ]]; then
  for share in $(yq --output-format=json e '(.. | select(tag == "!!str")) |= envsubst' "${CONFIG_FILE}" 2>/dev/null | jq -r '.share[] | @base64'); do
    _jq() {
      echo "${share}" | base64 --decode | jq -r "${1}"
    }
    echo "Creating share $(_jq '.name')"
    if [[ "$(_jq '.name')" = "null" ]] || [[ -z "$(_jq '.name')" ]]; then
      >&2 echo "ERROR: Name required"
      exit 1
    fi
    echo -e "\n[$(_jq '.name')]" >> /etc/samba/smb.conf
    if [[ "$(_jq '.path')" = "null" ]] || [[ -z "$(_jq '.path')" ]]; then
      >&2 echo "ERROR: Path required"
      exit 1
    fi
    echo "path = $(_jq '.path')" >> /etc/samba/smb.conf
    if [[ "$(_jq '.comment')" != "null" ]] && [[ -n "$(_jq '.comment')" ]]; then
      echo "comment = $(_jq '.comment')" >> /etc/samba/smb.conf
    fi
    if [[ "$(_jq '.browsable')" = "null" ]] || [[ -z "$(_jq '.browsable')" ]]; then
      echo "browsable = yes" >> /etc/samba/smb.conf
    else
      echo "browsable = $(_jq '.browsable')" >> /etc/samba/smb.conf
    fi
    if [[ "$(_jq '.readonly')" = "null" ]] || [[ -z "$(_jq '.readonly')" ]]; then
      echo "read only = yes" >> /etc/samba/smb.conf
    else
      echo "read only = $(_jq '.readonly')" >> /etc/samba/smb.conf
    fi
    if [[ "$(_jq '.guestok')" = "null" ]] || [[ -z "$(_jq '.guestok')" ]]; then
      echo "guest ok = yes" >> /etc/samba/smb.conf
    else
      echo "guest ok = $(_jq '.guestok')" >> /etc/samba/smb.conf
    fi
    if [[ "$(_jq '.validusers')" != "null" ]] && [[ -n "$(_jq '.validusers')" ]]; then
      echo "valid users = $(_jq '.validusers')" >> /etc/samba/smb.conf
    fi
    if [[ "$(_jq '.adminusers')" != "null" ]] && [[ -n "$(_jq '.adminusers')" ]]; then
      echo "admin users = $(_jq '.adminusers')" >> /etc/samba/smb.conf
    fi
    if [[ "$(_jq '.writelist')" != "null" ]] && [[ -n "$(_jq '.writelist')" ]]; then
      echo "write list = $(_jq '.writelist')" >> /etc/samba/smb.conf
    fi
    if [[ "$(_jq '.veto')" != "null" ]] && [[ "$(_jq '.veto')" = "no" ]]; then
      echo "veto files = /._*/.apdisk/.AppleDouble/.DS_Store/.TemporaryItems/.Trashes/desktop.ini/ehthumbs.db/Network Trash Folder/Temporary Items/Thumbs.db/" >> /etc/samba/smb.conf
      echo "delete veto files = yes" >> /etc/samba/smb.conf
    fi
    if [[ "$(_jq '.hidefiles')" != "null" ]] && [[ -n "$(_jq '.hidefiles')" ]]; then
      echo "hide files = $(_jq '.hidefiles')" >> /etc/samba/smb.conf
    fi
    if [[ -n "$(_jq '.recycle')" ]] && [[ "$(_jq '.recycle')" == "yes" ]]; then
      echo "vfs objects = ${SAMBA_GLOBAL_VFS_OBJECTS} recycle" >> /etc/samba/smb.conf
      echo "recycle:repository = .recycle" >> /etc/samba/smb.conf
      echo "recycle:keeptree = yes" >> /etc/samba/smb.conf
      echo "recycle:versions = yes" >> /etc/samba/smb.conf
    fi
  done
fi

testparm -s
