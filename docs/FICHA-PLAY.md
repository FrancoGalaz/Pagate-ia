# Ficha de Google Play — Págate-IA

Tarea **P-13**. Texto listo para pegar en *Play Console → Crecimiento → Ficha de
Play Store → Ficha principal*, en español de Chile, más la lista de recursos
gráficos que Play exige con sus dimensiones.

**Regla que gobierna todo este documento:** nada de lo que diga la ficha puede
ser algo que la app no haga. En particular, la app **no recibe pagos**, aunque el
onboarding hoy lo insinúe (`identity_step_screen.dart:111` dice «para que puedas
recibir pagos globalmente», que es falso y además arrastra la app hacia la
política de remesas de Play). Esa frase hay que borrarla del código antes de
publicar; aquí no aparece.

Límites verificados en la documentación oficial
([ficha de Play Store](https://support.google.com/googleplay/android-developer/answer/9866151),
consultada el 6 de octubre de 2026): nombre 30 caracteres, descripción breve 80,
descripción completa 4000.

---

## 1. Nombre de la aplicación (máx. 30)

**Opción elegida (24 caracteres):**

```
Págate-IA: tu valor hora
```

Por qué: deja el nombre de marca delante y la promesa concreta detrás, que es lo
que la gente busca («valor hora», «cuánto cobrar»). Play indexa el nombre con más
peso que cualquier otro campo.

Alternativas, si se prefiere otro ángulo:

| Nombre | Caracteres | Ángulo |
|---|---|---|
| `Págate-IA: tu valor hora` | 24 | Precio de la hora (elegida) |
| `Págate-IA: cuentas y precios` | 28 | Más amplio: gestión + precio |
| `Págate-IA` | 9 | Solo marca; desaprovecha la indexación |

---

## 2. Descripción breve (máx. 80)

**Opción elegida (70 caracteres):**

```
Calcula cuánto vale tu hora y ordena las cuentas de tu emprendimiento.
```

Alternativas:

| Texto | Caracteres |
|---|---|
| `Calcula cuánto vale tu hora y ordena las cuentas de tu emprendimiento.` | 70 |
| `Para artesanos: valor hora, precios, gastos e inventario en un solo lugar.` | 74 |
| `Deja de cobrar de menos. Calcula tu hora y lleva las cuentas del taller.` | 72 |

---

## 3. Descripción completa (máx. 4000)

Pegar tal cual. Play acepta un subconjunto de HTML en este campo; este texto está
en texto plano a propósito, que es lo que se ve bien en todos los dispositivos.

```
¿Sabes cuánto vale realmente una hora de tu trabajo?

Si vendes lo que haces con tus manos —cerámica, tejido, joyería, repostería,
carpintería, costura—, probablemente pusiste precio a tus productos mirando lo
que cobra el resto, o sumando los materiales y agregando «algo» por el trabajo.
Y ese «algo» casi nunca alcanza.

Págate-IA es una app simple para artesanos, emprendedores y talleres pequeños
que quieren saber tres cosas: cuánto vale su hora, cuánto entra y cuánto sale, y
si el mes cerró bien o mal.


CALCULA TU VALOR HORA

Dices cuánto quieres ganar al mes y cuántas horas puedes trabajar de verdad.
La app calcula lo que tiene que valer tu hora para que eso ocurra. Con ese
número, poner precio deja de ser una corazonada.


ORDENA TUS INGRESOS Y GASTOS

Anotas una venta o un gasto en segundos: cuánto, de qué y cuándo. La app arma
sola el resumen del mes, con lo que entró, lo que salió y el balance. También
puedes registrar tus gastos fijos para que no se te olviden al calcular.


LLEVA TU INVENTARIO

Productos y materiales en un mismo lugar, con precio, stock y stock mínimo. Si
quieres, anotas el proveedor y un código propio. Así sabes qué reponer antes de
quedarte sin material a mitad de un pedido.


PREGÚNTALE AL ASISTENTE

Págate-IA incluye un asistente con el que puedes conversar sobre tu negocio en
lenguaje normal: por qué te cuadra o no el mes, si un precio tiene sentido, en
qué se te está yendo la plata. Usa los datos que tú registraste, así que las
respuestas hablan de tu taller y no de un caso genérico.

Importante: las respuestas las genera un modelo de inteligencia artificial.
Pueden contener errores y son orientación informativa, no asesoría contable ni
tributaria. Para declarar impuestos o tomar una decisión grande, consulta a un
contador.


PENSADA PARA TRABAJO INDEPENDIENTE

No necesitas saber contabilidad. No hay planillas. No hay vocabulario de
empresa grande. Si vendes en ferias, por Instagram o por encargo, la app está
hecha para ese tamaño.


QUÉ NO HACE PÁGATE-IA

Lo decimos aquí para que no pierdas el tiempo descargándola si buscas otra cosa:

• No recibe pagos ni cobra a tus clientes. No es una billetera ni un medio de
  pago. Los montos que ves son los que tú anotas.
• No se conecta a tu banco. No lee tus movimientos reales.
• No emite boletas ni facturas ante el Servicio de Impuestos Internos.
• No es un software de contabilidad formal ni reemplaza a tu contador.


TUS DATOS

Tus números son tuyos. No vendemos tus datos, no hay publicidad dentro de la app
y no hay seguimiento publicitario. Cuando usas el asistente, parte del contexto
de tu negocio se envía al proveedor del modelo de lenguaje para poder
responderte; está explicado campo por campo en nuestra política de privacidad, y
el resto de la app funciona sin enviar nada. Puedes pedir que borremos tu cuenta
y todos tus datos cuando quieras.


Págate-IA está en desarrollo activo. Si echas en falta algo, escríbenos: lo que
viene después lo decidimos con lo que nos cuenten las personas que la usan.
```

### Palabras que la ficha tiene que contener, y por qué

Play no tiene campo de palabras clave: indexa el nombre, la descripción breve y
la descripción completa. Estas son las que la competencia usa en sus propias
fichas (ver `docs/COMPETENCIA.md`, donde están las fuentes) y que el texto de
arriba ya incluye de forma natural:

`valor hora` · `cuánto cobrar` · `precio` · `artesanos` · `emprendedores` ·
`emprendimiento` · `taller` · `ventas` · `gastos` · `ingresos` · `inventario` ·
`stock` · `materiales` · `ganancias` · `negocio` · `ferias` · `independiente`

Dos que la competencia usa y que **no** conviene meter, porque prometen lo que la
app no hace: `punto de venta` / `POS` y `boleta` / `factura electrónica`.

---

## 4. Recursos gráficos que Play exige

Fuente: [Ficha de Play Store — recursos gráficos](https://support.google.com/googleplay/android-developer/answer/9866151).

| Recurso | Dimensiones | Formato | Tamaño máx. | Cantidad | Estado |
|---|---|---|---|---|---|
| **Icono de la app** | 512 × 512 px | PNG de 32 bits con alfa | 1024 KB | 1, obligatorio | **Falta.** Hoy el icono de la app es, byte a byte, el logo por defecto de Flutter, y no hay icono adaptativo. Existe `landing/public/assets/brand/app-icon.png`, que puede servir de base. |
| **Gráfico de funciones** (*feature graphic*) | 1024 × 500 px | JPEG o PNG de 24 bits, sin alfa | — | 1, obligatorio | **Falta.** Es la imagen grande de cabecera de la ficha. |
| **Capturas de teléfono** | lado mínimo 320 px, máximo 3840 px; 16:9 o 9:16 | JPEG o PNG de 24 bits, sin alfa | 8 MB cada una | mínimo 2, hasta 8 | **Faltan.** Hay que tomarlas del rediseño terminado, no del estado actual. |
| **Capturas de tablet de 7″** | 1080–7680 px por lado; 16:9 horizontal o 9:16 vertical | JPEG o PNG de 24 bits | 8 MB | mínimo 4 | **Faltan.** |
| **Capturas de tablet de 10″** | 1080–7680 px por lado; 16:9 horizontal o 9:16 vertical | JPEG o PNG de 24 bits | 8 MB | mínimo 4 | **Faltan.** |
| **Vídeo de presentación** | URL de YouTube, pública o no listada, sin anuncios | — | — | opcional | No hay. Mejor no poner ninguno que poner uno malo. |

### Qué debe mostrar cada captura

Ocho capturas de teléfono, en este orden, con un titular corto encima de cada
una. Nada de cifras que la app no pueda producir:

1. **Inicio** con el balance del mes y los últimos movimientos. Titular: «Cómo
   va tu mes, de una mirada».
2. **Calculadora de valor hora**, con el resultado visible. Titular: «Cuánto
   tiene que valer tu hora».
3. **Registro de un movimiento**, el formulario abierto. Titular: «Anota una
   venta en segundos».
4. **Finanzas**, con la lista de movimientos del mes. Titular: «Todo lo que
   entró y salió».
5. **Gastos fijos**. Titular: «Lo que pagas todos los meses».
6. **Inventario**, con productos y materiales. Titular: «Qué tienes y qué te
   falta».
7. **Detalle de un ítem** con stock mínimo. Titular: «Reponé antes de quedarte
   sin material».
8. **Asistente**, con una conversación real corta. Titular: «Pregúntale sobre tu
   negocio». La captura debe mostrar el aviso de que las respuestas las genera
   una IA.

**Las capturas se toman con la cuenta de demostración** (ver §7), para que los
datos sean coherentes entre pantallas y no haya una pantalla con 15 movimientos y
la siguiente vacía.

---

## 5. Resto de campos de la ficha

| Campo | Valor | Nota |
|---|---|---|
| Categoría de la app | **Finanzas** | La app no cae bajo la política de Servicios Financieros de Play: no presta dinero, no transmite fondos, no opera con criptomonedas ni con instrumentos de inversión. Es gestión y orientación. |
| Etiquetas | `Finanzas personales`, `Presupuesto`, `Negocios` | Play permite hasta 5. |
| Correo electrónico de contacto | *(pendiente — ver abajo)* | Tiene que ser el mismo que `CONTACT.support` en `landing/src/content/legal-meta.ts`. |
| Sitio web | `https://francogalaz.github.io/Pagate-ia/landing-page/` | |
| Política de Privacidad | `https://francogalaz.github.io/Pagate-ia/landing-page/privacidad/` | Obligatoria. |
| Teléfono de contacto | Dejar vacío | Es opcional y publica el número. |
| Clasificación de contenido | Cuestionario IARC | Sin violencia, sexo, drogas, juego ni compras. Declarar que **sí** incluye IA generativa con contenido no filtrado por el desarrollador. |
| Anuncios | **No contiene anuncios** | Verificado: no hay ningún SDK de publicidad en `pubspec.yaml`. |
| Compras en la aplicación | **No** | Hoy no existe ninguna. En cuanto exista el plan Pro hay que cambiarlo y usar Google Play Billing: cobrarlo por fuera es causa de suspensión de la cuenta. |

### Pendiente de decisión del dueño

- **Correo de contacto de la ficha.** No existe ninguno operativo. El
  `soporte@pagate-ia.com` que muestra `ayuda_screen.dart:235` usa un dominio que
  el dueño no controla. Lo más barato es el correo de la cuenta de desarrollador.
- **Nombre público del desarrollador** que aparecerá bajo el nombre de la app.
- Si el nombre comercial lleva tilde y guion (`Págate-IA`) o se simplifica a
  `Pagate`. Hoy el repo usa las dos formas: la landing dice «Pagate» y la app
  «Págate-IA». Conviene unificarlas antes de publicar.

---

## 6. Prueba cerrada obligatoria antes de publicar

Si la cuenta de desarrollador es **personal y se creó después del 13 de
noviembre de 2023**, Play no da acceso a producción hasta haber corrido una
**prueba cerrada con un mínimo de 12 probadores inscritos de forma continua
durante 14 días**
([requisitos de prueba para cuentas personales nuevas](https://support.google.com/googleplay/android-developer/answer/14151465),
consultado el 6 de octubre de 2026). Los 14 días empiezan a contar cuando
Google aprueba la versión y hay 12 probadores dentro, no cuando se sube el AAB.
Las cuentas de organización y las personales anteriores a esa fecha están
exentas.

**Compruébalo en Play Console antes de comprometer cualquier fecha.** Si aplica,
hay que sumar al menos 14 días más el tiempo de reclutar a los 12, y esos 12
salen de la lista de espera (ver `docs/PLAN-PUBLICIDAD.md`).

---

## 7. Cuenta de demostración para el revisor

Play Console → *Contenido de la aplicación → Acceso a la app*. Hace falta,
porque un revisor que se registre solo llega a un dashboard vacío sin nada que
evaluar.

La cuenta debe venir precargada con: perfil completo, valor hora calculado, 15 a
20 transacciones repartidas en varios meses, 8 a 10 ítems de inventario con al
menos uno bajo el stock mínimo, y una conversación de chat.

**Nota para el revisor**, a pegar en el mismo formulario:

```
La app es una herramienta de registro y orientación financiera. No procesa
pagos, no se conecta a cuentas bancarias y no emite documentos tributarios.

El asistente de IA tiene un límite de 30 mensajes diarios en el plan gratuito.
El plan Pro aparece mencionado en la interfaz pero todavía no se puede comprar:
no hay compras dentro de la aplicación habilitadas.

En Android el único acceso es con correo y contraseña. El botón «Continuar con
Apple» no está implementado y el acceso con Google solo funciona en la versión
web.

Credenciales de la cuenta de demostración: (completar)
```

Los dos últimos párrafos describen limitaciones reales del código
(`welcome_screen.dart:250-253` y `google_auth_service.dart:20`). Decirlas evita
que el revisor las reporte como fallo.
