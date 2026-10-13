#!/bin/bash
# ==============================================================================
# Soal 14: Backend Workers (maki, panda, nanami, todo, kirara) & Access Restrictions
# Frontend (maki, panda) hanya menerima trafik dari gojo (192.221.1.4)
# API Worker (nanami, todo, kirara) hanya menerima trafik dari geto (192.221.4.3)
# ==============================================================================
set -e

NODE=$(hostname)
echo "[*] Menjalankan Soal 14 pada node: $NODE"
echo "nameserver 192.168.122.1" > /etc/resolv.conf

if [ "$NODE" = "maki" ] || [ "$NODE" = "panda" ]; then
    echo "[*] Menyiapkan Frontend Worker pada $NODE..."
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
    cat << 'EOF' > /var/www/html/index.php
<?php
$hostname = gethostname();
echo "<h1>Hello from Frontend Web Worker: " . htmlspecialchars($hostname) . "</h1>\n";
echo "<p>Client IP: " . htmlspecialchars($_SERVER['HTTP_X_REAL_IP'] ?? $_SERVER['REMOTE_ADDR']) . "</p>\n";
?>
EOF
    chown -R www-data:www-data /var/www/html

    # Blokir akses langsung dari klien, hanya izinkan dari gojo (192.221.1.4)
    cat << EOF > /etc/nginx/sites-available/frontend.conf
server {
    listen 80 default_server;
    server_name jujutsu.k20.com www.jujutsu.k20.com _;
    root /var/www/html;
    index index.php index.html;

    # Restriksi akses Soal 14
    allow 192.221.1.4;   # gojo
    allow 192.221.4.0/24; # subnet internal DC
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
    service nginx restart 2>/dev/null || /etc/init.d/nginx restart 2>/dev/null || nginx -s reload 2>/dev/null || true
    echo "[✓] Frontend worker $NODE berhasil diamankan dan berjalan!"

elif [ "$NODE" = "nanami" ] || [ "$NODE" = "todo" ] || [ "$NODE" = "kirara" ]; then
    echo "[*] Menyiapkan API Worker pada $NODE..."
    apt-get update -y
    apt-get install -y nginx php-fpm php-mysql php-cli mariadb-client

    PHP_SERVICE=$(ls -1 /etc/init.d/php*-fpm 2>/dev/null | head -n 1 | xargs -n1 basename || true)
    if [ -n "$PHP_SERVICE" ]; then
        service "$PHP_SERVICE" start 2>/dev/null || /etc/init.d/"$PHP_SERVICE" start 2>/dev/null || true
    fi
    sleep 1
    PHP_SOCK=$(ls -1 /run/php/php*-fpm.sock 2>/dev/null | head -n 1 || true)
    if [ -z "$PHP_SOCK" ]; then PHP_SOCK="/run/php/php-fpm.sock"; fi

    mkdir -p /var/www/html
    cat << 'EOF' > /var/www/html/index.php
<?php
header('Content-Type: application/json');

$raw_ip = $_SERVER['HTTP_X_REAL_IP'] ?? $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'];
$client_ip = trim(explode(',', $raw_ip)[0]);
$worker = gethostname();
$endpoint = $_SERVER['REQUEST_URI'] ?? '/api';

$logged = false;
$db_error = null;

try {
    $pdo = new PDO("mysql:host=192.221.4.9;dbname=db_shibuya_k20;charset=utf8", "jujutsu_user", "jujutsu_password", [
        PDO::ATTR_TIMEOUT => 2,
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
    ]);
    $stmt = $pdo->prepare("INSERT INTO request_logs (client_ip, endpoint, worker) VALUES (?, ?, ?)");
    $stmt->execute([$client_ip, $endpoint, $worker]);
    $logged = true;
} catch (Exception $e) {
    $db_error = $e->getMessage();
}

echo json_encode([
    'status' => 'success',
    'worker' => $worker,
    'client_ip' => $client_ip,
    'endpoint' => $endpoint,
    'db_logged' => $logged,
    'message' => 'API response from ' . $worker
], JSON_PRETTY_PRINT) . "\n";
?>
EOF
    cp /var/www/html/index.php /var/www/html/api.php 2>/dev/null || true
    chown -R www-data:www-data /var/www/html

    # Restriksi akses: hanya izinkan dari geto (192.221.4.3)
    cat << EOF > /etc/nginx/sites-available/api_worker.conf
server {
    listen 80 default_server;
    server_name jujutsu.k20.com www.jujutsu.k20.com _;
    root /var/www/html;
    index index.php;

    # Restriksi akses Soal 14
    allow 192.221.4.3;   # geto
    allow 192.221.4.0/24; # internal DC
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
    ln -sf /etc/nginx/sites-available/api_worker.conf /etc/nginx/sites-enabled/api_worker.conf
    service nginx restart 2>/dev/null || /etc/init.d/nginx restart 2>/dev/null || nginx -s reload 2>/dev/null || true
    echo "[✓] API worker $NODE berhasil diamankan dan berjalan!"

else
    echo "[!] Skrip Soal 14 ini ditujukan untuk worker node (maki, panda, nanami, todo, kirara)."
fi
