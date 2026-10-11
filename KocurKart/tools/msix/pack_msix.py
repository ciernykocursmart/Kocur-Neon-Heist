#!/usr/bin/env python3
"""Minimal MSIX packer (unsigned), compatible with Microsoft's makemsix output.

Writes the same container layout as the official MSIX SDK `makemsix pack`:
  * payload files, then AppxManifest.xml, AppxBlockMap.xml, [Content_Types].xml
  * ZIP entries with version 4.5, data descriptors (zip64 form) and a zip64
    end-of-central-directory record
  * compressible files deflated block by block (64 KiB uncompressed blocks,
    each ending in a sync flush) so every block's compressed size is exact;
    already-compressed media (png, jpg, ...) stored
  * AppxBlockMap.xml with the SHA-256 of every block

The package is unsigned; Microsoft Store signs packages on submission.

Usage: pack_msix.py <staging_dir> <out.msix> [--level N]
"""
import base64
import hashlib
import os
import struct
import sys
import time
import zlib
from xml.sax.saxutils import escape, quoteattr

BLOCK = 65536
STORED_EXT = {".png", ".jpg", ".jpeg", ".gif", ".zip", ".mp3", ".ogg", ".mp4", ".msix", ".appx", ".7z", ".gz", ".cab"}
CONTENT_TYPES = {
    ".txt": "text/plain", ".exe": "application/x-msdownload", ".dll": "application/x-msdownload",
    ".png": "image/png", ".jpg": "image/jpeg", ".xml": "application/vnd.ms-appx.manifest+xml",
    ".pck": "application/octet-stream", ".json": "application/json", ".ico": "image/vnd.microsoft.icon",
}


def dos_time(t):
    lt = time.localtime(t)
    dtime = (lt.tm_hour << 11) | (lt.tm_min << 5) | (lt.tm_sec // 2)
    ddate = ((lt.tm_year - 1980) << 9) | (lt.tm_mon << 5) | lt.tm_mday
    return dtime, ddate


def deflate_blocks(data, level):
    """Deflates each 64 KiB block as an independent stream ending in a sync
    flush (as the MSIX SDK does), so any block can be decoded on its own.
    Returns (stream, block_sizes)."""
    out = []
    sizes = []
    for i in range(0, len(data), BLOCK):
        co = zlib.compressobj(level, zlib.DEFLATED, -15, 9)
        c = co.compress(data[i:i + BLOCK]) + co.flush(zlib.Z_SYNC_FLUSH)
        out.append(c)
        sizes.append(len(c))
    out.append(b"\x03\x00")   # final empty fixed-Huffman block
    return b"".join(out), sizes


def verify_blocks(data, stream, sizes):
    """Self-check: every block decodes independently to the original bytes,
    and the whole entry decodes as one deflate stream."""
    pos = 0
    for k, size in enumerate(sizes):
        d = zlib.decompressobj(-15)
        got = d.decompress(stream[pos:pos + size])
        if got != data[k * BLOCK:(k + 1) * BLOCK]:
            raise SystemExit("block %d failed independent decode" % k)
        pos += size
    if zlib.decompress(stream, -15) != data:
        raise SystemExit("entry failed full decode")


def deflate_plain(data, level):
    co = zlib.compressobj(level, zlib.DEFLATED, -15)
    return co.compress(data) + co.flush(zlib.Z_FINISH)


class Writer:
    def __init__(self, path):
        self.f = open(path, "wb")
        self.entries = []
        self.dtime, self.ddate = dos_time(time.time())

    def add(self, name, data, method, comp):
        crc = zlib.crc32(data) & 0xFFFFFFFF
        fname = name.encode("utf-8")
        offset = self.f.tell()
        lfh = struct.pack("<IHHHHHIIIHH", 0x04034B50, 45, 0x08, method, self.dtime, self.ddate, 0, 0, 0, len(fname), 0)
        self.f.write(lfh + fname)
        self.f.write(comp)
        self.f.write(struct.pack("<IIQQ", 0x08074B50, crc, len(comp), len(data)))
        self.entries.append((fname, method, crc, len(comp), len(data), offset))
        return len(lfh) + len(fname)

    def close(self):
        cd_start = self.f.tell()
        for fname, method, crc, csize, usize, offset in self.entries:
            if csize >= 0xFFFFFFFF or usize >= 0xFFFFFFFF or offset >= 0xFFFFFFFF:
                raise SystemExit("files over 4 GiB are not supported by this packer")
            self.f.write(struct.pack("<IHHHHHHIIIHHHHHII", 0x02014B50, 45, 45, 0x08, method, self.dtime, self.ddate,
                                     crc, csize, usize, len(fname), 0, 0, 0, 0, 0, offset) + fname)
        cd_end = self.f.tell()
        n = len(self.entries)
        z64 = cd_end
        self.f.write(struct.pack("<IQHHIIQQQQ", 0x06064B50, 44, 45, 45, 0, 0, n, n, cd_end - cd_start, cd_start))
        self.f.write(struct.pack("<IIQI", 0x07064B50, 0, z64, 1))
        self.f.write(struct.pack("<IHHHHIIH", 0x06054B50, 0, 0, 0xFFFF, 0xFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0))
        self.f.close()


def collect(staging):
    files = []
    for root, _dirs, names in os.walk(staging):
        for n in names:
            full = os.path.join(root, n)
            rel = os.path.relpath(full, staging).replace(os.sep, "/")
            if rel in ("AppxManifest.xml", "AppxBlockMap.xml", "[Content_Types].xml", "AppxSignature.p7x"):
                continue
            files.append(rel)
    # Root files first, then folders, like makemsix.
    files.sort(key=lambda r: (r.count("/"), r.lower()))
    return files


def pack(staging, out, level=9):
    manifest = os.path.join(staging, "AppxManifest.xml")
    if not os.path.isfile(manifest):
        raise SystemExit("AppxManifest.xml missing in " + staging)
    order = collect(staging) + ["AppxManifest.xml"]
    w = Writer(out)
    bm = ['<?xml version="1.0" encoding="UTF-8" standalone="no"?><BlockMap xmlns="http://schemas.microsoft.com/appx/2010/blockmap" '
          'HashMethod="http://www.w3.org/2001/04/xmlenc#sha256">']
    exts = {}
    for rel in order:
        data = open(os.path.join(staging, rel), "rb").read()
        ext = os.path.splitext(rel)[1].lower()
        exts[ext] = CONTENT_TYPES.get(ext, "application/octet-stream")
        hashes = [base64.b64encode(hashlib.sha256(data[i:i + BLOCK]).digest()).decode() for i in range(0, len(data), BLOCK)]
        if ext in STORED_EXT:
            lfh = w.add(rel, data, 0, data)
            blocks = "".join('<Block Hash="%s"/>' % h for h in hashes)
        else:
            comp, sizes = deflate_blocks(data, level)
            verify_blocks(data, comp, sizes)
            lfh = w.add(rel, data, 8, comp)
            blocks = "".join('<Block Hash="%s" Size="%d"/>' % (h, s) for h, s in zip(hashes, sizes))
        bm.append('<File Name=%s Size="%d" LfhSize="%d">%s</File>' % (quoteattr(rel.replace("/", "\\")), len(data), lfh, blocks))
    bm.append("</BlockMap>")
    blockmap = "".join(bm).encode("utf-8")
    w.add("AppxBlockMap.xml", blockmap, 8, deflate_plain(blockmap, level))
    ct = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">']
    for ext, mime in sorted(exts.items()):
        if ext:
            ct.append('<Default ContentType=%s Extension=%s/>' % (quoteattr(mime), quoteattr(ext[1:])))
    ct.append('<Override ContentType="application/vnd.ms-appx.blockmap+xml" PartName="/AppxBlockMap.xml"/></Types>')
    ctypes = "".join(ct).encode("utf-8")
    w.add("[Content_Types].xml", ctypes, 8, deflate_plain(ctypes, level))
    w.close()
    return blockmap


if __name__ == "__main__":
    args = sys.argv[1:]
    lvl = 9
    if "--level" in args:
        i = args.index("--level")
        lvl = int(args[i + 1])
        del args[i:i + 2]
    if len(args) != 2:
        raise SystemExit(__doc__)
    pack(args[0], args[1], lvl)
    print("Wrote", args[1], os.path.getsize(args[1]), "bytes")
