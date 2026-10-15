#!/bin/bash
# ==============================================================================
# Soal 11: Setup BIND9 Authoritative DNS Master (utahime) & DNS Slave (shoko)
# Domain Utama: jujutsu.k20.com
# Domain Tanda-Hubung: jujutsu.k-20.com
#
# Part 1: utahime (192.221.1.2) -> DNS Master dengan allow-transfer ke shoko
# Part 2: shoko (192.221.1.3)   -> DNS Slave menarik zona dari utahime
# ==============================================================================
set -e

# ==============================================================================
# SECTION 1: Konfigurasi DNS Master pada utahime (192.221.1.2)
# ==============================================================================
setup_utahime() {
    echo "[*] Mengonfigurasi BIND9 Master pada utahime (192.221.1.2)..."
    echo "nameserver 192.168.122.1" > /etc/resolv.conf

    apt-get update -y
    apt-get install -y bind9 bind9utils dnsutils

    # 1. Konfigurasi forwarders dan opsi keamanan
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

    # 2. Deklarasi Zona Master dengan notify dan allow-transfer ke shoko (192.221.1.3)
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

    # 3. Database Forward Zone
    cat << 'EOF' > /etc/bind/zones/db.jujutsu.k20.com
$TTL    604800
@       IN      SOA     utahime.jujutsu.k20.com. hostmaster.jujutsu.k20.com. (
                              2026101301 ; Serial
                                  7200   ; Refresh (2 jam)
                                  3600   ; Retry (1 jam)
                               1209600   ; Expire (2 minggu)
                                  3600 ) ; Negative Cache TTL
;
@       IN      NS      utahime.jujutsu.k20.com.
@       IN      NS      shoko.jujutsu.k20.com.

utahime IN      A       192.221.1.2
shoko   IN      A       192.221.1.3
gojo    IN      A       192.221.1.4

; Apex domain mengarah ke public reverse proxy (gojo)
@       IN      A       192.221.1.4
www     IN      CNAME   jujutsu.k20.com.
EOF

    # 4. Validasi sintaks dan restart service
    named-checkconf
    named-checkzone jujutsu.k20.com /etc/bind/zones/db.jujutsu.k20.com
    service bind9 restart 2>/dev/null || /etc/init.d/bind9 restart 2>/dev/null || named 2>/dev/null || true

    echo "[OK] DNS Master pada utahime berhasil dikonfigurasi!"
}

# ==============================================================================
# SECTION 2: Konfigurasi DNS Slave pada shoko (192.221.1.3)
# ==============================================================================
setup_shoko() {
    echo "[*] Mengonfigurasi BIND9 Slave pada shoko (192.221.1.3)..."
    echo "nameserver 192.168.122.1" > /etc/resolv.conf

    apt-get update -y
    apt-get install -y bind9 bind9utils dnsutils

    # 1. Konfigurasi forwarders
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

    # 2. Deklarasi Zona Slave menarik dari master utahime (192.221.1.2)
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

    # 3. Validasi dan restart service
    named-checkconf
    service bind9 restart 2>/dev/null || /etc/init.d/bind9 restart 2>/dev/null || named 2>/dev/null || true

    echo "[OK] DNS Slave pada shoko berhasil dikonfigurasi!"
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
        echo "[!] Skrip Soal 11 ditujukan untuk node: utahime atau shoko."
        echo "    Penggunaan: $0 [utahime|shoko]"
        ;;
esac
