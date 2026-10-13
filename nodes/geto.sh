#!/bin/bash
# ==============================================================================
# Soal 14, 15, 17, 18: Internal Load Balancer on geto (192.221.4.3)
# Upstream: nanami (weight 3), todo (weight 1), kirara (backup)
# ==============================================================================
set -e

echo "nameserver 192.168.122.1" > /etc/resolv.conf

if [ ! -f /root/.configured_geto ]; then
    echo "[*] Installing Nginx on geto..."
    apt-get update -y
    apt-get install -y nginx
    touch /root/.configured_geto
fi

cat << 'EOF' > /etc/nginx/sites-available/loadbalancer.conf
# Soal 15 & 18: Weighted Round Robin 3:1 (nanami:todo), kirara backup, passive health check max_fails=2 fail_timeout=5s
upstream api_cluster {
    server 192.221.4.6:80 weight=3 max_fails=2 fail_timeout=5s; # nanami
    server 192.221.4.7:80 weight=1 max_fails=2 fail_timeout=5s; # todo
    server 192.221.4.8:80 backup;                               # kirara
}

server {
    listen 80 default_server;
    server_name _;

    # Soal 17: Trust client IP from gojo (192.221.1.4)
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
echo "[OK] Geto Load Balancer configured and running."
