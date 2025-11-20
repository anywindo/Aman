Judul: Laporan Analisis dan Implementasi Aplikasi Audit Keamanan Sistem serta Deteksi Anomali Berbasis Machine Learning

BAB I Pendahuluan
A.	Latar Belakang
B.	Rumusan Masalah	
C.	Tujuan Pembuatan Aplikasi	
D.	Manfaat Aplikasi	
E.	Batasan Masalah	
BAB II Landasan Teori	
A.	Pengertian Aplikasi	
B.	Konsep Dasar Cybersecurity Assessment	
C.	Konsep Machine Learning dalam Keamanan Sistem	
D.	Arsitektur Aplikasi	
E.	Etika Penggunaan dalam Peretasan Etis	
BAB III Perancangan Sistem	
A.	Gambaran Umum Sistem	
B.	Arsitektur Utama	
C.	Diagram Alur Proses Deteksi Anomali	
D.	Desain Antarmuka Pengguna	
E.	Deskripsi Fitur-Fitur Utama	
BAB IV Implementasi Aplikasi	
A.	Lingkungan Pengembangan	
B.	Implementasi Fitur-Fitur Aplikasi	
C.	Integrasi Antarmuka Pengguna	
D.	Alur Penggunaan Aplikasi oleh Pengguna	
BAB V Hasil dan Pembahasan.	
A.	Hasil Pembuatan Aplikasi	
B.	Penjelasan Kesesuaian Fitur dengan Tujuan	
C.	Keunggulan dan Kelemahan Aplikasi	
BAB VI Penutup	
A.	Kesimpulan	
B.	Saran Pengembangan	

---

## BAB I Pendahuluan

### A. Latar Belakang
Perangkat macOS semakin banyak digunakan untuk pekerjaan kritis, pengelolaan data sensitif, dan aktivitas daring sehari-hari. Meskipun macOS dikenal memiliki lapisan keamanan bawaan yang kuat, konfigurasi yang tidak tepat (misalnya berbagi file, port terbuka, kebijakan kata sandi lemah) tetap dapat membuka celah bagi ancaman. Di sisi lain, banyak alat audit keamanan yang tersedia bersifat terpisah, sulit digunakan, atau bergantung pada layanan cloud yang berpotensi mengurangi privasi. Aplikasi Aman dirancang untuk menjawab kebutuhan akan sebuah aplikasi audit keamanan sistem dan deteksi anomali jaringan yang terintegrasi, mudah digunakan, dan beroperasi secara lokal di perangkat pengguna.

### B. Rumusan Masalah
Rumusan masalah yang diangkat dalam pengembangan aplikasi ini antara lain:
- Bagaimana merancang sebuah aplikasi yang mampu menilai posture keamanan sistem operasi macOS secara menyeluruh dan terstruktur?
- Bagaimana mengidentifikasi paparan jaringan (seperti port dan layanan yang terbuka pada jaringan lokal) tanpa mengorbankan privasi pengguna?
- Bagaimana menerapkan konsep machine learning dan analitik statistik untuk memberikan deteksi anomali lalu lintas jaringan yang dapat dipahami oleh pengguna non‑ahli?
- Bagaimana menyajikan informasi teknis tersebut dalam bentuk antarmuka yang ringkas, interaktif, dan mudah ditindaklanjuti?

### C. Tujuan Pembuatan Aplikasi
Tujuan utama pembuatan aplikasi Aman adalah:
- Menghasilkan aplikasi audit keamanan sistem yang dapat memeriksa berbagai aspek konfigurasi macOS, mulai dari enkripsi disk, integritas sistem, kebijakan akun, hingga layanan jaringan.
- Menyediakan modul pemetaan jaringan dan pemindaian port untuk mengungkap perangkat serta layanan yang aktif pada jaringan lokal pengguna.
- Mengimplementasikan pipeline deteksi anomali berbasis machine learning dan statistik sehingga pola lalu lintas yang tidak lazim dapat diidentifikasi lebih dini.
- Menyediakan laporan dan ringkasan hasil yang mudah dipahami sehingga pengguna dapat segera mengambil langkah perbaikan.

### D. Manfaat Aplikasi
Manfaat yang diharapkan dari aplikasi ini meliputi:
- Bagi pengguna individu: mengetahui kondisi keamanan perangkatnya dan mendapatkan panduan singkat mengenai tindakan perbaikan yang disarankan.
- Bagi pengelola TI dan keamanan: memperoleh gambaran konsolidasi mengenai konfigurasi keamanan dan paparan jaringan macOS yang dikelola, serta bahan laporan audit internal.
- Bagi dunia pendidikan dan penelitian: menjadi studi kasus implementasi nyata integrasi audit sistem, pemetaan jaringan, dan deteksi anomali berbasis machine learning pada lingkungan macOS.

### E. Batasan Masalah
Untuk menjaga fokus dan kedalaman implementasi, beberapa batasan yang diterapkan adalah:
- Aplikasi ditujukan khusus untuk sistem operasi macOS generasi terbaru dan tidak menyasar sistem operasi lain.
- Aplikasi berfokus pada audit konfigurasi dan deteksi anomali, bukan pada fungsi penanggulangan otomatis atau antivirus penuh.
- Deteksi anomali dibangun di atas data metrik jaringan teragregasi; aplikasi tidak melakukan analisis payload secara rinci.
- Penggunaan fitur pemindaian jaringan dan port terbatas pada jaringan yang dimiliki atau dikelola pengguna secara sah.

## BAB II Landasan Teori

### A. Pengertian Aplikasi
Dalam konteks ini, aplikasi audit keamanan sistem dan deteksi anomali adalah perangkat lunak yang:
- Mengumpulkan informasi dari sistem operasi dan jaringan secara terkontrol.
- Mengolah informasi tersebut untuk menilai apakah konfigurasi dan perilaku sistem berada pada kondisi yang diharapkan.
- Menyajikan hasil analisis dalam bentuk visual dan narasi yang dapat dimengerti oleh manusia.
Aman memadukan ketiga aspek tersebut untuk membantu pengguna memahami posture keamanan perangkatnya.

### B. Konsep Dasar Cybersecurity Assessment
Cybersecurity assessment adalah proses sistematis untuk mengidentifikasi kelemahan, mengevaluasi risiko, dan menilai efektivitas kontrol keamanan yang diterapkan pada sebuah sistem. Dalam praktiknya, assessment mencakup:
- Audit konfigurasi sistem (enkripsi, kebijakan akun, layanan yang diaktifkan).
- Penilaian permukaan serangan jaringan (port dan layanan yang dapat diakses).
- Pencatatan temuan dan rekomendasi perbaikan yang dapat ditindaklanjuti.
Konsep ini menjadi dasar pemasangan berbagai modul pemeriksaan keamanan yang tersedia di aplikasi.

### C. Konsep Machine Learning dalam Keamanan Sistem
Machine learning dan statistik digunakan dalam Aman untuk:
- Membangun baseline perilaku normal lalu lintas jaringan berdasarkan metrik seperti jumlah byte, paket, dan aliran koneksi per satuan waktu.
- Mengukur seberapa jauh suatu kondisi menyimpang dari baseline (anomali) menggunakan pendekatan seperti z‑score, median absolute deviation, dan model gabungan beberapa fitur.
- Mengidentifikasi perubahan mendadak (change point) dan kemunculan entitas baru di jaringan (new talkers) yang berpotensi menandakan aktivitas tidak biasa.
Pendekatan ini termasuk dalam kategori deteksi anomali yang umumnya bersifat tidak terawasi (unsupervised), sehingga tidak bergantung pada tanda tangan serangan tertentu.

### D. Arsitektur Aplikasi
Secara konseptual, arsitektur aplikasi terbagi menjadi tiga lapisan:
- Lapisan antarmuka pengguna, yang menghadirkan tampilan audit keamanan sistem, modul keamanan jaringan, peta topologi, dan alat utilitas.
- Lapisan logika bisnis, yang menjalankan pemeriksaan konfigurasi sistem, mengelola proses pemetaan jaringan, dan mengatur alur data antara antarmuka dan modul analitik.
- Lapisan analitik, yang menerima data metrik jaringan dalam bentuk terstruktur, memprosesnya melalui beberapa tahap deteksi anomali, dan menghasilkan ringkasan serta skor risiko.
Komunikasi antar lapisan dirancang agar tetap menjaga pemisahan tanggung jawab namun tetap efisien dan responsif.

### E. Etika Penggunaan dalam Peretasan Etis
Penggunaan aplikasi ini harus mematuhi prinsip-prinsip peretasan etis, antara lain:
- Hanya digunakan pada perangkat dan jaringan yang dimiliki atau telah mendapatkan izin eksplisit.
- Hasil analisis dimanfaatkan untuk memperkuat keamanan, bukan untuk mencari atau mengeksploitasi kelemahan pihak lain.
- Mematuhi peraturan perundang-undangan serta kebijakan organisasi terkait pemantauan dan pemrosesan data jaringan.
Aplikasi ini dirancang untuk mendukung aktivitas audit yang bertanggung jawab, bukan aktivitas ofensif.

## BAB III Perancangan Sistem

### A. Gambaran Umum Sistem
Sistem yang dibangun terdiri dari beberapa modul utama:
- Modul audit keamanan sistem operasi yang melakukan serangkaian pemeriksaan terhadap pengaturan keamanan.
- Modul keamanan jaringan yang menyediakan toolkit analisis konektivitas, pemetaan jaringan lokal, dan profil jaringan.
- Modul deteksi anomali yang menganalisis data metrik jaringan secara historis untuk menemukan pola tidak biasa.
Ketiga modul tersebut terintegrasi dalam satu aplikasi dengan alur kerja yang saling mendukung.

### B. Arsitektur Utama
Arsitektur utama dirancang dengan mempertimbangkan:
- Pemisahan yang jelas antara lapisan presentasi, logika, dan analitik sehingga pengembangan dan pemeliharaan dapat dilakukan secara terstruktur.
- Penggunaan pemrosesan asinkron untuk menjaga antarmuka tetap responsif saat audit atau analisis sedang berjalan.
- Kemampuan untuk menambahkan modul pemeriksaan baru atau tahap analitik baru tanpa mengganggu modul yang sudah ada.
Desain ini memberikan fleksibilitas untuk pengembangan berkelanjutan sekaligus menjaga kestabilan aplikasi.

### C. Diagram Alur Proses Deteksi Anomali
Secara naratif, alur proses deteksi anomali meliputi:
1. Aplikasi mengumpulkan metrik jaringan dalam bentuk deret waktu (misalnya jumlah byte dan paket per interval).
2. Data metrik tersebut dikirim ke pipeline analitik yang telah dikonfigurasi.
3. Setiap tahap dalam pipeline menghitung baseline, mengukur penyimpangan, mengidentifikasi perubahan struktur, dan menandai entitas baru.
4. Hasil dari setiap tahap digabungkan menjadi ringkasan yang berisi skor deteksi, alasan (reason codes), dan informasi tambahan untuk penjelasan.
5. Ringkasan ini kemudian ditampilkan kepada pengguna sebagai bagian dari modul keamanan jaringan.

### D. Desain Antarmuka Pengguna
Desain antarmuka menekankan:
- Tampilan audit keamanan sistem yang menyajikan daftar temuan dengan status, tingkat keparahan, dan penjelasan remediasi.
- Tampilan keamanan jaringan dengan navigasi yang jelas untuk beralih antara toolkit internet, pemetaan jaringan, dan profil jaringan.
- Tampilan topologi jaringan yang memvisualisasikan perangkat serta hubungan di antaranya dengan cara yang mudah dipahami.
- Penggunaan warna, ikon, dan teks penjelas yang konsisten agar pengguna dapat dengan cepat membedakan kondisi aman, perlu ditinjau, dan berisiko.

### E. Deskripsi Fitur-Fitur Utama
Fitur utama aplikasi dapat dirangkum sebagai berikut:
- Audit keamanan sistem operasi macOS yang mencakup enkripsi, integritas sistem, pengaturan akun, serta layanan berbagi dan akses jarak jauh.
- Toolkit keamanan internet untuk menilai kebocoran DNS, paparan alamat IP, dukungan IPv6, kondisi firewall, dan konfigurasi proxy atau VPN.
- Modul pemetaan jaringan yang mendeteksi perangkat lain pada jaringan lokal dan mengidentifikasi layanan yang tersedia melalui pemindaian port.
- Modul deteksi anomali berbasis machine learning yang memberikan ringkasan pola lalu lintas tidak biasa beserta penjelasan singkat.

## BAB IV Implementasi Aplikasi

### A. Lingkungan Pengembangan
Lingkungan pengembangan yang digunakan meliputi:
- Sistem operasi macOS dengan dukungan pengembangan aplikasi desktop modern.
- Perangkat pengembangan terintegrasi untuk membangun antarmuka pengguna dan logika aplikasi.
- Lingkungan eksekusi Python untuk menjalankan pipeline analitik sebagai proses terpisah yang berkomunikasi melalui data terstruktur.

### B. Implementasi Fitur-Fitur Aplikasi
Dalam implementasinya:
- Modul audit keamanan sistem dikemas dalam bentuk kumpulan pemeriksaan yang dapat dijalankan secara berurutan, masing-masing dengan deskripsi, status, dan rekomendasi.
- Fitur keamanan jaringan memanfaatkan kombinasi informasi dari sistem dan permintaan jaringan ringan (misalnya untuk memperoleh informasi IP publik) dengan tetap mengutamakan privasi.
- Modul pemetaan jaringan menggabungkan enumerasi perangkat, koleksi informasi layanan, dan penyimpanan riwayat pemindaian untuk referensi di masa depan.
- Pipeline deteksi anomali diimplementasikan sebagai rangkaian tahap terkonfigurasi yang dapat diatur parameternya melalui berkas konfigurasi.

### C. Integrasi Antarmuka Pengguna
Integrasi antara antarmuka dan logika aplikasi dilakukan dengan:
- Menghubungkan komponen tampilan dengan sumber data reaktif sehingga perubahan hasil audit atau analisis langsung tercermin di layar.
- Menyediakan indikator progres dan status agar pengguna memahami bahwa proses audit atau analisis sedang berjalan.
- Menyisipkan pesan kesalahan dan log yang ramah pengguna apabila terjadi kegagalan, misalnya ketika lingkungan analitik tidak tersedia.

### D. Alur Penggunaan Aplikasi oleh Pengguna
Alur penggunaan tipikal oleh pengguna adalah:
1. Pengguna membuka aplikasi dan memilih modul audit keamanan sistem untuk menjalankan pemeriksaan awal.
2. Setelah mendapatkan gambaran dasar, pengguna beralih ke modul keamanan jaringan untuk mengevaluasi eksposur jaringan dan menjalankan pemetaan perangkat.
3. Jika diinginkan, pengguna mengaktifkan modul deteksi anomali untuk menganalisis pola lalu lintas selama periode tertentu.
4. Hasil audit, pemetaan, dan analitik kemudian dievaluasi, dan pengguna mengikuti rekomendasi yang diberikan untuk meningkatkan keamanan.

## BAB V Hasil dan Pembahasan

### A. Hasil Pembuatan Aplikasi
Hasil pengembangan berupa sebuah aplikasi yang:
- Mampu menjalankan audit konfigurasi keamanan sistem operasi macOS secara terstruktur dan menghasilkan daftar temuan yang jelas.
- Menyediakan pandangan menyeluruh terhadap perangkat dan layanan pada jaringan lokal melalui pemetaan dan pemindaian port.
- Mengaplikasikan teknik deteksi anomali untuk membantu mengidentifikasi aktivitas jaringan yang berpotensi tidak biasa.

### B. Penjelasan Kesesuaian Fitur dengan Tujuan
Secara umum, fitur-fitur yang direalisasikan selaras dengan tujuan awal:
- Audit sistem menjawab kebutuhan evaluasi posture keamanan yang menyeluruh.
- Modul keamanan jaringan dan pemetaan memberikan wawasan konkret tentang permukaan serangan yang terkait jaringan.
- Pipeline deteksi anomali memperkaya hasil dengan informasi dinamis yang tidak dapat diperoleh dari konfigurasi statis semata.
- Fitur laporan dan ringkasan mendukung pengguna dalam mengambil keputusan perbaikan.

### C. Keunggulan dan Kelemahan Aplikasi
Keunggulan:
- Seluruh proses analisis utama dilakukan secara lokal sehingga data sensitif tidak perlu dikirim ke layanan eksternal.
- Integrasi yang erat antara audit sistem, pemetaan jaringan, dan deteksi anomali memudahkan pengguna mendapatkan gambaran menyeluruh.
- Desain modular memudahkan penambahan pemeriksaan dan teknik analitik baru di masa mendatang.
Kelemahan:
- Bergantung pada dukungan sistem operasi dan lingkungan eksekusi tertentu sehingga tidak portabel ke semua platform.
- Hasil deteksi anomali bersifat probabilistik dan dapat mengandung false positive atau false negative.
- Aplikasi tidak menggantikan kebutuhan akan kebijakan keamanan organisasi yang komprehensif dan pemantauan profesional.

## BAB VI Penutup

### A. Kesimpulan
Pengembangan aplikasi Aman menunjukkan bahwa audit keamanan sistem dan deteksi anomali berbasis machine learning dapat diintegrasikan dalam satu platform yang ramah pengguna dan menjaga privasi. Kombinasi audit konfigurasi, pemetaan jaringan, dan analitik lalu lintas memberikan landasan yang kuat bagi pengguna untuk memahami dan meningkatkan keamanan perangkat macOS mereka.

### B. Saran Pengembangan
Beberapa saran pengembangan ke depan antara lain:
- Memperluas cakupan pemeriksaan keamanan dan menyesuaikan dengan standar atau regulasi baru yang muncul.
- Menyempurnakan metode deteksi anomali dengan teknik yang lebih canggih dan adaptif terhadap perubahan pola penggunaan.
- Meningkatkan kemampuan visualisasi, khususnya untuk topologi jaringan dan timeline anomali.
- Menyediakan opsi integrasi dengan alat pemantauan atau pelaporan eksternal bagi organisasi yang membutuhkan.

