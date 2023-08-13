#!/usr/bin/with-contenv sh
# shellcheck shell=sh

mkdir -p /etc/services.d/smbd

cat > /etc/services.d/smbd/run <<EOL
#!/usr/bin/execlineb -P
with-contenv
smbd -F --debug-stdout --no-process-group
EOL
chmod +x /etc/services.d/smbd/run
