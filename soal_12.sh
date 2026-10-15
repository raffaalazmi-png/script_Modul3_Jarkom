#!/bin/bash
# ==============================================================================
# Soal 12: A Record, CNAME, Reverse DNS (PTR), & DNS Forwarder
#
# Target:
#   - Record A Apex: jujutsu.k20.com -> gojo (192.221.1.4)
#   - Record CNAME: www.jujutsu.k20.com -> jujutsu.k20.com
#   - Reverse DNS: 192.221.1.4 -> jujutsu.k20.com (Zone: 1.221.192.in-addr.arpa)
#   - DNS Forwarder: Meneruskan query eksternal ke NAT Gateway (192.168.122.1)
# ==============================================================================
set -e

# ==============================================================================
# SECTION 1: Konfigurasi pada utahime (192.221.1.2) - Master DNS
# ==============================================================================
setup_utahime() {
    echo "[*] Mengonfigurasi PTR Record dan Reverse Zone Master pada utahime..."
    echo "nameserver 192.168.122.1" > /etc/resolv.conf

    # 1. Tambahkan deklarasi Reverse Zone pada named.conf.local jika belum ada
    if ! grep -q "1.221.192.in-addr.arpa" /etc/bind/named.conf.local 2>/dev/null; then
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

    # 2. Buat file basis data Reverse Zone PTR
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

; PTR Record untuk IP 192.221.1.4 (gojo) -> jujutsu.k20.com.
4       IN      PTR     jujutsu.k20.com.
EOF

    # 3. Validasi zona dan restart BIND9
    named-checkconf
    named-checkzone 1.221.192.in-addr.arpa /etc/bind/zones/db.1.221.192
    service bind9 restart 2>/dev/null || /etc/init.d/bind9 restart 2>/dev/null || named 2>/dev/null || true

    echo "[OK] Reverse DNS (PTR) dan Forwarder pada utahime berhasil dikonfigurasi!"
}

# ==============================================================================
# SECTION 2: Konfigurasi pada shoko (192.221.1.3) - Slave DNS
# ==============================================================================
setup_shoko() {
    echo "[*] Mengonfigurasi Reverse Zone Slave pada shoko..."
    echo "nameserver 192.168.122.1" > /etc/resolv.conf

    if ! grep -q "1.221.192.in-addr.arpa" /etc/bind/named.conf.local 2>/dev/null; then
        cat << 'EOF' >> /etc/bind/named.conf.local

zone "1.221.192.in-addr.arpa" {
    type slave;
    masters { 192.221.1.2; };
    file "/var/cache/bind/db.1.221.192";
};
EOF
        named-checkconf
        service bind9 restart 2>/dev/null || /etc/init.d/bind9 restart 2>/dev/null || named 2>/dev/null || true
    fi

    echo "[OK] Reverse DNS Slave pada shoko berhasil disinkronkan!"
}

# ==============================================================================
# Dispatcher Eksekusi
# ==============================================================================
TARGET="${1:-$(hostname)}"
case "$TARGET" in
    "utahime")
        setup_utahime
        ;;
    "shoko")
        setup_shoko
        ;;
    *)
        echo "[!] Skrip Soal 12 ditujukan untuk node: utahime atau shoko."
        echo "    Penggunaan: $0 [utahime|shoko]"
        ;;
esac
