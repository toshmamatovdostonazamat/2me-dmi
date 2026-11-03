# PbI₂, PbBr₂, FAI va MABr prekursorlarining 2-ME/DMI aralashmasida erishi — hisoblash ma'lumotlari

Ushbu repozitoriy maqolaning nazariy (cluster–continuum DFT) qismidagi barcha natijalarni qayta hosil qilish uchun
kerakli ma'lumotlar va kodni o'z ichiga oladi.

## Usul (qisqacha)
- Dastur: ORCA 6.1.1
- Geometriya: GFN2-xTB -> r²SCAN-3c / SMD(2-methoxyethanol)
- Termal tuzatma: GFN2-xTB (asosiy sxema); 15 ta vakil struktura uchun to'liq r²SCAN-3c/SMD (TightOpt, analitik chastotalar), qRRHO (ω₀ = 100 cm⁻¹)
- Sezgirlik testlari: CPCM(2-ME), CPCM (ε = 37,6; n = 1,472), ωB97M-V/def2-TZVP/SMD(2-ME)
- Termodinamik model: ligand almashinish muvozanatlari, massa balansi bilan to'yinish eruvchanligi

## Tuzilma
| Papka / fayl | Tarkibi |
| --- | --- |
| `results.ipynb` | barcha rasm, jadval va matndagi sonlarni (`tables/summary_numbers.txt`) hosil qiluvchi notebook |
| `data/orca_data.tar.xz` | notebook o'qiydigan ORCA chiqish fayllari (asl papka tuzilmasida) |
| `structures/s2_r2scan/` | asosiy r²SCAN-3c/SMD geometriyalari (.xyz) |
| `structures/s4_r2freq/` | TightOpt + chastota geometriyalari, vakil strukturalar (.xyz) |
| `inputs/` | ORCA kirish fayllari, hisob bosqichi bo'yicha: s1 = xTB opt, s2 = r²SCAN-3c opt, s3 = xTB freq, s4 = r²SCAN-3c TightOpt Freq, s5 = CPCM yagona nuqta, s6 = ωB97M-V yagona nuqta |
| `tables/`, `figures/` | notebook natijalari (CSV; PDF va 600 dpi PNG) |
| `scripts/` | hisoblarni ishga tushirish va yordamchi skriptlar |

Fayl nomlari: `<prekursor>_b<DMI soni>[_<izomer>]`; ion juftlari uchun `c` va `a` — kation va anion o'rinlaridagi DMI soni.

## Qayta hosil qilish
```bash
pip install -r requirements.txt
tar -xJf data/orca_data.tar.xz        # 2ME/, DMI/, PbI2/, ... papkalari shu yerda paydo bo'ladi
jupyter notebook results.ipynb        # Run All
```

## Iqtibos
Maqola chiqqandan keyin bibliografik ma'lumot qo'shiladi.
