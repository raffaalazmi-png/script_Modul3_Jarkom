#!/bin/bash
# ==============================================================================
# Soal 15: Nginx Load Balancer Internal (geto) - Weighted Round Robin (3:1)
#
# Load Balancer: geto (192.221.4.3)
# Upstream Cluster:
#   - nanami (192.221.4.6) -> weight=3
#   - todo   (192.221.4.7) -> weight=1
#   - kirara (192.221.4.8) -> backup
# ==============================================================================
set -e

# ==============================================================================
# SECTION 1: Konfigurasi Load Balancer pada geto (192.221.4.3)
# ==============================================================================
setup_geto() {
    echo "[*] Mengonfigurasi Weighted Round Robin Load Balancer pada geto..."
    echo "nameserver 192.168.122.1" > /etc/resolv.conf

    apt-get update -y
    apt-get install -y nginx

    # Konfigurasi upstream cluster dengan bobot 3:1 dan backup failover
    cat << 'EOF' > /etc/nginx/sites-available/loadbalancer.conf
upstream api_cluster {
    server 192.221.4.6:80 weight=3 max_fails=2 fail_timeout=5s; # nanami
    server 192.221.4.7:80 weight=1 max_fails=2 fail_timeout=5s; # todo
    server 192.221.4.8:80 backup;                               # kirara
}

server {
    listen 80 default_server;
    server_name _;

    # Konfigurasi penerimaan IP asli dari gojo (192.221.1.4)
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

    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/loadbalancer.conf /etc/nginx/sites-enabled/loadbalancer.conf

    nginx -t
    service nginx restart 2>/dev/null || /etc/init.d/nginx restart 2>/dev/null || nginx -s reload 2>/dev/null || true
    echo "[OK] Load Balancer geto (Weighted 3:1) berhasil dikonfigurasi!"
}

# ==============================================================================
# Dispatcher Eksekusi
# ==============================================================================
TARGET="${1:-$(hostname)}"
case "$TARGET" in
    "geto")
        setup_geto
        ;;
    *)
        echo "[!] Skrip Soal 15 ditujukan untuk node: geto."
        echo "    Penggunaan: $0 geto"
        ;;
esac
