---
name: nokia-xg040g-md-provisioning-master
description: "Master coordinator skill to inspect, root, backup, flash UrsusBoot and OpenWrt UBI, and deploy production residential services on Nokia Bell XG-040G-MD routers."
---

# Nokia Bell XG-040G-MD Provisioning Master Skill

Dùng khi tiếp nhận và thiết lập một router **Nokia Bell XG-040G-MD (Airoha AN7581)** mới, từ bản gốc nhà mạng (Stock China Mobile) cho đến khi thành node OpenWrt hoàn chỉnh với đầy đủ dịch vụ (3proxy, Tailscale, SmartDNS, AdGuard Home, Khóa TTL 64).

## Nguyên Tắc Cốt Lõi (Non-Negotiable Invariants)
1. **Bảo hiểm trước khi ghi**: Tuyệt đối không thực hiện bất kỳ lệnh ghi Flash nào trước khi đã sao lưu đầy đủ 9 phân vùng MTD gốc (đặc biệt là `bosa` và `ri`) về máy tính.
2. **Kiểm tra 2 chiều (Readback Verification)**: Sau khi ghi `mtd0`, bắt buộc phải đọc ngược lại từ Flash và so sánh mã băm SHA256. Nếu sai lệch, **không được reboot**, phải khôi phục file gốc ngay trong phiên Telnet.
3. **Chống trùng định danh (No MAC Collision)**: Mỗi router phải giữ đúng địa chỉ MAC phần cứng của riêng mình. Không clone đè MAC của router khác lên cổng WAN/LAN.
4. **Không làm rớt mạng máy tính**: Mạng dây kết nối với router mới tuyệt đối **không được gán Default Gateway** để toàn bộ lưu lượng internet/AI của PC đi qua Wi-Fi mà không bị gián đoạn.

---

## Quy Trình Điều Phối 5 Giai Đoạn

### Giai đoạn 1: Khảo sát hiện trạng (Environment & State Discovery)
1. **Kiểm tra kết nối vật lý**:
   - Cổng 1 (2.5GbE): Cổng WAN lấy internet từ modem.
   - Cổng 2, 3, 4 (1GbE): Cổng LAN nội bộ.
2. **Nhận diện trạng thái phần mềm**:
   - Nếu cổng 23 (Telnet) mở và phản hồi `Login:` $\rightarrow$ **Nokia Stock China Mobile** $\rightarrow$ Chuyển sang **Giai đoạn 2**.
   - Nếu cổng 80 phản hồi `UrsusBoot` $\rightarrow$ **UrsusBoot Recovery** $\rightarrow$ Chuyển sang **Giai đoạn 4**.
   - Nếu cổng 22 (SSH) mở và phản hồi OpenWrt $\rightarrow$ **OpenWrt hiện hữu** $\rightarrow$ Chuyển sang **Giai đoạn 5**.

### Giai đoạn 2: Khai thác Stock & Sao lưu 9 phân vùng bảo hiểm
Tham chiếu sub-skill: `skill://xg040g-md-stock-root-and-backup`
1. Đăng nhập Telnet port 23 bằng user `user` và mật khẩu in dưới tem đáy.
2. Leo quyền root: `su user_ftp` với mật khẩu tem đáy $\rightarrow$ Nhận shell `#` (`uid=0`).
3. Khởi chạy listener trên PC và trích xuất 9 phân vùng gốc:
   - `mtd0_bootloader.bin`, `mtd1_romfile.bin`, `mtd2_kernel.bin`, `mtd3_rootfs.bin`, `mtd6_bosa.bin`, `mtd7_ri.bin`, `mtd8_flag.bin`, `mtd9_flagback.bin`, `mtd10_config.bin`.
4. Xác thực kích thước và mã băm từng file trên PC.

### Giai đoạn 3: Nạp Bootloader UrsusBoot t71 (Có Web Failsafe)
Tham chiếu sub-skill: `skill://xg040g-md-ursusboot-ubi-flashing`
1. Lắp ráp `candidate_mtd0.bin` (512 KiB):
   - 0x000000..0x0007FF: Giữ nguyên BootROM header của router mục tiêu.
   - 0x000800..0x07B7FF: UrsusBoot FIP (U-Boot v2026.07 hỗ trợ SkyHigh & Fudan Micro).
   - 0x07C000..0x07FFFF: Giữ nguyên `tcboot` environment gốc.
2. Đẩy file vào `/tmp/ursusboot_mtd0.bin` trên router và kiểm tra SHA256.
3. Ghi mtd0 bằng `/sbin/mtd_debug write ...` và chạy Readback Check.

### Giai đoạn 4: Chuyển đổi sang OpenWrt UBI qua Web Recovery
1. Khởi động lại router và nhấn giữ nút **Reset**:
   - Đếm nhịp đèn đỏ: 2 nháy ngắn $\rightarrow$ 3 nháy dài $\rightarrow$ Đèn đỏ sáng đứng $\rightarrow$ Thả tay.
2. Truy cập Web Recovery tại `http://192.168.1.1` (hoặc qua SSH tunnel).
3. Đẩy `ubi-preloader.bin` và `openwrt-ubi-squashfs-sysupgrade.itb` vào RAM qua API `/api/firmware-begin`.
4. Gọi POST `/api/install-ubi` để format UBI, ghi 7 volumes và reboot vào OpenWrt.

### Giai đoạn 5: Cấu hình mạng & Triển khai dịch vụ (Multi-Node Policy)
Tham chiếu sub-skill: `skill://xg040g-md-dual-node-network-policy`
1. Gán địa chỉ MAC gốc của máy vào `/etc/config/network` (đọc từ `mtd7_ri.bin` hoặc tem đáy).
2. Thiết lập IP mạng nội bộ riêng (Node 1 = `192.168.10.1`, Node 2 = `192.168.20.1`).
3. Mở firewall WAN cho LuCI Web (80/443), SSH (22), AdGuard (3000).
4. Cài đặt các gói phụ trợ: `apk add kmod-tun ca-bundle`.
5. Khởi động chuỗi dịch vụ:
   - `3proxy` (resproxy): Cổng 10001, 10002, 10003 gắn với IP Tailscale của máy.
   - `SmartDNS`: Cổng 6053 (DoT mã hóa).
   - `AdGuard Home`: Web UI 3000, lọc DNS 5335.
   - `Tailscale`: Kích hoạt đăng nhập và nhận IP VPN riêng.
