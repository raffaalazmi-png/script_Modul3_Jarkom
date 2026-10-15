# Praktikum Jaringan Komputer 2026 — Modul 3
## Curtain Protocol: Shibuya Incident (Kelompok K-20)
### Solusi & Panduan Lengkap Soal Nomor 11 – 20


##  Daftar Node & Peran Layanan

| Subnet | Node | IP Address | Peran / Layanan | Tanggung Jawab Soal |
| :--- | :--- | :--- | :--- | :--- |
| **Subnet 1** | **`utahime`** | `192.221.1.2` | DNS Master (BIND9) | Soal 11, 12 |
| **Subnet 1** | **`shoko`** | `192.221.1.3` | DNS Slave (BIND9) | Soal 11, 12 |
| **Subnet 1** | **`gojo`** | `192.221.1.4` | Public Reverse Proxy, Caching, Rate Limit | Soal 12, 16, 17, 19 |
| **Subnet 4** | **`geto`** | `192.221.4.3` | Internal Load Balancer (Nginx) | Soal 14, 15, 17, 18 |
| **Subnet 4** | **`maki`** | `192.221.4.4` | Worker Web Frontend (Nginx + PHP-FPM) | Soal 14, 16 |
| **Subnet 4** | **`panda`** | `192.221.4.5` | Worker Web Frontend (Nginx + PHP-FPM) | Soal 14, 16 |
| **Subnet 4** | **`nanami`** | `192.221.4.6` | Worker API Utama (Weight 3) | Soal 14, 15, 17, 18 |
| **Subnet 4** | **`todo`** | `192.221.4.7` | Worker API Utama (Weight 1) | Soal 14, 15, 17, 18 |
| **Subnet 4** | **`kirara`** | `192.221.4.8` | Worker API Cadangan (Backup Server) | Soal 14, 17, 18 |
| **Subnet 4** | **`yaga`** | `192.221.4.9` | MariaDB Database Master | Soal 13, 17 |
| **Subnet 4** | **`inumaki`** | `192.221.4.11` | MariaDB Database Slave | Soal 13 |

---


## Pembahasan Lengkap Soal 11 – 20

---

### 🔹 Soal 11: Setup BIND9 DNS Master & Slave
* **Node Terlibat:** `utahime` (Master - `192.221.1.2`) dan `shoko` (Slave - `192.221.1.3`)
* **Domain:** `jujutsu.k20.com`

####  Konsep untuk Pemula
DNS berfungsi seperti "buku telepon internet" yang menerjemahkan nama domain yang mudah diingat (seperti `jujutsu.k20.com`) menjadi alamat IP numerik (`192.221.1.4`).
* **DNS Master (`utahime`):** Pemilik data domain asli. Konfigurasi zona dibuat di sini.
* **DNS Slave (`shoko`):** Salinan cadangan. Slave otomatis mendownload rekaman dari Master melalui mekanisme **Zone Transfer** (`allow-transfer`). Jika Master sedang sibuk atau mati, Slave tetap bisa menjawab permintaan client.

#### ⚙️ Cara Menjalankan
* Di terminal `utahime`:
  ```bash
  bash /root/utahime.sh
  # atau
  bash soal_11.sh
  ```
* Di terminal `shoko`:
  ```bash
  bash /root/shoko.sh
  # atau
  bash soal_11.sh
  ```

#### 🧪 Cara Mencoba & Menguji (Testing)
Buka terminal node client mana pun (misal: `kusakabe`, `itadori`, atau `gojo`), lalu jalankan:

1. **Uji Query ke Master (`utahime`):**
   ```bash
   dig @192.221.1.2 jujutsu.k20.com
   ```
   *Ekspektasi Output:* Muncul status `NOERROR` dan pada `ANSWER SECTION` terdapat alamat IP `192.221.1.4`.

2. **Uji Query ke Slave (`shoko`):**
   ```bash
   dig @192.221.1.3 jujutsu.k20.com
   ```
   *Ekspektasi Output:* Muncul status `NOERROR` dan IP `192.221.1.4`, membuktikan rekaman zona berhasil tersinkronisasi otomatis dari `utahime` ke `shoko`.

---

### 🔹 Soal 12: A Record, CNAME, Reverse DNS (PTR), & DNS Forwarder
* **Node Terlibat:** `utahime` (`192.221.1.2`)

#### 💡 Konsep untuk Pemula
* **A Record:** Menghubungkan nama domain langsung ke alamat IPv4 (`jujutsu.k20.com` $\to$ `192.221.1.4`).
* **CNAME (Canonical Name):** Alias nama lain yang merujuk ke domain utama (`www.jujutsu.k20.com` $\to$ `jujutsu.k20.com`).
* **Reverse DNS (PTR Record):** Kebalikan dari A Record. Mengubah alamat IP kembali menjadi nama domain (`192.221.1.4` $\to$ `jujutsu.k20.com`). Menggunakan zona khusus `1.221.192.in-addr.arpa`.
* **DNS Forwarder:** Jika server ditanya domain luar (seperti `google.com`) yang tidak diketahuinya, server akan meneruskan (*forward*) pertanyaan tersebut ke DNS internet publik (`192.168.122.1`).

#### ⚙️ Cara Menjalankan
* Di terminal `utahime`:
  ```bash
  bash soal_12.sh
  ```

#### 🧪 Cara Mencoba & Menguji (Testing)
Dari terminal client:

1. **Uji CNAME www:**
   ```bash
   dig @192.221.1.2 www.jujutsu.k20.com
   ```
   *Ekspektasi Output:* Terlihat `www.jujutsu.k20.com. CNAME jujutsu.k20.com.` lalu diselesaikan ke IP `192.221.1.4`.

2. **Uji Reverse DNS (PTR):**
   ```bash
   dig @192.221.1.2 -x 192.221.1.4
   ```
   *Ekspektasi Output:* Bagian `ANSWER SECTION` menampilkan:
   `4.1.221.192.in-addr.arpa. PTR jujutsu.k20.com.`

3. **Uji Forwarder Internet:**
   ```bash
   ping -c 2 google.com
   ```
   *Ekspektasi Output:* Ping berhasil dengan `0% packet loss` karena domain internet berhasil di-resolve melalui forwarder `192.168.122.1`.

---

### 🔹 Soal 13: MariaDB Master-Slave Database Replication
* **Node Terlibat:** `yaga` (Master - `192.221.4.9`) dan `inumaki` (Slave - `192.221.4.11`)
* **Database:** `db_shibuya_k20` | **Tabel:** `request_logs`

#### 💡 Konsep untuk Pemula
Replikasi database memastikan salinan data selalu terduplikasi secara realtime.
* **Master (`yaga`):** Setiap kali ada data baru yang masuk (INSERT/UPDATE), perubahan dicatat ke dalam log biner (*binary log* / `log-bin`).
* **Slave (`inumaki`):** Menghubungkan dirinya ke Master menggunakan user `replica_user`. Slave membaca *binary log* Master dan mengeksekusi ulang perubahan data tersebut secara otomatis di database lokalnya.

#### ⚙️ Cara Menjalankan
1. Di terminal `yaga`:
   ```bash
   bash /root/yaga.sh
   # atau
   bash soal_13.sh
   ```
2. Di terminal `inumaki`:
   ```bash
   bash /root/inumaki.sh
   # atau
   bash soal_13.sh
   ```

#### 🧪 Cara Mencoba & Menguji (Testing)
1. **Periksa Status Slave di `inumaki`:**
   ```bash
   mysql -uroot -e "SHOW SLAVE STATUS\G"
   ```
   *Ekspektasi Output:*
   * `Slave_IO_Running: Yes`
   * `Slave_SQL_Running: Yes`
   * `Seconds_Behind_Master: 0`

2. **Uji Replikasi Realtime:**
   * Di `yaga` (Master), masukkan data uji:
     ```bash
     mysql -uroot -e "INSERT INTO db_shibuya_k20.request_logs (client_ip, endpoint, worker) VALUES ('10.10.10.10', '/uji', 'test_master');"
     ```
   * Di `inumaki` (Slave), cek apakah data otomatis muncul:
     ```bash
     mysql -uroot -e "SELECT * FROM db_shibuya_k20.request_logs WHERE worker='test_master';"
     ```
   *Ekspektasi Output:* Data yang baru saja dibuat di `yaga` langsung muncul di `inumaki`!

---

### 🔹 Soal 14: Restriksi Akses Langsung ke Backend Worker
* **Web Frontend Workers:** `maki` (`192.221.4.4`) & `panda` (`192.221.4.5`)
* **API Workers:** `nanami` (`192.221.4.6`), `todo` (`192.221.4.7`), `kirara` (`192.221.4.8`)

#### 💡 Konsep untuk Pemula
Di lingkungan produksi yang aman, server aplikasi (worker) tidak boleh diakses langsung oleh user/klien luar.
* **Frontend (`maki`, `panda`)** hanya boleh menerima trafik yang melewati pintu gerbang reverse proxy `gojo` (`192.221.1.4`).
* **API Worker (`nanami`, `todo`, `kirara`)** hanya boleh menerima request dari internal load balancer `geto` (`192.221.4.3`).
* Jika ada klien yang mencoba menembak IP worker secara langsung, Nginx akan menolaknya dengan pesan `403 Forbidden`.

#### ⚙️ Cara Menjalankan
Jalankan skrip di masing-masing worker:
```bash
bash /root/maki.sh      # pada node maki
bash /root/panda.sh     # pada node panda
bash /root/nanami.sh    # pada node nanami
bash /root/todo.sh      # pada node todo
bash /root/kirara.sh    # pada node kirara
```

#### 🧪 Cara Mencoba & Menguji (Testing)
Dari terminal client (misal: `kusakabe`):

1. **Coba akses langsung ke worker frontend `maki`:**
   ```bash
   curl -I http://192.221.4.4/
   ```
   *Ekspektasi Output:* `HTTP/1.1 403 Forbidden` (Akses langsung ditolak!).

2. **Coba akses langsung ke worker API `nanami`:**
   ```bash
   curl -I http://192.221.4.6/
   ```
   *Ekspektasi Output:* `HTTP/1.1 403 Forbidden` (Akses langsung ditolak!).

3. **Akses legal melalui proxy `gojo`:**
   ```bash
   curl -H "Host: jujutsu.k20.com" http://192.221.1.4/
   ```
   *Ekspektasi Output:* `HTTP/1.1 200 OK` dan menampilkan ucapan selamat datang dari worker (`maki` atau `panda`).

---

### 🔹 Soal 15: Nginx Internal Load Balancer — Weighted Round Robin (3:1)
* **Node Terlibat:** `geto` (`192.221.4.3`)

#### 💡 Konsep untuk Pemula
**Load Balancer** membagi beban request ke beberapa server agar tidak ada server yang kewalahan (*overload*).
* **Weighted Round Robin (3:1):** Server `nanami` diberi bobot `weight=3`, sedangkan `todo` diberi bobot `weight=1`.
* Artinya, untuk setiap 4 request yang masuk ke `geto`, secara statistik **3 request dialihkan ke `nanami`** dan **1 request dialihkan ke `todo`**.

#### ⚙️ Cara Menjalankan
* Di terminal `geto`:
  ```bash
  bash /root/geto.sh
  # atau
  bash soal_15.sh
  ```

#### 🧪 Cara Mencoba & Menguji (Testing)
Dari terminal lokal di Data Center atau via proxy, lakukan perulangan 8 request:
```bash
for i in {1..8}; do curl -s http://192.221.4.3/ | grep -o '"worker": "[^"]*"'; done
```
*Ekspektasi Output:*
Dari 8 request, respons akan didominasi oleh `nanami` sebanyak ~6 kali dan `todo` sebanyak ~2 kali (rasio 3:1).

---

### 🔹 Soal 16: Public Reverse Proxy — Path-Based Routing
* **Node Terlibat:** `gojo` (`192.221.1.4`)

#### 💡 Konsep untuk Pemula
**Path-Based Routing** memilah lalu lintas berdasarkan alamat URL yang diminta:
1. Jika klien meminta halaman web utama root (`/`), request diarahkan secara bergantian (Round Robin) ke **Web Frontend (`maki` dan `panda`)**.
2. Jika klien meminta endpoint data (`/api`), request langsung dibelokkan ke **Load Balancer API `geto`**.

#### ⚙️ Cara Menjalankan
* Di terminal `gojo`:
  ```bash
  bash /root/gojo.sh
  # atau
  bash soal_16.sh
  ```

#### 🧪 Cara Mencoba & Menguji (Testing)
Dari terminal client:

1. **Uji Path Web Utama (`/`):**
   ```bash
   curl -H "Host: jujutsu.k20.com" http://192.221.1.4/
   ```
   *Ekspektasi Output:* Dijawab oleh `maki` atau `panda` (halaman HTML frontend).

2. **Uji Path API (`/api`):**
   ```bash
   curl -H "Host: jujutsu.k20.com" http://192.221.1.4/api
   ```
   *Ekspektasi Output:* Dijawab oleh API cluster (`nanami` atau `todo`) dalam format JSON:
   `{"status": "success", "worker": "nanami", ...}`.

---

### 🔹 Soal 17: Preservasi IP Asli Klien & Database Logging
* **Node Terlibat:** `gojo`, `geto`, worker API, dan `yaga`

#### 💡 Konsep untuk Pemula
Ketika sebuah request melewati reverse proxy (`gojo` $\to$ `geto` $\to$ worker), secara default IP pengirim yang terbaca oleh worker adalah IP proxy (`192.221.4.3`), bukan IP asli laptop/client!
* **Solusi Header:** `gojo` menyematkan header `X-Real-IP` dan `X-Forwarded-For` berisi IP asli klien.
* **Trusted Proxy:** `geto` dikonfigurasi dengan `set_real_ip_from 192.221.1.4` agar hanya mempercayai informasi IP asli jika datang dari `gojo`.
* **Logging:** Skrip PHP pada worker membaca header tersebut dan menyimpannya ke tabel `request_logs` di database `yaga`.

#### 🧪 Cara Mencoba & Menguji (Testing)
1. Kirim request dari client `kusakabe` (IP misal `192.221.3.100` atau DHCP):
   ```bash
   curl -H "Host: jujutsu.k20.com" http://192.221.1.4/api
   ```
2. Periksa respon JSON:
   `"client_ip": "192.221.X.X"` $\to$ Menunjukkan IP asli client, bukan IP `gojo` atau `geto`!
3. Cek database di `yaga`:
   ```bash
   mysql -uroot -e "SELECT id, client_ip, endpoint, worker, request_time FROM db_shibuya_k20.request_logs ORDER BY id DESC LIMIT 1;"
   ```
   *Ekspektasi Output:* Kolom `client_ip` mencatat alamat IP asli client dengan akurat.

---

### 🔹 Soal 18: Failover Backup Server & Passive Health Check
* **Node Terlibat:** `geto` (`192.221.4.3`) dan `kirara` (`192.221.4.8`)

#### 💡 Konsep untuk Pemula
* **Backup Server (`kirara`):** Server cadangan yang dalam kondisi normal **tidur / siaga**. Selama server utama (`nanami` dan `todo`) sehat, `kirara` tidak akan menerima request apapun.
* **Passive Health Check (`max_fails=2 fail_timeout=5s`):** Jika Nginx mendeteksi server utama gagal merespons sebanyak 2 kali dalam rentang waktu 5 detik, Nginx otomatis menandai server tersebut sedang rusak (*down*) dan mengalihkan seluruh trafik ke server cadangan (`kirara`) tanpa memunculkan error `502 Bad Gateway` ke user.

#### 🧪 Cara Mencoba & Menguji (Testing)
1. **Simulasikan Kerusakan Server Utama:**
   * Di terminal `nanami`: `service nginx stop`
   * Di terminal `todo`: `service nginx stop`
2. **Kirim Request dari Client:**
   ```bash
   curl -H "Host: jujutsu.k20.com" http://192.221.1.4/api
   ```
   *Ekspektasi Output:*
   Request tetap berhasil dengan status `200 OK` dan dijawab oleh:
   `"worker": "kirara"`, `"message": "API response from backup worker: kirara"`.
3. **Pulihkan Kembali:**
   * Di `nanami`: `service nginx start`
   * Di `todo`: `service nginx start`
   Request otomatis kembali dilayani oleh `nanami` dan `todo`.

---

### 🔹 Soal 19: Nginx Proxy Caching (10 Menit) & Rate Limiting (10 r/s)
* **Node Terlibat:** `gojo` (`192.221.1.4`)

#### 💡 Konsep untuk Pemula
1. **Proxy Caching (Web Frontend):**
   * Menyimpan salinan halaman web di memori/disk proxy selama 10 menit.
   * Akses pertama: `X-Cache-Status: MISS` (proxy mengambil dari backend worker).
   * Akses kedua & seterusnya: `X-Cache-Status: HIT` (proxy langsung menyajikan dari cache tanpa membebani backend worker).
2. **Rate Limiting (Endpoint `/api`):**
   * Membatasi jumlah request maksimal **10 request per detik** per alamat IP klien.
   * Mencegah serangan spam/DDoS. Jika request dikirim melebihi batas, Nginx menolaknya dengan kode `503 Service Temporarily Unavailable`.

#### 🧪 Cara Mencoba & Menguji (Testing)

1. **Uji Caching:**
   * Akses pertama:
     ```bash
     curl -I -H "Host: jujutsu.k20.com" http://192.221.1.4/ | grep -i x-cache-status
     ```
     *Output:* `X-Cache-Status: MISS`
   * Akses kedua (ulangi langsung perintah di atas):
     *Output:* `X-Cache-Status: HIT` (Berhasil di-cache!).

2. **Uji Rate Limiting:**
   Kirim 15 request beruntun tanpa jeda dari client:
   ```bash
   for i in {1..15}; do curl -s -o /dev/null -w "%{http_code} " -H "Host: jujutsu.k20.com" http://192.221.1.4/api; done; echo ""
   ```
   *Ekspektasi Output:*
   `200 200 200 ... 503 503 503` (Request awal diterima, request berlebih langsung ditolak dengan status `503`).

---

### 🔹 Soal 20: Audit Kapasitas Layanan & Apache Benchmark
* **Node Client:** `kusakabe` (atau client lain)

#### 💡 Konsep untuk Pemula
**Apache Benchmark (`ab`)** adalah alat untuk melakukan stress test (uji beban) pada web server.
* Parameter `-n 600`: Mengirimkan total 600 request.
* Parameter `-c 30`: Menjalankan 30 request secara bersamaan (*concurrency*).

#### ⚙️ Cara Menjalankan
Buka terminal `kusakabe`, lalu jalankan:
```bash
bash /root/soal_20.sh
```
Atau ketik perintah langsung:

1. **Benchmark Web Frontend (Uji Performa Cache):**
   ```bash
   ab -n 600 -c 30 -H "Host: jujutsu.k20.com" http://192.221.1.4/
   ```
   *Metrik yang Diamati:*
   * `Requests per second (RPS)`: Nilai RPS sangat tinggi (> 1000 RPS) karena seluruh 600 request dilayani langsung dari cache Nginx di `gojo`.
   * `Failed requests`: `0`.
   * `Time per request`: Sangat cepat (< 1-2 ms).

2. **Benchmark Endpoint `/api` (Uji Efek Rate Limiting):**
   ```bash
   ab -n 50 -c 10 -H "Host: jujutsu.k20.com" http://192.221.1.4/api
   ```
   *Metrik yang Diamati:*
   * Terlihat `Non-2xx responses: ~35-40` (kode 503), membuktikan bahwa sistem keamanan rate limiting aktif membatasi trafik berlebih.

---

## ⚡ Skrip Validasi Otomatis (`test_all.sh`)

Untuk menguji semua skenario dari nomor 11 hingga 20 sekaligus tanpa perlu mengetik perintah satu per satu, masuklah ke terminal salah satu client (misal: `kusakabe`), lalu jalankan:

```bash
curl -s https://raw.githubusercontent.com/raffaalazmi-png/script_Modul3_Jarkom/main/testing/test_all.sh | bash
# atau jika file sudah di-download:
bash testing/test_all.sh
```

Skrip ini akan otomatis memeriksa status DNS Master/Slave, Reverse DNS PTR, CNAME, restriksi akses 403, path routing, rasio load balancing, pencatatan IP asli ke database, cache HIT/MISS, dan rate limiting 503 dalam sekali jalan.

---

## 🛠️ Troubleshooting Singkat

1. **Gagal `apt-get update` saat node dinyalakan:**
   * Pastikan resolver mengarah ke gateway internet NAT:
     ```bash
     echo "nameserver 192.168.122.1" > /etc/resolv.conf
     ```
2. **Koneksi database dari worker ke `yaga` ditolak (Access Denied):**
   * Pastikan user `jujutsu_user` sudah memiliki hak akses remote di `yaga`:
     ```bash
     mysql -uroot -e "GRANT ALL PRIVILEGES ON *.* TO 'jujutsu_user'@'%' IDENTIFIED BY 'jujutsu_password'; FLUSH PRIVILEGES;"
     ```
3. **Nginx menampilkan error konfigurasi:**
   * Cek letak sintaks yang salah dengan perintah:
     ```bash
     nginx -t
     ```

---
*Semoga berhasil praktikumnya dan sukses dalam sesi demo!* 🚀
