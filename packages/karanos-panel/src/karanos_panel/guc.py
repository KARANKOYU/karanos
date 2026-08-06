"""Güç eylemleri.

systemd/logind üzerinden. `sudo` çağırmıyoruz: logind, oturum sahibi
yerel kullanıcıya kapatma/yeniden başlatma iznini polkit üzerinden
zaten veriyor. Böylece parola sorulmuyor ve panelin root yetkisine
ihtiyacı olmuyor.
"""

import shutil
import subprocess


def _calistir(komut):
    if shutil.which(komut[0]) is None:
        print(f"karanos-panel: {komut[0]} yok, eylem atlandi")
        return
    try:
        subprocess.Popen(komut)
    except OSError as hata:
        print(f"karanos-panel: {' '.join(komut)} basarisiz: {hata}")


def kapat():
    _calistir(["systemctl", "poweroff"])


def yeniden_baslat():
    _calistir(["systemctl", "reboot"])


def uyku():
    _calistir(["systemctl", "suspend"])


def oturumu_kapat():
    # Openbox oturumu kendisi kapatıyor; logind'e gitmek gerekmiyor ve
    # oturumu düzgün sonlandırması için doğru yol da bu.
    if shutil.which("openbox") is not None:
        _calistir(["openbox", "--exit"])
    else:
        _calistir(["loginctl", "terminate-session", "self"])


def kilitle():
    # 5. aşamada karanos-greeter ile birlikte kendi kilit ekranımız
    # gelecek; şimdilik logind'in kilit sinyali kullanılıyor.
    _calistir(["loginctl", "lock-session"])
