# SmileShot 📸

![Flutter](https://img.shields.io/badge/Framework-Flutter-02569B?style=for-the-badge&logo=flutter)
![Dart](https://img.shields.io/badge/Language-Dart-0175C2?style=for-the-badge&logo=dart)
![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=for-the-badge)

SmileShot adalah aplikasi kamera cerdas berbasis Flutter yang dirancang untuk membuat pengalaman fotografi lebih interaktif dan menyenangkan. Dengan memanfaatkan Google ML Kit, aplikasi ini tidak hanya mengambil gambar, tetapi juga memperkenalkan cara baru berinteraksi dengan kamera melalui deteksi ekspresi wajah secara *real-time*.

## Tampilan Aplikasi

| Mode Photo | Mode Filter |
| :---: | :---: |
| ![Mode Photo](http://uasspk.ryvidia.my.id/static/images/photo_screen.jpeg) | ![Mode Filter](http://uasspk.ryvidia.my.id/static/images/filter_screen.jpeg) |
| **Mode Game** | **Mode Pro** |
| ![Mode Game](http://uasspk.ryvidia.my.id/static/images/game_screen.jpeg) | ![Mode Pro](http://uasspk.ryvidia.my.id/static/images/pro_screen.jpeg) |


## ✨ Fitur Utama

Aplikasi ini memiliki 4 mode utama yang dapat diakses dengan mudah:

### 📸 **Mode Photo**
Mode kamera standar yang disempurnakan dengan fitur cerdas.
- **Smile to Shoot**: Ambil foto secara otomatis hanya dengan tersenyum!
- **Timer**: Pilihan timer 3, 5, atau 10 detik dengan *countdown* visual.
- **Kontrol Dasar**: Akses cepat untuk Flash dan beralih antara kamera depan/belakang.
- **Galeri Cepat**: Lihat foto terakhir dan buka galeri internal langsung dari layar kamera.

### 🎨 **Mode Filter**
Tambahkan sentuhan artistik pada foto Anda secara *real-time*.
- **Filter Live**: Lihat efek filter secara langsung pada pratinjau kamera sebelum gambar diambil.
- **Beragam Efek**: Termasuk filter *Blend Mode* (seperti *Burn*, *Dodge*) dan filter matriks (seperti *Grayscale*).
- **Pratinjau Akurat (WYSIWYG)**: Hasil foto yang disimpan sama persis dengan yang terlihat di layar, berkat teknik *widget capture*.

### 🎮 **Mode Game**
Ubah kamera Anda menjadi arena permainan interaktif.
- **Expression Challenge**: Tantangan untuk meniru ekspresi wajah yang ditampilkan di layar.
- **Deteksi Ekspresi Real-time**: Menggunakan ML Kit untuk mendeteksi ekspresi seperti **Senyum**, **Kaget**, dan **Tidur** (mata terpejam).
- **Sistem Skor & Waktu**: Dapatkan skor untuk setiap ekspresi yang berhasil ditiru dalam batas waktu 60 detik.

### 🔧 **Mode Pro**
Dapatkan kontrol manual penuh atas pengaturan kamera.
- **Kontrol Exposure (EV)**: Atur tingkat kecerahan gambar dengan slider yang presisi.
- **Kontrol Zoom**: Lakukan zoom in/out secara halus menggunakan slider.
- **Kunci Fokus**: Aktifkan atau nonaktifkan *autofocus* untuk kontrol kreatif yang lebih besar.

## 🛠️ Arsitektur & Teknologi

Proyek ini dibangun dengan arsitektur yang bersih dan modern untuk memastikan skalabilitas dan kemudahan pengelolaan.

- **Framework**: **Flutter**
- **Bahasa**: **Dart**
- **State Management**: **Provider** (`ChangeNotifier`)
- **Machine Learning**: **Google ML Kit**
- **Plugin Utama**: `camera`, `permission_handler`, `path_provider`

Arsitektur aplikasi ini terpusat pada kelas `CameraManager` yang berfungsi sebagai *single source of truth*. Ini memungkinkan setiap layar (mode) untuk bereaksi terhadap perubahan dan berbagi logika kamera yang sama, sehingga kode menjadi lebih bersih dan mudah dikelola.

## 🚀 Memulai

Untuk menjalankan proyek ini secara lokal, ikuti langkah-langkah berikut:

1.  **Clone repositori ini**
    ```sh
    git clone [https://github.com/username/smileshot.git](https://github.com/username/smileshot.git)
    ```

2.  **Masuk ke direktori proyek**
    ```sh
    cd smileshot
    ```

3.  **Instal semua dependencies**
    ```sh
    flutter pub get
    ```

4.  **Jalankan aplikasi**
    ```sh
    flutter run
    ```
Pastikan Anda memiliki perangkat atau emulator yang terhubung.

## 📁 Struktur Proyek

```bash
lib/
├── main.dart                   # Titik masuk utama aplikasi dan navigasi

├── managers/
│   └── camera_manager.dart     # Otak aplikasi, semua logika kamera & state

├── screens/
│   ├── photo_screen.dart       # UI untuk Mode Photo
│   ├── filter_screen.dart      # UI untuk Mode Filter
│   ├── game_screen.dart        # UI untuk Mode Game
│   └── pro_screen.dart         # UI untuk Mode Pro

└── widgets/
    └── timer_selector_widget.dart  # Contoh widget yang bisa digunakan ulang
```