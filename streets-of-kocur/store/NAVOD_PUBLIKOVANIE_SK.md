# Ako publikovať STREETS OF KOCUR v Microsoft Store

## Čo je pripravené

| Súbor | Na čo slúži |
| --- | --- |
| `StreetsOfKocur_1.0.0.0_x64.msix` | **Balík na nahratie do Store.** Je nepodpísaný, Store ho podpíše sám. Zostaví ho `tools/build_msix.sh`. |
| `STORE_LISTING.md` | Texty v angličtine aj slovenčine: názov, krátky a dlhý popis, vlastnosti, kľúčové slová, popisky screenshotov, vekové hodnotenie a systémové požiadavky. |
| `screenshots/*.png` | 10 skutočných screenshotov z hry vo Full HD (1920×1080): menu, 4 ulice a všetci 4 bossovia, výsledky ulice. |
| `art/*.png` | Box art 1:1 (2160×2160), poster 2:3 (1440×2160) a hero art 16:9 (3840×2160). |
| `msix/` | Zdroj balíka: `AppxManifest.xml` a logá (dlaždice, ikonka na lište, splash screen). |
| `StreetsOfKocur-store-assets.zip` | Všetko vyššie okrem .msix v jednom ZIP-e. |

Identita v balíku (z Partner Center):
- Name: `59513Lukes.StreetsOfKocur`
- Publisher: `CN=5B8EDAC0-7E93-4119-961E-9118180BF0FD`
- PublisherDisplayName: `Kocur`
- DisplayName: `Streets Of Kocur` (presne ako rezervovaný názov, s veľkým **O**)
- Verzia `1.0.0.0`, architektúra x64, Windows 10 1809 a novší

## ⚠️ Skontroluj ako prvé: názov aplikácie

`DisplayName` v balíku sa musí **presne** zhodovať s názvom rezervovaným v
Partner Center. Rozhodujú aj veľké písmená a medzery. Napísal si, že máš
rezervované **`Streets Of Kocur`** (veľké O), tak presne toto je v balíku.
V samotnej hre a na dlaždici v Štart menu (ShortName) zostáva nápis
„Streets of Kocur“, to Store nekontroluje. Ak je v Partner Center rezervovaný
iný tvar (napríklad s malým „of“), balík sa dá prebaliť:

```bash
DISPLAY_NAME="Presny Rezervovany Nazov" tools/build_msix.sh /cesta/k/makemsix
```

Alebo mi napíš presný názov a prebalím ho ja.

## Postup v Partner Center

1. **Apps and games → Streets Of Kocur → Start your submission.**
2. **Pricing and availability:** nastav cenu, trhy a dátum vydania.
3. **Properties:**
   - Kategória je *Games → Action & adventure*, druhá *Fighting*.
   - Privacy policy nie je potrebná, lebo hra nezbiera žiadne údaje a nepoužíva internet.
   - Systémové požiadavky sú v `STORE_LISTING.md`.
4. **Age ratings:** vyplň dotazník IARC. Odporúčané odpovede sú v
   `STORE_LISTING.md` (kreslené násilie medzi mačkami, bez krvi, bez nákupov
   v hre, offline).
5. **Packages:** nahraj `StreetsOfKocur_1.0.0.0_x64.msix`. Zariadenia sú Windows
   10/11 Desktop.
   - Ak sa Store spýta na **runFullTrust**, zdôvodnenie je pripravené
     v `STORE_LISTING.md`. Je to štandard pre desktopové hry (.exe).
6. **Store listings:**
   - **English (United States):** skopíruj anglické texty z `STORE_LISTING.md`.
   - **Slovenčina:** cez *Add/remove languages* pridaj slovenčinu a skopíruj
     slovenské texty. Hra samotná je v angličtine, slovenský listing je len
     popis v obchode.
   - V oboch listingoch nahraj:
     - Screenshots (Desktop): všetkých 10 súborov z `screenshots/` v poradí 01 až 10.
     - 1:1 Box art: `art/boxart_2160x2160.png`
     - 2:3 Poster art: `art/poster_1440x2160.png`
     - 16:9 Super hero art: `art/hero_3840x2160.png`
7. **Submission options → Notes for certification:** text je v `STORE_LISTING.md`.
8. **Submit to the Store.** Certifikácia zvyčajne trvá 1 až 3 pracovné dni.

## Odporúčané: lokálny test balíka pred odoslaním

Balík som zostavil a skontroloval na Linuxe, ale **nebol nainštalovaný ani
spustený na Windows**. Nepodpísaný balík sa nedá nainštalovať dvojklikom. Na
lokálny test treba podpísať jeho kópiu testovacím certifikátom so subjektom
`CN=5B8EDAC0-7E93-4119-961E-9118180BF0FD`. Na Windows spusti PowerShell ako
správca:

```powershell
$cert = New-SelfSignedCertificate -Type Custom -Subject "CN=5B8EDAC0-7E93-4119-961E-9118180BF0FD" `
  -KeyUsage DigitalSignature -FriendlyName "Kocur test" -CertStoreLocation "Cert:\CurrentUser\My" `
  -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}")
Export-PfxCertificate -Cert $cert -FilePath kocur_test.pfx -Password (ConvertTo-SecureString -String "test" -Force -AsPlainText)
Import-PfxCertificate -FilePath kocur_test.pfx -CertStoreLocation Cert:\LocalMachine\TrustedPeople -Password (ConvertTo-SecureString -String "test" -Force -AsPlainText)
# SignTool je súčasťou Windows SDK. Podpisuj kópiu - do Store nahraj NEpodpísaný originál.
copy StreetsOfKocur_1.0.0.0_x64.msix test.msix
signtool sign /fd SHA256 /a /f kocur_test.pfx /p test test.msix
```

Ak si certifikát robil už pre Kocur Dungeon alebo Kocur Tactics, môžeš použiť
ten istý `kocur_test.pfx`, lebo Publisher je rovnaký.

Potom dvojklikni na `test.msix`, zvoľ Install a spusti Streets Of Kocur zo Štart
menu. Voliteľne spusti **Windows App Certification Kit** (súčasť Windows SDK)
na nainštalovaný balík. Je to tá istá kontrola, ktorú robí Store.

## Ďalšie verzie (aktualizácie)

1. Zvýš `config/version` v `project.godot`, napríklad na `1.0.1`.
2. Spusti `tools/build_windows.sh`.
3. `tools/build_msix.sh /cesta/k/makemsix` vytvorí `build/msix/StreetsOfKocur_1.0.1.0_x64.msix`.
4. V Partner Center vytvor nový submission a nahraj nový balík.

Screenshoty, art a logá sa dajú znovu vyrobiť príkazom `tools/store_shots.sh`.
Potrebuje Godot 4.3 a xvfb-run.

## Ikona .exe

`StreetsOfKocur.exe` má už vlastnú ikonu (čierny Kocur) namiesto predvolenej
ikony Godotu a vyplnené údaje o verzii (Streets of Kocur, Kocur Studios, 1.0.0).
Rovnaké .exe je v ZIP-e aj v .msix balíku.
