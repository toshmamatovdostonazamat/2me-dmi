#!/bin/bash
# Blok 1 (R1-1, R2-1): vakil tuzilmalar uchun to'liq r2SCAN-3c/SMD(2-ME) termokimyo
#   ! r2SCAN-3c TightOpt Freq, s2_r2scan geometriyasidan boshlab
# Natija: <papka>/<label>_s4_r2freq.out  (notebook o'qiydigan s2/s3 fayllarga tegilmaydi)
#
# Ishlatish:
#   bash blok1.sh                 -> hammasi (ro'yxat tartibida, kichigidan kattasiga)
#   bash blok1.sh 2ME DMI         -> faqat ko'rsatilganlar (sinov uchun)
# Qayta ishga tushirilsa, tugagan hisoblar o'tkazib yuboriladi.

ROOT=/media/doston/72f1eff3-bf18-4476-8539-c8566520c822/FACsPbI3_VASP/FACsPbI3/ORCA/2ME-DMI
ORCA=/home/doston/orca_6_1_1/orca
NP=6
MAXCORE=2500

# label  papka (ROOT ga nisbatan)
LIST="
2ME            2ME
DMI            DMI
PbI2_b0        PbI2/calc/PbI2_b0
PbBr2_b0       PbBr2/calc/PbBr2_b0
PbBr2_b1       PbBr2/calc/PbBr2_b1
PbI2_b2_cis    PbI2/calc/PbI2_b2_cis
PbBr2_b2_cis   PbBr2/calc/PbBr2_b2_cis
PbI2_b4        PbI2/calc/PbI2_b4
PbBr2_b4       PbBr2/calc/PbBr2_b4
MABr_b0_c0a0   MABr/calc/MABr_b0_c0a0
FAI_b0_c0a0    FAI/calc/FAI_b0_c0a0
MABr_b2_c2a0   MABr/calc/MABr_b2_c2a0
FAI_b2_c2a0    FAI/calc/FAI_b2_c2a0
MABr_b4_c2a2   MABr/calc/MABr_b4_c2a2
FAI_b4_c2a2    FAI/calc/FAI_b4_c2a2
"

done_ok () { grep -q "ORCA TERMINATED NORMALLY" "$1" 2>/dev/null && grep -q "G-E(el)" "$1"; }

# "bash blok1.sh all" -> vakil ro'yxat o'rniga barcha tuzilmalar (32 ta + 2ME, DMI)
if [ "$1" = "all" ]; then
  shift
  LIST="2ME 2ME
DMI DMI"
  for pre in PbI2 PbBr2 FAI MABr; do
    for dd in "$ROOT/$pre"/calc/${pre}_b*; do
      LIST="$LIST
$(basename "$dd") $pre/calc/$(basename "$dd")"
    done
  done
fi

while read -r lab rel <&3; do
  [ -z "$lab" ] && continue
  if [ $# -gt 0 ] && [[ ! " $* " =~ " $lab " ]]; then continue; fi
  d="$ROOT/$rel"; base="${lab}_s4_r2freq"; xyz="${lab}_s2_r2scan.xyz"
  cd "$d" || { echo "!! papka yo'q: $d"; continue; }
  if done_ok "${base}.out"; then echo ">> $lab: allaqachon tugagan, o'tkazildi"; continue; fi
  # imag_disp.py mavhum moda bo'yicha siljitgan geometriya bo'lsa, shundan boshlanadi
  [ -e "${lab}_s4_disp.xyz" ] && xyz="${lab}_s4_disp.xyz"
  [ -e "$xyz" ] || { echo "!! $d/$xyz topilmadi"; continue; }

  cat > "${base}.inp" <<EOF
! r2SCAN-3c TightOpt Freq TightSCF CPCM(2-methoxyethanol)
%pal nprocs ${NP} end
%maxcore ${MAXCORE}
%cpcm
  smd true
  SMDsolvent "2-methoxyethanol"
end
%geom
  MaxIter 300
end
* xyzfile 0 1 ${xyz}
EOF
  echo ">> $lab  ($(date '+%H:%M'), boshlang'ich: $xyz)"
  t0=$(date +%s)
  "$ORCA" "${base}.inp" > "${base}.out" 2>&1 < /dev/null
  dt=$(( ($(date +%s) - t0) / 60 ))

  st=FAIL; grep -q "ORCA TERMINATED NORMALLY" "${base}.out" && st=OK
  conv="yaqinlashdi"; grep -q "did not converge" "${base}.out" && conv="YAQINLASHMADI"
  hess=$(grep -m1 -i -o -E "(analytic|numeric)[a-z ]*(hessian|frequenc)[a-z]*" "${base}.out")
  E=$(grep 'FINAL SINGLE POINT ENERGY' "${base}.out" | tail -1 | awk '{print $5}')
  g=$(grep 'G-E(el)' "${base}.out" | tail -1 | awk '{print $3}')
  im=$(grep 'imaginary mode' "${base}.out" | awk '{print $2}' | tr '\n' ' ')
  [ -z "$im" ] && im="yoq"; [ -z "$g" ] && g="-"; [ -z "$hess" ] && hess="?"
  echo "   $st  opt: $conv  ${dt} min  [$hess]"
  echo "   E = $E  G-E(el) = $g Eh  mavhum: $im"
  if [ "$st" = FAIL ]; then echo "   --- xato (oxirgi qatorlar) ---"; tail -15 "${base}.out" | sed 's/^/   /'; fi
done 3<<< "$LIST"
echo "=== Tayyor ($(date '+%H:%M')) ==="
