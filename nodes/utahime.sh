#!/bin/bash
# ==============================================================================
# Soal 11 & 12: DNS Master Setup on utahime (192.221.1.2)
# Domain: jujutsu.k20.com
# ==============================================================================
set -e

echo "nameserver 192.168.122.1" > /etc/resolv.conf

if [ ! -f /root/.configured_utahime ]; then
    echo "[*] Installing BIND9 and DNS utilities on utahime..."
    apt-get update -y
    apt-get install -y bind9 bind9utils dnsutils
    touch /root/.configured_utahime
fi

# 1. BIND options (DNS Forwarder to 192.168.122.1)
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

# 2. Local Zone definitions (Master with allow-transfer to shoko 192.221.1.3)
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

zone "1.221.192.in-addr.arpa" {
    type master;
    notify yes;
    also-notify { 192.221.1.3; };
    allow-transfer { 192.221.1.3; };
    file "/etc/bind/zones/db.1.221.192";
};
EOF

# 3. Forward Zone File for jujutsu.k20.com
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

# 4. Reverse Zone File for 192.221.1.X (PTR gojo 192.221.1.4 -> jujutsu.k20.com)
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
echo "[OK] Utahime DNS Master configured and running."
