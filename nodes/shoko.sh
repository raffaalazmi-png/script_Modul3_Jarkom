#!/bin/bash
# ==============================================================================
# Soal 11: DNS Slave Setup on shoko (192.221.1.3)
# ==============================================================================
set -e

echo "nameserver 192.168.122.1" > /etc/resolv.conf

if [ ! -f /root/.configured_shoko ]; then
    echo "[*] Installing BIND9 and DNS utilities on shoko..."
    apt-get update -y
    apt-get install -y bind9 bind9utils dnsutils
    touch /root/.configured_shoko
fi

cat << 'EOF' > /etc/bind/named.conf.options
options {
    directory "/var/cache/bind";

    forwarders {
        192.168.122.1;
    };

    allow-query { any; };
    allow-recursion { any; };
    dnssec-validation no;
    auth-nxdomain no;
    listen-on-v6 { any; };
};
EOF

cat << 'EOF' > /etc/bind/named.conf.local
zone "jujutsu.k20.com" {
    type slave;
    masters { 192.221.1.2; };
    file "/var/cache/bind/db.jujutsu.k20.com";
};

zone "jujutsu.k-20.com" {
    type slave;
    masters { 192.221.1.2; };
    file "/var/cache/bind/db.jujutsu.k20.com";
};

zone "1.221.192.in-addr.arpa" {
    type slave;
    masters { 192.221.1.2; };
    file "/var/cache/bind/db.1.221.192";
};
EOF

service bind9 restart 2>/dev/null || /etc/init.d/bind9 restart 2>/dev/null || named 2>/dev/null || true
echo "[OK] Shoko DNS Slave configured and running."
