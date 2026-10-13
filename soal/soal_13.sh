#!/bin/bash
# ==============================================================================
# Soal 13: MariaDB Master (yaga) & Slave (inumaki) Database Replication
# Database: db_shibuya_k20, Table: request_logs
# ==============================================================================
set -e

NODE=$(hostname)
echo "[*] Menjalankan Soal 13 pada node: $NODE"
echo "nameserver 192.168.122.1" > /etc/resolv.conf

if [ "$NODE" = "yaga" ]; then
    echo "[*] Mengonfigurasi MariaDB Master pada yaga (192.221.4.9)..."
    apt-get update -y
    apt-get install -y mariadb-server mariadb-client

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

CREATE USER IF NOT EXISTS 'replica_user'@'%' IDENTIFIED BY 'replica_password';
GRANT REPLICATION SLAVE ON *.* TO 'replica_user'@'%';

CREATE USER IF NOT EXISTS 'jujutsu_user'@'%' IDENTIFIED BY 'jujutsu_password';
GRANT ALL PRIVILEGES ON *.* TO 'jujutsu_user'@'%';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root';
FLUSH PRIVILEGES;
EOF
    echo "[✓] MariaDB Master pada yaga berhasil disiapkan!"

elif [ "$NODE" = "inumaki" ]; then
    echo "[*] Mengonfigurasi MariaDB Slave pada inumaki (192.221.4.11)..."
    apt-get update -y
    apt-get install -y mariadb-server mariadb-client

    mkdir -p /etc/mysql/mariadb.conf.d/
    cat << 'EOF' > /etc/mysql/mariadb.conf.d/60-slave.cnf
[mysqld]
bind-address            = 0.0.0.0
server-id               = 2
EOF

    service mariadb restart 2>/dev/null || service mysql restart 2>/dev/null || /etc/init.d/mysql restart 2>/dev/null || true
    sleep 2

    mysql -uroot << 'EOF'
STOP SLAVE;
CHANGE MASTER TO
    MASTER_HOST='192.221.4.9',
    MASTER_USER='replica_user',
    MASTER_PASSWORD='replica_password',
    MASTER_PORT=3306,
    MASTER_CONNECT_RETRY=10;
START SLAVE;
EOF
    echo "[✓] MariaDB Slave pada inumaki berhasil terhubung ke yaga!"

else
    echo "[!] Skrip Soal 13 ini ditujukan untuk node: yaga atau inumaki."
fi
