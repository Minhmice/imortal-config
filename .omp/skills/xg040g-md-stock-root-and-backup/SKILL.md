---
name: xg040g-md-stock-root-and-backup
description: "Comprehensive guide for gaining UID 0 root shell on stock China Mobile Nokia Bell XG-040G-MD and capturing a 9-partition restore-grade flash backup."
---

# Nokia Bell XG-040G-MD Stock Root & Backup Skill

Dùng khi cần phá khóa Telnet và sao lưu toàn bộ các phân vùng Flash gốc của router **Nokia Bell XG-040G-MD** chạy firmware gốc của nhà mạng China Mobile.

## 1. Khai Thác Telnet & Leo Quyền Root (UID 0)

### 1.1. Thông tin đăng nhập mặc định
- **Địa chỉ IP mặc định**: `192.168.1.1` (hoặc IP do người dùng cấu hình trong trang web quản trị).
- **Cổng Telnet**: `23` (Mặc định mở trên firmware China Mobile).
- **Username**: `user`
- **Password**: **In trên tem nhãn ở mặt đáy của từng con router** (chuỗi 8 ký tự gồm chữ và số, ví dụ `h8277a*3`).

### 1.2. Kỹ thuật leo quyền sang Root (`UID 0`)
Tài khoản `user` ban đầu chỉ có quyền hạn chế (`uid=1001(user-telnet)`). Để có toàn quyền đọc phân vùng raw MTD:
```sh
# Sau khi đăng nhập thành công vào prompt $
su user_ftp
# Nhập lại mật khẩu in trên tem đáy router khi được hỏi Password:
```
- **Kết quả**: Prompt chuyển sang dấu `#`.
- **Kiểm tra**: Gõ `id` $\rightarrow$ Kết quả phải là `uid=0(root) gid=0(root)`.

### 1.3. Cơ chế bẫy khóa 300 giây (Lockout Trap)
- **Hiện tượng**: Nếu nhập sai mật khẩu quá 3 lần, Telnet sẽ in thông báo:
  `login will be forbidden about 300s because of the continuous authentication failure (over 3 times)` và ngắt kết nối.
- **Cách xử lý triệt để**: Bộ đếm này chỉ nằm trong bộ nhớ RAM tạm thời của router. **Rút nguồn cắm lại** $\rightarrow$ Sau 40 giây router khởi động lại là bộ đếm được reset về 0 ngay lập tức, không cần chờ 5 phút.

---

## 2. Bảng Phân Vùng MTD Mục Tiêu (256 MB SPI-NAND)

| Phân vùng | Thiết bị block | Kích thước | Ý nghĩa phục hồi |
|---|---|---|---|
| `mtd0` | `/dev/mtd0ro` | 524.288 B (512 KiB) | **Bootloader**: U-Boot gốc nhà mạng (cứu brick mức thấp) |
| `mtd1` | `/dev/mtd1ro` | 262.144 B (256 KiB) | **Romfile**: Cấu hình xuất xưởng gốc |
| `mtd2` | `/dev/mtd2ro` | 4.718.592 B (4.5 MiB) | **Kernel**: Nhân hệ điều hành gốc |
| `mtd3` | `/dev/mtd3ro` | 37.748.736 B (36 MiB) | **Rootfs**: Hệ thống file Linux gốc |
| `mtd6` | `/dev/mtd6ro` | 262.144 B (256 KiB) | **BOSA**: Hiệu chuẩn laser quang (Cực kỳ quan trọng) |
| `mtd7` | `/dev/mtd7ro` | 262.144 B (256 KiB) | **RI**: Địa chỉ MAC phần cứng & Serial (Cực kỳ quan trọng) |
| `mtd8` | `/dev/mtd8ro` | 262.144 B (256 KiB) | **Flag**: Cờ chọn boot A/B Slot |
| `mtd9` | `/dev/mtd9ro` | 262.144 B (256 KiB) | **Flagback**: Cờ dự phòng boot A/B |
| `mtd10`| `/dev/mtd10ro`| 10.485.760 B (10 MiB) | **Config**: Dữ liệu cấu hình mạng hiện tại |

---

## 3. Quy Trình Trích Xuất Phân Vùng Qua Mạng (Network Dump)

Trên firmware stock của Nokia có sẵn công cụ `/usr/bin/nc` (netcat). Phương pháp an toàn và nhanh nhất là mở listener trên máy tính và đẩy trực tiếp luồng nhị phân từ router về.

### 3.1. Đoạn mã PowerShell tự động mở listener nhận file trên PC
```powershell
$backupDir = "backup_router_stock"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$port = 9876
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $port)
$listener.Start()

# Chờ kết nối và lưu dữ liệu
$client = $listener.AcceptTcpClient()
$cStream = $client.GetStream()
$fStream = [System.IO.File]::Create("$backupDir\$partName.bin")
$cStream.CopyTo($fStream)
$fStream.Close()
$cStream.Close()
$client.Close()
$listener.Stop()
```

### 3.2. Lệnh đẩy từ Router (qua phiên Telnet Root)
```sh
cat /dev/mtd0ro | nc <IP_PC> 9876
cat /dev/mtd1ro | nc <IP_PC> 9876
cat /dev/mtd6ro | nc <IP_PC> 9876
cat /dev/mtd7ro | nc <IP_PC> 9876
cat /dev/mtd8ro | nc <IP_PC> 9876
cat /dev/mtd9ro | nc <IP_PC> 9876
cat /dev/mtd2ro | nc <IP_PC> 9876
cat /dev/mtd3ro | nc <IP_PC> 9876
cat /dev/mtd10ro | nc <IP_PC> 9876
```

### 3.3. Tiêu chuẩn xác thực tính toàn vẹn (Verification Gate)
1. **Kiểm tra kích thước file**: Mọi file trích xuất phải có dung lượng chính xác từng byte như bảng trên.
2. **Kiểm tra MAC gốc**: Chạy tìm chuỗi trong `mtd7_ri.bin`:
   `strings mtd7_ri.bin | grep NBEL` $\rightarrow$ Phải nhìn thấy Serial `NBELFCEF...` và Board ID `XG040GMC2P5G`.
3. Chỉ khi 9 file nằm an toàn trên ổ cứng máy tính thì mới được phép chuyển sang thao tác ghi Flash!
