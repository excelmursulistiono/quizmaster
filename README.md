# QUIZMASTER — Smart Quiz & Learning Platform

Starter aplikasi kuis digital berbahasa Indonesia dengan antarmuka responsif, dashboard, pembuatan kuis, pengerjaan dengan timer, penilaian otomatis untuk pilihan ganda, pembahasan, leaderboard, riwayat hasil, ekspor CSV, mode gelap, dan konfigurasi Supabase.

## Penting: status versi ini

- **Demo lokal sudah bisa dicoba** tanpa akun database. Kuis dan hasil disimpan di `localStorage` browser yang digunakan.
- **Belum menjadi aplikasi produksi yang sepenuhnya terhubung** hanya dengan mengisi URL Supabase. Integrasi autentikasi, penyimpanan jawaban server-side, validasi timer di server, penilaian melalui fungsi tepercaya, dan semua kebijakan RLS perlu diselesaikan dan diuji sebelum dipakai untuk ujian sungguhan.
- Statistik peserta awal merupakan data contoh, bukan data sekolah yang nyata.
- Timer demo berjalan pada browser. Jangan gunakan untuk ujian resmi sebelum deadline dan pengumpulan divalidasi oleh backend.

## Menjalankan di komputer

Memerlukan Node.js 20 atau versi LTS terbaru.

```bash
npm install
npm run dev
```

Buka alamat lokal yang tampil di terminal.

## Deploy ke Vercel

1. Ekstrak folder ini lalu unggah ke repositori GitHub.
2. Impor repositori tersebut ke Vercel. Framework akan terdeteksi sebagai Vite.
3. Build command: `npm run build`; output directory: `dist`.
4. Deploy. Mode demo dapat dijalankan tanpa environment variable.
5. Untuk database, buat proyek Supabase dan lanjutkan panduan di bawah.

## Menghubungkan Supabase

1. Buat proyek di Supabase.
2. Buka **SQL Editor**, jalankan `supabase/schema.sql`, dan periksa hasilnya.
3. Salin `.env.example` menjadi `.env` untuk pengembangan lokal.
4. Isi `VITE_SUPABASE_URL` dan `VITE_SUPABASE_ANON_KEY` dengan URL proyek dan publishable/anon key dari dashboard Supabase.
5. Tambahkan variabel yang sama di **Vercel → Project → Settings → Environment Variables**, lalu redeploy.
6. Jangan pernah menaruh `service_role` key di frontend, GitHub, atau variabel berawalan `VITE_`.

Catatan: kode antarmuka saat ini mendeteksi keberadaan konfigurasi Supabase, tetapi operasi utama masih menggunakan mode demo lokal. Integrasi data Supabase penuh harus dibuat sebelum mengklaim data tersimpan di cloud.

## Fitur yang tersedia di demo

- Dashboard dengan statistik dan kuis populer.
- Navigasi Bank Soal, Manajemen Kuis, Data Peserta, Hasil Kuis, Leaderboard, Pengaturan.
- Buat/edit/hapus kuis demo dengan 1 soal pilihan ganda dan 4 opsi.
- Timer hitung mundur, navigasi soal, tandai tinjauan, kumpulkan jawaban.
- Penilaian otomatis dan pembahasan.
- Riwayat hasil tersimpan lokal dan ekspor CSV.
- Mode terang/gelap dan layout responsif.

## Sebelum penggunaan nyata di sekolah

- Bangun login Supabase Auth dan undangan/pembuatan akun yang aman.
- Pindahkan penilaian, deadline, dan finalisasi attempt ke Supabase Edge Functions atau RPC tepercaya.
- Pisahkan akses kunci jawaban dari query peserta; jangan pernah mengirim kunci jawaban ke browser sebelum waktunya.
- Tinjau RLS bersama administrator teknis dan uji akses dengan akun guru, peserta, dan administrator.
- Tambahkan impor Excel/CSV yang memvalidasi template, upload gambar, semua tipe soal, pagination server-side, serta laporan yang sesuai kebijakan privasi sekolah.
- Uji banyak peserta, pemutusan koneksi, pengiriman ulang, dan pencegahan hasil ganda.

## Struktur

```text
quizmaster/
├── index.html
├── package.json
├── .env.example
├── README.md
├── src/
│   ├── main.jsx
│   └── styles.css
└── supabase/
    └── schema.sql
```
