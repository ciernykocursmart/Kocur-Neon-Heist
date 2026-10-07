# Ako publikovať KOCUR: NEON HEIST v Microsoft Store

## Čo je pripravené

| Súbor | Na čo slúži |
| --- | --- |
| `build/msix/KocurNeonHeist_1.0.0.0_x64.msix` | **Balík na nahratie do Store** (nepodpísaný; Store ho podpíše sám) |
| `store/STORE_LISTING.md` | Anglické texty: názov, krátky a dlhý popis, vlastnosti, kľúčové slová, popisky screenshotov, odporúčania k vekovému hodnoteniu |
| `store/screenshots/*.png` | 8 screenshotov vo Full HD (1920×1080) |
| `store/art/*.png` | Box art 1:1, poster 2:3 a hero art 16:9 |
| `store/msix/` | Zdroj balíka (AppxManifest.xml + logá); balík sa zostaví príkazom `tools/build_msix.sh` |

Identita v balíku (z Partner Center):
- Name: `59513Lukes.KocurNeonHeist`
- Publisher: `CN=5B8EDAC0-7E93-4119-961E-9118180BF0FD`
- PublisherDisplayName: `Kocur`
- DisplayName: `Kocur: Neon Heist`
- Verzia: `1.0.0.0`, architektúra x64, Windows 10 1809+

## ⚠️ Skontroluj ako prvé: názov aplikácie

`DisplayName` v balíku sa musí **presne** zhodovať s názvom, ktorý máš
rezervovaný v Partner Center (rozhodujú aj veľké písmená, dvojbodka a medzery).
Balík používa **`Kocur: Neon Heist`**. Ak si rezervoval napríklad
„KOCUR: NEON HEIST“ alebo „Kocur Neon Heist“, balík sa dá znovu zostaviť:

```bash
DISPLAY_NAME="Presny Rezervovany Nazov" tools/build_msix.sh /cesta/k/makemsix
```

(Alebo mi napíš presný názov a balík prebalím ja.)

## Postup v Partner Center

1. **Partner Center → Apps and games → Kocur Neon Heist → Start your submission.**
2. **Pricing and availability:** cena (napr. 4,99 €), trhy, dátum vydania.
3. **Properties:** kategória *Games → Action & adventure*. Privacy policy nie
   je potrebná, pretože hra nezbiera žiadne údaje a nepoužíva internet.
   Systémové požiadavky nájdeš v `STORE_LISTING.md`.
4. **Age ratings:** vyplň dotazník IARC. Odporúčané odpovede sú v
   `STORE_LISTING.md` (fantasy násilie voči robotom, bez krvi, bez nákupov
   v hre).
5. **Packages:** nahraj `KocurNeonHeist_1.0.0.0_x64.msix`. Zariadenia:
   Windows 10/11 Desktop.
   - Store sa môže spýtať na zdôvodnenie schopnosti **runFullTrust**.
     Text je pripravený v `STORE_LISTING.md`. Je to štandard pre desktopové
     hry, ktoré bežia ako .exe.
6. **Store listings → English (United States):** skopíruj texty z
   `STORE_LISTING.md` a nahraj screenshoty a obrázky:
   - Screenshots (Desktop): všetkých 8 súborov z `store/screenshots/`
   - 1:1 Box art: `store/art/boxart_2160x2160.png`
   - 2:3 Poster art: `store/art/poster_1440x2160.png`
   - 16:9 Super hero art: `store/art/hero_3840x2160.png`
7. **Submission options:** voliteľné poznámky pre certifikáciu, napr.
   *"Offline single-player game, no account or login required."*
8. **Submit to the Store.** Certifikácia zvyčajne trvá 1 až 3 pracovné dni.

## Voliteľné: lokálny test balíka pred odoslaním

Nepodpísaný balík sa nedá nainštalovať dvojklikom; podpis pridá až Store.
Na lokálny test ho treba podpísať vlastným testovacím certifikátom, ktorého
subjekt je `CN=5B8EDAC0-7E93-4119-961E-9118180BF0FD`. Na Windows
(PowerShell ako admin):

```powershell
$cert = New-SelfSignedCertificate -Type Custom -Subject "CN=5B8EDAC0-7E93-4119-961E-9118180BF0FD" `
  -KeyUsage DigitalSignature -FriendlyName "Kocur test" -CertStoreLocation "Cert:\CurrentUser\My" `
  -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}")
Export-PfxCertificate -Cert $cert -FilePath kocur_test.pfx -Password (ConvertTo-SecureString -String "test" -Force -AsPlainText)
Import-PfxCertificate -FilePath kocur_test.pfx -CertStoreLocation Cert:\LocalMachine\TrustedPeople -Password (ConvertTo-SecureString -String "test" -Force -AsPlainText)
# SignTool je súčasťou Windows SDK. Podpisuj kópiu - do Store nahraj NEpodpísaný originál.
copy KocurNeonHeist_1.0.0.0_x64.msix test.msix
signtool sign /fd SHA256 /a /f kocur_test.pfx /p test test.msix
```

Potom stačí na `test.msix` dvojklik → Install. Do Store nahrávaj
**pôvodný nepodpísaný** `.msix`.

## Ďalšie verzie (aktualizácie)

1. Zvýš `config/version` v `project.godot` (napr. `1.0.1`).
2. `tools/build_windows.sh /cesta/k/godot`
3. `tools/build_msix.sh /cesta/k/makemsix` vytvorí `KocurNeonHeist_1.0.1.0_x64.msix`.
4. V Partner Center vytvor nový submission a nahraj nový balík.
