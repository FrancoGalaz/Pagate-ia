"""Lámina de revisión: todas las capturas de una carpeta en miniatura.

    python scripts/lamina.py capturas/<fecha>/<escala> capturas/<fecha>/lamina_<escala>.png

Solo usa la primera captura de cada pantalla (no los tramos `_p2`, `_p3`…),
ordenadas por su número, con el nombre debajo. Necesita Pillow.
"""

import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ANCHO, COLUMNAS, MARGEN, ROTULO = 270, 6, 16, 34

carpeta, salida = Path(sys.argv[1]), Path(sys.argv[2])
capturas = sorted(p for p in carpeta.glob("*.png") if not re.search(r"_p\d+$", p.stem))
if not capturas:
    sys.exit(f"No hay capturas en {carpeta}")

miniaturas = []
for p in capturas:
    img = Image.open(p).convert("RGB")
    miniaturas.append((p.stem, img.resize((ANCHO, round(img.height * ANCHO / img.width)))))

alto = max(m.height for _, m in miniaturas)
filas = -(-len(miniaturas) // COLUMNAS)
lamina = Image.new(
    "RGB",
    (COLUMNAS * (ANCHO + MARGEN) + MARGEN, filas * (alto + ROTULO + MARGEN) + MARGEN),
    "#d9dce1",
)
dibujo = ImageDraw.Draw(lamina)
try:
    fuente = ImageFont.truetype("arial.ttf", 16)
except OSError:
    fuente = ImageFont.load_default()

for i, (nombre, img) in enumerate(miniaturas):
    x = MARGEN + (i % COLUMNAS) * (ANCHO + MARGEN)
    y = MARGEN + (i // COLUMNAS) * (alto + ROTULO + MARGEN)
    lamina.paste(img, (x, y))
    dibujo.text((x, y + img.height + 6), nombre, fill="#1f2328", font=fuente)

salida.parent.mkdir(parents=True, exist_ok=True)
lamina.save(salida)
print(f"Lámina: {salida} ({len(miniaturas)} pantallas)")
