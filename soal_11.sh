#!/bin/bash
# ==============================================================================
# Soal 11: Setup BIND9 DNS Master (utahime) dan DNS Slave (shoko)
# Domain: jujutsu.k20.com
# ==============================================================================
set -e

NODE=$(hostname)
echo "[*] Menjalankan Soal 11 pada node: $NODE"
echo "nameserver 192.168.122.1" > /etc/resolv.conf

if [ "$NODE" = "utahime" ]; then
    echo "[*] Mengonfigurasi BIND9 Master pada utahime (192.221.1.2)..."
    apt-get update -y
    apt-get install -y bind9 bind9utils dnsutils

    # 1. Konfigurasi named.conf.options
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

    # 2. Deklarasi Zona Master dengan allow-transfer ke shoko (192.221.1.3)
    mkdir -p /etc/bind/zones
    cat << 'EOF' > /etc/bind/named.conf.local
zone "jujutsu.k20.com" {
    type master;
    notify yes;
    also-notify { 192.221.1.3; };
    allow-transfer { 192.221.1.3; };
    file "/etc/bind/zones/db.jujutsu.k20.com";
};

zone "jujutsu.k-20.com" {
    type master;
    notify yes;
    also-notify { 192.221.1.3; };
    allow-transfer { 192.221.1.3; };
    file "/etc/bind/zones/db.jujutsu.k20.com";
};
EOF

    # 3. File database forward zone
    cat << 'EOF' > /etc/bind/zones/db.jujutsu.k20.com
$TTL    604800
@       IN      SOA     utahime.jujutsu.k20.com. hostmaster.jujutsu.k20.com. (
                              2026101301 ; Serial
                                  7200   ; Refresh
                                  3600   ; Retry
                               1209600   ; Expire
                                  3600 ) ; Negative Cache TTL
;
@       IN      NS      utahime.jujutsu.k20.com.
@       IN      NS      shoko.jujutsu.k20.com.

utahime IN      A       192.221.1.2
shoko   IN      A       192.221.1.3
gojo    IN      A       192.221.1.4

@       IN      A       192.221.1.4
www     IN      CNAME   jujutsu.k20.com.
EOF

    service bind9 restart 2>/dev/null || /etc/init.d/bind9 restart 2>/dev/null || named 2>/dev/null || true
    echo "[✓] Utahime (DNS Master) selesai dikonfigurasi!"

elif [ "$NODE" = "shoko" ]; then
    echo "[*] Mengonfigurasi BIND9 Slave pada shoko (192.221.1.3)..."
    apt-get update -y
    apt-get install -y bind9 bind9utils dnsutils

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
EOF

    service bind9 restart 2>/dev/null || /etc/init.d/bind9 restart 2>/dev/null || named 2>/dev/null || true
    echo "[✓] Shoko (DNS Slave) selesai dikonfigurasi!"

else
    echo "[!] Skrip Soal 11 ini ditujukan untuk node: utahime atau shoko."
fi
