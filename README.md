# ImmortalWrt Configuration & 3proxy Setup

Kho lưu trữ cấu hình cho router ImmortalWrt (Airoha AN7581) chạy `3proxy` và `Tailscale`.

## Cấu trúc thư mục

├── etc/
│   ├── 3proxy-residential.cfg   # Cấu hình 3proxy đa cổng (10001, 10002, 10003)
│   ├── config/                  # Các file UCI config (firewall, network, tailscale, smartdns, natmap...)
│   ├── hotplug.d/iface/         # Script hotplug tự gán IP & route khi tailscale0 up
│   ├── init.d/                  # Procd init service (resproxy)
│   ├── nftables.d/              # Custom nftables hook (20-ttl-lock.nft khóa TTL 64 chống soi phát Wi-Fi)
│   └── rc.local                 # Script khởi động đảm bảo route Tailscale
└── scripts/
    └── deploy.sh                # Đẩy cấu hình từ repo lên router và nạp lại dịch vụ
```

## Thông tin Proxy

Kết nối qua mạng Tailscale (`100.71.252.27`):

```text
socks5h://proxy1:MinhProxy_9267_Xk3@100.71.252.27:10001
socks5h://proxy2:Proxy2_8Nk32xQa@100.71.252.27:10002
socks5h://proxy3:Proxy3_7Lm94zKt@100.71.252.27:10003
```

> **Ghi chú**: Sử dụng schema `socks5h://` để DNS query được phân giải trực tiếp tại router, chống rò rỉ DNS (DNS leak).

## Quản trị

### Sao lưu cấu hình từ router
```sh
./scripts/backup.sh [ROUTER_IP] [ROUTER_USER]
# Mặc định: 192.168.2.1 / root
```

### Triển khai cấu hình lên router
```sh
./scripts/deploy.sh [ROUTER_IP] [ROUTER_USER]
# Mặc định: 192.168.2.1 / root
```
