#!/bin/bash
# ==============================================================================
# Script Validasi & Testing Mandiri Praktikum Modul 3 (Soal 11 - 20)
# Jalankan script ini dari salah satu node client (misal: kusakabe / itadori)
# ==============================================================================

echo "nameserver 192.168.122.1" > /etc/resolv.conf
if ! which curl >/dev/null 2>&1 || ! which dig >/dev/null 2>&1; then
    echo "[*] Menginstal tools testing (curl, dnsutils)..."
    if which apt-get >/dev/null 2>&1; then
        apt-get update -y && apt-get install -y curl dnsutils
    elif which apk >/dev/null 2>&1; then
        apk update && apk add curl bind-tools
    fi
fi

GOJO_IP="192.221.1.4"
UTAHIME_IP="192.221.1.2"
SHOKO_IP="192.221.1.3"
GETO_IP="192.221.4.3"
DOMAIN="jujutsu.k20.com"

echo ""
echo "=========================================================="
echo "TEST 11: DNS Master (utahime) & DNS Slave (shoko)"
echo "=========================================================="
echo "[+] Query ke DNS Master (utahime):"
dig @$UTAHIME_IP $DOMAIN +short || true
echo "[+] Query ke DNS Slave (shoko):"
dig @$SHOKO_IP $DOMAIN +short || true

echo ""
echo "=========================================================="
echo "TEST 12: A Record, CNAME, PTR Reverse DNS, & Forwarder"
echo "=========================================================="
echo "[+] Resolusi CNAME www.$DOMAIN:"
dig @$UTAHIME_IP www.$DOMAIN +short || true
echo "[+] Reverse DNS (PTR) untuk $GOJO_IP:"
dig @$UTAHIME_IP -x $GOJO_IP +short || true
echo "[+] Forwarder Internet Test (ping google.com via gateway):"
ping -c 2 google.com || ping -c 2 8.8.8.8 || true

echo ""
echo "=========================================================="
echo "TEST 14: Restriksi Akses Langsung ke Worker"
echo "=========================================================="
echo "[+] Akses langsung ke Web Worker maki (192.221.4.4):"
echo "    Ekspektasi: 403 Forbidden (Akses langsung ditolak)"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://192.221.4.4/ || true
echo "[+] Akses langsung ke API Worker nanami (192.221.4.6):"
echo "    Ekspektasi: 403 Forbidden (Akses langsung ditolak)"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://192.221.4.6/ || true

echo ""
echo "=========================================================="
echo "TEST 15 & 16: Path Routing & Load Balancing (via gojo)"
echo "=========================================================="
echo "[+] Akses Root / (Frontend Maki & Panda):"
for i in {1..4}; do
    curl -s -H "Host: $DOMAIN" http://$GOJO_IP/ | grep -o "Frontend Web Worker: [^<]*" || true
done

echo ""
echo "[+] Akses Path /api (API Cluster via geto):"
for i in {1..4}; do
    curl -s -H "Host: $DOMAIN" http://$GOJO_IP/api | grep -o '"worker": "[^"]*"' || true
done

echo ""
echo "=========================================================="
echo "TEST 17: Preservasi IP Asli Klien (X-Real-IP)"
echo "=========================================================="
curl -s -H "Host: $DOMAIN" http://$GOJO_IP/api | grep -o '"client_ip": "[^"]*"' || true

echo ""
echo "=========================================================="
echo "TEST 19: Nginx Proxy Caching & Rate Limiting"
echo "=========================================================="
echo "[+] Caching Test pada Root / (Lihat X-Cache-Status):"
echo "    Request 1:"
curl -s -I -H "Host: $DOMAIN" http://$GOJO_IP/ | grep -i "x-cache-status" || true
echo "    Request 2 (Ekspektasi HIT):"
curl -s -I -H "Host: $DOMAIN" http://$GOJO_IP/ | grep -i "x-cache-status" || true

echo ""
echo "[+] Rate Limiting Test pada /api (Kirim 15 request cepat):"
for i in {1..15}; do
    curl -s -o /dev/null -w "%{http_code} " -H "Host: $DOMAIN" http://$GOJO_IP/api
done
echo ""
echo "Catatan: Status 503 menandakan request ditolak rate limit (> 10 r/s)."

echo ""
echo "=========================================================="
echo "Seluruh skenario pengujian telah selesai dijalankan!"
echo "=========================================================="
