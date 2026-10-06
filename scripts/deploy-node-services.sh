#!/usr/bin/env bash
set -euo pipefail

# Script tự động cấu hình và triển khai dịch vụ cho Node Nokia XG-040G-MD mới
# Sử dụng: ./scripts/deploy-node-services.sh <ROUTER_IP> <HOSTNAME> <LAN_IP> <MAC_LAN> <MAC_WAN>

ROUTER_IP="${1:-192.168.1.1}"
HOSTNAME="${2:-immortalwrt2}"
LAN_IP="${3:-192.168.20.1}"
MAC_LAN="${4:-90:03:2E:64:16:24}"
MAC_WAN="${5:-90:03:2E:64:16:25}"
ROUTER_USER="${ROUTER_USER:-root}"

echo "=========================================================="
echo "TRIỂN KHAI DỊCH VỤ CHO NODE MỚI: ${HOSTNAME}"
echo "Target: ${ROUTER_USER}@${ROUTER_IP} | LAN IP: ${LAN_IP}/24"
echo "MAC LAN: ${MAC_LAN} | MAC WAN: ${MAC_WAN}"
echo "=========================================================="

echo "[1/5] Đang nén và đẩy gói cấu hình cơ bản lên Router..."
tar -czf - \
  etc/3proxy-residential.cfg \
  etc/init.d/resproxy \
  etc/init.d/smartdns \
  etc/init.d/tailscale \
  etc/init.d/adguardhome \
  etc/rc.local \
  etc/config/dropbear \
  etc/config/smartdns \
  etc/config/adguardhome \
  etc/config/firewall \
  etc/adguardhome/adguardhome.yaml \
  etc/nftables.d | ssh -o BatchMode=yes -o StrictHostKeyChecking=no "${ROUTER_USER}@${ROUTER_IP}" "tar -xzf - -C /"

echo "[2/5] Đang cài đặt các gói phụ trợ qua apk..."
ssh -o BatchMode=yes -o StrictHostKeyChecking=no "${ROUTER_USER}@${ROUTER_IP}" << 'EOF'
echo "nameserver 1.1.1.1" > /tmp/resolv.conf
apk update >/dev/null 2>&1 || true
apk add kmod-tun ca-bundle >/dev/null 2>&1 || true
EOF

echo "[3/5] Đang cấu hình mạng riêng biệt (Chống trùng MAC & Subnet)..."
ssh -o BatchMode=yes -o StrictHostKeyChecking=no "${ROUTER_USER}@${ROUTER_IP}" << EOF
# Đặt Hostname
uci set system.@system[0].hostname='${HOSTNAME}'
uci commit system

# Cấu hình Network
cat > /etc/config/network << 'NETEOF'
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	list ipaddr '127.0.0.1/8'

config globals 'globals'
	option packet_steering '1'

config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'lan2'
	list ports 'lan3'
	list ports 'lan4'
	option macaddr '${MAC_LAN}'

config interface 'lan'
	option device 'br-lan'
	option proto 'static'
	option ip6assign '60'
	option multipath 'off'
	list ipaddr '${LAN_IP}/24'

config interface 'wan'
	option device 'lan1'
	option proto 'dhcp'

config interface 'wan6'
	option device 'lan1'
	option proto 'dhcpv6'

config interface 'tailscale'
	option device 'tailscale0'
	option proto 'none'

config device 'eth0_mac_fix'
	option name 'eth0'
	option macaddr '${MAC_LAN}'

config device 'lan2_mac_fix'
	option name 'lan2'
	option macaddr '${MAC_LAN}'

config device 'lan3_mac_fix'
	option name 'lan3'
	option macaddr '${MAC_LAN}'

config device 'lan4_mac_fix'
	option name 'lan4'
	option macaddr '${MAC_LAN}'

config device 'lan1_mac_fix'
	option name 'lan1'
	option macaddr '${MAC_WAN}'
NETEOF

# Mở Firewall WAN cho LuCI, SSH, AdGuard
uci add firewall rule >/dev/null 2>&1 || true
uci set firewall.@rule[-1].name='Allow-WAN-LuCI'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='80 443'
uci set firewall.@rule[-1].target='ACCEPT'

uci add firewall rule >/dev/null 2>&1 || true
uci set firewall.@rule[-1].name='Allow-WAN-SSH'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='22'
uci set firewall.@rule[-1].target='ACCEPT'

uci add firewall rule >/dev/null 2>&1 || true
uci set firewall.@rule[-1].name='Allow-WAN-AdGuard'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='3000'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
EOF

echo "[4/5] Đang thiết lập quyền hạn và người dùng cho dịch vụ..."
ssh -o BatchMode=yes -o StrictHostKeyChecking=no "${ROUTER_USER}@${ROUTER_IP}" << 'EOF'
# Tạo user adguardhome nếu chưa có
grep -q adguardhome /etc/passwd || echo "adguardhome:x:853:853:adguardhome:/var/run/adguardhome:/bin/false" >> /etc/passwd
grep -q adguardhome /etc/group || echo "adguardhome:x:853:adguardhome" >> /etc/group
mkdir -p /var/run/adguardhome /var/lib/adguardhome /etc/adguardhome /var/etc/smartdns /var/lib/tailscale /etc/tailscale
chown -R 853:853 /var/run/adguardhome /var/lib/adguardhome /etc/adguardhome

chmod +x /etc/init.d/resproxy /etc/init.d/smartdns /etc/init.d/tailscale /etc/init.d/adguardhome /etc/rc.local
chmod 600 /etc/3proxy-residential.cfg

# Kích hoạt tự khởi động
/etc/init.d/resproxy enable
/etc/init.d/smartdns enable
/etc/init.d/adguardhome enable
/etc/init.d/tailscale enable
EOF

echo "[5/5] Nạp lại mạng và khởi động dịch vụ..."
ssh -o BatchMode=yes -o StrictHostKeyChecking=no "${ROUTER_USER}@${ROUTER_IP}" << 'EOF'
/etc/init.d/network reload
/etc/init.d/firewall reload
/etc/init.d/smartdns restart
/etc/init.d/adguardhome restart
/etc/init.d/resproxy restart
/etc/init.d/tailscale restart
EOF

echo "=========================================================="
echo "[THÀNH CÔNG] Node ${HOSTNAME} đã được cấu hình hoàn chỉnh!"
echo "Bước cuối: Đăng nhập SSH vào node và gõ 'tailscale login' để nhận IP Tailscale!"
echo "=========================================================="
