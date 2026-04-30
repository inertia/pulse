#!/usr/bin/env bash
# One-time: generate a self-signed code-signing certificate and import into the
# user's login keychain. After this, build-and-install.sh signs Pulse with the
# cert (instead of ad-hoc), so macOS TCC's Designated Requirement stays stable
# across rebuilds — Full Disk Access grants survive instead of being silently
# invalidated by the cdhash drift inherent to ad-hoc signing.
#
# Run once. Re-running is a no-op if cert already exists with the same CN.
#
# What this DOES touch: ~/Library/Keychains/login.keychain-db
# What this DOES NOT touch: /Library/Keychains/System.keychain, sudo, trust DB,
# any other certificate.
set -euo pipefail

CERT_NAME="Pulse Personal Code Signing"

# Idempotency: skip if cert with this CN already in login keychain.
# Use unfiltered listing (no -v) — self-signed certs report as untrusted but
# codesign uses them fine; we just want to detect presence by CN.
if security find-identity -p codesigning login.keychain 2>/dev/null \
     | grep -q "\"$CERT_NAME\""; then
  echo "✓ Cert already present: $CERT_NAME"
  exit 0
fi

# Workspace under one temp dir with simple filenames. macOS `security import`
# empirically rejects PKCS#12 files at long paths produced by `mktemp -t` even
# when content is identical — easier to side-step than diagnose.
TMP_DIR=$(mktemp -d /tmp/pulse-cert-setup.XXXXXX)
TMP_KEY="$TMP_DIR/key.pem"
TMP_CSR="$TMP_DIR/req.csr"
TMP_CRT="$TMP_DIR/cert.crt"
TMP_P12="$TMP_DIR/bundle.p12"
TMP_CNF="$TMP_DIR/openssl.cnf"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_CNF" <<EOF
[req]
distinguished_name = req_dn
prompt = no
x509_extensions = v3_cs

[req_dn]
CN = $CERT_NAME

[v3_cs]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

echo "→ Generating RSA 2048 private key (PKCS#1 traditional — macOS compatible)…"
openssl genrsa -traditional -out "$TMP_KEY" 2048 2>/dev/null

echo "→ Generating CSR…"
openssl req -new -key "$TMP_KEY" -out "$TMP_CSR" -config "$TMP_CNF" 2>/dev/null

echo "→ Self-signing (10y validity)…"
openssl x509 -req -in "$TMP_CSR" -signkey "$TMP_KEY" -out "$TMP_CRT" \
  -days 3650 -extfile "$TMP_CNF" -extensions v3_cs 2>/dev/null

echo "→ Bundling into PKCS#12 (-legacy mode — modern AES-256 PKCS#12 is rejected by macOS)…"
# Empirically: explicit -keypbe PBE-SHA1-3DES is rejected on macOS 26 ("Unknown
# format"), but plain -legacy (which selects RC2-40 + 3DES per OpenSSL legacy
# defaults) is accepted. Don't override the PBE algorithms.
openssl pkcs12 -export -legacy \
  -out "$TMP_P12" \
  -inkey "$TMP_KEY" -in "$TMP_CRT" \
  -password pass:temppw -name "$CERT_NAME"

echo "→ Importing PKCS#12 bundle into login keychain (any-app access)…"
# `-A` (any application) avoids the GUI "codesign wants to access keychain"
# dialog. Tighter alternative is `-T /usr/bin/codesign`, but that authorises
# only the literal /usr/bin/codesign binary; xcodebuild internally invokes
# Xcode's bundled codesign at a different path, so the prompt re-appears at
# build time even after clicking "Always Allow". The cert is only used to sign
# Pulse on this dev machine, so any-app access is an acceptable trade-off.
security import "$TMP_P12" \
  -k "$HOME/Library/Keychains/login.keychain-db" \
  -P temppw \
  -A

echo
echo "=== Verify ==="
# Use unfiltered listing — `-v` filters out untrusted self-signed certs even
# though codesign doesn't actually require trust. So we look for the identity
# in the full list and then test-sign a tiny binary as the real proof.
if security find-identity -p codesigning login.keychain | grep -q "\"$CERT_NAME\""; then
  echo "✓ Cert in keychain"
else
  echo "✗ Cert not in keychain after import — investigate"
  exit 1
fi

TEST_BIN="$TMP_DIR/signtest"
cp /bin/echo "$TEST_BIN"
codesign --remove-signature "$TEST_BIN" 2>/dev/null || true
if codesign -s "$CERT_NAME" "$TEST_BIN" 2>&1 | grep -q "$TEST_BIN.*replacing"; then
  : # expected — codesign warns when re-signing
fi
if codesign -dvvv "$TEST_BIN" 2>&1 | grep -q "Authority=$CERT_NAME"; then
  echo "✓ Test-sign succeeded — codesign can use this cert"
else
  echo "✗ Test-sign failed — cert is in keychain but codesign rejects it"
  exit 1
fi
