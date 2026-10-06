---
name: xg040g-md-dual-node-network-policy
description: "Network architecture rules and configuration policies for deploying multiple Nokia XG-040G-MD routers on the same ISP modem without MAC or subnet collisions."
---

# Nokia Bell XG-040G-MD Dual-Node Network Policy Skill

Dùng khi triển khai thêm một hoặc nhiều router **Nokia Bell XG-040G-MD** cắm chung vào 1 modem nhà mạng (Modem Viettel/VNPT/FPT) nhằm đảm bảo hệ thống không bị xung đột phần cứng, rớt mạng hoặc mất quyền truy cập.

## 1. Chính Sách Địa Chỉ MAC (Hardware Anti-Collision)

### 1.1. Hiện tượng xung đột MAC (MAC Flapping)
Nếu clone nguyên bản file `/etc/config/network` từ Router 1 sang Router 2, cả 2 router sẽ mang cùng một địa chỉ MAC WAN `04:56:65:09:FE:8F`. Khi cắm chung vào modem Viettel:
- Switch của modem thấy 2 cổng mạng khác nhau cùng gửi frame chứa 1 địa chỉ MAC duy nhất.
- Bảng MAC forwarding table của modem bị đảo liên tục (MAC flapping) $\rightarrow$ Modem ngắt mạng, từ chối cấp IP cho Router 2 hoặc gây rớt mạng Router 1.

### 1.2. Quy tắc gán MAC độc lập
Mỗi thiết bị phải giữ đúng MAC xuất xưởng của riêng nó.
- **Cách tìm MAC gốc**:
  1. Đọc nhãn in ở mặt đáy router.
  2. Hoặc tìm chuỗi hex trong file `mtd7_ri.bin` gốc đã sao lưu:
     Chuỗi `NBELFCEF...` mang theo block MAC xuất xưởng (ví dụ `90:03:2E:64:16:24` cho LAN, `90:03:2E:64:16:25` cho WAN).
- **Cấu hình chuẩn trong `/etc/config/network`**:
  ```uci
  # Gán đúng MAC riêng của thiết bị:
  config device
      option name 'br-lan'
      option type 'bridge'
      list ports 'lan2'
      list ports 'lan3'
      list ports 'lan4'
      option macaddr '<MAC_LAN_CỦA_MÁY>'

  config device 'lan1_mac_fix'
      option name 'lan1'
      option macaddr '<MAC_WAN_CỦA_MÁY>'
  ```

---

## 2. Phân Bổ Dải Mạng Nội Bộ (Subnet Allocation)

Để không bao giờ bị đè route với modem chính (`192.168.1.1`):
- **Modem nhà mạng (Viettel)**: `192.168.1.0/24` (Cấp IP WAN cho các router).
- **Node 1 (`immortalwrt`)**:
  - LAN: `192.168.10.1/24`
  - Tailscale: `100.71.252.27`
- **Node 2 (`immortalwrt2`)**:
  - LAN: `192.168.20.1/24`
  - Tailscale: `100.68.191.34`
- **Node N tiếp theo**: Tăng dần `192.168.30.1`, `192.168.40.1`...

---

## 3. Mở Tường Lửa Cho Mạng Nhà (WAN Zone Access)

Mặc định OpenWrt chặn toàn bộ cổng vào từ phía WAN (`input 'REJECT'`). Khi cắm router vào modem nhà mạng, máy tính/điện thoại bắt Wi-Fi của modem nằm ở phía WAN của router.
Để truy cập được giao diện quản trị từ Wi-Fi gia đình mà không cần cắm dây LAN:

Chạy các lệnh mở firewall:
```sh
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-WAN-LuCI'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='80 443'
uci set firewall.@rule[-1].target='ACCEPT'

uci add firewall rule
uci set firewall.@rule[-1].name='Allow-WAN-SSH'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='22'
uci set firewall.@rule[-1].target='ACCEPT'

uci add firewall rule
uci set firewall.@rule[-1].name='Allow-WAN-AdGuard'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='3000'
uci set firewall.@rule[-1].target='ACCEPT'

uci commit firewall
/etc/init.d/firewall reload
```

---

## 4. Cấu Hình Bộ Dịch Vụ Dân Cư (Residential Services)

### 4.1. 3proxy (`resproxy`)
- File cấu hình: `/etc/3proxy-residential.cfg` (phân quyền `chmod 600`).
- **Quy tắc**: Lắng nghe trên IP Tailscale của router, **không dùng `-e` gán cứng IP nguồn**:
  ```text
  nscache 65536
  timeouts 1 5 30 60 180 1800 15 60
  users proxy1:CL:<PASS1> proxy2:CL:<PASS2> proxy3:CL:<PASS3>
  auth strong

  allow proxy1
  socks -p10001 -i<TAILSCALE_IP>
  flush

  allow proxy2
  socks -p10002 -i<TAILSCALE_IP>
  flush

  allow proxy3
  socks -p10003 -i<TAILSCALE_IP>
  flush
  ```
  *(Khi không có tham số `-e`, 3proxy tự động đi ra ngoài bằng bất kỳ IP WAN nào do modem cấp DHCP).*

### 4.2. Chuỗi DNS An Toàn (Chống rò rỉ ISP)
- **dnsmasq** (Port 53): Chuyển tiếp truy vấn sang `127.0.0.1#5335` (AdGuard Home).
- **AdGuard Home** (Port 5335 & Web 3000): Lọc domain quảng cáo/mã độc, chuyển tiếp sang `127.0.0.1:6053` (SmartDNS).
- **SmartDNS** (Port 6053): Tắt toàn bộ server plain UDP, chỉ giữ DoT (`dns.google`, `cloudflare-dns.com` có TLS verification).

### 4.3. Tailscale
- Cài đặt driver TUN và SSL:
  ```sh
  apk update && apk add kmod-tun ca-bundle
  ```
- Khởi động:
  ```sh
  /etc/init.d/tailscale restart
  tailscale login
  ```
- Node nhận IP trong dải `100.x.y.z`, luôn luôn truy cập được từ xa qua WireGuard.
