#!/usr/bin/env python3
"""Gera o ícone do app (Ícone B — Monograma, artefato "Zywny — Ícone e
Splash"): Z itálico Cormorant Garamond creme sobre vinho, com barra dourada.

Escreve: mipmaps legados, primeiro plano do ícone adaptativo (Android) e os
ícones da web. Depende de Pillow e de assets/fonts/. Uso: tool/build_app_icon.py
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BG, INK, ACCENT = (0x5A, 0x1E, 0x2B), (0xF4, 0xEE, 0xE1), (0xC8, 0xA4, 0x5A)
FONT = os.path.join(ROOT, "assets/fonts/CormorantGaramond-SemiBoldItalic.ttf")
S = 4  # supersampling


def art(size, transparent):
    """Ícone em `size` px; `transparent`: só o desenho, sem o fundo."""
    k = size * S / 1024
    img = Image.new("RGBA", (size * S, size * S), (0, 0, 0, 0) if transparent else BG + (255,))
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, round(760 * k))
    l, t, r, b = font.getbbox("Z")
    ink_w, ink_h = r - l, b - t
    # Grupo (Z + 8 + barra 10) com a caixa de linha de 0.8 × 760, centrado
    # em 1024 - 40 de altura, como no artefato.
    line = 0.8 * 760 * k
    top = ((1024 - 40) * k - (line + 18 * k)) / 2
    cx = size * S / 2
    cy = top + line / 2
    d.text((cx - ink_w / 2 - l, cy - ink_h / 2 - t), "Z", font=font, fill=INK + (255,))
    bar_y = top + line + 8 * k
    d.rounded_rectangle((cx - 110 * k, bar_y, cx + 110 * k, bar_y + 10 * k), radius=5 * k, fill=ACCENT + (255,))
    return img.resize((size, size), Image.LANCZOS)


def save(img, rel):
    p = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p)


res = "android/app/src/main/res"
for dpi, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    save(art(px, False).convert("RGB"), f"{res}/mipmap-{dpi}/ic_launcher.png")

# Primeiro plano adaptativo: tela de 108dp (432 px em xxxhdpi); só o miolo de
# 66dp é sempre visível, então o desenho ocupa ~55% dela.
fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
core = art(1024, True)
box = core.getbbox()
core = core.crop(box)
scale = (0.52 * 432) / max(core.size)
core = core.resize((round(core.width * scale), round(core.height * scale)), Image.LANCZOS)
fg.alpha_composite(core, ((432 - core.width) // 2, (432 - core.height) // 2))
save(fg, f"{res}/drawable-nodpi/ic_launcher_foreground.png")

full = art(1024, False)
save(full, "assets/icon/app_icon.png")
save(full.convert("RGB").resize((192, 192), Image.LANCZOS), "web/icons/Icon-192.png")
save(full.convert("RGB").resize((512, 512), Image.LANCZOS), "web/icons/Icon-512.png")
save(full.convert("RGB").resize((192, 192), Image.LANCZOS), "web/icons/Icon-maskable-192.png")
save(full.convert("RGB").resize((512, 512), Image.LANCZOS), "web/icons/Icon-maskable-512.png")
save(full.convert("RGB").resize((32, 32), Image.LANCZOS), "web/favicon.png")
print("ok")
