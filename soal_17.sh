#!/bin/bash
# ==============================================================================
# Soal 17: Preservasi IP Asli Klien (X-Real-IP & X-Forwarded-For) & Logging Database
# ==============================================================================
set -e

NODE=$(hostname)
echo "[*] Menjalankan Soal 17 pada node: $NODE"

if [ "$NODE" = "gojo" ]; then
    echo "[*] Memastikan proxy_set_header X-Real-IP aktif di gojo..."
    # Gojo meneruskan X-Real-IP $remote_addr
    bash /root/gojo.sh
    echo "[✓] Gojo header forwarding aktif."

elif [ "$NODE" = "geto" ]; then
    echo "[*] Memastikan set_real_ip_from 192.221.1.4 aktif di geto..."
    # Geto hanya percaya IP dari gojo
    bash /root/geto.sh
    echo "[✓] Geto trusted proxy aktif."

elif [ "$NODE" = "nanami" ] || [ "$NODE" = "todo" ] || [ "$NODE" = "kirara" ]; then
    echo "[*] Memastikan logging IP klien ke MariaDB aktif di $NODE..."
    bash /root/${NODE}.sh
    echo "[✓] Logging client IP ke database aktif di $NODE."

elif [ "$NODE" = "yaga" ]; then
    echo "[*] Memeriksa tabel request_logs di yaga..."
    mysql -uroot -e "SELECT * FROM db_shibuya_k20.request_logs ORDER BY id DESC LIMIT 5;" 2>/dev/null || true

else
    echo "[!] Skrip Soal 17 mencakup gojo, geto, nanami, todo, kirara, dan yaga."
fi
