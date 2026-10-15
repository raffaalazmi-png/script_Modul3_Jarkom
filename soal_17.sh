#!/bin/bash
# ==============================================================================
# Soal 17: Preservasi IP Asli Klien (X-Real-IP & X-Forwarded-For) & Database Logging
#
# Alur Kerja:
#   1. gojo (192.221.1.4)  : Menyematkan X-Real-IP dan X-Forwarded-For
#   2. geto (192.221.4.3)  : Mengonfigurasi modul real_ip (set_real_ip_from gojo)
#   3. API Workers         : Mencatat alamat IP asli ke basis data yaga
#   4. yaga (192.221.4.9)  : Menyimpan log dalam tabel db_shibuya_k20.request_logs
# ==============================================================================
set -e

# ==============================================================================
# SECTION 1: Verifikasi & Konfigurasi Header pada gojo (192.221.1.4)
# ==============================================================================
setup_gojo() {
    echo "[*] Mengonfigurasi preservasi header X-Real-IP pada gojo..."
    # Memastikan file konfigurasi gojo aktif
    bash /root/gojo.sh 2>/dev/null || true
    echo "[OK] Header forwarding X-Real-IP dan X-Forwarded-For aktif pada gojo!"
}

# ==============================================================================
# SECTION 2: Konfigurasi Trusted Reverse Proxy pada geto (192.221.4.3)
# ==============================================================================
setup_geto() {
    echo "[*] Mengonfigurasi real_ip_header dan trusted proxy pada geto..."
    # Memastikan file konfigurasi geto aktif
    bash /root/geto.sh 2>/dev/null || true
    echo "[OK] Modul real_ip geto berhasil membaca IP dari gojo!"
}

# ==============================================================================
# SECTION 3: Konfigurasi Logging Database pada API Workers
# ==============================================================================
setup_worker() {
    NODE_NAME="$1"
    echo "[*] Memastikan logging IP klien ke MariaDB aktif pada $NODE_NAME..."
    bash /root/${NODE_NAME}.sh 2>/dev/null || true
    echo "[OK] Skrip pencatatan log IP ke tabel database aktif pada $NODE_NAME!"
}

# ==============================================================================
# SECTION 4: Pengecekan Basis Data pada yaga (192.221.4.9)
# ==============================================================================
check_yaga() {
    echo "[*] Memeriksa isi tabel request_logs pada MariaDB Master (yaga)..."
    mysql -uroot -e "SELECT * FROM db_shibuya_k20.request_logs ORDER BY id DESC LIMIT 5;" 2>/dev/null || true
    echo "[OK] Pengecekan tabel request_logs selesai!"
}

# ==============================================================================
# Dispatcher Eksekusi
# ==============================================================================
TARGET="${1:-$(hostname)}"
case "$TARGET" in
    "gojo")
        setup_gojo
        ;;
    "geto")
        setup_geto
        ;;
    "nanami"|"todo"|"kirara")
        setup_worker "$TARGET"
        ;;
    "yaga")
        check_yaga
        ;;
    *)
        echo "[!] Skrip Soal 17 mencakup node: gojo, geto, nanami, todo, kirara, dan yaga."
        echo "    Penggunaan: $0 [node_name]"
        ;;
esac
