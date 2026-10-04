# MacCheck

„MacCheck“ – pradinė macOS SwiftUI diagnostikos programa, skirta MacBook remontą atliekančiam darbuotojui.

## Kas veikia

- Perskaito macOS sistemos ataskaitas apie kompiuterį, bateriją, ekraną, atmintį, saugyklą, kamerą, garsą, Wi‑Fi, Bluetooth, USB ir tinklo sąsajas.
- Pateikia vedamus fizinius testus su būsenomis „Neatlikta“, „Veikia“, „Gedimas“ ir „Netaikoma“.
- Turi spalvų perjungimo ekrano testą ir klaviatūros paspaudimų vizualų testą.
- Išsaugo atliktų testų ir nuskaitytos informacijos ataskaitą PDF formatu.
- Atidaro macOS spausdinimo langą ir leidžia ataskaitą spausdinti arba išsaugoti kaip PDF.
- Išsaugo tuos pačius diagnostikos duomenis JSON formatu.

## Sukompiliuotos programos paleidimas

Sukompiliuota `MacCheck.app` paleidžiama dukart spustelėjus – Terminalo ar Swift komandų galutiniam naudotojui nereikia.

## Sukūrimas

Vietiniam kūrimui reikia macOS 13 ar naujesnės versijos ir Xcode. Atidaryk `MacCheck.xcodeproj`, pasirink `MacCheck` schemą ir paleisk Build. Programėlė bus sukurta `Products/Release/MacCheck.app`.

Jei projektas yra GitHub repozitorijoje, `Build MacCheck for macOS` workflow sukurs `MacCheck.app.zip` artefaktą macOS vykdymo aplinkoje. Parsisiųsk artefaktą iš Actions run puslapio, išskleisk archyvą ir perkelk `MacCheck.app` į Applications arba paleisk tiesiai.

Šiuo metu programėlė nėra pasirašyta ar notarizuota platinimui. Jei macOS blokuoja atidarymą, vietiniam testavimui Finder lange spustelėk programą dešiniu pelės klavišu ir pasirink „Open“.

## Ribos

Automatinis nuskaitymas parodo macOS aptiktus duomenis; aptikimas nereiškia, kad komponentas pilnai veikia. Kamera, mikrofonas, garsiakalbiai, trackpad, jungtys, baterijos įkrovimas ir dangčio/miego elgsena šiame pradiniame variante tikrinami darbuotojo. Testai nekeičia firmware, neatlieka apkrovos ir neišsaugo klaviatūra įvesto turinio. Touch ID, Fn, Touch Bar ir sensorinių gedimų patikrai naudok atskiras Apple diagnostikos ar remonto procedūras.

## Kiti logiški žingsniai

- Sukurti Xcode app bundle su vietiniais leidimų aprašais ir pasirašymu.
- Pridėti pasirenkamus kameros bei mikrofono tiesioginius testus, kuriems reikės leidimų.
- Išplėsti ataskaitą CSV formatu, pridėti remonto numerio ir darbuotojo laukus.
