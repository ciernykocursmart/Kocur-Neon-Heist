# Ako publikovať KOCUR DUNGEON v Microsoft Store

## Čo je pripravené

| Súbor | Na čo slúži |
| --- | --- |
| `KocurDungeon_1.0.0.0_x64.msix` | **Balík na nahratie do Store** (nepodpísaný; Store ho podpíše sám). Zostaví ho `tools/build_msix.sh`. |
| `STORE_LISTING.md` | Texty v angličtine aj slovenčine: názov, krátky a dlhý popis, vlastnosti, kľúčové slová, popisky screenshotov, vekové hodnotenie, systémové požiadavky |
| `screenshots/*.png` | 9 skutočných screenshotov z hry vo Full HD (1920×1080) |
| `art/*.png` | Box art 1:1 (2160×2160), poster 2:3 (1440×2160), hero art 16:9 (3840×2160) |
| `msix/` | Zdroj balíka: `AppxManifest.xml` a logá (dlaždice, ikonka na lište, splash screen) |

Identita v balíku (z Partner Center):
- Name: `59513Lukes.KocurDungeon`
- Publisher: `CN=5B8EDAC0-7E93-4119-961E-9118180BF0FD`
- PublisherDisplayName: `Kocur`
- DisplayName: `Kocur Dungeon`
- Verzia `1.0.0.0`, architektúra x64, Windows 10 1809 a novší

## ⚠️ Skontroluj ako prvé: názov aplikácie

`DisplayName` v balíku sa musí **presne** zhodovať s názvom rezervovaným v
Partner Center (rozhodujú aj veľké písmená a medzery). Balík používa
**`Kocur Dungeon`**. Ak je rezervovaný iný tvar, balík sa dá prebaliť:

```bash
DISPLAY_NAME="Presny Rezervovany Nazov" tools/build_msix.sh /cesta/k/makemsix
```

(Alebo mi napíš presný názov a prebalím ho ja.)

## Postup v Partner Center

1. **Apps and games → Kocur Dungeon → Start your submission.**
2. **Pricing and availability:** cena, trhy, dátum vydania.
3. **Properties:** kategória *Games → Platformer*. Privacy policy nie je
   potrebná: hra nezbiera žiadne údaje a nepoužíva internet. Systémové
   požiadavky sú v `STORE_LISTING.md`.
4. **Age ratings:** dotazník IARC. Odporúčané odpovede sú v `STORE_LISTING.md`
   (kreslené fantasy násilie, bez krvi, bez nákupov v hre, offline).
5. **Packages:** nahraj `KocurDungeon_1.0.0.0_x64.msix`. Zariadenia: Windows
   10/11 Desktop.
   - Ak sa Store spýta na **runFullTrust**, zdôvodnenie je pripravené
     v `STORE_LISTING.md`. Je to štandard pre desktopové hry (.exe).
6. **Store listings:**
   - **English (United States):** skopíruj anglické texty z `STORE_LISTING.md`.
   - **Slovenčina:** cez *Add/remove languages* pridaj slovenčinu a skopíruj
     slovenské texty. (Hra samotná je v angličtine; slovenský listing je len
     popis v obchode.)
   - V oboch listingoch nahraj:
     - Screenshots (Desktop): všetkých 9 súborov z `screenshots/` v poradí 01 až 09
     - 1:1 Box art: `art/boxart_2160x2160.png`
     - 2:3 Poster art: `art/poster_1440x2160.png`
     - 16:9 Super hero art: `art/hero_3840x2160.png`
7. **Submission options → Notes for certification:** text je v `STORE_LISTING.md`.
8. **Submit to the Store.** Certifikácia zvyčajne trvá 1 až 3 pracovné dni.

## Odporúčané: lokálny test balíka pred odoslaním

Balík som zostavil a skontroloval na Linuxe, ale **nebol nainštalovaný ani
spustený na Windows**. Nepodpísaný balík sa nedá nainštalovať dvojklikom; na
lokálny test treba podpísať jeho kópiu testovacím certifikátom so subjektom
`CN=5B8EDAC0-7E93-4119-961E-9118180BF0FD`. Na Windows (PowerShell ako admin):

```powershell
$cert = New-SelfSignedCertificate -Type Custom -Subject "CN=5B8EDAC0-7E93-4119-961E-9118180BF0FD" `
  -KeyUsage DigitalSignature -FriendlyName "Kocur test" -CertStoreLocation "Cert:\CurrentUser\My" `
  -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}")
Export-PfxCertificate -Cert $cert -FilePath kocur_test.pfx -Password (ConvertTo-SecureString -String "test" -Force -AsPlainText)
Import-PfxCertificate -FilePath kocur_test.pfx -CertStoreLocation Cert:\LocalMachine\TrustedPeople -Password (ConvertTo-SecureString -String "test" -Force -AsPlainText)
# SignTool je súčasťou Windows SDK. Podpisuj kópiu - do Store nahraj NEpodpísaný originál.
copy KocurDungeon_1.0.0.0_x64.msix test.msix
signtool sign /fd SHA256 /a /f kocur_test.pfx /p test test.msix
```

Potom dvojklik na `test.msix` → Install → spusti Kocur Dungeon zo Štart menu.
Voliteľne spusti **Windows App Certification Kit** (súčasť Windows SDK) na
nainštalovaný balík; je to tá istá kontrola, ktorú robí Store.

## Ďalšie verzie (aktualizácie)

1. Zvýš `config/version` v `project.godot` (napr. `1.0.1`).
2. `tools/build_windows.sh`
3. `tools/build_msix.sh /cesta/k/makemsix` vytvorí `build/msix/KocurDungeon_1.0.1.0_x64.msix`.
4. V Partner Center vytvor nový submission a nahraj nový balík.

Screenshoty, art a logá sa dajú znovu vyrobiť príkazom `tools/store_shots.sh`
(potrebuje Godot 4.3 a xvfb-run).
