#!/bin/bash
# Blok 0: xTB termal tuzatmalarini tuzatish (R1-1)
#  1) PbI2, PbBr2 (12 ta) + gaz fazadagi 2ME, DMI: XTB VeryTightOpt Freq (r2SCAN geometriyasidan)
#  2) ligands_alpb/{2ME,DMI}: XTB Freq ALPB(methanol) r2SCAN geometriyasida (FAI, MABr seriyalari uchun)
# Eski s3 fayllari har bir papkadagi _v1/ ga ko'chiriladi (o'chirilmaydi).

ROOT=/media/doston/72f1eff3-bf18-4476-8539-c8566520c822/FACsPbI3_VASP/FACsPbI3/ORCA/2ME-DMI
ORCA=/home/doston/orca_6_1_1/orca
NP=6
MAXCORE=2500

run_xtb () {   # $1=papka  $2=s3 bazaviy nom  $3=boshlang'ich xyz  $4=ORCA kalit so'zlari
  local d=$1 base=$2 xyz=$3 kw=$4
  cd "$d" || { echo "!! papka yo'q: $d"; return; }
  if [ ! -e "$xyz" ]; then echo "!! $d/$xyz topilmadi, o'tkazib yuborildi"; return; fi
  mkdir -p _v1
  for f in "${base}".*; do [ -e "$f" ] && mv "$f" _v1/; done
  cat > "${base}.inp" <<EOF
! ${kw}
%pal nprocs ${NP} end
%maxcore ${MAXCORE}
* xyzfile 0 1 ${xyz}
EOF
  echo ">> ${d#$ROOT/}/${base}"
  "$ORCA" "${base}.inp" > "${base}.out" 2>&1
  local st=FAIL
  grep -q "ORCA TERMINATED NORMALLY" "${base}.out" && st=OK
  local g im
  g=$(grep 'G-E(el)' "${base}.out" | tail -1 | awk '{print $3}')
  im=$(grep 'imaginary mode' "${base}.out" | awk '{print $2}' | tr '\n' ' ')
  [ -z "$im" ] && im="yoq"
  [ -z "$g" ] && g="-"
  echo "   $st   G-E(el) = $g Eh   mavhum: $im"
}

echo "=== 1. PbX2 seriyalari: VeryTightOpt Freq (gaz) ==="
for pre in PbI2 PbBr2; do
  for d in "$ROOT/$pre"/calc/${pre}_b*; do
    lab=$(basename "$d")
    run_xtb "$d" "${lab}_s3_freq" "${lab}_s2_r2scan.xyz" "XTB VeryTightOpt Freq"
  done
done

echo "=== 1b. Erkin 2ME, DMI (gaz, PbX2 seriyalari uchun) ==="
for s in 2ME DMI; do
  run_xtb "$ROOT/$s" "${s}_s3_freq" "${s}_s2_r2scan.xyz" "XTB VeryTightOpt Freq"
done

echo "=== 2. Erkin 2ME, DMI: ALPB(methanol), r2SCAN geometriyasida (FAI, MABr uchun) ==="
for s in 2ME DMI; do
  d="$ROOT/ligands_alpb/$s"
  mkdir -p "$d"
  ln -sf "$ROOT/$s/${s}_s2_r2scan.out" "$d/"
  ln -sf "$ROOT/$s/${s}_s2_r2scan.xyz" "$d/"
  run_xtb "$d" "${s}_s3_freq" "${s}_s2_r2scan.xyz" "XTB Freq ALPB(methanol)"
done

echo "=== Tayyor ==="
