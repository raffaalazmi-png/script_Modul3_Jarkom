#!/bin/bash
# ==============================================================================
# Soal 15: Nginx Load Balancer Internal (geto) - Weighted Round Robin (3:1)
# nanami (weight=3) : todo (weight=1)
# ==============================================================================
set -e

NODE=$(hostname)
echo "[*] Menjalankan Soal 15 pada node: $NODE"
echo "nameserver 192.168.122.1" > /etc/resolv.conf

if [ "$NODE" = "geto" ]; then
    echo "[*] Mengonfigurasi Weighted Round Robin Load Balancer pada geto..."
    apt-get update -y
    apt-get install -y nginx

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

    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/loadbalancer.conf /etc/nginx/sites-enabled/loadbalancer.conf
    service nginx restart 2>/dev/null || /etc/init.d/nginx restart 2>/dev/null || nginx -s reload 2>/dev/null || true
    echo "[✓] Geto Load Balancer (Weighted 3:1) berhasil dikonfigurasi!"
else
    echo "[!] Skrip Soal 15 ini ditujukan untuk node: geto."
fi
