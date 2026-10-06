# Kế Hoạch Nạp Firmware ImmortalWrt & Nhân Bản Cấu Hình (Router 2)
**Thiết bị đích**: Nokia Bell XG-040G-MD (Airoha AN7581 / SkyHigh SPI-NAND 256MB)

---

## I. Đánh Giá Công Cụ `airoha-router-ursusflasher`

Dự án `airoha-router-ursusflasher` (từ Medvedolog) được thiết kế chuyên biệt cho đúng dòng phần cứng **Nokia Bell XG-040G-MD / MF (Airoha AN7581/AN7583)**. Phân tích mã nguồn và các file nhị phân trong thư mục `tools/airoha-router-ursusflasher`:

### 1. Những điểm hỗ trợ vượt trội:
1. **Trang bị sẵn Bootloader cứu hộ `UrsusBoot` (U-Boot v2026.07)**:
   - Thay thế bootloader gốc bằng UrsusBoot có tích hợp **Web Failsafe Recovery** tại `http://192.168.1.1`.
   - Chỉ cần nhấn giữ nút **Reset** (2 nháy ngắn + 3 nháy dài đèn đỏ đến khi đèn đỏ đứng), router sẽ tự vào Web Recovery để nạp lại firmware trong trình duyệt kể cả khi hệ điều hành bị hỏng hoàn toàn.
2. **Cơ chế chuyển đổi an toàn (A/B Dual-Slot "Pregnant Transition")**:
   - Không ghi đè ẩu vào toàn bộ Flash ngay lập tức.
   - Sử dụng cơ chế A/B có sẵn của Nokia (ghi thử nghiệm vào SLOT 2 trước). Nếu boot không thành công trong 15 lần khởi động, bootloader tự động quay về firmware gốc ở SLOT 1.
3. **Bảo tồn toàn vẹn định danh gốc (Identity Protection)**:
   - Tự động trích xuất và bảo toàn các phân vùng độc nhất của từng máy: `ri` (chứa địa chỉ MAC gốc và Serial), `bosa` (thông số cân chỉnh laser của module quang), `romfile`.
4. **Chuyển đổi phân vùng sang chuẩn UBI (Target Layout)**:
   - Chuẩn hóa layout Flash sang UBI giống hệt như Router 1 hiện tại (`bootloader`, `env`, `ubi` chứa kernel + rootfs squashfs).

---

## II. Các Bước Triển Khai Chi Tiết

### Giai đoạn 1: Chuẩn bị & Bảo hiểm (ĐÃ HOÀN THÀNH 100%)
- [x] Lấy được quyền Root `#` trên Router 2 qua Telnet (`user` / `h8277a*3` -> `su user_ftp`).
- [x] Dump toàn bộ các phân vùng gốc về thư mục `./backup_router2_stock/`:
  - `mtd0_bootloader.bin` (512 KB)
  - `mtd1_romfile.bin` (256 KB)
  - `mtd6_bosa.bin` (256 KB - Calibration quang)
  - `mtd7_ri.bin` (256 KB - MAC & Serial)
  - `mtd8_flag.bin` & `mtd9_flagback.bin` (512 KB - A/B flags)
  - `mtd2_kernel.bin` & `mtd3_rootfs.bin` (42.5 MB - Hệ điều hành gốc)
  - `mtd10_config.bin` (10 MB)

---

### Giai đoạn 2: Chuẩn bị Môi trường Máy tính
- [ ] Tạm thời tắt Wi-Fi hoặc các VPN trên PC trong lúc nạp để đường truyền `192.168.1.1` kết nối thẳng 1-1 vào Router 2 qua card mạng dây `Ethernet 2` (cắm cổng LAN 2 hoặc LAN 3 của Router 2).
- [ ] Đặt IP tĩnh tạm thời cho card `Ethernet 2`:
  - IP: `192.168.1.2` (hoặc `192.168.1.3`)
  - Subnet Mask: `255.255.255.0`
  - Gateway: `192.168.1.1`

---

### Giai đoạn 3: Nạp Bootloader UrsusBoot & Chuyển đổi sang ImmortalWrt UBI
*(Yêu cầu người dùng duyệt trước khi bấm chạy)*
- [ ] Chạy script tự động `START_ONECLICK.cmd` hoặc `START_EXPERT.cmd` từ thư mục `tools/airoha-router-ursusflasher`:
  1. Script kết nối Telnet vào Router 2 với root credential đã biết.
  2. Nạp UrsusBoot (BL2 Preloader + FIP U-Boot v2026.07).
  3. Format phân vùng UBI chuẩn cho Airoha AN7581.
  4. Đẩy bản build ImmortalWrt `squashfs-sysupgrade` vào volume UBI.
  5. Khởi động lại router vào hệ điều hành mới.

---

### Giai đoạn 4: Đồng bộ Cấu hình Y Hệt Router 1
Sau khi Router 2 khởi động vào ImmortalWrt:
- [ ] Đổi dải LAN sang `192.168.10.1` (tránh xung đột với modem nhà mạng).
- [ ] Chạy lệnh deploy từ repo:
  ```bash
  ./scripts/deploy.sh 192.168.10.1
  ```
- [ ] Cấu hình áp dụng tự động gồm:
  1. **3proxy (resproxy)**: Chạy 3 cổng 10001, 10002, 10003.
  2. **Chuỗi DNS**: dnsmasq (53) -> AdGuard Home (5335) -> SmartDNS (6053).
  3. **Tối ưu Kernel**: BBR congestion control + FQ qdisc + ZRAM 256MB.
  4. **Firewall**: Khóa TTL 64 tầng kernel (`20-ttl-lock.nft`).
  5. **Tailscale**: Đăng nhập node Tailscale mới để cấp IP riêng cho Router 2.

---

## III. Cơ Chế Xử Lý Khi Có Sự Cố (Emergency Brick Recovery)

1. **Sự cố mất điện hoặc lỗi giữa chừng**:
   - Vì đã có UrsusBoot trong NAND: Giữ nút **Reset** lúc cắm điện (2 nháy ngắn, 3 nháy dài đèn đỏ) -> Truy cập `http://192.168.1.1` từ trình duyệt web -> Nạp lại bất kỳ file `.bin` hay `.itb` nào mà không cần lệnh dòng lệnh.
2. **Trường hợp lỗi nặng nhất (Hỏng bootloader)**:
   - File `mtd0_bootloader.bin` gốc và toàn bộ phân vùng đã lưu trong máy tính tại `backup_router2_stock/`.
   - Có thể dùng dây USB-to-TTL cắm vào 3 chân UART trên mainboard nạp lại qua XMODEM/BootROM trong 2 phút.
