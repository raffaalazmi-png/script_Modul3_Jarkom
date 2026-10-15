#!/bin/bash
# ==============================================================================
# Soal 14: Backend Workers (maki, panda, nanami, todo, kirara) & Access Restrictions
#
# Part 1: Frontend Workers (maki & panda)
#         - Menyajikan aplikasi web beranda
#         - Restriksi akses: Hanya menerima koneksi dari gojo (192.221.1.4)
# Part 2: API Workers (nanami, todo, kirara)
#         - Menyajikan endpoint layanan API
#         - Restriksi akses: Hanya menerima koneksi dari geto (192.221.4.3)
# ==============================================================================
set -e

# ==============================================================================
# SECTION 1: Konfigurasi Frontend Worker (maki & panda)
# ==============================================================================
setup_frontend_worker() {
    NODE_NAME="$1"
    echo "[*] Menyiapkan Frontend Worker pada $NODE_NAME..."
    echo "nameserver 192.168.122.1" > /etc/resolv.conf

    apt-get update -y
    apt-get install -y nginx php-fpm php-cli

    PHP_SERVICE=$(ls -1 /etc/init.d/php*-fpm 2>/dev/null | head -n 1 | xargs -n1 basename || true)
    if [ -n "$PHP_SERVICE" ]; then
        service "$PHP_SERVICE" start 2>/dev/null || /etc/init.d/"$PHP_SERVICE" start 2>/dev/null || true
    fi
    sleep 1
    PHP_SOCK=$(ls -1 /run/php/php*-fpm.sock 2>/dev/null | head -n 1 || true)
    if [ -z "$PHP_SOCK" ]; then PHP_SOCK="/run/php/php-fpm.sock"; fi

    mkdir -p /var/www/html
    cat << EOF > /var/www/html/index.php
<?php
\$hostname = gethostname();
\$client_ip = \$_SERVER['HTTP_X_REAL_IP'] ?? \$_SERVER['REMOTE_ADDR'];
echo "<h1>Hello from Frontend Web Worker: " . htmlspecialchars(\$hostname) . "</h1>\n";
echo "<p>Client IP: " . htmlspecialchars(\$client_ip) . "</p>\n";
?>
EOF
    chown -R www-data:www-data /var/www/html

    # Konfigurasi VirtualHost dengan pembatasan akses ketat
    cat << EOF > /etc/nginx/sites-available/frontend.conf
server {
    listen 80 default_server;
    server_name jujutsu.k20.com www.jujutsu.k20.com _;
    root /var/www/html;
    index index.php index.html;

    # Restriksi akses Soal 14: Hanya izinkan public reverse proxy gojo dan subnet lokal
    allow 192.221.1.4;    # gojo
    allow 192.221.4.0/24;  # Data Center internal subnet
    allow 127.0.0.1;
    deny all;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_SOCK;
    }
}
EOF

    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/frontend.conf /etc/nginx/sites-enabled/frontend.conf

    nginx -t
    service nginx restart 2>/dev/null || /etc/init.d/nginx restart 2>/dev/null || nginx -s reload 2>/dev/null || true
    echo "[OK] Frontend Worker pada $NODE_NAME berhasil dikonfigurasi!"
}

# ==============================================================================
# SECTION 2: Konfigurasi API Worker (nanami, todo, kirara)
# ==============================================================================
setup_api_worker() {
    NODE_NAME="$1"
    echo "[*] Menyiapkan API Worker pada $NODE_NAME..."
    echo "nameserver 192.168.122.1" > /etc/resolv.conf

    apt-get update -y
    apt-get install -y nginx php-fpm php-cli php-mysql mariadb-client

    PHP_SERVICE=$(ls -1 /etc/init.d/php*-fpm 2>/dev/null | head -n 1 | xargs -n1 basename || true)
    if [ -n "$PHP_SERVICE" ]; then
        service "$PHP_SERVICE" start 2>/dev/null || /etc/init.d/"$PHP_SERVICE" start 2>/dev/null || true
    fi
    sleep 1
    PHP_SOCK=$(ls -1 /run/php/php*-fpm.sock 2>/dev/null | head -n 1 || true)
    if [ -z "$PHP_SOCK" ]; then PHP_SOCK="/run/php/php-fpm.sock"; fi

    mkdir -p /var/www/api
    cat << EOF > /var/www/api/index.php
<?php
header('Content-Type: application/json');
\$worker = gethostname();
\$client_ip = \$_SERVER['HTTP_X_REAL_IP'] ?? \$_SERVER['REMOTE_ADDR'];

// Pencatatan log ke MariaDB Master (yaga: 192.221.4.9)
\$db_host = '192.221.4.9';
\$db_user = 'jujutsu_user';
\$db_pass = 'jujutsu_password';
\$db_name = 'db_shibuya_k20';

\$logged = false;
try {
    \$conn = @new mysqli(\$db_host, \$db_user, \$db_pass, \$db_name, 3306);
    if (!\$conn->connect_error) {
        \$stmt = \$conn->prepare("INSERT INTO request_logs (client_ip, endpoint, worker) VALUES (?, ?, ?)");
        if (\$stmt) {
            \$endpoint = '/api';
            \$stmt->bind_param("sss", \$client_ip, \$endpoint, \$worker);
            \$stmt->execute();
            \$stmt->close();
            \$logged = true;
        }
        \$conn->close();
    }
} catch (Exception \$e) {
    // Log exception ignored
}

echo json_encode([
    'status' => 'success',
    'message' => 'API Worker Response',
    'worker' => \$worker,
    'client_ip' => \$client_ip,
    'db_logged' => \$logged,
    'timestamp' => date('Y-m-d H:i:s')
], JSON_PRETTY_PRINT);
?>
EOF
    chown -R www-data:www-data /var/www/api

    # Konfigurasi VirtualHost API dengan pembatasan akses ketat
    cat << EOF > /etc/nginx/sites-available/api.conf
server {
    listen 80 default_server;
    server_name _;
    root /var/www/api;
    index index.php index.html;

    # Restriksi akses Soal 14: Hanya izinkan internal load balancer geto dan subnet lokal
    allow 192.221.4.3;    # geto
    allow 192.221.4.0/24;  # Data Center internal subnet
    allow 127.0.0.1;
    deny all;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location /api {
        alias /var/www/api;
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_SOCK;
    }
}
EOF

    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/api.conf /etc/nginx/sites-enabled/api.conf

    nginx -t
    service nginx restart 2>/dev/null || /etc/init.d/nginx restart 2>/dev/null || nginx -s reload 2>/dev/null || true
    echo "[OK] API Worker pada $NODE_NAME berhasil dikonfigurasi!"
}

# ==============================================================================
# Dispatcher Eksekusi
# ==============================================================================
TARGET="${1:-$(hostname)}"
case "$TARGET" in
    "maki"|"panda")
        setup_frontend_worker "$TARGET"
        ;;
    "nanami"|"todo"|"kirara")
        setup_api_worker "$TARGET"
        ;;
    *)
        echo "[!] Skrip Soal 14 ditujukan untuk node: maki, panda, nanami, todo, atau kirara."
        echo "    Penggunaan: $0 [node_name]"
        ;;
esac
