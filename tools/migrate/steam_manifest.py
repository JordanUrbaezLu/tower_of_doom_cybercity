"""Read a Steam depot manifest (Steam/depotcache/<depot>_<manifest>.manifest). Stdlib only.

Used by bundle_tool.py to tell the stock BO3 Mod Tools files (depot 455131) from the files
packs, our tools and our builds added to the tools root (docs/174). The format is a sequence
of sections, each `uint32 magic, uint32 size, protobuf body`; the payload section holds one
FileMapping per file: 1 filename, 2 size, 3 flags (64 = directory), 5 sha1 of the content.
"""
import struct

PAYLOAD, METADATA, SIGNATURE, END = 0x71F617D0, 0x1F4812BE, 0x1B81B817, 0x32C415AB
DIRECTORY_FLAG = 64


def _varint(b, i):
    r = s = 0
    while True:
        c = b[i]
        i += 1
        r |= (c & 0x7F) << s
        s += 7
        if c < 0x80:
            return r, i


def _fields(b):
    i, n = 0, len(b)
    while i < n:
        key, i = _varint(b, i)
        f, wt = key >> 3, key & 7
        if wt == 0:
            v, i = _varint(b, i)
        elif wt == 1:
            v = b[i:i + 8]
            i += 8
        elif wt == 2:
            ln, i = _varint(b, i)
            v = b[i:i + ln]
            i += ln
        elif wt == 5:
            v = b[i:i + 4]
            i += 4
        else:
            raise ValueError('unsupported protobuf wire type %d' % wt)
        yield f, wt, v


def read(path):
    """Return (metadata dict keyed by field number, list of file dicts)."""
    data = open(path, 'rb').read()
    i, files, meta = 0, [], {}
    while i + 8 <= len(data):
        magic, size = struct.unpack_from('<II', data, i)
        i += 8
        if magic == END:
            break
        body = data[i:i + size]
        i += size
        if magic == PAYLOAD:
            for f, wt, v in _fields(body):
                if f != 1:
                    continue
                m = {'name': None, 'size': 0, 'flags': 0, 'sha': b''}
                for g, wt2, w in _fields(v):
                    if g == 1:
                        m['name'] = w.decode('utf-8', 'replace')
                    elif g == 2:
                        m['size'] = w
                    elif g == 3:
                        m['flags'] = w
                    elif g == 5:
                        m['sha'] = w
                files.append(m)
        elif magic == METADATA:
            for f, wt, v in _fields(body):
                meta[f] = v
    if meta.get(4):
        raise ValueError('manifest filenames are encrypted; cannot classify against it')
    return meta, files


def stock_files(path):
    """{lowercase forward-slash relative path: (size, sha1 bytes)} for every non-directory entry."""
    meta, entries = read(path)
    out = {}
    for m in entries:
        if m['flags'] & DIRECTORY_FLAG:
            continue
        out[m['name'].replace(chr(92), '/').lower()] = (m['size'], m['sha'])
    return meta, out


if __name__ == '__main__':
    import sys
    meta, files = stock_files(sys.argv[1])
    print('depot %s manifest %s: %d files, %d bytes' % (meta.get(1), meta.get(2), len(files), meta.get(5, 0)))
