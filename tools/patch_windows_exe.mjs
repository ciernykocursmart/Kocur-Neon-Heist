// Stamps the KOCUR icon and version metadata into a Windows executable.
//
// Used on the Godot *export template* before exporting, so Godot then embeds
// the game PCK into an already-branded executable (patching after export
// would disturb the embedded PCK section). Pure JavaScript: works on Linux
// CI without rcedit/wine.
//
//   node tools/patch_windows_exe.mjs <in.exe> <out.exe> <icon.ico> <version>
import fs from 'fs';
import * as ResEdit from 'resedit';
import * as PE from 'pe-library';

const [input, output, iconPath, version = '1.0.0'] = process.argv.slice(2);
if (!input || !output || !iconPath) {
  console.error('usage: patch_windows_exe.mjs <in.exe> <out.exe> <icon.ico> [version]');
  process.exit(2);
}
const parts = version.split('.').map((n) => parseInt(n, 10) || 0);
while (parts.length < 4) parts.push(0);

const exe = PE.NtExecutable.from(fs.readFileSync(input), { ignoreCert: true });
const res = PE.NtExecutableResource.from(exe);

// Icon: replace Godot's icon group (and its images) with ours.
const iconFile = ResEdit.Data.IconFile.from(fs.readFileSync(iconPath));
const groups = ResEdit.Resource.IconGroupEntry.fromEntries(res.entries);
const groupId = groups.length > 0 ? groups[0].id : 1;
const lang = groups.length > 0 ? groups[0].lang : 1033;
ResEdit.Resource.IconGroupEntry.replaceIconsForResource(
  res.entries, groupId, lang, iconFile.icons.map((i) => i.data));

// Version info.
const infos = ResEdit.Resource.VersionInfo.fromEntries(res.entries);
const vi = infos.length > 0 ? infos[0] : ResEdit.Resource.VersionInfo.createEmpty();
const langs = vi.getAvailableLanguages();
const lc = langs.length > 0 ? langs[0] : { lang: 1033, codepage: 1200 };
vi.setFileVersion(parts[0], parts[1], parts[2], parts[3], lc.lang);
vi.setProductVersion(parts[0], parts[1], parts[2], parts[3], lc.lang);
for (const key of ['Licence', 'Info']) vi.removeStringValue(lc, key);
vi.setStringValues(lc, {
  CompanyName: 'Kocur Neon Heist',
  FileDescription: 'KOCUR: NEON HEIST',
  ProductName: 'KOCUR: NEON HEIST',
  InternalName: 'KocurNeonHeist',
  OriginalFilename: 'KocurNeonHeist.exe',
  LegalCopyright: 'Original work. Built with Godot Engine (MIT).',
  FileVersion: parts.join('.'),
  ProductVersion: parts.join('.'),
});
vi.outputToResourceEntries(res.entries);

res.outputResource(exe);
fs.writeFileSync(output, Buffer.from(exe.generate()));
console.log(`patched ${output} (icon group ${groupId}, version ${parts.join('.')})`);
