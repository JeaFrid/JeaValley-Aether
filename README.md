# ✨JeaValley Aether✨

Terminal tabanlı Aether istemcisi; hesap oluşturur veya giriş yapar, seçtiğin yerel portu tüneller ve sana paylaşılabilir bir bağlantı üretir. Tünelin durumunu gösterir, istersen kapatırsın. Python zorunlu değildir; shell ve PowerShell sürümleri doğrudan çalışır.

## Gereksinimler
-------------
- Linux/macOS: `curl`, `jq` (paket yöneticisinden kur).  
- Windows: PowerShell 5+ (varsayılan), `aether.bat` yeterli.  
- Opsiyonel: Python 3.9+ (sadece `aether.py` kullanacaksan).

## Kurulum
-------
- Linux/macOS: `aether.sh` dosyasını çalıştırılabilir yap (`chmod +x aether.sh`).  
- Windows: `aether.bat` veya doğrudan `aether.ps1`.  
- Ortak: Aether uç noktasını değiştirmek için `JEATUNNEL_SERVER` ortam değişkenini ayarla (varsayılan: `http://127.0.0.1:8000`).

## Kullanım (temel komutlar)
-------------------------
- Etkileşimli menü: `./aether.sh` veya `aether.bat` (parametresiz).  
- Kayıt: `./aether.sh register --username ali --password 123456 --plan premium`  
  Windows: `aether.bat register --username ali --password 123456 --plan premium`
- Giriş: `./aether.sh login --username ali --password 123456`
- Tünel başlat: `./aether.sh run 9000`
- Durum: `./aether.sh status`
- Durdur: `./aether.sh stop`
- Oturum bilgisi: `./aether.sh whoami`
- Sunucu adresi ayarla: `./aether.sh config --server http://sunucu:8000`

Aynı komutlar Windows için `aether.bat` / `aether.ps1` ile birebir geçerlidir. Python kullanmak istersen: `python aether.py <komut>`.

## Akış (sıra/şema)
----------------
1) `register` veya `login` ile oturum aç.  
2) Yerelde çalışan servisinin portunu `run <port>` ile tünelle.  
3) Çıktıdaki paylaşım linkini karşı tarafa ilet.  
4) Gerekirse `status` ile isteklere/limite bak.  
5) İşin bitince `stop` ile oturumu kapat.  
6) `whoami` mevcut oturum bilgilerini gösterir.

## Konfigürasyon
-------------
- Linux/macOS oturum dosyası: `~/.jeatunnel.conf`  
- Windows oturum dosyası: `%USERPROFILE%\.jeatunnel.json`  
- Sunucu adresi ortam değişkeni: `JEATUNNEL_SERVER`  
- Konfigürasyon yolu ortam değişkeni: `JEATUNNEL_CONFIG`
# JeaValley-Aether
