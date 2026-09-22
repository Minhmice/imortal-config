# Tính năng đã cài đặt & Tối ưu trên ImmortalWrt (Nokia Bell XG-040G-MD)

Tài liệu chi tiết cấu hình và tối ưu hóa router Airoha AN7581.

---

## 1. 3proxy + Tailscale (Remote Access)
- Cấu hình: `/etc/3proxy-residential.cfg`.
- 3proxy chạy trên port `10001`, `10002`, `10003`; Tailscale cấp IP `100.71.252.27`.
- Ba port cùng đi ra qua WAN `192.168.1.40`, chia sẻ cùng public egress IP.
- Dropbear SSH đã bỏ giới hạn interface `lan`, cho phép quản trị an toàn từ xa qua Tailscale (`ssh root@100.71.252.27`).
- Định dạng client:
  ```text
  socks5h://<user>:<password>@100.71.252.27:<port>
  ```

---

## 2. Phần cứng Định Tuyến Tốc Độ Cao (Flow Offloading / Hardware NAT)
- Cấu hình: `/etc/config/firewall` (`flow_offloading='1'`, `flow_offloading_hw='1'`).
- Tình trạng: Flowtable phần cứng (`flags offload`) đã hoạt động trực tiếp trên các cổng `lan1` (2.5G), `lan2`, `lan3`, `lan4`.
- Tác dụng: Khi truyền tải lưu lượng lớn (download 2.5Gbps, kéo torrent, truyền file LAN), gói tin được switch phần cứng định tuyến trực tiếp mà không tốn chu kỳ CPU, giữ tải CPU ở mức < 1%.

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
  - Tên miền quảng cáo (`doubleclick.net`) bị chặn về `0.0.0.0`.
  - Tên miền thông thường (`google.com`) được phân giải song song với độ trễ thấp nhất.
- Giao diện quản trị AdGuard Home: `http://100.71.252.27:3000` (hoặc `http://192.168.2.1:3000`).

---

## 4. Tối ưu ZRAM Swap (Thuật toán ZSTD)
- Cấu hình:
  - `system.@system[0].zram_comp_algo='zstd'`
  - `system.@system[0].zram_size_mb='256'`
  - `vm.swappiness = 100` trong `/etc/sysctl.d/15-zram-swap.conf`
- Tác dụng: Tăng kích thước swap nén lên 256MB dùng thuật toán `zstd` có tỷ lệ nén cao, mở rộng dung lượng bộ nhớ khả dụng của router để chạy ổn định đồng thời 3proxy, AdGuard Home, SmartDNS và OpenClash.

---

## 5. TCP BBR Congestion Control
- Kernel module `kmod-tcp-bbr` được kích hoạt và gán mặc định trong `/etc/sysctl.d/12-tcp-bbr.conf`.
- Tối ưu hóa throughput cho các kết nối xuyên quốc gia, giảm packet loss và tối ưu độ trễ cho Proxy / VPN.

---

## 6. Khóa TTL Tầng Kernel
- File: `/etc/nftables.d/20-ttl-lock.nft`.
- Tự động chuẩn hóa IPv4 TTL = 64 và IPv6 Hop Limit = 64 tại hook postrouting.

---

## 7. Các công cụ quản trị khác
- **Policy Based Routing (`pbr`)**: Định tuyến theo thiết bị / domain.
- **NLBWMON (`nlbwmon`)**: Giám sát lưu lượng mạng chi tiết từng IP trong LuCI.
- **Wake-on-LAN (`luci-app-wol`)**: Đánh thức PC từ xa qua mạng nội bộ hoặc Tailscale.
- **NATMap (`natmap`)**: Hỗ trợ đục lỗ CGNAT khi cần mở port.
