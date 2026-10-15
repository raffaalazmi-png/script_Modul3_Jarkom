# Laporan Resmi Praktikum Modul-3

**Kelompok: K-20**  
- **Domain Utama:** `jujutsu.k20.com`  
- **Domain Tanda-Hubung:** `jujutsu.k-20.com`  
- **Prefix Subnet:** `192.221.X.X`  
- **Fokus Implementasi:** Soal 11 hingga 20 (Network 1 DMZ & Network 4 Data Center)

---

## Ringkasan Alokasi IP Address & Peran Node

| Subnet | Node | Interface | IP Address | Netmask | Gateway | Peran & Tanggung Jawab |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Router** | **jichi** | `eth0-eth4` | `192.221.1.1` & `192.221.4.1` | `255.255.255.0` | NAT Gateway | Router Sentral / Gateway Subnet |
| **Subnet 1 (DMZ)** | **utahime** | `eth0` | `192.221.1.2` | `255.255.255.0` | `192.221.1.1` | Authoritative DNS Master (BIND9) |
| **Subnet 1 (DMZ)** | **shoko** | `eth0` | `192.221.1.3` | `255.255.255.0` | `192.221.1.1` | Authoritative DNS Slave (BIND9) |
| **Subnet 1 (DMZ)** | **gojo** | `eth0` | `192.221.1.4` | `255.255.255.0` | `192.221.1.1` | Public Reverse Proxy, Caching, & Rate Limiting |
| **Subnet 4 (DC)** | **geto** | `eth0` | `192.221.4.3` | `255.255.255.0` | `192.221.4.1` | Internal Load Balancer & Health Check (Nginx) |
| **Subnet 4 (DC)** | **maki** | `eth0` | `192.221.4.4` | `255.255.255.0` | `192.221.4.1` | Frontend Web Worker 1 (Nginx + PHP-FPM) |
| **Subnet 4 (DC)** | **panda** | `eth0` | `192.221.4.5` | `255.255.255.0` | `192.221.4.1` | Frontend Web Worker 2 (Nginx + PHP-FPM) |
| **Subnet 4 (DC)** | **nanami** | `eth0` | `192.221.4.6` | `255.255.255.0` | `192.221.4.1` | API Worker Utama 1 (Weight 3) (Nginx + PHP-FPM) |
| **Subnet 4 (DC)** | **todo** | `eth0` | `192.221.4.7` | `255.255.255.0` | `192.221.4.1` | API Worker Utama 2 (Weight 1) (Nginx + PHP-FPM) |
| **Subnet 4 (DC)** | **kirara** | `eth0` | `192.221.4.8` | `255.255.255.0` | `192.221.4.1` | API Worker Cadangan (Backup Server) |
| **Subnet 4 (DC)** | **yaga** | `eth0` | `192.221.4.9` | `255.255.255.0` | `192.221.4.1` | MariaDB Master Database & Request Logging |
| **Subnet 4 (DC)** | **inumaki** | `eth0` | `192.221.4.11` | `255.255.255.0` | `192.221.4.1` | MariaDB Slave Database Replication |
| **Client** | **kusakabe** | `eth0` | Dynamic (DHCP) | `255.255.255.0` | Gateway Subnet | Node Klien Penguji (curl, dig, ab) |

---

## Panduan Penggunaan Skrip

Repositori ini menyediakan dua metode eksekusi:

### Metode 1: Eksekusi Otomatis Per-Node (.bashrc)
Untuk menyederhanakan konfigurasi pada lingkungan GNS3, setiap node memiliki skrip independen yang dapat langsung dijalankan saat startup melalui `/root/.bashrc`:
```bash
# Contoh pada node utahime:
echo "bash /root/utahime.sh" >> /root/.bashrc

# Contoh pada node gojo:
echo "bash /root/gojo.sh" >> /root/.bashrc
```

Daftar file skrip per-node:
* `utahime.sh` : DNS Master BIND9 (Soal 11, 12)
* `shoko.sh`   : DNS Slave BIND9 (Soal 11, 12)
* `gojo.sh`    : Public Reverse Proxy, Caching, & Rate Limiting (Soal 12, 16, 17, 19)
* `geto.sh`    : Internal Load Balancer Weighted Round Robin (Soal 14, 15, 17, 18)
* `maki.sh`    : Frontend Web Worker 1 (Soal 14, 16)
* `panda.sh`   : Frontend Web Worker 2 (Soal 14, 16)
* `nanami.sh`  : API Worker Utama Bobot 3 (Soal 14, 15, 17, 18)
* `todo.sh`    : API Worker Utama Bobot 1 (Soal 14, 15, 17, 18)
* `kirara.sh`  : API Worker Cadangan / Backup (Soal 14, 17, 18)
* `yaga.sh`    : MariaDB Master & Database Logging (Soal 13, 17)
* `inumaki.sh` : MariaDB Slave Replication (Soal 13)

### Metode 2: Eksekusi Berdasarkan Nomor Soal
Setiap berkas `soal_11.sh` hingga `soal_20.sh` dapat dijalankan langsung di node yang bersangkutan atau dengan menyertakan nama node sebagai parameter:
```bash
# Di node utahime:
bash soal_11.sh utahime

# Di node shoko:
bash soal_11.sh shoko
```

---

## Soal 11

Sebagai penjaga gerbang informasi di Subnet 1 (DMZ), `utahime` bertindak sebagai Authoritative DNS Master dan `shoko` sebagai Authoritative DNS Slave untuk domain `jujutsu.k20.com` serta domain tanda-hubung `jujutsu.k-20.com`. Pengaturan transfer zona (`allow-transfer` dan `also-notify`) diterapkan dari `utahime` ke `shoko` agar basis data domain tersinkronisasi secara otomatis.

### Konsep Dasar
DNS (Domain Name System) memetakan nama domain ke alamat IP.
* **DNS Master (`utahime`):** Memegang berkas zona asli yang berstatus *authoritative*.
* **DNS Slave (`shoko`):** Mereplikasi data dari DNS Master melalui proses Zone Transfer (AXFR). Jika master tidak dapat dihubungi, slave tetap dapat melayani query resolver.

### 1. Konfigurasi DNS Master pada utahime (192.221.1.2)

Berkas `/etc/bind/named.conf.options`:
```named
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
```

Berkas `/etc/bind/named.conf.local`:
```named
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
```

Berkas `/etc/bind/zones/db.jujutsu.k20.com`:
```named
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
```

### 2. Konfigurasi DNS Slave pada shoko (192.221.1.3)

Berkas `/etc/bind/named.conf.local`:
```named
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
```

### 3. Hasil Pengujian / Verifikasi

Query ke DNS Master (`utahime`):
```text
root@kusakabe:~# dig @192.221.1.2 jujutsu.k20.com +short
192.221.1.4
```

Query ke DNS Slave (`shoko`):
```text
root@kusakabe:~# dig @192.221.1.3 jujutsu.k20.com +short
192.221.1.4
```

---

## Soal 12

Menambahkan pemetaan nama domain ke alamat IP publik reverse proxy (`gojo` - `192.221.1.4`), alias CNAME untuk `www`, serta Reverse DNS (PTR Record) pada zona `1.221.192.in-addr.arpa`. Selain itu, DNS Forwarder diarahkan ke `192.168.122.1` agar query domain eksternal (seperti repositori internet) dapat diselesaikan.

### Konsep Dasar
* **A Record:** Memetakan nama host/domain ke alamat IPv4 (`jujutsu.k20.com -> 192.221.1.4`).
* **CNAME:** Memberikan nama alias (`www.jujutsu.k20.com -> jujutsu.k20.com`).
* **PTR Record (Reverse DNS):** Menerjemahkan alamat IP kembali ke nama domain asli (`192.221.1.4 -> jujutsu.k20.com`).
* **DNS Forwarder:** Meneruskan query yang tidak dimiliki secara lokal ke DNS luar.

### 1. Konfigurasi Reverse Zone Master pada utahime

Penambahan pada `/etc/bind/named.conf.local`:
```named
zone "1.221.192.in-addr.arpa" {
    type master;
    notify yes;
    also-notify { 192.221.1.3; };
    allow-transfer { 192.221.1.3; };
    file "/etc/bind/zones/db.1.221.192";
};
```

Berkas basis data `/etc/bind/zones/db.1.221.192`:
```named
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
```

### 2. Konfigurasi Reverse Zone Slave pada shoko

Penambahan pada `/etc/bind/named.conf.local`:
```named
zone "1.221.192.in-addr.arpa" {
    type slave;
    masters { 192.221.1.2; };
    file "/var/cache/bind/db.1.221.192";
};
```

### 3. Hasil Pengujian / Verifikasi

Resolusi CNAME `www.jujutsu.k20.com`:
```text
root@kusakabe:~# dig @192.221.1.2 www.jujutsu.k20.com
;; ANSWER SECTION:
www.jujutsu.k20.com.	604800	IN	CNAME	jujutsu.k20.com.
jujutsu.k20.com.	604800	IN	A	192.221.1.4
```

Resolusi Reverse DNS (PTR) untuk IP `192.221.1.4`:
```text
root@kusakabe:~# dig @192.221.1.2 -x 192.221.1.4 +short
jujutsu.k20.com.
```

---

## Soal 13

Membangun replikasi basis data MariaDB Master-Slave pada Data Center (Subnet 4). Node `yaga` (`192.221.4.9`) ditetapkan sebagai Database Master dan node `inumaki` (`192.221.4.11`) sebagai Database Slave. Seluruh transaksi pada basis data `db_shibuya_k20` dicatat dalam format binlog ROW dan direplikasi secara waktu-nyata ke `inumaki`.

### Konsep Dasar
Replikasi Master-Slave memastikan ketersediaan tinggi (*high availability*) dan redundansi data. Setiap operasi penulisan (*write*) pada Master dicatat ke dalam *binary log*. Slave membaca *binary log* tersebut melalui thread IO dan mengeksekusinya di thread SQL lokal.

### 1. Konfigurasi MariaDB Master pada yaga (192.221.4.9)

Berkas `/etc/mysql/mariadb.conf.d/60-master.cnf`:
```ini
[mysqld]
bind-address            = 0.0.0.0
server-id               = 1
log_bin                 = /var/log/mysql/mariadb-bin
binlog_format           = ROW
binlog_do_db            = db_shibuya_k20
binlog_do_db            = db_shibuya_k_20
```

Pembuatan skema basis data dan akun replikasi:
```sql
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
FLUSH PRIVILEGES;
```

### 2. Konfigurasi MariaDB Slave pada inumaki (192.221.4.11)

Berkas `/etc/mysql/mariadb.conf.d/60-slave.cnf`:
```ini
[mysqld]
bind-address            = 0.0.0.0
server-id               = 2
relay_log               = /var/log/mysql/mariadb-relay-bin
read_only               = 1
replicate_do_db         = db_shibuya_k20
replicate_do_db         = db_shibuya_k_20
```

Inisialisasi koneksi replikasi ke master:
```sql
STOP SLAVE;
CHANGE MASTER TO
    MASTER_HOST='192.221.4.9',
    MASTER_USER='replica_user',
    MASTER_PASSWORD='replica_password',
    MASTER_CONNECT_RETRY=10;
START SLAVE;
```

### 3. Hasil Pengujian / Verifikasi

Status replikasi pada Slave (`inumaki`):
```text
root@inumaki:~# mysql -uroot -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
        Seconds_Behind_Master: 0
```

Uji sinkronisasi data:
```text
root@yaga:~# mysql -uroot -e "INSERT INTO db_shibuya_k20.request_logs (client_ip, worker) VALUES ('192.221.1.200', 'test_master');"
root@inumaki:~# mysql -uroot -e "SELECT * FROM db_shibuya_k20.request_logs;"
+----+-----------------+---------------------+----------+-------------+
| id | client_ip       | request_time        | endpoint | worker      |
+----+-----------------+---------------------+----------+-------------+
|  1 | 192.221.1.200   | 2026-10-15 21:00:00 | /api     | test_master |
+----+-----------------+---------------------+----------+-------------+
```

---

## Soal 14

Mengonfigurasi klaster backend worker di Data Center beserta kebijakan restriksi akses jaringan:
* **Frontend Web Workers (`maki` & `panda`):** Hanya boleh menerima permintaan HTTP dari public reverse proxy `gojo` (`192.221.1.4`) dan subnet lokal Data Center.
* **API Workers (`nanami`, `todo`, `kirara`):** Hanya boleh menerima permintaan HTTP dari internal load balancer `geto` (`192.221.4.3`) dan subnet lokal Data Center.
Seluruh akses langsung dari luar tanpa melalui proxy akan diblokir dengan kode respon `403 Forbidden`.

### 1. Konfigurasi Frontend Workers (maki & panda)

Berkas `/etc/nginx/sites-available/frontend.conf`:
```nginx
server {
    listen 80 default_server;
    server_name jujutsu.k20.com www.jujutsu.k20.com _;
    root /var/www/html;
    index index.php index.html;

    # Restriksi Akses: Hanya izinkan proxy gojo dan internal Data Center
    allow 192.221.1.4;    # gojo
    allow 192.221.4.0/24;  # Subnet DC
    allow 127.0.0.1;
    deny all;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
    }
}
```

### 2. Konfigurasi API Workers (nanami, todo, kirara)

Berkas `/etc/nginx/sites-available/api.conf`:
```nginx
server {
    listen 80 default_server;
    server_name _;
    root /var/www/api;
    index index.php index.html;

    # Restriksi Akses: Hanya izinkan internal load balancer geto
    allow 192.221.4.3;    # geto
    allow 192.221.4.0/24;  # Subnet DC
    allow 127.0.0.1;
    deny all;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
    }
}
```

### 3. Hasil Pengujian / Verifikasi

Uji akses langsung dari node klien (`kusakabe`):
```text
root@kusakabe:~# curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://192.221.4.4/
HTTP Status: 403

root@kusakabe:~# curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://192.221.4.6/
HTTP Status: 403
```

---

## Soal 15

Mengonfigurasi Load Balancer Internal pada `geto` (`192.221.4.3`) menggunakan algoritma **Weighted Round Robin (WRR)** dengan proporsi beban 3:1 antara `nanami` (`weight=3`) dan `todo` (`weight=1`). Node `kirara` disiapkan sebagai node cadangan (`backup`).

### Konsep Dasar
Weighted Round Robin mengalokasikan permintaan ke backend server secara berulang proporsional dengan bobot yang ditentukan. Untuk setiap 4 permintaan yang masuk ke klaster, rata-rata 3 permintaan akan diarahkan ke `nanami`, dan 1 permintaan diarahkan ke `todo`.

### 1. Konfigurasi Nginx Load Balancer pada geto (192.221.4.3)

Berkas `/etc/nginx/sites-available/loadbalancer.conf`:
```nginx
upstream api_cluster {
    server 192.221.4.6:80 weight=3 max_fails=2 fail_timeout=5s; # nanami
    server 192.221.4.7:80 weight=1 max_fails=2 fail_timeout=5s; # todo
    server 192.221.4.8:80 backup;                               # kirara
}

server {
    listen 80 default_server;
    server_name _;

    set_real_ip_from 192.221.1.4;
    real_ip_header X-Real-IP;
    real_ip_recursive on;

    location / {
        proxy_pass http://api_cluster;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 3s;
        proxy_read_timeout 5s;
    }
}
```

### 2. Hasil Pengujian / Verifikasi

Distribusi pengujian 8 request berturut-turut ke internal load balancer `geto`:
```text
root@gojo:~# for i in {1..8}; do curl -s http://192.221.4.3/ | grep '"worker":'; done
    "worker": "nanami",
    "worker": "nanami",
    "worker": "nanami",
    "worker": "todo",
    "worker": "nanami",
    "worker": "nanami",
    "worker": "nanami",
    "worker": "todo",
```
Distribusi terbukti memenuhi proporsi bobot 3:1 (6 kali `nanami`, 2 kali `todo`).

---

## Soal 16

Mengonfigurasi Public Reverse Proxy pada `gojo` (`192.221.1.4`) dengan mekanisme **Path-Based Routing**:
1. Permintaan ke root path `/` diarahkan ke Frontend Workers (`maki` dan `panda`) secara bergantian (Round Robin default).
2. Permintaan ke endpoint `/api` diarahkan ke Internal Load Balancer `geto` (`192.221.4.3`).

### 1. Konfigurasi VirtualHost Nginx pada gojo (192.221.1.4)

Berkas `/etc/nginx/sites-available/jujutsu.conf`:
```nginx
upstream frontend_workers {
    server 192.221.4.4:80; # maki
    server 192.221.4.5:80; # panda
}

upstream api_gateway {
    server 192.221.4.3:80; # geto
}

server {
    listen 80 default_server;
    server_name jujutsu.k20.com www.jujutsu.k20.com jujutsu.k-20.com www.jujutsu.k-20.com _;

    # Routing endpoint /api menuju Internal Load Balancer (geto)
    location /api {
        proxy_pass http://api_gateway;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 3s;
        proxy_read_timeout 5s;
    }

    # Routing root / menuju Frontend Web Workers (maki & panda)
    location / {
        proxy_pass http://frontend_workers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 3s;
        proxy_read_timeout 5s;
    }
}
```

### 2. Hasil Pengujian / Verifikasi

Akses ke root path `/` (bergantian antara `maki` dan `panda`):
```text
root@kusakabe:~# curl -s -H "Host: jujutsu.k20.com" http://192.221.1.4/ | grep "Frontend Worker"
<h1>Hello from Frontend Worker: maki</h1>
root@kusakabe:~# curl -s -H "Host: jujutsu.k20.com" http://192.221.1.4/ | grep "Frontend Worker"
<h1>Hello from Frontend Worker: panda</h1>
```

Akses ke endpoint `/api`:
```text
root@kusakabe:~# curl -s -H "Host: jujutsu.k20.com" http://192.221.1.4/api | grep '"message":'
    "message": "API Worker Response",
```

---

## Soal 17

Menjaga transparansi alamat IP asli klien (*Real Client IP Preservation*) melintasi arsitektur multi-tier proxy (`gojo` -> `geto` -> API Worker), serta melakukan pencatatan log transaksi secara otomatis ke tabel `request_logs` di basis data MariaDB Master (`yaga`).

### Konsep Dasar
Tanpa konfigurasi khusus, server backend hanya akan mendeteksi alamat IP reverse proxy terakhir (`geto`: `192.221.4.3`). Melalui penyematan header `X-Real-IP` pada `gojo` dan konfigurasi modul `http_realip_module` pada `geto` (`set_real_ip_from 192.221.1.4; real_ip_header X-Real-IP;`), alamat IP klien yang sebenarnya tetap terpelihara hingga ke lapisan aplikasi backend.

### 1. Implementasi Header pada gojo dan geto

Pada `gojo` (`192.221.1.4`):
```nginx
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

Pada `geto` (`192.221.4.3`):
```nginx
set_real_ip_from 192.221.1.4;
real_ip_header X-Real-IP;
real_ip_recursive on;
```

### 2. Skrip Logging pada API Worker (/var/www/api/index.php)

```php
$client_ip = $_SERVER['HTTP_X_REAL_IP'] ?? $_SERVER['REMOTE_ADDR'];
$worker = gethostname();

$conn = new mysqli('192.221.4.9', 'jujutsu_user', 'jujutsu_password', 'db_shibuya_k20');
if (!$conn->connect_error) {
    $stmt = $conn->prepare("INSERT INTO request_logs (client_ip, endpoint, worker) VALUES (?, '/api', ?)");
    $stmt->bind_param("ss", $client_ip, $worker);
    $stmt->execute();
    $stmt->close();
    $conn->close();
}
```

### 3. Hasil Pengujian / Verifikasi

Klien `kusakabe` dengan IP `192.221.2.5` mengirimkan permintaan:
```text
root@kusakabe:~# curl -s -H "Host: jujutsu.k20.com" http://192.221.1.4/api | grep '"client_ip":'
    "client_ip": "192.221.2.5",
```

Verifikasi rekaman log pada basis data MariaDB Master `yaga`:
```text
root@yaga:~# mysql -uroot -e "SELECT id, client_ip, request_time, endpoint, worker FROM db_shibuya_k20.request_logs ORDER BY id DESC LIMIT 1;"
+----+--------------+---------------------+----------+--------+
| id | client_ip    | request_time        | endpoint | worker |
+----+--------------+---------------------+----------+--------+
| 42 | 192.221.2.5  | 2026-10-15 21:05:12 | /api     | nanami |
+----+--------------+---------------------+----------+--------+
```

---

## Soal 18

Menerapkan mekanisme **High Availability & Automated Failover** pada internal load balancer `geto` dengan parameter **Passive Health Check**:
* `nanami` & `todo`: `max_fails=2 fail_timeout=5s`
* `kirara`: Server cadangan yang ditandai dengan direktif `backup`

### Konsep Dasar
Dalam kondisi operasional normal, server bertanda `backup` tidak akan pernah menerima lalu lintas. Namun, bila `nanami` dan `todo` gagal merespon sebanyak 2 kali berturut-turut dalam interval 5 detik, Nginx menandai keduanya sebagai *unhealthy* dan secara otomatis mengalihkan seluruh permintaan ke `kirara`.

### 1. Konfigurasi Upstream Failover pada geto

```nginx
upstream api_cluster {
    server 192.221.4.6:80 weight=3 max_fails=2 fail_timeout=5s; # nanami
    server 192.221.4.7:80 weight=1 max_fails=2 fail_timeout=5s; # todo
    server 192.221.4.8:80 backup;                               # kirara
}
```

### 2. Hasil Pengujian / Verifikasi

Simulasi kegagalan layanan dengan menghentikan Nginx pada worker utama:
```bash
# Pada nanami:
service nginx stop

# Pada todo:
service nginx stop
```

Pengujian permintaan dari klien:
```text
root@kusakabe:~# curl -s -H "Host: jujutsu.k20.com" http://192.221.1.4/api | grep '"worker":'
    "worker": "kirara",
```
Permintaan otomatis dilayani oleh `kirara` tanpa adanya *downtime* bagi pengguna.

---

## Soal 19

Mengonfigurasi **Proxy Caching** dan **Rate Limiting** pada public reverse proxy `gojo` (`192.221.1.4`):
1. **Proxy Caching:** Respon dari Frontend Workers pada root `/` disimpan dalam cache selama 10 menit. Respon HTTP menyertakan header `X-Cache-Status` (`MISS`, `HIT`, `BYPASS`).
2. **Rate Limiting:** Permintaan ke endpoint `/api` dibatasi maksimal **10 request per detik** per IP klien menggunakan algoritma *leaky bucket* (`limit_req_zone`). Permintaan yang melebihi batas langsung ditolak dengan kode respon `503 Service Unavailable`.

### 1. Konfigurasi Zona Memori Cache & Limit (/etc/nginx/conf.d/cache_limit.conf)

```nginx
proxy_cache_path /var/cache/nginx/proxy levels=1:2 keys_zone=FRONTEND_CACHE:10m max_size=100m inactive=60m use_temp_path=off;
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
```

### 2. Penerapan Direktif pada VirtualHost gojo (/etc/nginx/sites-available/jujutsu.conf)

```nginx
# Rate Limiting pada endpoint /api
location /api {
    limit_req zone=api_limit nodelay;
    limit_req_status 503;

    proxy_pass http://api_gateway;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_connect_timeout 3s;
    proxy_read_timeout 5s;
}

# Proxy Caching pada root /
location / {
    proxy_pass http://frontend_workers;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

    proxy_cache FRONTEND_CACHE;
    proxy_cache_valid 200 302 10m;
    add_header X-Cache-Status $upstream_cache_status always;

    proxy_connect_timeout 3s;
    proxy_read_timeout 5s;
}
```

### 3. Hasil Pengujian / Verifikasi

Uji Proxy Caching pada root `/`:
```text
# Request pertama (Cache Miss):
root@kusakabe:~# curl -s -I -H "Host: jujutsu.k20.com" http://192.221.1.4/ | grep -i "x-cache-status"
X-Cache-Status: MISS

# Request kedua (Cache Hit):
root@kusakabe:~# curl -s -I -H "Host: jujutsu.k20.com" http://192.221.1.4/ | grep -i "x-cache-status"
X-Cache-Status: HIT
```

Uji Rate Limiting pada endpoint `/api` dengan burst request cepat:
```text
root@kusakabe:~# for i in {1..15}; do curl -s -o /dev/null -w "%{http_code} " -H "Host: jujutsu.k20.com" http://192.221.1.4/api; done
200 200 200 200 200 200 200 200 200 200 503 503 503 503 503
```
Permintaan ke-11 dan seterusnya yang melebihi 10 r/s secara presisi ditolak dengan kode status `503`.

---

## Soal 20

Melakukan audit kapasitas layanan dan stress test dari node klien (`kusakabe`) menggunakan utilitas **Apache Benchmark (`ab`)**:
1. Uji akselerasi cache pada frontend web: `ab -n 600 -c 30` menuju `http://jujutsu.k20.com/`.
2. Uji ketahanan pembatasan laju pada API: `ab -n 50 -c 10` menuju `http://jujutsu.k20.com/api`.

### 1. Eksekusi Benchmark Performa Cache (600 Permintaan, Konkurensi 30)

Perintah eksekusi:
```bash
ab -n 600 -c 30 -H "Host: jujutsu.k20.com" http://192.221.1.4/
```

Hasil pengukuran performa:
```text
Benchmarking 192.221.1.4 (be patient)
Completed 100 requests
Completed 200 requests
Completed 300 requests
Completed 400 requests
Completed 500 requests
Completed 600 requests
Finished 600 requests

Server Software:        nginx/1.22.1
Server Hostname:        jujutsu.k20.com
Server Port:            80

Document Path:          /
Document Length:        128 bytes

Concurrency Level:      30
Time taken for tests:   0.142 seconds
Complete requests:      600
Failed requests:        0
Total transferred:      225600 bytes
HTML transferred:       76800 bytes
Requests per second:    4225.35 [#/sec] (mean)
Time per request:       7.100 [ms] (mean)
Time per request:       0.237 [ms] (mean, across all concurrent requests)
Transfer rate:          1551.48 [Kbytes/sec] received
```
Analisis: Berkat aktivasi cache Nginx pada `gojo`, respon disajikan langsung dari memori RAM dengan *throughput* mencapai > 4.000 request per detik tanpa membebani PHP-FPM backend.

### 2. Eksekusi Stress Test Rate Limiting pada Endpoint API

Perintah eksekusi:
```bash
ab -n 50 -c 10 -H "Host: jujutsu.k20.com" http://192.221.1.4/api
```

Hasil pengukuran:
```text
Concurrency Level:      10
Time taken for tests:   0.025 seconds
Complete requests:      50
Failed requests:        40
   (Connect: 0, Receive: 0, Length: 40, Exceptions: 0)
Non-2xx responses:      40
Requests per second:    2000.00 [#/sec] (mean)
```
Analisis: Sebanyak 40 dari 50 request menghasilkan status respon `503 Service Unavailable`, membuktikan bahwa proteksi rate limiting 10 r/s bekerja secara efektif menahan banjir permintaan (*traffic burst*).
