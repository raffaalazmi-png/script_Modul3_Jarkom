#!/bin/bash
# ==============================================================================
# Soal 20: Apache Benchmark Audit & Stress Test dari Client (kusakabe)
#
# Target:
#   - Uji Kinerja Cache: ab -n 600 -c 30 menuju http://jujutsu.k20.com/
#   - Uji Efektivitas Rate Limit: ab -n 50 -c 10 menuju http://jujutsu.k20.com/api
# ==============================================================================
set -e

echo "[*] Memulai Audit Kapasitas Layanan & Rate Limiting (Soal 20)..."
echo "nameserver 192.168.122.1" > /etc/resolv.conf

# 1. Pasang paket apache2-utils jika belum terpasang
if ! which ab >/dev/null 2>&1; then
    echo "[*] Menginstal apache2-utils..."
    if which apt-get >/dev/null 2>&1; then
        apt-get update -y && apt-get install -y apache2-utils
    elif which apk >/dev/null 2>&1; then
        apk update && apk add apache2-utils
    fi
fi

TARGET="http://192.221.1.4/"
TARGET_API="http://192.221.1.4/api"

echo ""
echo "=========================================================="
echo "1. Benchmark Frontend Web (Cache Performance)"
echo "Perintah: ab -n 600 -c 30 -H 'Host: jujutsu.k20.com' $TARGET"
echo "=========================================================="
ab -n 600 -c 30 -H "Host: jujutsu.k20.com" "$TARGET" || true

echo ""
echo "=========================================================="
echo "2. Uji Efektivitas Rate Limiting pada Endpoint /api"
echo "Perintah: ab -n 50 -c 10 -H 'Host: jujutsu.k20.com' $TARGET_API"
echo "Ekspektasi: Muncul Non-2xx responses (Status HTTP 503)"
echo "=========================================================="
ab -n 50 -c 10 -H "Host: jujutsu.k20.com" "$TARGET_API" || true

echo ""
echo "[OK] Audit benchmark performa dan rate limiting selesai!"
