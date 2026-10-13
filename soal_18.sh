#!/bin/bash
# ==============================================================================
# Soal 18: Backup Server (kirara) & Passive Health Check pada geto
# max_fails=2 fail_timeout=5s pada nanami & todo
# ==============================================================================
set -e

NODE=$(hostname)
echo "[*] Menjalankan Soal 18 pada node: $NODE"

if [ "$NODE" = "geto" ]; then
    echo "[*] Memastikan konfigurasi backup server dan health check aktif di geto..."
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
    service nginx restart 2>/dev/null || /etc/init.d/nginx restart 2>/dev/null || nginx -s reload 2>/dev/null || true
    echo "[✓] Geto failover dan passive health check aktif!"

elif [ "$NODE" = "kirara" ]; then
    echo "[*] Memastikan layanan API kompatibel pada kirara..."
    bash /root/kirara.sh
    echo "[✓] Kirara backup API worker siap melayani fallback!"

else
    echo "[!] Skrip Soal 18 ditujukan untuk node: geto dan kirara."
fi
