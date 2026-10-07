# MacCheck

„MacCheck“ – pradinė macOS SwiftUI diagnostikos programa, skirta MacBook remontą atliekančiam darbuotojui.

## Kas veikia

- Perskaito macOS sistemos ataskaitas apie kompiuterį, bateriją, ekraną, atmintį, saugyklą, kamerą, garsą, Wi‑Fi, Bluetooth, USB ir tinklo sąsajas.
- Pateikia testus su būsenomis „Neatlikta“, „Veikia“, „Gedimas“ ir „Netaikoma“.
- Leidžia programoje tikrinti klaviatūros klavišus ir ekraną vientisomis spalvomis.
- Leidžia atskirus kairiojo, dešiniojo ir abiejų garso kanalų tonus.
- Leidžia įrašyti mikrofoną ir įrašą iškart paleisti.
- Paleidžia gyvą kameros vaizdą programoje.
- Turi 20 sekundžių ventiliatoriaus reakcijos apkrovos testą. Jis leidžia macOS pačiai padidinti apsukas; programa negali nustatyti tikslaus maksimalaus RPM. MacBook Air ventiliatoriaus neturi.
- Rodo baterijos įtampą, srovę ir apskaičiuotą galią, kai macOS pateikia šiuos IOKit duomenis.
- Stebi miego ir pabudimo įvykius, pateikia dangčio uždarymo bei automatinio ekrano šviesumo jutiklio bandymo instrukcijas.
- Išsaugo atliktų testų ir nuskaitytos informacijos ataskaitą PDF formatu.
- Atidaro macOS spausdinimo langą ir leidžia ataskaitą spausdinti arba išsaugoti kaip PDF.
- Išsaugo tuos pačius diagnostikos duomenis JSON formatu.

## Sukompiliuotos programos paleidimas

Sukompiliuota `MacCheck.app` paleidžiama dukart spustelėjus – Terminalo ar Swift komandų galutiniam naudotojui nereikia.

## Sukūrimas

Vietiniam kūrimui reikia macOS 13 ar naujesnės versijos ir Xcode. Atidaryk `MacCheck.xcodeproj`, pasirink `MacCheck` schemą ir paleisk Build. Programėlė bus sukurta `Products/Release/MacCheck.app`.

GitHub Actions workflow sukuria universalią `MacCheck-macOS-Universal.zip` programą su Intel (`x86_64`) ir Apple silicon (`arm64`) versijomis viename `.app` pakete. Ji reikalauja macOS 13 arba naujesnės versijos. Parsisiųsk artefaktą iš naujausio Actions run puslapio, išskleisk archyvą ir perkelk `MacCheck.app` į Applications arba paleisk tiesiai.

Šiuo metu programėlė nėra pasirašyta ar notarizuota platinimui. Jei macOS blokuoja atidarymą, vietiniam testavimui Finder lange spustelėk programą dešiniu pelės klavišu ir pasirink „Open“.

## Ribos

Automatinis nuskaitymas parodo macOS aptiktus duomenis; aptikimas nereiškia, kad komponentas pilnai veikia. Įkrovimo lange rodoma baterijos pusės telemetrija, o ne USB‑C adapterio išėjimo matavimas; dalį reikšmių macOS gali slėpti. macOS neturi patikimos viešos API tiksliam dangčio kampui ar aplinkos šviesos lux rodmeniui, todėl šie bandymai yra informaciniai ir atliekami stebint fizinę reakciją. Trackpad, jungtys ir dalis jutiklių tikrinami fiziškai. Ventiliatoriaus apkrovos testas trumpas, nutraukiamas, bet neparodo RPM ir nepriverčia ventiliatoriaus suktis maksimaliu greičiu. Testai neišsaugo klaviatūra įvesto turinio. Touch ID, Fn, Touch Bar ir kitų jutiklių gedimų patikrai naudok atskiras Apple diagnostikos ar remonto procedūras.

## Kiti logiški žingsniai

- Sukurti Xcode app bundle su vietiniais leidimų aprašais ir pasirašymu.
- Išplėsti ataskaitą CSV formatu, pridėti remonto numerio ir darbuotojo laukus.
