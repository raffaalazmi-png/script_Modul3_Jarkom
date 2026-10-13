#!/bin/bash
# ==============================================================================
# Soal 13 & 17: MariaDB Master Setup on yaga (192.221.4.9)
# Database: db_shibuya_k20, Table: request_logs
# ==============================================================================
set -e

echo "nameserver 192.168.122.1" > /etc/resolv.conf

if [ ! -f /root/.configured_yaga ]; then
    echo "[*] Installing MariaDB Server on yaga..."
    apt-get update -y
    apt-get install -y mariadb-server mariadb-client
    touch /root/.configured_yaga
fi

mkdir -p /etc/mysql/mariadb.conf.d/
cat << 'EOF' > /etc/mysql/mariadb.conf.d/60-master.cnf
[mysqld]
bind-address            = 0.0.0.0
server-id               = 1
log_bin                 = /var/log/mysql/mariadb-bin
binlog_format           = ROW
binlog_do_db            = db_shibuya_k20
binlog_do_db            = db_shibuya_k_20
EOF

service mariadb restart 2>/dev/null || service mysql restart 2>/dev/null || /etc/init.d/mysql restart 2>/dev/null || true
sleep 2

mysql -uroot << 'EOF'
CREATE DATABASE IF NOT EXISTS db_shibuya_k20;
CREATE TABLE IF NOT EXISTS db_shibuya_k20.request_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    client_ip VARCHAR(50) NOT NULL,
    request_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    endpoint VARCHAR(255) DEFAULT '/api',
    worker VARCHAR(50) DEFAULT NULL
);

CREATE DATABASE IF NOT EXISTS db_shibuya_k_20;
CREATE TABLE IF NOT EXISTS db_shibuya_k_20.request_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    client_ip VARCHAR(50) NOT NULL,
    request_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    endpoint VARCHAR(255) DEFAULT '/api',
    worker VARCHAR(50) DEFAULT NULL
);

CREATE USER IF NOT EXISTS 'replica_user'@'%' IDENTIFIED BY 'replica_password';
GRANT REPLICATION SLAVE ON *.* TO 'replica_user'@'%';

CREATE USER IF NOT EXISTS 'jujutsu_user'@'%' IDENTIFIED BY 'jujutsu_password';
GRANT ALL PRIVILEGES ON *.* TO 'jujutsu_user'@'%';

GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root';
FLUSH PRIVILEGES;
EOF

echo "[OK] Yaga DB Master configured and running."
