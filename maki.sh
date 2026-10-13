#!/bin/bash
# ==============================================================================
# Soal 14 & 16: Frontend Worker on maki (192.221.4.4)
# ==============================================================================
set -e

echo "nameserver 192.168.122.1" > /etc/resolv.conf

if [ ! -f /root/.configured_maki ]; then
    echo "[*] Installing Nginx and PHP-FPM on maki..."
    apt-get update -y
    apt-get install -y nginx php-fpm php-cli
    touch /root/.configured_maki
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
$hostname = gethostname();
echo "<h1>Hello from Frontend Worker: " . htmlspecialchars($hostname) . "</h1>\n";
echo "<p>Node: maki (192.221.4.4)</p>\n";
echo "<p>Client IP: " . htmlspecialchars($_SERVER['HTTP_X_REAL_IP'] ?? $_SERVER['REMOTE_ADDR']) . "</p>\n";
?>
EOF
chown -R www-data:www-data /var/www/html

cat << EOF > /etc/nginx/sites-available/frontend.conf
server {
    listen 80 default_server;
    server_name jujutsu.k20.com www.jujutsu.k20.com jujutsu.k-20.com www.jujutsu.k-20.com _;
    root /var/www/html;
    index index.php index.html;

    # Soal 14: Restrict direct client access, only accept from gojo (192.221.1.4)
    allow 192.221.1.4; # gojo proxy
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
ln -sf /etc/nginx/sites-available/frontend.conf /etc/nginx/sites-enabled/frontend.conf

service nginx restart 2>/dev/null || /etc/init.d/nginx restart 2>/dev/null || nginx -s reload 2>/dev/null || true
echo "[OK] Maki frontend worker configured and running."
