#!/bin/bash
# ==============================================================================
# Soal 16: Public Reverse Proxy (gojo) - Path-Based Routing
#
# Reverse Proxy: gojo (192.221.1.4)
# Rute Path:
#   - Path /    -> Forward ke Frontend Workers (maki & panda) - Round Robin
#   - Path /api -> Forward ke Internal Load Balancer (geto)
# ==============================================================================
set -e

# ==============================================================================
# SECTION 1: Konfigurasi Path-Based Routing pada gojo (192.221.1.4)
# ==============================================================================
setup_gojo() {
    echo "[*] Mengonfigurasi Path-Based Routing pada gojo (192.221.1.4)..."
    echo "nameserver 192.168.122.1" > /etc/resolv.conf

    apt-get update -y
    apt-get install -y nginx

    cat << 'EOF' > /etc/nginx/sites-available/jujutsu.conf
upstream frontend_workers {
    server 192.221.4.4:80; # maki
    server 192.221.4.5:80; # panda
}

upstream api_gateway {
    server 192.221.4.3:80; # geto
}

server {
    listen 80 default_server;
    server_name jujutsu.k20.com www.jujutsu.k20.com jujutsu.k-20.com www.jujutsu.k-20.com _;

    # Routing Path /api menuju internal load balancer (geto)
    location /api {
        proxy_pass http://api_gateway;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 3s;
        proxy_read_timeout 5s;
    }

    # Routing Path / menuju frontend web worker (maki & panda)
    location / {
        proxy_pass http://frontend_workers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 3s;
        proxy_read_timeout 5s;
    }
}
EOF

    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/jujutsu.conf /etc/nginx/sites-enabled/jujutsu.conf

    nginx -t
    service nginx restart 2>/dev/null || /etc/init.d/nginx restart 2>/dev/null || nginx -s reload 2>/dev/null || true
    echo "[OK] Path-Based Routing pada gojo berhasil dikonfigurasi!"
}

# ==============================================================================
# Dispatcher Eksekusi
# ==============================================================================
TARGET="${1:-$(hostname)}"
case "$TARGET" in
    "gojo")
        setup_gojo
        ;;
    *)
        echo "[!] Skrip Soal 16 ditujukan untuk node: gojo."
        echo "    Penggunaan: $0 gojo"
        ;;
esac
