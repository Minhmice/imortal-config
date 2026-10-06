# Nokia Bell XG-040G-MD Provisioning System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng bộ skill OMP chuẩn hóa (`.omp/skills/`), tài liệu hướng dẫn cài đặt thủ công (`MANUAL_PROVISIONING_GUIDE.md`) và bộ script tự động hóa trong `scripts/` để thiết lập router Nokia Bell XG-040G-MD mới thành node OpenWrt an toàn tuyệt đối chống brick.

**Architecture:** Tổ chức hệ thống gồm 1 skill điều phối chính (`nokia-xg040g-md-provisioning-master`), 3 sub-skills kiến thức kỹ thuật (`stock-root-and-backup`, `ursusboot-ubi-flashing`, `dual-node-network-policy`), 1 tài liệu thực hành thủ công đầy đủ lệnh copy-paste và 3 script bash hỗ trợ tự động hóa các tác vụ lặp lại.

**Tech Stack:** OMP Skills (Markdown/YAML frontmatter), POSIX Shell/Bash, PowerShell Core/Desktop, Python 3.12+, U-Boot v2026.07 (UrsusBoot), OpenWrt fw4 (nftables).

**Spec:** `docs/superpowers/specs/2026-10-07-nokia-xg040g-md-provisioning-system-design.md`

## Global Constraints

- Mọi Skill phải đặt trong `.omp/skills/<skill-name>/SKILL.md` và tuân thủ định dạng Markdown tiêu chuẩn của OMP.
- Tên skill dùng kebab-case: `nokia-xg040g-md-provisioning-master`, `xg040g-md-stock-root-and-backup`, `xg040g-md-ursusboot-ubi-flashing`, `xg040g-md-dual-node-network-policy`.
- Hướng dẫn thủ công phải có đầy đủ lệnh copy-paste chạy được trên cả Windows PowerShell và Linux/macOS Shell.
- Script tự động phải có cơ chế kiểm tra toàn vẹn mã băm SHA256 trước và sau khi ghi Flash (Readback Verification).
- Giữ nguyên các quyết định kiến trúc: SSH password auth enabled, resproxy chạy thay package 3proxy mặc định, MAC không được trùng lặp giữa các node.

---

### Task 1: Tạo Skill Điều Phối Chính (`nokia-xg040g-md-provisioning-master`)

**Files:**
- Create: `.omp/skills/nokia-xg040g-md-provisioning-master/SKILL.md`

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-10-07-nokia-xg040g-md-provisioning-system-design.md`
- Produces: Workflow checklist 5 giai đoạn cho Agent khi tiếp nhận router Nokia XG-040G-MD mới.

- [ ] **Step 1: Viết nội dung SKILL.md cho skill điều phối chính**
  Soạn thảo `.omp/skills/nokia-xg040g-md-provisioning-master/SKILL.md` bao gồm:
  - Frontmatter: `name`, `description`.
  - Giai đoạn 1: Khảo sát hiện trạng (Stock hay OpenWrt).
  - Giai đoạn 2: Gọi sub-skill sao lưu 9 phân vùng MTD.
  - Giai đoạn 3: Gọi sub-skill nạp UrsusBoot.
  - Giai đoạn 4: Hướng dẫn vào Web Recovery nạp OpenWrt UBI.
  - Giai đoạn 5: Gọi sub-skill cấu hình mạng & triển khai dịch vụ (3proxy, Tailscale, SmartDNS, AdGuard).

- [ ] **Step 2: Kiểm tra cú pháp và liên kết**
  Kiểm tra file đã tạo, đảm bảo không có cú pháp lỗi và đường dẫn tham chiếu chính xác.

- [ ] **Step 3: Commit**
  `git add .omp/skills/nokia-xg040g-md-provisioning-master/SKILL.md`

---

### Task 2: Tạo Sub-skill 1 Khai Thác Stock & Sao Lưu (`xg040g-md-stock-root-and-backup`)

**Files:**
- Create: `.omp/skills/xg040g-md-stock-root-and-backup/SKILL.md`

**Interfaces:**
- Consumes: Kinh nghiệm dump thực tế từ router 2 (`backup_router2_stock/`).
- Produces: Quy trình phá khóa Telnet, xử lý timeout 300s, lệnh kéo 9 phân vùng MTD qua mạng về PC.

- [ ] **Step 1: Viết nội dung SKILL.md cho sub-skill khai thác stock**
  Soạn thảo `.omp/skills/xg040g-md-stock-root-and-backup/SKILL.md`:
  - Khai thác tài khoản `user` và leo quyền `su user_ftp`.
  - Cơ chế bẫy timeout 300s và cách xử lý (rút nguồn cắm lại).
  - Bảng 9 phân vùng MTD cần sao lưu bắt buộc (`mtd0` đến `mtd10`).
  - Lệnh PowerShell TCP listener và lệnh shell `cat /dev/mtdX | nc` kéo file an toàn.
  - Quy trình kiểm tra dung lượng và mã hash SHA256 từng file backup.

- [ ] **Step 2: Kiểm tra tính hoàn thiện**
  Đảm bảo hướng dẫn chi tiết từng byte dung lượng mong đợi của 9 phân vùng.

- [ ] **Step 3: Commit**
  `git add .omp/skills/xg040g-md-stock-root-and-backup/SKILL.md`

---

### Task 3: Tạo Sub-skill 2 Nạp Bootloader Cứu Hộ & OpenWrt UBI (`xg040g-md-ursusboot-ubi-flashing`)

**Files:**
- Create: `.omp/skills/xg040g-md-ursusboot-ubi-flashing/SKILL.md`

**Interfaces:**
- Consumes: Quy trình ghép `candidate_mtd0` và gọi API UrsusBoot Web Recovery.
- Produces: Hướng dẫn nạp bootloader, kiểm tra readback, thao tác nút Reset vào Web Failsafe và flash UBI FIT image.

- [ ] **Step 1: Viết nội dung SKILL.md cho sub-skill nạp UrsusBoot & UBI**
  Soạn thảo `.omp/skills/xg040g-md-ursusboot-ubi-flashing/SKILL.md`:
  - Cấu trúc layout 512 KiB của `mtd0` (2048 bytes BootROM header + UrsusBoot FIP + 16 KB tcboot env).
  - Script python 1-lệnh ghép file candidate.
  - Lệnh ghi an toàn bằng `/sbin/mtd_debug` và bắt buộc đọc ngược lại (readback check).
  - Kỹ thuật quan sát đèn LED khi nhấn Reset: 2 nháy ngắn đỏ $\rightarrow$ 3 nháy dài đỏ $\rightarrow$ Đèn đỏ đứng.
  - Gọi API `/api/install-ubi` để format UBI, ghi 7 volumes và reboot vào OpenWrt.

- [ ] **Step 2: Kiểm tra tính nhất quán**
  Xác minh các offset hex (0x0, 0x800, 0x7C000) và hash sha256 khớp chuẩn.

- [ ] **Step 3: Commit**
  `git add .omp/skills/xg040g-md-ursusboot-ubi-flashing/SKILL.md`

---

### Task 4: Tạo Sub-skill 3 Chính Sách Mạng & Đa Node (`xg040g-md-dual-node-network-policy`)

**Files:**
- Create: `.omp/skills/xg040g-md-dual-node-network-policy/SKILL.md`

**Interfaces:**
- Consumes: Bài học thực tế về trùng MAC WAN/LAN và firewall WAN drop.
- Produces: Quy chuẩn cấu hình mạng khi triển khai node mới song song với node cũ.

- [ ] **Step 1: Viết nội dung SKILL.md cho sub-skill mạng & đa node**
  Soạn thảo `.omp/skills/xg040g-md-dual-node-network-policy/SKILL.md`:
  - Quy tắc phân bổ MAC: Đọc MAC gốc từ tem đáy / `mtd7_ri.bin`, không clone đè MAC của node khác để tránh modem Viettel ngắt kết nối.
  - Quy tắc phân chia Subnet: Node 1 dùng `192.168.10.1`, Node 2 dùng `192.168.20.1`, tránh dải `192.168.1.1` của modem chính.
  - Mở cổng tường lửa WAN cho LuCI (80/443), SSH (22), AdGuard (3000).
  - Cấu hình 3proxy gắn với IP Tailscale riêng của từng node, bỏ bind cứng IP nguồn WAN.
  - Thiết lập chuỗi DNS: dnsmasq (53) $\rightarrow$ AdGuard Home (5335) $\rightarrow$ SmartDNS (6053 DoT).

- [ ] **Step 2: Kiểm tra cấu hình tường lửa và routing**
  Đảm bảo các quy tắc nftables và UCI firewall chính xác.

- [ ] **Step 3: Commit**
  `git add .omp/skills/xg040g-md-dual-node-network-policy/SKILL.md`

---

### Task 5: Tạo Bộ Script Hỗ Trợ Tự Động Hóa (`scripts/`)

**Files:**
- Create: `scripts/backup-stock-partitions.sh`
- Create: `scripts/flash-ursusboot-candidate.sh`
- Create: `scripts/deploy-node-services.sh`

**Interfaces:**
- Consumes: Các lệnh shell tương tác qua SSH/Telnet đã kiểm chứng trong session.
- Produces: 3 script độc lập có thể chạy trực tiếp bằng tham số dòng lệnh.

- [ ] **Step 1: Viết script `scripts/backup-stock-partitions.sh`**
  Script tự động mở listener nhận đủ 9 phân vùng MTD từ router stock và xác thực kích thước từng file.

- [ ] **Step 2: Viết script `scripts/flash-ursusboot-candidate.sh`**
  Script tự động ghép `candidate_mtd0.bin` từ file `mtd0_bootloader.bin` gốc với UrsusBoot FIP, đẩy file lên router và kiểm tra SHA256 sau khi ghi.

- [ ] **Step 3: Viết script `scripts/deploy-node-services.sh`**
  Script tự động deploy toàn bộ cấu hình node mới (đặt hostname, gán MAC, đổi subnet LAN, cài đặt 3proxy, Tailscale, SmartDNS, AdGuard Home và mở firewall WAN).

- [ ] **Step 4: Cấp quyền thực thi và kiểm tra cú pháp**
  Chạy `bash -n scripts/*.sh` kiểm tra syntax.

- [ ] **Step 5: Commit**
  `git add scripts/backup-stock-partitions.sh scripts/flash-ursusboot-candidate.sh scripts/deploy-node-services.sh`

---

### Task 6: Viết Cẩm Nang Hướng Dẫn Thủ Công Toàn Diện (`MANUAL_PROVISIONING_GUIDE.md`)

**Files:**
- Create: `MANUAL_PROVISIONING_GUIDE.md`

**Interfaces:**
- Consumes: Toàn bộ quy trình từ Spec doc và kinh nghiệm giải quyết lỗi trong buổi làm việc.
- Produces: Sách hướng dẫn tự làm từng bước bằng tay không cần trợ giúp của AI.

- [ ] **Step 1: Viết Chương 1 - Chuẩn Bị & Sơ Đồ Cắm Cáp**
  Mô tả chi tiết cách nối dây (cổng 1 là WAN, cổng 2/3 là LAN), cách đặt IP tĩnh máy tính để không bị mất mạng Wi-Fi.

- [ ] **Step 2: Viết Chương 2 - Phá Khóa Telnet & Sao Lưu 9 Phân Vùng MTD**
  Cung cấp sẵn đoạn mã PowerShell 1-Click mở port 9876 nhận 9 file backup từ lệnh `cat /dev/mtdX | nc` trên router.

- [ ] **Step 3: Viết Chương 3 - Ghép File & Nạp Bootloader UrsusBoot Có Kiểm Tra Hai Chiều**
  Cung cấp lệnh Python ghép file 512 KB, lệnh ghi `mtd_debug` và lệnh đọc ngược kiểm tra SHA256.

- [ ] **Step 4: Viết Chương 4 - Bấm Nút Reset & Nạp OpenWrt UBI Qua Web Cứu Hộ**
  Hướng dẫn trực quan cách đếm nhịp đèn LED (2 ngắn + 3 dài $\rightarrow$ đứng) và thao tác trên web `http://192.168.1.1`.

- [ ] **Step 5: Viết Chương 5 - Cấu Hình Mạng Chống Trùng MAC & Kích Hoạt Bộ 4 Dịch Vụ**
  Lệnh đổi IP LAN, đổi MAC theo tem, mở port Web/SSH từ mạng nhà, cấu hình 3proxy và kết nối Tailscale.

- [ ] **Step 6: Viết Chương 6 - Cứu Brick Khẩn Cấp & Bảng Mã Lỗi Thường Gặp**
  Xử lý khi quên mật khẩu, khi cúp điện lúc nạp, và cách dùng Web Failsafe để nạp lại bất kỳ lúc nào.

- [ ] **Step 7: Commit**
  `git add MANUAL_PROVISIONING_GUIDE.md`

---

### Task 7: Kiểm Thử Toàn Diện & Nghiệm Thu (Verification)

- [ ] **Step 1: Kiểm tra cấu trúc thư mục và tính hợp lệ của tất cả file skill**
  Đảm bảo cả 4 file `SKILL.md` đều có frontmatter đúng cú pháp và nội dung đầy đủ không có placeholder "TODO/TBD".

- [ ] **Step 2: Kiểm tra tính sẵn sàng của các file script**
  Đảm bảo các script trong `scripts/` sạch cú pháp.

- [ ] **Step 3: Kiểm tra tính nhất quán giữa tài liệu thủ công và các skill**
  Đảm bảo thông số IP, port (10001-10003, 6053, 3000, 5335), lệnh CLI khớp nhau 100%.

- [ ] **Step 4: Commit hoàn tất và bàn giao**
