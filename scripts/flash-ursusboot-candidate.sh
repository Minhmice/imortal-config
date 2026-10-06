#!/usr/bin/env bash
set -euo pipefail

# Script lắp ráp candidate mtd0 và hỗ trợ nạp an toàn cho Nokia Bell XG-040G-MD
# Sử dụng: ./scripts/flash-ursusboot-candidate.sh <PATH_TO_STOCK_MTD0> [PATH_TO_FIP]

STOCK_MTD0="${1:-backup_router_stock/mtd0_bootloader.bin}"
FIP_FILE="${2:-tools/airoha-router-ursusflasher/payloads/md/ursusboot/ursusboot-md-0.1.0-alpha5-UBIUX1-TEST61-update.fip}"
OUT_FILE="candidate_mtd0_ursusboot.bin"

if [ ! -f "${STOCK_MTD0}" ]; then
  echo "[LỖI] Không tìm thấy file mtd0 gốc: ${STOCK_MTD0}"
  exit 1
fi

if [ ! -f "${FIP_FILE}" ]; then
  echo "[LỖI] Không tìm thấy file UrsusBoot FIP: ${FIP_FILE}"
  exit 1
fi

echo "=========================================================="
echo "LẮP RÁP BOOTLOADER CANDIDATE MTD0 (512 KiB) - NOKIA XG-040G-MD"
echo "=========================================================="

python3 -c "
import hashlib, sys

stock = open('${STOCK_MTD0}', 'rb').read()
fip = open('${FIP_FILE}', 'rb').read()

if len(stock) != 524288:
    print(f'[LỖI] File stock mtd0 không đúng kích thước 524288 bytes (thực tế: {len(stock)})')
    sys.exit(1)

candidate = bytearray(stock)
# Giữ nguyên 2048 bytes đầu (BootROM header)
# Ghi đè FIP từ byte 2048
candidate[2048:2048+len(fip)] = fip
# Giữ nguyên 16 KiB cuối (0x7C000..0x7FFFF tcboot env)

with open('${OUT_FILE}', 'wb') as f:
    f.write(candidate)

candidate_sha = hashlib.sha256(candidate).hexdigest()
print(f'[OK] Đã tạo thành công {sys.argv[1] if len(sys.argv)>1 else \"candidate_mtd0_ursusboot.bin\"}')
print(f'     Kích thước: {len(candidate)} bytes')
print(f'     SHA256 Candidate: {candidate_sha}')
"

CANDIDATE_SHA=$(sha256sum "${OUT_FILE}" | awk '{print $1}')

echo "----------------------------------------------------------"
echo "HƯỚNG DẪN NẠP VÀO FLASH TRÊN ROUTER (CHỐNG BRICK 100%):"
echo "1. Đẩy file ${OUT_FILE} vào /tmp/ursusboot_mtd0.bin trên router."
echo "2. Chạy lệnh kiểm tra mã băm trên router:"
echo "   sha256sum /tmp/ursusboot_mtd0.bin"
echo "   -> Phải khớp chính xác: ${CANDIDATE_SHA}"
echo ""
echo "3. Thực hiện chuỗi lệnh ghi Flash (chạy trong phiên Telnet root):"
echo "   /sbin/mtd_debug erase /dev/mtd0 0 524288"
echo "   /sbin/mtd_debug write /dev/mtd0 0 524288 /tmp/ursusboot_mtd0.bin && sync"
echo ""
echo "4. ĐỌC NGƯỢC LẠI TỪ CHIP FLASH ĐỂ KIỂM TRA (BẮT BUỘC):"
echo "   dd if=/dev/mtd0 of=/tmp/readback_mtd0.bin bs=131072 count=4"
echo "   sha256sum /tmp/readback_mtd0.bin"
echo ""
echo ">>> NẾU SHA256 ĐỌC NGƯỢC LẠI KHỚP ${CANDIDATE_SHA} -> NẠP THÀNH CÔNG!"
echo ">>> NẾU SAI LỆCH DÙ 1 BIT: TUYỆT ĐỐI KHÔNG REBOOT, GHI TRẢ LẠI BẢN GỐC NGAY!"
echo "=========================================================="
