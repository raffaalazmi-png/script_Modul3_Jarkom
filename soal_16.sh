#!/bin/bash
# ==============================================================================
# Soal 16: Public Reverse Proxy (gojo) - Path-Based Routing
# /    -> Forward ke maki & panda (Round Robin)
# /api -> Forward ke geto (Internal Load Balancer)
# ==============================================================================
set -e

NODE=$(hostname)
echo "[*] Menjalankan Soal 16 pada node: $NODE"
echo "nameserver 192.168.122.1" > /etc/resolv.conf

if [ "$NODE" = "gojo" ]; then
    echo "[*] Mengonfigurasi Path-Based Routing pada gojo (192.221.1.4)..."
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
    server_name jujutsu.k20.com www.jujutsu.k20.com jujutsu.k-20.com _;

    # Path /api menuju geto
    location /api {
        proxy_pass http://api_gateway;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 3s;
        proxy_read_timeout 5s;
    }

    # Root / menuju frontend maki & panda
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
    service nginx restart 2>/dev/null || /etc/init.d/nginx restart 2>/dev/null || nginx -s reload 2>/dev/null || true
    echo "[✓] Gojo Path-Based Routing berhasil dikonfigurasi!"
else
    echo "[!] Skrip Soal 16 ini ditujukan untuk node: gojo."
fi
