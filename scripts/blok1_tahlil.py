#!/usr/bin/env python3
"""
Blok 0 + Blok 1 tahlili (R1-1, R2-1). Faqat standart Python kutubxonalari ishlatiladi.

 1) Blok 0 ta'siri: ΔG_b,i (3-tenglama) eski (tables/exchange_dG_v1.csv) va yangi s3 fayllar bilan
 2) Blok 1: termokimyo darajasi
      A = E(s2, r2SCAN-3c/SMD) + [G-E(el)](s3, GFN2-xTB)          <- qo'lyozmadagi sxema
      B = E(s4) + [G-E(el)](s4), hammasi r2SCAN-3c/SMD, TightOpt  <- to'liq sxema
    B - A = geometriya relaksatsiyasi (E_s4 - E_s2) + termokimyo darajasi (GmE_s4 - GmE_s3)
 3) qRRHO sezgirligi s4 chastotalaridan: RRHO, qRRHO(ω0 = 50, 100, 150 cm-1)
Natijalar ekranga va tables/blok1_*.csv ga yoziladi.
"""
import os, re, glob, csv, math, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else \
    "/media/doston/72f1eff3-bf18-4476-8539-c8566520c822/FACsPbI3_VASP/FACsPbI3/ORCA/2ME-DMI"
TAB = os.path.join(ROOT, "tables")
PRE = ["PbI2", "PbBr2", "FAI", "MABr"]
REF = {"PbI2": "b0", "PbBr2": "b0", "FAI": "b0_c0a0", "MABr": "b0_c0a0"}
HA, T = 2625.4996, 298.15
R = 8.314462618e-3                       # kJ/mol/K
h, kB, c, NA = 6.62607015e-34, 1.380649e-23, 2.99792458e10, 6.02214076e23   # c: cm/s


# ---------------------------------------------------------------- o'qish
def last(path, pat, grp=1):
    if not path or not os.path.exists(path):
        return None
    m = re.findall(pat, open(path, errors="ignore").read())
    return float(m[-1]) if m else None


E_of = lambda p: last(p, r"FINAL SINGLE POINT ENERGY\s+(-?\d+\.\d+)")
G_of = lambda p: last(p, r"G-E\(el\)\s+\.\.\.\s+(-?\d+\.\d+)\s+Eh")


def freqs(path):
    """oxirgi VIBRATIONAL FREQUENCIES blokidagi noldan farqli chastotalar, cm-1"""
    txt = open(path, errors="ignore").read()
    i = txt.rfind("VIBRATIONAL FREQUENCIES")
    if i < 0:
        return None
    out, started = [], False
    for line in txt[i:].splitlines()[1:]:
        m = re.match(r"\s*\d+:\s+(-?\d+\.\d+)\s+cm\*\*-1", line)
        if m:
            started = True
            v = float(m.group(1))
            if abs(v) > 1e-3:
                out.append(v)
        elif started and line.strip():
            break
    return out


def xyz(path):
    if not path or not os.path.exists(path):
        return None
    L = open(path).read().split("\n")
    n = int(L[0])
    return [tuple(map(float, l.split()[1:4])) for l in L[2:2 + n]]


def drmsd(a, b):
    """masofalar matritsasi bo'yicha RMSD (aylanishga bog'liq emas), Å"""
    if not a or not b or len(a) != len(b):
        return None
    s, k = 0.0, 0
    for i in range(len(a)):
        for j in range(i + 1, len(a)):
            s += (math.dist(a[i], a[j]) - math.dist(b[i], b[j])) ** 2
            k += 1
    return math.sqrt(s / k)


def gvib(nu, w0=None):
    """tebranma erkin energiya, kJ/mol. w0=None -> RRHO; aks holda Grimme qRRHO (entropiya)"""
    Bav = 1e-44                                     # kg m^2
    G = 0.0
    for v in nu:
        if v <= 0:
            continue
        x = h * c * v / (kB * T)
        zpe_e = R * T * (x / 2 + x / math.expm1(x))
        Sh = R * (x / math.expm1(x) - math.log(-math.expm1(-x)))
        S = Sh
        if w0:
            mu = h / (8 * math.pi ** 2 * c * v)
            mu_p = mu * Bav / (mu + Bav)
            Sr = R * (0.5 + math.log(math.sqrt(8 * math.pi ** 3 * mu_p * kB * T / h ** 2)))
            wt = 1 / (1 + (w0 / v) ** 4)
            S = wt * Sh + (1 - wt) * Sr
        G += zpe_e - T * S
    return G


# ---------------------------------------------------------------- fayllar
def species(pre):
    out = {}
    for d in sorted(glob.glob(os.path.join(ROOT, pre, "calc", f"{pre}_b*"))):
        lab = os.path.basename(d)[len(pre) + 1:]
        b = lambda s: os.path.join(d, f"{pre}_{lab}_{s}")
        out[lab] = dict(s2=b("s2_r2scan.out"), s3=b("s3_freq.out"), s4=b("s4_r2freq.out"),
                        x2=b("s2_r2scan.xyz"), x4=b("s4_r2freq.xyz"))
    return out


def ligand(name, pre):
    d = os.path.join(ROOT, name)
    s3dir = os.path.join(ROOT, "ligands_alpb", name) if pre in ("FAI", "MABr") else d
    return dict(s2=f"{d}/{name}_s2_r2scan.out", s3=f"{s3dir}/{name}_s3_freq.out",
                s4=f"{d}/{name}_s4_r2freq.out")


bnum = lambda lab: int(re.match(r"b(\d+)", lab).group(1))


def dG(Gc, G0, G2, GD, b):
    return Gc - G0 + b * (G2 - GD)


def table(title, head, rows, fname=None):
    print(f"\n{title}")
    w = [max(len(str(x)) for x in [hd] + [r[i] for r in rows]) for i, hd in enumerate(head)]
    print("  ".join(str(hd).rjust(w[i]) for i, hd in enumerate(head)))
    for r in rows:
        print("  ".join(str(x).rjust(w[i]) for i, x in enumerate(r)))
    if fname:
        with open(os.path.join(TAB, fname), "w", newline="") as f:
            csv.writer(f).writerows([head] + rows)


f1 = lambda v: "-" if v is None else f"{v:.1f}"
f2 = lambda v: "-" if v is None else f"{v:.2f}"

# ================================================================ 1) Blok 0 ta'siri
old = {}
p_old = os.path.join(TAB, "exchange_dG_v1.csv")
if os.path.exists(p_old):
    for r in csv.DictReader(open(p_old)):
        old[(r["prekursor"], r["label"])] = float(r["dG_kJ"])

rows0, A = [], {}
for pre in PRE:
    sp = species(pre)
    L2, LD = ligand("2ME", pre), ligand("DMI", pre)
    try:
        G2 = (E_of(L2["s2"]) + G_of(L2["s3"])) * HA
        GD = (E_of(LD["s2"]) + G_of(LD["s3"])) * HA
        G0 = (E_of(sp[REF[pre]]["s2"]) + G_of(sp[REF[pre]]["s3"])) * HA
    except (TypeError, KeyError):
        print(f"!! {pre}: mos yozuv yoki erituvchi fayli topilmadi"); continue
    for lab, f in sp.items():
        e, g = E_of(f["s2"]), G_of(f["s3"])
        if e is None or g is None:
            continue
        new = dG((e + g) * HA, G0, G2, GD, bnum(lab))
        A[(pre, lab)] = new
        o = old.get((pre, lab))
        rows0.append([pre, lab, bnum(lab), f1(o), f1(new), f1(None if o is None else new - o)])
table("1) Blok 0 ta'siri: ΔG_b,i (3-tenglama), kJ/mol  [eski = exchange_dG_v1.csv]",
      ["prekursor", "label", "b", "eski", "yangi", "farq"], rows0, "blok1_blok0_effect.csv")

# ================================================================ 2) Blok 1: termokimyo darajasi
rows1, rowsq, info = [], [], []
for pre in PRE:
    sp = species(pre)
    L2, LD = ligand("2ME", pre), ligand("DMI", pre)
    ref = sp.get(REF[pre])
    need = [L2["s4"], LD["s4"], ref and ref["s4"]]
    if not all(p and G_of(p) is not None for p in need):
        print(f"!! {pre}: b0 yoki erituvchilar uchun s4 natijasi yo'q, o'tkazildi"); continue

    def parts(f):
        return dict(E2=E_of(f["s2"]) * HA, g3=G_of(f["s3"]) * HA,
                    E4=E_of(f["s4"]) * HA, g4=G_of(f["s4"]) * HA, nu=freqs(f["s4"]))

    P2, PD, P0 = parts(L2), parts(LD), parts(ref)
    for lab, f in sp.items():
        if lab == REF[pre] or G_of(f["s4"]) is None:
            continue
        Pc, b = parts(f), bnum(lab)
        d = lambda k: Pc[k] - P0[k] + b * (P2[k] - PD[k])
        dA = d("E2") + d("g3")
        dB = d("E4") + d("g4")
        rows1.append([pre, lab, b, f1(dA), f1(dB), f1(dB - dA), f1(d("E4") - d("E2")), f1(d("g4") - d("g3"))])
        # qRRHO sezgirligi: faqat tebranma qism o'zgaradi, qolgani bir xil
        gv = {}
        for key, w0 in [("RRHO", None), ("q50", 50.0), ("q100", 100.0), ("q150", 150.0)]:
            G = lambda P: gvib(P["nu"], w0)
            gv[key] = G(Pc) - G(P0) + b * (G(P2) - G(PD))
        rowsq.append([pre, lab, b] + [f2(gv[k] - gv["q100"]) for k in ("RRHO", "q50", "q150")])

    for lab in [REF[pre]] + [l for l in sp if l != REF[pre]]:
        f = sp[lab]
        if G_of(f["s4"]) is None:
            continue
        nu = freqs(f["s4"]) or []
        txt = open(f["s4"], errors="ignore").read()
        info.append([pre, lab, txt.count("GEOMETRY OPTIMIZATION CYCLE"),
                     "YO'Q" if "did not converge" in txt else "ha",
                     sum(1 for v in nu if v < 0), f1(min(nu) if nu else None),
                     sum(1 for v in nu if 0 < v < 50), f2(drmsd(xyz(f["x2"]), xyz(f["x4"])))])

for nm in ("DMI", "2ME"):
    p = ligand(nm, "PbI2")["s4"]
    if G_of(p) is not None:
        nu = freqs(p) or []
        x2 = xyz(os.path.join(ROOT, nm, f"{nm}_s2_r2scan.xyz"))
        x4 = xyz(os.path.join(ROOT, nm, f"{nm}_s4_r2freq.xyz"))
        txt = open(p, errors="ignore").read()
        info.insert(0, ["erituvchi", nm, txt.count("GEOMETRY OPTIMIZATION CYCLE"),
                        "YO'Q" if "did not converge" in txt else "ha",
                        sum(1 for v in nu if v < 0), f1(min(nu) if nu else None),
                        sum(1 for v in nu if 0 < v < 50), f2(drmsd(x2, x4))])

table("2a) s4 hisoblar holati",
      ["prekursor", "label", "opt_tsikl", "yaqinlashdi", "n_mavhum", "min_nu", "n(<50cm-1)", "dRMSD_s2-s4,A"],
      info, "blok1_status.csv")
table("2b) ΔG_b,i, kJ/mol:  A = qo'lyozma (r2SCAN-3c E + xTB termo),  B = to'liq r2SCAN-3c/SMD\n"
      "     B-A = geometriya (E_s4-E_s2) + termokimyo darajasi (GmE_s4-GmE_s3)",
      ["prekursor", "label", "b", "A", "B", "B-A", "geom", "termo"], rows1, "blok1_thermo.csv")
table("3) qRRHO sezgirligi (s4 chastotalari): ΔG_b ning qRRHO(ω0 = 100 cm-1) dan farqi, kJ/mol",
      ["prekursor", "label", "b", "RRHO", "qRRHO_50", "qRRHO_150"], rowsq, "blok1_qrrho.csv")

if rows1:
    mx = max(abs(float(r[5])) for r in rows1)
    mq = max(abs(float(x)) for r in rowsq for x in r[3:]) if rowsq else float("nan")
    print(f"\nXulosa: |B - A| max = {mx:.1f} kJ/mol;  qRRHO/RRHO tanlovi bo'yicha max = {mq:.1f} kJ/mol")
