#!/bin/bash
# ==============================================================================
# Soal 13: MariaDB Slave Setup on inumaki (192.221.4.11)
# ==============================================================================
set -e

echo "nameserver 192.168.122.1" > /etc/resolv.conf

if [ ! -f /root/.configured_inumaki ]; then
    echo "[*] Installing MariaDB Server on inumaki..."
    apt-get update -y
    apt-get install -y mariadb-server mariadb-client
    touch /root/.configured_inumaki
fi

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

echo "[OK] Inumaki DB Slave configured and replicating."
