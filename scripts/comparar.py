"""Antes y después lado a lado, una lámina por escala de letra.

    python scripts/comparar.py capturas/<antes> capturas/<despues> salida.png [--solo-cambios]

Recorre las escalas (1.0, 1.5, 2.0) que existan en las dos carpetas y, por
cada pantalla (primera captura, sin los tramos `_p2`…), pone la de antes y la
de después juntas. Las pantallas se emparejan por nombre, no por número: si
se agrega una pantalla, la numeración cambia pero el par sigue. Con
`--solo-cambios` omite los pares idénticos (sin contar la barra de estado,
donde cambia la hora). Necesita Pillow.
"""

import re
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

ANCHO, MARGEN, ROTULO, PARES_POR_FILA = 220, 14, 30, 4
BARRA_DE_ESTADO = 70  # px de la captura donde solo cambia la hora


def pantallas(carpeta):
    """{nombre sin número: ruta} de la primera captura de cada pantalla."""
    salida = {}
    for p in sorted(carpeta.glob("*.png")):
        if re.search(r"_p\d+$", p.stem):
            continue
        salida[re.sub(r"^\d+_", "", p.stem)] = p
    return salida


def cambio(ruta_a, ruta_b):
    """True si las capturas difieren debajo de la barra de estado."""
    x, y = Image.open(ruta_a).convert("RGB"), Image.open(ruta_b).convert("RGB")
    if x.size != y.size:
        return True
    caja = ImageChops.difference(x, y).getbbox()
    return caja is not None and caja[3] > BARRA_DE_ESTADO


def miniatura(ruta):
    img = Image.open(ruta).convert("RGB")
    return img.resize((ANCHO, round(img.height * ANCHO / img.width)))


solo_cambios = "--solo-cambios" in sys.argv
args = [a for a in sys.argv[1:] if a != "--solo-cambios"]
antes, despues, destino = Path(args[0]), Path(args[1]), Path(args[2])
try:
    fuente = ImageFont.truetype("arial.ttf", 15)
except OSError:
    fuente = ImageFont.load_default()

for escala in ("1.0", "1.5", "2.0"):
    a, d = antes / escala, despues / escala
    if not (a.is_dir() and d.is_dir()):
        continue
    pa, pd = pantallas(a), pantallas(d)
    nombres = [n for n in pd if n in pa]
    if solo_cambios:
        nombres = [n for n in nombres if cambio(pa[n], pd[n])]
    if not nombres:
        continue
    pares = [(n, miniatura(pa[n]), miniatura(pd[n])) for n in nombres]
    alto = max(max(x.height, y.height) for _, x, y in pares)
    ancho_par = 2 * ANCHO + MARGEN
    filas = -(-len(pares) // PARES_POR_FILA)
    lamina = Image.new(
        "RGB",
        (PARES_POR_FILA * (ancho_par + 3 * MARGEN) + MARGEN,
         filas * (alto + 2 * ROTULO + MARGEN) + MARGEN),
        "#d9dce1",
    )
    dibujo = ImageDraw.Draw(lamina)
    for i, (nombre, x, y) in enumerate(pares):
        cx = MARGEN + (i % PARES_POR_FILA) * (ancho_par + 3 * MARGEN)
        cy = MARGEN + (i // PARES_POR_FILA) * (alto + 2 * ROTULO + MARGEN)
        dibujo.text((cx, cy), nombre, fill="#1f2328", font=fuente)
        lamina.paste(x, (cx, cy + ROTULO))
        lamina.paste(y, (cx + ANCHO + MARGEN, cy + ROTULO))
        dibujo.text((cx, cy + ROTULO + alto + 4), "antes", fill="#57534e", font=fuente)
        dibujo.text((cx + ANCHO + MARGEN, cy + ROTULO + alto + 4), "después", fill="#57534e", font=fuente)
    salida = destino.with_name(f"{destino.stem}_{escala}{destino.suffix}")
    salida.parent.mkdir(parents=True, exist_ok=True)
    lamina.save(salida)
    print(f"Comparación: {salida} ({len(pares)} pantallas)")
