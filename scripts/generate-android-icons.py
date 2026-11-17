#!/usr/bin/env python3
"""Genera los PNG del icono de Pagate desde la misma geometria que el vector.

Por que existe este script en vez de PNG pegados a mano: el icono adaptativo
vive en android/app/src/main/res/drawable/ic_launcher_foreground.xml y es la
fuente de verdad. Los PNG legacy (API 24-25, que no leen mipmap-anydpi-v26) y el
icono de 512x512 de la ficha de Google Play tienen que ser *el mismo* dibujo; si
se generan a ojo con otra herramienta, divergen en el primer retoque. Aqui la
geometria se declara una sola vez y los dos formatos salen de ella.

Uso:
    python scripts/generate-android-icons.py

Requiere Pillow (`pip install Pillow`). Reescribe:
    android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png
    android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher_round.png
    android/play/icon-512.png

El resultado es determinista: dos ejecuciones producen bytes identicos.
"""

from __future__ import annotations

import pathlib
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover - ruta de error de entorno
    sys.exit('Falta Pillow. Instalalo con: pip install Pillow')

# ---------------------------------------------------------------------------
# Geometria, en las coordenadas del lienzo adaptativo de 108x108 dp.
# Es una transcripcion literal del pathData de ic_launcher_foreground.xml:
# cualquier cambio alla tiene que replicarse aqui (y al reves).
# ---------------------------------------------------------------------------

VIEWPORT = 108.0
# El lanzador solo muestra los 72 dp centrales del lienzo de 108: ese recorte es
# el que hay que reproducir en los PNG para que legacy y adaptativo se vean
# igual. 18 dp de margen por lado.
VISIBLE = 72.0
VISIBLE_OFFSET = (VIEWPORT - VISIBLE) / 2.0

BRAND = (0x00, 0x6B, 0x5F, 0xFF)  # token `brand` de docs/DISENO-v2.md
GLYPH = (0xFF, 0xFF, 0xFF, 0xFF)

# Radio de la esquina del PNG legacy, en fraccion del lado. 22 % aproxima la
# mascara de rectangulo redondeado que aplican los lanzadores de Android 8+, de
# modo que el icono no cambia de forma al cruzar de API 25 a 26.
LEGACY_CORNER = 0.22

# Supermuestreo antes de reducir con LANCZOS. Con 8x el borde del arco del
# cuenco queda limpio incluso en el PNG de 48 px, que es el caso critico.
SUPERSAMPLE = 8

# Union de primitivas que forma el contorno exterior de la «P» y el ojo que se
# le resta. Comprobado contra el pathData: el subtrazo exterior es
# rect(33..58, 29..63) + semicirculo derecho de centro (58,46) r 17 +
# rect(33..44, 29..79); el ojo es rect(44..58, 40..52) + semicirculo r 6.
# Se usan las elipses completas porque su mitad izquierda cae dentro del
# rectangulo contiguo y no altera la silueta.
OUTER_RECTS = [
    (33.0, 29.0, 58.0, 63.0),  # cuenco, parte recta
    (33.0, 29.0, 44.0, 79.0),  # asta vertical
]
OUTER_ELLIPSES = [
    (41.0, 29.0, 75.0, 63.0),  # centro (58,46), r 17
]
HOLE_RECTS = [
    (44.0, 40.0, 58.0, 52.0),
]
HOLE_ELLIPSES = [
    (52.0, 40.0, 64.0, 52.0),  # centro (58,46), r 6
]

# Densidades de Android y el lado en px del icono legacy en cada una.
DENSITIES = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}

PLAY_ICON_SIDE = 512


def _to_px(value: float, side: int) -> float:
    """Pasa una coordenada del lienzo de 108 dp a px del PNG de lado `side`."""
    return (value - VISIBLE_OFFSET) * side / VISIBLE


def _glyph_mask(side: int) -> Image.Image:
    """Mascara en escala de grises con la «P» en blanco sobre negro."""
    mask = Image.new('L', (side, side), 0)
    draw = ImageDraw.Draw(mask)

    def box(rect: tuple[float, float, float, float]) -> list[float]:
        x0, y0, x1, y1 = rect
        return [_to_px(x0, side), _to_px(y0, side),
                _to_px(x1, side), _to_px(y1, side)]

    for rect in OUTER_RECTS:
        draw.rectangle(box(rect), fill=255)
    for ellipse in OUTER_ELLIPSES:
        draw.ellipse(box(ellipse), fill=255)
    # El ojo se resta pintando de negro sobre la mascara ya formada.
    for rect in HOLE_RECTS:
        draw.rectangle(box(rect), fill=0)
    for ellipse in HOLE_ELLIPSES:
        draw.ellipse(box(ellipse), fill=0)

    return mask


def _shape_mask(side: int, shape: str) -> Image.Image:
    """Mascara del contorno del icono: cuadrado, redondeado o circulo."""
    mask = Image.new('L', (side, side), 0)
    draw = ImageDraw.Draw(mask)
    if shape == 'square':
        draw.rectangle([0, 0, side - 1, side - 1], fill=255)
    elif shape == 'rounded':
        draw.rounded_rectangle(
            [0, 0, side - 1, side - 1],
            radius=side * LEGACY_CORNER,
            fill=255,
        )
    elif shape == 'circle':
        draw.ellipse([0, 0, side - 1, side - 1], fill=255)
    else:  # pragma: no cover - error de programacion
        raise ValueError(f'forma desconocida: {shape}')
    return mask


def render(side: int, shape: str) -> Image.Image:
    """Compone el icono final a `side` px con la forma exterior indicada."""
    big = side * SUPERSAMPLE

    icon = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    # Fondo de marca recortado por la forma exterior.
    icon.paste(Image.new('RGBA', (big, big), BRAND), (0, 0), _shape_mask(big, shape))
    # Glifo encima, recortado tambien por la forma exterior para que nunca
    # sobresalga si en el futuro se agranda la geometria.
    glyph = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    glyph.paste(Image.new('RGBA', (big, big), GLYPH), (0, 0), _glyph_mask(big))
    glyph.putalpha(Image.composite(
        glyph.getchannel('A'),
        Image.new('L', (big, big), 0),
        _shape_mask(big, shape),
    ))
    icon = Image.alpha_composite(icon, glyph)

    return icon.resize((side, side), Image.LANCZOS)


def main() -> int:
    root = pathlib.Path(__file__).resolve().parent.parent
    res = root / 'android' / 'app' / 'src' / 'main' / 'res'
    play = root / 'android' / 'play'
    play.mkdir(parents=True, exist_ok=True)

    written: list[str] = []

    for density, side in DENSITIES.items():
        folder = res / f'mipmap-{density}'
        folder.mkdir(parents=True, exist_ok=True)
        for name, shape in (('ic_launcher', 'rounded'),
                            ('ic_launcher_round', 'circle')):
            path = folder / f'{name}.png'
            render(side, shape).save(path, format='PNG', optimize=True)
            written.append(f'{path.relative_to(root)} ({side}x{side})')

    # La ficha de Play pide 512x512 PNG de 32 bits. Se entrega cuadrado y a
    # sangre: la Play Store aplica su propia mascara segun la superficie, de modo
    # que redondear aqui produciria esquinas dobles.
    play_path = play / 'icon-512.png'
    render(PLAY_ICON_SIDE, 'square').save(play_path, format='PNG', optimize=True)
    written.append(f'{play_path.relative_to(root)} ({PLAY_ICON_SIDE}x{PLAY_ICON_SIDE})')

    for line in written:
        print(line)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
