# Tính năng đã cài đặt trên ImmortalWrt

Ghi chú trạng thái thực tế của router ImmortalWrt Airoha AN7581.

## 1. 3proxy + Tailscale (Remote Access)

- Cấu hình: `/etc/3proxy-residential.cfg`.
- 3proxy chạy trên port `10001`, `10002`, `10003`; Tailscale cấp IP `100.71.252.27`.
- Ba port cùng đi ra qua WAN `192.168.1.40`, nên cùng public egress IP. Khác port chỉ tách account, không tạo thêm IP.
- Tailscale cung cấp đường hầm riêng; không cần expose proxy trực tiếp ra Internet.
- Định dạng client:

  ```text
  socks5h://<user>:<password>@100.71.252.27:<port>
  ```

## 2. SmartDNS

- Đã cài `smartdns` và `luci-app-smartdns`.
- Service đang chạy, dùng nhiều upstream DNS và các tùy chọn cache/prefetch/dual-stack.
- SmartDNS chọn upstream/bản ghi theo speed check và cache; kết quả phụ thuộc cấu hình, mạng và thời điểm đo.

## 3. Khóa TTL Tầng Kernel

- File: `/etc/nftables.d/20-ttl-lock.nft`.
- Rule nftables đặt IPv4 TTL và IPv6 Hop Limit thành `64` cho traffic postrouting.
- Chạy trực tiếp trong hook Netfilter postrouting của kernel, không tốn tài nguyên.

## 4. NATMap

- Đã cài `natmap` và `luci-app-natmap`.
- Hỗ trợ STUN hole-punching khi cần mở port ra ngoài từ môi trường CGNAT.

## 5. TCP BBR Congestion Control (Google BBR)

- Đã cài kernel module `kmod-tcp-bbr`.
- File cấu hình: `/etc/sysctl.d/12-tcp-bbr.conf`.
- Tự động thay thế thuật toán `cubic` cũ bằng `bbr`, giúp tối đa hóa throughput mạng quốc tế, giảm packet loss và tối ưu độ trễ cho Proxy / VPN / SSH.

## 6. PBR (Policy Based Routing)

- Đã cài `pbr` và `luci-app-pbr`.
- Cho phép định tuyến thông minh trên nền nftables: ép các thiết bị, IP hoặc domain cụ thể đi qua interface mong muốn (WAN, Tailscale, VPN...).

## 7. NLBWMON (Giám Sát Băng Thông Thiết Bị)

- Đã cài `nlbwmon` và `luci-app-nlbwmon`.
- Thống kê chi tiết dung lượng upload/download của từng địa chỉ IP và thiết bị trong mạng LAN, có biểu đồ Chart.js trực quan trong LuCI.

## 8. Wake-on-LAN (WOL)

- Đã cài `luci-app-wol`, `wakeonlan`, `etherwake`.
- Cho phép bật máy tính (PC) từ xa trong mạng LAN qua giao diện web LuCI hoặc qua kết nối Tailscale.
