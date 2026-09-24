#!/usr/bin/env bash
# TEST-ONLY certificate authority for the App Store JWS chain tests (never trusted by the running server).
# Mirrors Apple's shape: an ECDSA P-256 root, an intermediate carrying Apple's WWDR marker
# (1.2.840.113635.100.6.2.1) and a leaf carrying the receipt-signing marker (1.2.840.113635.100.6.11.1), plus:
#   dev-leaf    — issued by the same intermediate but WITHOUT the leaf marker (a developer's own certificate);
#   rogue-*     — a look-alike chain from a root the server does not trust.
# Re-run to regenerate (files are committed; the keys protect nothing).
set -euo pipefail
cd "$(dirname "$0")"
OUT=test-ca
rm -rf "$OUT" && mkdir -p "$OUT"
cd "$OUT"

ec() { openssl ecparam -name prime256v1 -genkey -noout -out "$1.key.tmp" && openssl pkcs8 -topk8 -nocrypt -in "$1.key.tmp" -out "$1.key" && rm "$1.key.tmp"; }

cat > ext.cnf <<'EOF'
[root]
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
[intermediate]
basicConstraints = critical, CA:TRUE, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid
1.2.840.113635.100.6.2.1 = ASN1:NULL
[leaf]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid
1.2.840.113635.100.6.11.1 = ASN1:NULL
[devleaf]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid
EOF

mk_root() { # name cn
  ec "$1"
  openssl req -x509 -new -key "$1.key" -sha256 -days 7300 -subj "/CN=$2/O=Aura Test/C=IN" \
    -extensions root -config <(cat /etc/ssl/openssl.cnf 2>/dev/null || true; cat ext.cnf) -out "$1.pem"
}
mk_cert() { # name cn issuer section
  ec "$1"
  openssl req -new -key "$1.key" -subj "/CN=$2/O=Aura Test/C=IN" -out "$1.csr"
  openssl x509 -req -in "$1.csr" -CA "$3.pem" -CAkey "$3.key" -CAcreateserial -sha256 -days 3650 \
    -extfile ext.cnf -extensions "$4" -out "$1.pem"
  rm "$1.csr"
}

mk_root root "Aura Test Root CA - G3"
mk_cert intermediate "Aura Test WWDR - G6" root intermediate
mk_cert leaf "Aura Test Prod ECC Receipt Signing" intermediate leaf
mk_cert dev-leaf "Aura Test Apple Development: Someone" intermediate devleaf
mk_root rogue-root "Apple Root CA - G3"
mk_cert rogue-intermediate "Aura Test WWDR - G6" rogue-root intermediate
mk_cert rogue-leaf "Aura Test Prod ECC Receipt Signing" rogue-intermediate leaf
rm -f ./*.srl ext.cnf
for f in *.pem; do openssl x509 -in "$f" -outform der -out "${f%.pem}.der"; done
ls
