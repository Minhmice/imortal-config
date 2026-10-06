# Thiết Kế Hệ Thống Cài Đặt & Nhân Bản Router Nokia Bell XG-040G-MD

- **Ngày tạo**: 2026-10-07
- **Mục tiêu**: Cung cấp bộ công cụ tự động hóa dạng OMP Skills (`.omp/skills/`) và tài liệu hướng dẫn thủ công hoàn chỉnh (`MANUAL_PROVISIONING_GUIDE.md`) kèm script hỗ trợ để thiết lập bất kỳ router Nokia Bell XG-040G-MD mới nào thành một node OpenWrt chuẩn hóa với đầy đủ dịch vụ (3proxy, Tailscale, SmartDNS, AdGuard Home, Khóa TTL) và an toàn tuyệt đối chống brick.

---

## 1. Bối Cảnh & Mục Tiêu Kỹ Thuật

### 1.1. Phần cứng mục tiêu
- **Thiết bị**: Nokia Bell XG-040G-MD (biến thể China Mobile / Custom Carrier).
- **SoC**: Airoha (MediaTek) AN7581DT (4 nhân Cortex-A53, NPU định tuyến 2.5G).
- **Bộ nhớ**: 512 MiB DDR3/4 RAM.
- **Bộ nhớ Flash**: 256 MiB SPI-NAND (SkyHigh S35ML02G300 hoặc Fudan Micro FM25G02B).
- **Cổng kết nối**: 1 cổng 2.5GbE (cổng 1 - WAN) + 3 cổng 1GbE (cổng 2, 3, 4 - LAN).

### 1.2. Thách thức kỹ thuật đã kiểm chứng thực tế
1. **Bảo mật stock carrier**: Firmware gốc khóa cổng Telnet root trực tiếp; chỉ cho phép tài khoản `user` với mật khẩu riêng in dưới tem đáy; phải leo quyền qua tài khoản dịch vụ `su user_ftp` để đạt UID 0 (`root`). Nhập sai mật khẩu quá 3 lần bị khóa 300s.
2. **Nguy cơ brick phần cứng**: Ghi sai bootloader hoặc không bảo toàn 2048 bytes BootROM prefix / calibration quang (`bosa`, `ri`) sẽ làm hỏng thiết bị vĩnh viễn hoặc mất sóng quang GPON/XG-PON.
3. **Xung đột khi chạy nhiều node (Dual-node collision)**:
   - Nếu nhân bản cấu hình nguyên bản, cả 2 router sẽ mang cùng một địa chỉ MAC WAN/LAN $\rightarrow$ Gây xung đột MAC (MAC flapping) trên modem nhà mạng, khiến router thứ 2 bị ngắt kết nối.
   - Trùng dải subnet nội bộ (`192.168.1.x` hoặc `192.168.10.x`) làm hỏng bảng định tuyến của mạng gia đình.
   - Cổng WAN mặc định của OpenWrt chặn toàn bộ cổng Web (80/443), SSH (22), AdGuard (3000) $\rightarrow$ Người dùng không thể truy cập từ Wi-Fi gia đình nếu không mở firewall WAN.

---

## 2. Kiến Trúc Bộ Kỹ Năng (Skill Architecture)

Hệ thống được tổ chức thành 1 Skill điều phối chính và 3 Sub-skill chuyên sâu đặt tại `.omp/skills/`:

```text
imortal-config/
├── .omp/skills/
│   ├── nokia-xg040g-md-provisioning-master/
│   │   └── SKILL.md                 # Điều phối 5 giai đoạn, kiểm tra trạng thái máy, gọi sub-skills
│   ├── xg040g-md-stock-root-and-backup/
│   │   └── SKILL.md                 # Khai thác Telnet stock, UID 0, trích xuất 9 phân vùng MTD
│   ├── xg040g-md-ursusboot-ubi-flashing/
│   │   └── SKILL.md                 # Ghép mtd0, nạp UrsusBoot t71, Web Recovery & 7 volume UBI
│   └── xg040g-md-dual-node-network-policy/
│       └── SKILL.md                 # Khắc phục MAC duplicate, subnet 192.168.20.1, WAN rules & 3proxy
│
├── MANUAL_PROVISIONING_GUIDE.md     # Cẩm nang hướng dẫn người dùng tự thao tác từng lệnh
│
└── scripts/
    ├── backup-stock-partitions.sh   # Script tự động kéo 9 phân vùng MTD qua mạng về PC
    ├── flash-ursusboot-candidate.sh # Script ghép mtd0 và nạp có readback check
    └── deploy-node-services.sh      # Script cấu hình dịch vụ, MAC, IP và firewall cho node mới
```

---

## 3. Chi Tiết Các Hợp Phần

### 3.1. Skill Chính: `nokia-xg040g-md-provisioning-master`
- **Nhiệm vụ**: Đóng vai trò bộ não điều phối.
- **Quy trình 5 giai đoạn**:
  1. **Khảo sát ban đầu**: Quét cổng, xác định router đang ở Stock China Mobile hay OpenWrt, kiểm tra kết nối vật lý.
  2. **An toàn & Sao lưu**: Yêu cầu gọi sub-skill `xg040g-md-stock-root-and-backup` để tạo 9 file backup trước bất kỳ lệnh ghi nào.
  3. **Nạp Bootloader Cứu Hộ**: Gọi sub-skill `xg040g-md-ursusboot-ubi-flashing` để nạp UrsusBoot có Web Recovery.
  4. **Nạp Hệ Điều Hành OpenWrt UBI**: Kích hoạt Web Recovery qua nút Reset và flash bản UBI FIT image.
  5. **Cấu hình & Nhân bản Dịch vụ**: Gọi sub-skill `xg040g-md-dual-node-network-policy` để gán MAC độc lập, đổi IP LAN, mở WAN firewall và khởi động 3proxy/Tailscale/SmartDNS/AdGuard.

### 3.2. Sub-skill 1: `xg040g-md-stock-root-and-backup`
- **Kỹ thuật leo quyền**:
  - Telnet port 23: User `user`, mật khẩu đọc từ tem đáy thiết bị.
  - Chuyển sang root: `su user_ftp`, nhập lại mật khẩu tem $\rightarrow$ Đạt shell `#` (`uid=0(root)`).
  - Khắc phục timeout 300s: Nếu thử sai quá 3 lần, hướng dẫn rút nguồn cắm lại để xóa bộ đếm trong RAM.
- **Trích xuất 9 phân vùng MTD qua mạng**:
  - Dùng lệnh `cat /dev/mtdXro | nc <PC_IP> <PORT>` truyền trực tiếp về máy tính/Router 1.
  - Danh sách 9 phân vùng bắt buộc: `mtd0_bootloader.bin`, `mtd1_romfile.bin`, `mtd2_kernel.bin`, `mtd3_rootfs.bin`, `mtd6_bosa.bin` (quang), `mtd7_ri.bin` (MAC/Serial), `mtd8_flag.bin`, `mtd9_flagback.bin`, `mtd10_config.bin`.
  - Kiểm tra dung lượng và tính toàn vẹn của từng file trước khi chuyển bước.

### 3.3. Sub-skill 2: `xg040g-md-ursusboot-ubi-flashing`
- **Ghép candidate `mtd0` (512 KiB)**:
  - 0x000000..0x0007FF (2048 bytes): Giữ nguyên BootROM header gốc của máy mục tiêu.
  - 0x000800..0x07B7FF (503.808 bytes): Thay thế bằng UrsusBoot FIP (U-Boot v2026.07 tích hợp patch Fudan Micro & SkyHigh).
  - 0x07C000..0x07FFFF (16 KiB): Giữ nguyên `tcboot` environment gốc.
- **Ghi an toàn & Readback Verification**:
  - Dùng `/sbin/mtd_debug erase /dev/mtd0 0 524288` và `/sbin/mtd_debug write ...`.
  - Ngay sau khi ghi: Chạy `dd if=/dev/mtd0 ... | sha256sum` đọc ngược lại từ Flash.
  - **Chốt chặn an toàn**: Chỉ reboot khi SHA256 đọc ngược lại trùng 100% với candidate. Nếu lệch, nạp lại bản backup gốc ngay trong phiên Telnet hiện tại.
- **Kích hoạt Web Recovery qua nút Reset**:
  - Cắm nguồn, đợi 1 giây, giữ nút Reset.
  - Quan sát: 2 nháy ngắn đỏ $\rightarrow$ 3 nháy dài đỏ $\rightarrow$ Đèn đỏ đứng $\rightarrow$ Thả tay.
  - Web Recovery mở tại `http://192.168.1.1` (API `/api/status`, `/api/install-ubi`).
- **Nạp OpenWrt UBI Image**:
  - Đẩy `openwrt-airoha-an7581-nokia_xg-040g-md-ubi-preloader.bin` (113 KB) và `openwrt-airoha-an7581-nokia_xg-040g-md-ubi-squashfs-sysupgrade.itb` (10.3 MB) vào RAM.
  - Kích hoạt format và nạp 7 volumes UBI (`ubootenv`, `ubootenv2`, `bosa`, `ri`, `fip`, `fit`, `rootfs_data`).

### 3.4. Sub-skill 3: `xg040g-md-dual-node-network-policy`
- **Chống xung đột phần cứng (Hardware anti-collision)**:
  - Trích xuất địa chỉ MAC gốc của máy từ chuỗi `NBELFCEF...` trong `mtd7_ri.bin` hoặc nhãn máy (ví dụ `90:03:2E:64:16:24` cho LAN, `...25` cho WAN).
  - Gán đúng MAC riêng biệt vào `/etc/config/network`, xóa bỏ hoàn toàn các cấu hình đè MAC của Node 1.
  - Phân bổ dải LAN độc lập: Node 1 dùng `192.168.10.1/24`, Node 2 dùng `192.168.20.1/24`.
- **Chính sách tường lửa WAN**:
  - Mở cổng `80/443` (LuCI), `22` (SSH Dropbear), `3000` (AdGuard Home Web) từ zone WAN để máy tính trong mạng gia đình truy cập trực tiếp qua IP modem cấp.
- **Chính sách dịch vụ**:
  - `3proxy`: Lắng nghe trên IP Tailscale của máy (`-i<TAILSCALE_IP>`), không dùng `-e` gán cứng IP nguồn WAN để tránh lỗi gán sai IP DHCP.
  - `SmartDNS`: Chạy port `6053`, sử dụng DoT Cloudflare/Google, tắt plain UDP để chống rò rỉ DNS.
  - `AdGuard Home`: Chạy port `3000` (Web) và `5335` (DNS filter), khởi động qua procd với user `adguardhome`.
  - `Tailscale`: Cài `kmod-tun`, kích hoạt `tailscale login` và cấp IP Tailscale riêng cho node.

---

## 4. Tài Liệu Hướng Dẫn Thủ Công (`MANUAL_PROVISIONING_GUIDE.md`)

Tài liệu được viết theo ngôn ngữ thực hành rõ ràng, chia làm 6 bước:
1. **Chuẩn bị môi trường**: Cách cắm dây mạng 1-1, đọc mật khẩu tem đáy, cài đặt IP tĩnh PC.
2. **Khai thác Telnet & Sao lưu Flash**: Lệnh Telnet, leo quyền root, script PowerShell 1-dòng mở listener nhận 9 file backup.
3. **Ghép file Bootloader & Ghi mtd0**: Hướng dẫn dùng script Python hoặc file nhị phân có sẵn, lệnh ghi `mtd_debug` và kiểm tra SHA256.
4. **Thao tác nút Reset & Nạp ROM Web**: Hướng dẫn nhìn đèn LED và dùng trình duyệt nạp ROM qua giao diện Web Recovery.
5. **Cấu hình dịch vụ & Đổi IP**: Lệnh đổi subnet, đổi MAC, cấu hình 3proxy, Tailscale, SmartDNS.
6. **Xử lý sự cố & Cứu Brick khẩn cấp**: Cách đưa máy về U-Boot Web Failsafe khi lỗi ROM, hoặc cách nạp lại mtd0 gốc qua UART nếu hỏng bootloader.

---

## 5. Tiêu Chuẩn Nghiệm Thu (Acceptance Criteria)

1. Mọi skill trong `.omp/skills/` tuân thủ đúng định dạng Markdown của OMP Skill, có description rõ ràng để agent tự động nhận diện.
2. Tài liệu `MANUAL_PROVISIONING_GUIDE.md` có đầy đủ câu lệnh copy-paste thực thi được trên Windows PowerShell và Linux Shell.
3. Các script trong `scripts/` chạy độc lập, có cơ chế kiểm tra lỗi trước khi thực thi lệnh ghi Flash.
4. Hệ thống đảm bảo 100% router mới được cài đặt sẽ có Web Failsafe chống brick, MAC riêng biệt không xung đột, và đầy đủ bộ 4 dịch vụ hoạt động.
