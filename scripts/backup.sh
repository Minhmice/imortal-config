#!/bin/sh
set -e

ROUTER_IP="${1:-100.71.252.27}"
ROUTER_USER="${2:-root}"

echo "Fetching configs from ${ROUTER_USER}@${ROUTER_IP}..."

ssh.exe -o BatchMode=yes -o StrictHostKeyChecking=no "${ROUTER_USER}@${ROUTER_IP}" \
  "tar -czf - \
    /etc/3proxy-residential.cfg \
    /etc/init.d/resproxy \
    /etc/rc.local \
    /etc/config/3proxy \
    /etc/config/tailscale \
    /etc/config/firewall \
    /etc/config/dropbear \
    /etc/config/smartdns \
    /etc/config/natmap \
    /etc/config/pbr \
    /etc/config/nlbwmon \
    /etc/nftables.d \
    /etc/adguardhome/adguardhome.yaml \
    /etc/config/adguardhome \
    /etc/config/dhcp \
    /etc/sysctl.conf \
    /etc/config/system" | tar -xzf -

echo "Configs backed up successfully into ./etc"
