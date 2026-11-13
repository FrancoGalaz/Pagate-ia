"""Contraste WCAG de la paleta elegida, A · Greda y carbón (docs/diseno/variantes-cabal.html).

    python docs/diseno/contraste.py

Cada par lleva el mínimo que exige AA: 4,5 para texto normal, 3 para
componentes de UI (bordes, íconos sueltos). Los títulos se piden a 7 (AAA)
porque el color oscuro carga casi todo el texto de la app. Sale con 1 si
algún par no llega.

Regla que sale de aquí: el color de acción NUNCA va directo sobre la cabecera
oscura (da 2,7:1, bajo el 3:1 de componentes). Los botones de Inicio van dentro
de la tarjeta blanca superpuesta.

Roles de los montos: el ingreso va en verde; el gasto va en el oscuro con
signo «−» (no lleva color propio); el carmesí es solo para alertas (sin
stock) y acciones destructivas (Borrar).
"""

import colorsys
import sys

VARIANTES = {
    "A · Greda y carbón": dict(
        accion="B04A26", oscuro="2E2622", tinte="FBF6F2", texto2="6A5D55",
        apagado="756860", borde="8C7F77", sobreOscuro2="E8DCD3",
        ingreso="1D6B45", alerta="A3213F",
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


def mezcla(h, fraccion):
    """El color `h` al `fraccion` sobre blanco, como color-mix() del HTML."""
    c = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return "".join(f"{round(x * fraccion + 255 * (1 - fraccion)):02X}" for x in c)


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
        ("alerta sobre blanco (Sin stock, Borrar como texto)", v["alerta"], BLANCO, 4.5),
        ("alerta sobre tinte", v["alerta"], v["tinte"], 4.5),
        ("alerta sobre su chip (alerta al 10 %)", v["alerta"], mezcla(v["alerta"], 0.10), 4.5),
        ("blanco sobre alerta (botón destructivo)", BLANCO, v["alerta"], 4.5),
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
        f"  tonos: accion {tono(v['accion'])}, alerta {tono(v['alerta'])}, "
        f"ingreso {tono(v['ingreso'])}, oscuro {tono(v['oscuro'])} (grados)"
    )
sys.exit(1 if fallos else 0)
