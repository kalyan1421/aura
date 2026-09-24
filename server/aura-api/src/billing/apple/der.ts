/**
 * Just enough DER to list an X.509 certificate's extension OIDs (Node's X509Certificate doesn't expose arbitrary
 * extensions). Certificate ::= SEQUENCE { tbsCertificate SEQUENCE { …, [3] EXPLICIT Extensions }, … };
 * Extension ::= SEQUENCE { extnID OBJECT IDENTIFIER, critical BOOLEAN DEFAULT FALSE, extnValue OCTET STRING }.
 */

interface Tlv {
  tag: number;
  start: number; // first content byte
  end: number; // one past the last content byte
}

export class DerError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'DerError';
  }
}

function readTlv(buf: Buffer, at: number, limit: number): Tlv {
  if (at + 2 > limit) throw new DerError('truncated');
  const tag = buf[at];
  let len = buf[at + 1];
  let p = at + 2;
  if (len & 0x80) {
    const n = len & 0x7f;
    if (n === 0 || n > 4 || p + n > limit) throw new DerError('bad length');
    len = 0;
    for (let i = 0; i < n; i++) len = len * 256 + buf[p + i];
    p += n;
  }
  if (p + len > limit) throw new DerError('truncated');
  return { tag, start: p, end: p + len };
}

function children(buf: Buffer, parent: Tlv): Tlv[] {
  const out: Tlv[] = [];
  let at = parent.start;
  while (at < parent.end) {
    const t = readTlv(buf, at, parent.end);
    out.push(t);
    at = t.end;
  }
  return out;
}

export function decodeOid(bytes: Buffer): string {
  if (bytes.length === 0) throw new DerError('empty oid');
  const arcs: number[] = [];
  const first = bytes[0];
  arcs.push(first < 80 ? Math.floor(first / 40) : 2, first < 80 ? first % 40 : first - 80);
  let v = 0;
  for (let i = 1; i < bytes.length; i++) {
    v = v * 128 + (bytes[i] & 0x7f);
    if (!(bytes[i] & 0x80)) {
      arcs.push(v);
      v = 0;
    }
  }
  return arcs.join('.');
}

/** Dotted OIDs of every extension of a DER certificate (empty when it has none). Throws DerError on malformed input. */
export function certificateExtensionOids(der: Buffer): string[] {
  const cert = readTlv(der, 0, der.length);
  if (cert.tag !== 0x30) throw new DerError('not a sequence');
  const [tbs] = children(der, cert);
  if (!tbs || tbs.tag !== 0x30) throw new DerError('no tbsCertificate');
  const ext = children(der, tbs).find((t) => t.tag === 0xa3);
  if (!ext) return [];
  const [seq] = children(der, ext);
  if (!seq || seq.tag !== 0x30) throw new DerError('bad extensions');
  return children(der, seq).map((e) => {
    const [oid] = children(der, e);
    if (!oid || oid.tag !== 0x06) throw new DerError('bad extension');
    return decodeOid(der.subarray(oid.start, oid.end));
  });
}
