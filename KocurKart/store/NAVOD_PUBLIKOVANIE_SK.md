# Ako publikovať KOCUR KART v Microsoft Store 🏁

## 📦 Čo je pripravené

| Súbor | Na čo slúži |
|---|---|
| `release/KocurKart_1.0.0.0_x64.msix` | **Balík na nahratie do Store.** Je nepodpísaný, Store ho podpíše sám. |
| `store/STORE_LISTING.md` | Anglické texty do Store: názov, krátky a dlhý popis, vlastnosti, kľúčové slová, popisky screenshotov, systémové požiadavky, vekové hodnotenie, zdôvodnenie `runFullTrust` |
| `store/screenshots/*.png` | 4 screenshoty z hry vo Full HD (1920×1080). Ďalšie môžeš pridať vlastné. |
| `store/art/*.png` | Box art 1:1, poster 2:3, hero art 16:9 a logo 1:1 |
| `store/msix/` | Zdroj balíka (AppxManifest.xml + logá). Balík sa zostaví príkazom `tools/build_msix.sh`. |

Identita v balíku (z tvojho Partner Center):
- Name: `59513Lukes.KocurKart`
- Publisher: `CN=5B8EDAC0-7E93-4119-961E-9118180BF0FD`
- PublisherDisplayName: `Kocur`
- DisplayName: `Kocur Kart`
- Verzia `1.0.0.0`, architektúra x64, Windows 10 1809 a novšie

## ⚠️ Skontroluj ako prvé: názov aplikácie
`DisplayName` v balíku sa musí **presne** zhodovať s názvom rezervovaným v Partner Center,
vrátane veľkých písmen a medzier. Balík používa **`Kocur Kart`**. Ak máš rezervované niečo iné,
napíš mi presný názov a balík prebalím. Alebo ho prebal sám:
```bash
cd KocurKart
DISPLAY_NAME="Presny Nazov" tools/build_msix.sh
```

## 🚀 Postup v Partner Center
1. **Partner Center → Apps and games → Kocur Kart → Start your submission**
2. **Pricing and availability:** cena (alebo zadarmo), trhy, dátum vydania
3. **Properties:**
   - kategória **Games → Racing & flying**
   - Privacy policy netreba: hra nezbiera žiadne údaje a nepoužíva internet
   - systémové požiadavky vyplň podľa tabuľky v `STORE_LISTING.md`
4. **Age ratings:** vyplň dotazník IARC. Odporúčané odpovede sú v `STORE_LISTING.md`
   (bez násilia, bez nákupov, bez online funkcií). Výsledok by mal byť PEGI 3 / Everyone.
5. **Packages:** nahraj `KocurKart_1.0.0.0_x64.msix`. Zariadenia: Windows 10/11 Desktop.
   - Store sa môže spýtať na zdôvodnenie schopnosti **runFullTrust**. Text je pripravený
     v `STORE_LISTING.md`. Pre desktopové hry, ktoré bežia ako .exe, je to štandard.
6. **Store listings → English (United States):** skopíruj texty z `STORE_LISTING.md` a nahraj:
   - **Screenshots (Desktop):** 4 súbory z `store/screenshots/` (01 až 04) plus vlastné, ak chceš
     a k nim popisky z tabuľky
   - **1:1 Box art:** `store/art/boxart_2160x2160.png`
   - **2:3 Poster art:** `store/art/poster_1440x2160.png`
   - **16:9 Super hero art:** `store/art/hero_3840x2160.png`
   - **Store logo:** `store/art/logo_1080x1080.png`
7. **Submission options:** poznámka pre certifikáciu je tiež v `STORE_LISTING.md`
8. **Submit to the Store.** Certifikácia zvyčajne trvá 1 až 3 pracovné dni. ⏳

## 🧪 Voliteľné: lokálny test balíka pred odoslaním
Nepodpísaný balík sa nedá nainštalovať dvojklikom, podpis pridá až Store. Na lokálny test ho
podpíš testovacím certifikátom so subjektom `CN=5B8EDAC0-7E93-4119-961E-9118180BF0FD`
(PowerShell ako správca, SignTool je súčasťou Windows SDK):

```powershell
$cert = New-SelfSignedCertificate -Type Custom -Subject "CN=5B8EDAC0-7E93-4119-961E-9118180BF0FD" `
  -KeyUsage DigitalSignature -FriendlyName "Kocur test" -CertStoreLocation "Cert:\CurrentUser\My" `
  -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}")
Export-PfxCertificate -Cert $cert -FilePath kocur_test.pfx -Password (ConvertTo-SecureString -String "test" -Force -AsPlainText)
Import-PfxCertificate -FilePath kocur_test.pfx -CertStoreLocation Cert:\LocalMachine\TrustedPeople -Password (ConvertTo-SecureString -String "test" -Force -AsPlainText)
copy KocurKart_1.0.0.0_x64.msix test.msix
signtool sign /fd SHA256 /a /f kocur_test.pfx /p test test.msix
```
Potom stačí dvojklik na `test.msix` → **Install**. Do Store nahraj **pôvodný nepodpísaný** `.msix`.

💡 Odporúčam to spraviť aspoň raz. Balík som overil automatickými kontrolami, ale na skutočnom
Windows ešte nainštalovaný nebol.

## 🔄 Ďalšie verzie (aktualizácie)
1. Zvýš `config/version` v `KocurKart/project.godot` (napr. `1.0.1`). Balík dostane verziu `1.0.1.0`.
2. `tools/build_windows.sh godot` a potom `tools/build_msix.sh`
3. V Partner Center vytvor nový submission a nahraj nový `.msix`.
   Store vyžaduje, aby každá nová verzia mala vyššie číslo.
