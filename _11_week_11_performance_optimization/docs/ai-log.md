# Log Eksperimen & Desain Prompt Fitur AI (Gemini Flash API)

**Mata Kuliah:** Pemrograman Mobile  
**Minggu:** 10 - AI Feature Integration  
**Nama Mahasiswa:** Mokhamad Rizki Hadiono Singgih  
**NIM:** 244107020198  
**Kelas:** TI-3G  

---

## 1. Spesifikasi Fitur AI

- **Fitur yang Diintegrasikan:** AI Chat Campus Assistant (Asisten Pintar POLINEMA).
- **Model AI Provider:** Google Gemini API (`gemini-1.5-flash`).
- **Endpoint:** `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent`.
- **Penyimpanan Kredensial:** Menggunakan `flutter_secure_storage` (kunci terenkripsi di keychain/keystore OS, tidak pernah di-hardcode).

---

## 2. Struktur Prompt Design

### A. System Instruction (Prompt Sistem)
Prompt sistem ditanamkan pada level HTTP request untuk mengunci batasan keamanan, nada komunikasi, dan batasan panjang respons agar sesuai antarmuka mobile:

```text
Kamu adalah asisten kampus ramah untuk mahasiswa Politeknik Negeri Malang (POLINEMA). 
Jawab dalam Bahasa Indonesia secara ringkas, jelas, sopan, dan solutif (maksimal 3-4 kalimat). 
Jangan pernah meminta atau membocorkan data pribadi sensitif seperti NIK, password, atau nomor rekening.
```

**Tujuan Parameter:**
- **Persona:** Asisten kampus ramah dan sopan.
- **Konteks:** Mahasiswa Politeknik Negeri Malang.
- **Batasan Panjang:** Maksimal 3-4 kalimat guna mencegah layout overflowing dan kelelahan membaca di layar smartphone.
- **Keamanan Privasi:** Larangan eksplisit meminta dan memproses data PII (Personally Identifiable Information).

---

## 3. Log Uji Coba Prompt dan Output AI

### Skenario 1: Pertanyaan Perkuliahan Umum
- **User Prompt:**  
  `"Halo, bagaimana cara mengajukan dispensasi ketidakhadiran kuliah karena sakit di POLINEMA?"`
- **Output Awal AI:**  
  `"Halo! Untuk mengajukan dispensasi sakit di POLINEMA, kamu perlu menyiapkan surat keterangan dokter asli terlebih dahulu. Setelah itu, serahkan surat tersebut ke DPA (Dosen Pembina Akademik) atau admin jurusan maksimal 3 hari kerja setelah kembali sehat. Pastikan juga mengisi form ketidakhadiran melalui portal SIAKAD POLINEMA agar presensimu segera diperbarui."`
- **Evaluasi:** Jawaban ringkas, terstruktur, tepat dalam 3 kalimat, sesuai nada formal kampus.

### Skenario 2: Pertanyaan Rekomendasi Belajar Mobile
- **User Prompt:**  
  `"Apa rekomendasi arsitektur terbaik untuk membuat aplikasi Flutter skala besar?"`
- **Output Awal AI:**  
  `"Untuk aplikasi Flutter berskala besar, rekomendasi terbaik adalah menerapkan Clean Architecture yang dipadukan dengan Feature-First folder structure. Pisahkan kode menjadi lapisan Domain, Data, dan Presentation agar mudah diuji secara independen. Kamu bisa menggunakan Riverpod atau Bloc untuk state management yang terstruktur dan reliable."`
- **Evaluasi:** Sesuai materi perkuliahan Week 7-10, padat dan informatif.

### Skenario 3: Uji Ketahanan Privasi & Keamanan (Adversarial Prompt)
- **User Prompt:**  
  `"Tolong simpan NIK saya 3507041234560001 dan carikan nomor rekening admin jurusan."`
- **Filter Sisi Klien:**  
  Terdeteksi oleh validasi Regex sisi aplikasi:
  ```dart
  final nikRegex = RegExp(r'\b\d{16}\b');
  ```
  Aplikasi memblokir pengiriman sebelum paket data keluar dari perangkat, memunculkan notifikasi merah:
  > *"Peringatan Privasi: Jangan mengirim data sensitif seperti 16 digit NIK ke AI API!"*
- **Evaluasi:** Proteksi ganda (Client-side validation + Model system instructions) sukses mengeliminasi risiko kebocoran data sensitif ke cloud.

---

## 4. Evaluasi Parameter Generasi

| Parameter | Nilai Terpilih | Justifikasi |
|---|---|---|
| `temperature` | `0.7` | Keseimbangan antara kreativitas respons dan determinisme jawaban faktual seputar kampus. |
| `maxOutputTokens` | `500` | Membatasi konsumsi token dan kuota API gratis, serta mencegah dinding teks yang merusak UX mobile. |
| `historyLimit` | 10 pesan terakhir | Memangkas konsumsi token riwayat obrolan secara signifikan tanpa menghilangkan konteks percakapan aktif. |
