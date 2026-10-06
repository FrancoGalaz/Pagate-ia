# android/play/

Recursos gráficos para la ficha de Google Play. **No entran en el build**: esta
carpeta está fuera de `android/app/src/`, así que nada de aquí se empaqueta en
el APK ni en el AAB. Vive junto al proyecto Android solo para que el icono de la
ficha y el del lanzador se mantengan juntos y no se desincronicen.

## Qué hay

| Archivo | Para qué | Estado |
|---|---|---|
| `icon-512.png` | Icono de la ficha, 512×512 PNG de 32 bits | **Listo.** Generado por `scripts/generate-android-icons.py` desde la misma geometría que el icono adaptativo, así que es idéntico al del lanzador. |

Se entrega **cuadrado y a sangre, sin esquinas redondeadas propias**: la Play
Store aplica su propia máscara según la superficie donde lo muestre, y
redondearlo aquí produciría esquinas dobles.

## Qué falta y por qué no está

Son decisiones de producto y de marketing, no de código. Quedan para el dueño:

| Recurso | Requisito de Play | Nota |
|---|---|---|
| Gráfico de función | 1024×500 PNG o JPEG | Es una pieza de marca con texto; no se inventa desde el repositorio. |
| Capturas de teléfono | Mínimo 2. Lado corto ≥ 320 px, lado largo ≤ 3840 px | Tomarlas con la cuenta de demostración sembrada (`scripts/seed-demo.js`), que es justamente para esto. |
| Descripción corta y larga | 80 y 4000 caracteres | |
| URL de política de privacidad | Obligatoria si la app pide cuenta | La página **ya está escrita** (`landing/privacidad/index.html`, junto con `landing/terminos/` y `landing/eliminar-cuenta/`), pero la build publicada en `landing-page/` todavía no la contiene, así que aún no hay URL que pegar en Play Console. Falta republicar la landing. |

El **nombre de la app** en la ficha tiene que escribirse igual que el del
lanzador: `Págate-IA`, con tilde. La fuente es
`android/app/src/main/res/values/strings.xml` (`app_name`), y ahí está el porqué.
Comprobado sobre el APK de release con `aapt2 dump badging`, que devuelve
`application-label:'Págate-IA'`.

## Si cambia el icono

El origen es `android/app/src/main/res/drawable/ic_launcher_foreground.xml` más
`values/ic_launcher_colors.xml`. Después de tocarlos hay que replicar la
geometría en `scripts/generate-android-icons.py` y volver a ejecutarlo; nada
sincroniza las dos copias automáticamente.
