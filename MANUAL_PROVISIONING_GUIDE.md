# Cẩm Nang Cài Đặt Thủ Công Nokia Bell XG-040G-MD
### Chuyển đổi từ Stock China Mobile sang OpenWrt UBI & Cấu hình Dịch vụ Dân Cư

Tài liệu hướng dẫn từng bước dành cho người dùng tự thao tác cài đặt một router **Nokia Bell XG-040G-MD (chip Airoha AN7581)** mới mà không cần qua AI.

---

## MỤC LỤC
1. [Chương 1: Chuẩn Bị & Sơ Đồ Cắm Cáp Mạng](#chương-1-chuẩn-bị--sơ-đồ-cắm-cáp-mạng)
2. [Chương 2: Khai Thác Telnet & Sao Lưu 9 Phân Vùng MTD (Bảo Hiểm)](#chương-2-khai-thác-telnet--sao-lưu-9-phân-vùng-mtd-bảo-hiểm)
3. [Chương 3: Lắp Ráp & Nạp Bootloader UrsusBoot (Readback Check)](#chương-3-lắp-ráp--nạp-bootloader-ursusboot-readback-check)
4. [Chương 4: Thao Tác Nút Reset & Nạp OpenWrt UBI Qua Web Cứu Hộ](#chương-4-thao-tác-nút-reset--nạp-openwrt-ubi-qua-web-cứu-hộ)
5. [Chương 5: Cấu Hình Mạng Chống Trùng MAC & Khởi Động Dịch Vụ](#chương-5-cấu-hình-mạng-chống-trùng-mac--khởi-động-dịch-vụ)
6. [Chương 6: Bảng Mã Lỗi Thường Gặp & Quy Trình Cứu Brick Khẩn Cấp](#chương-6-bảng-mã-lỗi-thường-gặp--quy-trình-cứu-brick-khẩn-cấp)

---

## Chương 1: Chuẩn Bị & Sơ Đồ Cắm Cáp Mạng

### 1.1. Sơ đồ cổng vật lý trên Nokia Bell XG-040G-MD
```text
  [ Cổng 1 ]        [ Cổng 2 ]        [ Cổng 3 ]        [ Cổng 4 ]
 (LAN 1 - 2.5G)    (LAN 2 - 1G)      (LAN 3 - 1G)      (LAN 4 - 1G)
       │                 │                 │                 │
    [ WAN ]           [ LAN ]           [ LAN ]           [ LAN ]
(Nối Modem chính) (Nối PC cấu hình)  (Dự phòng)        (Dự phòng)
```

### 1.2. Đọc thông số dưới tem đáy Router mới
Lật mặt đáy của router, chụp lại tem nhãn để ghi nhận:
1. **User đăng nhập**: Mặc định là `user`.
2. **Password mặc định**: Chuỗi 8 ký tự in tại dòng *终端密码* hoặc *Password* (Ví dụ: `h8277a*3`).
3. **MAC LAN / WAN**: Chuỗi 12 ký tự hex (Ví dụ `90:03:2E:64:16:24`).

### 1.3. Cài đặt IP mạng dây trên máy tính (Để không bị mất mạng Wi-Fi)
Khi cắm dây từ router mới vào PC, để Windows không bị mất mạng internet Wi-Fi:
- Mở **Network Connections** (`ncpa.cpl`) $\rightarrow$ Bấm chuột phải vào card mạng dây $\rightarrow$ **Properties**.
- Chọn **Internet Protocol Version 4 (TCP/IPv4)**:
  - **IP address**: `192.168.1.3` (hoặc `192.168.20.2` tùy giai đoạn)
  - **Subnet mask**: `255.255.255.0`
  - **Default Gateway**: **ĐỂ TRỐNG (TUYỆT ĐỐI KHÔNG ĐIỀN)** $\rightarrow$ Giúp Windows 100% duyệt web qua Wi-Fi.
- **Bỏ chọn Internet Protocol Version 6 (TCP/IPv6)** (Uncheck) để chặn router phát DNS đè vào máy tính.

---

## Chương 2: Khai Thác Telnet & Sao Lưu 9 Phân Vùng MTD (Bảo Hiểm)

> **CẢNH BÁO QUAN TRỌNG**: Không bao giờ được nạp ROM khi chưa sao lưu đủ 9 file `.bin`. Bản sao lưu này bảo vệ máy bạn 100% khỏi mọi nguy cơ biến thành "cục gạch".

### 2.1. Đăng nhập Telnet & Leo quyền Root
1. Mở Terminal / PowerShell gõ:
   ```bash
   telnet 192.168.1.1 23
   ```
2. Khi màn hình hiện `Login:`, gõ:
   - `user`
   - Nhập mật khẩu ở tem đáy khi hiện `Password:`.
3. Khi hiện dấu `$`, gõ lệnh leo quyền root:
   ```sh
   su user_ftp
   # Nhập lại mật khẩu ở tem đáy
   ```
4. Khi hiện dấu `#`, gõ `id` để kiểm tra. Màn hình phải hiện: `uid=0(root) gid=0(root)`.

*Lưu ý: Nếu nhập sai quá 3 lần bị khóa 300s, chỉ cần rút nguồn router cắm lại là hết khóa ngay.*

### 2.2. Kéo 9 phân vùng gốc về máy tính bằng Netcat
1. **Trên máy tính Windows**: Mở một cửa sổ PowerShell riêng, chạy script mở cổng nhận:
   ```powershell
   # Chạy script có sẵn trong repo:
   ./scripts/backup-stock-partitions.sh 192.168.1.1 backup_router_stock
   ```
   *(Hoặc gõ thủ công trên PowerShell để nhận từng file:)*
   ```powershell
   $l = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, 9876); $l.Start()
   $c = $l.AcceptTcpClient(); $f = [IO.File]::Create("mtd0_bootloader.bin")
   $c.GetStream().CopyTo($f); $f.Close(); $c.Close(); $l.Stop()
   ```

2. **Trên cửa sổ Telnet của Router**, gửi từng phân vùng về PC (thay `192.168.1.3` bằng IP máy tính):
   ```sh
   cat /dev/mtd0ro | nc 192.168.1.3 9876
   cat /dev/mtd1ro | nc 192.168.1.3 9876
   cat /dev/mtd6ro | nc 192.168.1.3 9876
   cat /dev/mtd7ro | nc 192.168.1.3 9876
   cat /dev/mtd8ro | nc 192.168.1.3 9876
   cat /dev/mtd9ro | nc 192.168.1.3 9876
   cat /dev/mtd2ro | nc 192.168.1.3 9876
   cat /dev/mtd3ro | nc 192.168.1.3 9876
   cat /dev/mtd10ro | nc 192.168.1.3 9876
   ```

3. **Kiểm tra dung lượng file trên máy tính**:
   - `mtd0_bootloader.bin`: đúng 524.288 bytes
   - `mtd1_romfile.bin`: đúng 262.144 bytes
   - `mtd6_bosa.bin` & `mtd7_ri.bin` & `mtd8` & `mtd9`: đúng 262.144 bytes mỗi file
   - `mtd2_kernel.bin`: 4.718.592 bytes
   - `mtd3_rootfs.bin`: 37.748.736 bytes
   - `mtd10_config.bin`: 10.485.760 bytes

---

## Chương 3: Lắp Ráp & Nạp Bootloader UrsusBoot (Readback Check)

UrsusBoot là U-Boot v2026.07 tích hợp Web Failsafe Recovery. Cài bootloader này giúp bạn từ nay về sau chỉ cần giữ nút Reset là tự bật web cứu hộ để nạp ROM.

### 3.1. Tạo file `candidate_mtd0.bin` trên máy tính
Chạy script lắp ráp có sẵn:
```bash
./scripts/flash-ursusboot-candidate.sh backup_router_stock/mtd0_bootloader.bin
```
Script sẽ lấy 2048 bytes đầu (header) và 16 KB cuối (`tcboot` env) của router ghép với UrsusBoot FIP để tạo ra file `candidate_mtd0_ursusboot.bin` (524.288 bytes) và in mã SHA256 ra màn hình.

### 3.2. Đẩy file lên router và ghi Flash
1. Đẩy file vào `/tmp` của router:
   - Dùng lệnh `wget http://<IP_PC>/candidate_mtd0_ursusboot.bin -O /tmp/ursusboot_mtd0.bin`
   - Hoặc dùng script đẩy qua netcat.
2. Kiểm tra mã băm trên router:
   ```sh
   sha256sum /tmp/ursusboot_mtd0.bin
   ```
   *(Mã in ra phải trùng 100% với mã hash trên PC).*
3. **Thực hiện lệnh ghi (Chạy trong Telnet Root)**:
   ```sh
   /sbin/mtd_debug erase /dev/mtd0 0 524288
   /sbin/mtd_debug write /dev/mtd0 0 524288 /tmp/ursusboot_mtd0.bin && sync
   ```
4. **Đọc ngược lại từ Flash để kiểm tra (BẮT BUỘC - READBACK CHECK)**:
   ```sh
   dd if=/dev/mtd0 of=/tmp/readback_mtd0.bin bs=131072 count=4
   sha256sum /tmp/readback_mtd0.bin
   ```
   - **NẾU MÃ HASH KHỚP TUYỆT ĐỐI**: Chúc mừng bạn, bootloader UrsusBoot đã nạp an toàn 100%!
   - **NẾU MÃ HASH KHÔNG KHỚP**: **TUYỆT ĐỐI KHÔNG REBOOT!** Ghi trả lại file backup ngay:
     `/sbin/mtd_debug write /dev/mtd0 0 524288 /tmp/stock_mtd0_backup.bin && sync`

---

## Chương 4: Thao Tác Nút Reset & Nạp OpenWrt UBI Qua Web Cứu Hộ

### 4.1. Cách vào Web Recovery UrsusBoot
1. Rút dây nguồn router.
2. Cắm nguồn lại, chờ đúng 1 giây $\rightarrow$ **Lập tức nhấn và giữ chặt nút RESET**.
3. Nhìn đèn đỏ ở mặt trước router:
   - Đèn đỏ nháy ngắn 2 lần.
   - Tiếp tục giữ $\rightarrow$ Đèn đỏ nháy dài 3 lần.
   - Đèn đỏ chuyển sang **sáng đứng cố định (không nháy nữa)** $\rightarrow$ **Thả tay ra khỏi nút Reset**.
4. Mở trình duyệt web trên máy tính, truy cập: **`http://192.168.1.1`**. Bạn sẽ thấy giao diện cứu hộ UrsusBoot Recovery (màu nâu sẫm hình chú gấu).

### 4.2. Nạp ROM OpenWrt UBI qua Web Recovery
1. Ở mục **Preloader**: Chọn file `openwrt-airoha-an7581-nokia_xg-040g-md-ubi-preloader.bin` (trong thư mục `tools/.../payloads/`). Bấm Upload.
2. Ở mục **Firmware**: Chọn file `openwrt-airoha-an7581-nokia_xg-040g-md-ubi-squashfs-sysupgrade.itb` (trong thư mục `tools/.../fw/`). Bấm Upload.
3. Khi cả 2 file đều báo `VALID`, bấm nút **Install UBI** (hoặc Migration to UBI).
4. Quan sát tiến trình chạy từ 0% đến 100% (`COMPLETE`).
5. Bấm nút **Reboot**. Router sẽ khởi động lại và chính thức chạy OpenWrt Snapshot (Kernel 6.18 / 6.12).

---

## Chương 5: Cấu Hình Mạng Chống Trùng MAC & Khởi Động Dịch Vụ

Sau khi router vào OpenWrt, mặc định router có IP `192.168.1.1` (cổng LAN 2, 3).
Đăng nhập SSH:
```bash
ssh root@192.168.1.1
```

### 5.1. Chạy script cấu hình tự động
Trong thư mục repository `imortal-config`, chạy 1 lệnh duy nhất:
```bash
./scripts/deploy-node-services.sh 192.168.1.1 immortalwrt2 192.168.20.1 <MAC_LAN_CỦA_MÁY> <MAC_WAN_CỦA_MÁY>
```
Script sẽ tự động:
1. Đổi IP mạng LAN thành `192.168.20.1/24` (tránh trùng `192.168.10.1` của Router 1 và `192.168.1.1` của Modem).
2. Gán đúng MAC LAN và MAC WAN phần cứng riêng biệt của router mới (tránh modem Viettel bị MAC flapping).
3. Mở cổng tường lửa WAN cho LuCI (80/443), SSH (22), AdGuard Home (3000).
4. Cài `kmod-tun` và kích hoạt tự khởi động 4 dịch vụ: `3proxy`, `smartdns`, `adguardhome`, `tailscale`.

### 5.2. Đăng nhập Tailscale
Đăng nhập vào router qua IP mới:
```bash
ssh root@192.168.20.1
tailscale login
```
Màn hình sẽ hiện 1 đường link `https://login.tailscale.com/a/...`. Mở link trên trình duyệt và bấm **Authorize** để nhận IP Tailscale riêng (ví dụ `100.68.191.34`).

### 5.3. Cấu hình cổng SOCKS5 3proxy
Mở file `/etc/3proxy-residential.cfg`:
```text
allow proxy1
socks -p10001 -i<IP_TAILSCALE_VỪA_NHẬN>
flush

allow proxy2
socks -p10002 -i<IP_TAILSCALE_VỪA_NHẬN>
flush

allow proxy3
socks -p10003 -i<IP_TAILSCALE_VỪA_NHẬN>
flush
```
Khởi động lại: `/etc/init.d/resproxy restart`.

---

## Chương 6: Bảng Mã Lỗi Thường Gặp & Quy Trình Cứu Brick Khẩn Cấp

### 6.1. Bảng mã lỗi thường gặp

| Hiện tượng | Nguyên nhân | Cách khắc phục |
|---|---|---|
| **Cắm router vào PC bị mất mạng Chrome** | Windows ưu tiên mạng dây hơn Wi-Fi, hoặc bị dính IPv6 DNS `fe80::1`. | Vào card mạng dây đặt IP tĩnh, **để trống ô Gateway**, bỏ tích IPv6. |
| **Telnet báo "forbidden about 300s"** | Nhập sai mật khẩu quá 3 lần. | Rút nguồn router cắm lại để xóa bộ đếm trong RAM. |
| **Cắm router vào modem không có mạng, Tailscale offline** | Bị trùng địa chỉ MAC với router khác đã cắm trước đó. | Kiểm tra `/etc/config/network`, sửa `macaddr` cổng WAN `lan1` về đúng MAC trên tem máy. |
| **Từ Wi-Fi nhà không vào được Web 192.168.1.x** | Tường lửa OpenWrt mặc định chặn truy cập từ cổng WAN. | Vào SSH thêm 3 rule `Allow-WAN-LuCI`, `Allow-WAN-SSH`, `Allow-WAN-AdGuard` vào `/etc/config/firewall`. |
| **Tailscale báo `tstun.New error: no such device`** | Chưa có driver TUN của kernel Linux. | Chạy `echo "nameserver 1.1.1.1" > /tmp/resolv.conf && apk update && apk add kmod-tun`. |

### 6.2. Quy trình cứu Brick khẩn cấp
1. **Trường hợp lỗi hệ điều hành OpenWrt (Không vào được SSH/Web)**:
   - Rút nguồn cắm lại, giữ nút **Reset** theo nhịp (2 ngắn + 3 dài $\rightarrow$ đứng) để vào lại UrsusBoot Web Recovery `http://192.168.1.1`.
   - Nạp lại firmware `.itb` là máy sống lại bình thường.
2. **Trường hợp hỏng phân vùng UBI hoàn toàn**:
   - Vào Web Recovery UrsusBoot $\rightarrow$ Nạp lại file `ubi-preloader.bin` và `sysupgrade.itb` để format lại 7 volume UBI từ đầu.
3. **Trường hợp mất điện đúng lúc ghi `mtd0` (Hỏng bootloader)**:
   - Tháo 4 ốc dưới đáy router, nối cáp USB-to-TTL vào 3 chân UART (`TX`, `RX`, `GND` - không cắm chân VCC).
   - Dùng công cụ `tools/airoha-router-ursusflasher`: Chạy `START_EXPERT.cmd` chọn mục **5 (Khôi phục Bootloader qua UART/BootROM)**.
   - Nạp lại file `mtd0_bootloader.bin` gốc đã sao lưu trong `backup_router_stock/`. Máy sẽ hồi sinh 100%.
