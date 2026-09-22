# Tính năng đã cài đặt trên ImmortalWrt

Ghi chú trạng thái thực tế của router ImmortalWrt Airoha AN7581.

## 1. 3proxy + Tailscale

- Cấu hình: `/etc/3proxy-residential.cfg`.
- 3proxy chạy trên port `10001`, `10002`, `10003`; Tailscale cấp IP `100.71.252.27`.
- Ba port cùng đi ra qua WAN `192.168.1.40`, nên cùng public egress IP. Khác port chỉ tách account, không tạo thêm IP.
- Tailscale cung cấp đường hầm riêng; không cần expose proxy trực tiếp ra Internet.
- Định dạng client:

  ```text
  socks5h://<user>:<password>@100.71.252.27:<port>
  ```

- Password proxy từng xuất hiện trong chat/repository cũ. Cần đổi trước khi chia sẻ repo hoặc cấp quyền cho người khác.

## 2. SmartDNS

- Đã cài `smartdns` và `luci-app-smartdns`.
- Service đang chạy, dùng nhiều upstream DNS và các tùy chọn cache/prefetch/dual-stack.
- SmartDNS chọn upstream/bản ghi theo speed check và cache; kết quả phụ thuộc cấu hình, mạng và thời điểm đo.
- Kiểm tra:

  ```sh
  /etc/init.d/smartdns status
  nslookup google.com 127.0.0.1
  ```

## 3. Chuẩn hóa TTL/Hop Limit

- File: `/etc/nftables.d/20-ttl-lock.nft`.
- Rule nftables đặt IPv4 TTL và IPv6 Hop Limit thành `64` cho traffic postrouting.
- Đây không phải cơ chế ẩn danh, không che giấu hoàn toàn số thiết bị và có thể phá chẩn đoán mạng. Tắt nếu không có nhu cầu tương thích cụ thể.

## 4. NATMap

- Đã cài `natmap` và `luci-app-natmap`.
- Instance mặc định vẫn tắt.
- NATMap thử NAT traversal qua STUN/keep-alive. Thành công phụ thuộc loại NAT/CGNAT; không đảm bảo mở được inbound TCP và không thay thế Tailscale/VPS.
- Không expose LuCI, SSH hoặc 3proxy công khai bằng cấu hình mặc định.

## 5. DAE và SyncDial chưa cài

- DAE cần kernel modules như `kmod-sched-bpf`, `kmod-sched-core`, `kmod-veth`, `kmod-xdp-sockets-diag`; snapshot AN7581 hiện không cung cấp đủ dependency phù hợp.
- SyncDial chưa được bật. Multi-WAN/Policy Based Routing là hướng an toàn hơn để thử traffic splitting trên firewall4/nftables.
