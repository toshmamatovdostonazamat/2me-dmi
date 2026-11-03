#!/bin/bash
# GitHub repozitoriysi uchun fayllarni alohida papkaga yig'adi (R1-7: ma'lumotlar va kod).
#
# Ishlatish:
#   bash repo_yig.sh                     # ROOT = shu skript turgan 2ME-DMI papkasi, DEST = ../2ME-DMI_github
#   bash repo_yig.sh <ROOT> <DEST>
#
# Natija (DEST):
#   README.md, requirements.txt, .gitignore
#   results.ipynb                  — barcha rasm/jadvallarni hosil qiluvchi notebook
#   data/orca_data.tar.xz          — notebook uchun kerakli ORCA fayllari (asl papka tuzilmasida)
#   structures/s2_r2scan/*.xyz     — asosiy (r2SCAN-3c/SMD) geometriyalar
#   structures/s4_r2freq/*.xyz     — TightOpt Freq geometriyalari (15 vakil struktura)
#   inputs/<bosqich>/*.inp         — ORCA kirish fayllari
#   tables/, figures/              — notebook natijalari
#   scripts/                       — hisoblash va yordamchi skriptlar
set -e

ROOT=${1:-$(cd "$(dirname "$0")" && pwd)}
DEST=${2:-$(dirname "$ROOT")/2ME-DMI_github}
ROOT=$(cd "$ROOT" && pwd)
[ -d "$ROOT/PbI2" ] || { echo "!! $ROOT da PbI2/ papkasi yo'q — ROOT noto'g'ri"; exit 1; }
if [ -e "$DEST" ]; then echo "!! $DEST allaqachon bor — o'chiring yoki boshqa joy ko'rsating"; exit 1; fi
mkdir -p "$DEST"/{data,structures/s2_r2scan,structures/s4_r2freq,inputs,tables,figures,scripts}
cd "$ROOT"
echo "ROOT: $ROOT"
echo "DEST: $DEST"

# asosiy hisob papkalari (zaxira papkalari _v1, _v2fail, _s4_imag, _s4_uzilgan_* kirmaydi)
DIRS=$( { echo 2ME; echo DMI; ls -d */calc/*/ 2>/dev/null | sed 's#/$##'; } )
[ -d ligands_alpb ] && DIRS="$DIRS"$'\n'"ligands_alpb/2ME"$'\n'"ligands_alpb/DMI"

# ---------------------------------------------------------------- 1. structures
n2=0; n4=0
for d in $DIRS; do
  for f in "$d"/*_s2_r2scan.xyz; do [ -f "$f" ] && [ ! -L "$f" ] && cp "$f" "$DEST/structures/s2_r2scan/" && n2=$((n2+1)); done
  for f in "$d"/*_s4_r2freq.xyz; do [ -f "$f" ] && cp "$f" "$DEST/structures/s4_r2freq/" && n4=$((n4+1)); done
done
echo "structures: s2 = $n2, s4 = $n4"

# ---------------------------------------------------------------- 2. inputs (bosqich bo'yicha)
ni=0
for d in $DIRS; do
  for f in "$d"/*.inp; do
    [ -f "$f" ] || continue
    b=$(basename "$f")
    [[ "$b" == *_atom* ]] && continue
    st=$(echo "$b" | grep -oE '_s[0-9][a-z0-9_]*\.inp$' | sed 's/^_//; s/\.inp$//')
    [ -z "$st" ] && st=boshqa
    [[ "$d" == ligands_alpb/* ]] && st="${st}_ALPB"
    mkdir -p "$DEST/inputs/$st"; cp "$f" "$DEST/inputs/$st/"; ni=$((ni+1))
  done
done
echo "inputs: $ni ta fayl ($(ls "$DEST/inputs" | tr '\n' ' '))"

# ---------------------------------------------------------------- 3. data: notebook uchun ORCA fayllari
LIST=$(mktemp)
for d in $DIRS; do
  for f in "$d"/*_s2_r2scan.out "$d"/*_s2_r2scan.xyz "$d"/*_s3_freq.out \
           "$d"/*_s4_r2freq.out "$d"/*_s4_r2freq.xyz "$d"/*_s4_r2freq.hess \
           "$d"/*_s5_cpcm2me.out "$d"/*_s5_cpcmdmi.out "$d"/*_s6_wb97mv.out; do
    [ -e "$f" ] && echo "$f" >> "$LIST"
  done
done
echo "data: $(wc -l < "$LIST") ta fayl siqilmoqda (xz, bir necha daqiqa)..."
tar -chJf "$DEST/data/orca_data.tar.xz" -T "$LIST"     # -h: symlinklar (ligands_alpb) o'rniga haqiqiy fayllar
rm -f "$LIST"

# ---------------------------------------------------------------- 4. notebook, tables, figures, scripts
NB=""
for c in results.ipynb solubility_paper.ipynb; do [ -f "$c" ] && { NB=$c; break; }; done
[ -n "$NB" ] && cp "$NB" "$DEST/results.ipynb" || echo "!! results.ipynb topilmadi"
[ -d tables ] && cp tables/* "$DEST/tables/" 2>/dev/null || true
[ -d figures ] && cp figures/* "$DEST/figures/" 2>/dev/null || true
for s in blok0.sh blok1.sh blok2.sh imag_disp.py davom.sh blok1_tahlil.py repo_yig.sh; do
  [ -f "$s" ] && cp "$s" "$DEST/scripts/"
done

# ---------------------------------------------------------------- 5. requirements.txt (joriy python dan versiyalar)
python3 - "$DEST/requirements.txt" <<'EOF'
import sys, importlib, platform
out = [f"# Python {platform.python_version()}"]
for mod, pkg in [("numpy", "numpy"), ("pandas", "pandas"), ("scipy", "scipy"), ("matplotlib", "matplotlib"),
                 ("ase", "ase"), ("PIL", "pillow"), ("notebook", "notebook")]:
    try:
        v = importlib.import_module(mod).__version__
        out.append(f"{pkg}=={v}")
    except Exception:
        out.append(pkg)
open(sys.argv[1], "w").write("\n".join(out) + "\n")
EOF

# ---------------------------------------------------------------- 6. .gitignore va README.md
cat > "$DEST/.gitignore" <<'EOF'
# notebook ishga tushganda yaratiladigan papka va fayllar
.ipynb_checkpoints/
__pycache__/
results.zip
# arxivdan chiqarilgan ORCA fayllari (repozitoriyda faqat data/orca_data.tar.xz saqlanadi)
2ME/
DMI/
PbI2/
PbBr2/
FAI/
MABr/
ligands_alpb/
# katta ORCA fayllari
*.gbw
*.densities
*.densitiesinfo
*.tmp
EOF

ORCA_V=$(grep -m1 -oE "Program Version [0-9.]+" 2ME/*_s2_r2scan.out 2>/dev/null | head -1 | awk '{print $3}')
cat > "$DEST/README.md" <<EOF
# PbI₂, PbBr₂, FAI va MABr prekursorlarining 2-ME/DMI aralashmasida erishi — hisoblash ma'lumotlari

Ushbu repozitoriy maqolaning nazariy (cluster–continuum DFT) qismidagi barcha natijalarni qayta hosil qilish uchun
kerakli ma'lumotlar va kodni o'z ichiga oladi.

## Usul (qisqacha)
- Dastur: ORCA ${ORCA_V:-6.1.1}
- Geometriya: GFN2-xTB -> r²SCAN-3c / SMD(2-methoxyethanol)
- Termal tuzatma: GFN2-xTB (asosiy sxema); 15 ta vakil struktura uchun to'liq r²SCAN-3c/SMD (TightOpt, analitik chastotalar), qRRHO (ω₀ = 100 cm⁻¹)
- Sezgirlik testlari: CPCM(2-ME), CPCM (ε = 37,6; n = 1,472), ωB97M-V/def2-TZVP/SMD(2-ME)
- Termodinamik model: ligand almashinish muvozanatlari, massa balansi bilan to'yinish eruvchanligi

## Tuzilma
| Papka / fayl | Tarkibi |
| --- | --- |
| \`results.ipynb\` | barcha rasm, jadval va matndagi sonlarni (\`tables/summary_numbers.txt\`) hosil qiluvchi notebook |
| \`data/orca_data.tar.xz\` | notebook o'qiydigan ORCA chiqish fayllari (asl papka tuzilmasida) |
| \`structures/s2_r2scan/\` | asosiy r²SCAN-3c/SMD geometriyalari (.xyz) |
| \`structures/s4_r2freq/\` | TightOpt + chastota geometriyalari, vakil strukturalar (.xyz) |
| \`inputs/\` | ORCA kirish fayllari, hisob bosqichi bo'yicha: s1 = xTB opt, s2 = r²SCAN-3c opt, s3 = xTB freq, s4 = r²SCAN-3c TightOpt Freq, s5 = CPCM yagona nuqta, s6 = ωB97M-V yagona nuqta |
| \`tables/\`, \`figures/\` | notebook natijalari (CSV; PDF va 600 dpi PNG) |
| \`scripts/\` | hisoblarni ishga tushirish va yordamchi skriptlar |

Fayl nomlari: \`<prekursor>_b<DMI soni>[_<izomer>]\`; ion juftlari uchun \`c\` va \`a\` — kation va anion o'rinlaridagi DMI soni.

## Qayta hosil qilish
\`\`\`bash
pip install -r requirements.txt
tar -xJf data/orca_data.tar.xz        # 2ME/, DMI/, PbI2/, ... papkalari shu yerda paydo bo'ladi
jupyter notebook results.ipynb        # Run All
\`\`\`

## Iqtibos
Maqola chiqqandan keyin bibliografik ma'lumot qo'shiladi.
EOF

# ---------------------------------------------------------------- 7. hisobot
echo
echo "=== Tayyor: $DEST ==="
du -sh "$DEST"/* "$DEST"/data/* 2>/dev/null | sed 's#'"$DEST"'/##'
BIG=$(find "$DEST" -type f -size +95M)
if [ -n "$BIG" ]; then
  echo "!! GitHub 100 MB chegarasidan katta fayllar:"; echo "$BIG"
  echo "   Yechim: data arxivini GitHub Release'ga yuklang yoki 'split -b 90M' bilan bo'ling."
fi
echo
echo "Keyingi qadamlar:"
echo "  1. LICENSE faylini tanlang (corresponding author bilan kelishib)."
echo "  2. cd \"$DEST\" && git init && git add . && git commit -m \"Data and code for 2-ME/DMI solubility study\""
echo "  3. GitHub'da bo'sh repozitoriy oching va: git remote add origin <URL> && git push -u origin main"
