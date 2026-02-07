# Mocha to Aegisub (v1.0)

[English](#english) | [Türkçe](#türkçe)

---

## Türkçe

Bu Aegisub Scripti, Mocha üzerinden alınan tracking (takip) verilerini doğrudan Aegisub altyazılarına uygulamanızı sağlar. Ayrıca, tracking için video klipleri kırpan bir modülü de içerir.

### Özellikler

* **Frame-to-Frame Takip:** Position, scale ve rotation verilerini uygular.
* **Akıllı Offset:** Altyazınızın orijinal konumunu koruyarak takibi bu konuma göre hesaplar.
* **Kırpma Modülü:** Seçili altyazının olduğu video kesitini Mocha'da kullanılmak üzere FFmpeg kullanarak kırpar.
* **Çoklu Dil Desteği:** İngilizce ve Türkçe dil seçenekleri mevcuttur.

### Kurulum

1. Her iki `.lua` dosyasını da Aegisub automation klasörüne taşıyın:
   - `C:\Users\KULLANICI_ADI\AppData\Roaming\Aegisub\automation\autoload`
2. Kırpma modülünü kullanabilmeniz için bilgisayarınızda **FFmpeg**'in kurulu olduğundan emin olun.
3. Aegisub içerisinden script ayarlarına girerek FFmpeg dizinini tanımlayın.

### Kullanım

1. Hareket ettirmek istediğiniz altyazı satırını seçin.
2. `Automation > Mocha to Aegisub > Uygula` seçeneğine basın.
3. Mocha AE (After Effects) veya Mocha Pro üzerinden kopyaladığınız takip keyframe verisini kutucuğa yapıştırın ve Uygula butonuna basın.

---

## English

This Aegisub Script allows you to apply Mocha tracking data directly to Aegisub subtitles. It also includes a trimming module to prepare video clips for tracking.

### Features

* **Frame-by-frame Tracking:** Applies position, scale, and rotation.
* **Smart Offsets:** Keeps your subtitle's original relative position.
* **Trim Module:** Uses FFmpeg to cut specific parts of your video for Mocha.
* **Multi-Language:** Supports English and Turkish.

### Installation

1. Move both `.lua` files to your Aegisub automation folder:
   - `C:\Users\USERNAME\AppData\Roaming\Aegisub\automation\autoload`
2. Ensure you have **FFmpeg** installed to be able to use the Trim module.
3. Configure the FFmpeg path in the script's settings within Aegisub.

### Usage

1. Select a subtitle line.
2. Go to `Automation > Mocha to Aegisub > Apply`.
3. Paste your keyframe data and hit Apply.
