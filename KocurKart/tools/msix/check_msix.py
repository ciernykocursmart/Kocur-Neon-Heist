#!/usr/bin/env python3
"""Independent validation of an MSIX: zip integrity, block map hashes and
sizes against the actual compressed data, manifest identity and assets."""
import base64, hashlib, re, struct, sys, zipfile, zlib
import xml.dom.minidom

path = sys.argv[1]
raw = open(path, "rb").read()
z = zipfile.ZipFile(path)
assert z.testzip() is None, "zip CRC failure"
names = z.namelist()
assert names[-2:] == ["AppxBlockMap.xml", "[Content_Types].xml"], names[-3:]
bm = xml.dom.minidom.parseString(z.read("AppxBlockMap.xml"))
files = bm.getElementsByTagName("File")
listed = set()
blocks = 0
for f in files:
    name = f.getAttribute("Name").replace("\\", "/")
    listed.add(name)
    info = z.getinfo(name)
    data = z.read(name)
    assert int(f.getAttribute("Size")) == len(data), name
    off = info.header_offset
    sig, = struct.unpack("<I", raw[off:off + 4])
    nlen, elen = struct.unpack("<HH", raw[off + 26:off + 30])
    assert int(f.getAttribute("LfhSize")) == 30 + nlen + elen, name
    pos = off + 30 + nlen + elen
    for k, b in enumerate(f.getElementsByTagName("Block")):
        chunk = data[k * 65536:(k + 1) * 65536]
        assert base64.b64encode(hashlib.sha256(chunk).digest()).decode() == b.getAttribute("Hash"), (name, k)
        if b.hasAttribute("Size"):
            size = int(b.getAttribute("Size"))
            assert zlib.decompressobj(-15).decompress(raw[pos:pos + size]) == chunk, (name, k)
            pos += size
        blocks += 1
payload = set(n for n in names if n not in ("AppxBlockMap.xml", "[Content_Types].xml"))
assert listed == payload, payload ^ listed
man = xml.dom.minidom.parseString(z.read("AppxManifest.xml"))
ident = man.getElementsByTagName("Identity")[0]
print("Identity:", ident.getAttribute("Name"), ident.getAttribute("Publisher"), ident.getAttribute("Version"), ident.getAttribute("ProcessorArchitecture"))
print("DisplayName:", man.getElementsByTagName("DisplayName")[0].firstChild.data, "| Publisher display:", man.getElementsByTagName("PublisherDisplayName")[0].firstChild.data)
app = man.getElementsByTagName("Application")[0]
assert app.getAttribute("Executable") in names, "executable missing"
manifest_text = z.read("AppxManifest.xml").decode()
for asset in re.findall(r'Assets\\\\[A-Za-z0-9_.]+\.png', manifest_text):
    assert asset.replace("\\", "/") in names, "missing " + asset
print("OK: %d files, %d blocks verified (hashes + independent block decode), assets and executable present." % (len(files), blocks))
