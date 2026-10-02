#!/usr/bin/env python3
"""Patch noVNC 1.7.0 for WayVNC/neatvnc RSA-AES-256 (RFB security type 129)."""

from pathlib import Path
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

if "const securityTypeUnixLogon         = 129;" not in rfb_text:
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

old = """            case securityTypePlain:
                return this._negotiatePlainAuth();
            // CGL_WAYVNC_RSA_AES256_PATCH
            case securityTypeRSA_AES256:
                return this._negotiateRA2neAuth({
                    challengeLength: 32,
                    hashAlgorithm: "SHA-256",
                    sessionKeyLength: 32,
                    hashLength: 32,
                });

            case securityTypeRA2ne:
"""
new = """            case securityTypePlain:
                return this._negotiatePlainAuth();
            // CGL_WAYVNC_RSA_AES256_PATCH
            case securityTypeRSA_AES256:
                return this._negotiateRA2neAuth({
                    challengeLength: 32,
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

# Make the existing RA2 implementation parameterised for the RSA-AES-256
# variant used by neatvnc: 32-byte randoms, SHA-256 and a 256-bit AES-EAX key.
old = """    async negotiateRA2neAuthAsync() {
        this._hasStarted = true;
"""
new = """    async negotiateRA2neAuthAsync(options = {}) {
        const challengeLength = options.challengeLength || 16;
        const hashAlgorithm = options.hashAlgorithm || "SHA-1";
        const sessionKeyLength = options.sessionKeyLength || 16;
        const hashLength = options.hashLength || 20;
        this._hasStarted = true;
"""
if old not in ra2_text:
    raise SystemExit("CGL+: noVNC ra2.js entry point did not match 1.7.0.")
ra2_text = ra2_text.replace(old, new, 1)

ra2_text = ra2_text.replace(
    "const clientRandom = new Uint8Array(16);",
    "const clientRandom = new Uint8Array(challengeLength);",
    1,
)
ra2_text = ra2_text.replace(
    "clientRandomMessage[0] = (serverKeyBytes & 0xff00) >>> 8;",
    "clientRandomMessage[0] = (serverKeyBytes & 0xff00) >>> 8;",
    1,
)
ra2_text = ra2_text.replace(
    "const serverRandom = await legacyCrypto.decrypt(\n            { name: \"RSA-PKCS1-v1_5\" }, clientRSACipher, serverEncryptedRandom);\n        if (serverRandom === null || serverRandom.length !== 16) {",
    "const serverRandom = await legacyCrypto.decrypt(\n            { name: \"RSA-PKCS1-v1_5\" }, clientRSACipher, serverEncryptedRandom);\n        if (serverRandom === null || serverRandom.length !== challengeLength) {",
    1,
)
ra2_text = ra2_text.replace(
    "let clientSessionKey = new Uint8Array(32);\n        let serverSessionKey = new Uint8Array(32);\n        clientSessionKey.set(serverRandom);\n        clientSessionKey.set(clientRandom, 16);\n        serverSessionKey.set(clientRandom);\n        serverSessionKey.set(serverRandom, 16);",
    "let clientSessionKey = new Uint8Array(challengeLength * 2);\n        let serverSessionKey = new Uint8Array(challengeLength * 2);\n        clientSessionKey.set(serverRandom);\n        clientSessionKey.set(clientRandom, challengeLength);\n        serverSessionKey.set(clientRandom);\n        serverSessionKey.set(serverRandom, challengeLength);",
    1,
)
ra2_text = ra2_text.replace(
    'clientSessionKey = await window.crypto.subtle.digest("SHA-1", clientSessionKey);\n        clientSessionKey = new Uint8Array(clientSessionKey).slice(0, 16);\n        serverSessionKey = await window.crypto.subtle.digest("SHA-1", serverSessionKey);\n        serverSessionKey = new Uint8Array(serverSessionKey).slice(0, 16);',
    'clientSessionKey = await window.crypto.subtle.digest(hashAlgorithm, clientSessionKey);\n        clientSessionKey = new Uint8Array(clientSessionKey).slice(0, sessionKeyLength);\n        serverSessionKey = await window.crypto.subtle.digest(hashAlgorithm, serverSessionKey);\n        serverSessionKey = new Uint8Array(serverSessionKey).slice(0, sessionKeyLength);',
    1,
)
ra2_text = ra2_text.replace(
    "serverHash = await window.crypto.subtle.digest(\"SHA-1\", serverHash);\n        clientHash = await window.crypto.subtle.digest(\"SHA-1\", clientHash);",
    "serverHash = await window.crypto.subtle.digest(hashAlgorithm, serverHash);\n        clientHash = await window.crypto.subtle.digest(hashAlgorithm, clientHash);",
    1,
)
ra2_text = ra2_text.replace(
    "await this._waitSockAsync(2 + 20 + 16);\n        if (this._sock.rQshift16() !== 20) {",
    "await this._waitSockAsync(2 + hashLength + 16);\n        if (this._sock.rQshift16() !== hashLength) {",
    1,
)
ra2_text = ra2_text.replace(
    "20, this._sock.rQshiftBytes(20 + 16));",
    "hashLength, this._sock.rQshiftBytes(hashLength + 16));",
    1,
)
ra2_text = ra2_text.replace(
    "for (let i = 0; i < 20; i++) {",
    "for (let i = 0; i < hashLength; i++) {",
    1,
)

if "challengeLength" not in ra2_text or "hashAlgorithm" not in ra2_text:
    raise SystemExit("CGL+: RSA-AES-256 patch verification failed.")

rfb.write_text(rfb_text, encoding="utf-8")
ra2.write_text(ra2_text, encoding="utf-8")
print("CGL+: Patched noVNC 1.7.0 for WayVNC RSA-AES-256 security type 129.")
