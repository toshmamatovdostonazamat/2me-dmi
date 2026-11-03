#!/usr/bin/env python3
"""
s4 hisoblarida mavhum chastota qolgan tuzilmalarni qayta optimallashga tayyorlash.
Har bir shunday tuzilma uchun:
  - <label>_s4_r2freq.hess dan mavhum moda(lar) vektori o'qiladi;
  - optimallashgan geometriya shu moda(lar) bo'yicha siljitiladi (eng katta atom siljishi = AMP Å)
    va <label>_s4_disp.xyz ga yoziladi;
  - eski s4 fayllari _s4_imag/ papkasiga ko'chiriladi (o'chirilmaydi).
Shundan keyin blok1.sh shu tuzilmalarni _s4_disp.xyz dan qayta hisoblaydi.

Ishlatish:  python3 imag_disp.py            -> faqat ro'yxatni ko'rsatadi (hech narsa o'zgarmaydi)
            python3 imag_disp.py --apply    -> siljitadi va ko'chiradi
"""
import os, re, glob, sys, shutil, math

ROOT = "/media/doston/72f1eff3-bf18-4476-8539-c8566520c822/FACsPbI3_VASP/FACsPbI3/ORCA/2ME-DMI"
AMP = 0.25            # Å
APPLY = "--apply" in sys.argv
args = [a for a in sys.argv[1:] if not a.startswith("--")]
if args:
    ROOT = args[0]


def read_hess(path):
    L = open(path, errors="ignore").read().split("\n")
    i = next(k for k, l in enumerate(L) if l.strip() == "$vibrational_frequencies")
    n = int(L[i + 1])
    freqs = [float(L[i + 2 + k].split()[1]) for k in range(n)]
    i = next(k for k, l in enumerate(L) if l.strip() == "$normal_modes")
    nr, nc = map(int, L[i + 1].split())
    M = [[0.0] * nc for _ in range(nr)]
    k, cols = i + 2, []
    while k < len(L) and len(cols) < nc + 1:
        s = L[k].split()
        if not s or s[0].startswith("$"):
            break
        if all(re.fullmatch(r"\d+", x) for x in s):          # ustunlar sarlavhasi
            cols = list(map(int, s)); k += 1
            for r in range(nr):
                vals = list(map(float, L[k + r].split()[1:]))
                for j, c in enumerate(cols):
                    M[r][c] = vals[j]
            k += nr
            if cols[-1] == nc - 1:
                break
        else:
            k += 1
    return freqs, M


def read_xyz(p):
    L = open(p).read().split("\n")
    n = int(L[0])
    return [(l.split()[0], list(map(float, l.split()[1:4]))) for l in L[2:2 + n]]


def write_xyz(p, at, comment):
    with open(p, "w") as f:
        f.write(f"{len(at)}\n{comment}\n")
        for s, (x, y, z) in at:
            f.write(f"{s:2s} {x:14.8f} {y:14.8f} {z:14.8f}\n")


outs = sorted(glob.glob(os.path.join(ROOT, "*", "calc", "*", "*_s4_r2freq.out")) +
              glob.glob(os.path.join(ROOT, "*", "*_s4_r2freq.out")))
found = 0
for out in outs:
    txt = open(out, errors="ignore").read()
    if "imaginary mode" not in txt:
        continue
    d, base = os.path.dirname(out), os.path.basename(out)[:-4]
    lab = base[:-len("_s4_r2freq")]
    hess, xyz = os.path.join(d, base + ".hess"), os.path.join(d, base + ".xyz")
    if not (os.path.exists(hess) and os.path.exists(xyz)):
        print(f"!! {lab}: .hess yoki .xyz yo'q"); continue
    freqs, M = read_hess(hess)
    imag = [k for k, v in enumerate(freqs) if v < 0]
    at = read_xyz(xyz)
    disp = [[0.0, 0.0, 0.0] for _ in at]
    for k in imag:
        for a in range(len(at)):
            for x in range(3):
                disp[a][x] += M[3 * a + x][k]
    mx = max(math.sqrt(sum(v * v for v in d3)) for d3 in disp) or 1.0
    new = [(s, [p[x] + AMP * disp[a][x] / mx for x in range(3)]) for a, (s, p) in enumerate(at)]
    big = sorted(range(len(at)), key=lambda a: -sum(v * v for v in disp[a]))[:4]
    who = ", ".join(f"{at[a][0]}{a}" for a in big)
    print(f"{lab:16s} mavhum: {' '.join(f'{freqs[k]:.1f}' for k in imag):24s} eng ko'p siljiydigan atomlar: {who}")
    found += 1
    if APPLY:
        write_xyz(os.path.join(d, f"{lab}_s4_disp.xyz"), new,
                  f"{lab}: s4 geometriyasi mavhum moda(lar) bo'yicha {AMP} A siljitilgan")
        os.makedirs(os.path.join(d, "_s4_imag"), exist_ok=True)
        for f in glob.glob(os.path.join(d, base + ".*")):
            shutil.move(f, os.path.join(d, "_s4_imag", os.path.basename(f)))

print(f"\nJami {found} ta tuzilma." + ("" if APPLY else "  O'zgartirish uchun: python3 imag_disp.py --apply"))
