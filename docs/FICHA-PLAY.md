# Ficha de Google Play — Págate-IA

Tarea **P-13**. Texto listo para pegar en *Play Console → Crecimiento → Ficha de
Play Store → Ficha principal*, en español de Chile, más la lista de recursos
gráficos que Play exige con sus dimensiones.

**Regla que gobierna todo este documento:** nada de lo que diga la ficha puede
ser algo que la app no haga. La app **no recibe pagos**, y el onboarding ya no lo
insinúa: la frase «para que puedas recibir pagos globalmente» —que era falsa y
arrastraba la app hacia la política de remesas de Play— está borrada de
`identity_step_screen.dart`, donde hoy solo queda el comentario que explica por
qué se fue.

**Índice.** **§0 lo que solo puede hacer el dueño (la lista cerrada)** · **§0 bis
publicar la landing** · §1 nombre · §2 descripción breve · **§3 el ángulo chileno
y sus fuentes** · §4 descripción completa · §5 recursos gráficos · §6 resto de
campos · §7 prueba cerrada obligatoria · **§8 los cinco datos legales, línea por
línea** · §9 cuenta de demostración.

Límites verificados en la documentación oficial
([ficha de Play Store](https://support.google.com/googleplay/android-developer/answer/9866151),
consultada el 6 de octubre de 2026): nombre 30 caracteres, descripción breve 80,
descripción completa 4000.

---

## 0. LO QUE SOLO PUEDE HACER EL DUEÑO

> **Ocho cosas. Esta lista es cerrada: no falta nada más que no sea código.**
> Ninguna la puede hacer un agente, ninguna se puede inventar y mientras falte
> cualquiera de las siete primeras no hay nada que subir a Google Play.
>
> **Las tres primeras son nuevas en esta revisión, y son las gordas: el proyecto
> de producción `pagate-17211` está vacío.** No es una sospecha, está comprobado
> hoy, 6 de octubre de 2026, contra las APIs reales (las respuestas literales
> están en el §0.0). La app compila, los tests pasan y el emulador funciona,
> pero una app instalada desde Play no podría ni registrar a nadie.

| # | Qué falta | Dónde se hace | Qué pasa si falta |
|---|---|---|---|
| **1** | **Encender Authentication** y elegir el proveedor *Correo electrónico/contraseña* | Consola de Firebase → *Authentication* → **Comenzar** → *Sign-in method* → habilitar **Correo electrónico/contraseña**. (Google, si se quiere la web, en la misma pantalla) | **Comprobado: no está encendido.** Identity Toolkit responde `CONFIGURATION_NOT_FOUND` al proyecto. En producción nadie puede registrarse ni entrar: la app se queda en la pantalla de bienvenida para todo el mundo, incluido el revisor de Play |
| **2** | **Crear la base de datos de Firestore** | Consola de Firebase → *Firestore Database* → **Crear base de datos** → modo producción → región **`southamerica-west1`** (la misma que las funciones, `functions/src/config.ts`) | **Comprobado: no existe.** La API responde `SERVICE_DISABLED` («*Cloud Firestore API has not been used in project pagate-17211 before or it is disabled*»). Sin esto no hay dónde guardar nada, y el paso 3 ni se puede intentar |
| **3** | **Desplegar reglas y funciones** | En el equipo del dueño, con el árbol limpio: `APP_CHECK_SITE_KEY=... ./scripts/deploy-web.sh` (hosting + `firestore.rules` + functions). Requiere antes el **plan Blaze** y el secreto `OPENROUTER_API_KEY` (checklist del README) | **Comprobado: no hay nada desplegado.** `https://southamerica-west1-pagate-17211.cloudfunctions.net/waitlist` responde **404** y `https://pagate-17211.web.app/` responde **404**. Sin funciones no hay asistente, no hay agregados mensuales y **no hay borrado de cuenta** —que Play exige—; sin reglas desplegadas, Firestore queda con las de por defecto |
| **4** | **Publicar la landing**, para que respondan las tres URLs legales | Un solo gesto, detallado en el **§0 bis** | **Comprobado hoy:** la portada responde `200` y `privacidad/`, `terminos/` y `eliminar-cuenta/` responden **`404`**. Play **exige** que la URL de política de privacidad responda, así que esto bloquea la ficha antes incluso de poder guardarla |
| **5** | **Los cinco datos de identidad legal**: nombre completo o razón social, RUT, domicilio para notificaciones, correo de privacidad y correo de soporte | `landing/src/content/legal-meta.ts`, líneas **28, 29, 30, 42 y 43**. El detalle, dato por dato, en el **§8.1** | **Comprobado: los cinco siguen con marcador.** La política de privacidad y los términos identifican al responsable «por descripción» y no por nombre: riesgo de revisión en Play y documento legal cojo |
| **6** | **El correo de soporte real** —es el quinto del punto anterior, pero además hay que **declararlo en Play** | El mismo archivo (línea **43**) **y** Play Console → *Crecimiento → Ficha de Play Store → Ficha principal → Correo electrónico de contacto*. **Tienen que ser el mismo** | Play exige un correo de contacto en la ficha, y es el canal al que llegan las solicitudes de borrado de quien ya no tiene la app instalada. Lo más barato y rápido es el correo de la cuenta de desarrollador de Google Play |
| **7** | **La clave de subida real** (*upload keystore*) | Se genera en el equipo del dueño con `keytool` y se declara en `android/key.properties`. Receta exacta en el **§0.1** | **Comprobado: `android/key.properties` no existe** (solo está `key.properties.example`). Sin él, el build de release se firma con el keystore de **depuración** y Play lo rechaza: *«You uploaded an APK or Android App Bundle that was signed in debug mode»*. `android/app/build.gradle.kts` lo avisa a gritos al compilar |
| **8** | **El formulario de Seguridad de los datos** | Play Console → *Política → Contenido de la aplicación → Seguridad de los datos* | Obligatorio para publicar. Las respuestas ya están decididas y razonadas, una por una, en **`docs/SEGURIDAD-DATOS-PLAY.md`**. Necesita la URL de privacidad del punto 4 |

**Y una novena que puede no aplicar: los 12 probadores durante 14 días.** Va
aparte porque es la única que depende de un dato que solo el dueño puede mirar.

| Condición | Dónde se comprueba | Si aplica |
|---|---|---|
| Que la cuenta de Play sea **personal** y se haya creado **después del 13 de noviembre de 2023** | Play Console → *Configuración → Detalles de la cuenta de desarrollador* | Hay que correr una **prueba cerrada con 12 probadores inscritos de forma continua durante 14 días** (Play Console → *Probar y publicar → Pruebas → Prueba cerrada*) y luego **solicitar** el acceso a producción. Hasta cumplirlo, *Producción* está **inhabilitada**: no es que la revisión salga mal, es que el botón no existe. Las citas de la documentación oficial, en el **§7** |

Las cuentas de **organización**, y las personales creadas **antes** de esa
fecha, están exentas. **Compruébalo antes de comprometer cualquier fecha**, porque
si aplica son 14 días de calendario que no se pueden comprimir.

### 0.0 Cómo se comprobó el estado del proyecto de producción

No hace falta acceso a la consola para saber si Authentication y Firestore están
encendidos: las dos APIs lo dicen. Estos cuatro comandos son los que dieron los
resultados de la tabla, y sirven para volver a comprobarlo **después** de
hacerlo, que es lo que importa.

```sh
# Clave web pública del proyecto (lib/firebase_options.dart).
KEY=AIzaSyDNtdgCov0WpdZnyUhhdDHp1yewnHdr-vA

# 1. ¿Authentication encendido con correo/contraseña?
curl -s -X POST \
  "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$KEY" \
  -H 'Content-Type: application/json' \
  -d '{"email":"sonda@pagate.invalid","password":"x1234567","returnSecureToken":true}'

# 2. ¿Existe la base de datos de Firestore?
curl -s "https://firestore.googleapis.com/v1/projects/pagate-17211/databases/(default)/documents/users/sonda?key=$KEY"

# 3. ¿Están desplegadas las funciones?
curl -s -o /dev/null -w '%{http_code}\n' \
  "https://southamerica-west1-pagate-17211.cloudfunctions.net/waitlist"

# 4. ¿Hay algo en Hosting?
curl -s -o /dev/null -w '%{http_code}\n' "https://pagate-17211.web.app/"
```

Lo que respondieron el 6 de octubre de 2026, y cómo se lee cada respuesta:

| # | Respuesta literal | Qué significa |
|---|---|---|
| 1 | `"message": "CONFIGURATION_NOT_FOUND"` | Authentication **nunca se inicializó** en el proyecto. No es «la contraseña está mal» ni «ese correo no existe» (que serían `INVALID_LOGIN_CREDENTIALS` o `EMAIL_NOT_FOUND`): es que no hay configuración de autenticación que consultar |
| 2 | `"status": "PERMISSION_DENIED"` con `"reason": "SERVICE_DISABLED"` y el texto *«Cloud Firestore API has not been used in project pagate-17211 before or it is disabled»* | La base de datos **no está creada**. Si existiera y las reglas rechazaran la lectura, el 403 vendría de `firestore.rules` y el mensaje citaría la regla, como pasa en el emulador |
| 3 | `404` | La función `waitlist` **no está desplegada**. Una función desplegada responde `405` al `GET` (solo acepta `POST`), no `404` |
| 4 | `404` | **Hosting vacío**. Nunca se ha subido el build web |

**Qué NO prueban estas sondas:** si el plan Blaze está activo, si el secreto
`OPENROUTER_API_KEY` existe o si App Check está registrado. Eso está en el
*Checklist de configuración en consola* del `README.md`, y hay que recorrerlo
igual: el paso 3 de la tabla no se puede completar sin Blaze ni sin el secreto.

**Tres decisiones más que son suyas y no bloquean**, pero conviene tomarlas
antes de escribir la ficha: el nombre público del desarrollador, el nombre
comercial (`Págate-IA` o `Pagate`, ya unificado a `Págate-IA`) y si alguna vez
habrá plan Pro. Están en el **§8.3** y en `docs/PLAN-PUBLICIDAD.md` §7.

### 0.1 La clave de subida, paso a paso

El proyecto ya está preparado: `android/app/build.gradle.kts` lee
`android/key.properties` si existe y, si no, firma con el keystore de
depuración **avisando por consola**. Lo único que falta es el archivo.

```sh
# 1. Generar el keystore. FUERA del repositorio.
keytool -genkeypair -v   -keystore C:/Users/Franco/claves/pagate-upload.jks   -storetype JKS -keyalg RSA -keysize 2048 -validity 10000   -alias upload   -dname "CN=Pagate, OU=Desarrollo, O=Pagate, L=Santiago, ST=RM, C=CL"
```

```properties
# 2. Crear android/key.properties con estas cuatro líneas.
#    NO se versiona: android/.gitignore ya excluye key.properties, *.jks,
#    *.keystore, *.aab y *.apk.
storeFile=C:/Users/Franco/claves/pagate-upload.jks
storePassword=<la que pusiste en el paso 1>
keyAlias=upload
keyPassword=<la de la clave, normalmente la misma>
```

```sh
# 3. Generar el artefacto que se sube a Play.
flutter build appbundle --release   --dart-define=PAGATE_ENV=prod   --dart-define=APP_CHECK_SITE_KEY=<la clave de reCAPTCHA v3>
```

**Respalda el `.jks` y las contraseñas.** Si se pierde la clave de subida, Play
la puede reiniciar, pero **solo** si la app usa Play App Signing. Y ojo con la
huella: la SHA-256 que hay que registrar en App Check / Play Integrity es la del
**certificado de firma de la app** (Play Console → *Probar y publicar →
Integridad de la app*), no la de este keystore de subida.

---

## 0 bis. PUBLICAR LA LANDING: UN SOLO GESTO

> **Por qué va aquí y no en un documento de la web:** sin esto no hay URL de
> política de privacidad, y sin esa URL Play no acepta la ficha. Es el **punto 4
> del §0**.

### Qué hay hecho y qué falta

Hecho: `landing/` tiene las tres páginas legales y `landing-page/` —la carpeta
que sirve GitHub Pages— ya está reconstruida con ellas **en la rama
`arquitectura-segura`**. Falta: que ese contenido llegue a **`main`**, que es la
rama que GitHub Pages publica.

Comprobado hoy, 6 de octubre de 2026, con `curl`:

| URL | Hoy |
|---|---|
| `https://francogalaz.github.io/Pagate-ia/landing-page/` | **200** |
| `https://francogalaz.github.io/Pagate-ia/landing-page/privacidad/` | **404** |
| `https://francogalaz.github.io/Pagate-ia/landing-page/terminos/` | **404** |
| `https://francogalaz.github.io/Pagate-ia/landing-page/eliminar-cuenta/` | **404** |

Que la portada responda `200` demuestra que Pages ya está configurado y
sirviendo `landing-page/` desde `main`: no hay nada que configurar, solo que
llegue el contenido.

### El gesto

```sh
# Desde el repositorio principal, con el árbol limpio.
git checkout main
git merge arquitectura-segura      # o la rama que lleve la landing al día
git push origin main
```

Eso dispara `.github/workflows/landing-pages.yml`, que corre con `landing/**` y
hace, por su cuenta: `npm ci`, `npm run lint`, `npm test`, `npm run build`,
copia `landing/dist/` a `landing-page/` y commitea el resultado con `[skip ci]`.
Si la build falla, **no publica nada**: es la red de seguridad, no un trámite.

**Si no se quiere fusionar la rama entera** (lleva app, backend y reglas), vale
igual con llevar solo la landing, porque el filtro del workflow es por rutas:

```sh
git checkout main
git checkout arquitectura-segura -- landing landing-page
git commit -m "landing: publica las tres páginas legales"
git push origin main
```

### Cómo se comprueba, dos minutos después

1. En GitHub, pestaña **Actions**, el workflow **«Landing Pages»** tiene que
   terminar en verde. Si falla en `lint` o `test`, no se publicó nada y hay que
   arreglar eso primero.
2. Esperar a que Pages termine de desplegar (suele tardar de uno a tres minutos
   más que el workflow) y pedir las cuatro URLs:

```sh
for u in "" privacidad/ terminos/ eliminar-cuenta/; do
  printf "%-16s " "${u:-portada}"
  curl -s -o /dev/null -w "%{http_code}" \
    "https://francogalaz.github.io/Pagate-ia/landing-page/$u"
  echo
done
```

   **Las cuatro tienen que responder `200`.** Un `404` en `privacidad/` es el
   que bloquea la ficha; los otros dos dejan sin destino los términos y el
   enlace público de eliminación de cuenta, que Play exige a toda app que
   permita crear una cuenta (el detalle, con los archivos que lo sostienen, en
   `docs/SEGURIDAD-DATOS-PLAY.md` §4.2).

3. Abrir `…/privacidad/` en el teléfono y comprobar dos cosas a ojo: que **no
   se ve ningún `[MARCADOR]` entre corchetes** y que el aviso de datos
   pendientes corresponde a lo que todavía falta del §0. Cuando se rellenen los
   cinco datos, ese aviso desaparece solo.

4. Pegar la URL de `…/privacidad/` en Play Console → *Ficha principal →
   Política de Privacidad* y en *Contenido de la aplicación → Seguridad de los
   datos*. Son dos sitios distintos y los dos la piden.

**Lo que no hay que hacer:** subir `landing-page/` a mano desde el equipo. El
workflow la reconstruye desde `landing/` en cada push, así que un cambio hecho
solo en la carpeta publicada se pierde en la siguiente publicación.

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
| **Mercado Pago** (link de pago) | Las cifras que circulan para 2026 son 3,19 % + IVA con dinero al instante y 2,89 % + IVA a 10 días | **NO verificado, y hoy tampoco se puede.** Vuelto a comprobar el 6 de octubre de 2026: <https://www.mercadopago.cl/costs-section/cost-sales> responde **302** y redirige a `mercadopago.cl/login/identification`, o sea que la tarifa está detrás de la sesión. **Solo el dueño, con una cuenta de Mercado Pago, puede leer el número.** Hasta entonces no se escribe en ningún texto público ni en ningún valor por defecto del código. |

**Y el límite que esto no cruza:** el campo guarda la comisión que el usuario
anota, y el neto se deriva como `amount - platformFee`. La app **no** elige la
comisión por él, **no** la calcula a partir del medio de pago y **no** calcula
impuestos. Rellenar por defecto un «3,19 %» sería inventarle un dato al usuario.

---

## 4. Descripción completa (máx. 4000)

Pegar tal cual. Play acepta un subconjunto de HTML en este campo; este texto está
en texto plano a propósito, que es lo que se ve bien en todos los dispositivos.

**3.931 caracteres de los 4.000**, contados sobre el bloque de abajo. Quedan 69
de margen: si hay que añadir una línea, hay que quitar otra, y el recuento se
hace de verdad y no a ojo. Para volver a contarlo, copiar el bloque a un archivo
y pedir su longitud en caracteres —no en bytes, que con las tildes no es lo
mismo—:

````sh
python -c "print(len(open('descripcion.txt', encoding='utf-8').read().strip()))"
````

```
¿Sabes cuánto vale realmente una hora de tu trabajo?

Si vendes lo que haces con tus manos —cerámica, tejido, joyería, repostería,
carpintería, costura—, probablemente pusiste precio mirando lo que cobra el
resto, o sumando los materiales y agregando «algo» por el trabajo. Y ese «algo»
casi nunca alcanza.

Págate-IA es una app simple para artesanos, emprendedores y talleres pequeños
que quieren saber tres cosas: cuánto cobrar por su hora, cuánto entra y cuánto
sale, y si el mes cerró bien o mal.


CALCULA TU VALOR HORA

Dices cuánto quieres ganar al mes y cuántas horas puedes trabajar de verdad.
La app calcula lo que tiene que valer tu hora para que eso ocurra. Con ese
número, poner precio deja de ser una corazonada.

Y al cerrar el mes te muestra dos cifras, con su nombre exacto: lo que te entró
por hora y lo que te sobró por hora una vez pagados los gastos. No son lo mismo,
y la diferencia suele sorprender.


ORDENA TUS INGRESOS Y GASTOS

Anotas una venta o un gasto en segundos: cuánto, de qué y cuándo. La app arma
sola el resumen del mes, con lo que entró, lo que salió y el balance. Y tus
gastos fijos, para que no se te olviden al calcular.


PENSADA PARA CHILE

Si eliges pesos chilenos, los montos se ven con los miles separados por punto y
sin decimales, como se escriben acá. En cada venta puedes anotar con qué la
respaldaste —boleta de venta, boleta de honorarios o nada— y cuánto se quedó el
medio de pago.

Y hay una razón práctica: en Chile los bancos ya informan al Servicio de
Impuestos Internos cuántos abonos recibe una cuenta que pasa de 50
transferencias de 50 personas distintas en un mes, y las plataformas de pago
piden inicio de actividades para intermediar un cobro.

Págate-IA no declara impuestos, no emite boletas y no te dice qué hacer con el
SII: eso lo ve tu contador. Lo que hace es que, cuando te lo pregunten, la
respuesta ya esté escrita.


LLEVA TU INVENTARIO

Productos y materiales en un mismo lugar, con precio, stock y stock mínimo, y si
quieres el proveedor y un código propio. Así sabes qué reponer antes de quedarte
sin material a mitad de un pedido.


PREGÚNTALE AL ASISTENTE

Un asistente con el que puedes conversar sobre tu negocio en lenguaje normal:
por qué te cuadra o no el mes, si un precio tiene sentido, en qué se te está
yendo la plata. Usa los datos que tú registraste, así que habla de tu taller y
no de un caso genérico.

Importante: las respuestas las genera un modelo de inteligencia artificial.
Pueden contener errores y son orientación informativa, no asesoría contable ni
tributaria. La app te lo recuerda siempre y te deja reportar cualquier respuesta
con un botón. Para declarar impuestos o tomar una decisión grande, consulta a un
contador.


PENSADA PARA TRABAJO INDEPENDIENTE

No necesitas saber contabilidad y no hay planillas. Si vendes en ferias, por
Instagram o por encargo, está hecha para ese tamaño de emprendimiento.


QUÉ NO HACE PÁGATE-IA

Para que no pierdas el tiempo si buscas otra cosa:

• No recibe pagos ni cobra a tus clientes. No es una billetera ni un medio de
  pago. Los montos que ves son los que tú anotas.
• No se conecta a tu banco. No lee tus movimientos reales.
• No emite boletas ni facturas ante el SII.
• No es un software de contabilidad formal ni reemplaza a tu contador.


TUS DATOS

Tus números son tuyos. No vendemos tus datos, no hay publicidad dentro de la app
y no hay seguimiento publicitario. Cuando usas el asistente, parte del contexto
de tu negocio se envía al proveedor del modelo de lenguaje para poder
responderte; está explicado campo por campo en nuestra política de privacidad, y
el resto de la app funciona sin enviar nada.

Y si te quieres ir, te vas: Perfil, Configuración, Eliminar cuenta. Se borra todo
lo que guardaste, sin escribirle a nadie.


Págate-IA está en desarrollo activo. Si echas en falta algo, escríbenos: lo que
viene después lo decidimos con lo que nos cuenten quienes la usan.
```

### Palabras que la ficha tiene que contener, y por qué

Play no tiene campo de palabras clave: indexa el nombre, la descripción breve y
la descripción completa. Estas son las que la competencia usa en sus propias
fichas (ver `docs/COMPETENCIA.md`, donde están las fuentes).

**Presentes en el texto de arriba**, comprobado buscándolas una por una y no de
memoria:

`valor hora` · `cuánto cobrar` · `precio` · `artesanos` · `emprendedores` ·
`emprendimiento` · `taller` · `ventas` · `gastos` · `ingresos` · `inventario` ·
`stock` · `materiales` · `negocio` · `ferias` · `independiente`

> Esta lista decía antes que las diecisiete estaban «de forma natural», y tres no
> estaban: `cuánto cobrar`, `emprendimiento` y `ganancias`. Las dos primeras se
> metieron en esta revisión donde encajaban (el párrafo de presentación y el
> bloque de trabajo independiente).

**`ganancias` se queda fuera a propósito.** La app calcula un **balance**
—ingresos menos gastos del mes— y eso no es la ganancia de un negocio: no
descuenta el costo de lo vendido, ni el sueldo de quien trabaja, ni nada que no
esté anotado. Escribir «calcula tus ganancias» indexaría mejor y describiría peor,
y la regla del encabezado de este documento no tiene excepciones por SEO.

Dos que la competencia usa y que **no** conviene meter, porque prometen lo que la
app no hace: `punto de venta` / `POS` y `boleta` / `factura electrónica`.

---

## 5. Recursos gráficos que Play exige

Fuente: [Ficha de Play Store — recursos gráficos](https://support.google.com/googleplay/android-developer/answer/9866151).

| Recurso | Dimensiones | Formato | Tamaño máx. | Cantidad | Estado |
|---|---|---|---|---|---|
| **Icono de la app** | 512 × 512 px | PNG de 32 bits con alfa | 1024 KB | 1, obligatorio | **Listo.** `android/play/icon-512.png`, generado por `scripts/generate-android-icons.py` desde la misma geometría que el icono adaptativo (`android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`), así que es idéntico al del lanzador. Se entrega cuadrado y a sangre: la máscara la aplica Play. Ya no es el logo por defecto de Flutter. |
| **Gráfico de funciones** (*feature graphic*) | 1024 × 500 px | JPEG o PNG de 24 bits, sin alfa | — | 1, obligatorio | **Falta.** Es la imagen grande de cabecera de la ficha. |
| **Capturas de teléfono** | lado mínimo 320 px, máximo 3840 px; 16:9 o 9:16 | JPEG o PNG de 24 bits, sin alfa | 8 MB cada una | mínimo 2, hasta 8 | **Faltan**, pero ya se pueden tomar: el rediseño está cerrado. Ojo con el formato, que es el detalle que se pasa por alto: las capturas del diseño final que hay en `docs/capturas/r7-*.png` miden **1080 × 2400**, o sea **9:20 y no 9:16**, porque es la pantalla del emulador. Hay que **componerlas sobre un lienzo 9:16** (1080 × 1920 sirve) con el titular encima, no subirlas tal cual. Y tomarlas con la cuenta de demostración: las de `r7-*` no todas la usan. |
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
3. **Lo que la hora valió de verdad**, la sección que la app muestra bajo el
   valor hora objetivo. Titular: «Lo que te entró y lo que te sobró».

   **Ojo con el titular, que aquí es donde se mintió una vez.** La pantalla
   muestra **dos** cifras con dos nombres distintos, y no son intercambiables
   (`net_hourly_value_section.dart`):

   - **«Lo que te entró por hora»** = (ingresos − comisiones) ÷ horas. **No
     descuenta los gastos.**
   - **«Lo que te sobró por hora»** = la anterior menos los gastos del mes. Puede
     ser negativa, y la app no la recorta a cero.

   Con los datos de la cuenta demo de este mes son **$8.092** y **$2.754**: casi
   el triple de diferencia. Un titular como «cuánto te quedó» sobre la primera
   cifra es exactamente el error que se corrigió en el código, así que no puede
   volver por la ficha.

   Vale una captura propia porque es la frontera que describe
   `docs/COMPETENCIA.md` §1.9: descontar la comisión del medio de pago **no** es
   un diferenciador —CraftCost lo hace, con perfiles por plataforma— pero hacerlo
   **sobre los ingresos reales del mes para sacar el valor de la hora** sí lo es,
   porque ninguna de las siete calculadoras lleva las cuentas del mes. No
   escribir en la ficha que «nadie descuenta comisiones»: es falso y está
   desmentido en ese documento.

   **Las dos cifras salen solo en el mes en curso de la cuenta demo**, que es el
   único con comisiones sembradas (8.995 CLP sobre 980.000 de ingresos).
4. **Registro de un movimiento**, el formulario abierto, con los campos de
   documento y comisión a la vista. Titular: «Anota una venta en segundos».
5. **Finanzas**, con la lista de movimientos del mes. Titular: «Todo lo que
   entró y salió».
6. **Gastos fijos**. Titular: «Lo que pagas todos los meses».
7. **Inventario**, con productos y materiales y algún ítem en estado «Bajo».
   Titular: «Qué tienes y qué te falta».
8. **Asistente**, con una conversación real corta. Titular: «Pregúntale sobre tu
   negocio». La captura tiene que mostrar **el aviso de que responde una IA**
   (va fijo bajo la cabecera, no hay que buscarlo) y, si cabe, el botón de
   reportar respuesta: son las dos cosas que la política de Play para apps con
   IA generativa exige tener, y verlas en la ficha ayuda en la revisión.

Fuera quedó el detalle de un ítem de inventario, que repetía lo que ya cuenta la
captura 7, para hacerle sitio al valor hora neto.

**Las capturas se toman con la cuenta de demostración** (ver §9), para que los
datos sean coherentes entre pantallas: que el balance del mes de la captura 1 sea
el mismo que suman los movimientos de la captura 5, y que ninguna pantalla salga
vacía al lado de otra llena.

**La captura 8 no se puede tomar con la cuenta recién sembrada.** El sembrado no
crea la conversación a propósito (el por qué está en el §9): hay que entrar con
la cuenta demo y hablar con el asistente antes de capturar.

---

## 6. Resto de campos de la ficha

| Campo | Valor | Nota |
|---|---|---|
| Categoría de la app | **Finanzas** | La app no cae bajo la política de Servicios Financieros de Play: no presta dinero, no transmite fondos, no opera con criptomonedas ni con instrumentos de inversión. Es gestión y orientación. |
| Etiquetas | `Finanzas personales`, `Presupuesto`, `Negocios` | Play permite hasta 5. |
| Correo electrónico de contacto | *(pendiente — ver abajo)* | Tiene que ser el mismo que `CONTACT.support` en `landing/src/content/legal-meta.ts`. |
| Sitio web | `https://francogalaz.github.io/Pagate-ia/landing-page/` | |
| Política de Privacidad | `https://francogalaz.github.io/Pagate-ia/landing-page/privacidad/` | Obligatoria. **Hoy responde 404**: hay que publicar la landing antes de pegarla (§0 bis). |
| Teléfono de contacto | Dejar vacío | Es opcional y publica el número. |
| Clasificación de contenido | Cuestionario IARC | Sin violencia, sexo, drogas, juego ni compras. Declarar que **sí** incluye IA generativa con contenido no filtrado por el desarrollador. |
| Anuncios | **No contiene anuncios** | Verificado: no hay ningún SDK de publicidad en `pubspec.yaml`. |
| Compras en la aplicación | **No** | No existe ninguna: no hay `in_app_purchase` ni integración de facturación en `pubspec.yaml`, y **ningún texto que lea el usuario menciona un plan de pago**. El día que haya algo que vender hay que cambiar esta respuesta y cobrarlo con Google Play Billing: cobrarlo por fuera es causa de suspensión de la cuenta. |
| Eliminación de cuenta | Dentro de la app: *Perfil → Configuración → Eliminar cuenta*. URL pública: `.../landing-page/eliminar-cuenta/` | Play exige **las dos** a toda app que permita crear una cuenta. Las dos existen; la URL **hoy responde 404** hasta publicar la landing (§0 bis). El detalle, en `docs/SEGURIDAD-DATOS-PLAY.md` §4.2. |

### Pendiente de decisión del dueño

El inventario completo, con archivo y número de línea, está en el **§8**: los
**cinco** datos de identidad legal (razón social o nombre, RUT, domicilio, correo
de privacidad y correo de soporte) más el nombre público del desarrollador, que
no vive en ningún archivo del repositorio sino en Play Console.

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

## 8. LOS CINCO DATOS LEGALES, LÍNEA POR LÍNEA

> Este apartado es el **detalle del punto 5 del §0**, no un bloqueo aparte.
> Cinco datos, un solo archivo, cinco líneas. Nadie puede decidirlos en su lugar
> y no se pueden inventar: van en una política de privacidad y en unos términos
> de servicio.

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

**No reutilizar `soporte@pagate-ia.com`**: usa un dominio que el dueño no
controla (verificado en `docs/AUDITORIA-2026-09-29.md`). Ya no sale en ninguna
pantalla —la de Ayuda son solo preguntas frecuentes y no muestra ningún correo—,
pero sigue apareciendo en documentos viejos y en el `README.md`, así que conviene
decirlo: **no vale**. Lo más barato y rápido es el correo de la cuenta de
desarrollador de Google Play.

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
| **Nombre comercial: `Págate-IA` o `Pagate`** | **Ya unificado a `Págate-IA`, con tilde, en los cuatro sitios que lo fijan**: `android/app/src/main/res/values/strings.xml` (`app_name`, que es lo que el lanzador pinta bajo el icono y lo que sale en Ajustes), `pubspec.yaml`, `functions/package.json` y los tres `<title>` de las páginas legales. El nombre de la ficha (§1) tiene que escribirse igual: el de la app instalada y el de los documentos legales publicados no pueden discrepar. Si el dueño prefiere `Pagate`, hay que cambiarlo en los cuatro a la vez |
| **El plan Pro** | No existe, y **ya no se menciona en ningún texto que lea el usuario**: no hay nada que decidir para publicar. La decisión es si algún día lo habrá, y eso está en `docs/PLAN-PUBLICIDAD.md` §7. Si la respuesta es sí, pasa por Google Play Billing (§6) |
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

**Quién la siembra:** `scripts/seed-demo.js`, que escribe **solo** contra los
emuladores (aborta si no están las variables de entorno). Lo que deja, verificado
leyéndolo de Firestore el 6 de octubre de 2026:

| Qué | Cuánto |
|---|---|
| Cuenta | `demo@pagate.cl` / `PagateDemo2026`, taller «Greda Austral», rubro Cerámica, CLP |
| Valor hora objetivo | 7.500 CLP (900.000 ÷ 120 h) |
| Movimientos | 38 en tres meses: 11 + 13 + 14 |
| Mes en curso | ingresos 980.000 · gastos 640.500 · **saldo 339.500** · comisiones 8.995 |
| Inventario | 12 ítems, 4 bajo el mínimo (para que se vea el estado de alerta) |
| Gastos fijos | 3 (103.490 CLP al mes) |
| Contrato C-3 | 6 ingresos con `docType`, 2 con comisión del medio de pago |
| Agregados | `months/*` con los cuatro campos, incluido `totalPlatformFees` |

Los tres meses cierran en positivo, los gastos fijos **no duplican** ninguna
transacción de la cartola, el mes en curso no tiene movimientos con fecha futura
y el script lo comprueba todo antes de escribir. El detalle de cada regla, en
`scripts/README.md`.

**Lo que el sembrado NO deja, y hay que hacer a mano: la conversación del
asistente.** El script no la siembra a propósito. Podría escribirla con el Admin
SDK, pero entonces la respuesta «del asistente» la habría escrito el script y no
el modelo: sería una respuesta de IA inventada, en la cuenta que se le entrega a
un revisor y en la captura 8 de la ficha. La conversación se consigue de la única
forma en que es verdad: **entrando con la cuenta demo y hablando con el
asistente**. Son dos o tres mensajes y hay 25 disponibles.

**Para la cuenta que se le entrega al revisor hay que volver a sembrar contra el
proyecto de producción**, y eso solo lo puede hacer el dueño: el script, por
diseño, se niega a escribir fuera de los emuladores. Y antes de poder sembrar
ahí hacen falta los pasos 1, 2 y 3 del **§0**: hoy el proyecto de producción no
tiene Authentication encendido ni base de datos creada.

**Nota para el revisor**, a pegar en el mismo formulario:

```
La app es una herramienta de registro y orientación financiera. No procesa
pagos, no se conecta a cuentas bancarias y no emite documentos tributarios.

El asistente de IA tiene un límite de 25 mensajes EN TOTAL (de por vida, no
diarios). No hay compras dentro de la aplicación: no se vende ningún plan, ni
dentro de la app ni fuera, y no hay nada que se pueda pagar. Si la cuenta de
demostración agota sus 25 mensajes, el asistente deja de responder y el resto de
la app sigue funcionando igual; por eso la cuenta se entrega con la conversación
ya cargada y con mensajes sin gastar.

Las respuestas del asistente las genera un modelo de lenguaje. La app lo avisa de
forma permanente en la pestaña del asistente y ofrece un botón para reportar
cualquier respuesta.

En Android el único acceso es con correo y contraseña: es el único botón de
ingreso que se muestra. El acceso con Google existe solo en la versión web.

Para eliminar la cuenta y todos sus datos desde dentro de la app:
Perfil → Configuración → Eliminar cuenta.

Credenciales de la cuenta de demostración: (completar)
```

Cada párrafo de esa nota describe algo comprobado en el código de hoy, y por eso
está:

| Lo que dice la nota | Dónde se sostiene |
|---|---|
| 25 mensajes de por vida, no diarios | `functions/src/quota.ts:66` (`FREE_LIFETIME_QUOTA = 25`) y el mensaje que lee el usuario en `freeQuotaExhaustedMessage()` |
| No hay compras dentro de la app, ni plan que vender | No existe `in_app_purchase` ni ninguna integración de facturación en `pubspec.yaml`. **Y ya no se menciona ningún plan Pro en texto que lea el usuario**: la única cadena que lo nombra es la insignia de `perfil_tab.dart`, que solo se pinta si `plan == 'pro'` —valor que únicamente escribe el backend— y el mensaje de cuota agotada ya no invita a cambiar de plan |
| Aviso de IA y botón de reporte | El aviso vive fijo bajo la cabecera del asistente (`ia_tab.dart:47-53`) y el reporte escribe en `users/{uid}/aiReports` (`ai_provider.dart:320-345`), con sus reglas en `firestore.rules` |
| En Android solo correo y contraseña | El botón de Google se renderiza solo donde existe (`GoogleAuthService.isAvailable` es `kIsWeb`). El botón «Continuar con Apple» **ya no existe**: se borró junto con `_onAppleSignIn`, así que la nota tampoco lo menciona |
| Borrado de cuenta dentro de la app | `configuracion_screen.dart` → `EliminarCuentaScreen`, contra el callable `deleteAccount` (`functions/src/account.ts`), que borra el árbol completo con `recursiveDelete` y después **verifica** que no quedó nada |

Decirlo en la nota evita que el revisor reporte como fallo algo que es una
decisión, y evita lo contrario: que la ficha prometa algo que la app no hace.
