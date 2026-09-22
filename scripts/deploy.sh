#!/bin/sh
set -e

ROUTER_IP="${1:-100.71.252.27}"
ROUTER_USER="${2:-root}"

echo "Deploying configs to ${ROUTER_USER}@${ROUTER_IP}..."

tar -czf - etc | ssh.exe -o BatchMode=yes -o StrictHostKeyChecking=no "${ROUTER_USER}@${ROUTER_IP}" "tar -xzf - -C /"

ssh.exe -o BatchMode=yes -o StrictHostKeyChecking=no "${ROUTER_USER}@${ROUTER_IP}" << 'EOF'
chmod +x /etc/init.d/resproxy /etc/hotplug.d/iface/99-tailscale /etc/rc.local
chmod 600 /etc/3proxy-residential.cfg

/etc/init.d/firewall reload
/etc/init.d/resproxy restart
/etc/init.d/tailscale restart
EOF

echo "Deployed and services reloaded successfully."
