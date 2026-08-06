#!/usr/bin/env python3
"""QEMU screendump'inin (PPM) gercekten bir masaustu gosterip
gostermedigini olcer.

NEDEN VAR: 1. ve 2. asamada CI yesil yandi ama QEMU ekrani simsiyahti —
grafik oturum hic acilmamisti. "RESULT=OK" satirina bakmak yetmiyor;
ekranda bir sey CIZILDIGINI de dogrulamak gerekiyor.

Olcut iki tane, ikisi de gecmeli:
  1. Renk cesitliligi: kacta kac farkli renk var. Bos bir X kok penceresi
     tek renktir; duvar kagidi degradesi binlerce renk uretir.
  2. Parlaklik yayilimi (standart sapma): tek duz renkle doldurulmus bir
     ekran 0'a yakin sapma verir.

Kullanim:  screen-not-blank.py <dosya.ppm> [--min-renk N] [--min-sapma X]
Cikis:     0 = ekranda icerik var, 1 = bos/duz ekran, 2 = dosya okunamadi
"""

import sys


def ppm_oku(path):
	with open(path, "rb") as fh:
		d = fh.read()
	if d[:2] != b"P6":
		return None
	parts, idx = [], 2
	while len(parts) < 3:
		while idx < len(d) and d[idx:idx + 1].isspace():
			idx += 1
		if d[idx:idx + 1] == b"#":
			while idx < len(d) and d[idx:idx + 1] != b"\n":
				idx += 1
			continue
		start = idx
		while idx < len(d) and not d[idx:idx + 1].isspace():
			idx += 1
		parts.append(int(d[start:idx]))
	idx += 1
	w, h = parts[0], parts[1]
	return w, h, d[idx:idx + w * h * 3]


def main():
	if len(sys.argv) < 2:
		sys.exit("kullanim: screen-not-blank.py <dosya.ppm> [--min-renk N] [--min-sapma X]")
	path = sys.argv[1]
	min_renk = 24
	min_sapma = 3.0
	for i, a in enumerate(sys.argv):
		if a == "--min-renk":
			min_renk = int(sys.argv[i + 1])
		elif a == "--min-sapma":
			min_sapma = float(sys.argv[i + 1])

	veri = ppm_oku(path)
	if not veri:
		print(f"EKRAN-TANI: {path} okunamadi (PPM degil)")
		return 2
	w, h, raw = veri
	if len(raw) < w * h * 3:
		print(f"EKRAN-TANI: {path} eksik ({len(raw)} bayt)")
		return 2

	# Her pikseli gezmek gereksiz; 4'er piksel atlayarak ornekliyoruz.
	adim = 4 * 3
	renkler = set()
	toplam = 0
	kare_toplam = 0
	sayi = 0
	for off in range(0, w * h * 3 - 3, adim):
		r, g, b = raw[off], raw[off + 1], raw[off + 2]
		renkler.add((r, g, b))
		parlaklik = (r * 299 + g * 587 + b * 114) / 1000.0
		toplam += parlaklik
		kare_toplam += parlaklik * parlaklik
		sayi += 1

	ort = toplam / sayi
	sapma = max(0.0, (kare_toplam / sayi) - ort * ort) ** 0.5

	print(f"EKRAN-TANI: {w}x{h} · {len(renkler)} farkli renk · "
	      f"ortalama parlaklik {ort:.1f} · sapma {sapma:.2f}")

	if len(renkler) < min_renk and sapma < min_sapma:
		print(f"EKRAN-TANI: BOS — en az {min_renk} renk ve {min_sapma} sapma bekleniyordu")
		return 1
	print("EKRAN-TANI: ekranda icerik var")
	return 0


if __name__ == "__main__":
	sys.exit(main())
