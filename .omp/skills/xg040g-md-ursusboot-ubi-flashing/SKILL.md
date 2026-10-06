---
name: xg040g-md-ursusboot-ubi-flashing
description: "Procedure for constructing candidate mtd0, flashing UrsusBoot with readback validation, entering Web Recovery via Reset button, and migrating to OpenWrt UBI."
---

# Nokia Bell XG-040G-MD UrsusBoot & UBI Flashing Skill

Dùng khi nạp Bootloader cứu hộ **UrsusBoot (v0.1.0-alpha5-t71)** và chuyển đổi hệ điều hành sang **OpenWrt UBI** cho dòng router **Nokia Bell XG-040G-MD (Airoha AN7581)**.

## 1. Cấu Trúc Khối `mtd0` (512 KiB Candidate Assembly)

Nokia Bell XG-040G-MD sử dụng phân vùng `mtd0` kích thước đúng **524.288 bytes** (512 KiB). Khi thay thế U-Boot, bắt buộc phải bảo tồn các khối phần cứng gốc của chính thiết bị đó:

```text
0x000000 ┌──────────────────────────────────────────┐
         │ 2048 bytes: BootROM Header Gốc Của Máy   │  (Chứa mã định danh chip và khóa khởi động)
0x000800 ├──────────────────────────────────────────┤
         │                                          │
         │ 503.808 bytes: UrsusBoot FIP (U-Boot     │  (Chứa BL31 + U-Boot v2026.07 đã tích hợp
         │ v2026.07 t71 hỗ trợ SkyHigh & Fudan)    │   sẵn Web Recovery và driver SPI-NAND)
         │                                          │
0x07C000 ├──────────────────────────────────────────┤
         │ 16 KiB: tcboot Environment Gốc Của Máy   │  (Chứa biến môi trường U-Boot xuất xưởng)
0x080000 └──────────────────────────────────────────┘
```

### 1.1. Lệnh Python lắp ráp `candidate_mtd0.bin`
```python
import hashlib

# 1. Đọc file mtd0 gốc đã dump từ máy mục tiêu
live_mtd0 = open("backup_router_stock/mtd0_bootloader.bin", "rb").read()
# 2. Đọc file UrsusBoot FIP
hybrid_fip = open("payloads/md/ursusboot/ursusboot-md-0.1.0-alpha5-UBIUX1-TEST61-update.fip", "rb").read()

# 3. Lắp ghép
rom_header = live_mtd0[:2048]
env_block = live_mtd0[0x7C000:0x80000]

candidate = bytearray(live_mtd0)
candidate[2048:2048 + len(hybrid_fip)] = hybrid_fip

with open("candidate_mtd0.bin", "wb") as f:
    f.write(candidate)

print("Kích thước:", len(candidate))
print("SHA256 Candidate:", hashlib.sha256(candidate).hexdigest())
```

---

## 2. Quy Trình Nạp Bootloader & Kiểm Tra Hai Chiều (Readback Check)

Sau khi chuyển file `candidate_mtd0.bin` vào thư mục `/tmp/` trên router qua TFTP hoặc `wget`:

### 2.1. Chuỗi lệnh nạp Flash mức thấp
```sh
# 1. Xóa đúng 512 KiB của mtd0
/sbin/mtd_debug erase /dev/mtd0 0 524288

# 2. Ghi đè candidate vào mtd0
/sbin/mtd_debug write /dev/mtd0 0 524288 /tmp/candidate_mtd0.bin && sync

# 3. ĐỌC NGƯỢC LẠI TỪ CHIP FLASH RA RAM
dd if=/dev/mtd0 of=/tmp/readback_mtd0.bin bs=131072 count=4
sha256sum /tmp/readback_mtd0.bin
```

### 2.2. Quy Tắc Sống Còn (Safety Invariant)
- **Nếu SHA256 đọc ngược lại khớp 100% với candidate**: Ghi thành công. Được phép chuyển sang bước tiếp theo.
- **Nếu SHA256 đọc ngược lại SAI LỆCH DÙ 1 BIT**:
  - **TUYỆT ĐỐI KHÔNG KHỞI ĐỘNG LẠI HOẶC RÚT NGUỒN ROUTER!**
  - Chạy ngay lệnh khôi phục bản gốc:
    ```sh
    /sbin/mtd_debug erase /dev/mtd0 0 524288
    /sbin/mtd_debug write /dev/mtd0 0 524288 /tmp/stock_mtd0_backup.bin && sync
    ```

---

## 3. Thao Tác Nút RESET Vào UrsusBoot Web Recovery

1. Rút dây nguồn router.
2. Cắm nguồn lại, chờ đúng 1 giây $\rightarrow$ **Lập tức nhấn và giữ chặt nút RESET**.
3. Quan sát đèn LED đỏ ở mặt trước:
   - Đèn đỏ **nháy ngắn 2 lần**.
   - Tiếp tục giữ $\rightarrow$ Đèn đỏ **nháy dài 3 lần**.
   - Đến khi đèn đỏ **sáng đứng cố định (hết nháy)** $\rightarrow$ **Thả tay ra khỏi nút Reset**.
4. Kết quả: Router khởi động vào UrsusBoot Web Recovery tại IP `192.168.1.1` (cổng 80).

---

## 4. Chuyển Đổi Sang OpenWrt UBI Qua Web API

Từ máy tính kết nối với cổng LAN 2/3 (IP tĩnh `192.168.1.2/24`):

### 4.1. Tải 2 file cần thiết lên RAM của router
1. **Preloader chuyển đổi**: `openwrt-airoha-an7581-nokia_xg-040g-md-ubi-preloader.bin` (113 KB).
2. **Firmware OpenWrt UBI**: `openwrt-airoha-an7581-nokia_xg-040g-md-ubi-squashfs-sysupgrade.itb` (10.3 MB).

Sử dụng script Python `ursus_web_client.py`:
```python
import ursus_web_client as uw
from pathlib import Path

host = "192.168.1.1" # hoặc 127.0.0.1:18080 qua SSH tunnel
uw.upload(host, Path("ubi-preloader.bin"), "preloader")
uw.upload(host, Path("openwrt-ubi-sysupgrade.itb"), "firmware")
```

### 4.2. Kích hoạt phân vùng và ghi UBI
Gửi request kích hoạt:
```sh
curl -X POST -H "X-Ursus-Confirm: INSTALL-UBI" -H "X-Ursus-Keep-Settings: 0" http://192.168.1.1/api/install-ubi
```
UrsusBoot sẽ tự động thực hiện 17 bước:
- Sao lưu `bosa` và `ri` vào RAM.
- Format toàn bộ NAND thành UBI.
- Tạo 7 phân vùng UBI (`ubootenv`, `ubootenv2`, `bosa`, `ri`, `fip`, `fit`, `rootfs_data`).
- Ghi và xác thực lại từng phân vùng.
- Ghi BL2 preloader cuối cùng.

### 4.3. Khởi động lại vào OpenWrt
Sau khi log in `UBI: 100% - COMPLETE`:
```sh
curl -X POST -H "X-Ursus-Confirm: REBOOT" http://192.168.1.1/api/reboot
```
Router sẽ khởi động thẳng vào OpenWrt Kernel 6.18 / 6.12.
