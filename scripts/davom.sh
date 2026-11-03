#!/bin/bash
# Tok uzilgandan keyin: 8 ta siljitilgan tuzilma (s4) holatini ko'rsatadi va uzilganlarini davom ettirishga tayyorlaydi.
#   bash davom.sh          -> faqat holat (hech narsa o'zgarmaydi)
#   bash davom.sh --apply  -> uzilgan hisobni oxirgi geometriyadan davom ettirishga tayyorlaydi
# Keyin: nohup bash blok1.sh > blok1.log 2>&1 &   (tugaganlar o'tkazib yuboriladi)

ROOT=/media/doston/72f1eff3-bf18-4476-8539-c8566520c822/FACsPbI3_VASP/FACsPbI3/ORCA/2ME-DMI
APPLY=0; [ "$1" = "--apply" ] && APPLY=1
cd "$ROOT" || exit 1

if pgrep -f "orca" >/dev/null; then
  echo "!! ORCA hali ishlayapti — avval to'xtating yoki tugashini kuting:"; pgrep -af orca | head -3; exit 1
fi

valid_xyz () {  # to'liq yozilgan xyz faylmi (atomlar soni + 2 qator)
  [ -s "$1" ] || return 1
  local n; n=$(head -1 "$1" | tr -d ' \r')
  [[ "$n" =~ ^[0-9]+$ ]] || return 1
  [ "$(awk 'NR > 2 && NF >= 4' "$1" | wc -l)" -eq "$n" ]
}

printf "%-16s %-34s %s\n" "tuzilma" "holat" "izoh"
for disp in */calc/*/*_s4_disp.xyz; do
  d=$(dirname "$disp"); lab=$(basename "$disp" _s4_disp.xyz)
  base="$d/${lab}_s4_r2freq"; out="$base.out"
  if grep -q "ORCA TERMINATED NORMALLY" "$out" 2>/dev/null && grep -q "G-E(el)" "$out"; then
    im=$(grep 'imaginary mode' "$out" | awk '{print $2}' | tr '\n' ' ')
    printf "%-16s %-34s %s\n" "$lab" "TAYYOR" "mavhum: ${im:-yoq}"
    continue
  fi
  if [ ! -e "$out" ]; then
    printf "%-16s %-34s %s\n" "$lab" "boshlanmagan" "_s4_disp.xyz dan boshlanadi"
    continue
  fi
  cyc=$(grep -c "GEOMETRY OPTIMIZATION CYCLE" "$out")
  if grep -q "OPTIMIZATION RUN DONE" "$out"; then stage="opt tugagan, Freq da uzilgan"
  else stage="opt $cyc-tsiklda uzilgan"; fi
  if valid_xyz "$base.xyz"; then src="oxirgi geometriya ($cyc tsikl) dan davom etadi"
  else src="geometriya fayli yo'q/buzilgan — _s4_disp.xyz dan qayta boshlanadi"; fi
  printf "%-16s %-34s %s\n" "$lab" "UZILGAN: $stage" "$src"
  if [ $APPLY = 1 ]; then
    bk="$d/_s4_uzilgan_$(date +%m%d_%H%M)"; mkdir -p "$bk"
    cp "$disp" "$bk/"
    valid_xyz "$base.xyz" && cp "$base.xyz" "$disp"     # blok1.sh shu geometriyadan boshlaydi
    for f in "$base".* "$d/${lab}_s4_r2freq"_*; do [ -e "$f" ] && mv "$f" "$bk/"; done
    echo "                 -> tayyorlandi (eski fayllar: ${bk#$ROOT/})"
  fi
done
if [ $APPLY = 0 ]; then echo -e "\nDavom ettirish uchun: bash davom.sh --apply && nohup bash blok1.sh > blok1.log 2>&1 &"; fi
