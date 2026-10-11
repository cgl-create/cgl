#!/usr/bin/env python3
"""QMLE by CGL+ — local hybrid encryption desktop prototype."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import pygame
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.hazmat.primitives.ciphers.aead import AESGCM


APP_NAME = "QMLE by CGL+"
YELLOW = (242, 201, 76)
BACKGROUND = (15, 16, 19)
PANEL = (26, 28, 33)
PANEL_ALT = (35, 37, 43)
WHITE = (242, 243, 245)
MUTED = (160, 165, 175)
RED = (255, 105, 105)
GREEN = (115, 220, 155)
WIDTH, HEIGHT = 1000, 760
MAX_INPUT_CHARS = 100_000

DATA_DIR = Path.home() / ".config" / "qmle"
PRIVATE_KEY_PATH = DATA_DIR / "private_key.pem"
PUBLIC_KEY_PATH = DATA_DIR / "public_key.pem"


def ensure_keys() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    try:
        os.chmod(DATA_DIR, 0o700)
    except OSError:
        pass

    if PRIVATE_KEY_PATH.exists() and PUBLIC_KEY_PATH.exists():
        return

    key = rsa.generate_private_key(public_exponent=65537, key_size=3072)
    private_bytes = key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    public_bytes = key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    PRIVATE_KEY_PATH.write_bytes(private_bytes)
    PUBLIC_KEY_PATH.write_bytes(public_bytes)
    try:
        os.chmod(PRIVATE_KEY_PATH, 0o600)
        os.chmod(PUBLIC_KEY_PATH, 0o644)
    except OSError:
        pass


def load_public_key():
    return serialization.load_pem_public_key(PUBLIC_KEY_PATH.read_bytes())


def load_private_key():
    return serialization.load_pem_private_key(PRIVATE_KEY_PATH.read_bytes(), password=None)


def encrypt_text(text: str) -> str:
    if not text:
        raise ValueError("Enter text to encrypt.")
    if len(text) > MAX_INPUT_CHARS:
        raise ValueError(f"Input is limited to {MAX_INPUT_CHARS:,} characters.")

    aes_key = AESGCM.generate_key(bit_length=256)
    nonce = os.urandom(12)
    encrypted = AESGCM(aes_key).encrypt(nonce, text.encode("utf-8"), None)
    wrapped_key = load_public_key().encrypt(
        aes_key,
        padding.OAEP(
            mgf=padding.MGF1(algorithm=hashes.SHA256()),
            algorithm=hashes.SHA256(),
            label=None,
        ),
    )
    package = {
        "version": 1,
        "algorithm": "RSA-OAEP-SHA256+AES-256-GCM",
        "wrapped_key": wrapped_key.hex(),
        "nonce": nonce.hex(),
        "ciphertext": encrypted.hex(),
    }
    serialized = json.dumps(package, separators=(",", ":"), sort_keys=True).encode("utf-8")
    return serialized.hex()


def decrypt_text(hex_text: str) -> str:
    cleaned = "".join(hex_text.split())
    if not cleaned:
        raise ValueError("Paste hexadecimal ciphertext into the input area.")
    try:
        serialized = bytes.fromhex(cleaned)
        package = json.loads(serialized.decode("utf-8"))
        if package.get("version") != 1:
            raise ValueError("Unsupported QMLE ciphertext version.")
        if package.get("algorithm") != "RSA-OAEP-SHA256+AES-256-GCM":
            raise ValueError("Unsupported encryption format.")
        wrapped_key = bytes.fromhex(package["wrapped_key"])
        nonce = bytes.fromhex(package["nonce"])
        ciphertext = bytes.fromhex(package["ciphertext"])
    except (ValueError, KeyError, TypeError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError("Invalid QMLE hexadecimal ciphertext.") from exc

    aes_key = load_private_key().decrypt(
        wrapped_key,
        padding.OAEP(
            mgf=padding.MGF1(algorithm=hashes.SHA256()),
            algorithm=hashes.SHA256(),
            label=None,
        ),
    )
    try:
        plaintext = AESGCM(aes_key).decrypt(nonce, ciphertext, None)
    except Exception as exc:
        raise ValueError("Decryption failed: wrong key or ciphertext was altered.") from exc
    return plaintext.decode("utf-8")


class QMLEApp:
    def __init__(self):
        pygame.init()
        pygame.display.set_caption(APP_NAME)
        self.screen = pygame.display.set_mode((WIDTH, HEIGHT), pygame.RESIZABLE)
        self.clock = pygame.time.Clock()
        self.font = pygame.font.SysFont("Arial", 18)
        self.small = pygame.font.SysFont("Arial", 14)
        self.title_font = pygame.font.SysFont("Arial", 30, bold=True)
        self.input_text = ""
        self.output_text = ""
        self.mode = "encrypt"
        self.status = "Ready"
        self.status_color = MUTED
        self.input_scroll = 0
        self.output_scroll = 0
        self.focused = "input"
        self.running = True
        self.buttons = {}

    def text(self, value, x, y, color=WHITE, font=None):
        surface = (font or self.font).render(value, True, color)
        self.screen.blit(surface, (x, y))

    def button(self, name, label, rect, active=False, primary=False):
        color = YELLOW if primary or active else PANEL_ALT
        fg = BACKGROUND if primary or active else WHITE
        pygame.draw.rect(self.screen, color, rect, border_radius=9)
        self.text(label, rect.x + 14, rect.y + 10, fg, self.small)
        self.buttons[name] = rect

    def wrap_lines(self, value, max_width):
        lines = []
        for raw in value.splitlines() or [""]:
            if not raw:
                lines.append("")
                continue
            current = ""
            for char in raw:
                candidate = current + char
                if self.font.size(candidate)[0] > max_width and current:
                    lines.append(current)
                    current = char
                else:
                    current = candidate
            lines.append(current)
        return lines

    def draw_text_area(self, rect, content, focused, scroll):
        pygame.draw.rect(self.screen, PANEL, rect, border_radius=10)
        pygame.draw.rect(self.screen, YELLOW if focused else PANEL_ALT, rect, width=2, border_radius=10)
        inner = rect.inflate(-24, -22)
        old_clip = self.screen.get_clip()
        self.screen.set_clip(inner)
        lines = self.wrap_lines(content, inner.width)
        line_height = 23
        max_scroll = max(0, len(lines) * line_height - inner.height)
        scroll = min(scroll, max_scroll)
        y = inner.y - scroll
        for line in lines:
            if y + line_height >= inner.y and y <= inner.bottom:
                self.text(line, inner.x, y, WHITE, self.small)
            y += line_height
        self.screen.set_clip(old_clip)
        return scroll

    def do_encrypt(self):
        try:
            self.output_text = encrypt_text(self.input_text)
            self.status = "Encryption complete — hexadecimal output ready."
            self.status_color = GREEN
            self.output_scroll = 0
        except Exception as exc:
            self.status = str(exc)
            self.status_color = RED

    def do_decrypt(self):
        try:
            self.output_text = decrypt_text(self.input_text)
            self.status = "Decryption complete."
            self.status_color = GREEN
            self.output_scroll = 0
        except Exception as exc:
            self.status = str(exc)
            self.status_color = RED

    def copy_output(self):
        try:
            pygame.scrap.init()
            pygame.scrap.put(pygame.SCRAP_TEXT, self.output_text.encode("utf-8") + b"\0")
            self.status = "Output copied to clipboard."
            self.status_color = GREEN
        except Exception:
            self.status = "Clipboard unavailable; select and copy output manually."
            self.status_color = RED

    def draw(self):
        width, height = self.screen.get_size()
        self.screen.fill(BACKGROUND)
        self.text("CGL+", 28, 20, YELLOW, self.title_font)
        self.text("QMLE  /  HYBRID ENCRYPTION", 125, 30, WHITE, self.small)
        self.text("Local prototype", width - 150, 30, MUTED, self.small)

        top = 72
        self.button("encrypt_mode", "ENCRYPT", pygame.Rect(28, top, 112, 38),
                    active=self.mode == "encrypt")
        self.button("decrypt_mode", "DECRYPT", pygame.Rect(148, top, 112, 38),
                    active=self.mode == "decrypt")
        self.text("Input", 30, 128, WHITE)
        self.text("Plain text to encrypt, or hex ciphertext to decrypt", 90, 131, MUTED, self.small)

        input_rect = pygame.Rect(28, 158, width - 56, max(150, int((height - 250) * 0.44)))
        self.input_scroll = self.draw_text_area(
            input_rect, self.input_text, self.focused == "input", self.input_scroll
        )
        action_y = input_rect.bottom + 12
        self.button("run", "ENCRYPT TEXT" if self.mode == "encrypt" else "DECRYPT HEX",
                    pygame.Rect(28, action_y, 150, 40), primary=True)
        self.button("clear", "CLEAR", pygame.Rect(190, action_y, 82, 40))
        self.button("copy", "COPY OUTPUT", pygame.Rect(284, action_y, 118, 40))

        output_label_y = action_y + 54
        self.text("Output", 30, output_label_y, WHITE)
        self.text("Hexadecimal ciphertext or decrypted text", 95, output_label_y + 3, MUTED, self.small)
        output_rect = pygame.Rect(28, output_label_y + 28, width - 56,
                                  max(100, height - (output_label_y + 72)))
        self.output_scroll = self.draw_text_area(
            output_rect, self.output_text, self.focused == "output", self.output_scroll
        )
        status_y = height - 27
        self.text(self.status[:150], 30, status_y, self.status_color, self.small)
        pygame.display.flip()

    def handle_click(self, pos):
        for name, rect in self.buttons.items():
            if not rect.collidepoint(pos):
                continue
            if name == "encrypt_mode":
                self.mode = "encrypt"
                self.status = "Enter plain text to encrypt."
                self.status_color = MUTED
            elif name == "decrypt_mode":
                self.mode = "decrypt"
                self.status = "Paste hexadecimal ciphertext to decrypt."
                self.status_color = MUTED
            elif name == "run":
                self.do_encrypt() if self.mode == "encrypt" else self.do_decrypt()
            elif name == "clear":
                self.input_text = ""
                self.output_text = ""
                self.status = "Cleared."
                self.status_color = MUTED
                self.input_scroll = self.output_scroll = 0
            elif name == "copy":
                self.copy_output()
            return
        width, height = self.screen.get_size()
        input_rect = pygame.Rect(28, 158, width - 56, max(150, int((height - 250) * 0.44)))
        output_label_y = input_rect.bottom + 12 + 54
        output_rect = pygame.Rect(28, output_label_y + 28, width - 56,
                                  max(100, height - (output_label_y + 72)))
        if input_rect.collidepoint(pos):
            self.focused = "input"
        elif output_rect.collidepoint(pos):
            self.focused = "output"

    def run(self):
        while self.running:
            self.draw()
            self.clock.tick(60)
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    self.running = False
                elif event.type == pygame.MOUSEBUTTONDOWN:
                    if event.button == 1:
                        self.handle_click(event.pos)
                    elif event.button == 4:
                        if self.focused == "input":
                            self.input_scroll = max(0, self.input_scroll - 46)
                        else:
                            self.output_scroll = max(0, self.output_scroll - 46)
                    elif event.button == 5:
                        if self.focused == "input":
                            self.input_scroll += 46
                        else:
                            self.output_scroll += 46
                elif event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        self.running = False
                    elif event.key == pygame.K_TAB:
                        self.focused = "output" if self.focused == "input" else "input"
                    elif self.focused == "input":
                        if event.key == pygame.K_BACKSPACE:
                            self.input_text = self.input_text[:-1]
                        elif event.key == pygame.K_RETURN:
                            self.input_text += "\n"
                        elif event.key == pygame.K_v and (event.mod & pygame.KMOD_CTRL or event.mod & pygame.KMOD_META):
                            try:
                                pygame.scrap.init()
                                raw = pygame.scrap.get(pygame.SCRAP_TEXT)
                                if raw:
                                    self.input_text += raw.decode("utf-8", errors="replace").rstrip("\0")
                            except Exception:
                                pass
                        elif event.key == pygame.K_a and (event.mod & pygame.KMOD_CTRL or event.mod & pygame.KMOD_META):
                            pass
                        elif event.unicode and event.unicode.isprintable():
                            if len(self.input_text) < MAX_INPUT_CHARS:
                                self.input_text += event.unicode
                    elif self.focused == "output" and event.key == pygame.K_c and (event.mod & pygame.KMOD_CTRL or event.mod & pygame.KMOD_META):
                        self.copy_output()
        pygame.quit()


def main() -> int:
    try:
        ensure_keys()
        QMLEApp().run()
        return 0
    except Exception as exc:
        print(f"QMLE error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
