"""Contraste WCAG de las dos variantes de paleta (docs/diseno/variantes-cabal.html).

    python docs/diseno/contraste.py

Cada par lleva el mínimo que exige AA: 4,5 para texto normal, 3 para
componentes de UI (bordes, íconos sueltos). Los títulos se piden a 7 (AAA)
porque el color oscuro carga casi todo el texto de la app. Sale con 1 si
algún par no llega.

Regla que sale de aquí: el color de acción NUNCA va directo sobre la cabecera
oscura (da 2,7:1 en A y 2,2:1 en B, bajo el 3:1 de componentes). Los botones
de Inicio van dentro de la tarjeta blanca superpuesta.
"""

import colorsys
import sys

VARIANTES = {
    "A · Greda y carbón": dict(
        accion="B04A26", oscuro="2E2622", tinte="FBF6F2", texto2="6A5D55",
        apagado="756860", borde="8C7F77", sobreOscuro2="E8DCD3",
        ingreso="1D6B45", gasto="A3213F",
    ),
    "B · Arcilla y monte": dict(
        accion="A8502E", oscuro="1F3B33", tinte="F5F8F5", texto2="56645D",
        apagado="65726B", borde="7D8A83", sobreOscuro2="D5E3DC",
        ingreso="17704C", gasto="A3213F",
    ),
}
BLANCO = "FFFFFF"


def luminancia(h):
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def contraste(a, b):
    la, lb = sorted((luminancia(a), luminancia(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def tono(h):
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return round(colorsys.rgb_to_hls(r, g, b)[0] * 360)


def pares(v):
    return [
        ("blanco sobre acción (texto del botón principal)", BLANCO, v["accion"], 4.5),
        ("acción como texto sobre blanco (enlaces)", v["accion"], BLANCO, 4.5),
        ("acción como texto sobre tinte", v["accion"], v["tinte"], 4.5),
        ("oscuro sobre blanco (títulos, íconos)", v["oscuro"], BLANCO, 7),
        ("oscuro sobre tinte", v["oscuro"], v["tinte"], 7),
        ("blanco sobre oscuro (cabecera, pestaña activa)", BLANCO, v["oscuro"], 7),
        ("texto secundario de la cabecera sobre oscuro", v["sobreOscuro2"], v["oscuro"], 4.5),
        ("texto secundario sobre blanco", v["texto2"], BLANCO, 4.5),
        ("texto secundario sobre tinte", v["texto2"], v["tinte"], 4.5),
        ("apagado (nav inactiva, placeholders) sobre blanco", v["apagado"], BLANCO, 4.5),
        ("apagado sobre tinte", v["apagado"], v["tinte"], 4.5),
        ("borde de campo sobre blanco (UI)", v["borde"], BLANCO, 3),
        ("ingreso sobre blanco", v["ingreso"], BLANCO, 4.5),
        ("ingreso sobre tinte", v["ingreso"], v["tinte"], 4.5),
        ("gasto sobre blanco", v["gasto"], BLANCO, 4.5),
        ("gasto sobre tinte", v["gasto"], v["tinte"], 4.5),
    ]


fallos = 0
for nombre, v in VARIANTES.items():
    print(f"== {nombre}")
    for desc, a, b, minimo in pares(v):
        r = contraste(a, b)
        ok = r >= minimo
        fallos += not ok
        print(f"  {'OK' if ok else 'NO'}  {r:5.2f}:1  (min {minimo})  {desc}")
    print(
        f"  tonos: accion {tono(v['accion'])}, gasto {tono(v['gasto'])}, "
        f"ingreso {tono(v['ingreso'])}, oscuro {tono(v['oscuro'])} (grados)"
    )
sys.exit(1 if fallos else 0)
