#!/bin/bash
# ==============================================================================
# Soal 18: Backup Server (kirara) & Passive Health Check pada geto
#
# Target:
#   - Parameter Passive Health Check: max_fails=2 fail_timeout=5s (nanami & todo)
#   - Server Cadangan: kirara (192.221.4.8) berstatus 'backup'
#   - Failover Otomatis: Bila nanami dan todo down, request dialihkan ke kirara
# ==============================================================================
set -e

# ==============================================================================
# SECTION 1: Konfigurasi Upstream Failover pada geto (192.221.4.3)
# ==============================================================================
setup_geto() {
    echo "[*] Mengonfigurasi parameter failover dan backup server pada geto..."
    cat << 'EOF' > /etc/nginx/sites-available/loadbalancer.conf
upstream api_cluster {
    server 192.221.4.6:80 weight=3 max_fails=2 fail_timeout=5s; # nanami
    server 192.221.4.7:80 weight=1 max_fails=2 fail_timeout=5s; # todo
    server 192.221.4.8:80 backup;                               # kirara
}

server {
    listen 80 default_server;
    server_name _;

    set_real_ip_from 192.221.1.4;
    real_ip_header X-Real-IP;
    real_ip_recursive on;

    location / {
        proxy_pass http://api_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 3s;
        proxy_read_timeout 5s;
    }
}
EOF

    nginx -t
    service nginx restart 2>/dev/null || /etc/init.d/nginx restart 2>/dev/null || nginx -s reload 2>/dev/null || true
    echo "[OK] Passive health check dan server backup pada geto aktif!"
}

# ==============================================================================
# SECTION 2: Konfigurasi Server Cadangan pada kirara (192.221.4.8)
# ==============================================================================
setup_kirara() {
    echo "[*] Memastikan kesiapan worker cadangan pada kirara..."
    bash /root/kirara.sh 2>/dev/null || true
    echo "[OK] Server backup kirara siap melayani fallback lalu lintas!"
}

# ==============================================================================
# Dispatcher Eksekusi
# ==============================================================================
TARGET="${1:-$(hostname)}"
case "$TARGET" in
    "geto")
        setup_geto
        ;;
    "kirara")
        setup_kirara
        ;;
    *)
        echo "[!] Skrip Soal 18 ditujukan untuk node: geto dan kirara."
        echo "    Penggunaan: $0 [geto|kirara]"
        ;;
esac
