#!/usr/bin/env bash
set -euo pipefail

# Script trích xuất an toàn 9 phân vùng MTD gốc của Nokia Bell XG-040G-MD
# Sử dụng: ./scripts/backup-stock-partitions.sh [ROUTER_IP] [DEST_DIR]

ROUTER_IP="${1:-192.168.1.1}"
DEST_DIR="${2:-backup_router_stock}"
PORT="${PORT:-9876}"

mkdir -p "${DEST_DIR}"

echo "=========================================================="
echo "BẮT ĐẦU SAO LƯU 9 PHÂN VÙNG MTD GỐC - NOKIA XG-040G-MD"
echo "Target: ${ROUTER_IP} | Thư mục lưu: ${DEST_DIR} | Port: ${PORT}"
echo "=========================================================="

# Danh sách: number:name:expected_bytes
PARTITIONS=(
  "0:mtd0_bootloader:524288"
  "1:mtd1_romfile:262144"
  "6:mtd6_bosa:262144"
  "7:mtd7_ri:262144"
  "8:mtd8_flag:262144"
  "9:mtd9_flagback:262144"
  "2:mtd2_kernel:4718592"
  "3:mtd3_rootfs:37748736"
  "10:mtd10_config:10485760"
)

# Lấy địa chỉ IP máy tính hướng về router
LOCAL_IP=$(python3 -c "import socket; s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.connect(('${ROUTER_IP}', 80)); print(s.getsockname()[0]); s.close()")
echo "[INFO] Địa chỉ IP máy tính kết nối với Router: ${LOCAL_IP}"

for item in "${PARTITIONS[@]}"; do
  IFS=":" read -r num name expected_size <<< "${item}"
  target_file="${DEST_DIR}/${name}.bin"

  if [ -f "${target_file}" ] && [ "$(wc -c < "${target_file}")" -eq "${expected_size}" ]; then
    echo "[PASS] ${name}.bin đã tồn tại và đủ dung lượng (${expected_size} B). Bỏ qua."
    continue
  fi

  echo "[WAIT] Đang kéo /dev/mtd${num}ro (${name}, ${expected_size} bytes)..."
  
  # Khởi chạy background receiver trên máy tính
  nc -l -p "${PORT}" > "${target_file}" &
  NC_PID=$!
  sleep 0.5

  echo "[CMD] Gửi lệnh trên Router: cat /dev/mtd${num}ro | nc ${LOCAL_IP} ${PORT}"
  echo ">>> Vui lòng đảm bảo phiên Telnet Root trên router đang chạy lệnh trên!"
  
  wait "${NC_PID}"

  actual_size=$(wc -c < "${target_file}")
  if [ "${actual_size}" -ne "${expected_size}" ]; then
    echo "[FAIL] ${name}.bin lỗi dung lượng! Nhận: ${actual_size} B, Mong đợi: ${expected_size} B."
    exit 1
  else
    sha=$(sha256sum "${target_file}" | awk '{print $1}')
    echo "[OK] ${name}.bin hoàn tất! SHA256: ${sha}"
  fi
done

echo "=========================================================="
echo "[THÀNH CÔNG] Toàn bộ 9 phân vùng gốc đã được lưu an toàn tại ${DEST_DIR}!"
echo "=========================================================="
