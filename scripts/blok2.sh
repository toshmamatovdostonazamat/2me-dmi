#!/bin/bash
# Blok 2 (R1-5, R2-1): mavjud s2 geometriyalarida yagona nuqta (single point) sezgirlik testlari
#
#  A qism (tez, barcha tuzilmalar + 2ME, DMI):
#     s5_cpcm2me : r2SCAN-3c, CPCM(2-ME), SMD'siz          -> kontinuum modeli (SMD vs CPCM)
#     s5_cpcmdmi : r2SCAN-3c, CPCM, eps = 37.6, n = 1.472  -> kontinuum tarkibi (2-ME vs DMI dielektrigi)
#  B qism (og'ir, 15 ta vakil tuzilma):
#     s6_wb97mv  : wB97M-V/def2-TZVP, SMD(2-ME)            -> boshqa elektron tuzilish metodi
#
# Ishlatish:  bash blok2.sh A   |   bash blok2.sh B   |   bash blok2.sh   (A, keyin B)
# Qayta ishga tushirilsa, tugagan hisoblar o'tkazib yuboriladi.

ROOT=/media/doston/72f1eff3-bf18-4476-8539-c8566520c822/FACsPbI3_VASP/FACsPbI3/ORCA/2ME-DMI
ORCA=/home/doston/orca_6_1_1/orca
NP=6
MAXCORE=2000
PARTS=${1:-AB}

REP="2ME DMI PbI2_b0 PbBr2_b0 PbBr2_b1 PbI2_b2_cis PbBr2_b2_cis PbI2_b4 PbBr2_b4
MABr_b0_c0a0 FAI_b0_c0a0 MABr_b2_c2a0 FAI_b2_c2a0 MABr_b4_c2a2 FAI_b4_c2a2"

done_ok () { grep -q "ORCA TERMINATED NORMALLY" "$1" 2>/dev/null && grep -q "FINAL SINGLE POINT ENERGY" "$1"; }

run_sp () {   # $1=papka $2=label $3=suffix $4=kalit so'zlar $5=qo'shimcha blok
  local d=$1 lab=$2 suf=$3 kw=$4 blk=$5
  local base="${lab}_${suf}" xyz="${lab}_s2_r2scan.xyz"
  cd "$d" || { echo "!! papka yo'q: $d"; return; }
  if done_ok "${base}.out"; then echo "   $lab $suf: tayyor, o'tkazildi"; return; fi
  [ -e "$xyz" ] || { echo "!! $d/$xyz topilmadi"; return; }
  printf '! %s\n%%pal nprocs %s end\n%%maxcore %s\n%b* xyzfile 0 1 %s\n' \
         "$kw" "$NP" "$MAXCORE" "$blk" "$xyz" > "${base}.inp"
  local t0=$(date +%s)
  "$ORCA" "${base}.inp" > "${base}.out" 2>&1 < /dev/null
  local dt=$(( ($(date +%s) - t0) / 60 ))
  local st=FAIL; done_ok "${base}.out" && st=OK
  local E=$(grep 'FINAL SINGLE POINT ENERGY' "${base}.out" | tail -1 | awk '{print $5}')
  echo "   $st  $lab $suf  ${dt} min  E = ${E:--}"
  [ "$st" = FAIL ] && tail -8 "${base}.out" | sed 's/^/      /'
}

dir_of () {   # label -> papka
  case $1 in
    2ME|DMI) echo "$ROOT/$1" ;;
    *) local pre=${1%%_*}; echo "$ROOT/$pre/calc/$1" ;;
  esac
}

ALL_LABELS () {
  echo 2ME; echo DMI
  for pre in PbI2 PbBr2 FAI MABr; do
    for d in "$ROOT/$pre"/calc/${pre}_b*; do basename "$d"; done
  done
}

SMD_BLK='%cpcm\n  smd true\n  SMDsolvent "2-methoxyethanol"\nend\n'
DMI_BLK='%cpcm\n  epsilon 37.6\n  refrac 1.472\nend\n'

if [[ $PARTS == *A* ]]; then
  echo "=== A qism: r2SCAN-3c kontinuum sezgirligi ($(date '+%H:%M')) ==="
  while read -r lab <&3; do
    d=$(dir_of "$lab")
    run_sp "$d" "$lab" s5_cpcm2me "r2SCAN-3c TightSCF CPCM(2-methoxyethanol)" ""
    run_sp "$d" "$lab" s5_cpcmdmi "r2SCAN-3c TightSCF CPCM" "$DMI_BLK"
  done 3< <(ALL_LABELS)
fi

if [[ $PARTS == *B* ]]; then
  echo "=== B qism: wB97M-V/def2-TZVP/SMD(2-ME) ($(date '+%H:%M')) ==="
  for lab in $REP; do
    d=$(dir_of "$lab")
    run_sp "$d" "$lab" s6_wb97mv "wB97M-V def2-TZVP def2/J RIJCOSX TightSCF CPCM(2-methoxyethanol)" "$SMD_BLK"
  done
fi
echo "=== Tayyor ($(date '+%H:%M')) ==="
