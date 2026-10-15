#!/bin/bash
# ==============================================================================
# Soal 19: Nginx Proxy Caching (10 Menit) & Rate Limiting (10 r/s) pada gojo
#
# Target:
#   - Proxy Caching: Path / disimpan dalam memori cache selama 10 menit
#   - Header Status Cache: X-Cache-Status disematkan pada setiap respon HTTP
#   - Rate Limiting: Path /api dibatasi maksimal 10 request/detik per IP klien
#   - Kode Penolakan: HTTP 503 Service Unavailable jika melebihi batas rate
# ==============================================================================
set -e

# ==============================================================================
# SECTION 1: Konfigurasi Cache dan Rate Limiting pada gojo (192.221.1.4)
# ==============================================================================
setup_gojo() {
    echo "[*] Mengaktifkan Proxy Caching dan Rate Limiting pada gojo..."
    echo "nameserver 192.168.122.1" > /etc/resolv.conf

    mkdir -p /var/cache/nginx/proxy
    chown -R www-data:www-data /var/cache/nginx

    # 1. Definisi zone memori caching dan pembatasan frekuensi (rate limit)
    cat << 'EOF' > /etc/nginx/conf.d/cache_limit.conf
proxy_cache_path /var/cache/nginx/proxy levels=1:2 keys_zone=FRONTEND_CACHE:10m max_size=100m inactive=60m use_temp_path=off;
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
EOF

    # 2. VirtualHost Nginx dengan penerapan caching dan rate limiting
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

    # Rate limiting pada /api: 10 request/detik per IP klien
    location /api {
        limit_req zone=api_limit nodelay;
        limit_req_status 503;

        proxy_pass http://api_gateway;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 3s;
        proxy_read_timeout 5s;
    }

    # Proxy caching pada /: Cache valid selama 10 menit
    location / {
        proxy_pass http://frontend_workers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_cache FRONTEND_CACHE;
        proxy_cache_valid 200 302 10m;
        add_header X-Cache-Status $upstream_cache_status always;

        proxy_connect_timeout 3s;
        proxy_read_timeout 5s;
    }
}
EOF

    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/jujutsu.conf /etc/nginx/sites-enabled/jujutsu.conf

    nginx -t
    service nginx restart 2>/dev/null || /etc/init.d/nginx restart 2>/dev/null || nginx -s reload 2>/dev/null || true
    echo "[OK] Proxy Caching (10m) dan Rate Limiting (10r/s) pada gojo berhasil diaktifkan!"
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
        echo "[!] Skrip Soal 19 ditujukan untuk node: gojo."
        echo "    Penggunaan: $0 gojo"
        ;;
esac
