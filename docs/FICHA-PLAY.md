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

**Índice.** §1 nombre · §2 descripción breve · **§3 el ángulo chileno y sus
fuentes** · §4 descripción completa · §5 recursos gráficos · §6 resto de campos ·
§7 prueba cerrada obligatoria · **§8 lo que tiene que rellenar el dueño** · §9
cuenta de demostración.

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
| `Ordena lo que vendes y lo que gastas, y calcula cuánto vale tu hora.` | 68 |

La última es la que mejor acompaña el ángulo del §3: pone «ordena» delante, que es
exactamente lo que la app hace, sin prometer nada tributario.

---

## 3. El ángulo chileno: por qué ahora, y con qué fuentes

Este apartado no es texto para pegar en Play: es la **base verificada** de la que
salen la descripción completa del §4 y la sección «Por qué ahora» de la landing
(`landing/src/components/ContextoChile.tsx`). Las fuentes se citan aquí, en el
documento; en la landing no, a propósito, porque una página de producto con pies
de página de circulares del SII asusta más de lo que informa.

**Lo que está verificado, con el enlace al lado.** Todo consultado el 6 de
octubre de 2026.

1. **La ley.** Ley N° 21.713, *de cumplimiento de las obligaciones
   tributarias*, con entrada en vigencia **escalonada**: cada medida tiene su
   propia fecha, y el propio SII las lista una por una
   ([SII — combate a la elusión, la evasión y la informalidad](https://www.sii.cl/destacados/ley_cumplimiento_obligaciones_tributarias/combate_elusion_evasion_informalidad.html)).

2. **El umbral de los abonos, con su cifra exacta.** Los bancos e instituciones
   financieras tienen que informar al SII el **número de abonos** que recibe un
   titular cuando, dentro de un mismo **día, semana o mes**, se superan **50
   abonos provenientes de 50 o más personas o entidades distintas**; o cuando en
   un **semestre** hay **al menos 100 abonos de 100 personas o entidades
   distintas**
   ([SII — información bancaria](https://www.sii.cl/destacados/ley_cumplimiento_obligaciones_tributarias/informacion_bancaria_tf.html);
   [Circular N° 2 del SII, de 2 de enero de 2025](https://www.sii.cl/normativa_legislacion/circulares/2025/circu2.pdf)).
   Se informa **semestralmente**, en julio y enero, y solo el **monto agregado**:
   la entidad no identifica a quién le transfirió a quién
   ([Gob.cl](https://www.gob.cl/noticias/transferencias-bancarias-ley-cumplimiento-tributario-funcionamiento-combatir-informalidad/),
   que lo resume así: «*Los bancos deberán informar al SII respecto de quienes
   reciban 50 o más transferencias de personas distintas dentro de un mismo día,
   semana o mes*»).

3. **No hay impuesto nuevo.** La misma fuente del Gobierno lo dice con esas
   palabras: «*las modificaciones contenidas en la nueva Ley no producen un
   incremento en la carga tributaria de los contribuyentes*». Esto es lo que
   impide que el texto de la landing sea alarmista: lo que cambió es la
   **información** que cruza el SII, no lo que se paga.

4. **Lo que de verdad aprieta al artesano que vende por Instagram.** Desde el
   **1 de octubre de 2025**, las **plataformas digitales de intermediación** y
   los **administradores, operadores o proveedores de medios de pago
   electrónico** están obligados a **exigir la acreditación del inicio de
   actividades** antes de autorizar una actividad económica o intermediar una
   operación
   ([SII, 16 de septiembre de 2025](https://www.sii.cl/noticias/2025/160925noti01pcr.htm);
   [circular que regula la obligación, SII, 30 de abril de 2025](https://www.sii.cl/noticias/2025/300425noti02srm.htm)).
   Es el hecho más concreto de los cuatro: toca el trámite, no la declaración.

### Una corrección al dato de partida, para que nadie la repita

El encargo de este carril daba por sentado que «la Ley de Cumplimiento
Tributario entró en vigor el **2 de enero de 2026**». **No pude verificarlo en
ninguna fuente oficial, y la evidencia apunta a otra fecha.** Lo que sí está
documentado: la circular que regula el reporte de abonos es la **Circular N° 2
de 2 de enero de 2025** —el día y el mes coinciden, el año no—, su extracto se
publicó en el Diario Oficial el **8 de enero de 2025**, y el primer envío de
información al SII fue en **julio de 2025**. La fecha de 2026 aparece en blogs de
software contable, no en el SII ni en Gob.cl.

**Consecuencia práctica:** no escribir «entró en vigor el 2 de enero de 2026» en
ningún texto público. El gancho no necesita esa fecha: los dos hechos de los
puntos 2 y 4 son vigentes hoy y son más concretos.

### Las comisiones de los medios de pago (contexto del contrato C-3)

El contrato C-3 añade un campo `platformFee` a las transacciones. Estado de la
verificación de las cifras que se suelen citar:

| Medio de pago | Comisión | Verificación |
|---|---|---|
| **Khipu** (transferencia) | **0,69 % + IVA**, o **UF 0,0105 + IVA** por transacción | **Verificado** en su propia página de tarifas: <https://www.khipu.com/page/tarifas-instantaneos-chile> |
| **Mercado Pago** (link de pago) | Las cifras que circulan para 2026 son 3,19 % + IVA con dinero al instante y 2,89 % + IVA a 10 días | **NO verificado.** Su página de costos (<https://www.mercadopago.cl/costs-section/cost-sales>) se renderiza con JavaScript y devuelve 403 a un lector de texto. **Hay que comprobarlo en la propia página antes de usar el número en cualquier texto público o en un valor por defecto del código.** |

**Y el límite que esto no cruza:** el campo guarda la comisión que el usuario
anota, y el neto se deriva como `amount - platformFee`. La app **no** elige la
comisión por él, **no** la calcula a partir del medio de pago y **no** calcula
impuestos. Rellenar por defecto un «3,19 %» sería inventarle un dato al usuario.

---

## 4. Descripción completa (máx. 4000)

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


PENSADA PARA CHILE

Si eliges pesos chilenos, los montos se ven con los miles separados por punto y
sin decimales, como se escriben acá. Y hay una razón práctica detrás: en Chile
los bancos ya informan al Servicio de Impuestos Internos cuántos abonos recibe
una cuenta cuando pasa de 50 transferencias de 50 personas distintas en un mes, y
las plataformas de pago piden inicio de actividades para intermediar un cobro. Si
vendes por Instagram y te pagan por transferencia, conviene tener a mano y
ordenado lo que vendiste y lo que gastaste.

Págate-IA no declara impuestos, no emite boletas y no te dice qué hacer con el
SII: eso lo ve tu contador. Lo que hace es que, cuando te lo pregunten, la
respuesta ya esté escrita.


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

## 5. Recursos gráficos que Play exige

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

**Las capturas se toman con la cuenta de demostración** (ver §9), para que los
datos sean coherentes entre pantallas y no haya una pantalla con 15 movimientos y
la siguiente vacía.

---

## 6. Resto de campos de la ficha

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

El inventario completo, con archivo y número de línea, está en el **§8**. En
resumen: el correo de contacto de la ficha, el nombre público del desarrollador y
los cuatro datos de identificación del responsable.

---

## 7. Prueba cerrada obligatoria antes de publicar

**Requisito verificado en la documentación oficial de Google**, consultada el 6
de octubre de 2026:
[*Requisitos de prueba para las cuentas de desarrollador personales nuevas*](https://support.google.com/googleplay/android-developer/answer/14151465).

Lo que dice esa página, en sus propios términos:

- Va dirigida a **desarrolladores con cuentas personales de Google Play Console
  creadas después del 13 de noviembre de 2023**.
- Esas cuentas tienen que **«ejecutar una prueba cerrada de su app con un mínimo
  de 12 probadores que hayan aceptado participar de forma continua durante al
  menos 14 días»**.
- Hasta cumplirlo, **«algunas funciones de Play Console, como Producción y
  Registro previo, permanecerán inhabilitadas»**.
- Cumplido el requisito, **«puedes solicitar acceso a producción en el Panel de
  Play Console»**. No es automático: hay que pedirlo y Google lo revisa.

Tres detalles que la página implica y que conviene tener claros:

1. **Son 14 días de calendario, continuos y los más recientes.** Si en algún
   momento el número de probadores inscritos baja de 12, la cuenta de días
   empieza otra vez. No se acumulan tramos.
2. **Inscribirse no basta.** Los probadores tienen que instalar y usar la app;
   si no, la solicitud de acceso a producción se puede rechazar por falta de
   participación.
3. **Las cuentas de organización están exentas**, igual que las personales
   creadas antes del 13 de noviembre de 2023.

**Compruébalo en Play Console antes de comprometer cualquier fecha**, porque de
esto depende el calendario entero. Si aplica, hay que sumar **al menos 14 días**
al plan, más el tiempo de reclutar a los 12 —conviene invitar a 18 o 20 para
tener margen cuando alguno se desinstale—, y esos probadores salen de la lista de
espera (ver `docs/PLAN-PUBLICIDAD.md` §0 y §4, Semana 6).

---

## 8. LO QUE TIENE QUE RELLENAR EL DUEÑO, Y DÓNDE

> **Esto es lo primero que bloquea la publicación.** Cinco datos, un solo
> archivo, cinco líneas. Nadie puede decidirlos en su lugar y no se pueden
> inventar: van en una política de privacidad y en unos términos de servicio.

### 8.1 Los cinco datos

Todos viven en **`landing/src/content/legal-meta.ts`**. Se editan ahí y aparecen
solos en las tres páginas legales.

| # | Línea | Constante | Qué hay que decidir |
|---|---|---|---|
| 1 | **28** | `RESPONSIBLE.legalName` | Nombre completo (persona natural) o razón social (sociedad). Es la misma decisión que fija los puntos 2 y 3. |
| 2 | **29** | `RESPONSIBLE.taxId` | El RUT que corresponda a la decisión del punto 1. |
| 3 | **30** | `RESPONSIBLE.address` | Domicilio para notificaciones: calle, número, comuna, región. |
| 4 | **42** | `CONTACT.privacy` | Buzón **atendido** para privacidad y solicitudes de borrado. Es el que recibe las peticiones de eliminación de cuenta. |
| 5 | **43** | `CONTACT.support` | Correo de soporte. **Tiene que ser el mismo** que se declare en Play Console → Ficha principal → Correo electrónico de contacto. |

**El `soporte@pagate-ia.com` que muestra la app no vale**: usa un dominio que el
dueño no controla (verificado en `docs/AUDITORIA-2026-09-29.md`). Lo más barato y
lo más rápido es usar el correo de la cuenta de desarrollador de Google Play.

### 8.2 Qué pasa mientras falten

Las páginas legales **ya no imprimen los corchetes**. Una política publicada con
`[RAZÓN SOCIAL…]` a la vista es motivo de rechazo en Play, así que cada página
tiene dos redacciones y elige la que corresponde al estado real del dato
(`esMarcador()` en `legal-meta.ts`):

- Donde iría el nombre y el RUT, el visitante lee «*el titular de la cuenta de
  desarrollador con la que se publica Págate-IA en Google Play, con domicilio en
  Chile*», y que esos datos se publicarán en esa misma página.
- Donde iría el correo, lee «*la dirección de contacto del desarrollador que
  aparece en la ficha de Págate-IA en Google Play*», que es un canal que existe
  siempre porque Play obliga a publicarlo.
- El botón `mailto:` de la página de eliminación de cuenta **no se renderiza**
  mientras no haya buzón: un `mailto:[CORREO…]` es un enlace roto, y eso es peor
  que no ofrecer el botón.
- Las tres páginas muestran, bajo el título, un aviso sobrio que enumera qué
  datos faltan. **En cuanto se rellenen los cinco, el aviso desaparece solo**:
  no hay que tocar ningún otro archivo.

Tres tests lo vigilan y fallan si alguien reintroduce un corchete en lo que se
renderiza: `landing/src/pages/legal.test.tsx` («ninguna página muestra un
marcador entre corchetes» y «ningún enlace mailto apunta a un destinatario con
corchetes») y `landing/src/honestidad.test.ts` («ningún texto renderizado deja un
marcador entre corchetes»).

**Que no haya corchetes no significa que el documento esté listo.** Sin los
cinco datos, la política identifica al responsable por descripción y no por
nombre, y eso es un riesgo de revisión que solo se cierra rellenándolos.

### 8.3 Decisiones que no están en ese archivo

| Decisión | Dónde se refleja |
|---|---|
| **Nombre público del desarrollador** bajo el nombre de la app | Play Console → Configuración de la cuenta de desarrollador |
| **Correo de contacto de la ficha** | Play Console → Ficha principal. Igual al punto 5 del §8.1 |
| **Nombre comercial: `Págate-IA` o `Pagate`** | Ya unificado a `Págate-IA` en toda la landing y en la ficha (§1), porque es el nombre que usa la app y el que llevan las páginas legales. Si el dueño prefiere `Pagate`, hay que cambiarlo en los dos sitios a la vez, no en uno |
| **Tipo de cuenta de desarrollador** (personal o de organización) | Determina si aplica la prueba cerrada del §7. **Hay que comprobarlo antes de comprometer cualquier fecha** |

### 8.4 Fecha de los documentos legales

`LEGAL_VERSION` (líneas 52-53 del mismo archivo) dice «versión 1.0, 6 de octubre
de 2026». Está escrita a mano a propósito: un documento legal no puede cambiar su
fecha de vigencia cada vez que se recompila la landing. **Si se rellenan los
cinco datos, hay que subir la versión y la fecha en el mismo commit.**

---

## 9. Cuenta de demostración para el revisor

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

El asistente de IA tiene un límite de 25 mensajes EN TOTAL (de por vida, no
diarios) en el plan gratuito. El plan Pro aparece mencionado en la interfaz pero
todavía no se puede comprar: no hay compras dentro de la aplicación habilitadas.
Si la cuenta de demostración agota sus 25 mensajes, el asistente deja de
responder; por eso la cuenta se entrega con la conversación ya cargada y con
mensajes sin gastar.

En Android el único acceso es con correo y contraseña. El botón «Continuar con
Apple» no está implementado y el acceso con Google solo funciona en la versión
web.

Credenciales de la cuenta de demostración: (completar)
```

Los dos últimos párrafos describen limitaciones reales del código
(`welcome_screen.dart:250-253` y `google_auth_service.dart:20`). Decirlas evita
que el revisor las reporte como fallo.
