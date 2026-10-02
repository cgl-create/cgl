#!/usr/bin/env python3
"""Patch noVNC 1.7.0 for WayVNC/neatvnc RSA-AES-256 (RFB security type 129)."""

from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
rfb = root / "core" / "rfb.js"
ra2 = root / "core" / "ra2.js"

if not rfb.is_file() or not ra2.is_file():
    raise SystemExit("CGL+: noVNC core files are missing.")

rfb_text = rfb.read_text(encoding="utf-8")
ra2_text = ra2.read_text(encoding="utf-8")

marker = "CGL_WAYVNC_RSA_AES256_PATCH"
if marker in rfb_text and marker in ra2_text:
    print("CGL+: WayVNC RSA-AES-256 noVNC patch is already applied.")
    raise SystemExit(0)

if not re.search(r"const\s+securityTypeUnixLogon\s*=\s*129\s*;", rfb_text):
    raise SystemExit("CGL+: noVNC 1.7.0 security-type layout changed; refusing unsafe patch.")

# WayVNC/neatvnc uses RFB security type 129 for RSA-AES-256. noVNC 1.7.0
# reserves 129 for Tight UnixLogon, so the stock client selects the wrong
# handshake. Keep the change narrowly scoped to this security type.
rfb_text = rfb_text.replace(
    "const securityTypeUnixLogon         = 129;",
    "// CGL_WAYVNC_RSA_AES256_PATCH\nconst securityTypeRSA_AES256        = 129;",
    1,
)

rfb_text = rfb_text.replace(
    "            securityTypeMSLogonII,\n            securityTypePlain,",
    "            securityTypeMSLogonII,\n            securityTypePlain,\n            securityTypeRSA_AES256,",
    1,
)

old = """            // Look for a matching security type in the order that the
            // server prefers
            this._rfbAuthScheme = -1;
            for (let type of types) {
                if (this._isSupportedSecurityType(type)) {
                    this._rfbAuthScheme = type;
                    break;
                }
            }
"""
new = """            // CGL_WAYVNC_RSA_AES256_PATCH
            // WayVNC advertises VeNCrypt first, but noVNC 1.7.0 only
            // understands VeNCrypt Plain (256), while WayVNC commonly
            // exposes X509Plain (262). Prefer its supported RSA-AES-256
            // security type when advertised.
            this._rfbAuthScheme = -1;
            const preferredTypes = types.includes(securityTypeRSA_AES256) ?
                [securityTypeRSA_AES256, ...types.filter(type => type !== securityTypeRSA_AES256)] :
                types;
            for (let type of preferredTypes) {
                if (this._isSupportedSecurityType(type)) {
                    this._rfbAuthScheme = type;
                    break;
                }
            }
"""
if old not in rfb_text:
    raise SystemExit("CGL+: noVNC security negotiation block did not match 1.7.0.")

rfb_text = rfb_text.replace(old, new, 1)

old = """            case securityTypePlain:\n                return this._negotiatePlainAuth();\n\n            case securityTypeUnixLogon:\n                return this._negotiateTightUnixAuth();\n\n            case securityTypeRA2ne:\n"""
new = """            case securityTypePlain:
                return this._negotiatePlainAuth();

            // CGL_WAYVNC_RSA_AES256_PATCH
            case securityTypeRSA_AES256:
                return this._negotiateRA2neAuth({
                    hashAlgorithm: "SHA-256",
                    sessionKeyLength: 32,
                    hashLength: 32,
                });

            case securityTypeRA2ne:
"""
if old not in rfb_text:
    raise SystemExit("CGL+: noVNC authentication switch did not match 1.7.0.")

rfb_text = rfb_text.replace(old, new, 1)

old = """    _negotiateRA2neAuth() {
"""
new = """    // CGL_WAYVNC_RSA_AES256_PATCH
    _negotiateRA2neAuth(options = {}) {
"""
if old not in rfb_text:
    raise SystemExit("CGL+: noVNC RA2 handler did not match 1.7.0.")
rfb_text = rfb_text.replace(old, new, 1)

old = """            this._rfbRSAAESAuthenticationState.negotiateRA2neAuthAsync()
"""
new = """            this._rfbRSAAESAuthenticationState.negotiateRA2neAuthAsync(options)
"""
if old not in rfb_text:
    raise SystemExit("CGL+: noVNC RA2 async call did not match 1.7.0.")
rfb_text = rfb_text.replace(old, new, 1)

# Parameterize the existing RA2 implementation for RSA-AES-256.
# Per the RFB RSA-AES-256 specification, the RSA randoms remain 16 bytes;
# only SHA-1 -> SHA-256 and the resulting AES key length/hash length change.
old = """    async negotiateRA2neAuthAsync() {
        this._hasStarted = true;
"""
new = """    async negotiateRA2neAuthAsync(options = {}) {
        const hashAlgorithm = options.hashAlgorithm || "SHA-1";
        const sessionKeyLength = options.sessionKeyLength || 16;
        const hashLength = options.hashLength || 20;
        this._hasStarted = true;
"""
if old not in ra2_text:
    raise SystemExit("CGL+: noVNC ra2.js entry point did not match 1.7.0.")
ra2_text = ra2_text.replace(old, new, 1)

old = 'clientSessionKey = await window.crypto.subtle.digest("SHA-1", clientSessionKey);\n        clientSessionKey = new Uint8Array(clientSessionKey).slice(0, 16);\n        serverSessionKey = await window.crypto.subtle.digest("SHA-1", serverSessionKey);\n        serverSessionKey = new Uint8Array(serverSessionKey).slice(0, 16);'
new = 'clientSessionKey = await window.crypto.subtle.digest(hashAlgorithm, clientSessionKey);\n        clientSessionKey = new Uint8Array(clientSessionKey).slice(0, sessionKeyLength);\n        serverSessionKey = await window.crypto.subtle.digest(hashAlgorithm, serverSessionKey);\n        serverSessionKey = new Uint8Array(serverSessionKey).slice(0, sessionKeyLength);'
if old not in ra2_text:
    raise SystemExit("CGL+: noVNC RA2 key derivation block did not match 1.7.0.")
ra2_text = ra2_text.replace(old, new, 1)

old = 'serverHash = await window.crypto.subtle.digest("SHA-1", serverHash);\n        clientHash = await window.crypto.subtle.digest("SHA-1", clientHash);'
new = 'serverHash = await window.crypto.subtle.digest(hashAlgorithm, serverHash);\n        clientHash = await window.crypto.subtle.digest(hashAlgorithm, clientHash);'
if old not in ra2_text:
    raise SystemExit("CGL+: noVNC RA2 hash block did not match 1.7.0.")
ra2_text = ra2_text.replace(old, new, 1)

old = 'await this._waitSockAsync(2 + 20 + 16);\n        if (this._sock.rQshift16() !== 20) {'
new = 'await this._waitSockAsync(2 + hashLength + 16);\n        if (this._sock.rQshift16() !== hashLength) {'
if old not in ra2_text:
    raise SystemExit("CGL+: noVNC RA2 server-hash length block did not match 1.7.0.")
ra2_text = ra2_text.replace(old, new, 1)

old = '20, this._sock.rQshiftBytes(20 + 16));'
new = 'hashLength, this._sock.rQshiftBytes(hashLength + 16));'
if old not in ra2_text:
    raise SystemExit("CGL+: noVNC RA2 server-hash payload block did not match 1.7.0.")
ra2_text = ra2_text.replace(old, new, 1)

old = 'for (let i = 0; i < 20; i++) {'
new = 'for (let i = 0; i < hashLength; i++) {'
if old not in ra2_text:
    raise SystemExit("CGL+: noVNC RA2 server-hash compare block did not match 1.7.0.")
ra2_text = ra2_text.replace(old, new, 1)

if "hashAlgorithm" not in ra2_text or "hashLength" not in ra2_text:
    raise SystemExit("CGL+: RSA-AES-256 patch verification failed.")

rfb.write_text(rfb_text, encoding="utf-8")
ra2.write_text(ra2_text, encoding="utf-8")
print("CGL+: Patched noVNC 1.7.0 for WayVNC RSA-AES-256 security type 129.")
