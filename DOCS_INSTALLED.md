# Tính năng đã cài đặt & Tối ưu trên ImmortalWrt (Nokia Bell XG-040G-MD)

Tài liệu chi tiết cấu hình và tối ưu hóa router Airoha AN7581.

---

## 1. 3proxy + Tailscale (Remote Access)
- Cấu hình: `/etc/3proxy-residential.cfg`.
- 3proxy chạy trên port `10001`, `10002`, `10003`; Tailscale cấp IP `100.71.252.27`.
- Ba port cùng đi ra qua WAN `192.168.1.40`, chia sẻ cùng public egress IP.
- Dropbear SSH nghe trên LAN và Tailscale; cả SSH key và mật khẩu đều được hỗ trợ, cấu hình MaxAuthTries=3, IdleTimeout=900, SSHKeepAlive=60.
- Định dạng client:
  ```text
  socks5h://<user>:<password>@100.71.252.27:<port>
  ```

---

## 2. Phần cứng Định Tuyến Tốc Độ Cao (Flow Offloading / Hardware NAT)
- Cấu hình: `/etc/config/firewall` (`flow_offloading='1'`, `flow_offloading_hw='1'`).
- Tình trạng: nftables flowtable có `flags offload` trên `lan1`, `lan2`, `lan3`, `lan4`; NPU firmware hiện diện và driver đã bind.
- Tác dụng: các luồng đủ điều kiện có thể bypass phần lớn network stack. Không khẳng định tải CPU `<1%` nếu chưa benchmark thực tế; tắt hardware offload khi dùng SQM hoặc cần NLBWMON đếm tuyệt đối chính xác.

---

## 3. Cặp bài trùng: AdGuard Home + SmartDNS
- Chuỗi xử lý DNS:
  ```text
  Thiết bị (PC, Phone, TV) 
    → dnsmasq (Port 53) 
    → AdGuard Home (Port 5335) [Lọc domain quảng cáo, tracker, mã độc]
    → SmartDNS (Port 6053) [Gửi đa luồng DoT, đo ping trả IP nhanh nhất]
    → Internet
  ```
- Kết quả kiểm tra:
  - `doubleclick.net` trả `0.0.0.0`/`::`.
  - `google.com` trả kết quả bình thường qua chuỗi dnsmasq → AdGuard Home → SmartDNS.
- AdGuard Home DNS chỉ nghe loopback `127.0.0.1:5335`; Web UI chỉ nghe Tailscale `100.71.252.27:3000` và đã bật xác thực admin; query log và statistics lưu 7 ngày, bật optimistic cache.

---

## 4. Tối ưu ZRAM Swap (Thuật toán ZSTD)
- Cấu hình:
  - `system.@system[0].zram_comp_algo='zstd'`
  - `system.@system[0].zram_size_mb='256'`
  - `vm.swappiness = 100` trong `/etc/sysctl.conf` (file được OpenWrt backup qua sysupgrade).
- ZRAM là swap nén trong RAM, không biến 328MB RAM thành một dung lượng cố định lớn hơn. `zstd` ưu tiên tỷ lệ nén; theo dõi CPU/latency và đổi sang `lz4` nếu swap-heavy.

---

## 5. TCP BBR Congestion Control
- Kernel module `kmod-tcp-bbr` được kích hoạt; `net.ipv4.tcp_congestion_control=bbr` lưu trong `/etc/sysctl.conf`.
- BBR chỉ áp dụng cho TCP do chính router phát/nhận (ví dụ 3proxy, SSH), không tự thay đổi congestion control của các máy LAN được NAT qua router.

---

## 6. Khóa TTL Tầng Kernel
- File: `/etc/nftables.d/20-ttl-lock.nft`.
- Tự động chuẩn hóa IPv4 TTL = 64 và IPv6 Hop Limit = 64 được giới hạn riêng cho interface WAN (`oifname "lan1"`), không làm ảnh hưởng traffic LAN và Tailscale.

## 7. Hardening và Dọn Dẹp Sau Audit
- Đã xóa rule WAN `Allow-3proxy`; proxy chỉ dùng qua Tailscale/LAN.
- Đã tắt full-cone NAT vì không có nhu cầu gaming/NAT traversal cụ thể.
- Đã gỡ các include firewall Zerotier/OpenClash không hoạt động để `fw4 check` sạch cảnh báo.
- Tailscale đã trả về procd quản lý bằng nftables; xóa route/IP thủ công trong `rc.local` và hotplug.
- Đã tắt tự khởi động (autostart) các dịch vụ nhàn rỗi chưa có nhu cầu dùng: 3proxy mặc định, natmap, openclash, p910nd, ksmbd, wsdd2.
- `dns_redirect` toàn cục đã tắt; cưỡng ép DNS toàn mạng chỉ nên thêm bằng rule giới hạn source zone LAN.
- LuCI/AdGuard/SSH chỉ truy cập qua LAN/Tailscale; WAN input tiếp tục `REJECT`.
---

## 8. Các công cụ quản trị khác

---

- **Policy Based Routing (`pbr`)**: đã cài nhưng đang tắt; bật sau khi có policy rõ ràng.
- **NLBWMON (`nlbwmon`)**: đang chạy; hardware offload có thể làm thiếu thống kê một số luồng.
- **Wake-on-LAN (`luci-app-wol`)**: đánh thức PC từ LAN/Tailscale.
- **NATMap (`natmap`)**: đã cài nhưng không có instance; ưu tiên Tailscale hơn expose dịch vụ công khai.
