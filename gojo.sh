#!/bin/bash
# ==============================================================================
# Soal 16, 17, 19: Public Reverse Proxy, Caching, and Rate Limiting on gojo (192.221.1.4)
# ==============================================================================
set -e

echo "nameserver 192.168.122.1" > /etc/resolv.conf

if [ ! -f /root/.configured_gojo ]; then
    echo "[*] Installing Nginx on gojo..."
    apt-get update -y
    apt-get install -y nginx
    touch /root/.configured_gojo
fi

mkdir -p /var/cache/nginx/proxy
chown -R www-data:www-data /var/cache/nginx

cat << 'EOF' > /etc/nginx/conf.d/cache_limit.conf
proxy_cache_path /var/cache/nginx/proxy levels=1:2 keys_zone=FRONTEND_CACHE:10m max_size=100m inactive=60m use_temp_path=off;
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
EOF

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

    # Soal 16 & 19: Path /api -> Forward to geto with Rate Limiting (10r/s)
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

    # Soal 16 & 19: Root / -> Forward to maki/panda with Caching (10m) & Header X-Cache-Status
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

service nginx restart 2>/dev/null || /etc/init.d/nginx restart 2>/dev/null || nginx -s reload 2>/dev/null || true
echo "[OK] Gojo Public Reverse Proxy configured and running."
