#!/bin/bash
# ==============================================================================
# Soal 14, 15, 17, 18: API Worker on nanami (192.221.4.6)
# ==============================================================================
set -e

echo "nameserver 192.168.122.1" > /etc/resolv.conf

if [ ! -f /root/.configured_nanami ]; then
    echo "[*] Installing Nginx, PHP-FPM, and PHP MySQL on nanami..."
    apt-get update -y
    apt-get install -y nginx php-fpm php-mysql php-cli mariadb-client
    touch /root/.configured_nanami
fi

PHP_SERVICE=$(ls -1 /etc/init.d/php*-fpm 2>/dev/null | head -n 1 | xargs -n1 basename || true)
if [ -n "$PHP_SERVICE" ]; then
    service "$PHP_SERVICE" start 2>/dev/null || /etc/init.d/"$PHP_SERVICE" start 2>/dev/null || true
fi
sleep 1
PHP_SOCK=$(ls -1 /run/php/php*-fpm.sock 2>/dev/null | head -n 1 || true)
if [ -z "$PHP_SOCK" ]; then
    PHP_SOCK="/run/php/php-fpm.sock"
fi

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

cat << EOF > /etc/nginx/sites-available/api_worker.conf
server {
    listen 80 default_server;
    server_name jujutsu.k20.com www.jujutsu.k20.com _;
    root /var/www/html;
    index index.php;

    # Soal 14: Restrict direct client access, only accept from geto (192.221.4.3)
    allow 192.221.4.3; # geto
    allow 192.221.4.0/24; # DC subnet
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
echo "[OK] Nanami API worker configured and running."
