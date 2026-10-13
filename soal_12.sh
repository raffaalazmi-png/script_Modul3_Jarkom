#!/bin/bash
# ==============================================================================
# Soal 12: A Record, CNAME, Reverse DNS (PTR), & DNS Forwarder pada utahime (Master)
# Target: A jujutsu.k20.com -> gojo (192.221.1.4), CNAME www, PTR 192.221.1.4
# ==============================================================================
set -e

NODE=$(hostname)
echo "[*] Menjalankan Soal 12 pada node: $NODE"
echo "nameserver 192.168.122.1" > /etc/resolv.conf

if [ "$NODE" = "utahime" ]; then
    # 1. Forwarder sudah aktif di named.conf.options mengarah ke 192.168.122.1
    # 2. Tambahkan Reverse Zone pada named.conf.local
    if ! grep -q "1.221.192.in-addr.arpa" /etc/bind/named.conf.local; then
        cat << 'EOF' >> /etc/bind/named.conf.local

zone "1.221.192.in-addr.arpa" {
    type master;
    notify yes;
    also-notify { 192.221.1.3; };
    allow-transfer { 192.221.1.3; };
    file "/etc/bind/zones/db.1.221.192";
};
EOF
    fi

    mkdir -p /etc/bind/zones
    # 3. Buat file zona reverse PTR
    cat << 'EOF' > /etc/bind/zones/db.1.221.192
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

4       IN      PTR     jujutsu.k20.com.
EOF

    service bind9 restart 2>/dev/null || /etc/init.d/bind9 restart 2>/dev/null || named 2>/dev/null || true
    echo "[✓] Reverse DNS (PTR), CNAME, dan Forwarder pada utahime berhasil dikonfigurasi!"

elif [ "$NODE" = "shoko" ]; then
    if ! grep -q "1.221.192.in-addr.arpa" /etc/bind/named.conf.local; then
        cat << 'EOF' >> /etc/bind/named.conf.local

zone "1.221.192.in-addr.arpa" {
    type slave;
    masters { 192.221.1.2; };
    file "/var/cache/bind/db.1.221.192";
};
EOF
        service bind9 restart 2>/dev/null || /etc/init.d/bind9 restart 2>/dev/null || named 2>/dev/null || true
        echo "[✓] Reverse DNS Slave pada shoko disinkronkan!"
    fi
else
    echo "[!] Skrip Soal 12 ini ditujukan untuk node: utahime."
fi
