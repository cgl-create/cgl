# QMLE by CGL+

A local Python/Pygame desktop prototype for hybrid text encryption. The interface uses the CGL+ yellow-and-dark theme.

## Run

Python 3.15 is the intended interpreter for the current development setup.

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install --only-binary=:all: -r requirements.txt
python qmle.py
```

On macOS, if you use a virtual environment created from Python 3.15, activate it before running QMLE.

## Features

- Encrypt and decrypt text in a Pygame desktop interface.
- AES-256-GCM encrypts the message; RSA-3072-OAEP with SHA-256 wraps the random AES key.
- The serialized encrypted package is displayed as hexadecimal.
- A local RSA keypair is generated on first launch and stored in `~/.config/qmle/`.
- Input supports typing and clipboard paste; output has a copy button.

## Key storage

The private key is stored locally at `~/.config/qmle/private_key.pem` with owner-only file permissions where supported. It is currently not password-encrypted. Protect your user account and back up this key securely if you need to decrypt saved ciphertext later. Anyone with the private key can decrypt messages encrypted for its matching public key.

Do not delete or replace the keypair if you need to decrypt earlier messages. QMLE currently uses one local keypair; exchanging ciphertext with another person requires sharing that recipient's public key and selecting the matching private key for decryption, which is not yet implemented.

## Prototype status

This is an educational prototype, not an audited security product. Do not use it for high-value secrets. Hexadecimal is only the output representation; encryption is provided by AES-GCM and RSA-OAEP.
