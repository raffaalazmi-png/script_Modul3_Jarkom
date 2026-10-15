#!/bin/bash
# ==============================================================================
# Soal 13: MariaDB Master (yaga) & Slave (inumaki) Database Replication
#
# Master : yaga (192.221.4.9)   -> server-id=1, log_bin, binlog_format=ROW
# Slave  : inumaki (192.221.4.11)-> server-id=2, relay_log, read_only=1
# Basis Data: db_shibuya_k20, Tabel: request_logs
# ==============================================================================
set -e

# ==============================================================================
# SECTION 1: Konfigurasi MariaDB Master pada yaga (192.221.4.9)
# ==============================================================================
setup_yaga() {
    echo "[*] Mengonfigurasi MariaDB Master pada yaga (192.221.4.9)..."
    echo "nameserver 192.168.122.1" > /etc/resolv.conf

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

    # Inisialisasi basis data, skema tabel, dan akun replikasi
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

    echo "[OK] MariaDB Master pada yaga berhasil disiapkan!"
    mysql -uroot -e "SHOW MASTER STATUS\G" || true
}

# ==============================================================================
# SECTION 2: Konfigurasi MariaDB Slave pada inumaki (192.221.4.11)
# ==============================================================================
setup_inumaki() {
    echo "[*] Mengonfigurasi MariaDB Slave pada inumaki (192.221.4.11)..."
    echo "nameserver 192.168.122.1" > /etc/resolv.conf

    apt-get update -y
    apt-get install -y mariadb-server mariadb-client

    mkdir -p /etc/mysql/mariadb.conf.d/
    cat << 'EOF' > /etc/mysql/mariadb.conf.d/60-slave.cnf
[mysqld]
bind-address            = 0.0.0.0
server-id               = 2
relay_log               = /var/log/mysql/mariadb-relay-bin
read_only               = 1
replicate_do_db         = db_shibuya_k20
replicate_do_db         = db_shibuya_k_20
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

STOP SLAVE;
CHANGE MASTER TO
    MASTER_HOST='192.221.4.9',
    MASTER_USER='replica_user',
    MASTER_PASSWORD='replica_password',
    MASTER_CONNECT_RETRY=10;
START SLAVE;
EOF

    echo "[OK] MariaDB Slave pada inumaki berhasil disiapkan!"
    mysql -uroot -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master" || true
}

# ==============================================================================
# Dispatcher Eksekusi
# ==============================================================================
TARGET="${1:-$(hostname)}"
case "$TARGET" in
    "yaga")
        setup_yaga
        ;;
    "inumaki")
        setup_inumaki
        ;;
    *)
        echo "[!] Skrip Soal 13 ditujukan untuk node: yaga atau inumaki."
        echo "    Penggunaan: $0 [yaga|inumaki]"
        ;;
esac
