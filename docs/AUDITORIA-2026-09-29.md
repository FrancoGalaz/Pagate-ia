# Auditoría técnica — Págate-IA (2026-09-29)

Auditoría de la rama `arquitectura-segura` (HEAD `9b56b27`) con 24 agentes: 10 auditores por
dimensión, 10 refutadores adversariales y 4 de diseño visual. Cada hallazgo cita archivo y línea
comprobados sobre el código actual; 2 se descartaron al refutarlos y 72 se corrigieron de severidad.

| Severidad | Cantidad |
| --- | --- |
| Crítica | 18 |
| Alta | 61 |
| Media | 147 |
| Baja | 44 |
| **Total** | **270** |

El sistema visual que resuelve los hallazgos de frontend está en [DISENO-v2.md](DISENO-v2.md).
El plan de ejecución, en [PLAN.md](PLAN.md).

---

## 1. Comprobación en ejecución e infraestructura

Estos hallazgos no salen de leer código sino de ejecutar la app en un emulador Android y de sondear
el proyecto `pagate-17211` desde fuera. Mandan sobre todo lo demás.

### El proyecto de Firebase está vacío

| Servicio | Estado comprobado | Evidencia |
| --- | --- | --- |
| Authentication | Nunca inicializado | `identitytoolkit.googleapis.com` devuelve `CONFIGURATION_NOT_FOUND` para el proyecto entero |
| Cloud Firestore | API deshabilitada | `SERVICE_DISABLED`: "Cloud Firestore API has not been used in project pagate-17211 before" |
| Cloud Functions | Ninguna desplegada | `chat`, `waitlist` y `onTransactionWritten` responden HTTP 404 |
| Hosting | Nunca desplegado | `pagate-17211.web.app` responde HTTP 404 "Site Not Found" |
| Landing pública | Build de mayo | GitHub Pages sirve `index-DMBjDY22.js`, el que guarda los correos en `localStorage` |

Consecuencia: **hoy nadie puede registrarse ni entrar**. Al pulsar "Siguiente" en el registro, la app
muestra `An internal error has occurred. [ CONFIGURATION_NOT_FOUND`, en inglés y cortado por el borde.
Como todo cuelga del portón de sesión, la app es inusable de punta a punta. Se arregla en la consola,
no en el código.

### Build de publicación

- `flutter build appbundle --release` **falla**: `Failed to find cmdline-tools when checking final appbundle for debug symbols`. No se puede generar el artefacto que Play exige hasta instalar *Android SDK Command-line Tools* desde el SDK Manager de Android Studio.
- `flutter build apk --release` sí funciona: 57,1 MB, sin ofuscación ni reducción de recursos activadas.
- Requisito de Play confirmado en la documentación oficial: desde el 31 de agosto de 2026 las apps nuevas deben apuntar a **API 36**. El proyecto resuelve `targetSdk` 36 y `minSdk` 24, así que cumple.
- El icono sigue siendo, byte a byte, el logotipo por defecto de Flutter, y no hay icono adaptativo.

### Permisos y red

- El permiso de INTERNET **sí** llega al APK de release por fusión de manifiestos de los SDK nativos de Firebase. **Descartado como problema** tras comprobarlo con `aapt2 dump permissions`.
- La app arrastra permisos de mensajería push que no usa: `com.google.android.c2dm.permission.RECEIVE`, `WAKE_LOCK` y `READ_GSERVICES`.
- El flujo de desarrollo local que documentan README y AGENTS.md está roto en Android: `Cleartext HTTP traffic to 10.0.2.2 not permitted`. Falta una configuración de seguridad de red que lo permita solo en depuración.

### Interfaz, observado en pantalla

- En el registro, con el teclado abierto, el botón "Siguiente" se monta encima del campo de contraseña y tapa el aviso legal.
- Los puntos del campo de contraseña son un marcador de posición, no contenido: parece relleno cuando está vacío.
- El mensaje de error que ve el usuario es texto interno de Firebase en inglés.

---

## 2. Hallazgos críticos y altos

Detalle completo, ordenado por dimensión.

### Estado de la auditoría anterior

#### [2.1-A] El build release sigue firmado con el keystore de debug

`android/app/build.gradle.kts:38` · **Crítica** · esfuerzo M · **bloquea publicación**

Hallazgo 2.1-A intacto: `signingConfig = signingConfigs.getByName("debug")` con el TODO de la plantilla justo encima (lineas 36-37). Google Play rechaza un AAB firmado con el keystore de debug, asi que esto bloquea literalmente el objetivo de publicar. La parte de `minSdk 21` del mismo hallazgo SI esta resuelta, pero solo en el working tree sin commitear: `git diff` muestra `minSdk = 21` -> `minSdk = flutter.minSdkVersion` en la linea 28.

**Corrección.** Tarea DUENO S1-01: generar el keystore de release, crear android/key.properties (ignorado por git, hoy .gitignore no lo cubre) y anadir `signingConfigs.release` leyendolo de ese archivo. Commitear ademas el cambio de minSdk que ya esta en el working tree.

#### [2.1-C] App Check sigue sin exigirse en produccion (ENFORCE_APP_CHECK=false)

`functions/.env:2` · **Alta** · esfuerzo S · **bloquea publicación**

El hallazgo critico 2.1 #3 sigue abierto. F0-05 creo functions/.env, pero con `ENFORCE_APP_CHECK=false` (functions/.env:2, mismo valor en .env.example:4 y como default en functions/src/config.ts:20-23). En functions/src/chat.ts:152 la comprobacion `if (ENFORCE_APP_CHECK.value() && !request.app)` queda inerte: cualquier cuenta autoregistrada puede llamar `chat` con curl y un ID token y consumir credito de OpenRouter sin pasar por la app. Con la app publicada en Play el riesgo de abuso se multiplica. Nota: el commit F0-05 SI cerro la parte de maxInstances (chat.ts:143, months.ts:50, waitlist.ts:105) y cors (chat.ts:145), que era el hallazgo 2.1-A separado.

**Corrección.** Tarea DUENO S1-03: registrar App Check en consola (Play Integrity con el SHA-256 del keystore de release y reCAPTCHA v3 para web). Luego S1-04: poner ENFORCE_APP_CHECK=true en functions/.env y anadir `enforceAppCheck: true` en las opciones de onCall de chat.ts, y redesplegar.

> *Matizado al verificar:* Los hechos son exactos: `functions/.env:2` dice `ENFORCE_APP_CHECK=false`; `functions/.env.example:4` igual; `functions/src/config.ts:20-23` declara `defineBoolean('ENFORCE_APP_CHECK', { default: false, ... })`; y `functions/src/chat.ts:152` es `if (ENFORCE_APP_CHECK.value() && !request.app)`, inerte. Tambien es cierto que F0-05 cerro maxInstances (chat.ts:143 `maxInstances: 5`, months.ts:50 `maxInstances: 10`, waitlist.ts:105 `maxInstances: 2`) y cors (chat.ts:145). Matices que bajan la severidad de critica a alta: (1) el abuso esta acotado por cuota diaria por cuenta, `functions/src/chat.ts:26` `export const DAILY_QUOTA: Record<Plan, number> = { free: 30, pro: 300 }` consumida en transacc…

#### [2.1-C] Configuracion web de Firebase sigue con placeholders (parcialmente corregido por F0-02)

`lib/firebase_options.dart:51` · **Alta** · esfuerzo S

El critico 2.1 #1 esta a medias. F0-02 (c995c32) puso los valores reales de Android (lineas 35-41, apiKey y appId coinciden con android/app/google-services.json) y cambio `currentPlatform` para lanzar UnsupportedError en iOS/macOS/Windows/Linux/Fuchsia (lineas 19-28). Pero el bloque `web` sigue con `apiKey: 'AIzaSy...r-vA'` (linea 51) y `appId: '1:390581596119:web:xxxxxxxxxxxx'` (linea 52). El guard `webIsConfigured` (linea 60) hace que lib/core/config/firebase_bootstrap.dart:22-27 lance un StateError, asi que la web deja de arrancar del todo. Dos consecuencias: (1) .github/workflows/ci.yml:28 sigue construyendo `flutter build web --release` sin fallar, y deploy-web.yml publicaria un hosting que solo muestra la pantalla de error; (2) el guard solo mira `appId.contains('xxxx')`, asi que si el dueno rellena el appId y olvida la apiKey el chequeo pasa igual. Ademas, la restriccion de las API keys en GCP por package+SHA / referrer (parte del mismo hallazgo) sigue pendiente.

**Corrección.** F0-01 (DUENO): `flutterfire configure --project=pagate-17211 --platforms=android,web` o copiar apiKey/appId web desde la consola. Endurecer `webIsConfigured` para que tambien valide la apiKey. Restringir ambas keys en GCP. Para Play esto no bloquea (Android ya esta configurado), pero si bloquea cualquier deploy web.

#### [2.2-A] Los despliegues siguen sin correr ningun test

`.github/workflows/deploy-web.yml:34` · **Alta** · esfuerzo M

Hallazgo 2.2-A intacto. El job `deploy` va directo de checkout a `flutter build web` (linea 34) y `firebase deploy` (lineas 63-66): no hay `needs:` a un job de tests ni pasos de `flutter analyze`/`flutter test`/`npm test`. scripts/deploy-web.sh:35 hace lo mismo en local y ademas no pasa `--project` (depende del alias activo del CLI) ni comprueba en que rama esta. Un push de tag `v*` con las reglas rotas las despliega igual.

**Corrección.** Extraer los jobs de ci.yml a un workflow reutilizable e invocarlo con `needs:` antes del deploy. En deploy-web.sh: anadir `--project pagate-17211` y una verificacion de rama y de los tres bloques de verificacion antes de desplegar.

#### [2.4-A] delete de users/{uid} sigue permitido y deja huerfanas todas las subcolecciones

`firestore.rules:98` · **Alta** · esfuerzo M

Hallazgo 2.4-A intacto: `allow delete: if isOwner(uid);` en users/{uid}. Firestore no borra subcolecciones al borrar el documento padre, asi que inventory, transactions, fixedExpenses, months, conversations/messages y meta/usage quedan colgando sin documento raiz (y months/meta ya no son accesibles ni por el dueno, porque las reglas de lectura dependen del arbol). No existe ningun callable de borrado de cuenta (verificado: functions/src/index.ts solo exporta chat, onTransactionWritten y waitlist). Google Play exige una ruta de borrado de cuenta y datos para apps con login.

**Corrección.** S1-07: denegar `delete` en users/{uid} y anadir un callable `deleteAccount` que use `firestore.recursiveDelete` mas `auth.deleteUser`, con boton en Configuracion y la URL de borrado de datos para la ficha de Play.

#### [2.5-A] Moneda: cinco formateadores distintos, simbolo $ fijo, profile.currency ignorado y negativos como $-5000

`lib/features/finances/presentation/pages/finanzas_tab.dart:15` · **Alta** · esfuerzo M

Hallazgo 2.5-A intacto y verificado uno por uno. Hay cinco implementaciones con reglas distintas: finanzas_tab.dart:15-24 (`-$1.234`, separador '.'), lib/core/services/pdf_report_service.dart:22-33 (identica pero duplicada), lib/features/dashboard/presentation/pages/tabs/home_tab.dart:243 y :610 (dos copias en el MISMO archivo, formato '12.3K'), lib/features/dashboard/presentation/widgets/financial_charts.dart:499 (igual), mas el inline de lib/features/inventory/presentation/pages/inventario_tab.dart:435 (`toStringAsFixed(2)`, con dos decimales para CLP). Ninguna consulta `profile.currency`, aunque el perfil admite CLP y USD (firestore.rules:76). El caso `$-5000` se reproduce en home_tab.dart:196: `'\$${_fmt(balance)}'` con balance negativo pasa por la rama `v.toStringAsFixed(0)` y sale `$-5000`; lo mismo en home_tab.dart:590. Y `lib/core/utils/` solo contiene app_feedback.dart: el currency_formatter del contrato C-2 no existe. `intl` esta en pubspec.yaml:17 y no se importa en ningun sitio.

**Corrección.** C-2: crear lib/core/utils/currency_formatter.dart con `formatCurrency(num, {required String currency})` sobre NumberFormat.currency (CLP sin decimales, USD con 2), leer la moneda del perfil y sustituir las cinco implementaciones. Test unitario incluyendo negativos.

> *Matizado al verificar:* Verifique las seis ubicaciones una a una y son correctas: `finanzas_tab.dart:15-24` (`String _money`, separador '.', `'${negative ? '-' : ''}\$$buffer'`); `pdf_report_service.dart:22-33` (`static String _fmt`, misma logica duplicada); `home_tab.dart:243-244` y `:610-611` (dos copias identicas de `String _fmt(double v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);` en el mismo archivo); `financial_charts.dart:499-500` (tercera copia); `inventario_tab.dart:435` (`'${item.stock} ${item.unit}  •  \$${item.price.toStringAsFixed(2)}'`). `ls lib/core/utils/` devuelve solo `app_feedback.dart`; `grep -rn 'package:intl' lib/` no devuelve nada aunque `pubspec.yaml:17` decl…

#### [2.5-A] IdentityStepScreen: pantalla clara bajo tema oscuro, pais sin onTap, moneda que no se guarda y 'Paso 1 de 3' sin pasos 2 y 3

`lib/features/onboarding/presentation/pages/identity_step_screen.dart:81` · **Alta** · esfuerzo M

Hallazgo 2.5-A intacto en sus cuatro partes. (1) `backgroundColor: AppColors.surface` (linea 81) con textos en AppColors.textPrimary (106, 162) mientras app_shell.dart:28 fuerza `themeMode: ThemeMode.dark`: la pantalla de registro sale ilegible. (2) `_buildCountrySelector` (lineas 259-302) es un Container con 'Chile' hardcodeado (linea 288) y un icono `expand_more` (295-299) sin ningun GestureDetector: parece un desplegable y no hace nada. (3) `_selectedCurrency` (linea 26) se actualiza con setState (linea 323) pero `_onNext` (lineas 37-73) nunca lo usa ni lo pasa a createUserWithEmailAndPassword: la eleccion se pierde. (4) `PagateStepHeader(currentStep: 1, totalSteps: 3)` (lineas 86-90) es la UNICA instancia del widget en todo lib/ (verificado por grep): no existen los pasos 2 y 3.

**Corrección.** B2-04, y encaja con el rediseno de la pantalla de registro: reescribir con la paleta clara unica, quitar el selector de pais, o persistir la moneda o quitarla del registro (ya se elige en el onboarding), y poner `totalSteps` al numero real de pasos.

### Sistema de diseño: tokens, tema y tipografía

#### Manrope se registra como variable font sin fontVariations: el peso por defecto del archivo es ExtraLight (wght 200)

`pubspec.yaml:38` · **Crítica** · esfuerzo S · **bloquea publicación**

pubspec.yaml:37-40 registra `assets/fonts/Manrope[wght].ttf` como familia `Manrope` sin entradas `weight:` por peso. Inspeccionando el binario: la tabla `fvar` declara un unico eje `wght` con rango 200-800 y **default 200**, y el `name` ID 1 del archivo es literalmente "Manrope ExtraLight" (version 4.504, unitsPerEm 2000). En todo `lib/` hay **0 usos de `FontVariation`/`fontVariations`** (grep verificado). Mientras tanto el tema pide w800 en 6 estilos (app_theme.dart:26,32,38,46) y los widgets sobreescriben el peso 120 veces (46 w700, 42 w600, 22 w800, 7 w500, 3 w400). Con una variable font declarada como un unico asset, Flutter no fija el eje `wght`: el motor renderiza la instancia por defecto (ExtraLight) y, como mucho, aplica negrita sintetica. Es exactamente lo contrario de la direccion elegida ("tipografia fuerte, cifras grandes y legibles").

**Corrección.** Dos opciones: (1) declarar instancias estaticas por peso en pubspec (`weight: 400/500/600/700/800` apuntando a TTF estaticos extraidos del variable), que es lo mas robusto; o (2) mantener el variable y anadir `fontVariations: [FontVariation('wght', X)]` en cada estilo del `TextTheme` de app_theme.dart:21-120, sincronizado con `fontWeight`. Ademas subir el suelo de peso: en fintech densa el cuerpo va en 450-500, no en 400. Verificar en dispositivo real con una captura antes/despues.

#### El tema oscuro esta forzado y cuesta 251 referencias en 21 archivos + 163 lineas de tema

`lib/features/auth/presentation/widgets/app_shell.dart:28` · **Crítica** · esfuerzo L · **bloquea publicación**

app_shell.dart:26-28 monta `theme: AppTheme.lightTheme`, `darkTheme: AppTheme.darkTheme` y `themeMode: ThemeMode.dark`: el tema claro existe pero nunca se usa. Coste real de eliminar el oscuro, contado con grep: **251 usos de tokens con sufijo Dark** (`backgroundDark`, `surfaceDark`, `surfaceDarkElevated`, `surfaceDarkSecondary`, `borderDark`, `textPrimaryDark`, `textSecondaryDark`, `textTertiaryDark`) repartidos asi -- finanzas_tab.dart 42, inventario_tab.dart 23, app_theme.dart 19, ia_tab.dart 19, home_tab.dart 17, detalle_item_screen.dart 16, perfil_tab.dart 15, ayuda_screen.dart 15, editar_perfil_screen.dart 14, financial_charts.dart 13, dashboard_screen.dart 11, configuracion_screen.dart 9, setup_inicial_screen.dart 8, hourly_rate_setup_page.dart 7, transaction_form_sheet.dart 7, login_screen.dart 5, bootstrap_error_app.dart 4, session_error_view.dart 3, splash_screen.dart 2, premium_text_field.dart 1, glass_card.dart 1. Mas: `AppTheme.darkTheme` (app_theme.dart:398-560, 163 lineas), `bootstrap_error_app.dart:27` que instancia darkTheme a mano, `pagate_section_card.dart:29` que ramifica por `brightness == Brightness.dark`, y 3 tests que montan darkTheme (test/widget_test.dart:16 y :39, test/features/auth/welcome_screen_test.dart:17). Ademas hay 2 pantallas que ya usan tokens CLAROS bajo el tema oscuro y por tanto hoy se ven mal: welcome_screen.dart (12 usos de tokens claros) e identity_step_screen.dart (12 usos).

**Corrección.** Orden recomendado: (1) borrar `AppTheme.darkTheme` completo y las 8 constantes *Dark de app_constants.dart (lineas 49-56 y 67-70); (2) `app_shell.dart` se queda solo con `theme: AppTheme.lightTheme` (sin `darkTheme` ni `themeMode`); (3) barrido archivo por archivo sustituyendo cada token Dark por su equivalente claro -- lo mas rapido es que las 5 pantallas del rediseno se reescriban directamente y el resto se pase con sed dirigido + revision; (4) `pagate_section_card.dart:29` pierde el `if`; (5) los 3 tests pasan a `AppTheme.lightTheme`.

> *Matizado al verificar:* El núcleo es exacto. app_shell.dart:26-28 es literalmente `theme: AppTheme.lightTheme,` / `darkTheme: AppTheme.darkTheme,` / `themeMode: ThemeMode.dark,`. Reproduje el censo de tokens *Dark con grep: 259 ocurrencias en 22 archivos, de las cuales 8 son las declaraciones en app_constants.dart:50-54 y :66-68 → **251 usos en 21 archivos**, y el desglose por archivo coincide uno a uno (finanzas_tab 42, inventario_tab 23, ia_tab 19, app_theme 19, home_tab 17, detalle_item 16, perfil_tab 15, ayuda 15, editar_perfil 14, financial_charts 13, dashboard 11, configuracion 9, setup_inicial 8, hourly_rate 7, transaction_form 7, login 5, bootstrap_error 4, session_error 3, splash 2, premium_text_field 1, …

#### Tokens de gradiente: 4 declarados, 15 usos de brandGradient en 9 archivos, 2 sin usar

`lib/core/constants/app_constants.dart:86` · **Alta** · esfuerzo M · **bloquea publicación**

Cuatro presets de gradiente en app_constants.dart: `brandGradient` (:86-90, esmeralda a esmeralda oscuro en diagonal), `heroGradient` (:92-96, azul noche, **0 usos**), `fadeToBackground` (:98-105, **0 usos**) y `fadeToWhite` (:107-114, 1 uso en identity_step_screen.dart:238). `brandGradient` se usa 15 veces en 9 archivos: login_screen.dart:147, splash_screen.dart:20, ayuda_screen.dart:76, dashboard_screen.dart:142 y :309, home_tab.dart:69 y :158, ia_tab.dart:140, :385 y :409, hourly_rate_setup_page.dart:127 y :207, detalle_item_screen.dart:89, perfil_tab.dart:31 y :70. Ninguno codifica informacion: son decoracion de avatares, logos y la tarjeta de balance. Ademas hay 2 gradientes declarados inline fuera de tokens (welcome_screen.dart y hourly_rate_setup_page.dart).

**Corrección.** Borrar los 4 presets. `brandGradient` se sustituye por `AppColors.brand` plano en los 15 sitios (un `Container` con `color:` en vez de `gradient:`). `fadeToWhite` en identity_step_screen.dart:238 se sustituye por un borde superior de 1px o nada. Los 2 gradientes inline se borran con sus pantallas.

#### Sombras de marca (glow verde): shadowBrand, AppShadows.brand y brandStrong

`lib/core/constants/app_constants.dart:83` · **Alta** · esfuerzo S · **bloquea publicación**

Tres tokens de sombra coloreada de marca: `AppColors.shadowBrand` (app_constants.dart:83, `0x40006B5F`, **0 usos**), `AppShadows.brand` (:249-255, brand al 25%, blur 16, offset 0,6) y `AppShadows.brandStrong` (:257-263, brand al 40%, blur 24, offset 0,8). 6 usos verificados: pagate_primary_button.dart:36 (el CTA primario de toda la app lleva glow), login_screen.dart:149, splash_screen.dart:22, welcome_screen.dart:78, home_tab.dart:160 (tarjeta de balance) y perfil_tab.dart:33. Es el 'boton pastilla con glow' prohibido, y en pagate_primary_button esta en el componente compartido, asi que contamina toda la app.

**Corrección.** Borrar los tres tokens. En pagate_primary_button.dart eliminar el `Container` envolvente (lineas 30-38) y la propiedad `hasShadow` (:14, :23) por completo: el boton solido no lleva sombra. Conservar solo `AppShadows.sm` (2 usos) y `md` para elevaciones neutras, y revisar si `lg` (1 uso) y `xl` (1 uso, welcome_screen.dart:134) sobreviven al rediseno -- probablemente no.

#### Radios enormes: el radio mas usado de la app es 32px y el segundo es la pastilla de 100px

`lib/core/constants/app_constants.dart:157` · **Alta** · esfuerzo M · **bloquea publicación**

Escala `AppRadius` en app_constants.dart:151-158: xs 8, sm 12, md 16, lg 20, xl 24, **xxl 32**, **pill 100**. Uso real contado con grep sobre lib/: `xxlBorder` 31 usos (el mas usado de todos), `pillBorder` 20, `xlBorder` 18, `lgBorder` 13, `smBorder` 10, `xl` 4, `mdBorder` 4, `xsBorder` 3. Es decir **51 de 103 usos de radio son 32px o pastilla**. Peor: esta cableado en el tema, no solo en pantallas -- `inputDecorationTheme` usa `AppRadius.xxlBorder` en los cinco borders (app_theme.dart:193, 197, 201, 208, 215), `cardTheme` usa `xlBorder` (:180), `elevatedButtonTheme` y `outlinedButtonTheme` usan `pillBorder` (:250, :276), `chipTheme` usa `lgBorder` (:320). `AppRadius.pill` como double suelto (:158) tiene 0 usos directos.

**Corrección.** Recortar la escala a 4 valores: `none 0`, `sm 6`, `md 10`, `lg 14` (o similar); borrar `xxl` y `pill`. Inputs y botones pasan a `sm`/`md` con **borde visible de 1px**; tarjetas a `md`. Los 51 sitios de 32px/pastilla se reemplazan en bloque. Mantener un unico radio grande solo si aparece un avatar circular, y entonces usar `BoxShape.circle`, no un radio.

#### La escala tipografica no sirve para densidad: tres roles compiten en 14px, dos pasos muertos y ningun estilo numerico

`lib/core/theme/app_theme.dart:21` · **Alta** · esfuerzo M

`_baseTextTheme` (app_theme.dart:21-120) tiene 15 estilos: 48/36/30/28/24/20/18/16/14 + body 16/14/12 + label 14/12/11. Problemas verificados: (1) **Pasos muertos** -- `displayLarge` (48px, :22) y `displayMedium` (36px, :29) tienen **0 usos** en todo lib/ (conteo de `textTheme.*`: bodyMedium 30, bodySmall 25, labelSmall 16, titleMedium 10, bodyLarge 9, titleSmall 8, labelMedium 8, titleLarge 7, headlineSmall 6, headlineMedium 5, displaySmall 3, headlineLarge 2, labelLarge 1, displayLarge 0, displayMedium 0). (2) **Colisiones** -- tres estilos distintos a 14px (`titleSmall` w600 :75, `bodyMedium` w400 :87, `labelLarge` w700 letterSpacing .5 :99) y dos a 16px (`titleMedium` w600, `bodyLarge` w400); el equipo no distingue cual usar, y por eso hay **120 `fontWeight` explicitos en widgets** sobreescribiendo el tema (46 w700, 42 w600, 22 w800, 7 w500, 3 w400). (3) **Fuera de escala** -- el `chipTheme` usa `fontSize: 13` (:309, :315), un tamano que no existe en la escala. (4) **Aireada** -- `height: 1.5` en los tres estilos de body (:85, :91, :97), demasiado para densidad alta; 1.35-1.45 es lo correcto. (5) **Falta el rol numerico** -- no hay ningun estilo pensado para montos (ni tamano, ni tnum, ni tracking cero).

**Corrección.** Reducir a ~10 roles con un unico significado cada uno: display (32, w700, tracking -0.02em) para la cifra grande de balance; heading (20/17, w700); body (15/13, w450/w500, height 1.4); label (12 w600 uppercase tracking .06em) para etiquetas de dato; y una familia numerica (amountLg 28 / amountMd 17 / amountSm 14, todas con `tabularFigures`). Borrar displayLarge y displayMedium. Prohibir `fontWeight` en las pantallas via lint o revision: si hace falta un peso, es que falta un rol.

> *Matizado al verificar:* Reproduje el censo de roles y sale **idéntico**: displayLarge 0, displayMedium 0, displaySmall 3, headlineLarge 2, headlineMedium 5, headlineSmall 6, titleLarge 7, titleMedium 10, titleSmall 8, bodyLarge 9, bodyMedium 30, bodySmall 25, labelLarge 1, labelMedium 8, labelSmall 16. Pasos muertos confirmados: `displayLarge:` en app_theme.dart:22 (fontSize 48 en :24) y `displayMedium:` en :29, ambos con 0 usos. Colisiones confirmadas: 14px en titleSmall (:75, w600), bodyMedium (:87, w400) y labelLarge (:99, w700, letterSpacing 0.5); 16px en titleMedium (:69) y bodyLarge (:81). Fuera de escala: `fontSize: 13` en chipTheme, app_theme.dart:309 y :315 ✓. `height: 1.5` en :85, :91 y :97 ✓. MATIZ (núm…

#### 14 colores hardcodeados fuera del sistema en graficos y acciones rapidas, 6 de ellos inexistentes en la paleta

`lib/features/dashboard/presentation/widgets/financial_charts.dart:510` · **Alta** · esfuerzo S

`_pieColors` en financial_charts.dart:510-521 es una lista global de 10 `Color(0x...)`: seis duplican tokens existentes (006B5F=brand, FF735C=accent, 3B82F6=info, F59E0B=warning, 10B981=success, EF4444=error) y cuatro **no existen en la paleta** (8B5CF6 violeta, EC4899 rosa, 14B8A6 turquesa, 6366F1 indigo). Ademas home_tab.dart:301, :307, :313 y :319 definen cuatro colores por accion rapida, de los cuales 00C2B8 (turquesa) y F97316 (naranja) tampoco existen en AppColors. Es decoracion pura: cuatro botones de accion con cuatro colores distintos contradicen 'color solo cuando significa algo'.

**Corrección.** Definir en app_constants.dart una rampa explicita de series de datos (`AppColors.series1..series6`) derivada de la marca, ordenada por contraste y verificada para daltonismo, y que `_pieColors` la consuma. Las cuatro acciones rapidas de home_tab pasan a un unico color neutro (icono en `textSecondary` sobre superficie), reservando `success`/`error` solo para signo de dinero.

#### PagatePrimaryButton envuelve el CTA en un glow de marca y PagateSectionCard ramifica por brightness

`lib/core/widgets/pagate_primary_button.dart:30` · **Alta** · esfuerzo S · **bloquea publicación**

`PagatePrimaryButton` (14 usos, el boton principal de toda la app) envuelve el `ElevatedButton` en un `Container` cuya unica razon de existir es la sombra de marca: pagate_primary_button.dart:30-38 (`boxShadow: AppShadows.brand` condicionado a `hasShadow && isEnabled`), con la propiedad publica `hasShadow` por defecto en `true` (:14, :23). Sumado al `pillBorder` del `elevatedButtonTheme` (app_theme.dart:250) y a la altura 56 (app_constants.dart:188), el CTA es exactamente el 'boton pastilla con glow' prohibido. Por su parte `PagateSectionCard` (pagate_section_card.dart) usa radio 32 (`AppRadius.xxlBorder`, :24) y ramifica por tema (`Theme.of(context).brightness == Brightness.dark ? AppShadows.none : AppShadows.sm`, :29), rama que queda muerta al eliminar el oscuro.

**Corrección.** `PagatePrimaryButton`: borrar el Container y la propiedad `hasShadow`, devolver directamente el `ElevatedButton`; boton rectangular de radio `sm`, altura 44-48, sin sombra, peso w600. `PagateSectionCard`: radio `md`, borde de 1px `AppColors.border`, sin sombra, y eliminar el `if` de brightness. Revisar de paso `PagateSocialButton` (pagate_social_button.dart:22) que calcula su altura como `AppSizes.buttonHeight - 2`, aritmetica magica que debe salir de un token.

> *Matizado al verificar:* El diagnóstico técnico es exacto; el impacto está inflado. Confirmado: pagate_primary_button.dart:30-38 es `return Container(width: double.infinity, height: AppSizes.buttonHeight, decoration: hasShadow && isEnabled ? BoxDecoration(borderRadius: AppRadius.pillBorder, boxShadow: AppShadows.brand) : null, ...)`, con `final bool hasShadow;` en :14 y `this.hasShadow = true,` en :23; `AppSizes.buttonHeight = 56.0` en app_constants.dart:188; `AppRadius.pillBorder` en el elevatedButtonTheme en app_theme.dart:250. PagateSectionCard: `borderRadius: AppRadius.xxlBorder,` en :24 y el ternario `Theme.of(context).brightness == Brightness.dark ? AppShadows.none : AppShadows.sm` en :29-31 ✓. PagateSocialBu…

#### Falta la fila etiqueta-valor y hay 6 reimplementaciones a mano

`lib/features/finances/presentation/pages/finanzas_tab.dart:280` · **Alta** · esfuerzo M

El componente mas necesario de una app financiera densa -- la fila `etiqueta ....... valor` -- no existe en lib/core/widgets/, y cada pantalla lo ha reinventado: `_StatRow` (finanzas_tab.dart:280, icono en caja + label + monto), `_DetailRow` (detalle_item_screen.dart:383, label + valor + divider opcional), `_ContactRow` (ayuda_screen.dart:259), `_ItemRow` (configuracion_screen.dart:235), `_MiniStat` (home_tab.dart:247), `_StatItem` (perfil_tab.dart:208). Seis implementaciones con seis criterios distintos de peso, color y alineacion, y ninguna con cifras tabulares.

**Corrección.** Crear `PagateDataRow({label, value, valueStyle, leading, trailing, emphasis})` en lib/core/widgets/, con el valor en el estilo numerico tabular y alineado a la derecha, label en `textSecondary` a la izquierda, altura fija (44) y divider de 1px opcional. Migrar las 6 y borrarlas.

### Las cinco pantallas que se rediseñan

#### Bienvenida: 'Ver términos' es un callejón sin salida y no hay política de privacidad en la app

`lib/features/auth/presentation/pages/welcome_screen.dart:301` · **Crítica** · esfuerzo M · **bloquea publicación**

La línea 292 afirma 'Al continuar, aceptas nuestros Términos y Privacidad' y el `TextButton` de las líneas 301-307 responde con un snackbar: 'Puedes revisar los términos desde configuración'. En `configuracion_screen.dart` no hay ninguna sección de términos ni de privacidad. Un grep por 'érmino|Privacidad|privacy' en todo `lib/` devuelve exactamente 5 coincidencias: las 3 de esta pantalla y las 2 de `identity_step_screen.dart:214,219`. No existe ni pantalla, ni URL, ni webview. Google Play exige una política de privacidad enlazada y accesible para publicar.

**Corrección.** Publicar términos y privacidad como páginas en el dominio de la landing y abrirlas con `url_launcher` desde ambos puntos. Sustituir el snackbar por el enlace real y mantener el texto legal como una sola línea con dos enlaces tappables, no como dos afordancias compitiendo.

#### Registro: pantalla clara renderizada con el tema oscuro — separador invisible y hints ilegibles

`lib/features/onboarding/presentation/pages/identity_step_screen.dart:81` · **Crítica** · esfuerzo M · **bloquea publicación**

`app_shell.dart:28` fuerza `themeMode: ThemeMode.dark` globalmente. `welcome_screen.dart:28` se protege con `Theme(data: AppTheme.lightTheme)`, pero el `Navigator` está por encima de ese `Theme`, así que la ruta empujada en la línea 231 escapa del override. Esta pantalla pinta `backgroundColor: AppColors.surface` (blanco, línea 81) y se renderiza con `darkTheme`. Consecuencias verificadas: el `Divider()` de la línea 155 toma `dividerTheme.color = AppColors.glass` (`app_theme.dart:540`), blanco al 10% sobre blanco — invisible; los tres `PagateTextField` (122, 133, 145) toman `inputDecorationTheme` oscuro (`app_theme.dart:466-504`), relleno #3A4A6B con hints #64748B, contraste ~1.6:1; y `PagateStepHeader` dibuja el botón de volver como un círculo `AppColors.surface` con borde `borderLight` #F3F4F6 sobre fondo blanco, prácticamente invisible.

**Corrección.** Al eliminar el tema oscuro (decisión 2) desaparece la causa raíz: borrar `AppTheme.darkTheme`, poner `themeMode: ThemeMode.light` o quitar el parámetro, y borrar el `Theme(data: lightTheme)` de `welcome_screen.dart:28-31`. Revisar después que el divisor y el botón de volver tengan contraste real (`AppColors.border` #E5E7EB, no `borderLight`).

#### Onboarding: '800.000' se guarda como meta de 800 pesos

`lib/features/onboarding/presentation/pages/setup_inicial_screen.dart:58` · **Crítica** · esfuerzo M · **bloquea publicación**

Línea 58: `_goalController.text.replaceAll(',', '.')` y línea 59 `double.tryParse(rawGoal)`. Un usuario chileno teclea su meta mensual como '800.000' (separador de miles con punto) y `double.tryParse('800.000')` devuelve 800.0. La validación de la línea 77 (`goal == null || goal <= 0`) la deja pasar sin avisar. La meta queda en 800 pesos y contamina todo lo que la consume: `_GoalProgress` en finanzas (líneas 328-386) y la barra de la tarjeta de balance en inicio (líneas 211-227) marcarán 100% con la primera venta. Con ',' pasa lo mismo: '800,000' → '800.000' → 800.0. El mismo defecto está en el diálogo de gastos fijos de `finanzas_tab.dart:440`.

**Corrección.** Formateador de entrada que inserte separadores de miles mientras se escribe y un parser que quite los puntos de millar antes de `double.parse` (o `NumberFormat.decimalPattern('es_CL').parse`). Centralizar en `lib/core/utils/` y usarlo en los tres puntos de entrada de dinero (este, `finanzas_tab.dart:440`, `transaction_form_sheet.dart:117-122`).

#### Inicio: el balance se muestra como '$1234.6K' y un saldo negativo como '$-5000'

`lib/features/dashboard/presentation/pages/tabs/home_tab.dart:243` · **Crítica** · esfuerzo M · **bloquea publicación**

`_fmt` (líneas 243-244): `v >= 1000 ? '${(v/1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0)`. Con un balance de 1.234.567 devuelve '1234.6K' → la tarjeta principal muestra '$1234.6K' (línea 196). Con un balance negativo de -5000 no entra en la rama K y devuelve '-5000' → '$-5000' (el signo queda detrás del símbolo). El mismo formateador está copiado dos veces más en este archivo: inline en `_MiniStat` (línea 277) y en `_TransactionRow._fmt` (líneas 610-611). Finanzas usa un cuarto formateador distinto, `_money` (`finanzas_tab.dart:15-24`), que para el mismo saldo devuelve '$1.234.567'. Ninguno de los cuatro lee `profile.currency`, aunque el onboarding la persiste (`user_profile_provider.dart:107`): un usuario en USD ve exactamente el mismo formato que uno en CLP.

**Corrección.** Un único `lib/core/utils/currency_formatter.dart` con `NumberFormat.currency` de `intl` (ya está en pubspec), que reciba el `currency` del perfil, ponga el signo delante del símbolo y no abrevie en K. Sustituir los cuatro formateadores y los dos de `financial_charts.dart:499` y `pdf_report_service.dart`.

#### Bienvenida: tarjetas flotantes con métricas inventadas sobre el hero

`lib/features/auth/presentation/pages/welcome_screen.dart:146` · **Alta** · esfuerzo S · **bloquea publicación**

Dos `_FloatingStatsCard` flotan sobre el círculo del hero mostrando '+24%' con etiqueta 'GANANCIA' (líneas 146-156) y 'Optimizado' con etiqueta 'STOCK' (líneas 159-169). Son cifras fabricadas presentadas con el lenguaje visual de un dato real del usuario: icono de tendencia, etiqueta en mayúsculas, valor destacado. El widget completo (`_FloatingStatsCard`, líneas 320-387) existe solo para esto. Es exactamente el patrón prohibido (tarjetas de vidrio flotando sobre un hero + métricas inventadas) y además es riesgo de rechazo por 'misleading claims' en Play Store.

**Corrección.** Eliminar ambas `Positioned` y la clase `_FloatingStatsCard` completa (líneas 320-387). El hero de una fintech sobria no lleva ilustración con datos falsos: un titular fuerte alineado a la izquierda, un párrafo de una línea y el CTA.

> *Matizado al verificar:* Los hechos se confirman: welcome_screen.dart:146-156 `Positioned(right:10, top:100, child: _FloatingStatsCard(icon: Icons.trending_up, label: 'GANANCIA', value: '+24%'))` y :159-169 el de 'STOCK'/'Optimizado', ambos `const`, es decir literales fijos. La clase es privada y solo se usa ahí. Dos correcciones: (a) la clase va de la línea 321 (`class _FloatingStatsCard`) a la 388, no 320-387; (b) la ponderación está inflada. No hay nada en Play Policy que trate una ilustración de onboarding con cifras de ejemplo como 'misleading claim' —la política de Tergiversación apunta a afirmaciones sobre lo que la app hace, no a mock-ups decorativos—, y borrar dos `Positioned` no es un requisito de publica…

#### Bienvenida: en Android el único botón social visible es el stub de Apple

`lib/features/auth/presentation/pages/welcome_screen.dart:247` · **Alta** · esfuerzo M · **bloquea publicación**

`GoogleAuthService.isAvailable` es `kIsWeb` (`google_auth_service.dart:20`), así que el bloque `if (googleAvailable)` de las líneas 239-246 no se renderiza nunca en el APK. El botón de Apple (líneas 247-254) sí se renderiza siempre y al pulsarlo solo muestra 'Apple Sign-In estará disponible próximamente'. Resultado en el build que va a Play Store: el usuario ve dos opciones de arranque y una de ellas es un botón muerto. Además el icono de Google de la línea 242 es `Icons.g_mobiledata`, la 'G' genérica de Material, no la marca oficial que exigen las directrices de 'Sign in with Google'.

**Corrección.** Quitar el botón de Apple hasta que exista la integración (decisión 3: fuera stubs). Para Google: integrar `google_sign_in` con el asset oficial de marca, o no ofrecer login social en móvil y dejar solo correo. No dejar botones que solo informan de su propia ausencia.

> *Matizado al verificar:* Los hechos se confirman: google_auth_service.dart:20 `bool get isAvailable => kIsWeb;`, welcome_screen.dart:239-246 envuelve el botón de Google en `if (googleAvailable)`, y :247-254 renderiza siempre `PagateSocialButton(label:'Continuar con Apple', icon: Icons.apple, onPressed: () => AppFeedback.showMessage(context, 'Apple Sign-In estará disponible próximamente.'))`. El icono de :242 es `Icons.g_mobiledata`. Lo que no se sostiene es la ponderación: el registro por correo (`PagatePrimaryButton` :224-235 → IdentityStepScreen) funciona, así que el usuario nunca queda bloqueado; un botón social que avisa de su propia ausencia no cae en la política de Funcionalidad Mínima de Play, que apunta a a…

#### Registro: la sección 'Configuración Regional' entera es decorativa — el país no se puede tocar y la moneda se descarta

`lib/features/onboarding/presentation/pages/identity_step_screen.dart:159` · **Alta** · esfuerzo S

La sección de las líneas 159-197 ocupa ~130px y no produce ningún dato. `_buildCountrySelector` (líneas 259-302) es un `Container` con un icono de bandera, el texto fijo 'Chile' y un chevron `Icons.expand_more` que sugiere un desplegable: no tiene `GestureDetector`, `InkWell` ni `onTap` en ninguna línea, y el modelo de datos de `docs/ARQUITECTURA.md` no tiene campo `country`. `_selectedCurrency` (línea 26) sí cambia con los tabs de las líneas 318-347, pero `_onNext` (líneas 37-73) nunca lo lee: solo llama a `createUserWithEmailAndPassword` con nombre, correo y contraseña. Acto seguido `setup_inicial_screen.dart:31` vuelve a inicializar `_selectedCurrency = kDefaultCurrency` y pregunta la moneda por segunda vez (líneas 181-186), esta vez sí persistiéndola.

**Corrección.** Borrar la sección completa (159-197) y los dos builders (259-347). La moneda se pregunta una sola vez, en `setup_inicial_screen`. El país no se usa: si algún día hace falta, se deriva del `currency` o del locale del dispositivo.

#### Onboarding: fondo azul noche pegado a una pantalla de registro blanca

`lib/features/onboarding/presentation/pages/setup_inicial_screen.dart:102` · **Alta** · esfuerzo M · **bloquea publicación**

`backgroundColor: AppColors.backgroundDark` (#16213E) en la línea 102, y 8 tokens `*Dark` más (117, 125, 177, 236, 270, 273, 282). El usuario viene de `identity_step_screen.dart:81` que es blanco puro. Dos pantallas consecutivas del mismo flujo, sin transición ni justificación, con fondos opuestos. Además `_PillSelector` (línea 270) usa `surfaceDarkSecondary` y `PagateChipSelector` (línea 157) usa `colorScheme.surfaceContainerHighest`, que en `ColorScheme.dark()` no está definido en `app_theme.dart:408-421` y cae al gris neutro por defecto de M3 — ajeno a la paleta azul del resto.

**Corrección.** Reescribir con tokens claros al eliminar el tema oscuro. Fondo `AppColors.background`, tarjetas `surface`, bordes `border`.

> *Matizado al verificar:* El salto de fondo es real: setup_inicial_screen.dart:102 `backgroundColor: AppColors.backgroundDark` (#16213E en app_constants.dart:51) inmediatamente después de identity_step_screen.dart:81 `AppColors.surface` (#FFFFFF). Pero la cuenta y el diagnóstico de los chips fallan. (a) El grep de `Dark` en setup_inicial_screen.dart devuelve 8 líneas en total —102, 117, 125, 177, 236, 270, 273, 282—, es decir 7 *además* de la 102, no 8 más. (b) La afirmación sobre `PagateChipSelector` está refutada: pagate_chip_selector.dart:61 usa `colorScheme.surfaceContainerHighest`, y en el SDK que compila este proyecto (rev 9325183a…, el mismo de .metadata) color_scheme.dart:1278 define `Color get surfaceContai…

#### Inicio: tarjeta hero con degradado, glow verde y radio de 32px

`lib/features/dashboard/presentation/pages/tabs/home_tab.dart:154` · **Alta** · esfuerzo M · **bloquea publicación**

`_BalanceCard` (líneas 154-161) combina las cuatro cosas prohibidas a la vez: `gradient: AppColors.brandGradient` (línea 158), `borderRadius: AppRadius.xxlBorder` = 32px (línea 159) y `boxShadow: AppShadows.brandStrong` (línea 160), que es una sombra verde marca al 40% con 24px de blur — un glow de color. El avatar de la cabecera repite el degradado (línea 69). Es la tarjeta que define la identidad visual de la app y es literalmente el patrón de referencia que el dueño pidió eliminar.

**Corrección.** Fondo plano `surface`, borde 1px `border`, radio 12-16px, sin sombra de color. La jerarquía la da la tipografía: balance en 32-36px w800 negro, no un degradado.

> *Matizado al verificar:* Los hechos son exactos: home_tab.dart:154-161 `Container(... decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: AppRadius.xxlBorder, boxShadow: AppShadows.brandStrong))`, con `AppRadius.xxl = 32.0` (app_constants.dart:157) y `AppShadows.brandStrong = [BoxShadow(color: brand.withValues(alpha: 0.40), blurRadius: 24, offset: Offset(0,8))]` (app_constants.dart:257-263) — efectivamente un glow de color de marca. El avatar de :68-71 repite `gradient: AppColors.brandGradient`. Corrijo la ponderación: es una violación directa de la decisión 1 en el elemento más visible, pero no impide publicar nada ni rompe ninguna función; alta, no crítica bloqueante. La corrección propuest…

#### Inicio: punto rojo de notificaciones permanente que abre la pantalla de Ayuda

`lib/features/dashboard/presentation/pages/tabs/home_tab.dart:115` · **Alta** · esfuerzo S · **bloquea publicación**

Las líneas 115-126 dibujan un círculo de 8px en `AppColors.error` sobre la campana, sin ninguna condición: se renderiza siempre, en cada sesión, para cada usuario. No hay sistema de notificaciones en el repo. Y el `onNotificationsTap` que recibe (línea 108) está cableado en `dashboard_screen.dart:66` a `_openHelp`, que empuja `AyudaScreen`. Es decir: una campana con badge de no leídos permanente que abre la ayuda.

**Corrección.** Quitar el punto (115-126). Si el destino es la ayuda, usar `Icons.help_outline` y etiquetarlo como ayuda; si se quiere campana, que haya notificaciones de verdad.

> *Matizado al verificar:* Los hechos son 100% correctos y los verifiqué todos. home_tab.dart:115-126 `Positioned(top:10, right:10, child: Container(width:8, height:8, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)))` cuelga del `Stack` de :105 sin ninguna condición. El `onNotificationsTap` de :108 llega desde dashboard_screen.dart:64-67 `HomeTab(onQuickActionTap: _onQuickAction, onNotificationsTap: _openHelp)` y `_openHelp` (:93-98) empuja `AyudaScreen`. No hay sistema de notificaciones: grep de `firebase_messaging|FirebaseMessaging|flutter_local_notifications` sobre lib/ y pubspec.yaml devuelve 0 coincidencias. Lo único que corrijo es `bloquea_publicacion: true`: un badge decorativo…

#### Inicio: 'IA', 'Artesano' y 'Mi Negocio' como datos del usuario

`lib/features/dashboard/presentation/pages/tabs/home_tab.dart:74` · **Alta** · esfuerzo S

Línea 74: `profile?.avatarInitials ?? 'IA'` — las iniciales por defecto del avatar son literalmente 'IA'. No es solo el fallback de la pantalla: `user_profile_entity.dart:55` hace `return parts.isEmpty ? 'IA' : parts.join()`, así que la entidad también las genera. Línea 90: `'Hola, ${profile?.name.split(' ').first ?? 'Artesano'} 👋'` — nombre placeholder más emoji en el saludo. Línea 97: `profile?.businessName ?? 'Mi Negocio'`. Durante la carga del perfil, y ante cualquier error del stream, el usuario ve un avatar que dice 'IA' sobre 'Hola, Artesano 👋 / Mi Negocio' presentado como si fuera su perfil.

**Corrección.** Quitar el emoji. Mientras el perfil no ha cargado, mostrar un esqueleto o dejar el bloque vacío, no datos inventados. Cambiar el fallback de `initialsFor` a una inicial neutra derivada del correo, o a un icono.

#### Inicio: cuatro colores inventados fuera de la paleta en las acciones rápidas

`lib/features/dashboard/presentation/pages/tabs/home_tab.dart:297` · **Alta** · esfuerzo S

`_QuickActions._actions` (líneas 297-322) define cuatro colores con hex literales: `0xFF00C2B8` (turquesa, línea 301), `0xFFEF4444` (línea 307), `0xFF3B82F6` (línea 313) y `0xFFF97316` (naranja, línea 320). El turquesa y el naranja no existen en `AppColors`; los otros dos duplican `error` e `info`. `_ActionButton` (líneas 380-392) los usa a 15% de relleno y 30% de borde en un cuadrado de 52px con radio 20. El resultado es una fila arcoíris de cuatro iconos decorativos donde el color no significa nada — viola 'color solo cuando significa algo' y la regla de AGENTS.md de no hardcodear estilos. La cuarta acción es 'Preguntar IA' con `Icons.smart_toy_outlined` (líneas 318-320), el robot genérico.

**Corrección.** Fila de acciones monocroma con los iconos en `textPrimary` sobre fondo neutro, reservando el color solo para ingreso (verde) y gasto (rojo) porque ahí sí significa signo. Nada de hex inline. Cambiar el robot por un icono de conversación.

#### Inicio: los tres gráficos ocupan el 49% del scroll y empujan los movimientos fuera de pantalla

`lib/features/dashboard/presentation/pages/tabs/home_tab.dart:408` · **Alta** · esfuerzo M

`_ChartsSection` (líneas 408-435) apila `MonthlyBarChart` (220px de gráfico, `financial_charts.dart:37`), `NetBalanceLineChart` (200px, línea 193) y `CategoryPieChart` (140px, línea 349), cada uno dentro de un `_ChartCard` con 16px de padding, fila de título y 16px de separación (`financial_charts.dart:443-471`). Suman ~834px de los ~1.697px totales de la pantalla. En 360x800 el viewport útil es ~712px (sin SafeArea superior, menos 64px de barra inferior y ~24 de gesto). Medido por secciones: cabecera 68 + 16 + tarjeta de balance 209 + 24 + acciones 109 + 24 = 450px; el título 'Métricas Financieras' y el primer gráfico consumen los 262px restantes y el gráfico queda cortado. 'Actividad Reciente' empieza a los ~1.183px, es decir 1,7 viewports de scroll. Para llegar al final hacen falta ~3 gestos. Y dos de los tres gráficos muestran 'Aún no hay datos mensuales' hasta que el usuario tiene 2 meses registrados (`financial_charts.dart:30` y `:170`), así que en las primeras semanas ese 49% del scroll es espacio vacío con un mensaje.

**Corrección.** Bajar los gráficos por debajo de los movimientos o moverlos a Finanzas. En Inicio, una sola visualización compacta (sparkline de 60-80px del balance por mes) y, por encima, 6-8 movimientos reales. El objetivo declarado es densidad alta de información útil: hoy la primera pantalla entrega 4 cifras y 4 botones.

#### Inicio: la tarjeta de balance y los gráficos muestran ceros y estados vacíos cuando el stream falla

`lib/features/dashboard/presentation/pages/tabs/home_tab.dart:140` · **Alta** · esfuerzo S

`_BalanceCard.build` (líneas 140-241) lee `summary`, `hasData` y `goalProgress` pero no consulta `finances.error` ni `finances.isLoading` en ninguna línea. Ante un `permission-denied` o un fallo de red, `hasData` es false y la tarjeta muestra '$0' (línea 196), la etiqueta 'Sin datos' (línea 185) y el texto 'Registra tus primeros ingresos y gastos en Finanzas' (línea 232) — presenta un fallo como si el usuario no tuviera datos. Los tres gráficos hacen lo mismo: un grep de 'error' en `financial_charts.dart` solo devuelve las líneas 132 y 287, ambas usos de `AppColors.error` como color; `MonthlyBarChart` (línea 30) y `NetBalanceLineChart` (línea 170) caen a 'Aún no hay datos mensuales'. Solo `_RecentActivity` (línea 460) lo hace bien, con `PagateErrorState` y `finances.retry`. Contradice el principio 5 de docs/ARQUITECTURA.md.

**Corrección.** Replicar el patrón de `_RecentActivity` (líneas 460-465) en `_BalanceCard` y en los tres gráficos: si `finances.error != null`, `PagateErrorState` con `onRetry: finances.retry`; si `isLoading`, esqueleto.

#### Finanzas: se abre sin un solo movimiento a la vista — ~698px de tarjetas antes del primer dato

`lib/features/finances/presentation/pages/finanzas_tab.dart:213` · **Alta** · esfuerzo M

`_FinanzasBody` (líneas 213-235) apila cuatro bloques con 24px entre ellos. Medido: cabecera 140px (padding 24 + fila de título con IconButton 48 + 16 + chips 36 + 16), `_SummaryCard` 192px (padding 24x2 + tres `_StatRow` de 32px + dos `Divider(height: AppSpacing.xl)` de 24px, líneas 245-277), `_GoalProgress` 116px (líneas 334-385), `_FixedExpensesSection` ~132px vacío (líneas 505-571) y el título 'Movimientos del mes' 38px. Total ~698px sobre un viewport útil de ~712px en 360x800: el primer `_TransactionTile` (79px cada uno con su separación, líneas 797-853) aparece justo debajo del borde. Para ver 10 movimientos hacen falta ~1.488px, es decir 2,1 viewports. La pantalla que se llama Finanzas no muestra ninguna transacción sin scroll.

**Corrección.** Comprimir el resumen a una sola fila densa de tres cifras (ingresos / gastos / balance) con la meta como una barra fina debajo, ~120px en vez de 308. Colapsar gastos fijos a una línea con total y un chevron. Así los movimientos empiezan sobre los 300px y caben 5-6 en la primera pantalla.

#### Finanzas: el diálogo de gasto fijo pierde lo escrito al fallar y convierte '50.000' en 50

`lib/features/finances/presentation/pages/finanzas_tab.dart:398` · **Alta** · esfuerzo M · **bloquea publicación**

`_addExpense` (líneas 393-456) monta un `AlertDialog` con dos `TextField` sin validación: el botón 'Guardar' (líneas 430-433) cierra el diálogo con `Navigator.pop(dialogContext, true)` pase lo que pase. Después, en la línea 438, `final name = nameController.text;` se lee sin `trim()`, en la 440 `double.tryParse(amountController.text.trim().replaceAll(',', '.'))` convierte '50.000' en 50.0, y en las líneas 441-442 ambos controllers se liberan. Si el nombre está vacío o el monto es inválido, el provider lanza (`finances_provider.dart:201-207`), se muestra un snackbar y el usuario tiene que volver a abrir el diálogo y teclear todo otra vez. Además, con '50.000' no hay error: se guarda un gasto fijo de 50 pesos en silencio.

**Corrección.** Envolver en un `Form` con validadores y no cerrar hasta que `validate()` pase, o convertirlo en un bottom sheet con el mismo patrón que `transaction_form_sheet.dart` (que sí usa `_formKey.currentState?.validate()` en la línea 126). Usar el parser de miles centralizado.

> *Matizado al verificar:* Todo lo descrito es literal: `_addExpense` finanzas_tab.dart:393-456, `AlertDialog` en :400-435 con dos `TextField` sin `validator` y sin `Form`, botón 'Guardar' en :430-433 `ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true))` incondicional, :438 `final name = nameController.text;` sin `trim()`, :439-440 `double.tryParse(amountController.text.trim().replaceAll(',', '.'))`, :441-442 los dos `dispose()`. El provider rechaza después: finances_provider.dart:201-207 lanza `ArgumentError` si el nombre queda vacío o el monto no es > 0. Y `transaction_form_sheet.dart:126` sí hace `if (!(_formKey.currentState?.validate() ?? false)) return;`, o sea el patrón bueno ya existe. Dos mati…

#### Las cinco tabs del dashboard dibujan contenido bajo la barra de estado

`lib/features/dashboard/presentation/pages/dashboard_screen.dart:208` · **Alta** · esfuerzo S · **bloquea publicación**

`_buildMobileLayout` (líneas 205-239) pone `body: IndexedStack(children: _pages)` sin ningún `SafeArea`. El único `SafeArea` del archivo está en la línea 219 y es `top: false`, solo para la barra inferior. Grep de 'SafeArea' en `home_tab.dart` y `finanzas_tab.dart`: cero coincidencias. Inicio arranca con `_HomeHeader` cuyo padding superior es `AppSpacing.xl` = 24px (línea 57-62) y Finanzas con `_FinanzasHeader` igual (líneas 113-119). En un teléfono con barra de estado de 24-48dp, el avatar, el saludo y el título 'Finanzas' quedan parcial o totalmente bajo la barra. Con `targetSdk` heredado de Flutter (`android/app/build.gradle.kts:29`), Android 15 fuerza edge-to-edge y el solapamiento es total.

**Corrección.** Envolver el `IndexedStack` de la línea 208 en `SafeArea(bottom: false)`, o añadir `MediaQuery.paddingOf(context).top` al padding superior de cada cabecera. Verificar en un dispositivo con notch antes de subir el AAB.

#### Botones pastilla con glow e inputs de radio 32: el problema está en los tokens, no en las pantallas

`lib/core/theme/app_theme.dart:512` · **Alta** · esfuerzo M

El rediseño no se puede hacer solo en las cinco pantallas porque la forma prohibida está en el tema. `elevatedButtonTheme` usa `AppRadius.pillBorder` = 100 (línea 512 en oscuro, equivalente en claro), así que las 10 llamadas a `PagatePrimaryButton` del repo salen como pastillas; y `PagatePrimaryButton` (`pagate_primary_button.dart:30-38`) añade encima `AppShadows.brand`, una sombra verde marca al 25% con 16px de blur — el 'botón pastilla con glow' literal. `inputDecorationTheme` usa `AppRadius.xxlBorder` = 32 (líneas 470, 474, 481, 488) sobre campos de 56px de alto, casi pastillas. En las cinco pantallas hay además 9 usos directos de `xxlBorder` (3 en inicio, 4 en finanzas, 2 en registro) y 5 de `pillBorder`. `AppRadius` define `pill = 100` y `xxl = 32`, y `AppColors` expone `brandGradient`, `heroGradient`, `glass`, `glassStrong`, `fadeToWhite` y `fadeToBackground`: tokens de glassmorphism y degradados que invitan a reintroducir lo que se quiere quitar.

**Corrección.** Bajar la escala de radios a 4/8/12/16 y eliminar `pill` y `xxl`. Quitar `AppShadows.brand` y `brandStrong` y el `hasShadow` de `PagatePrimaryButton`. Borrar `brandGradient`, `heroGradient`, `glass`, `glassStrong` y los dos `fadeTo*`. Sin esto, cada pantalla rediseñada volverá a heredar la forma antigua.

### Las pantallas que solo se limpian

#### El monto "25.000" se guarda como 25 pesos, en silencio y sin error

`lib/features/finances/presentation/widgets/transaction_form_sheet.dart:118` · **Crítica** · esfuerzo M · **bloquea publicación**

_parseAmount hace raw.replaceAll(',', '.') y luego double.tryParse. El formateador de la linea 246 permite escribir tanto '.' como ','. En Chile el punto es separador de miles: si el usuario escribe "25.000" para veinticinco mil pesos, tryParse devuelve 25.0 y el formulario lo acepta como valido (validator linea 248-253 pasa, _submit linea 128-129 pasa) y guarda 25. No hay aviso ninguno. El caso "1.234,56" produce "1.234.56" y si falla, pero con el mensaje generico "Ingresa un monto valido", sin explicar el formato. Es la accion mas usada de la app y contamina transactions, el agregado months/ que calcula el trigger, los tres graficos, la meta mensual y el contexto que recibe la IA.

**Corrección.** Crear lib/core/utils/currency_formatter.dart (tarea C-2 del PLAN) con un parseAmount(String, {required String currency}) que normalice segun locale es-CL: quitar los puntos de miles, aceptar la coma como decimal y rechazar formatos ambiguos. Ademas formatear el campo mientras se escribe (1.234.567) para que el usuario vea lo que va a guardar, y bloquear decimales cuando la moneda es CLP.

#### No hay forma de eliminar la cuenta ni de leer Terminos/Privacidad dentro de la app

`lib/features/dashboard/presentation/pages/configuracion_screen.dart:122` · **Crítica** · esfuerzo M · **bloquea publicación**

Configuracion tiene cuatro secciones (Negocio, Metas, Seguridad, Notificaciones) y ninguna ofrece eliminar la cuenta ni enlaces legales. Verifique con grep en todo lib/: no existe ningun 'eliminar cuenta', 'deleteAccount' ni enlace a politica de privacidad en ninguna pantalla. Y welcome_screen.dart:304, al tocar 'Ver terminos', responde literalmente 'Puedes revisar los terminos desde configuracion.' — o sea, manda al usuario a una pantalla que no los tiene. La seccion Seguridad (lineas 123-132) solo tiene 'Cambiar contrasena'.

**Corrección.** Anadir a la seccion Seguridad: (a) 'Eliminar mi cuenta' con dialogo de confirmacion y reautenticacion, apoyado en el callable deleteAccount con recursiveDelete que ya esta planificado como S1-07; (b) filas 'Terminos de servicio' y 'Politica de privacidad' que abran las URLs publicadas. Corregir welcome_screen.dart:300-306 para que abra la URL real en vez del snackbar circular.

#### Boton "Continuar con Apple" muerto: en el APK de Play es el unico boton social y no hace nada

`lib/features/auth/presentation/pages/login_screen.dart:246` · **Alta** · esfuerzo S · **bloquea publicación**

PagateSocialButton('Continuar con Apple') se renderiza SIEMPRE, sin condicion de disponibilidad, y su onPressed (_onAppleSignIn, lineas 95-100) solo muestra el snackbar 'Apple Sign-In estara disponible proximamente.'. Peor: el boton de Google de la linea 238 esta condicionado a _googleAuth.isAvailable, que en google_auth_service.dart:20 es 'bool get isAvailable => kIsWeb'. En el build de Android que va a Play, isAvailable es false, asi que la pantalla muestra el separador 'o continua con' (lineas 217-233, incondicional) seguido unicamente del boton de Apple roto. El mismo stub esta duplicado en welcome_screen.dart:252.

**Corrección.** Borrar el boton de Apple de login_screen.dart y de welcome_screen.dart. Envolver tambien el separador 'o continua con' (217-233) en la misma condicion _googleAuth.isAvailable, para que en Android no quede un separador colgando sin nada debajo. Si se quiere Google en movil hay que integrar el paquete google_sign_in (P4-07); mientras tanto, login con correo y nada mas.

> *Matizado al verificar:* Los hechos son exactos y los confirmo uno a uno. login_screen.dart:246-250: `PagateSocialButton(label: 'Continuar con Apple', icon: Icons.apple_rounded, onPressed: _onAppleSignIn)`, sin ninguna condicion; `_onAppleSignIn` en :95-100 solo hace `AppFeedback.showMessage(context, 'Apple Sign-In estara disponible proximamente.')`. El de Google si esta condicionado: :238 `if (_googleAuth.isAvailable) ...[`, y google_auth_service.dart:20 es literalmente `bool get isAvailable => kIsWeb;`, luego en el build Android es false. El separador es incondicional: :217-233, con 'o continua con' en :225. El duplicado esta en welcome_screen.dart:248-253, con `final googleAvailable = GoogleAuthService().isAvail…

#### Tras actualizar el stock, el detalle del item sigue mostrando el valor viejo

`lib/features/inventory/presentation/pages/detalle_item_screen.dart:12` · **Alta** · esfuerzo M · **bloquea publicación**

DetalleItemScreen es StatelessWidget y recibe un InventoryItemEntity inmutable por constructor (linea 12-13), pasado desde inventario_tab.dart:401. _showUpdateStockDialog llama a provider.updateStock (linea 292), muestra 'Stock actualizado.' (linea 308) y cierra el dialogo, pero como la pantalla nunca observa el provider, el stock de la linea 166 ('{item.stock} / {item.minStock} min.'), el de la linea 194 y el color/etiqueta de estado (lineas 15-35) siguen mostrando el numero anterior. El usuario ve un mensaje de exito y un dato que lo contradice. Solo se corrige volviendo atras y reentrando.

**Corrección.** Cambiar la firma a DetalleItemScreen({required String itemId}) y obtener el item con context.watch<InventoryProvider>() buscandolo por id en cada build; si ya no existe (borrado), hacer pop. Actualizar la llamada en inventario_tab.dart:401. Es exactamente la tarea B2-03 del PLAN, aun pendiente.

#### hourly_rate_setup_page es el manifiesto del diseno IA: glassmorphism, degradado de fondo y animacion de entrada

`lib/features/hourly_value/presentation/pages/hourly_rate_setup_page.dart:10` · **Alta** · esfuerzo M

El propio docstring lo confiesa: lineas 10-11, 'Premium configuration page... Features: Gradient background, glassmorphism, smooth animations'. Contiene todo lo prohibido a la vez: degradado decorativo de fondo de tres paradas (lineas 158-169: backgroundDark -> brand al 10% -> backgroundDark), GlassCard envolviendo los campos (linea 231), chips con brandGradient en el icono de cabecera (linea 207) y en el numero del dialogo de exito (linea 127), y una animacion FadeTransition + SlideTransition de toda la pagina al entrar (lineas 34-56, 171-174).

**Corrección.** Reescribir la pagina completa: fondo plano, cabecera con back, tres campos con el PagateTextField estandar, el resultado del calculo como cifra grande alineada a la izquierda sobre fondo plano con borde discreto, y cero animacion de entrada. Borrar el AnimationController y las dos animaciones.

#### Tema oscuro cableado a mano en las 17 pantallas: 165 referencias a AppColors.*Dark

`lib/features/auth/presentation/widgets/app_shell.dart:28` · **Alta** · esfuerzo L

app_shell.dart:28 fuerza themeMode: ThemeMode.dark, y las pantallas no confian en el tema sino que hardcodean los tokens oscuros. Conte 165 referencias a AppColors.*Dark (backgroundDark, surfaceDark, surfaceDarkSecondary, borderDark, textPrimaryDark, textSecondaryDark, textTertiaryDark) repartidas en los 17 archivos de mi dimension: inventario_tab 22, ia_tab 19, detalle_item 15, ayuda 15, perfil_tab 14, financial_charts 13, editar_perfil 12, dashboard_screen 11, configuracion 9, hourly_rate_setup 7, transaction_form_sheet 6, login 5, bootstrap_error_app 4, session_error_view 3, splash 2, glass_card 2, premium_text_field 2. Con la decision de tema SOLO CLARO, cambiar app_shell a ThemeMode.light no arregla nada: las 165 pintan texto casi blanco (0xFFF1F5F9) sobre fondos claros y quedan ilegibles. bootstrap_error_app.dart:27 ademas instancia AppTheme.darkTheme directamente.

**Corrección.** Hacerlo en una sola pasada junto con el rediseno de las cinco pantallas grandes, no en dos: (1) dejar solo lightTheme en app_theme.dart y borrar darkTheme; (2) quitar los tokens *Dark de app_constants.dart; (3) sustituir cada color hardcodeado por el del tema (Theme.of(context).colorScheme / textTheme) en vez de por su gemelo claro, para no repetir el error. app_shell.dart:26-28 pasa a 'theme: AppTheme.lightTheme' sin darkTheme ni themeMode, y bootstrap_error_app.dart:27 igual.

#### Dato inventado "$830 extra" presentado como sugerencia de la IA

`lib/features/dashboard/presentation/pages/ayuda_screen.dart:100` · **Alta** · esfuerzo S · **bloquea publicación**

Tarjeta fija con icono de robot (smart_toy_outlined, linea 81), fondo brandGradient (linea 76) y el titulo 'Sugerencia del dia' (linea 89), cuyo texto es una constante escrita a mano: 'Reduce tus gastos fijos en 10% para ganar $830 extra este mes.' (linea 100). No lee ni un solo dato del usuario, no llama a la IA y la cifra no sale de ninguna parte. Es un dato inventado presentado como analisis real de la app, y ademas en una moneda ($830) que no tiene sentido en CLP. Ya estaba en la auditoria de septiembre (tarea B2-07) y sigue igual.

**Corrección.** Borrar la tarjeta completa (lineas 73-114) junto con el gradiente. Si en el futuro se quiere una sugerencia real, tiene que venir del callable chat con datos del usuario, no de una constante.

> *Matizado al verificar:* Los hechos son exactos al 100%: ayuda_screen.dart:73-114 es un `Container` con `gradient: AppColors.brandGradient` (:76), `Icon(Icons.smart_toy_outlined, ...)` (:81), titulo 'Sugerencia del dia' (:89) y el literal de :100 `'Reduce tus gastos fijos en 10% para ganar \$830 extra este mes.'`. Es una `const List`/literal en el arbol de widgets: no toca ningun provider ni el callable chat. Incluso esta subestimada su visibilidad: dashboard_screen.dart:66-67 enlaza `onNotificationsTap: _openHelp` y `_openHelp` (:94-99) empuja `AyudaScreen`, o sea la campana de Inicio lleva directo a esta tarjeta, no solo Perfil > Ayuda. Lo que corrijo es la ponderacion: `bloquea_publicacion: true` no se sostiene …

#### Moneda hardcodeada con "$" en 10 sitios: ignora profile.currency, sin separador de miles y con decimales en CLP

`lib/features/inventory/presentation/pages/inventario_tab.dart:435` · **Alta** · esfuerzo M

Diez puntos de mi dimension imprimen el simbolo dolar a mano y ninguno consulta profile.currency: inventario_tab.dart:435 ('\$${item.price.toStringAsFixed(2)}', ademas con 2 decimales, asi que un producto de 12000 CLP se ve '$12000.00'), detalle_item_screen.dart:190 (igual), perfil_tab.dart:116 (la meta como '$1200000', sin puntos de miles, y a tres centimetros de un _StatItem que dice 'Moneda: CLP' — se contradicen en la misma tarjeta), configuracion_screen.dart:98 y :111, financial_charts.dart:48, :90, :206 y :248 (ejes y tooltips de los tres graficos) y hourly_rate_setup_page.dart:131. La auditoria previa ya conto 5 implementaciones distintas de moneda; estas 10 siguen ahi.

**Corrección.** Implementar C-2 (lib/core/utils/currency_formatter.dart con formatCurrency(num, {required String currency}) usando NumberFormat de intl: CLP sin decimales y con punto de miles, USD con 2) y reemplazar los 10 sitios. El paquete intl ya esta en pubspec pero sin usar.

### Accesibilidad, contraste y adaptabilidad

#### Ningún control de solo icono tiene etiqueta para el lector de pantalla (TalkBack los anuncia como "botón" sin nombre)

`lib/core/widgets/pagate_back_button.dart:14` · **Alta** · esfuerzo S · **bloquea publicación**

En todo `lib/` hay CERO usos de `Semantics`, `semanticLabel`, `ExcludeSemantics` y `MergeSemantics`, y solo 3 `tooltip:` (ia_tab.dart:304, finanzas_tab.dart:135, finanzas_tab.dart:624). Verificado con `tester.ensureSemantics()` sobre el árbol real:

- `PagateBackButton` (pagate_back_button.dart:14): el nodo semántico es `SemanticsNode(Rect 40x40, actions: [tap])` — sin label y sin el flag `isButton`. TalkBack no dice nada al enfocarlo. Se usa en 4 pantallas: configuracion_screen.dart:35, ayuda_screen.dart:54, detalle_item_screen.dart:53 y editar_perfil_screen.dart:116 (aquí como `leading` del AppBar, sustituyendo al botón nativo que sí trae etiqueta localizada).
- Campana de notificaciones (home_tab.dart:107): `SemanticsNode(48x48, flags: [isButton, isEnabled])` — con flag de botón pero SIN label. Además el icono es una campana pero abre la pantalla de Ayuda, así que ni siquiera un label derivado del icono sería correcto.
- IconButton de editar del detalle de item (detalle_item_screen.dart:65): sin `tooltip`.
- FAB de agregar item (inventario_tab.dart:192): `FloatingActionButton` con solo `Icon(Icons.add_rounded)` y sin `tooltip`. Flutter no pone tooltip por defecto.
- Botón de enviar del chat (ia_tab.dart:376): `GestureDetector` con un `Icon(Icons.send_rounded)` dentro de un `Container` circular; sin label ni rol.
- Botón de cerrar del banner de error del chat (ia_tab.dart:302) sí tiene tooltip, pero es la excepción.

El análisis previo al lanzamiento de Google Play ejecuta el Accessibility Scanner y reporta "unlabeled clickable items" como hallazgo explícito; un revisor con TalkBack lo ve en la primera pantalla.

**Corrección.** Envolver cada control de solo icono en `Semantics(button: true, label: '...')` o, mejor, sustituir los `GestureDetector` por `IconButton`/`InkWell` con `tooltip`. Concretamente: `PagateBackButton` → `IconButton(tooltip: 'Volver', ...)` con `constraints` de 48x48; home_tab.dart:107 → `tooltip: 'Ayuda'` (y cambiar el icono a `help_outline`, porque hoy es una campana que no lleva a notificaciones); detalle_item_screen.dart:65 → `tooltip: 'Actualizar stock'`; inventario_tab.dart:192 → `tooltip: 'Agregar producto'`; ia_tab.dart:376 → `IconButton(tooltip: 'Enviar', onPressed: enabled ? onSend : null)`.

> *Matizado al verificar:* Los hechos son correctos y los verifiqué uno a uno. `grep -rn "Semantics\|semanticLabel\|semanticsLabel" lib/` devuelve CERO resultados. `grep -rn "tooltip:" lib/` devuelve exactamente 3: ia_tab.dart:304, finanzas_tab.dart:135, finanzas_tab.dart:624. Controles citados, comprobados en la línea exacta: pagate_back_button.dart:14 `Widget build(...) => GestureDetector(` con `Container` de `AppSizes.backButtonSize` (:17-18) y un `Icon(Icons.chevron_left_rounded)` (:27), sin envoltorio semántico; sus 4 usos existen en ayuda_screen.dart:54, configuracion_screen.dart:35, editar_perfil_screen.dart:116 (`leading: const PagateBackButton()`) y detalle_item_screen.dart:53. home_tab.dart:107 es `IconButt…

#### 19 controles construidos con GestureDetector: se anuncian como texto plano, no como botones, y no informan su estado de selección

`lib/features/dashboard/presentation/pages/dashboard_screen.dart:293` · **Alta** · esfuerzo M · **bloquea publicación**

Hay 19 `GestureDetector(` en `lib/` haciendo de botón, pestaña o fila de menú. `GestureDetector` solo aporta la acción `tap`: no marca `isButton`, ni `isSelected`, ni `isInMutuallyExclusiveGroup`. Verificado con `ensureSemantics()`:

- Acción rápida "Venta" (home_tab.dart:376): `SemanticsNode(78x71, actions: [tap], label: "Venta")` — sin `isButton`. TalkBack lo lee como una etiqueta de texto cualquiera.
- "Cerrar Sesión" (perfil_tab.dart:247): `SemanticsNode(312x70, actions: [tap], label: "Cerrar Sesión")` — igual, sin rol de botón y sin diálogo de confirmación.
- Fila de FAQ (ayuda_screen.dart:146): `actions: [tap]`, sin `isButton` ni `isExpanded`; no se sabe que es un acordeón.
- Pestaña de moneda CLP/USD (identity_step_screen.dart:320): `actions: [tap], label: "CLP"`, sin indicación de seleccionada.

El resto, todos con el mismo defecto: dashboard_screen.dart:293 (las 5 pestañas de la barra inferior — no se anuncian como pestaña ni cuál está activa), pagate_chip_selector.dart:49, pagate_step_header.dart:45, welcome_screen.dart:259, ayuda_screen.dart:265, configuracion_screen.dart:249, editar_perfil_screen.dart:185 y :235, ia_tab.dart:175 y :376, finanzas_tab.dart:163, inventario_tab.dart:299 y :397, setup_inicial_screen.dart:259.

**Corrección.** Para la barra de navegación (dashboard_screen.dart:293) usar `NavigationBar`/`NavigationDestination` de Material 3, que ya trae rol de pestaña, estado seleccionado y alto mínimo correcto. Para el resto, sustituir por `InkWell`/`TextButton`/`FilterChip` o envolver en `Semantics(button: true, selected: isSelected, ...)`. En el rediseño fintech conviene reemplazar las pastillas artesanales por `ChoiceChip`/`SegmentedButton`, que dan semántica y foco gratis.

#### La pantalla de Inicio se desborda con el tamaño de letra "Grande" de Android (1,3x), no hace falta llegar a 2x

`lib/features/dashboard/presentation/pages/tabs/home_tab.dart:165` · **Alta** · esfuerzo M · **bloquea publicación**

Desbordes verificados montando las pantallas reales con la fuente Manrope cargada y `TextScaler.linear()`:

| Pantalla | Archivo:línea | 1,3x | 1,5x | 2,0x @360 | 2,0x @320 |
|---|---|---|---|---|---|
| Inicio, cabecera "Balance del Mes" + pastilla del mes | home_tab.dart:165 | +13 px | +49 px | +54 px | +94 px |
| Inicio, fila Ingresos/Gastos (`_MiniStat`) | home_tab.dart:203 | — | — | +42 px | +82 px |
| Inicio, cabecera de los 3 gráficos | financial_charts.dart:454 | — | — | +4/+9/+37 px | +44/+49/+77 px |
| Login, "¿No tienes cuenta? / Crear cuenta" | login_screen.dart:255 | — | +19 px | +127 px | — |
| Detalle de item, fila de estado de stock | detalle_item_screen.dart:144 | — | — | +14 px | — |
| Detalle de item, filas Tipo/Precio/Stock | detalle_item_screen.dart:401 | — | — | +64/+74 px | — |
| Ayuda, cabecera con botón de volver | ayuda_screen.dart:52 | — | — | +8,2 px | — |

Causa común: `Row` con hijos de ancho intrínseco sin `Flexible`/`Expanded`. En home_tab.dart:165 son un `Text` y un `Container` con pastilla; en :203 dos `_MiniStat` separados por `SizedBox(width: AppSpacing.xl)`; en detalle_item_screen.dart:401 un `Row(mainAxisAlignment: spaceBetween)` con dos `Text` sueltos; en login_screen.dart:255 un `Text` y un `TextButton`.

(Comprobado también que NO se rompen: Finanzas, Perfil y el registro hasta 2,0x; y Bienvenida en 320x568, 360x640 y horizontal.)

**Corrección.** Envolver en `Flexible`/`Expanded` el hijo largo de cada `Row` citado y añadir `maxLines` + `overflow: TextOverflow.ellipsis` a los `Text` que no deban partirse. En home_tab.dart:203, cambiar el `Row` de dos `_MiniStat` por un `Wrap` o darles `Expanded`. En detalle_item_screen.dart:401, `Expanded(child: Text(label))` + `Flexible(child: Text(value, textAlign: right))`. Añadir un test de regresión que monte las 5 pantallas a 1,3x / 2,0x y falle si hay `RenderFlex overflowed` (el arnés ya existe y funciona).

#### Contraste: la paleta clara incumple WCAG en el placeholder, el estado deshabilitado, los bordes y 4 de los 5 colores semánticos

`lib/core/constants/app_constants.dart:58` · **Alta** · esfuerzo M · **bloquea publicación**

Ratios WCAG 2.1 calculados (no estimados) sobre los hex reales de `app_constants.dart`, para los pares que la app usa de verdad en el tema claro (el que sobrevive a la decisión "solo claro"). Umbrales: 4.5:1 texto normal, 3:1 texto grande e iconos/bordes.

| Par | Ratio | Veredicto | Dónde se usa |
|---|---|---|---|
| textDisabled #CBD5E1 sobre surface #FFFFFF | **1.48** | falla todo | drag handle de los sheets, app_theme.dart:346 |
| textOnBrand #FFFFFF sobre textDisabled #CBD5E1 (botón primario deshabilitado) | **1.48** | falla todo | app_theme.dart:241-242 |
| borderLight #F3F4F6 sobre surface #FFFFFF | **1.10** | falla (<3:1) | borde de todas las Card, app_theme.dart:182 |
| border #E5E7EB sobre surface #FFFFFF | **1.24** | falla (<3:1) | `outline`, bordes de inputs y botones |
| border #E5E7EB sobre background #F3F4F6 | **1.13** | falla (<3:1) | separadores sobre el fondo |
| warning #F59E0B sobre warningLight #FEF3C7 | **1.93** | falla todo | badges de stock bajo |
| warning #F59E0B sobre surface #FFFFFF | **2.15** | falla todo | icono y texto de aviso |
| success #10B981 sobre successLight #D1FAE5 | **2.24** | falla todo | montos de ingreso |
| textTertiary #9CA3AF sobre background #F3F4F6 | **2.31** | falla todo | textos terciarios |
| accent #FF735C sobre accentLight #FFF0ED | **2.41** | falla todo | acentos |
| **textTertiary #9CA3AF sobre surfaceSecondary #F8FAFC (placeholder de TODOS los inputs)** | **2.43** | falla todo | app_theme.dart:225-227 |
| accent #FF735C sobre background #F3F4F6 | **2.43** | falla todo | |
| success #10B981 sobre surface #FFFFFF | **2.54** | falla todo | |
| textTertiary #9CA3AF sobre surface #FFFFFF | **2.54** | falla todo | pagate_label.dart:22 (etiquetas de formulario en mayúsculas), pagate_text_field.dart:104 (icono del ojo), pagate_step_header.dart:106, welcome_screen.dart:271 y :295, identity_step_screen.dart:207, :278, :297 y :342 |
| accent #FF735C sobre surface #FFFFFF | **2.67** | falla todo | |
| accentDark #E85D47 sobre accentLight #FFF0ED | **3.11** | falla texto normal | |
| info #3B82F6 sobre infoLight #DBEAFE | **3.01** | falla texto normal | |
| error #EF4444 sobre errorLight #FEE2E2 | **3.08** | falla texto normal | |
| error #EF4444 sobre background #F3F4F6 | **3.42** | falla texto normal | |
| info #3B82F6 sobre surface #FFFFFF | **3.68** | falla texto normal | |
| error #EF4444 sobre surface #FFFFFF | **3.76** | falla texto normal | montos de gasto |
| textSecondary #6B7280 sobre background #F3F4F6 | **4.39** | falla por poco | el texto secundario del fondo de app |
| textSecondary #6B7280 sobre surfaceTertiary #F1F5F9 | **4.41** | falla por poco | |

Sí cumplen: textPrimary #16213E (14.44 / 15.89), brand #006B5F (6.43 sobre blanco, 5.61 sobre brandLight), textOnBrand sobre brand (6.43), textSecondary sobre blanco (4.83) y sobre surfaceSecondary (4.62).

**Corrección.** Oscurecer la rampa de grises y los semánticos: `textTertiary` a ~#6B7280 o eliminarlo y usar `textSecondary` (que a su vez conviene llevar a ~#5A6474 para que pase 4.5:1 también sobre `background`); `textDisabled` a ~#94A3B8 y, para el botón deshabilitado, usar fondo #E2E8F0 con texto #64748B (≈4.6:1); `border` a ~#D1D5DB o #9CA3AF donde el borde sea el único indicador del control (3:1); versiones "ink" de los semánticos para texto (success #047857, warning #B45309, error #B91C1C, info #1D4ED8) reservando los actuales solo para rellenos. Encaja con la dirección fintech sobria: menos color decorativo, más contraste real.

> *Matizado al verificar:* Recalculé las 24 filas con la fórmula WCAG 2.1 sobre los hex reales y NO encontré ni un solo error: 1.48 (textDisabled #CBD5E1 / #FFFFFF y blanco sobre textDisabled), 1.10 (borderLight #F3F4F6 / blanco), 1.24, 1.13, 1.93, 2.15, 2.24, 2.31, 2.41, 2.43, 2.43, 2.54, 2.54, 2.67, 3.11, 3.01, 3.08, 3.42, 3.68, 3.76, 4.39, 4.41; y los que aprueba: 15.89/14.44, 6.43, 5.61, 4.83, 4.62. Todos los tokens están donde dice: app_constants.dart:58-63 (textPrimary/textSecondary/textTertiary/textDisabled), :71-72 (border/borderLight), :35-42 (semánticos), :45-48 (fondos claros). Las anclas de tema también: app_theme.dart:182 `side: BorderSide(color: AppColors.borderLight)` en `cardTheme`, :191 `fillColor: A…

#### El tema oscuro está forzado y conviven pantallas diseñadas en claro: separadores y botones invisibles

`lib/features/auth/presentation/widgets/app_shell.dart:28` · **Alta** · esfuerzo L · **bloquea publicación**

`AppShell` fija `themeMode: ThemeMode.dark` (app_shell.dart:28) para toda la app, pero hay pantallas pintadas en claro por encima de ese tema:

- `WelcomeScreen` envuelve su cuerpo en `Theme(data: AppTheme.lightTheme, ...)` (welcome_screen.dart:28-31) — el comentario lo admite: "se fuerza el tema claro para que los botones y textos se vean".
- `IdentityStepScreen` usa `backgroundColor: AppColors.surface` (blanco, identity_step_screen.dart:81) pero hereda el tema oscuro del `MaterialApp` (se abre con `Navigator.push`, fuera del `Theme` local de Bienvenida). Consecuencias medidas sobre esos hex: el `Divider()` de identity_step_screen.dart:155 toma `dividerTheme` oscuro = `glass #1AFFFFFF` (blanco al 10%) sobre blanco → **1.10:1**, invisible; los `PagateTextField` se pintan con `fillColor: surfaceDarkSecondary #3A4A6B` (azul oscuro) sobre una página blanca.
- `PagateStepHeader` hardcodea `color: AppColors.surface` y `border: AppColors.borderLight` (pagate_step_header.dart:51-56): botón blanco con borde #F3F4F6 sobre fondo blanco → **1.10:1**, no se ve.
- En login_screen.dart:201 el enlace "¿Olvidaste tu contraseña?" usa `AppColors.brand #006B5F` sobre `backgroundDark #16213E` → **2.47:1**. Lo mismo el `CircularProgressIndicator` de splash_screen.dart:44 (brand sobre backgroundDark) y el borde `borderDark #3A4A6B` sobre `surfaceDark #1F283E` → **1.66:1**, por debajo del 3:1 que exige un borde que delimita un componente.
- El hint oscuro `textTertiaryDark #64748B` sobre `surfaceDarkSecondary #3A4A6B` (fillColor de los inputs en oscuro) da **1.86:1**.

La decisión del dueño es eliminar el tema oscuro por completo, así que esto no es un "bug de tema oscuro": es el trabajo de migración que hay que hacer y que hoy deja controles invisibles.

**Corrección.** Borrar `darkTheme` de app_theme.dart:398-560, quitar `darkTheme`/`themeMode` de app_shell.dart:27-28, borrar el bloque "Backgrounds (Dark theme)" y "Text (Dark theme)" de app_constants.dart:50-68 junto con `glass`/`glassStrong` (:77-78) y las pastillas de degradado, quitar el `Theme(data: AppTheme.lightTheme)` de welcome_screen.dart:28-31 y reescribir con tokens claros todas las pantallas que hoy usan `backgroundDark`/`surfaceDark`/`textPrimaryDark` (login, splash, setup, dashboard, los 5 tabs, configuración, editar perfil, ayuda, detalle de item, valor hora). Aprovechar para subir `borderDark`→`border` al nuevo valor con 3:1.

#### Formularios sin acción de teclado, sin autocompletado y con etiquetas no asociadas al campo

`lib/core/widgets/pagate_text_field.dart:26` · **Alta** · esfuerzo M

Verificado por búsqueda en todo `lib/`: hay **un solo** `textInputAction` (ia_tab.dart:344) y **cero** `autofillHints`. `PagateTextField` (constructor en pagate_text_field.dart:26-43) ni siquiera expone `textInputAction`, `onFieldSubmitted`, `autofillHints` ni `textCapitalization`, así que ninguna pantalla puede ponerlos.

Consecuencias concretas:
- En login (login_screen.dart:179-191) y registro (identity_step_screen.dart:122-150) el teclado muestra "intro" en vez de "siguiente/listo" y no hay salto entre campos; el usuario debe cerrar el teclado y tocar el campo siguiente.
- Sin `autofillHints: [AutofillHints.email]` / `[AutofillHints.newPassword]` / `[AutofillHints.password]`, el gestor de contraseñas de Android y Google Password Manager no rellenan ni ofrecen guardar la credencial recién creada.
- Las etiquetas visibles no están asociadas al campo: se dibujan como un `Text` aparte (`PagateLabel`) encima de un input que solo lleva `hintText`. Ejemplos: identity_step_screen.dart:120+122, :131+133, :143+145; editar_perfil_screen.dart:135+144, :153+162, :272+281; transaction_form_sheet.dart:214+216, :223+225, :236+238, :257+259, :266+268, :271+273. El lector anuncia dos nodos sin relación, y al escribir el placeholder desaparece y el campo se queda sin nombre.
- Los formularios en sheets y diálogos van directamente sin etiqueta, solo `hintText`: inventario_tab.dart:56-96 (5 campos), finanzas_tab.dart:409 y :416, detalle_item_screen.dart:260.

Bien: los campos de monto sí usan teclado numérico (`numberWithOptions(decimal: true)` en transaction_form_sheet.dart:242, inventario_tab.dart:67/77/86, editar_perfil_screen.dart:285, setup_inicial_screen.dart:191, finanzas_tab.dart:418, hourly_rate_setup_page.dart:238/257/276) y el sheet de transacción descuenta `viewInsets.bottom` (transaction_form_sheet.dart:168-170), así que el teclado no tapa el campo activo.

**Corrección.** Añadir a `PagateTextField` los parámetros `textInputAction`, `onFieldSubmitted`, `autofillHints` y `focusNode`, y pasar `labelText` en vez de `PagateLabel` + `hintText` (o envolver etiqueta y campo en `Semantics(label: ...)` si se quiere mantener la etiqueta arriba, que además encaja mejor con la densidad fintech). Cablear `TextInputAction.next` entre campos y `done` en el último, con `FocusScope.of(context).nextFocus()`. Envolver login y registro en `AutofillGroup` con los `autofillHints` correspondientes.

#### Botones de guardar sin estado de carga: se pueden pulsar dos veces y duplicar datos

`lib/features/inventory/presentation/pages/inventario_tab.dart:98` · **Alta** · esfuerzo S

- inventario_tab.dart:98-148: el `PagatePrimaryButton('Guardar item')` no recibe `isLoading` y su `onPressed` es un `async` que espera `provider.addItem(...)` sin deshabilitarse. `PagatePrimaryButton` sí soporta `isLoading` (pagate_primary_button.dart:22, :28) pero aquí no se usa. Dos toques seguidos crean dos items en Firestore.
- finanzas_tab.dart:430-433: el `ElevatedButton('Guardar')` del diálogo de gasto fijo cierra el diálogo con `Navigator.pop(dialogContext, true)` y la escritura ocurre después (línea 446) sin ningún indicador; tampoco valida el monto, así que un campo vacío llega como `amount ?? 0` (línea 446) y las reglas de Firestore lo rechazan con un error genérico.
- detalle_item_screen.dart:280-311: el `ElevatedButton('Guardar')` del diálogo de stock ejecuta `await provider.updateStock(...)` dentro del `onPressed` sin bloquear el botón.
- welcome_screen.dart:240-244: `PagateSocialButton('Continuar con Google')` llama a `_signInWithGoogle` (welcome_screen.dart:15-23) sin ningún estado de carga; `PagateSocialButton` ni siquiera acepta `isLoading` (pagate_social_button.dart:7-17).

Bien: login (login_screen.dart:210), registro (identity_step_screen.dart:249), onboarding (setup_inicial_screen.dart:205), sheet de transacción (transaction_form_sheet.dart:284, con guarda `if (_saving) return` en :125) y editar perfil (editar_perfil_screen.dart:295) sí gestionan el doble envío.

**Corrección.** Convertir el sheet de inventario en un `StatefulWidget` con `_saving` y pasar `isLoading: _saving` + `onPressed: _saving ? null : ...`; añadir `isLoading` a `PagateSocialButton`; en los dos diálogos, mover la escritura a un `StatefulBuilder` con bandera de guardado o cerrar el diálogo solo tras el `await`. Copiar el patrón de `transaction_form_sheet.dart:124-131`, que ya es el correcto.

### Estructura y salud del código Flutter

#### El parseo de montos no entiende el formato chileno: '150.000' se guarda como 150

`lib/features/finances/presentation/widgets/transaction_form_sheet.dart:117` · **Crítica** · esfuerzo M · **bloquea publicación**

`_parseAmount` (linea 117-122) hace `raw.trim().replaceAll(',', '.')` y `double.tryParse`. El inputFormatter de la linea 245-247 permite explicitamente `[0-9.,]`. Con '150.000' (como lo escribe cualquier usuario chileno) tryParse devuelve 150.0 y la transaccion se guarda con 150 pesos sin ningun aviso; con '1.234,56' devuelve null y el formulario dice 'Ingresa un monto valido' sin explicar por que. Ademas hay 5 convenciones incompatibles en el repo: replaceAll(',', '.') en transaction_form_sheet.dart:118, finanzas_tab.dart:439-440, inventario_tab.dart:103, editar_perfil_screen.dart:60 y setup_inicial_screen.dart:58; y replaceAll(',', '') en hourly_rate_setup_page.dart:74. En finanzas_tab.dart:446 el resultado nulo se convierte en `amount ?? 0`, que firestore.rules rechaza con permission-denied porque exige amount > 0.

**Corrección.** Crear `lib/core/utils/amount_parser.dart` con un unico `double? parseAmount(String raw, {required String currency})` que quite los separadores de miles y normalice la coma decimal segun la moneda (CLP: sin decimales; USD: 2), y usarlo en los 6 sitios. En finanzas_tab.dart:446 no pasar 0: abortar y avisar.

#### No existe ruta a Politica de privacidad ni a borrado de cuenta: Google Play lo exige

`lib/features/dashboard/presentation/pages/configuracion_screen.dart:133` · **Crítica** · esfuerzo M · **bloquea publicación**

configuracion_screen.dart tiene las secciones Perfil, Metas, Seguridad y Notificaciones (lineas 40-157) y ninguna entrada de Terminos, Privacidad ni Eliminar cuenta. welcome_screen.dart:301-307 tiene un boton 'Ver terminos' que responde con el snackbar 'Puedes revisar los terminos desde configuracion', lo cual es falso porque ahi no hay nada. identity_step_screen.dart:213-221 pinta 'Terminos' y 'Privacidad' en color de marca como si fueran enlaces, pero son TextSpan sin recognizer: no son pulsables. Google Play exige un enlace accesible a la politica de privacidad y, para toda app que permita crear cuenta, una via de borrado de cuenta dentro de la app. Grep confirma que no hay ningun `url_launcher`, ni callable `deleteAccount`, ni pantalla de terminos en todo lib/.

**Corrección.** Anadir en Configuracion una seccion 'Legal' con Terminos y Privacidad (abriendo URLs publicas con url_launcher, que hay que anadir a pubspec) y una seccion 'Cuenta' con 'Eliminar mi cuenta' que llame al callable `deleteAccount` previsto en PLAN.md S1-07. Hacer pulsables los TextSpan de identity_step_screen.dart:213-221 con TapGestureRecognizer y quitar el boton falso de welcome_screen.dart:301-307.

#### La pantalla de registro esta pintada en claro pero corre bajo ThemeMode.dark

`lib/features/onboarding/presentation/pages/identity_step_screen.dart:81` · **Alta** · esfuerzo S · **bloquea publicación**

app_shell.dart:28 fija `themeMode: ThemeMode.dark` para toda la app. IdentityStepScreen se monta bajo ese AppShell y pinta `backgroundColor: AppColors.surface` (blanco, linea 81) con `AppColors.textPrimary` (azul oscuro). Pero sus `PagateTextField` heredan el `inputDecorationTheme` de darkTheme (app_theme.dart:466-468: `fillColor: AppColors.surfaceDarkSecondary` = #3A4A6B) y pintan el texto con `theme.colorScheme.onSurface` (pagate_text_field.dart:69), que en darkTheme es #F1F5F9: texto casi blanco sobre relleno azul marino, dentro de una tarjeta blanca. El `Divider()` de la linea 155 usa `dividerTheme.color = AppColors.glass` (blanco al 10%), o sea invisible sobre blanco. WelcomeScreen evita el problema envolviendose a mano en `Theme(data: AppTheme.lightTheme)` (welcome_screen.dart:28-31); IdentityStepScreen no lo hace. Es la primera pantalla del embudo de alta.

**Corrección.** Con la decision de tema unico claro esto se resuelve solo al borrar darkTheme y dejar `theme: AppTheme.lightTheme` sin `themeMode`. Mientras tanto, y como regla permanente: ninguna pantalla debe fijar colores de fondo o texto contra tokens de una paleta distinta a la del ThemeData activo.

#### El tema es decorativo: 254 colores hardcodeados en widgets y un darkTheme incompleto

`lib/core/theme/app_theme.dart:398` · **Alta** · esfuerzo L · **bloquea publicación**

Hay 254 referencias a tokens `AppColors.*Dark*` escritas directamente en widgets, repartidas en 21 archivos (finanzas_tab 42, inventario_tab 23, ia_tab 19, home_tab 17, detalle_item_screen 16, perfil_tab 15, ayuda_screen 15, editar_perfil 14, financial_charts 13, dashboard_screen 11, configuracion 9, y 10 archivos mas). La causa es que `darkTheme` (lineas 398-560) solo define appBar, card, bottomNavigationBar, inputDecoration, elevatedButton, outlinedButton, divider, bottomSheet y progressIndicator: le faltan `chipTheme`, `dialogTheme`, `snackBarTheme`, `textButtonTheme` y `sliderTheme`, que `lightTheme` si tiene (lineas 287-395). Por eso cada AlertDialog se repinta a mano (finanzas_tab.dart:401, :866; detalle_item_screen.dart:255, :323; hourly_rate_setup_page.dart:97). Consecuencia para la decision de producto: pasar a tema claro no es tocar app_shell.dart:28, son 254 sustituciones repartidas por toda la capa de presentacion.

**Corrección.** Orden: (1) borrar `darkTheme` (app_theme.dart:396-560) y el `darkTheme`/`themeMode` de app_shell.dart:27-28 y bootstrap_error_app.dart:27; (2) completar lightTheme con dialogTheme, snackBarTheme, chipTheme y textButtonTheme con la paleta clara sobria; (3) sustituir las 254 referencias `*Dark` por `Theme.of(context).colorScheme.*` o por los tokens claros equivalentes, archivo por archivo empezando por los 5 de rediseno; (4) borrar del AppColors los 12 tokens de la seccion oscura para que nadie pueda volver a usarlos.

> *Matizado al verificar:* El recuento total es exacto pero mal atribuido. `grep -rhoE "AppColors\.[A-Za-z]*Dark[A-Za-z]*" lib/ | sort | uniq -c` da exactamente 254 (textSecondaryDark 84, textPrimaryDark 56, borderDark 47, surfaceDark 36, backgroundDark 15, surfaceDarkSecondary 10, textTertiaryDark 3, brandDark 2, accentDark 1). Pero 22 de esas 254 estan dentro del propio lib/core/theme/app_theme.dart, donde son legitimas: en widgets hay 232, en 20 archivos, no 254 en 21. Ademas `brandDark`/`accentDark` (3 refs) no son tokens de tema oscuro, son tonos de marca. Los conteos por archivo si son todos correctos (finanzas_tab 42, inventario_tab 23, ia_tab 19, home_tab 17, detalle_item 16, perfil_tab 15, ayuda 15, editar_p…

#### Metricas y estados inventados visibles en la interfaz

`lib/features/auth/presentation/pages/welcome_screen.dart:154` · **Alta** · esfuerzo S · **bloquea publicación**

welcome_screen.dart:146-169: dos tarjetas flotando sobre el hero con 'GANANCIA +24%' (linea 154) y 'STOCK Optimizado' (linea 167), valores constantes que no salen de ningun dato. welcome_screen.dart:202: 'La primera herramienta financiera disenada por y para artesanos', afirmacion de primacia sin respaldo. ayuda_screen.dart:100: 'Reduce tus gastos fijos en 10% para ganar $830 extra este mes' presentado bajo el rotulo 'Sugerencia del dia' con icono de IA, cuando es un string literal. home_tab.dart:115-126: un punto rojo de notificacion pendiente dibujado incondicionalmente, sin ninguna condicion que lo apague, y cuyo tap abre AyudaScreen (dashboard_screen.dart:66). Todo esto choca de frente con la decision de producto (prohibido metricas inventadas y superlativos vacios) y las dos primeras pueden ser senaladas como afirmacion enganosa en la revision de Play.

**Corrección.** Borrar las dos tarjetas flotantes y el hero ilustrado completo (welcome_screen.dart:107-172), reescribir el titular sin superlativo, eliminar la tarjeta de 'Sugerencia del dia' de ayuda_screen.dart:73-114 o conectarla al callable `chat` con datos reales, y quitar el punto rojo de home_tab.dart:115-126 hasta que exista un contador real de notificaciones.

#### La moneda elegida en el registro se descarta y el paso dice '1 de 3' cuando solo hay 2

`lib/features/onboarding/presentation/pages/identity_step_screen.dart:26` · **Alta** · esfuerzo S · **bloquea publicación**

`_selectedCurrency` se declara en la linea 26 y se escribe en :321-324 al pulsar CLP/USD, pero `_onNext()` (lineas 37-73) solo llama a `createUserWithEmailAndPassword`: el valor nunca llega a Firestore. El usuario elige moneda y se pierde. Luego `SetupInicialScreen` vuelve a preguntarla (setup_inicial_screen.dart:31, :88) y esa si se guarda. Ademas `PagateStepHeader(currentStep: 1, totalSteps: 3)` en la linea 86-90 promete tres pasos: el segundo es SetupInicialScreen, que ni siquiera usa PagateStepHeader (no aparece en ese archivo), y no existe un tercero. El doc del propio componente (pagate_step_header.dart:11-12) dice 'All three onboarding screens MUST use this component' y solo lo usa una.

**Corrección.** Quitar de la pantalla de registro el bloque 'Configuracion Regional' entero (lineas 158-197, selectores de pais y moneda) y dejar solo nombre, correo y contrasena; la moneda ya se pide en el paso siguiente. Poner `totalSteps: 2` y anadir PagateStepHeader(currentStep: 2, totalSteps: 2) en setup_inicial_screen, o eliminar el indicador de pasos.

#### DetalleItemScreen recibe la entidad congelada: tras actualizar stock muestra el valor viejo

`lib/features/inventory/presentation/pages/detalle_item_screen.dart:12` · **Alta** · esfuerzo S

El constructor recibe `required this.item` (lineas 12-13) y toda la pantalla lee de esa copia inmutable: `item.stock` en :166 y :194, `item.price` en :190, `item.stockStatus` en :16 y :27. `_showUpdateStockDialog` llama a `provider.updateStock(itemId: item.id, newStock: stock)` (:292) y cierra el dialogo, pero como la pantalla es StatelessWidget y no observa el provider, se queda mostrando el stock anterior hasta que el usuario retrocede y vuelve a entrar. Lo pushea inventario_tab.dart:398-402 pasandole el objeto.

**Corrección.** Cambiar la firma a `DetalleItemScreen({required this.itemId})`, y en build hacer `context.watch<InventoryProvider>().allItems.firstWhereOrNull((i) => i.id == itemId)`, con estado vacio si el item se borro. Ajustar el push en inventario_tab.dart:401. De paso `allItems` (inventory_provider.dart:49), hoy muerto, pasa a tener uso.

### Backend, reglas y coste

#### No existe borrado de cuenta ni URL pública de eliminación de datos (requisito obligatorio de Google Play)

`functions/src/index.ts:5` · **Crítica** · esfuerzo M · **bloquea publicación**

`index.ts:5-7` exporta solo `chat`, `onTransactionWritten` y `waitlist`: no hay callable `deleteAccount` ni endpoint HTTP de eliminación. En el cliente, `lib/features/dashboard/presentation/pages/configuracion_screen.dart` (297 líneas) solo tiene las secciones Negocio, Metas, Seguridad (solo 'Enviar correo de restablecimiento', línea 128-129) y Notificaciones (dos stubs 'Próximamente', líneas 140 y 150): no hay ninguna opción de eliminar la cuenta. Fuera de la app tampoco: `landing/src/App.tsx` es una página única sin router y `landing/src/components/Footer.tsx:22-23` tiene 'Términos' y 'Privacidad' con `href: '#'`. Google Play exige desde 2023 (Data deletion policy) dos caminos para cualquier app que permita crear cuenta: (1) una opción dentro de la app y (2) una URL accesible desde fuera, declarada en la ficha de Play. Hoy faltan los dos, más la política de privacidad, que también es obligatoria. La revisión de Play rechaza el envío.

**Corrección.** Implementar callable `deleteAccount` en `functions/src/` (región `southamerica-west1`, `secrets: []`, `maxInstances` bajo) que: exija `request.auth` y reautenticación reciente (`auth_time` dentro de 5 min), borre en cascada con `getFirestore().recursiveDelete(db.doc('users/'+uid))` —cubre `inventory`, `transactions`, `fixedExpenses`, `months`, `meta/usage` y `conversations/{id}/messages`, que `recursiveDelete` sí recorre—, borre después el usuario de Auth con `getAuth().deleteUser(uid)`, y registre la operación. Añadir en `configuracion_screen.dart` una sección 'Cuenta' con 'Eliminar mi cuenta' + diálogo de confirmación con texto explícito de qué se borra. Publicar en la landing una ruta estática `/eliminar-cuenta` y `/privacidad` (basta con añadir `landing/public/eliminar-cuenta.html` y `privacidad.html`, que Vite copia a `dist/` y el workflow `landing-pages.yml` publica) describiendo qué datos se guardan, cómo pedir el borrado sin instalar la app y en cuánto tiempo se ejecuta. Declarar esa URL en Play Console → Data safety.

#### `functions/.env` versiona y despliega `ENFORCE_APP_CHECK=false`: `chat` queda abierto a cualquier cuenta autoregistrada y se factura al dueño

`functions/.env:2` · **Crítica** · esfuerzo M · **bloquea publicación**

F0-05 creó el archivo pero con el valor apagado. `functions/.env:2` dice `ENFORCE_APP_CHECK=false`, el archivo está **rastreado por git** (`git ls-files functions/` lo lista; `.gitignore:68` lo desexcluye con `!functions/.env`) y **sí se sube en el deploy** (`firebase.json:44-51` solo ignora `node_modules`, `.git`, `test`, los `firebase-debug*.log` y `*.local`). El CLI lee ese `.env` y fija el parámetro, así que producción despliega con App Check desactivado. El efecto en `functions/src/chat.ts:152` es que la rama `if (ENFORCE_APP_CHECK.value() && !request.app)` nunca se evalúa, y `chat` queda protegido únicamente por `request.auth` (chat.ts:149). Cadena de abuso verificada en el código: (1) el registro por email está abierto y `lib/core/services/firebase_auth_service.dart:44-49` no llama a `sendEmailVerification`, así que cualquiera crea cuentas contra Identity Toolkit con la API key pública; (2) `chat` no exige que exista `users/{uid}` —en chat.ts:179-180 `profile` puede ser `undefined` y `planOf` devuelve `'free'`—, de modo que una cuenta recién creada, sin onboarding, ya puede chatear; (3) la cuota es de 30 mensajes/día por cuenta (chat.ts:26). Coste por llamada: hasta 20 mensajes de historial (chat.ts:24 y :218) de hasta 2.000 caracteres cada uno (chat.ts:23) más 1.024 tokens de salida (`functions/src/openrouter.ts:61`), o sea ~10-15k tokens de entrada al final de una conversación llena. Una cuenta que agota su cuota maximizando el prompt consume del orden de 750.000 tokens de entrada y 30.000 de salida al día; 1.000 cuentas (script trivial) son ~780M tokens/día, además de 30.000 invocaciones y ~120.000 escrituras en Firestore. El techo real no es la cuota sino `maxInstances` (ver hallazgo aparte). Y no hay observabilidad: `openrouter.ts:33-36` ni siquiera lee el campo `usage` de la respuesta, y PLAN.md:26 deja F0-04 (plan Blaze + alertas de presupuesto USD 5/20 + clave de OpenRouter con tope de gasto) en estado `todo`.

**Corrección.** Antes de publicar: registrar App Check en consola (Play Integrity con el SHA-256 del keystore de release, reCAPTCHA v3 para web), poner `ENFORCE_APP_CHECK=true` en `functions/.env` y además `enforceAppCheck: true` en las opciones de `onCall` de chat.ts:137-146 para que el runtime rechace antes de ejecutar código. En paralelo y con independencia de App Check: exigir en `chat` que `users/{uid}` exista y que `request.auth.token.email_verified === true`; configurar en OpenRouter una clave con límite de gasto duro; crear las alertas de presupuesto de F0-04; y registrar en cada llamada el `usage` que devuelve OpenRouter (`prompt_tokens`/`completion_tokens`) con `logger.info` para poder ver el gasto por uid.

> *Matizado al verificar:* El fondo es real y grave, pero la causa está mal atribuida. Comprobado: `functions/.env` (con CRLF) tiene tres líneas y la :2 es `ENFORCE_APP_CHECK=false`; `git ls-files functions/` lista `functions/.env`; `.gitignore:68` es `!functions/.env` (la línea citada es exacta); `firebase.json:44-51` ignora solo `node_modules`, `.git`, `test`, `firebase-debug.log`, `firebase-debug.*.log` y `*.local`. `chat.ts:152` es `if (ENFORCE_APP_CHECK.value() && !request.app)` y `chat.ts:149` `if (!request.auth)`. La cadena de abuso también se sostiene: `firebase_auth_service.dart:44-58` crea la cuenta y como mucho llama `updateDisplayName` (:55), nunca `sendEmailVerification`; `chat.ts:179-180` (`const profil…

#### `firestore.rules:98` permite que el cliente borre `users/{uid}` y deje huérfanas todas las subcolecciones

`firestore.rules:98` · **Alta** · esfuerzo S · **bloquea publicación**

`allow delete: if isOwner(uid);` en el documento raíz del usuario. En Firestore borrar un documento NO borra sus subcolecciones: quedarían vivas `inventory/`, `transactions/`, `fixedExpenses/`, `months/`, `meta/usage` y `conversations/{id}/messages` sin ningún documento padre y, sobre todo, sin ninguna vía de acceso desde el cliente (las reglas de las subcolecciones siguen concediendo acceso por uid, pero la UI ya no tendría perfil). El usuario de Firebase Auth tampoco se borra. Peor aún para Play: si mañana se conecta un botón 'eliminar cuenta' a este `delete`, la app declarará que borra los datos y en realidad los conservará indefinidamente, lo que es una declaración falsa en Data safety. `functions/test/rules.test.ts` no cubre este caso (no hay ningún `it()` sobre el delete de `users/{uid}`).

**Corrección.** Cambiar a `allow delete: if false;` y dejar el borrado exclusivamente en manos del callable `deleteAccount` con `recursiveDelete` (Admin SDK, que no pasa por reglas). Añadir en `functions/test/rules.test.ts` un caso que verifique que el dueño NO puede borrar su propio documento de usuario.

> *Matizado al verificar:* La línea es exacta: `firestore.rules:98` dice `allow delete: if isOwner(uid);` dentro de `match /users/{uid} {` (:94). El comportamiento de Firestore que describe es correcto (borrar el documento no borra subcolecciones) y las subcolecciones siguen accesibles por uid (`inventory` :119-122, `transactions` :143-146, `fixedExpenses` :158-161, `months` :165-168, `conversations` :170-178, `meta` :180-183). También es cierto que `functions/test/rules.test.ts` no lo cubre: en el bloque `describe('users/{uid}')` (:121) los `it()` están en las líneas 122, 127, 132, 136, 145, 150, 157, 164 y 170 y ninguno prueba el delete del documento raíz. Matizo dos cosas. (1) Severidad inflada a crítica: hoy NO e…

#### Sin tope de gasto ni alerta: el `usage` de OpenRouter se descarta y no hay ningún límite global de llamadas

`functions/src/openrouter.ts:33` · **Alta** · esfuerzo M · **bloquea publicación**

La interfaz `OpenRouterResponse` (openrouter.ts:33-36) solo declara `choices` y `error`: el objeto `usage` que devuelve la API (tokens de prompt y de respuesta, y el coste) se descarta. En `chat.ts` no se registra ningún dato de consumo: el único `logger` relacionado es el de error en chat.ts:251. Tampoco hay ningún contador agregado a nivel de proyecto: la cuota de chat.ts:177-195 es por usuario (`users/{uid}/meta/usage`), no global, así que no existe ningún punto del sistema donde el dueño pueda ver, y menos aún frenar, el gasto total del día. En el repo no hay nada de presupuesto (PLAN.md:26, F0-04 en `todo`) ni función programada que vigile (no hay ningún `onSchedule` en `functions/src/`).

**Corrección.** Leer `usage` en `askOpenRouter` y devolverlo junto al texto; en `chat.ts` emitir `logger.info('chat.usage', { uid, model, promptTokens, completionTokens })` para poder construir un panel y alertas en Cloud Logging. Añadir un contador global en un documento tipo `system/usage/{yyyy-MM-dd}` incrementado con `FieldValue.increment` en la misma transacción de la cuota, y un corte duro (`resource-exhausted` para todos) cuando se supere el presupuesto diario. Configurar en Google Cloud → Billing → Budgets las alertas de F0-04 y una clave de OpenRouter con límite de gasto.

> *Matizado al verificar:* Los hechos se verifican. `functions/src/openrouter.ts:33-36` es `interface OpenRouterResponse { choices?: Array<{ message?: { content?: string | null } }>; error?: { message?: string }; }` — no declara ni lee `usage`. En `functions/src/chat.ts` el único `logger` de todo el archivo es `logger.error('OpenRouter falló', { uid, conversationId: convRef.id, error: String(err) });` (:251). La cuota es por usuario: `chat.ts:160` `db.doc('users/'+uid+'/meta/usage')` y la transacción en :177-195. `grep -rn 'onSchedule' functions/` solo acierta en `node_modules` (no hay ninguno en `functions/src/`), e `index.ts:5-7` exporta tres funciones. MATICES: (1) Es en gran medida el mismo hallazgo que el anteri…

#### Amplificación de coste: cada escritura de transacción dispara el trigger sin ningún límite de tasa, y el `monthKey` lo elige el cliente

`functions/src/months.ts:44` · **Alta** · esfuerzo M · **bloquea publicación**

`onTransactionWritten` (months.ts:44-51) se dispara en cada create/update/delete de `users/{uid}/transactions/{txId}` y ejecuta `recalcMonth` para cada `monthKey` afectado (months.ts:71). Cada `recalcMonth` hace dos consultas de agregación (months.ts:27) más una escritura (months.ts:31). Las reglas no ponen ningún límite al ritmo de escritura del cliente: `firestore.rules:145` permite `create, update` de transacciones sin más condición que la validación de forma. Un usuario autenticado con un script puede escribir decenas de miles de transacciones por minuto (`BulkWriter` del SDK admin no, pero el SDK cliente sí llega a varios cientos por segundo), y cada una cuesta al dueño 1 invocación de función + 2 a 4 agregaciones + 1 a 2 escrituras. `maxInstances: 10` (months.ts:50) limita la concurrencia, no el total: los eventos se encolan y terminan ejecutándose todos. Agravante: el `monthKey` lo fija el cliente y `firestore.rules:139` lo valida con `^[0-9]{4}-[0-9]{2}$`, que acepta mes `00` a `99`; es decir, el cliente puede crear hasta 10.000 documentos distintos en `users/{uid}/months/` (p. ej. `2026-99`), que la UI leerá y mostrará como meses reales (`finances_firebase_datasource.dart:60-62` lee toda la colección `months` ordenada por id, sin `limit`).

**Corrección.** (1) Validar en reglas que `monthKey` sea coherente con `date`: `d.monthKey == d.date.toMillis()`... no es expresable directamente, así que usar `d.monthKey.matches('^[0-9]{4}-(0[1-9]|1[0-2])$')` como mínimo, y a medio plazo derivar `monthKey` en el propio trigger a partir de `date` en vez de confiar en el cliente. (2) Añadir un tope de transacciones por usuario y día (contador en `meta/usage` incrementado desde el trigger, y rechazo en reglas por encima de un número razonable de documentos, o simplemente alertar). (3) Bajar `maxInstances` no arregla el coste total: lo que hace falta es la alerta de presupuesto de F0-04 y vigilar el número de invocaciones.

> *Matizado al verificar:* Casi todo se verifica. `functions/src/months.ts:44-51` declara `onDocumentWritten({ document: 'users/{uid}/transactions/{txId}', region: REGION, memory: '256MiB', maxInstances: 10 }` y `:71` es `await Promise.all([...keys].map((key) => recalcMonth(uid, key)));`. `recalcMonth` lanza dos agregaciones con `Promise.all` (:27) y una escritura (:31). `firestore.rules:145` es `allow create, update: if isOwner(uid) && validTransaction(incoming());`, sin ninguna condición de tasa (y Firestore Rules no puede expresarla). `firestore.rules:139` es `&& d.monthKey.matches('^[0-9]{4}-[0-9]{2}$')`, que en efecto acepta mes `00`–`99`. `finances_firebase_datasource.dart:60-62` es `Stream<List<FinancesSummary…

#### `recalcMonth` lee y escribe fuera de transacción, sin `retry`, sin borrar meses vacíos y sin reconciliación: los totales pueden quedar mal para siempre

`functions/src/months.ts:27` · **Alta** · esfuerzo M · **bloquea publicación**

months.ts:27 lanza las dos agregaciones con `Promise.all` y months.ts:31 escribe el resultado con `.set()` sin transacción. Con dos escrituras rápidas sobre el mismo mes (el caso normal: el usuario añade dos gastos seguidos, o edita y borra), las dos invocaciones del trigger se solapan; la que leyó el estado más antiguo puede commitear la última y dejar `totalIncome`/`totalExpenses`/`transactionCount` desfasados de forma permanente, porque nada vuelve a recalcular ese mes hasta la siguiente escritura en él. Además las opciones del trigger (months.ts:45-51) NO incluyen `retry: true`, así que un fallo transitorio (cuota de Firestore, cold start que excede el plazo, error de red en la agregación) pierde el evento y el mes queda incorrecto sin que nadie se entere. Tampoco existe ninguna función programada de reconciliación: `functions/src/index.ts:5-7` solo exporta tres funciones y no hay ningún `onSchedule` en `functions/src/`. Por último, months.ts:11 documenta explícitamente que un mes sin transacciones se deja en 0 en vez de borrarse; eso hace que `chat.ts:214` (`orderBy(FieldPath.documentId(), 'desc').limit(1)`) pueda elegir como 'último mes' un documento vacío y le cuente al asistente que el negocio no facturó nada.

**Corrección.** Envolver lectura y escritura en `db.runTransaction` (verificar que `firebase-admin` 14 admite `aggregate().get()` dentro de la transacción; si no, usar `FieldValue.increment` con los deltas calculados a partir de `before`/`after`, que es transaccional por construcción y además elimina las agregaciones). Añadir `retry: true` a las opciones de months.ts:45-51. Borrar el documento del mes cuando `transactionCount === 0`. Añadir una función programada diaria (`onSchedule`) que reconcilie los meses del usuario con actividad reciente. Añadir un test que escriba dos transacciones en paralelo y verifique el total.

#### `waitlist`: el rate limit es evadible con una cabecera y no hay deduplicación, así que cualquiera puede llenar Firestore de documentos

`functions/src/waitlist.ts:44` · **Alta** · esfuerzo M · **bloquea publicación**

Sigue abierto tal cual lo describió la auditoría anterior. `clientIp` (waitlist.ts:44-51) toma el **primer** valor de `X-Forwarded-For`, que es el que controla el cliente: basta con `curl -H 'X-Forwarded-For: 1.2.3.4'` y cambiar el valor en cada petición para que `isRateLimited` (waitlist.ts:26-42) nunca dispare, porque el mapa se indexa por esa cadena. Además el contador vive en memoria de la instancia (waitlist.ts:24) y `maxInstances: 2` (waitlist.ts:105) significa que incluso sin trucos el límite efectivo es 10 por hora y por IP, y se reinicia con cada cold start. El endpoint no exige App Check ni CAPTCHA, y waitlist.ts:148-150 escribe con `.add()`, que genera un id nuevo cada vez: el mismo correo puede entrar mil veces. El chequeo de origen (waitlist.ts:119-123) no protege nada porque solo se aplica si el cliente envía la cabecera `Origin`, cosa que `curl` no hace. Adicional: `http://localhost:5173` está en la lista de orígenes permitidos de producción (waitlist.ts:11).

**Corrección.** Usar el **último** salto de `X-Forwarded-For` (el que inserta el balanceador de Google y el cliente no puede falsificar), o directamente `req.ip`. Sustituir el `.add()` por `.doc(sha256(email)).set({...}, { merge: true })` para que el mismo correo sea idempotente. Exigir App Check (la landing puede usar reCAPTCHA v3 o Turnstile) o, como mínimo, mover el rate limit a Firestore con un documento por IP. Dejar `localhost:5173` solo cuando `process.env.FUNCTIONS_EMULATOR === 'true'`. Añadir tests de `validateWaitlistBody` y de `isRateLimited` con XFF falsificado.

> *Matizado al verificar:* Todos los hechos técnicos se confirman con las líneas exactas. `waitlist.ts:44-51`: `clientIp` hace `return first.split(',')[0].trim();`, el primer salto de `X-Forwarded-For`, que controla el cliente. `isRateLimited` (:26-42) indexa `hitsByIp` (:24, `new Map<string, number[]>()` en memoria) por esa cadena. `RATE_MAX_PER_WINDOW = 5` (:15) y `maxInstances: 2` (:105) dan el límite efectivo de 10/hora/IP que cita, y la aritmética es correcta. La escritura es `.collection('waitlist').add({ ...parsed.value, createdAt: FieldValue.serverTimestamp() })` (:148-150), id nuevo en cada llamada. El chequeo de origen (:119-123) es `if (typeof req.headers.origin === 'string' && !originAllowed)`, así que si…

### Requisitos técnicos de Google Play

#### El build release se firma con la keystore de debug: Google Play rechaza el upload

`android/app/build.gradle.kts:38` · **Crítica** · esfuerzo M · **bloquea publicación**

El bloque `buildTypes { release { ... } }` (lineas 34-40) conserva el TODO de la plantilla de Flutter y asigna `signingConfig = signingConfigs.getByName("debug")`. No existe ningun bloque `signingConfigs` propio, no existe `android/key.properties` (verificado: no esta en el arbol) y no hay ninguna lectura de propiedades de keystore en el script. La keystore de debug si existe en la maquina (C:/Users/Franco/.android/debug.keystore, 2618 bytes, creada 2026-02-09), asi que `flutter build appbundle --release` SI produce un .aab, pero firmado con el certificado de debug (CN=Android Debug). Play Console rechaza explicitamente ese upload con «You uploaded an APK or Android App Bundle that was signed in debug mode». Ademas, sin keystore propia no hay SHA-256 estable que registrar en App Check / Play Integrity ni en las restricciones de la API key (README.md:92,94 ya lo asumen).

**Corrección.** 1) DUENO genera la keystore de subida: `keytool -genkey -v -keystore C:/Users/Franco/claves/pagate-upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload` (guardarla FUERA del repo y respaldarla; si se pierde, Play permite reset del upload key pero no de la de firma si no se usa Play App Signing). 2) Crear `android/key.properties` (ya ignorado por android/.gitignore:12) con storePassword / keyPassword / keyAlias=upload / storeFile=C:/Users/Franco/claves/pagate-upload.jks. 3) En android/app/build.gradle.kts, antes de `android { }`: `val keystoreProperties = java.util.Properties().apply { val f = rootProject.file("key.properties"); if (f.exists()) f.inputStream().use { load(it) } }`. 4) Dentro de `android { }` anadir `signingConfigs { create("release") { keyAlias = keystoreProperties["keyAlias"] as String?; keyPassword = keystoreProperties["keyPassword"] as String?; storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }; storePassword = keystoreProperties["storePassword"] as String? } }`. 5) Cambiar la linea 38 por `signingConfig = signingConfigs.getByName("release")` y borrar el TODO de las lineas 36-37. 6) Anadir un guard: si `storeFile == null`, fallar el build release en vez de caer a debug. 7) Play App Signing: al crear la app, Play pide la clave de firma; con el flujo por defecto Google genera y custodia la clave de firma de la app y la keystore anterior queda como *upload key*. La SHA-256 que hay que registrar en App Check/Play Integrity y en las restricciones de la API key es la de **Play Console -> Test and release -> App integrity -> App signing key certificate**, NO la del upload key (registrar ambas mientras se prueba por sideload).

#### El icono de la app es, byte a byte, el logo por defecto de Flutter y no hay icono adaptativo

`android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png:1` · **Alta** · esfuerzo M · **bloquea publicación**

Verificado por MD5: los cinco `ic_launcher.png` del repo son identicos a los de la plantilla C:/Users/Franco/flutter/packages/flutter_tools/templates/app/android.tmpl/app/src/main/res/mipmap-*/ (mdpi 6270344430679711b81476e29878caa7, hdpi 13e9c72ec37fac220397aa819fa1ef2d, xhdpi a0a8db5985280b3679d99a820ae2db79, xxhdpi afe1b655b9f32da22f9a4301bb8e6ba8, xxxhdpi 57838d52c318faff743130c3fcfae0c6). Dimensiones actuales: 48/72/96/144/192 px. Ademas NO existe `res/mipmap-anydpi-v26/ic_launcher.xml`: `ls res/` devuelve solo drawable, drawable-v21, mipmap-{h,m,xh,xxh,xxxh}dpi, values, values-night. Sin icono adaptativo, en Android 8+ (es decir, todo el rango soportado con minSdk 24... en realidad desde API 26) el launcher recorta el PNG legacy dentro de una mascara y le anade un fondo blanco, y en Android 13+ no hay icono tematizado (monochrome). AndroidManifest.xml:5 apunta a `@mipmap/ic_launcher` y no declara `android:roundIcon`.

**Corrección.** Producir el icono a partir de un unico master SVG/PNG de 1024x1024 y generar EXACTAMENTE: (a) `res/mipmap-anydpi-v26/ic_launcher.xml` y `ic_launcher_round.xml` con `<adaptive-icon>` -> `<background>`, `<foreground>` y `<monochrome>`; (b) foreground y background como PNG en las cinco densidades a 108 dp: mdpi 108x108, hdpi 162x162, xhdpi 216x216, xxhdpi 324x324, xxxhdpi 432x432 (el contenido visible debe caber en el circulo central de 66 dp; margen de seguridad de 18 dp por lado); (c) los `ic_launcher.png` legacy de respaldo para API <26 en 48/72/96/144/192; (d) el monochrome en las mismas cinco densidades, silueta blanca sobre transparente. Formato PNG-32 con alfa (no JPEG, no WebP con perdida para el legacy). Aparte, la ficha de Play exige un PNG de 512x512 de 32 bits con alfa, un feature graphic de 1024x500 y al menos 2 capturas de telefono (16:9 o 9:16, lado menor >= 320 px, mayor <= 3840 px). Anadir `android:roundIcon="@mipmap/ic_launcher_round"` en AndroidManifest.xml:5.

> *Matizado al verificar:* Los HECHOS son exactos. MD5 de los cinco PNG del repo == MD5 de la plantilla C:/Users/Franco/flutter/packages/flutter_tools/templates/app/android.tmpl/app/src/main/res/mipmap-*/: mdpi 6270344430679711b81476e29878caa7, hdpi 13e9c72ec37fac220397aa819fa1ef2d, xhdpi a0a8db5985280b3679d99a820ae2db79, xxhdpi afe1b655b9f32da22f9a4301bb8e6ba8, xxxhdpi 57838d52c318faff743130c3fcfae0c6. Dimensiones leidas de la cabecera IHDR: 48/72/96/144/192. `ls android/app/src/main/res/` devuelve solo drawable, drawable-v21, mipmap-{m,h,xh,xxh,xxxh}dpi, values, values-night: NO hay mipmap-anydpi-v26 ni res/xml. AndroidManifest.xml:5 es `android:icon="@mipmap/ic_launcher">` y el `<application>` (lineas 2-5) no decl…

#### No existe eliminacion de cuenta ni ruta de borrado de datos: Play lo exige para apps con registro

`lib/features/dashboard/presentation/pages/configuracion_screen.dart:122` · **Alta** · esfuerzo L · **bloquea publicación**

La pantalla de Configuracion tiene cuatro secciones (Negocio 53-89, Metas 91-120, Seguridad 122-132, Notificaciones 134-157) y la lista termina en la linea 159. La unica accion de cuenta es `Cambiar contrasena` (125-130). No hay `Eliminar cuenta`, no hay `Cerrar sesion`, no hay enlace a politica de privacidad ni a terminos, y no hay numero de version. Busqueda confirmada en todo `lib/`: las unicas ocurrencias de `delete` son `finances_firebase_datasource.dart:107`, `:122` e `inventory_firebase_datasource.dart:57`, todas sobre documentos de negocio, ninguna sobre la cuenta. La app crea cuentas (FirebaseAuth con email/password + Google), asi que la politica de Play de eliminacion de datos obliga a ofrecer borrado de cuenta DENTRO de la app y ademas una URL web accesible sin instalar la app, y a declarar ambas en el formulario de Data Safety.

**Corrección.** AGENTE: anadir en Configuracion una seccion `Cuenta` con `Cerrar sesion` y `Eliminar cuenta`; esta ultima con dialogo de confirmacion, reautenticacion (`reauthenticateWithCredential`, obligatorio porque Firebase exige credencial reciente) y llamada a una nueva callable `deleteAccount` en functions/ que borre recursivamente `users/{uid}` (inventory, transactions, fixedExpenses, months, conversations, meta/usage) y despues `admin.auth().deleteUser(uid)`. Tambien anadir las filas `Terminos` y `Privacidad` que abran las URLs reales. DUENO: publicar la pagina de borrado de datos (puede colgar de la landing de GitHub Pages) y rellenar la seccion «Eliminacion de datos» y el formulario Data Safety en Play Console.

> *Matizado al verificar:* El nucleo del hallazgo es CIERTO: `grep -rn "deleteUser|deleteAccount|reauthenticate" lib/` no devuelve nada, y las unicas ocurrencias de borrado son lib/features/finances/data/datasources/finances_firebase_datasource.dart:107 (`_transactions.doc(transactionId).delete();`), :122 (`_fixedExpenses.doc(id).delete();`) e lib/features/inventory/data/datasources/inventory_firebase_datasource.dart:57 (`Future<void> deleteItem(...) => _items.doc(itemId).delete();`). En el backend, functions/src/index.ts:5-7 exporta solo `chat`, `onTransactionWritten` y `waitlist`, y `grep -rn "deleteUser|recursiveDelete|deleteAccount" functions/src/` sale vacio: no hay ninguna via de borrado de cuenta ni endpoint w…

#### minSdk 21 en HEAD rompe el build de Android; el arreglo esta sin commitear

`android/app/build.gradle.kts:28` · **Alta** · esfuerzo S · **bloquea publicación**

El arbol de trabajo tiene `minSdk = flutter.minSdkVersion` pero el commit HEAD tiene `minSdk = 21` (verificado con `git diff`: es el unico cambio sin commitear del repo). En Flutter 3.42.0-0.0.pre (confirmado con `flutter --version`), `FlutterExtension.kt:26` fija `minSdkVersion = 24`, `:23` `compileSdkVersion = 36`, `:34` `targetSdkVersion = 36` y `:42` `ndkVersion = 28.2.13676358`. Es decir, el cambio pendiente resuelve a **24**, no a 21. Y no es cosmetico: `DependencyVersionChecker.kt:116` define `errorMinSdkVersion = 23` y `:326` lanza GradleException si `minSdk < 23`, asi que **desde HEAD el build de Android falla directamente**. Consecuencia de producto de subir a 24: se deja fuera Android 5.0-6.0 (API 21-23).

**Corrección.** Commitear el cambio (es obligatorio para que compile). Dejarlo como `minSdk = flutter.minSdkVersion` acopla el minimo a la version de Flutter, lo que puede mover el minSdk sin aviso en un upgrade; para una app que se publica conviene fijarlo explicito: `minSdk = 24`. Documentar en el README que se soporta Android 7.0+.

> *Matizado al verificar:* La conclusion es correcta pero el MECANISMO que se da esta mal. Cierto y verificado: `git status --porcelain` devuelve solo ` M android/app/build.gradle.kts`, y `git diff` es exactamente `-        minSdk = 21` / `+        minSdk = flutter.minSdkVersion` en la linea 28. Cierto: FlutterExtension.kt:25 `val minSdkVersion: Int = 24`, :23 compileSdk 36, :34 targetSdk 36, :42 ndk 28.2.13676358, con Flutter 3.42.0-0.0.pre (bin/cache/flutter.version.json). Cierto: DependencyVersionChecker.kt:116 `errorMinSdkVersion: Int = 23` y :326-334 lanza DependencyValidationException si `minSdkVersion.version < errorMinSdkVersion`. ERROR: ese check se engancha SOLO a las tareas assemble — DependencyVersionChec…

### Políticas, privacidad y datos de Google Play

#### No existe política de privacidad: ni documento, ni URL pública, ni enlace vivo dentro de la app

`landing/src/components/Footer.tsx:22` · **Crítica** · esfuerzo M · **bloquea publicación**

Google Play exige una URL de política de privacidad accesible públicamente, declarada en la ficha Y enlazada desde dentro de la app. No existe en ninguna parte del repo: (1) `landing/src/components/Footer.tsx:22-23` declara `{ label: 'Términos', href: '#' }` y `{ label: 'Privacidad', href: '#' }`, dos enlaces muertos; (2) el build publicado `landing-page/` solo contiene `index.html`, `assets/` y los iconos — no hay `privacidad.html` ni `terminos.html`; (3) en la app, `lib/features/onboarding/presentation/pages/identity_step_screen.dart:213-221` pinta 'Términos' y 'Privacidad' como `TextSpan` con `TextStyle(color: AppColors.brand)` pero SIN `recognizer`: son texto coloreado, no enlaces (verificado: `grep recognizer` no devuelve nada en ese archivo); (4) `lib/features/auth/presentation/pages/welcome_screen.dart:293` dice 'Al continuar, aceptas nuestros Términos y Privacidad' y el botón 'Ver términos' de la línea 306 muestra un snackbar 'Puedes revisar los términos desde configuración' (línea 304), pero `configuracion_screen.dart:52-157` solo tiene las secciones Negocio, Metas, Seguridad y Notificaciones: no hay sección legal. Es un callejón circular. Además `pubspec.yaml:10-26` no incluye `url_launcher`, así que hoy no hay forma técnica de abrir una URL externa desde la app.

**Corrección.** Redactar la política de privacidad (debe cubrir explícitamente: correo, nombre, nombre y tipo de negocio, meta mensual, valor hora, transacciones, inventario y conversaciones del chat; el envío a OpenRouter y sus subprocesadores; retención; base legal; el derecho de borrado y el correo de contacto) y los términos. Publicarlas como `/privacidad` y `/terminos` en la landing de GitHub Pages (o en `pagate-17211.web.app`), añadirlas a `footerLinks.Legal`, poner la URL en la ficha de Play, añadir `url_launcher` y convertir los TextSpan de `identity_step_screen.dart:213-221` y `welcome_screen.dart:293-306` en enlaces reales.

#### No existe ningún camino de borrado de cuenta: ni dentro de la app ni una URL pública de solicitud

`lib/features/user_profile/presentation/pages/perfil_tab.dart:183` · **Crítica** · esfuerzo M · **bloquea publicación**

Play exige desde 2023 dos cosas para toda app con cuentas de usuario: un camino de borrado DENTRO de la app y además una URL web pública para solicitarlo sin instalarla. No hay ninguna de las dos. El menú del perfil (`perfil_tab.dart:145-189`) es: Configuración, Ayuda e Ideas, Calificar la App, Compartir Págate-IA y, como única acción destructiva, 'Cerrar Sesión' (línea 185). `configuracion_screen.dart:122-132` tiene la sección 'Seguridad' con un único ítem, 'Cambiar contraseña'. Peor: aunque se añadiera un botón, hoy no funcionaría bien. `firestore.rules:98` permite `allow delete: if isOwner(uid)` sobre `users/{uid}`, pero borrar ese documento deja huérfanas e inaccesibles para siempre las subcolecciones `transactions/`, `inventory/`, `fixedExpenses/`, `months/`, `conversations/{id}/messages/` y `meta/usage`, y no elimina la cuenta de Firebase Auth (`firebase_auth_service.dart` no expone `delete()` en ninguna línea; sus métodos son signIn, createUser, signOut, sendPasswordReset).

**Corrección.** Implementar el callable `deleteAccount` ya previsto en PLAN.md (S1-07) usando `firestore.recursiveDelete(db.doc('users/'+uid))` + `admin.auth().deleteUser(uid)` + borrado del registro de `waitlist` que coincida por correo; denegar `delete` directo en `firestore.rules:98`; añadir el botón en Configuración con confirmación y reautenticación; y publicar una página web pública de solicitud de borrado (formulario o correo indicado) y declarar esa URL en Play Console → Seguridad de los datos → Eliminación de cuenta.

#### El chat envía nombre, negocio, sueldo objetivo, totales del mes y las últimas 10 transacciones a OpenRouter sin declararlo ni pedir consentimiento

`functions/src/prompt.ts:82` · **Crítica** · esfuerzo M · **bloquea publicación**

Inventario exacto de lo que viaja a un tercero en CADA llamada al asistente, verificado línea a línea. `buildSystemPrompt` (`prompt.ts:142-173`) concatena: nombre del usuario (`prompt.ts:82`), nombre del negocio (`:83`), rubro (`:84`), moneda (`:85`), meta mensual de ingresos formateada (`:86-88`) y plan (`:89`); sueldo mensual deseado, horas disponibles al mes y valor hora calculado (`:99-101`); mes, ingresos, gastos, balance y número de movimientos (`:112-116`); y las últimas 10 transacciones una por una con fecha ISO, tipo, categoría entre corchetes, TÍTULO LIBRE y monto (`:125-131`, alimentadas por `chat.ts:215` `orderBy('date','desc').limit(10)`); más el conteo de productos y materiales (`:134-139`, de `chat.ts:216-217`). A eso `chat.ts:232-239` le suma los últimos 20 mensajes íntegros de la conversación (`HISTORY_LIMIT = 20`, `chat.ts:24` y `:218`). Todo ese bloque sale por `openrouter.ts:49-64` en un POST a `https://openrouter.ai/api/v1/chat/completions` con cabeceras `HTTP-Referer: https://pagate-17211.web.app` y `X-Title: Pagate-IA` (`openrouter.ts:54-55`), que identifican la app ante OpenRouter. El título de una transacción es texto libre del usuario y en la práctica contiene nombres de clientes ('Venta a María', 'Pedido Juan'): son datos personales de TERCEROS que el usuario no ha consentido compartir. Subprocesadores: `config.ts:15` fija `OPENROUTER_MODEL` por defecto en `deepseek/deepseek-v4-flash`, o sea OpenRouter enruta a DeepSeek u otro proveedor aguas abajo; no se envía ninguna cabecera de política de datos (`openrouter.ts:51-56` no incluye `X-OpenRouter-Data-Policy` ni equivalente), así que rigen los ajustes por defecto de la cuenta, que pueden permitir registro y entrenamiento. No hay una sola línea en `README.md`, `docs/ARQUITECTURA.md` ni `AGENTS.md` que documente qué hace OpenRouter con estos datos (grep verificado: las únicas menciones son `README.md:28,87,129`, `ARQUITECTURA.md:9,116-117`, `AGENTS.md:51`, y todas hablan del secreto, no del tratamiento).

**Corrección.** (1) Declarar en Seguridad de Datos de Play: 'Información financiera → Otra información financiera del usuario' como COMPARTIDA con terceros, más 'Información personal → Nombre' y 'Mensajes → Otros mensajes en la app'. (2) Nombrar a OpenRouter y al proveedor del modelo en la política de privacidad, con enlace a sus políticas. (3) Fijar en la cuenta de OpenRouter la política de datos más restrictiva (sin registro, sin entrenamiento) y enviar explícitamente la cabecera correspondiente desde `openrouter.ts:51-56` para no depender de un ajuste de consola. (4) Mostrar en `ia_tab.dart`, antes del primer mensaje, un aviso claro de qué contexto se envía y a quién, con aceptación explícita persistida. (5) Evaluar seudonimizar el nombre y los títulos de transacción antes de construir el prompt.

#### El release sigue firmándose con el keystore de depuración: Play rechaza el AAB en la subida

`android/app/build.gradle.kts:38` · **Crítica** · esfuerzo S · **bloquea publicación**

Ya estaba registrado en docs/AUDITORIA-2026-09.md §2.1 y sigue exactamente igual (lo reverifiqué en el archivo actual): `buildTypes { release { signingConfig = signingConfigs.getByName("debug") } }`, líneas 34-40, con el TODO de la plantilla en la línea 36. El único cambio en el working tree respecto a HEAD es `minSdk = flutter.minSdkVersion` en lugar de `minSdk = 21` (git diff verificado), que no toca la firma. Lo incluyo aquí porque es el bloqueo mecánico previo a todo lo demás de mi dimensión: Play Console rechaza el artefacto antes de llegar a revisión de políticas con 'You uploaded an APK or Android App Bundle that was signed in debug mode'.

**Corrección.** Generar el keystore de release (tarea S1-01 del plan, es del dueño), crear `android/key.properties` ignorado por git, declarar `signingConfigs.release` leyéndolo y apuntar el buildType release a él. Añadir `*.jks` y `key.properties` al `.gitignore` antes de crear nada.

#### Asistente de IA generativa sin mecanismo de reporte, sin aviso de contenido generado y sin moderación de salida

`lib/features/dashboard/presentation/pages/tabs/ia_tab.dart:420` · **Alta** · esfuerzo M · **bloquea publicación**

La política de Play para apps con IA generativa exige un mecanismo IN-APP para que el usuario reporte o denuncie contenido ofensivo, y que ese canal se use para informar el filtrado. `ia_tab.dart` (471 líneas, leído completo) no lo tiene: `_MessageBubble` (líneas 420-470) solo pinta un `SelectableText` con el texto del modelo; el único control contextual del chat es 'Nueva conversación' (`:172-212`) y el banner de error (`:246-317`). Un grep de `reportar|denunci|flag|abuso` sobre todo `lib/` no devuelve ninguna coincidencia funcional. Tampoco hay aviso de que la respuesta la genera un modelo y puede equivocarse (grep de `puede equivocarse|no es asesor|verifica` sobre `lib/`: cero resultados), pese a que la app da orientación sobre precios y dinero. Del lado servidor las únicas salvaguardas son instrucciones en el prompt: `prompt.ts:157` ('No inventes cifras, productos, clientes ni movimientos') y `prompt.ts:160` ('No des asesoría legal ni tributaria específica'); son sugerencias al modelo, no filtros. `chat.ts:257` guarda la respuesta en `messages` sin pasarla por ninguna moderación. Se agrava con la inyección de prompt ya registrada en la auditoría previa (§2.3, `prompt.ts:82-84` y `:127-129` interpolan campos del usuario sin escapar): un título de transacción puede reescribir las instrucciones del sistema y no hay red de seguridad después.

**Corrección.** (1) Añadir en cada burbuja del asistente una acción de reportar (menú largo o icono) que escriba en una colección `reports/` y confirme al usuario. (2) Añadir una línea fija bajo el composer: 'Respuestas generadas por IA. Pueden contener errores; no son asesoría contable ni tributaria.' (3) Declarar la app como GenAI en la ficha de Play y describir en el cuestionario el mecanismo de reporte. (4) Cerrar S1-08 (sanitización y delimitadores en `prompt.ts`) antes de publicar.

#### La landing pública, que es el sitio donde vivirá la política de privacidad, muestra métricas y testimonios inventados

`landing/src/components/Stats.tsx:8` · **Alta** · esfuerzo S · **bloquea publicación**

`landing/src/components/Stats.tsx:8-11` declara cuatro métricas presentadas como reales, con animación de contador: `'$42.8k' — Valor hora promedio calculado`, `'150' + 'M+' — Horas facturadas al mes`, `'8.500' + '+' — Freelancers activos`, `'98' + '%' — Satisfacción de usuarios`. La app no ha salido: no hay 8.500 usuarios ni una medición de satisfacción. `landing/src/components/Testimonials.tsx:8-30` inventa tres testimonios firmados con nombre y profesión: María González (Diseñadora Freelance, línea 10-12), Carlos Martínez (Desarrollador Web, :18-19) y Ana Silva (Consultora de Marketing, :25-26), los tres con `rating: 5`. Y NO es solo código fuente: verifiqué que el build publicado en GitHub Pages ya los contiene — `landing-page/assets/index-H2tCG13A.js` incluye las cadenas 'González' y '8.500' (grep con coincidencia). Es decir, están en vivo ahora mismo en el sitio al que apuntará la URL de privacidad de la ficha de Play, y el revisor de Play visita esa URL.

**Corrección.** Borrar `Stats.tsx` y `Testimonials.tsx` del render de `App.tsx`, o sustituirlos por contenido verificable (qué hace la app, capturas reales). Regenerar `landing-page/` con el workflow `landing-pages.yml`; NO editar el build a mano.

#### El usuario no puede borrar su historial de conversaciones con la IA por ningún medio

`firestore.rules:170` · **Alta** · esfuerzo M · **bloquea publicación**

`firestore.rules:170-178` fija `allow write: if false` tanto en `conversations/{convId}` como en `conversations/{convId}/messages/{msgId}`: el cliente solo lee. Y no existe ningún callable de borrado (`functions/src/index.ts:5-7` exporta únicamente `chat`, `onTransactionWritten` y `waitlist`). Lo único que parece borrar es 'Nueva conversación' en `ia_tab.dart:172-212`, que llama a `AiProvider.newConversation()` (`ai_provider.dart:272-285`): ese método solo cancela la suscripción y vacía `_messages` en memoria — los documentos de Firestore quedan intactos para siempre. Mismo problema con `months/{monthKey}` (`firestore.rules:165-168`) y `meta/usage` (`:180-183`). Las conversaciones contienen los mensajes del usuario sobre su negocio y las respuestas del modelo, que a su vez incluyen las cifras del prompt. En Seguridad de Datos de Play hay que responder 'Los usuarios pueden solicitar que se eliminen los datos' por categoría: para 'Mensajes' la respuesta honesta hoy es NO.

**Corrección.** Añadir al callable `deleteAccount` un hermano `deleteConversation(conversationId)` con `recursiveDelete`, y exponerlo desde el chat (borrar una conversación y 'borrar todo el historial'). Alternativa mínima viable: incluir el borrado del historial dentro del borrado de cuenta y declarar correctamente la limitación mientras tanto.

#### El canal de soporte de la ficha no existe: correo en un dominio no controlado y acciones que solo muestran un snackbar

`lib/features/dashboard/presentation/pages/ayuda_screen.dart:235` · **Alta** · esfuerzo S · **bloquea publicación**

Play exige un correo de soporte válido en la ficha y que lo que la app ofrece como soporte funcione. `ayuda_screen.dart:235` muestra `soporte@pagate-ia.com`: el dominio `pagate-ia.com` no aparece en ningún sitio del repo (la landing vive en `francogalaz.github.io/Pagate-ia/`, ver `landing-page/index.html:5`, y el hosting es `pagate-17211.web.app`, ver `chat.ts:145` y `openrouter.ts:54`), es decir es un correo inventado. Al tocarlo, `_ContactRow` (`ayuda_screen.dart:265-269`) no abre el cliente de correo: muestra el snackbar 'Te pondremos en contacto con soporte desde "soporte@pagate-ia.com"'. La segunda fila, `ayuda_screen.dart:244`, ofrece 'Chat en vivo (Pro)', un servicio que no existe en ninguna parte del código. El mismo patrón de botón falso está en `perfil_tab.dart:167-171` ('Calificar la App' → snackbar 'Pronto abriremos la calificación') y `perfil_tab.dart:176-180` ('Compartir Págate-IA' → snackbar, sin `Share`).

**Corrección.** Poner un correo real que el dueño controle (p. ej. el de la cuenta de desarrollador) y que sea el mismo que se declare en la ficha de Play; hacer que la fila lo abra con `mailto:` vía `url_launcher`; eliminar 'Chat en vivo (Pro)'; hacer que 'Calificar la App' abra `market://details?id=com.pagate.apppagate` (funcionará en cuanto esté publicada) y 'Compartir' use `share_plus`, o eliminar ambas.

### Tests, CI y red de seguridad

#### CI nunca construye Android y el objetivo es Google Play

`.github/workflows/ci.yml:28` · **Alta** · esfuerzo S · **bloquea publicación**

El job `flutter` hace `flutter analyze`, `flutter test` y `flutter build web --release`. No existe ningun `flutter build apk --release` ni `flutter build appbundle --release` en ningun workflow (verificado en los tres: ci.yml, deploy-web.yml, landing-pages.yml). El build de release de Android es el unico que activa R8/minificacion, el merge de manifests de los plugins de Firebase y la resolucion de `minSdk`/`targetSdk`, y es el unico camino que produce lo que se sube a Play. Ademas `android/app/build.gradle.kts:38` sigue firmando release con la keystore de debug y `minSdk` acaba de cambiarse a `flutter.minSdkVersion` en el working tree sin commitear. Resultado: el primer AAB real de la vida del proyecto se compilara el dia del envio, sin que nadie sepa si compila.

**Corrección.** Anadir al job `flutter` de ci.yml un paso `flutter build appbundle --release` (con `--dart-define=PAGATE_ENV=prod`). Mientras no haya keystore propia, al menos `flutter build apk --release --no-shrink` para validar que compila; cuando exista `key.properties` (S1-01), que el job firme con un secreto y suba el .aab como artifact. Como coste cero adicional, anadir `flutter build apk --debug` ya detectaria roturas de Gradle/plugins.

> *Matizado al verificar:* El núcleo es cierto y lo comprobé: `grep -rn "build apk|appbundle|build android" .github/ scripts/` no devuelve nada (exit 1); `.github/workflows/ci.yml:28` es `- run: flutter build web --release`, y ni `deploy-web.yml` ni `landing-pages.yml` tocan Gradle. `android/app/build.gradle.kts:38` tiene `signingConfig = signingConfigs.getByName("debug")` y `git diff` confirma `-        minSdk = 21` / `+        minSdk = flutter.minSdkVersion` sin commitear. PERO dos afirmaciones del 'problema' son falsas: (1) el merge de manifests de los plugins y la resolución de `minSdk`/`targetSdk` NO son exclusivos del build de release — existen `build/app/outputs/logs/manifest-merger-debug-report.txt` y `build/…

#### Ninguna de las cinco pantallas del rediseno tiene una prueba que sobreviva al rediseno

`test/features/auth/welcome_screen_test.dart:21` · **Alta** · esfuerzo M · **bloquea publicación**

La suite Flutter completa son 15 tests en 6 archivos (verificado: `flutter test` = 15 passed). Desglose real: widget_test.dart = 2 tests de `PagatePrimaryButton`; bootstrap_error_app_test.dart = 2 tests de texto y callback; firebase_options_test.dart = 3 tests de constantes por plataforma; welcome_screen_test.dart = 1 test; finances_provider_test.dart = 3 tests del provider; calculate_hourly_rate_test.dart = 4 tests del caso de uso. De las cinco pantallas a redisenar (bienvenida, registro, onboarding, inicio, finanzas) solo `WelcomeScreen` tiene test, y lo unico que comprueba son dos literales (`find.text('Pagate-IA')` linea 21 y `find.text('Empezar ahora (Gratis)')` linea 22) que el rediseno va a cambiar. Registro (identity_step_screen.dart, 347 lineas), onboarding (setup_inicial_screen.dart, 290), inicio (home_tab.dart, 620) y finanzas (finanzas_tab.dart, 886) tienen cero tests: 2.143 lineas de UI sin una sola asercion.

**Corrección.** Antes de tocar el diseno, anadir un test de humo estructural por pantalla que NO dependa de textos: pumpear cada pantalla con fakes a 360x640, 412x915 y 800x1280 y afirmar `expect(tester.takeException(), isNull)` mas la presencia de los widgets clave por `find.byType` (no por texto). Es lo unico que sobrevive a un rediseno de copy y de estilo.

> *Matizado al verificar:* Los datos son exactos. `flutter test` con el SDK del proyecto (Dart 3.12.0-113.1.beta) termina en `00:00 +15: All tests passed!`, y el desglose coincide: `test/widget_test.dart:10` y `:33`, `bootstrap_error_app_test.dart:7` y `:23`, `firebase_options_test.dart:11`, `:23`, `:39`, `welcome_screen_test.dart:9`, `finances_provider_test.dart:115`, `:133`, `:156`, `calculate_hourly_rate_test.dart:13`, `:25`, `:47`, `:58`. `wc -l` da 620 (home_tab.dart) + 886 (finanzas_tab.dart) + 347 (identity_step_screen.dart) + 290 (setup_inicial_screen.dart) = 2143, tal cual. `welcome_screen_test.dart:21-22` son en efecto `expect(find.text('Págate-IA'), findsOneWidget);` y `expect(find.text('Empezar ahora (Gra…

#### `dart format` cambiaria 56 de 85 archivos y ningun workflow lo comprueba

`.github/workflows/ci.yml:26` · **Alta** · esfuerzo S

Medido hoy: `dart format -o none lib` reporta 'Formatted 79 files (55 changed)' y sobre test/ (excluyendo dos archivos temporales que dejo otro agente) 'Formatted 6 files (1 changed)'. Total 56 de 85. Es la diferencia entre el estilo viejo y el estilo 'tall' de Dart 3.7+; el `sdk: ^3.12.0-113.1.beta` de pubspec.yaml ya selecciona el nuevo. Ejemplo verificado en lib/main.dart:35-38 (el cuerpo de `build` con la indentacion antigua de dos niveles). Ni ci.yml ni deploy-web.yml ni AGENTS.md:15-20 ejecutan `dart format --set-exit-if-changed`, asi que la deriva es invisible.

**Corrección.** Normalizar el formato en un commit unico y aislado ANTES de empezar el rediseno, y anadir `dart format --output=none --set-exit-if-changed lib test` como paso de ci.yml justo antes de `flutter analyze`.

#### `deploy-web.yml` despliega reglas, functions y hosting sin ejecutar un solo test

`.github/workflows/deploy-web.yml:16` · **Alta** · esfuerzo S · **bloquea publicación**

Sigue igual que en la auditoria del 2026-09-21 (S1-10 en PLAN.md:84 esta en `todo`). El job `deploy` (lineas 16-20) no declara `needs:` de ningun job de ci.yml y sus pasos son build web (34-39), build functions (41-45) y dos deploys (49-67): cero `flutter test`, cero `npm test`. El script equivalente, scripts/deploy-web.sh:25-35, tampoco corre tests. Como se dispara con `workflow_dispatch` y con tags `v*`, un tag desde cualquier commit despliega reglas de Firestore sin verificarlas contra rules.test.ts.

**Corrección.** Convertir ci.yml en workflow reutilizable (`workflow_call`) y anadir `needs: [flutter, functions]` al job de deploy; en deploy-web.sh, ejecutar los tres bloques de verificacion de PLAN.md:12-14 antes de desplegar y abortar si alguno falla.

> *Matizado al verificar:* Verificado línea por línea y todo cuadra: `.github/workflows/deploy-web.yml` job `deploy:` en `:16` (name `:17`, runs-on `:18`, environment `:19`, steps `:20`) sin `needs:`; 'Build Flutter web' `:34-39`; 'Build Cloud Functions' `:41-45`; 'Deploy hosting' `:49-55` y 'Deploy firestore rules + functions' `:58-67`; ningún `flutter test` ni `npm test` en todo el archivo; triggers `workflow_dispatch` (`:4`) y `tags: ['v*']` (`:6`). `scripts/deploy-web.sh:25-35` igual: `flutter build web --release` (`:27`), `npm --prefix functions run build` (`:32`), `firebase deploy --only hosting,firestore,functions` (`:35`), cero tests. `docs/PLAN.md:84` S1-10 en `todo`, confirmado. Matices: es una re-notificac…

---

## 3. Hallazgos medios y bajos

Resumen en tabla. El detalle completo de cada uno está en el registro de la auditoría.

### Estado de la auditoría anterior

| Sev | Hallazgo | Ubicación | Corrección | Esf |
| --- | --- | --- | --- | --- |
| Media | [2.1-A] Clave antigua de OpenRouter sin revocar (VERIFICAR) | `README.md:91` | DUENO: revocar la clave antigua en el panel de OpenRouter, crear una nueva con limite de gasto y guardarla con `firebase functions:secrets:set OPENROUTER_API_KEY`. Anotar la revocacion en PLAN.md par… | S |
| Media | [2.1-A] Cache-Control de 1 ano sobre JS sin hash en el hosting | `firebase.json:26` | Dejar el cache largo solo en `assets/**` y `canvaskit/**`, y anadir `no-cache` explicito para `index.html`, `flutter_bootstrap.js` y `flutter_service_worker.js`. | S |
| Media | [2.1-M] Hosting sin CSP, HSTS, X-Frame-Options, nosniff ni Referrer-Policy | `firebase.json:15` | Anadir un bloque de headers para `**` con Strict-Transport-Security, X-Content-Type-Options: nosniff, X-Frame-Options: DENY, Referrer-Policy y una CSP (primero en Content-Security-Policy-Report-Only … | S |
| Media | [2.1-M] dev.sh levanta los emuladores contra el project id real | `scripts/dev.sh:15` | Anadir `--project demo-pagate` en dev.sh (el script de tests de functions ya lo usa: functions/package.json:17). Opcionalmente declarar un alias `staging` en .firebaserc (S1-13). | S |
| Media | [2.2-A] Service account escrita con echo, limpieza no garantizada y --force en el deploy | `.github/workflows/deploy-web.yml:62` | Migrar a Workload Identity Federation (google-github-actions/auth) o, como minimo, mover el borrado a un step con `if: always()`. Quitar `--force` y confirmar los borrados a mano. | M |
| Media | [2.2-M] Actions sin pin a SHA, sin bloque permissions y Flutter beta sin version fija | `.github/workflows/ci.yml:17` | Pinear cada action a su SHA completo, anadir `permissions: contents: read` a ci.yml y a deploy-web.yml, y fijar `flutter-version` a la beta concreta con la que se verifico el repo. | S |
| Media | [2.2-M] Sin APP_CHECK_SITE_KEY el build web de produccion sale con App Check apagado y solo un debugPrint | `.github/workflows/deploy-web.yml:39` | Fallar el build web de produccion cuando `Env.appCheckSiteKey` esta vacio y `PAGATE_ENV=prod` (assert en el bootstrap o comprobacion en el workflow antes del build). | S |
| Media | [2.2-M] Tests de functions sin typecheck, eslint no type-aware, sin Dependabot ni npm audit, sin .nvmrc | `functions/tsconfig.json:17` | Anadir functions/tsconfig.test.json que incluya `test` y correrlo en CI; pasar eslint a `recommendedTypeChecked`; crear .github/dependabot.yml para npm (functions, landing) y github-actions; anadir `… | S |
| Media | [2.3-A] waitlist: rate limit anulable por X-Forwarded-For, limitador en memoria, sin dedupe y localhost en la… | `functions/src/waitlist.ts:48` | S1-05: tomar el ultimo salto de XFF (VERIFICAR el formato que inyecta el front de Functions 2a gen), escribir con `doc(sha256(email)).set(..., {merge:true})` en vez de `.add()`, anadir Turnstile/reCA… | M |
| Media | [2.3-A] recalcMonth sigue haciendo read-then-write fuera de transaccion y sin retry | `functions/src/months.ts:27` | B2-01: envolver lectura y escritura en `db.runTransaction` (VERIFICAR que firebase-admin 14 permita aggregate dentro de transaccion; si no, usar FieldValue.increment desde el delta del evento), anadi… | M |
| Media | [2.3-M] La cuota diaria del chat sigue calculandose en UTC | `functions/src/chat.ts:42` | B2-02: formatear la clave del dia con la zona America/Santiago (Intl.DateTimeFormat con timeZone) y cubrirlo con un test de borde. | S |
| Media | [2.3-M] La cuota no se devuelve si OpenRouter falla y messageCount queda desfasado | `functions/src/chat.ts:193` | B2-02: en el catch, decrementar chatCountDay y borrar el mensaje de usuario (o marcarlo como fallido); anadir un reintento con backoff para errores 5xx/red; recortar el historial por presupuesto de c… | M |
| Media | [2.3-M] Los meses vaciados no se borran y el chat elige el 'ultimo mes' por id de documento | `functions/src/months.ts:31` | B2-01: borrar el documento del mes cuando `transactionCount == 0`. Alternativamente, en chat.ts filtrar por `transactionCount > 0`. | S |
| Media | [2.4-M] Ninguna regla de lectura limita request.query.limit | `firestore.rules:95` | C-1/S1-06: separar `get` de `list` y exigir `request.query.limit <= 200` en list; anadir `.limit()` en los datasources ANTES de desplegar las reglas nuevas (si no, se rompen las pantallas). | M |
| Media | [2.4-M] Sin tope numerico superior: Infinity en los agregados | `firestore.rules:37` | C-1: anadir tope (amount/price/monthlyGoal <= 1e12, stock/minStock <= 1e9) en las funciones de validacion y cubrirlo en rules.test.ts. | S |
| Media | [2.4-M] monthKey no se valida contra date | `firestore.rules:137` | C-1: derivar monthKey en el trigger a partir de date (y dejar de aceptarlo del cliente), o validarlo en reglas contra `d.date.toMillis()`. | M |
| Media | [2.5-A] DetalleItemScreen sigue recibiendo el item inmutable y muestra el stock viejo | `lib/features/inventory/presentation/pages/detalle_item_screen.dart:12` | B2-03: cambiar el constructor a `DetalleItemScreen({required this.itemId})` y resolver el item con `context.watch<InventoryProvider>()`, con estado vacio si el item fue borrado. | S |
| Media | [2.5-A] Sin verificacion de email al registrarse | `lib/core/services/firebase_auth_service.dart:44` | B2-06: enviar `sendEmailVerification()` tras crear la cuenta, mostrar un aviso persistente mientras `emailVerified` sea false y ofrecer reenvio. | M |
| Media | [2.5-M] 'Sugerencia del dia' con un dato inventado presentado como IA | `lib/features/dashboard/presentation/pages/ayuda_screen.dart:100` | B2-07: quitar la tarjeta, o calcular el 10% de la suma real de fixedExpenses del mes y formatearlo con el currency_formatter. | S |
| Media | [2.5-M] AiProvider deduplica los mensajes optimistas por rol+texto | `lib/features/dashboard/presentation/providers/ai_provider.dart:164` | B2-08: deduplicar por el id que devuelve el backend (ChatReply ya trae conversationId; conviene que devuelva tambien el id del mensaje) o por timestamp de creacion. | S |
| Media | [2.5-M] `?conversationId` ata el proyecto al SDK beta | `lib/core/services/ai_service.dart:58` | B2-08: sustituir por `if (conversationId != null) 'conversationId': conversationId` y reevaluar si el proyecto puede volver al canal stable (T3-07). | S |
| Media | [2.5-M] La persistencia offline de Firestore nunca se limpia al cerrar sesion | `lib/core/services/firebase_auth_service.dart:60` | B2-07: en signOut, envolver en try/catch y encadenar `FirebaseFirestore.instance.terminate()` + `clearPersistence()` antes de cerrar la sesion. | S |
| Media | [2.5-M] '1.234,56' no parsea y el formulario falla en silencio | `lib/features/finances/presentation/widgets/transaction_form_sheet.dart:117` | B2-03: normalizar quitando los separadores de miles antes de convertir la coma decimal, y mostrar un error de validacion en el campo en vez del `return` mudo. | S |
| Media | [2.5-M] Controllers dispuestos durante la animacion, showMessage con contexto ya popeado y _MonthlyGoalSync s… | `lib/features/finances/presentation/pages/finanzas_tab.dart:441` | B2-03: convertir el dialogo en un StatefulWidget que disponga sus controllers en dispose; capturar el ScaffoldMessenger antes del pop; anadir un flag `disposed` o un `context.mounted` antes del setMo… | M |
| Media | [2.5-M] IndexedStack en movil y _pages[i] en escritorio: se pierde el estado al cruzar 720 px | `lib/features/dashboard/presentation/pages/dashboard_screen.dart:195` | B2-03: usar IndexedStack en las dos ramas del LayoutBuilder. | S |
| Media | [2.5-M] Google Sign-In solo funciona en web y el boton de Apple es un stub visible en Android | `lib/core/services/google_auth_service.dart:20` | P4-07 adelantado: anadir el paquete google_sign_in para Android antes de publicar, u ocultar tambien el boton de Google en movil. Ocultar el boton de Apple hasta que exista la integracion (en Android… | M |
| Media | [2.5-M] La busqueda de inventario no tiene TextEditingController | `lib/features/inventory/presentation/providers/inventory_provider.dart:65` | B2-03: pasar un TextEditingController al campo de busqueda y limpiarlo junto con `_searchQuery` en setActiveTab. | S |
| Media | [2.6-M] La landing sigue con metricas, testimonios y roadmap inventados | `landing/src/components/Stats.tsx:7` | B2-10 (copy lo decide el DUENO): quitar Stats y Testimonials o sustituirlos por contenido verificable, y reescribir el Roadmap con fechas reales y sin porcentajes. | M |
| Media | [2.7] Huecos de cobertura de tests sin cambios | `functions/package.json:18` | T3-02 y T3-04: tests de las funciones puras del backend con fetch stub; `test:unit` sin archivo fijo; en Flutter, tests de los tres estados del AuthGate con stream inyectado, de serializacion de mode… | L |
| Media | [NUEVO por F0-02] El test de firebase_options rompera el CI en cuanto el dueno complete la configuracion web | `test/features/auth/firebase_options_test.dart:39` | Invertir la asercion: comprobar que la apiKey y el appId web no contienen placeholders ('...' ni 'xxxx'), que es la propiedad que de verdad se quiere garantizar, en vez de fijar el estado 'pendiente'. | S |
| Media | [NUEVO por F0-03] La pantalla de error de arranque muestra la excepcion cruda y usa el tema oscuro | `lib/features/auth/presentation/widgets/bootstrap_error_app.dart:79` | Mostrar un mensaje generico al usuario y dejar el detalle solo bajo `kDebugMode`; migrar la pantalla a la paleta clara unica cuando se elimine darkTheme; anadir estado de carga al reintento. | S |
| Baja | [2.2-B] ci.yml sigue disparando en la rama arquitectura-segura | `.github/workflows/ci.yml:5` | Quitar `arquitectura-segura` cuando se haga el merge a main. | S |
| Baja | [2.3-A] Prompt injection: campos de perfil y transacciones interpolados sin escapar | `functions/src/prompt.ts:82` | S1-08: anadir `sanitizeField()` que colapse saltos de linea y recorte la longitud, envolver cada valor en delimitadores explicitos y anadir tests de inyeccion a functions/test/prompt.test.ts. | S |
| Baja | [2.3-B] openrouter.ts: res.json() fuera del try que traduce errores, y el archivo sigue sin tests | `functions/src/openrouter.ts:77` | Envolver el `res.json()` en su propio try y lanzar `OpenRouterError('Respuesta no-JSON')`. Anadir tests con un stub de `fetch` (200 ok, 429, cuerpo vacio, JSON malformado, timeout). | S |
| Baja | [2.4-A] createdAt sigue siendo mutable y updatedAt no esta atado a request.time (y el cliente lo explota) | `firestore.rules:53` | C-1/S1-06: en update exigir `incoming().createdAt == resource.data.createdAt` y `incoming().updatedAt == request.time` en las cuatro colecciones; en el cliente, escribir createdAt solo en la creacion… | M |
| Baja | [2.4-B] validHourlyRate acepta un mapa vacio o parcial y eso rompe el cliente | `firestore.rules:59` | C-1: anadir `hasAll(['desiredMonthlySalary','availableHoursPerMonth','hourlyValue'])` en validHourlyRate y, en paralelo, hacer null-safe el fromJson del modelo (B2-05). | S |
| Baja | [2.4-B] isOwner no excluye usuarios anonimos | `firestore.rules:17` | Anadir `request.auth.token.firebase.sign_in_provider != 'anonymous'` a isOwner, o dejar el proveedor anonimo deshabilitado de forma explicita y documentado. | S |
| Baja | [2.4-B] rules.test.ts sigue sin cubrir los casos que mas importan | `functions/test/rules.test.ts:121` | T3-03: anadir un caso por cada regla nueva del contrato C-1 y los casos que faltan de las reglas actuales. | M |
| Baja | [2.5-A] HourlyRateModel.fromJson hace `as num` sin null-check dentro del map de un stream | `lib/features/hourly_value/data/models/hourly_rate_model.dart:12` | B2-05: `(json['desiredMonthlySalary'] as num?)?.toDouble() ?? 0` y devolver null si falta algun campo obligatorio; test de deserializacion con mapa parcial. | S |
| Baja | [2.5-B] Cuatro dependencias sin usar en pubspec.yaml (intl incluida) | `pubspec.yaml:21` | C-2: eliminar http, build_runner, json_serializable y cupertino_icons; conservar intl y empezar a usarla en el formateador de moneda. | S |
| Baja | [2.5-B] Codigo muerto, stubs 'Proximamente', version hardcodeada, FAQ desactualizada, indice sin uso y fuente… | `lib/core/widgets/pagate_info_card.dart:8` | B2-11 y B2-07/B2-09: borrar el codigo muerto (conservando updateTransaction/updateItem, que P4-01 va a necesitar), ocultar los stubs, leer la version del paquete, reescribir la FAQ contra las pantall… | M |
| Baja | [2.6-B] vitest de la landing corre en entorno node: imposible testear componentes | `landing/vite.config.ts:12` | T3-05: anadir jsdom como devDependency y marcar el entorno por archivo con `// @vitest-environment jsdom`, mas un test de WaitlistForm (validacion, envio, error). | S |
| Baja | [2.6-B] web/index.html conserva el titulo y la descripcion de la plantilla de Flutter | `web/index.html:21` | B2-09: poner titulo, descripcion y metadatos reales en web/index.html y revisar web/manifest.json (nombre, short_name, colores, iconos). | S |
| Baja | [NUEVO por F0-05] El cors de chat admite cualquier localhost tambien en produccion | `functions/src/chat.ts:145` | Construir la lista de origenes condicionando la entrada de localhost a `process.env.FUNCTIONS_EMULATOR`, igual que se hara en S1-05 para waitlist. | S |

### Sistema de diseño: tokens, tema y tipografía

| Sev | Hallazgo | Ubicación | Corrección | Esf |
| --- | --- | --- | --- | --- |
| Media | Cero soporte de cifras tabulares (tnum) en una app de dinero, pese a que Manrope las trae | `lib/core/theme/app_theme.dart:21` | Anadir al TextTheme una familia de estilos numericos (`amountLarge`, `amountMedium`, `amountSmall`, `numericSmall`) con `fontFeatures: const [FontFeature.tabularFigures()]` y `fontFeaturesculo` opcio… | S |
| Media | Tokens de glassmorphism: glass, glassStrong, GlassCard y el orbe con BackdropFilter | `lib/core/constants/app_constants.dart:77` | Borrar `glass` y `glassStrong` de app_constants.dart (desaparecen solos al borrar darkTheme). Borrar `glass_card.dart` entero y reemplazar su uso en hourly_rate_setup_page.dart por una superficie pla… | S |
| Media | Inputs sin borde visible y con radio 32: contradicen 'bordes discretos' y rompen la percepcion de campo | `lib/core/theme/app_theme.dart:192` | `enabledBorder` con `BorderSide(color: AppColors.border, width: 1)`, `focusedBorder` con brand a 1.5px, radio `sm`/`md`, `fillColor: AppColors.surface` (blanco) sobre fondo gris, `contentPadding` a 1… | S |
| Media | El propio tema hardcodea 10 fontSize en vez de derivar del TextTheme | `lib/core/theme/app_theme.dart:252` | Construir cada `textStyle` de componente con `textTheme.labelLarge?.copyWith(...)` etc., nunca con `TextStyle(fontFamily: ...)` suelto. Cuando se anada `fontVariations` para el peso de Manrope, esto … | S |
| Media | 162 violaciones de tokens (colores y tamanos hardcodeados) en 17 archivos | `lib/features/dashboard/presentation/widgets/financial_charts.dart:510` | Prioridad por volumen: financial_charts.dart y home_tab.dart concentran 65 de las 162. Los 45 `Colors.white`/`white70` son todos consecuencia del tema oscuro: desaparecen con la migracion a claro (pa… | L |
| Media | Faltan tokens semanticos de finanzas: ingreso/gasto se pintan reusando success/error | `lib/core/constants/app_constants.dart:35` | Anadir `AppColors.amountPositive` / `amountNegative` / `amountNeutral` (y sus fondos suaves), distintos de `success`/`error`. El gasto ordinario en texto primario con signo, no en rojo; el rojo se re… | S |
| Media | Configuracion de tema muerta: cardTheme, chipTheme, sliderTheme y bottomNavigationBarTheme no se aplican a na… | `lib/core/theme/app_theme.dart:175` | Borrar `cardTheme`, `chipTheme`, `sliderTheme` y `bottomNavigationBarTheme`. A cambio, anadir al tema claro lo que la app SI usa y hoy no esta tematizado: `navigationRailTheme`, `iconButtonTheme` (6 … | S |
| Media | PagateInfoCard tiene cero consumidores; GlassCard y PremiumTextField viven fuera del sistema | `lib/core/widgets/pagate_info_card.dart:8` | Borrar los tres archivos. Quitar `export 'pagate_info_card.dart';` de widgets.dart:11. Migrar los 3 usos de `PremiumTextField` en hourly_rate_setup_page.dart a `PagateTextField` (y si le falta algo, … | S |
| Media | Tres widgets compartidos hardcodean tokens del tema claro en vez de leer del tema | `lib/core/widgets/pagate_step_header.dart:52` | Sustituir por `Theme.of(context).colorScheme.*` / `textTheme.*`. Al pasar a tema unico claro el sintoma desaparece, pero la causa (componente compartido que no consume el tema) no: hay que arreglarla… | S |
| Media | PagateErrorState queda fuera del barrel, centra todo y solo lo usan 3 de 5 pantallas con estado de error | `lib/core/widgets/pagate_error_state.dart:7` | Exportarlo en widgets.dart. Reescribir alineado a la izquierda, sin icono gigante: titulo corto en w600, una linea de detalle en `textSecondary`, y un boton secundario 'Reintentar' rectangular (hoy u… | S |
| Media | Falta el estado vacio y hay 4 reimplementaciones; no existe ningun esqueleto de carga | `lib/features/finances/presentation/pages/finanzas_tab.dart:685` | Crear `PagateEmptyState({title, description, action})` alineado a la izquierda, sin icono grande, y `PagateSkeleton` / `PagateSkeletonRow` (rectangulos con el color `surfaceTertiary` y una animacion … | M |
| Media | Falta el chip de filtro y el selector de mes: 4 implementaciones distintas, ninguna reutilizable | `lib/features/finances/presentation/pages/finanzas_tab.dart:152` | Crear `PagateFilterChip` (rectangular, radio `sm`, borde 1px, estado seleccionado por fondo solido neutro y texto brand, altura 32) y `PagateMonthSelector({months, selected, onSelect})` como componen… | M |
| Media | Faltan encabezado de seccion y lista densa: los movimientos son tarjetas de 24px de radio, una por fila | `lib/features/dashboard/presentation/pages/configuracion_screen.dart:192` | Crear `PagateSectionHeader({title, trailing})` (titulo a la izquierda en `labelMedium` uppercase, accion opcional a la derecha, sin caja) y `PagateList` / `PagateListRow`: una sola superficie blanca … | M |
| Media | Manrope es defendible pero esta mal explotada; si se cambia, la alternativa es Inter | `pubspec.yaml:38` | Recomendacion: **conservar Manrope** y arreglar su uso (ver el hallazgo de fontVariations y el de tnum), que es el camino mas barato y ya cumple los criterios duros. Fijar la paleta de pesos a 500 (c… | S |
| Media | La licencia OFL de Manrope no se distribuye con la app ni hay pantalla de licencias | `pubspec.yaml:38` | Anadir `assets/fonts/OFL.txt` con el texto de la licencia, declarar la carpeta en la seccion `assets:` de pubspec.yaml, y registrarla en `LicenseRegistry.addLicense` desde el arranque. Anadir en conf… | S |
| Baja | 22 tokens declarados sin un solo uso en toda la app | `lib/core/constants/app_constants.dart:28` | Borrarlos todos en el mismo commit que la limpieza de glass/gradientes/sombras. Dejar la escala de espaciado como rejilla pura de 4 (4, 8, 12, 16, 24, 32, 48) sin alias semanticos, y bajar `screenHor… | S |
| Baja | PLAN.md sigue pidiendo 'tokens dark', contradiciendo la decision de producto del 2026-09-29 | `docs/PLAN.md:109` | Actualizar PLAN.md (B2-04 pasa a 'reescribir con el tema claro unico') y AGENTS.md (seccion 'UI y theming': un solo tema; nav propia, no BottomNavigationBar; tokens numericos con tnum obligatorios pa… | S |

### Las cinco pantallas que se rediseñan

| Sev | Hallazgo | Ubicación | Corrección | Esf |
| --- | --- | --- | --- | --- |
| Media | Bienvenida: círculo de 280px con degradado, sombra de 40px y BackdropFilter que no hace nada | `lib/features/auth/presentation/pages/welcome_screen.dart:108` | Borrar el `Positioned` del orbe (43-58), el `SizedBox` del hero (108-172) y el `import 'dart:ui'` de la línea 1. El espacio recuperado (~380px) se usa para contenido real: qué hace la app en tres lín… | S |
| Media | Bienvenida: superlativo vacío y todo centrado | `lib/features/auth/presentation/pages/welcome_screen.dart:201` | Alinear todo a la izquierda con un margen de 24px. Sustituir el superlativo por lo que la app hace de verdad y se puede comprobar ('Registra ventas y gastos, calcula tu valor hora y sabes cuánto te q… | S |
| Media | Registro: 'Paso 1 de 3' cuando el onboarding solo tiene 2 pantallas y la segunda no tiene cabecera | `lib/features/onboarding/presentation/pages/identity_step_screen.dart:86` | O `totalSteps: 2` y añadir `PagateStepHeader(currentStep: 2, totalSteps: 2)` en `setup_inicial_screen.dart`, o quitar el indicador de pasos de ambas. Dada la dirección densa y sobria, lo segundo: dos… | S |
| Media | Registro: 96px de espacio muerto y un degradado que no cubre nada | `lib/features/onboarding/presentation/pages/identity_step_screen.dart:229` | Borrar el `SizedBox` de la línea 229 y el `gradient` de la línea 238. Si se quiere el efecto de desvanecido hay que convertirlo en `Stack` de verdad; en una fintech densa, no hace falta. | S |
| Media | Registro: emoji en el titular, promesa falsa de pagos y enlaces legales que no son tappables | `lib/features/onboarding/presentation/pages/identity_step_screen.dart:104` | Quitar el emoji. Cambiar el copy por lo que la pantalla realmente hace ('Crea tu cuenta'). Añadir `TapGestureRecognizer` a ambos spans apuntando a las URLs reales, y sacar el bloque del `Center`. | S |
| Media | Onboarding: el nombre se reinyecta al campo si el usuario lo borra | `lib/features/onboarding/presentation/pages/setup_inicial_screen.dart:39` | Precargar una sola vez con un flag `_prefilled` (o en `initState` más un listener puntual al servicio), y usar `controller.value = TextEditingValue(text: v, selection: TextSelection.collapsed(offset:… | S |
| Media | Onboarding: dos componentes de chip distintos en la misma pantalla y claims vacíos | `lib/features/onboarding/presentation/pages/setup_inicial_screen.dart:242` | Un solo componente de selección para ambos casos. Botón etiquetado por lo que hace ('Guardar y continuar'). Quitar el '2 minutos'. | S |
| Media | Onboarding: sin cabecera, sin estado de error y sin forma de volver | `lib/features/onboarding/presentation/pages/setup_inicial_screen.dart:101` | Añadir el mismo patrón `PagateErrorState` + `retry()` que usa finanzas, y una cabecera coherente con la decisión que se tome sobre los pasos. | S |
| Media | Inicio: 'Balance del Mes' y 'Actividad Reciente' muestran el mes seleccionado en Finanzas, no el actual | `lib/features/dashboard/presentation/pages/tabs/home_tab.dart:141` | Que Inicio lea siempre el mes en curso (`FinancesProvider.currentMonthKey`) en lugar de la selección de Finanzas, o que el título muestre el mes explícito ('Septiembre' en vez de 'del Mes'). 'Activid… | M |
| Media | Finanzas: el botón de exportar PDF descarga la fuente por red y usa una tipografía ajena a la marca | `lib/features/finances/presentation/pages/finanzas_tab.dart:133` | Cargar Manrope desde los assets con `pw.Font.ttf(await rootBundle.load(...))` y eliminar la dependencia de red. Deshabilitar el botón cuando no hay movimientos en el mes. | S |
| Media | Finanzas: no hay chip para el mes en curso si todavía está vacío | `lib/features/finances/presentation/pages/finanzas_tab.dart:107` | Garantizar siempre un chip para `FinancesProvider.currentMonthKey`, aunque no tenga documento, y ordenar la lista con el mes actual primero. Hacer scroll al seleccionado al entrar. | S |
| Media | Títulos en Title Case inglés en las cinco pantallas (10 ocurrencias) | `lib/features/dashboard/presentation/pages/tabs/home_tab.dart:169` | Pasar los 10 a mayúscula inicial única. Aprovechar para acortar: 'Balance del Mes' → el mes concreto ('Septiembre'), 'Métricas Financieras' → fuera (la sección sobra si los gráficos bajan). | S |
| Media | Etiquetas de formulario con contraste insuficiente para Play Store | `lib/core/widgets/pagate_label.dart:22` | Usar `AppColors.textSecondary` (#6B7280, ~5.7:1) y subir a 12px, o consumir `colorScheme.onSurfaceVariant`. Revisar de paso los textos de 10px hardcodeados en `welcome_screen.dart:296` y `:370` y en … | S |
| Media | Los campos de texto no tienen autofill ni acción de teclado | `lib/core/widgets/pagate_text_field.dart:56` | Añadir los tres parámetros al widget. En registro: `autofillHints: [AutofillHints.name / .email / .newPassword]`, `textInputAction: next` en los dos primeros y `done` con `onFieldSubmitted: (_) => _o… | S |
| Baja | Finanzas: el FAB deshabilitado se ve idéntico al habilitado | `lib/features/finances/presentation/pages/finanzas_tab.dart:56` | Quitar los colores explícitos y dejar que el tema aplique el estado deshabilitado, u ocultar el FAB cuando `provider.error != null` (la pantalla ya muestra `PagateErrorState` con reintento en esa sit… | S |
| Baja | Finanzas: Dismissible sin onDismissed depende de que el stream llegue antes de terminar la animación | `lib/features/finances/presentation/pages/finanzas_tab.dart:738` | Añadir `onDismissed` (aunque sea para registrar) o cambiar a `confirmDismiss` que devuelva `false` y elimine solo vía stream, con un `AnimatedList`/`SnackBar` de deshacer si se quiere permitir revert… | S |

### Las pantallas que solo se limpian

| Sev | Hallazgo | Ubicación | Corrección | Esf |
| --- | --- | --- | --- | --- |
| Media | La pagina de Valor Hora no tiene boton de volver: callejon sin salida | `lib/features/hourly_value/presentation/pages/hourly_rate_setup_page.dart:157` | Anadir la cabecera estandar con PagateBackButton, igual que configuracion_screen.dart:33-46 y ayuda_screen.dart:52-65. Y que el boton 'Continuar' del dialogo de exito cierre el dialogo y haga pop de … | S |
| Media | La FAQ miente sobre donde se configura la meta y sobre los campos del formulario | `lib/features/dashboard/presentation/pages/ayuda_screen.dart:25` | Reescribir las 4 respuestas contra la app real: la meta se edita en Perfil > Configuracion > Meta de ingresos; el formulario pide titulo, monto, categoria y fecha. Y anadir la pregunta que falta y qu… | S |
| Media | Contacto de soporte falso: un dominio que no existe y un "Chat en vivo (Pro)" que no lleva a ningun lado | `lib/features/dashboard/presentation/pages/ayuda_screen.dart:235` | Dejar una sola fila de contacto con un correo que exista de verdad (el mismo que se declare como email de soporte en la ficha de Play, requisito obligatorio) y que al tocarla abra el cliente de corre… | S |
| Media | "Calificar la App" y "Compartir Pagate-IA" no hacen nada | `lib/features/user_profile/presentation/pages/perfil_tab.dart:165` | Ahora que el objetivo es publicar en Play: 'Calificar la App' debe abrir market://details?id=com.pagate.apppagate con url_launcher (y solo mostrarse en Android). 'Compartir' debe usar el share sheet … | S |
| Media | La seccion Notificaciones de Configuracion es un stub completo: dos filas "Proximamente" | `lib/features/dashboard/presentation/pages/configuracion_screen.dart:134` | Borrar la seccion entera (lineas 134-157). Un ajuste que no existe no se anuncia en Configuracion; cuando exista FCM (P4-07) se vuelve a anadir. Ocultar stubs es exactamente lo que pide la tarea B2-0… | S |
| Media | Los graficos pintan "$-5000" y "1500.0K": el formateador no contempla negativos ni millones | `lib/features/dashboard/presentation/widgets/financial_charts.dart:499` | Reemplazar _fmt por el currency_formatter compartido de C-2, con una variante compacta que maneje el signo aparte del simbolo ('-$5.000') y escale a M cuando corresponda. Aplicarlo en las cuatro llam… | S |
| Media | El grafico de tendencia se rompe cuando todos los meses son negativos | `lib/features/dashboard/presentation/widgets/financial_charts.dart:199` | Calcular el rango con padding relativo al recorrido real en ambos sentidos y no anclar a 0 ni a 1000: por ejemplo range = maxY - minY (con un minimo si es 0), minY - range*0.15 y maxY + range*0.15, d… | S |
| Media | Divisor colgante permanente al final de la tarjeta de detalle: supplier y code nunca se llenan | `lib/features/inventory/presentation/pages/detalle_item_screen.dart:196` | Dos opciones coherentes: (a) borrar supplier y code del modelo y de la UI si no se van a pedir; (b) anadirlos como campos opcionales en el formulario de alta. En cualquier caso, resolver el divisor p… | S |
| Media | La campana de notificaciones de Inicio abre la pantalla de Ayuda | `lib/features/dashboard/presentation/pages/dashboard_screen.dart:66` | Como no hay sistema de notificaciones (ver el hallazgo de la seccion Notificaciones), quitar la campana de la cabecera de Inicio. Si se quiere dejar acceso a la ayuda desde Inicio, usar Icons.help_ou… | S |
| Media | En escritorio se pierde el estado de las pestanas al cruzar los 720 px | `lib/features/dashboard/presentation/pages/dashboard_screen.dart:195` | Usar IndexedStack tambien en _buildDesktopLayout, exactamente igual que en movil. Es la tarea B2-03 del PLAN. | S |
| Media | La meta mensual escrita con puntos de miles se rechaza sin explicar por que | `lib/features/dashboard/presentation/pages/editar_perfil_screen.dart:60` | Usar el mismo parseAmount del currency_formatter de C-2 para los dos formularios, y formatear el campo mientras se escribe. Mostrar el error bajo el campo con un validator en vez de en un snackbar ge… | S |
| Media | La pagina de Valor Hora no precarga el valor ya guardado: el formulario siempre sale vacio | `lib/features/hourly_value/presentation/pages/hourly_rate_setup_page.dart:22` | En didChangeDependencies (con el mismo patron de guarda _initialized que usa editar_perfil_screen.dart:35-47) rellenar los tres campos desde provider.currentRate cuando exista, y cambiar el titulo a … | S |
| Media | Promesa falsa: "calcular el costo real de tus productos" es una funcionalidad que no existe | `lib/features/hourly_value/presentation/pages/hourly_rate_setup_page.dart:139` | Ajustar los dos textos a lo que la app hace de verdad hoy: el valor hora queda guardado y el asistente lo tiene en cuenta al responder sobre precios. Si se quiere sostener la promesa, la tarea es ana… | S |
| Media | Se le muestra al usuario el texto crudo de la excepcion | `lib/features/auth/presentation/widgets/bootstrap_error_app.dart:79` | Mapear el error con el describeFirebaseError que ya existe en lib/core/config/firebase_errors.dart y que usan login_screen.dart:67 y configuracion_screen.dart:187, en vez de interpolar el objeto. Si … | S |
| Media | "Pagate-IA v1.0.0 - MVP" hardcodeado en el pie de Perfil | `lib/features/user_profile/presentation/pages/perfil_tab.dart:196` | Quitar '- MVP' y leer la version con package_info_plus en vez de escribirla, para que siga a pubspec y al versionCode que Play exige subir en cada release. | S |
| Media | El chat de IA muta estado dentro de build() | `lib/features/dashboard/presentation/pages/tabs/ia_tab.dart:57` | Mover la deteccion a didChangeDependencies o suscribirse al AiProvider con un listener que dispare el scroll, dejando build sin efectos. Anadir ademas padding inferior al ListView (lineas 87-99) para… | S |
| Baja | glass_card.dart y premium_text_field.dart: se BORRAN los dos, solo los usa la pagina de valor hora | `lib/features/hourly_value/presentation/widgets/glass_card.dart:4` | BORRAR ambos archivos. Al reescribir hourly_rate_setup_page usar PagateLabel + PagateTextField de lib/core/widgets/, que es lo que ya usan editar_perfil_screen.dart y transaction_form_sheet.dart. Cer… | S |
| Baja | El buscador de inventario recibe un parametro muerto y no se puede limpiar | `lib/features/inventory/presentation/pages/inventario_tab.dart:235` | Convertir _InventarioHeader en StatefulWidget con su propio TextEditingController inicializado desde provider.searchQuery, y anadir un suffixIcon de limpiar que llame a provider.search('') y vacie el… | S |
| Baja | El grafico de categorias no dice de que periodo habla, y sus etiquetas son ilegibles | `lib/features/dashboard/presentation/widgets/financial_charts.dart:312` | Poner el periodo en el titulo ('Gastos de Marzo 2025', usando el monthLabelFromKey que ya existe). Sacar los porcentajes de dentro de las porciones y dejarlos solo en la leyenda de la derecha, que ya… | M |
| Baja | Cerrar sesion sin confirmacion y sin manejo de error | `lib/features/user_profile/presentation/pages/perfil_tab.dart:188` | Dialogo de confirmacion, try/catch con describeFirebaseError, y limpieza de la persistencia de Firestore antes de cerrar sesion. Es parte de la tarea B2-07 del PLAN. | S |
| Baja | El boton Guardar de Editar Perfil se estiliza a mano en vez de usar el boton compartido | `lib/features/dashboard/presentation/pages/editar_perfil_screen.dart:294` | Sustituir por PagatePrimaryButton(label: 'Guardar cambios', isLoading: _isSaving, onPressed: _onSave). | S |
| Baja | El mensaje de confirmacion se lanza con un context ya desmontado | `lib/features/finances/presentation/widgets/transaction_form_sheet.dart:144` | Capturar el ScaffoldMessengerState antes del pop, igual que ya se captura el Navigator en la linea 133, y usar esa referencia para mostrar el snackbar. Mismo patron a revisar en detalle_item_screen.d… | S |

### Accesibilidad, contraste y adaptabilidad

| Sev | Hallazgo | Ubicación | Corrección | Esf |
| --- | --- | --- | --- | --- |
| Media | Áreas táctiles por debajo de 48x48 dp en 11 controles (medidas, no estimadas) | `lib/core/constants/app_constants.dart:194` | Añadir a `AppSizes` un `minTouchTarget = 48.0` y aplicarlo: subir `backButtonSize` a 48 (o envolver en `SizedBox(width: 48, height: 48)`), subir `chipHeight` a 48 y el padding vertical de las pastill… | M |
| Media | El texto blanco de las porciones del gráfico de torta falla en 9 de los 10 colores | `lib/features/dashboard/presentation/widgets/financial_charts.dart:362` | Sacar el porcentaje de dentro de la porción y llevarlo a la leyenda de la derecha (financial_charts.dart:408-415), que ya lo muestra; o usar `titleStyle` con el color de texto oscuro sobre los tonos … | S |
| Media | El botón atrás de Android descarta formularios a medio llenar sin avisar (cero PopScope en toda la app) | `lib/features/finances/presentation/widgets/transaction_form_sheet.dart:33` | Envolver los dos sheets y las dos pantallas de formulario en `PopScope(canPop: !_hasUnsavedChanges, onPopInvokedWithResult: ...)` mostrando un diálogo "¿Descartar cambios?". Añadir una `AppBar` con `… | M |
| Media | Ninguna de las 5 pestañas usa SafeArea: con edge-to-edge (obligatorio en Android 15) la cabecera queda bajo l… | `lib/features/dashboard/presentation/pages/dashboard_screen.dart:206` | Envolver el `body` del `Scaffold` móvil y el `Row` del layout de escritorio en `SafeArea`, o poner `SafeArea(bottom: false)` en la raíz de cada tab. Añadir `useSafeArea: true` a `showModalBottomSheet… | S |
| Media | La app no declara localización: TalkBack anuncia los roles en inglés y el selector de fecha sale en inglés | `lib/features/auth/presentation/widgets/app_shell.dart:22` | Añadir `flutter_localizations: {sdk: flutter}` a `pubspec.yaml` y en `AppShell`: `locale: const Locale('es')`, `supportedLocales: const [Locale('es'), Locale('en')]`, `localizationsDelegates: GlobalM… | S |
| Media | Los tres gráficos no exponen nada al lector de pantalla y las cifras se abrevian como "1.8K" | `lib/features/dashboard/presentation/widgets/financial_charts.dart:38` | Envolver cada gráfico en `Semantics(label: ...)` con un resumen en texto ("Ingresos de septiembre 1.850.000 pesos, gastos 940.000, balance 910.000") y marcar el `CustomPaint` con `ExcludeSemantics`. … | M |
| Media | Borrar un movimiento solo es posible deslizando: sin alternativa para lector de pantalla ni para movilidad re… | `lib/features/finances/presentation/pages/finanzas_tab.dart:738` | Añadir al `Dismissible` `Semantics(customSemanticsActions: {const CustomSemanticsAction(label: 'Eliminar movimiento'): () => ...})`, o —mejor para el rediseño— hacer que tocar el movimiento abra un d… | S |
| Media | Alturas fijas y 57 fontSize literales que ignoran el escalado del sistema | `lib/features/finances/presentation/widgets/transaction_form_sheet.dart:328` | Sustituir los alto fijos por `ConstrainedBox(minHeight: ...)` o `IntrinsicHeight`, añadir `maxLines`+`overflow` a los `Text` dentro de cajas fijas, y reemplazar los 57 `fontSize` literales por estilo… | M |
| Media | Elementos decorativos y datos inventados que el lector de pantalla lee como si fueran reales | `lib/features/auth/presentation/pages/welcome_screen.dart:146` | Envolver los decorativos en `ExcludeSemantics` y, mejor aún en el marco del rediseño, eliminarlos: las tarjetas flotantes del hero, el orbe borroso y el punto rojo falso están en la lista de prohibic… | S |
| Baja | Diálogos con contraste insuficiente, sin etiquetas y con títulos que desbordan | `lib/features/hourly_value/presentation/pages/hourly_rate_setup_page.dart:101` | Envolver el título en `Expanded`/`Flexible`; dar a los `TextField` de los diálogos `labelText` además del hint y el color de hint corregido de la nueva paleta; definir un `ElevatedButton.styleFrom` e… | S |

### Estructura y salud del código Flutter

| Sev | Hallazgo | Ubicación | Corrección | Esf |
| --- | --- | --- | --- | --- |
| Media | Controllers dispuestos antes de que el dialogo/sheet termine su animacion de salida (3 sitios) | `lib/features/inventory/presentation/pages/inventario_tab.dart:155` | Convertir los tres contenidos de dialogo/sheet en StatefulWidget propios (`_NuevoItemSheet`, `_NuevoGastoFijoDialog`, `_ActualizarStockDialog`) que creen los controllers en initState y los liberen en… | M |
| Media | Seis implementaciones distintas de formateo de moneda, ninguna usa `intl` ni respeta `profile.currency` | `lib/features/finances/presentation/pages/finanzas_tab.dart:15` | `lib/core/utils/currency_formatter.dart` con `String formatCurrency(num value, {required String currency, bool compact = false})` sobre `NumberFormat.currency` de intl (CLP sin decimales y locale es_… | M |
| Media | Siete controles que solo muestran un snackbar de 'proximamente' | `lib/features/dashboard/presentation/pages/configuracion_screen.dart:137` | Borrar los siete controles y el selector de pais. 'Calificar' y 'Compartir' se pueden implementar de verdad con url_launcher y share_plus si se quieren conservar; el boton de Apple debe desaparecer h… | S |
| Media | Trocear los 7 archivos grandes: corte concreto por archivo | `lib/features/finances/presentation/pages/finanzas_tab.dart:1` | finanzas_tab.dart -> presentation/pages/finanzas_tab.dart (solo FinanzasTab + FAB, ~70), widgets/finanzas_month_selector.dart (_FinanzasHeader+estado y el export a PDF, ~130), widgets/finanzas_summar… | L |
| Media | Logica de negocio dentro de widgets: agregacion, sincronizacion y escalas de grafico en build() | `lib/features/dashboard/presentation/widgets/financial_charts.dart:315` | Mover a FinancesProvider los getters derivados `expensesByCategory`, `monthsChronological` y `chartMaxY` (cacheados, recalculados solo al llegar datos nuevos). Sustituir `_MonthlyGoalSync` por un `Pr… | M |
| Media | Cuatro tablas distintas de nombres de mes y un quinto derivado por corte de string | `lib/features/finances/domain/entities/finances_summary_entity.dart:46` | Un unico `lib/core/utils/month_labels.dart` con `monthNameLong(int)`, `monthNameShort(int)` y `monthLabelFromKey(String)` sobre `DateFormat.MMMM('es_CL')` de intl. Borrar las 4 listas y reescribir `_… | S |
| Media | Ciclo de dependencias entre features user_profile y dashboard | `lib/features/user_profile/presentation/pages/perfil_tab.dart:7` | Mover `configuracion_screen.dart` y `editar_perfil_screen.dart` a `lib/features/user_profile/presentation/pages/` y `ayuda_screen.dart` a `lib/features/support/presentation/pages/` (o a user_profile … | S |
| Media | La raiz de inyeccion vive dentro de features/auth, que acaba dependiendo de otras 6 features | `lib/features/auth/presentation/widgets/user_scope.dart:9` | Mover `UserScope`, `ProfileGate` y las 5 fabricas `create*Provider` a `lib/app/user_scope.dart` (o `lib/core/di/`), dejando en features/auth solo AuthGate, login, welcome y splash. Mover `financial_c… | M |
| Media | Excepciones tragadas sin registro en AiProvider (3 sitios) | `lib/features/dashboard/presentation/providers/ai_provider.dart:138` | Registrar siempre antes de traducir: `debugPrint('AiProvider: ...: $e\n$st')` en los tres sitios (con `catch (e, st)`), y en `_onStreamError(Object error, StackTrace st)`. Cuando se anada Crashlytics… | S |
| Media | Mutacion de estado dentro de build() en la pestana de IA | `lib/features/dashboard/presentation/pages/tabs/ia_tab.dart:57` | Sustituir por un listener explicito: en initState suscribirse al AiProvider (`addListener`) y comparar longitudes ahi, o usar un `ValueListenableBuilder`/`didUpdateWidget`. Guardar `_renderedCount` f… | S |
| Media | El PDF descarga sus tipografias por red y duplica 7 colores de marca | `lib/core/services/pdf_report_service.dart:43` | Cargar Manrope desde el asset con `pw.Font.ttf(await rootBundle.load('assets/fonts/Manrope[wght].ttf'))`, sin red. Derivar los 7 PdfColor de AppColors con un helper `PdfColor.fromInt(AppColors.brand.… | S |
| Media | Cinco dependencias de pubspec sin un solo import y una que falta para publicar | `pubspec.yaml:13` | Quitar cupertino_icons, http, build_runner y json_serializable. Empezar a usar intl en currency_formatter y month_labels. Anadir google_sign_in (y configurar el SHA-1/SHA-256 en Firebase), url_launch… | S |
| Media | Dos componentes de campo de texto y una tarjeta glassmorphism compitiendo con core/widgets | `lib/features/hourly_value/presentation/widgets/premium_text_field.dart:6` | Borrar glass_card.dart y premium_text_field.dart, reescribir hourly_rate_setup_page con PagateTextField y una tarjeta de borde discreto; sustituir `_SheetField` por PagateTextField; anadir `export 'p… | S |
| Media | El estado de las pestanas se pierde al cruzar el breakpoint de 720 px | `lib/features/dashboard/presentation/pages/dashboard_screen.dart:195` | Usar `IndexedStack` en las dos ramas: en `_buildDesktopLayout` sustituir `_pages[_currentIndex]` por `IndexedStack(index: _currentIndex, children: _pages)`. | S |
| Media | Consultas de Firestore sin limite en los cuatro datasources | `lib/features/finances/data/datasources/finances_firebase_datasource.dart:43` | Anadir `.limit(200)` a transacciones e items, `.limit(36)` a meses, `.limit(100)` a gastos fijos y `.limitToLast(100)` al stream de mensajes, coordinado con la regla `request.query.limit <= 200` que … | M |
| Baja | HourlyRateModel.fromJson hace `as num` sin comprobar nulo dentro de un stream | `lib/features/hourly_value/data/models/hourly_rate_model.dart:12` | Usar `(json['desiredMonthlySalary'] as num?)?.toDouble()` y devolver null desde `_fromData` si falta cualquiera de los dos campos, igual que ya hace con las horas. Anadir un test de deserializacion c… | S |
| Baja | Codigo muerto verificado: 8 simbolos sin un solo uso en lib/ ni test/ | `lib/features/finances/presentation/providers/finances_provider.dart:59` | Borrar los 8 simbolos y las dos cadenas de repositorio. Conservar `updateTransaction` y `updateItem` (finances_provider.dart:189, inventory_provider.dart:110), que hoy tampoco se usan desde la UI per… | S |
| Baja | Veintiun tokens de diseno sin uso y AppShadows escrito con literales en vez de tokens | `lib/core/constants/app_constants.dart:81` | Borrar los 21 tokens muertos al hacer la limpieza de la paleta oscura, hacer que AppShadows use AppColors.shadowLight/shadowMedium, y mover `_pieColors` a app_constants.dart como `AppColors.categoric… | S |
| Baja | La busqueda del inventario no tiene controller y no se puede limpiar | `lib/features/inventory/presentation/pages/inventario_tab.dart:235` | Convertir `_InventarioHeader` en StatefulWidget con su propio `TextEditingController` liberado en dispose, sincronizarlo con `provider.searchQuery` y anadir un suffixIcon de limpiar. Al mover el shee… | S |
| Baja | UserProfileProvider es el unico provider sin proteccion frente a notificar tras dispose | `lib/features/user_profile/presentation/providers/user_profile_provider.dart:115` | Replicar en UserProfileProvider y HourlyRateProvider el flag `_disposed` y el helper `_notify()` que ya usan los otros tres providers, por consistencia y para cerrar el hueco del finally tras await. | S |
| Baja | Version de la app escrita a mano y etiquetada como MVP | `lib/features/user_profile/presentation/pages/perfil_tab.dart:196` | Leer la version con package_info_plus (`PackageInfo.fromPlatform()`) y mostrar solo `v${info.version}`, sin el sufijo MVP. | S |
| Baja | BackdropFilter que no filtra nada en la pantalla de bienvenida | `lib/features/auth/presentation/pages/welcome_screen.dart:53` | Borrar el Positioned completo (lineas 43-58) junto con el resto del hero decorativo; el import `dart:ui` de la linea 1 se queda sin uso y tambien se va. | S |

### Backend, reglas y coste

| Sev | Hallazgo | Ubicación | Corrección | Esf |
| --- | --- | --- | --- | --- |
| Media | Si OpenRouter falla, la cuota ya se consumió, el mensaje del usuario quedó guardado y `messageCount` se desin… | `functions/src/chat.ts:250` | Mover la escritura del mensaje del usuario y el incremento de cuota después de una respuesta correcta, o compensarlos en el `catch` (`FieldValue.increment(-1)` sobre `chatCountDay` y borrado de la co… | M |
| Media | Un único modelo por defecto sin alternativa: si OpenRouter lo retira o devuelve 402, el chat muere entero y e… | `functions/src/config.ts:14` | Declarar un modelo de respaldo (`OPENROUTER_MODEL_FALLBACK`) y reintentar con él ante 404/429/503. Propagar el `status` de `OpenRouterError` a `chat.ts` y mapear: 402/401 → `unavailable` con mensaje … | M |
| Media | `maxInstances: 5` con 256 MiB fija la concurrencia en 1: el chat soporta 5 conversaciones simultáneas en todo… | `functions/src/chat.ts:141` | Subir a `memory: '512MiB'` con `cpu: 1` y `concurrency: 20` (la función pasa casi todo su tiempo esperando una respuesta HTTP, así que la concurrencia es prácticamente gratis) y ajustar `maxInstances… | S |
| Media | Las reglas no ponen techo superior a ningún número: los agregados mensuales pueden quedar en `Infinity` | `firestore.rules:37` | Añadir topes en los helpers: `v is number && v >= 0 && v <= 1e12` y `v is number && v > 0 && v <= 1e12`; para `stock`/`minStock`, `v is int && v >= 0 && v <= 1e9`. Blindar además `months.ts:32-34` co… | S |
| Media | `createdAt` es mutable y `updatedAt` no está atado a `request.time`: el cliente puede reescribir la historia | `firestore.rules:97` | En cada `allow update`, exigir `incoming().createdAt == resource.data.createdAt && incoming().updatedAt == request.time`; en cada `allow create`, `incoming().createdAt == request.time && incoming().u… | M |
| Media | Ninguna regla de lectura limita el tamaño de la consulta y ningún datasource usa `.limit()` | `firestore.rules:95` | Añadir `.limit(200)` (o el valor del contrato C-1) a los seis streams y, en reglas, condicionar las lecturas de colección: `allow list: if isOwner(uid) && request.query.limit <= 200;` separando `get`… | M |
| Media | El system prompt interpola campos del usuario sin escapar: inyección de prompt | `functions/src/prompt.ts:82` | Añadir `sanitizeField(v)` que recorte a un máximo, colapse saltos de línea (`/\s+/g → ' '`) y elimine los caracteres de marcado de sección (`#`, `-` al inicio, backticks). Envolver los bloques de dat… | S |
| Media | La cuota diaria se calcula en UTC, no en horario de Chile | `functions/src/chat.ts:42` | Calcular el `dayKey` con `Intl.DateTimeFormat('en-CA', { timeZone: 'America/Santiago' }).format(date)`, que devuelve directamente `yyyy-MM-dd`. Añadir un test unitario con una fecha límite (23:30 UTC… | S |
| Media | `deploy-web.yml` despliega reglas y funciones sin correr un solo test, con `--force` y sin bloque `permission… | `.github/workflows/deploy-web.yml:66` | Añadir un job `tests` con `flutter analyze && flutter test`, `npm --prefix functions run lint && build && test` y el bloque de landing, y `needs: [tests]` en `deploy`. Quitar `--force`. Escribir el s… | M |
| Media | `firebase.json` cachea un año los bundles de Flutter sin hash: los usuarios web se quedan atascados en la ver… | `firebase.json:26` | Restringir el caché largo a `assets/**`, `canvaskit/**` y `**/*.@(png|jpg|svg|woff2)`; poner `Cache-Control: no-cache` en `/index.html`, `/flutter_bootstrap.js`, `/flutter_service_worker.js` y `/main… | S |
| Media | `scripts/dev.sh` levanta los emuladores contra el project id real de producción | `scripts/dev.sh:15` | Cambiar a `firebase emulators:start --project demo-pagate` en scripts/dev.sh:15. El prefijo `demo-` hace que el CLI garantice que no se toca ningún proyecto real. | S |
| Media | `scripts/deploy-web.sh` despliega sin `--project`, sin comprobar la rama y sin correr tests | `scripts/deploy-web.sh:35` | Añadir `--project pagate-17211` a la línea 35; antes del build, ejecutar los tres bloques de verificación de AGENTS.md y abortar si alguno falla; comprobar `git rev-parse --abbrev-ref HEAD` y el árbo… | S |
| Media | `chat` no exige perfil de usuario ni correo verificado, y su lista CORS incluye localhost en producción | `functions/src/chat.ts:149` | Al principio del handler, leer `users/{uid}` y lanzar `failed-precondition` si no existe (ya se lee el perfil dentro de la transacción de chat.ts:178, así que basta con mover la comprobación). Exigir… | S |
| Media | Cero tests de `chat.ts`, `months.ts`, `waitlist.ts` y `openrouter.ts`, y los tests de reglas no cubren los ca… | `functions/test/rules.test.ts:121` | Añadir `functions/test/chat.test.ts`, `months.test.ts`, `waitlist.test.ts` y `openrouter.test.ts` (los dos primeros contra el emulador, ya disponible vía `emulators:exec`; los dos últimos puros con s… | L |
| Baja | Índice compuesto `monthKey + date` declarado pero nunca usado | `firestore.indexes.json:3` | Borrar el primer bloque de `firestore.indexes.json` y redesplegar los índices. Si más adelante se añade `.orderBy('date')` a la consulta del datasource, volver a crearlo. | S |
| Baja | `validHourlyRate` acepta un mapa vacío o parcial, e `isOwner` no distingue usuarios anónimos | `firestore.rules:59` | Añadir `r.keys().hasAll(['desiredMonthlySalary', 'availableHoursPerMonth', 'hourlyValue'])` a `validHourlyRate`. En `isOwner`, añadir `&& request.auth.token.firebase.sign_in_provider != 'anonymous'` … | S |

### Requisitos técnicos de Google Play

| Sev | Hallazgo | Ubicación | Corrección | Esf |
| --- | --- | --- | --- | --- |
| Media | Nunca se ha compilado un release: no hay AAB, no hay APK release y CI no toca Android | `.github/workflows/ci.yml:13` | AGENTE: anadir al workflow un job `android` con `flutter build appbundle --release` (usando un keystore de CI desde secretos, o al menos `flutter build apk --debug` mientras no haya keystore) y subir… | M |
| Media | R8 y shrinkResources se activan por defecto en release y no hay proguard-rules.pro | `android/app/build.gradle.kts:34` | Crear `android/app/proguard-rules.pro` con, como minimo: `-keep class io.flutter.** { *; }` no hace falta (ya lo cubre flutter_proguard_rules), pero si `-dontwarn com.google.firebase.**`, `-dontwarn … | M |
| Media | android.permission.INTERNET no esta en el manifest principal; solo llega por merge de las AAR de Firebase | `android/app/src/main/AndroidManifest.xml:1` | Declarar explicitamente `<uses-permission android:name="android.permission.INTERNET"/>` en el manifest principal. Despues de la primera build de release, revisar `build/app/intermediates/merged_manif… | S |
| Media | allowBackup no esta declarado: por defecto true, con la sesion y la cache de Firestore copiadas a Google Drive | `android/app/src/main/AndroidManifest.xml:2` | Anadir `android:allowBackup="false"` y `android:dataExtractionRules="@xml/data_extraction_rules"` al `<application>` (mas `android:fullBackupContent="@xml/backup_rules"` para API <31), con `res/xml/d… | S |
| Media | versionCode y versionName no tienen proceso: salen de pubspec y de un local.properties ignorado por git | `pubspec.yaml:5` | Fijar la regla en el README: el versionCode se incrementa en pubspec (`1.0.0+2`, `1.0.1+3`, ...) en el mismo commit que el cambio, nunca se reutiliza ni se baja, y el `+N` es monotono aunque el `1.0.… | S |
| Media | El nombre del producto aparece con cinco grafias distintas entre pubspec, manifest, UI, landing y web | `android/app/src/main/AndroidManifest.xml:3` | DUENO: decidir el nombre canonico de la ficha de Play (maximo 30 caracteres; `Págate-IA` cabe y la tilde se renderiza bien en android:label). AGENTE: propagarlo a AndroidManifest.xml:3, app_shell.dar… | S |
| Media | web/index.html y web/manifest.json siguen siendo la plantilla por defecto de Flutter | `web/manifest.json:2` | Rellenar name/short_name/description con el nombre canonico y la descripcion real, y sustituir #0175C2 por el color de marca (`AppColors.brand` es `0xFF006B5F`, app_constants.dart:25). Actualizar tam… | S |
| Media | El arranque encadena tres fondos distintos y el tema nativo nocturno contradice la decision de «solo claro» | `android/app/src/main/res/values-night/styles.xml:4` | Borrar `android/app/src/main/res/values-night/styles.xml` (o dejarlo identico al claro), hacer que `drawable/launch_background.xml` y `drawable-v21/launch_background.xml` pinten el mismo color de fon… | S |
| Media | Sin flutter_localizations: el selector de fecha se dibuja en ingles dentro de una app 100% en espanol | `lib/features/finances/presentation/widgets/transaction_form_sheet.dart:104` | Anadir `flutter_localizations: {sdk: flutter}` a pubspec, y en `AppShell` y `BootstrapErrorApp`: `localizationsDelegates: GlobalMaterialLocalizations.delegates`, `supportedLocales: const [Locale('es'… | S |
| Media | El PDF descarga la fuente Nunito de fonts.gstatic.com en tiempo de ejecucion | `lib/core/services/pdf_report_service.dart:43` | Cargar Manrope desde el bundle: `final data = await rootBundle.load('assets/fonts/Manrope[wght].ttf'); final font = pw.Font.ttf(data);`. Al ser fuente variable puede hacer falta instanciar los pesos … | S |
| Media | «Ver términos» es un stub que muestra un SnackBar apuntando a una pantalla que no tiene términos | `lib/features/auth/presentation/pages/welcome_screen.dart:301` | DUENO: redactar y publicar Terminos y Politica de privacidad (pueden colgar de la landing en GitHub Pages) y poner la URL de la politica en Play Console -> Politica de privacidad. AGENTE: sustituir e… | M |
| Baja | El applicationId com.pagate.apppagate es irreversible tras la primera publicacion | `android/app/build.gradle.kts:25` | DUENO: decidir AHORA, antes de la primera subida, si se queda `com.pagate.apppagate` o se cambia a algo como `com.pagate.app` o `cl.pagate.app`. Si se cambia, hay que hacerlo en bloque: build.gradle.… | S |
| Baja | Se va a publicar en produccion con Flutter/Dart del canal beta congelado hace 8 meses | `pubspec.yaml:8` | DUENO/AGENTE: comprobar si algo obliga hoy al canal beta (no se encontro ninguna API en `lib/` que lo exija; la restriccion parece heredada). Si no, mover pubspec.yaml:8 a la restriccion stable corre… | M |
| Baja | Tamano del artefacto: una sola libreria nativa, tres ABIs, y compatibilidad con paginas de 16 KB ya verificada | `android/app/build.gradle.kts:24` | Ninguna accion obligatoria. Medir el tamano real con `flutter build appbundle --release --analyze-size` tras la primera build y, si interesa recortar, evaluar `--target-platform android-arm64` (deja … | S |
| Baja | El keystore solo esta ignorado dentro de android/; en la raiz del repo no | `.gitignore:52` | Anadir al `.gitignore` de la raiz: `*.jks`, `*.keystore`, `key.properties`, `*.aab`, `*.apk`, y `/release/`. Es mas barato ponerlo antes de generar la keystore que descubrirlo en un `git add .`. | S |

### Políticas, privacidad y datos de Google Play

| Sev | Hallazgo | Ubicación | Corrección | Esf |
| --- | --- | --- | --- | --- |
| Media | El onboarding afirma que la app sirve para 'recibir pagos globalmente', lo que es falso y la reclasificaría c… | `lib/features/onboarding/presentation/pages/identity_step_screen.dart:111` | Sustituir por lo que la app hace de verdad, por ejemplo 'Configura tu perfil para calcular tu valor hora y ordenar los números de tu negocio.' Revisar que ninguna otra cadena insinúe pagos, cobros o … | S |
| Media | 'Sugerencia del día' con una cifra inventada presentada como salida de la IA | `lib/features/dashboard/presentation/pages/ayuda_screen.dart:100` | Eliminar la tarjeta, o calcularla de verdad a partir de `users/{uid}/fixedExpenses` y `months/{monthKey}` y formatearla con la moneda del perfil, mostrándola solo cuando haya datos suficientes. | S |
| Media | El formulario de lista de espera recoge nombre y correo sin aviso de privacidad, sin consentimiento y sin for… | `landing/src/components/WaitlistForm.tsx:24` | Añadir al formulario un enlace visible a la política de privacidad y una frase de consentimiento explícita ('Al registrarte aceptas recibir un aviso por correo cuando la app esté disponible'); inclui… | S |
| Media | Se anuncia un plan Pro de pago que no existe: cuando se active obligará a usar la facturación de Google Play | `lib/core/services/ai_service.dart:89` | Ahora: quitar 'o pasa a Pro' de `ai_service.dart:89` y 'Chat en vivo (Pro)' de `ayuda_screen.dart:244`; dejar el distintivo PRO de `perfil_tab.dart:63` solo si el backend puede concederlo manualmente… | S |
| Media | Superlativos no verificables y tarjetas con métricas ficticias en la pantalla de bienvenida | `lib/features/auth/presentation/pages/welcome_screen.dart:202` | Cambiar el subtítulo por una descripción de lo que la app hace ('Calcula tu valor hora, ordena tus ingresos y gastos y controla tu inventario'); eliminar las dos tarjetas flotantes, que además chocan… | S |
| Media | La app se presenta como incompleta: etiqueta 'MVP' visible y funciones rotuladas 'Próximamente' | `lib/features/user_profile/presentation/pages/perfil_tab.dart:196` | Quitar '• MVP' del pie; eliminar la sección Notificaciones completa de Configuración en vez de dejar dos filas muertas; eliminar el botón de Apple mientras no esté implementado (o implementarlo). Tod… | S |
| Media | El registro pide país y moneda y los descarta: datos recogidos sin finalidad y ajuste que el usuario cree hab… | `lib/features/onboarding/presentation/pages/identity_step_screen.dart:179` | Quitar los dos selectores del paso de registro (la moneda ya se pide en el onboarding real) o persistirlos de verdad. Si el país nunca se va a usar, no pedirlo: cada campo recogido es un campo más qu… | S |
| Media | La landing anuncia funciones 'En desarrollo' al 60% que no tienen una línea de código, y una suscripción canc… | `landing/src/components/Roadmap.tsx:22` | Cambiar los estados a 'Idea' / 'Previsto' sin porcentajes, o eliminar la sección Roadmap; borrar 'Cancela cuando quieras'; alinear el copy del héroe con lo que el botón hace de verdad ('Únete a la li… | S |
| Baja | Los informes en PDF descargan tipografías de Google en tiempo de ejecución: tercero no declarado y función qu… | `lib/core/services/pdf_report_service.dart:43` | Cargar la fuente local con `pw.Font.ttf(await rootBundle.load('assets/fonts/Manrope[wght].ttf'))` y eliminar `PdfGoogleFonts`. Si por algún motivo se conserva, mencionar la descarga de fuentes en la … | S |
| Baja | Tres nombres distintos para el mismo producto entre la app, el Android y la landing | `android/app/src/main/AndroidManifest.xml:3` | Elegir una forma canónica (recomiendo 'Págate-IA', que es la del producto) y aplicarla en `android:label`, en la ficha de Play, en el `<title>` y la marca de la landing, y en `web/index.html` / `web/… | S |

### Tests, CI y red de seguridad

| Sev | Hallazgo | Ubicación | Corrección | Esf |
| --- | --- | --- | --- | --- |
| Media | Cinco funciones exportadas de `functions/src` no tienen ningun test, incluida la que calcula todas las cifras… | `functions/src/months.ts:13` | Tres archivos nuevos en functions/test/: (1) months.test.ts contra el emulador ya cableado (sembrar transacciones, invocar `recalcMonth`, comprobar totales, cambio de monthKey y mes que queda en cero… | M |
| Media | Nada fija la version de Flutter: cada run de CI y cada deploy usan el beta del dia | `.github/workflows/ci.yml:19` | Fijar `flutter-version: 3.42.0-0.0.pre` (la version con la que la auditoria previa verifico el repo) en ambos workflows, o pasar a `stable` si Dart 3.12 ya llego (T3-07 en PLAN.md:132). | S |
| Media | `landing-pages.yml` solo dispara en `main`, y todo el trabajo vive en `arquitectura-segura` | `.github/workflows/landing-pages.yml:9` | Documentar explicitamente que landing-page/ solo se regenera tras el merge a main, y restringir el `workflow_dispatch` a main (comprobar `github.ref_name == 'main'` en un `if:` del job) para que no s… | S |
| Media | `landing-pages.yml` corre `npm ci` con un token de escritura al repo; los otros dos workflows no declaran `pe… | `.github/workflows/landing-pages.yml:15` | Anadir `permissions: contents: read` a nivel de workflow en ci.yml y deploy-web.yml. En landing-pages.yml, separar en dos jobs: uno que instale y construya con `contents: read` y suba `dist/` como ar… | M |
| Media | Ninguna action esta fijada a SHA, incluida la que recibe la service account de Firebase | `.github/workflows/deploy-web.yml:50` | Pinear todas las actions a SHA completo con un comentario del tag, y anadir dependabot.yml con ecosistema `github-actions` para que las subidas de version lleguen como PR revisable (S1-12 en PLAN.md:… | S |
| Media | Los tests de functions nunca pasan por el typechecker, y arreglarlo cuesta cero hoy | `functions/tsconfig.json:17` | Anadir `functions/tsconfig.test.json` que extienda el principal con `"include": ["src", "test"]` y `"noEmit": true`, y un script `typecheck` que lo ejecute; llamarlo desde ci.yml entre `npm run lint`… | S |
| Media | eslint de functions no es type-aware: falta `no-floating-promises` en un backend que escribe en Firestore | `functions/eslint.config.mjs:7` | Cambiar a `tseslint.configs.recommendedTypeChecked` con `languageOptions.parserOptions.projectService: true`, apoyandose en el tsconfig.test.json del hallazgo anterior. | S |
| Media | No hay hooks de pre-commit ni ninguna verificacion local obligatoria | `AGENTS.md:92` | Crear `.githooks/pre-commit` que ejecute `dart format --output=none --set-exit-if-changed` sobre los archivos .dart staged y `flutter analyze --no-pub` (rapido, sin tests), documentar `git config cor… | S |
| Media | Medicion real de los lints que faltan: solo `discarded_futures` tiene volumen; el resto se puede activar grat… | `analysis_options.yaml:12` | Activar ya el grupo de cero coste, sobre todo `cancel_subscriptions` y `close_sinks` (blindan los 5 providers que el rediseno va a tocar) y `avoid_dynamic_calls`; anadir `strict-casts: true` y `stric… | S |
| Media | El test de WelcomeScreen se rompera por el motivo equivocado y su argumento de tema es inerte | `test/features/auth/welcome_screen_test.dart:17` | Reescribirlo por estructura: `find.byType(PagatePrimaryButton)`, `find.byType(PagateSocialButton)` y `tester.takeException() == null` a varios tamanos. Y cuando se elimine el tema oscuro (decision 2)… | S |
| Media | `firebase_options_test.dart` se pondra rojo justo cuando el dueno arregle el problema | `test/features/auth/firebase_options_test.dart:39` | Sustituirlo por la invariante real, que es la que importa en produccion: que `bootstrapFirebase()` lanza un `StateError` con mensaje claro cuando se corre en web sin configurar (firebase_bootstrap.da… | S |
| Media | Los modelos de serializacion no tienen ningun test y uno de ellos casteaba sin null-check | `lib/features/hourly_value/data/models/hourly_rate_model.dart:12` | Un archivo `test/features/*/data/models/*_test.dart` por modelo, con tres casos cada uno: documento completo, documento con campos ausentes y documento con tipos incorrectos. Son puros (Timestamp fun… | S |
| Media | Nada verifica el corte responsive de 720 px del dashboard, que hoy pierde el estado de las pestanas | `lib/features/dashboard/presentation/pages/dashboard_screen.dart:195` | Widget test que pumpee DashboardScreen con providers falsos, escriba en un campo, cambie `tester.view.physicalSize` de 400 a 900 y de vuelta, y compruebe que el texto sigue ahi. Cubre la regresion y … | S |
| Media | El formulario que capta los leads de la landing no tiene test porque vitest corre en `node` | `landing/vite.config.ts:12` | Cambiar a `environment: 'jsdom'` (o usar `// @vitest-environment jsdom` por archivo) y anadir un test de WaitlistForm: rellenar, enviar, mockear saveWaitlistEntry, y comprobar el mensaje de exito y e… | S |
| Baja | El arranque (`bootstrapFirebase`) no tiene ningun test pese a ser el unico punto que puede dejar la app en ne… | `lib/core/config/firebase_bootstrap.dart:21` | Test unitario de la rama web con `debugDefaultTargetPlatformOverride`/`kIsWeb` no es posible directamente, pero si se puede extraer la decision a una funcion pura (`String? bootstrapBlockerReason({re… | M |
| Baja | La pantalla de error de arranque queda huerfana al eliminar el tema oscuro y sus tests no lo detectan | `lib/features/auth/presentation/widgets/bootstrap_error_app.dart:27` | Al eliminar el tema oscuro, anadir en los tests de BootstrapErrorApp y SessionErrorView una asercion de contraste minima: leer `Theme.of(context).scaffoldBackgroundColor` y el `color` del `TextStyle`… | S |
| Baja | Golden tests: no tienen sentido para blindar el rediseno en este proyecto, y hay tres razones concretas | `test/widget_test.dart:1` | No hacer goldens de pantalla completa. En su lugar: (a) tests estructurales de humo con `tester.takeException()` a tres anchos, que es lo que realmente atrapa los overflows del rediseno; (b) como muc… | M |
| Baja | `test:unit` apunta a un archivo fijo y `npm test` levanta el emulador incluso para tests puros | `functions/package.json:18` | `"test:unit": "vitest run --exclude test/rules.test.ts"` y `"test:rules": "firebase-tools emulators:exec --only firestore --project demo-pagate 'vitest run test/rules.test.ts'"`, con `"test": "npm ru… | S |
| Baja | `build_runner` y `json_serializable` estan en dev_dependencies sin usarse | `pubspec.yaml:31` | Quitar `build_runner` y `json_serializable` (los modelos usan serializacion manual a proposito, segun finances_transaction_model.dart:5-8) y anadir `mocktail` y `fake_cloud_firestore` a dev_dependenc… | S |

---

## 4. Resumen por dimensión

Lo que concluyó cada auditor, en sus términos.

### Estado de la auditoría anterior

Verifiqué uno por uno los hallazgos de las secciones 2.1 a 2.7 de docs/AUDITORIA-2026-09.md contra el código actual de la rama arquitectura-segura (HEAD 9b56b27). De los ~48 hallazgos originales, 8 están cerrados, el resto sigue abierto (48 hallazgos reportados arriba incluyen 3 problemas nuevos que introdujeron los propios arreglos), y detecté 1 falso positivo parcial y 2 imprecisiones de redacción.

(a) CORREGIDOS, por commit.
- eb92269 (F0-03) cierra el crítico 2.1 #2: main.dart:19-27 envuelve bootstrapFirebase() en try/catch y monta BootstrapErrorApp con botón de reintento. Hay test (test/features/auth/bootstrap_error_app_test.dart).
- c995c32 (F0-02) cierra la mitad Android del crítico 2.1 #1: firebase_options.dart:35-41 ya tiene la apiKey y el appId reales (coinciden con android/app/google-services.json) y currentPlatform lanza UnsupportedError en iOS/macOS/Windows/Linux/Fuchsia (líneas 19-28) en vez de devolver Android para todo lo no-web. La configuración web sigue en placeholders.
- 153f84f (F0-05) cierra el alto 2.1 sobre maxInstances y cors: chat.ts:143-145 (maxInstances 5 + cors), months.ts:50 (maxInstances 10), waitlist.ts:105 (maxInstances 2). Crea functions/.env y functions/.env.example, pero con ENFORCE_APP_CHECK=false, así que NO cierra el crítico de App Check.
- 9dee885 (F0-06) cierra el alto 2.6: landing-page/assets/index-H2tCG13A.js contiene la URL real de la función waitlist y ya no hay localStorage ni console.log del email; existe .github/workflows/landing-pages.yml (cierra también el medio 2.2 "no hay workflow que publique landing-page/"); y WaitlistForm.tsx:13-14 más required en los dos inputs (67, 76) cierran el medio 2.6 de "nombre opcional en cliente, obligatorio en servidor".
- c926f63 (F0-06) cierra el bajo 2.6: README.md:94 ya dice com.pagate.apppagate.
- Parcial sin commitear: android/app/build.gradle.kts:28 tiene minSdk = flutter.minSdkVersion en el working tree (git diff pendiente), lo que resuelve la mitad "minSdk 21" del alto 2.1. La mitad del keystore sigue abierta.

(b) FALSO POSITIVO / IMPRECISIONES.
- Falso positivo parcial, 2.5-B "índice compuesto sin uso": de los tres índices de firestore.indexes.json, dos SÍ se usan. El (type, monthKey) y el (type, monthKey, amount) los consume months.ts:17-27, que filtra por type y monthKey y agrega AggregateField.sum('amount') y count. El único realmente sin uso es el primero, (monthKey ASC, date DESC) en firestore.indexes.json:3-10: ninguna consulta lo necesita — el cliente solo hace where('monthKey') suelto (finances_firebase_datasource.dart:45), orderBy(documentId) (:61), orderBy('name') (:73) y where('type') (inventory_firebase_datasource.dart:25), y el backend hace orderBy('date') suelto (chat.ts:215).
- Imprecisión en 2.3-B: openrouter.ts:77 sí está dentro de un try (el try/finally que abre en la línea 46), no "fuera del try". El problema real es que está fuera del try interno (48-70) que traduce los fallos a OpenRouterError, así que un cuerpo no-JSON sale como SyntaxError cruda.
- Imprecisión en 2.5-A: el caso "negativos como $-5000" no ocurre en finanzas_tab.dart:15-24, cuyo _money sí antepone el signo correctamente ("-$5.000"). Se reproduce en home_tab.dart:196 y :590 y en financial_charts.dart, que usan el _fmt de tipo "12.3K".
- No verifiqué el conteo de "~50 magic numbers" ni el inventario completo de tokens sin uso de 2.5-B; sí verifiqué por grep cada símbolo de código muerto que la auditoría nombraba, y los seis están efectivamente sin uso.

(c) PROBLEMAS NUEVOS QUE INTRODUJERON LOS ARREGLOS (los tres últimos hallazgos de la lista).
- c995c32 dejó en test/features/auth/firebase_options_test.dart:39-41 una aserción que fija webIsConfigured == false. El día que el dueño complete F0-01 (que es precisamente lo que desbloquea el deploy) ese test falla y rompe ci.yml:27.
- eb92269 pinta la excepción cruda al usuario final en bootstrap_error_app.dart:79 (hoy filtraría rutas internas y el id de tarea "F0-01") y construye esa pantalla con AppTheme.darkTheme (línea 27), en contra de la decisión de tema único claro.
- 153f84f metió un regex de localhost en la allowlist de cors de chat (chat.ts:145) que aplica también en producción, el mismo patrón que la auditoría ya criticaba en waitlist.ts:11.

LO QUE BLOQUEA LA PUBLICACIÓN EN GOOGLE PLAY (3 hallazgos marcados como bloqueantes): el release sigue firmado con el keystore de debug (android/app/build.gradle.kts:38) — Play rechaza el AAB; App Check sigue desactivado (functions/.env:2 + chat.ts:152), lo que deja el endpoint de chat abierto a cualquier cuenta autoregistrada con gasto real de OpenRouter; y la clave antigua de OpenRouter sigue sin revocar (README.md:91). Muy cerca de bloquear, aunque no lo marqué como tal: el borrado de cuenta (firestore.rules:98 permite el delete pero deja todas las subcolecciones huérfanas y no existe callable deleteAccount — Play exige una ruta de borrado de cuenta y datos) y los botones de login de Apple y Google que no funcionan en Android (login_screen.dart:247-249, google_auth_service.dart:20).

Aviso operativo: tres servidores MCP configurados (fetch, figma, unityMCP) no lograron conectar en esta sesión. No afectó esta auditoría, que fue solo de lectura sobre el repositorio.

### Sistema de diseño: tokens, tema y tipografía

El sistema de diseno esta bien organizado en la forma (un fichero de tokens, un fichero de tema, un barrel de componentes) y mal orientado en el fondo: fue disenado para la estetica que el dueno acaba de prohibir. Hay tres defectos que considero criticos y son los que mejor explican por que la app "se ve asquerosa" pese a tener tokens.

1) Tipografia rota de raiz. Manrope se registra en pubspec.yaml:37-40 como variable font sin `weight:` por peso, y el binario tiene `fvar` con eje wght 200-800 y **default 200** (su name ID 1 es literalmente "Manrope ExtraLight"). En todo lib/ hay **cero** usos de `FontVariation`. Es decir: el tema pide w800 en seis estilos y los widgets sobreescriben el peso 120 veces, pero lo que muy probablemente se dibuja es ExtraLight o negrita sintetica. Hay que verificarlo en dispositivo, pero los hechos del archivo son concluyentes y la correccion es de una tarde.

2) Cero cifras tabulares en una app de dinero. Ningun estilo declara `fontFeatures`, pese a que la GSUB de Manrope **si** trae `tnum`. Los montos se apilan en columna en cinco componentes (finanzas_tab.dart:317 y :844, home_tab.dart:247 y :528, detalle_item_screen.dart:383) y bailan. Es un defecto real, no cosmetico.

3) El tema oscuro forzado (app_shell.dart:28) cuesta **251 referencias a tokens *Dark en 21 archivos**, mas 163 lineas de `darkTheme`, mas `bootstrap_error_app.dart:27`, `pagate_section_card.dart:29` y 3 tests. Los tres archivos mas cargados son finanzas_tab.dart (42), inventario_tab.dart (23) e ia_tab.dart (19). Es el trabajo mas voluminoso del rediseno y conviene hacerlo antes de tocar las 5 pantallas, no despues.

Sobre lo prohibido, inventariado uno por uno: **glassmorphism** = `glass`/`glassStrong` (app_constants.dart:77-78, 6 usos), `glass_card.dart` entero y el orbe de 400px con `BackdropFilter(blur 80)` en welcome_screen.dart:41-58 -> todo se borra. **Gradientes** = 4 presets (:86, :92, :98, :107), de los cuales 2 no se usan y `brandGradient` se usa 15 veces en 9 archivos -> se sustituye por color plano. **Sombras de marca** = `shadowBrand` (:83, sin uso), `AppShadows.brand` y `brandStrong` (6 usos), uno de ellos dentro del CTA compartido (pagate_primary_button.dart:36) -> se borran. **Radios enormes** = 51 de los 103 usos de radio son 32px (`xxlBorder`, 31) o pastilla (`pillBorder`, 20), y estan cableados en el tema: los cinco borders de input usan 32 (app_theme.dart:193-215) y los dos botones usan pastilla (:250, :276) -> escala nueva de 0/6/10/14.

La escala tipografica no sirve para densidad: `displayLarge` (48) y `displayMedium` (36) tienen cero usos, hay tres roles distintos compitiendo en 14px, el `chipTheme` usa un 13px que no existe en la escala, el body va a `height: 1.5`, y no hay ningun rol numerico. Sintoma medible: 120 `fontWeight` explicitos en pantallas sobreescribiendo el tema.

De los diez widgets de core/widgets: ninguno sirve tal cual. Se borra **PagateInfoCard** (0 usos). Se reescriben **PagatePrimaryButton** (glow + pastilla), **PagateSectionCard** (radio 32 + rama por brightness), **PagateErrorState** (fuera del barrel, todo centrado, banner rojo), **PagateChipSelector** (no usa el chipTheme, alphas cableados), **PagateStepHeader** (duplica PagateBackButton y hardcodea 4 tokens claros), **PagateTextField** y **PagateLabel** (hardcodean tokens claros). **PagateBackButton** y **PagateSocialButton** sobreviven con retoques. Fuera del barrel, `GlassCard` y `PremiumTextField` (hourly_value) se borran y se migran a los compartidos.

Faltan siete componentes que hoy estan reimplementados a mano: fila etiqueta-valor (**6 copias**: finanzas_tab:280, detalle_item:383, ayuda:259, configuracion:235, home_tab:247, perfil_tab:208), estado vacio (**4 copias**), chip de filtro (**4 patrones**), selector de mes (inline dentro de `_FinanzasHeaderState`, finanzas_tab.dart:152-192), encabezado de seccion (**2 criterios opuestos**), lista densa (hoy cada movimiento es una tarjeta de radio 24, finanzas_tab.dart:778-845) y esqueleto de carga (**0**, hay 8 spinners).

Violaciones de tokens contadas con grep: **162 en 17 archivos**, concentradas en financial_charts.dart (34) y home_tab.dart (31), que juntos son el 40%. Incluyen 14 colores hardcodeados en graficos y acciones rapidas, de los cuales 6 no existen siquiera en la paleta. Ademas 22 tokens declarados no se usan nunca, y `cardTheme`, `chipTheme`, `sliderTheme` y `bottomNavigationBarTheme` son configuracion muerta porque la app no usa esos widgets de Material, mientras que el `NavigationRail` que si usa no tiene tema y se pinta inline.

Recomendacion sobre la fuente: conservar Manrope (x-height 0.540, eje 200-800, `tnum`, OFL, 165 KB) y arreglar como se usa; es lo mas barato y cumple los requisitos duros. Su unica carencia real es que no tiene cursiva, y la app no la usa. Si aun asi se quiere una voz mas neutra, la sustituta es Inter. Pendiente legal antes de publicar: la licencia OFL no se distribuye con el .ttf y la app no tiene pantalla de licencias de terceros.

Orden sugerido para no rehacer trabajo: (1) arreglar peso variable + tnum + escala tipografica; (2) borrar glass/gradientes/sombras de marca/radios grandes y tokens muertos; (3) eliminar el tema oscuro y migrar los 251 usos; (4) construir los siete componentes que faltan; (5) recien entonces rediseñar las cinco pantallas.

### Las cinco pantallas que se rediseñan

DIMENSION: las cinco pantallas del rediseño (bienvenida, registro, onboarding, inicio, finanzas). Todo lo que sigue está verificado abriendo el archivo en el HEAD actual de `arquitectura-segura`.

VEREDICTO. Las cinco pantallas están construidas sobre la estética exacta que el dueño prohibió: círculo de 280px con degradado y sombra de 40px de blur en bienvenida, dos tarjetas flotando con métricas inventadas ("+24%" y "STOCK Optimizado"), tarjeta hero con `brandGradient` + `AppShadows.brandStrong` (glow verde) y radio de 32px en inicio, botones pastilla de radio 100 con sombra de marca en las 10 llamadas a `PagatePrimaryButton`, inputs con radio 32 sobre 56px de alto, dos emojis 👋 en titulares, y títulos en Title Case inglés ("Balance del Mes", "Acciones Rápidas", "Métricas Financieras", "Meta Mensual"). No es un problema de "pulir": es el sistema de tokens el que empuja a este resultado, así que el rediseño exige tocar `app_constants.dart` y `app_theme.dart`, no solo las cinco pantallas.

TEMA. El borrado del tema oscuro no es cosmético: `app_shell.dart:28` fuerza `ThemeMode.dark` para toda la app, pero `welcome_screen.dart:28` e `identity_step_screen.dart:81` están pintadas en claro. Como el `Navigator` vive por encima del `Theme(lightTheme)` de bienvenida, la pantalla de registro se renderiza con el tema oscuro sobre un `Scaffold` blanco: el `Divider()` de la línea 155 es blanco al 10% sobre blanco (invisible) y los hints de los tres campos son #64748B sobre relleno #3A4A6B. Hay 67 usos de tokens `*Dark` en las tres pantallas del dashboard (42 solo en finanzas). Pasar a claro-único arregla este bug de paso.

DATOS FALSOS. Cuatro focos: las dos tarjetas del hero de bienvenida (`+24%`, `Optimizado`), el punto rojo permanente de notificaciones en inicio que además abre la pantalla de Ayuda, las iniciales por defecto 'IA' del avatar (también en la entidad), y los placeholders 'Artesano' / 'Mi Negocio' que se muestran como si fueran el perfil real.

JERARQUÍA. Hoy un artesano que abre la app ve: saludo con emoji, una cifra ("$1234.6K" — formato roto), cuatro botones de colores y medio gráfico de barras. Cero movimientos. Los tres gráficos ocupan ~834px, el 49% del scroll total de la pantalla, y están arriba de la actividad real. En finanzas el primer movimiento aparece a los ~698px: la pantalla se abre sin un solo dato transaccional a la vista.

DENSIDAD. Inicio mide ~1.697px de alto contra un viewport útil de ~712px en 360x800: 2,4 pantallas, ~3 gestos de scroll para llegar al final, y ~1,7 viewports hasta el primer movimiento. Finanzas necesita ~2,1 viewports para ver 10 movimientos. En 712px bien aprovechados caben las 6 cifras del mes, los gastos fijos y 8-10 movimientos: unas 3-4 veces más información útil.

DINERO. Cuatro formateadores distintos conviviendo (`_money` en finanzas, `_fmt` tres veces en inicio, otro en los gráficos), ninguno lee `profile.currency` aunque el onboarding la persiste. Inicio muestra "$1234.6K" donde finanzas muestra "$1.234.567" para el mismo saldo, y un balance negativo sale como "$-5000". Peor: "800.000" tecleado por un chileno se guarda como 800 pesos, tanto en la meta mensual del onboarding como en los gastos fijos.

PLAY STORE. Falta política de privacidad accesible: el botón "Ver términos" muestra un snackbar que remite a configuración, donde no hay nada (grep confirma que solo existen esas 5 cadenas en todo `lib/`). El botón de Apple es un stub que responde "próximamente". Google Sign-In está oculto en Android (`isAvailable => kIsWeb`), así que en el APK el único botón social visible es el que no funciona. Y ninguna de las cinco tabs tiene SafeArea superior: el contenido se dibuja bajo la barra de estado.

CONSERVAR. `FinancesProvider` (streams, error+retry, selección de mes, meta inyectada) está sano y no hay que tocarlo. El manejo de error de `FinanzasTab.build:34-43` es correcto y es el patrón a copiar en inicio. El swipe-to-delete con confirmación, el sheet de transacción con `Form`+`validate`, el estado vacío de movimientos con CTA, los estados de carga de `_TransactionsSection`, la lógica de `_onNext`/`_onContinue` (validación, try/catch, guardas `mounted`) y toda la capa de datos de las cinco pantallas se conservan tal cual: el trabajo es de presentación.

### Las pantallas que solo se limpian

Audité las 17 pantallas/widgets de "solo limpieza" y el resultado es que no es solo limpieza: hay 3 bloqueadores duros para Google Play, 1 bug de corrupción silenciosa de datos en la acción más importante de la app, y un archivo (hourly_rate_setup_page + glass_card + premium_text_field) que es literalmente el manifiesto del diseño IA que el dueño quiere eliminar.

LO QUE MÁS DUELE: (1) transaction_form_sheet.dart:117-122 convierte "25.000" en 25.0 y lo guarda sin avisar — un chileno que registra una venta de 25 mil pesos ve registrado 25 pesos, y eso contamina meses/, gráficos, meta y el prompt de la IA. (2) login_screen.dart:246-250 muestra SIEMPRE "Continuar con Apple", que solo lanza un snackbar "próximamente"; como Google solo está disponible en web (google_auth_service.dart:20), en el APK de Play el bloque "o continúa con" queda con un único botón que no hace nada. (3) No existe eliminar cuenta ni enlaces a Términos/Privacidad en Configuración, y welcome_screen.dart:304 le dice al usuario que los busque justamente ahí: Play exige ambas cosas para apps con registro.

DISEÑO IA: el peor foco es hourly_rate_setup_page.dart, cuyo propio docstring (líneas 10-11) dice "Premium... Gradient background, glassmorphism, smooth animations": fondo en degradado decorativo (158-169), GlassCard (231) y animación fade+slide de entrada (171-174). GlassCard y PremiumTextField solo los usa esa página, así que se BORRAN los dos junto con la reescritura. Además hay 8 archivos con brandGradient decorativo (avatares, logos, chips, indicador de nav, tarjeta hero de inventario), 9 pillBorder en elementos que no son chips y 165 referencias a AppColors.*Dark, que es la deuda real de pasar a tema solo claro.

MENTIRAS Y HUMO: "$830 extra" inventado y presentado como sugerencia de IA (ayuda_screen.dart:100), FAQ que manda a configurar la meta en Finanzas cuando solo se puede en Editar Perfil (ayuda_screen.dart:25), soporte@pagate-ia.com (dominio que no existe en ningún sitio del repo salvo el prototipo HTML), "Chat en vivo (Pro)", "Calificar la App" y "Compartir" que solo muestran un snackbar, sección Notificaciones entera en "Próximamente", "v1.0.0 • MVP" hardcodeado y la promesa de "calcular el costo real de tus productos" para una funcionalidad que no existe.

BUGS DE INTERFAZ CONFIRMADOS: detalle de item sigue mostrando el stock viejo tras actualizarlo; la página de valor hora no tiene botón de volver (callejón sin salida en web); divisor colgante permanente en la tarjeta de detalle porque supplier/code nunca se llenan; la campana de notificaciones abre la pantalla de Ayuda; _fmt pinta "$-5000" y "1500.0K"; el gráfico de tendencia salta a maxY=1000 si todos los meses son negativos; y el escritorio pierde el estado de las pestañas al cruzar los 720px.

Prioridad para publicar: primero los 4 bloqueadores (monto, Apple, cuenta/legales, callejón del valor hora), luego los textos que mienten (son gratis y son lo que lee un revisor de Play), y recién después el repintado a tema claro, que conviene hacer de una sola pasada junto con el rediseño de las cinco pantallas grandes para no tocar los mismos 165 puntos dos veces.

### Accesibilidad, contraste y adaptabilidad

Auditoría de accesibilidad, contraste y adaptabilidad sobre los 79 archivos de `lib/` en la rama `arquitectura-segura`. Todo lo que sigue está verificado abriendo el archivo y, en los puntos medibles, montando las pantallas reales en tests de widget temporales con la fuente Manrope cargada y `tester.ensureSemantics()` / `tester.getSize()` (los archivos de prueba se borraron; el repo queda como estaba, solo con la modificación previa de `android/app/build.gradle.kts`).

Estado: la app **no pasaría una revisión básica de accesibilidad de Google Play**. Cinco bloqueos, todos ellos de los que el Accessibility Scanner del informe previo al lanzamiento marca de forma explícita.

1. **Etiquetas ausentes.** En todo `lib/` hay cero `Semantics`, `semanticLabel`, `ExcludeSemantics` y `MergeSemantics`, y solo 3 `tooltip:`. El botón de volver (usado en 4 pantallas) expone `SemanticsNode(actions:[tap])` sin nombre ni rol; la campana de Inicio expone `isButton` sin label; el FAB de inventario y el botón de enviar del chat no tienen etiqueta. Además, 19 `GestureDetector` hacen de botón o pestaña sin declarar `isButton` ni `selected`: la barra de navegación completa, las pastillas de mes/categoría/moneda y las filas de menú se anuncian como texto plano.

2. **Áreas táctiles.** 11 controles por debajo de 48x48 dp, medidos: botón de volver 40x40, chips 35, chip de mes 36, pestaña CLP 40, y el botón de cerrar del banner del chat en ~16x16 por llevar `padding: EdgeInsets.zero` + `constraints: const BoxConstraints()`.

3. **Contraste.** Calculado sobre los hex reales de `app_constants.dart`: el placeholder de **todos** los inputs (`textTertiary` sobre `surfaceSecondary`) da 2.43:1; el botón primario deshabilitado 1.48:1; los bordes de tarjeta 1.10:1 (mínimo 3:1); `warning` 2.15:1, `success` 2.54:1, `accent` 2.67:1, `error` 3.76:1, `info` 3.68:1; incluso `textSecondary` sobre el fondo de app se queda en 4.39:1. En el gráfico de torta, el blanco falla sobre 9 de los 10 colores (peor caso 2.15:1).

4. **Texto escalado.** La pantalla de Inicio ya desborda con el ajuste "Grande" de Android (1,3x): `home_tab.dart:165` se pasa 13 px, 49 px a 1,5x y 94 px a 2x en 320 dp. A 2x también se rompen la fila Ingresos/Gastos, las cabeceras de los tres gráficos, el pie del login, el detalle de item y la cabecera de Ayuda. Finanzas, Perfil y Registro aguantan.

5. **Tema.** `AppShell` fuerza `ThemeMode.dark` mientras Bienvenida se pinta en claro y el Registro usa fondo blanco bajo tema oscuro: eso deja un separador a 1.10:1 (invisible), un botón de volver blanco sobre blanco y un enlace de login a 2.47:1. La eliminación del tema oscuro que ya decidió el dueño es, además de una decisión de diseño, la corrección de estos defectos.

Fuera de los bloqueos: cero `PopScope` en toda la app (el botón atrás descarta formularios llenos sin avisar, y la página de valor hora no tiene ninguna salida visible), ninguna de las 5 pestañas usa `SafeArea` (con el edge-to-edge obligatorio de Android 15 las cabeceras quedan bajo la barra de estado, y el layout de escritorio tampoco la usa), la app no declara `flutter_localizations` (TalkBack mezcla inglés y español, el selector de fecha sale en inglés), los formularios no tienen `textInputAction` ni `autofillHints` y sus etiquetas no están asociadas al campo, tres botones de guardar permiten doble envío, borrar un movimiento solo es posible deslizando, y hay 57 `fontSize` literales más varias alturas fijas que ignoran el escalado.

Nota sobre el rediseño: buena parte de lo que rompe la accesibilidad coincide con lo que la dirección visual acordada ya prohíbe — el orbe borroso y las tarjetas flotantes del hero de Bienvenida (que además el lector anuncia como "+24% de ganancia", cifra inventada), el punto rojo de notificación falso, los 10 colores arbitrarios del donut y las pastillas con radio 100. Corregir contraste y semántica y aplicar la dirección fintech densa son, en la práctica, el mismo trabajo.


### Estructura y salud del código Flutter

La arquitectura macro sigue en pie: `features/<f>/{data,domain,presentation}` se respeta en las 6 features, los 10 constructores estables de docs/ARQUITECTURA.md coinciden literalmente con el codigo, todas las lecturas son streams y los 5 providers exponen error+retry. `flutter analyze` sobre lib/ da 0 issues. El problema no esta en el esqueleto sino en la capa de presentacion: es donde vive la logica, el formato, los colores y los bugs.

Tres cosas destacan por encima del resto. (1) El tema es decorativo: hay 254 referencias a tokens `AppColors.*Dark` hardcodeadas en 21 archivos de widgets, y `darkTheme` (app_theme.dart:398-560) ni siquiera define chipTheme, dialogTheme, snackBarTheme, textButtonTheme ni sliderTheme, asi que cada pantalla se repinta a mano. Pasar a "solo claro" NO es cambiar `themeMode` en app_shell.dart:28: son 254 sustituciones mas el borrado de 163 lineas de darkTheme. Esto tambien explica el bug visible de identity_step_screen.dart (pantalla pintada en claro corriendo bajo tema oscuro: inputs azul marino sobre fondo blanco y un Divider invisible en la pantalla de registro, la primera del embudo). (2) Hay tres bugs de datos y ciclo de vida que rompen la app en uso normal: controllers dispuestos antes de que termine la animacion de salida de 3 dialogos/sheets, y un parseo de montos con 5 convenciones distintas donde ninguna entiende el formato chileno "150.000" (se guarda 150 en lugar de 150000, en silencio). (3) Para Google Play faltan dos rutas obligatorias que no existen en ninguna parte del codigo: enlace a Politica de privacidad y borrado de cuenta en la app, ademas de metricas inventadas visibles ("+24%", "$830 extra", punto rojo de notificaciones siempre encendido) y 7 controles que solo muestran un snackbar de "proximamente".

La duplicacion medida: 6 formateadores de moneda distintos mas 6 call sites crudos, 4 tablas de nombres de mes, 5 parseos de monto, 2 componentes de campo de texto paralelos, 7 colores de marca reescritos como literales en el PDF y 10 colores de torta que repiten tokens. Hay 8 simbolos muertos verificados uno a uno con grep, 21 tokens de diseno sin usar y 5 dependencias de pubspec sin un solo import (http, intl, cupertino_icons, build_runner, json_serializable) mientras falta google_sign_in para que el login con Google funcione en Android. El acoplamiento tiene un ciclo real user_profile <-> dashboard y una raiz de inyeccion (UserScope) metida dentro de features/auth que hace que auth dependa de otras 6 features.

### Backend, reglas y coste

Auditoría de solo lectura de la dimensión Backend, reglas y coste sobre C:/Users/Franco/Documents/Pagate-ia (rama arquitectura-segura), estado actual del árbol de trabajo. Revisados: functions/src/{chat,config,index,months,openrouter,prompt,waitlist}.ts, functions/test/, functions/{package.json,tsconfig.json,vitest.config.ts,eslint.config.mjs,.env,.env.example,.env.local,.secret.local}, firestore.rules, firestore.indexes.json, firebase.json, .firebaserc, scripts/{dev.sh,deploy-web.sh} y los tres workflows de .github/workflows/.

QUÉ CAMBIÓ DESDE LA AUDITORÍA DEL 2026-09-21. F0-05 está hecho de verdad: chat.ts:143 tiene maxInstances 5, chat.ts:145 tiene cors restringido, months.ts:50 tiene maxInstances 10, waitlist.ts:105 tiene maxInstances 2 y functions/.env existe. F0-06 también: landing/.env.production trae la URL real de waitlist, el build de landing-page/ ya la contiene y landing-pages.yml la publica. Dos falsos positivos de la auditoría previa que hoy NO aplican: functions/.secret.local contiene un placeholder ('sk-or-emulad...', 20 caracteres), no una clave real, y no hay ninguna clave de OpenRouter en el historial de git (git log --all -S 'sk-or-v1' no devuelve nada).

QUÉ SIGUE ABIERTO DE LAS SECCIONES 2.2, 2.3 Y 2.4. De 2.2 (CI/CD): siguen abiertos el deploy sin tests y con --force (deploy-web.yml:66), el JSON de cuenta de servicio con echo y rm que no corre si falla (deploy-web.yml:62 y :67), la ausencia de bloque permissions y de pins por SHA, deploy-web.sh sin --project ni verificación (línea 35), la ausencia de Dependabot y npm audit, y ci.yml:5 apuntando aún a arquitectura-segura. Se cerró el punto de que no había workflow de landing. De 2.3 (Functions): siguen abiertos el rate limit evadible de waitlist (waitlist.ts:44-51), el .add() sin dedupe (waitlist.ts:150), localhost:5173 en la allowlist de producción (waitlist.ts:11), el read-then-write sin transacción ni retry de months.ts:27-36 y :44-51, la inyección de prompt de prompt.ts:82-84 y :127-129, la cuota en UTC de chat.ts:42, la cuota que no se devuelve si OpenRouter falla (chat.ts:250-253), los meses vacíos que no se borran (months.ts:11 y :31) y res.json() fuera del try interno (openrouter.ts:77). De 2.4 (reglas): siguen abiertos todos y cada uno: createdAt mutable (firestore.rules:53-55 y :97), delete de users/{uid} (firestore.rules:98), lecturas sin request.query.limit (8 reglas allow read: líneas 95, 120, 144, 159, 166, 171, 175 y 181, y cero .limit() en los 6 streams de los datasources), sin tope numérico superior (firestore.rules:37-43), monthKey no validado contra date (firestore.rules:138-139), validHourlyRate sin hasAll (firestore.rules:59-65), isOwner sin excluir anónimos (firestore.rules:17-19) y los huecos de rules.test.ts.

LO QUE LA AUDITORÍA ANTERIOR NO VIO. Cinco cosas nuevas y verificadas. Primera y más grave para el objetivo de publicar: no existe absolutamente nada de borrado de cuenta —ni callable (index.ts:5-7 exporta solo tres funciones), ni opción en Configuración (configuracion_screen.dart, 297 líneas, sin ninguna entrada de cuenta), ni URL pública (la landing es una SPA sin router y Footer.tsx:22-23 tiene Términos y Privacidad con href '#')— y Google Play exige los dos caminos más la política de privacidad. Segunda: functions/.env no es solo un archivo que faltaba, es un archivo rastreado por git que fija ENFORCE_APP_CHECK=false y que sí se despliega, porque firebase.json:44-51 no lo excluye; es decir, App Check está apagado por configuración explícita versionada. Tercera: chat.ts:141 declara 256 MiB, lo que en Functions 2ª gen fuerza concurrencia 1 por instancia, así que maxInstances 5 significa exactamente cinco conversaciones simultáneas en todo el mundo: el tope de gasto que introdujo F0-05 es a la vez un tope de disponibilidad trivial de saturar. Cuarta: amplificación de coste por escritura, porque las reglas no limitan el ritmo de creación de transacciones y cada una dispara el trigger con dos agregaciones y una escritura, y además el monthKey lo elige el cliente con una regex (firestore.rules:139) que acepta meses 00 a 99, permitiendo fabricar hasta 10.000 documentos en months/. Quinta: no hay ninguna observabilidad de coste, porque openrouter.ts:33-36 ni siquiera declara el campo usage de la respuesta y en chat.ts no se registra un solo dato de consumo.

RIESGO CONCRETO CON LAS CUOTAS ACTUALES. Hoy puede llamar a chat cualquiera que tenga un token de Firebase Auth: el registro por email está abierto, no se envía verificación de correo (firebase_auth_service.dart:44-49) y chat ni siquiera exige que exista users/{uid} (chat.ts:179-180, profile puede ser undefined y planOf devuelve free). Cada cuenta tiene 30 mensajes al día (chat.ts:26) y cada llamada puede arrastrar 20 mensajes de historial (chat.ts:24 y :218) de hasta 2.000 caracteres (chat.ts:23) más 1.024 tokens de salida (openrouter.ts:61): una cuenta que agota su cuota maximizando el prompt mueve del orden de 750.000 tokens de entrada y 30.000 de salida al día, y mil cuentas —un script de media tarde— rondan los 780 millones de tokens diarios más 30.000 invocaciones y unas 120.000 escrituras en Firestore. El techo real no lo pone la cuota sino maxInstances 5 con concurrencia 1, que limita a unas 60-100 llamadas por minuto: eso acota el desastre a decenas de miles de llamadas diarias, pero al precio de que la app se caiga sola para los usuarios legítimos. Y no hay red de contención: PLAN.md:26 deja F0-04 (plan Blaze con alertas de presupuesto y clave de OpenRouter con tope de gasto) en estado todo.

VEREDICTO. Once hallazgos marcados como bloqueantes. Dos de ellos son bloqueos de revisión de Play y no de ingeniería (borrado de cuenta ausente, y el delete de firestore.rules:98 que haría falsa cualquier declaración de eliminación de datos); los otros nueve son dinero o disponibilidad el primer día. El orden que recomiendo: (1) deleteAccount con recursiveDelete + botón en Configuración + páginas estáticas de privacidad y eliminación en la landing; (2) allow delete: if false en firestore.rules:98; (3) App Check en consola y ENFORCE_APP_CHECK=true con enforceAppCheck en el onCall, más exigir perfil y correo verificado; (4) alertas de presupuesto y clave de OpenRouter con tope, y logging del usage; (5) cpu 1 con concurrency 20 en chat; (6) months.ts transaccional con retry: true y una función de reconciliación programada; (7) compensación de cuota y reintento ante fallo de OpenRouter, con modelo de respaldo; (8) waitlist con XFF del último salto y dedupe por sha256(email).

### Requisitos técnicos de Google Play

DIMENSION: requisitos tecnicos de Google Play. Todo lo de abajo esta verificado abriendo archivos, leyendo el plugin Gradle de Flutter instalado y la cache de AARs; nada es de manual.

LO QUE YA ESTA BIEN (descartado como problema): targetSdk resuelve a 36 y CUMPLE el requisito vigente — Play exige API 36 para apps nuevas y actualizaciones desde el 31-ago-2026, plazo ya vencido a dia de hoy (29-sep-2026), con extension solicitable hasta el 1-nov-2026 (support.google.com/googleplay/android-developer/answer/11926878). El entorno de build esta completo: SDK platform android-36, build-tools 36.1.0 y NDK 28.2.13676358 instalados, justo los que pide Flutter 3.42. `flutter analyze` sale limpio, asi que no hay nada de Dart que rompa el release. El requisito de paginas de 16 KB se cumple sin tocar nada: la unica .so del proyecto es libflutter.so y sus PT_LOAD estan alineados a 0x10000. MainActivity esta `exported="true"` con su LAUNCHER, que es lo correcto. El tamano no sera problema (~18-25 MB de descarga por ABI, muy por debajo de los 200 MB).

RESOLUCION EXACTA DE `flutter.*` EN FLUTTER 3.42.0-0.0.pre (leido en FlutterExtension.kt): minSdkVersion=24 (:26), compileSdkVersion=36 (:23), targetSdkVersion=36 (:34), ndkVersion=28.2.13676358 (:42). O sea, el cambio sin commitear de `minSdk 21` a `flutter.minSdkVersion` resuelve a 24, y ademas es OBLIGATORIO: DependencyVersionChecker.kt:116 fija errorMinSdkVersion=23 y :326 lanza GradleException por debajo, asi que HEAD tal cual NO compila para Android.

LOS CINCO BLOQUEOS REALES: (1) release firmado con la keystore de debug (build.gradle.kts:38); (2) el icono es byte a byte el logo de Flutter y no hay icono adaptativo; (3) no existe eliminacion de cuenta, que Play exige para apps con registro; (4) no hay URL de politica de privacidad y el boton «Ver terminos» es un stub que remite a una pantalla vacia; (5) minSdk 21 en HEAD rompe el build. Ademas, nadie ha compilado nunca un release: solo hay un APK de debug x86_64 y el CI no toca Android, de modo que R8 (que Flutter activa SOLO en release, con shrinkResources, y sin ningun proguard-rules.pro en este repo) esta sin probar.

═══ LISTA ORDENADA PARA LLEGAR A UN AAB FIRMADO Y SUBIBLE ═══

PUEDE HACER UN AGENTE (en este orden):
1. Commitear el cambio de minSdk, preferiblemente como `minSdk = 24` explicito. Sin esto no compila.
2. Anadir `<uses-permission android:name="android.permission.INTERNET"/>` al manifest principal.
3. Anadir `android:allowBackup="false"` + `res/xml/data_extraction_rules.xml`, y `android:roundIcon`.
4. Escribir el bloque `signingConfigs { create("release") {...} }` que lee `android/key.properties`, cambiar la linea 38 a `signingConfigs.getByName("release")` y hacer que el build falle si no hay keystore en vez de caer a debug.
5. Crear `android/app/proguard-rules.pro` con las reglas de Firestore/gRPC/printing.
6. Generar el icono adaptativo completo (anydpi-v26 + foreground/background/monochrome en las cinco densidades a 108 dp) a partir del master que entregue el dueno.
7. Limpiar el arranque: borrar values-night/styles.xml, unificar los dos launch_background y poner ThemeMode.light.
8. Anadir `flutter_localizations` con `supportedLocales: [Locale('es')]`.
9. Cambiar PdfGoogleFonts por Manrope desde el bundle.
10. Implementar eliminacion de cuenta (UI + callable `deleteAccount` que borre users/{uid} y el usuario de Auth) y las filas de Terminos/Privacidad en Configuracion.
11. Unificar el nombre visible en los siete sitios donde difiere y limpiar web/index.html y web/manifest.json.
12. Anadir a .gitignore de la raiz: *.jks, *.keystore, key.properties, *.aab, *.apk.
13. Anadir al CI un job que corra `flutter build appbundle --release` y suba el artifact.

SOLO PUEDE HACER EL DUENO:
A. Decidir si `com.pagate.apppagate` es definitivo. Es irreversible tras la primera subida; decidir ANTES del punto 14.
B. Decidir el nombre canonico de la ficha (<=30 caracteres) y comprobar que esta libre en Play.
C. Generar la keystore de subida con keytool, guardarla fuera del repo, respaldarla y crear `android/key.properties` con las contrasenas.
D. Entregar el master del icono a 1024x1024, el PNG de ficha 512x512, el feature graphic 1024x500 y al menos dos capturas de telefono.
E. Redactar y publicar Terminos, Politica de privacidad y la pagina web de eliminacion de datos.
F. Crear la cuenta de Google Play Developer (25 USD, una vez), superar la verificacion de identidad y — si la cuenta es personal creada tras nov-2023 — el requisito de 12 testers durante 14 dias continuos en testing cerrado antes de poder pasar a produccion.
G. Crear la app en Play Console, aceptar Play App Signing y rellenar Data Safety, publico objetivo, anuncios, contenido de IA generativa (la app tiene chat con IA) y la clasificacion de contenido.
H. Registrar en Firebase App Check la SHA-256 de la clave de firma de la APP que da Play Console (no la del upload key) y actualizar las restricciones de la API key de Android.
I. Cargar los secretos de firma en GitHub si se quiere firmar desde CI.

ORDEN DE EJECUCION: 1-5 desbloquean el primer `flutter build appbundle --release` real. Ese build es imprescindible antes de seguir, porque es lo unico que destapara los fallos de R8 (`build/app/outputs/mapping/release/missing_rules.txt`). Instalar ese AAB en un telefono fisico y ejercitar login, chat, Firestore, App Check y exportacion de PDF con el binario minificado. Solo despues tiene sentido invertir en los puntos 6-13 y en la ficha.

Fuentes del requisito de target API: https://support.google.com/googleplay/android-developer/answer/11926878 y https://developer.android.com/google/play/requirements/target-sdk

### Políticas, privacidad y datos de Google Play

DIMENSIÓN: POLÍTICAS, PRIVACIDAD Y DATOS DE GOOGLE PLAY — Págate-IA, rama arquitectura-segura, 2026-09-29.

VEREDICTO: la app NO se puede enviar hoy a Google Play. Hay 11 bloqueos, 5 de ellos de cumplimiento de políticas que no dependen de la consola sino de escribir código y textos que no existen. El orden real de trabajo es: keystore de release (sin él ni se sube el AAB) → permiso INTERNET (sin él el revisor recibe una app muerta) → política de privacidad publicada → borrado de cuenta → declaración honesta del envío a OpenRouter → salvaguardas de IA generativa → limpieza de contenido inventado.

(a) INVENTARIO DE DATOS. Lo que recoge la app, con destino exacto y capacidad de borrado hoy:
• Correo y contraseña → Firebase Auth (no Firestore). Sin verificación de correo. El usuario NO puede borrar su cuenta.
• Nombre → `users/{uid}.name` (setup_inicial_screen.dart:84-90 → user_profile_model.dart:56-63). Editable, no borrable.
• Nombre del negocio, tipo de negocio, moneda, meta mensual, iniciales del avatar → mismo documento `users/{uid}` (user_profile_model.dart:56-63). Editables, no borrables.
• Valor hora: sueldo mensual deseado + horas disponibles + valor calculado → mapa `users/{uid}.hourlyRate` (hourly_rate_model.dart:19-23). No borrable.
• Transacciones: título libre, descripción, monto, tipo, categoría, fecha → `users/{uid}/transactions/{id}` (finances_firebase_datasource.dart:89). SÍ borrables una a una (línea 107).
• Gastos fijos → `users/{uid}/fixedExpenses/{id}`. SÍ borrables (línea 122).
• Inventario: nombre, tipo, precio, stock, unidad, proveedor, código → `users/{uid}/inventory/{id}`. SÍ borrable (línea 57).
• Agregados mensuales → `users/{uid}/months/{yyyy-MM}`, escritos por el trigger. NO borrables (firestore.rules:165-168, write:false).
• Conversaciones y mensajes del chat → `users/{uid}/conversations/{id}/messages/{id}`, escritos por el backend (chat.ts:209 y :257). NO borrables por ningún camino (firestore.rules:170-178).
• Contador de cuota → `users/{uid}/meta/usage`. NO borrable.
• Lista de espera de la landing: nombre + correo + origen → `waitlist/{id}` (waitlist.ts:148-150). Inaccesible e imborrable desde cualquier cliente (firestore.rules:188-190).
Cifrado en tránsito: SÍ en todo (Firestore y callables por TLS; OpenRouter por https, openrouter.ts:38). En reposo: cifrado por defecto de Firestore. Sin SDK de analítica ni crash reporting (pubspec.yaml:10-26 verificado), así que no hay telemetría que declarar más allá de la automática de Play.
FRONTERA PERSONAL / FINANCIERO: personal = correo, nombre, nombre y tipo de negocio, mensajes del chat. FINANCIERO, que Play trata como categoría SENSIBLE = meta mensual, valor hora y sueldo objetivo, transacciones con monto, agregados mensuales, precios y valor del inventario. Todo lo financiero, además, se COMPARTE con un tercero (punto b), que es la casilla más auditada del formulario.

(b) TERCEROS. En cada mensaje al asistente sale hacia `https://openrouter.ai/api/v1/chat/completions` (openrouter.ts:49-64, con cabeceras `HTTP-Referer: https://pagate-17211.web.app` y `X-Title: Pagate-IA` que identifican la app): nombre del usuario (prompt.ts:82), nombre del negocio (:83), rubro (:84), moneda (:85), meta mensual (:86-88), plan (:89), sueldo deseado + horas + valor hora (:99-101), mes/ingresos/gastos/balance/nº movimientos (:112-116), las ÚLTIMAS 10 TRANSACCIONES con fecha, tipo, categoría, título libre y monto (:125-131, alimentadas por chat.ts:215), conteo de productos y materiales (:134-139) y los ÚLTIMOS 20 MENSAJES íntegros (chat.ts:218 y :232-239). Los títulos de transacción son texto libre y en la práctica contienen nombres de clientes: son datos de terceros. SUBPROCESADORES: OpenRouter es un enrutador, no el modelo; config.ts:15 fija por defecto `deepseek/deepseek-v4-flash`, así que el destino final es DeepSeek u otro proveedor aguas abajo, y el modelo es cambiable en caliente por parámetro. No se envía ninguna cabecera de política de datos (openrouter.ts:51-56), de modo que rige el ajuste por defecto de la cuenta, que puede permitir registro y entrenamiento. NADA de esto está documentado: las únicas menciones a OpenRouter en el repo (README.md:28,87,129; ARQUITECTURA.md:9,116-117; AGENTS.md:51) hablan del secreto, nunca del tratamiento de datos.

(c) BORRADO DE CUENTA. No existe ni el camino in-app ni la URL pública, y ambas son obligatorias. El menú del perfil termina en 'Cerrar Sesión' (perfil_tab.dart:185) y Configuración → Seguridad solo tiene 'Cambiar contraseña' (configuracion_screen.dart:125-130). Aunque se añadiera el botón, hoy rompería: firestore.rules:98 permite borrar `users/{uid}` dejando huérfanas e inaccesibles para siempre todas las subcolecciones, y firebase_auth_service.dart no expone `delete()`. Falta: callable `deleteAccount` con `recursiveDelete` + `auth().deleteUser` + borrado del registro de waitlist, denegar el delete directo en reglas, botón con confirmación y reautenticación, y una página web de solicitud de borrado cuya URL se declara en Play Console.

(d) CONTENIDO ENGAÑOSO. En la app: ayuda_screen.dart:100 (`$830 extra` como sugerencia de IA, constante); identity_step_screen.dart:111 ('para que puedas recibir pagos globalmente', rotundamente falso); welcome_screen.dart:202 ('La primera herramienta financiera...'), :154 ('+24% GANANCIA') y :167 ('STOCK Optimizado'); ayuda_screen.dart:235 (soporte@pagate-ia.com, dominio que no se posee) y :244 ('Chat en vivo (Pro)'). En la landing, Y YA PUBLICADO —verifiqué que `landing-page/assets/index-H2tCG13A.js` contiene las cadenas—: Stats.tsx:8-11 ('8.500 freelancers activos', '98% satisfacción', '$42.8k', '150M+ horas') y Testimonials.tsx:8-30 (tres testimonios firmados con nombre, profesión y 5 estrellas: María González, Carlos Martínez, Ana Silva). Más CTA.tsx:78 ('Cancela cuando quieras'), Hero.tsx:78/100 ('Ahora disponible en versión beta' + 'Crear cuenta gratis' que lleva a una lista de espera) y Roadmap.tsx:22,58,153,158 (CRM y multi-usuario 'En desarrollo' al 60% sin una línea de código). Riesgo: los testimonios fabricados y las métricas de usuarios son el caso de manual de la política de Tergiversación, y están en el sitio que el revisor abrirá al comprobar la URL de privacidad.

(e) CATEGORÍA. La app NO cae bajo la política de Servicios Financieros de Play: no presta dinero, no transmite fondos, no opera con criptomonedas ni con instrumentos de inversión. Verificado: functions/src/index.ts:5-7 solo exporta `chat`, `onTransactionWritten` y `waitlist`; no hay pasarela, saldo ni transferencia en todo lib/. Es una app de gestión y orientación, categoría Finanzas. Consecuencia práctica: no necesita licencias ni declaraciones de servicios financieros, PERO sí le aplica el trato sensible de la información financiera en Seguridad de Datos, y el cuestionario de contenido preguntará por funciones financieras. La única amenaza a esta clasificación limpia es la frase de identity_step_screen.dart:111: si un revisor la lee literalmente, activa la política de remesas y la revisión se alarga semanas pidiendo documentación que no existe. Borrarla es lo más barato de todo este informe.

(f) IA GENERATIVA. Play exige mecanismo in-app de reporte de contenido ofensivo, salvaguardas y declaración en la ficha. Falta todo el mecanismo: ia_tab.dart (471 líneas, leído entero) no tiene acción de reportar en `_MessageBubble` (:420-470) ni en ningún otro sitio, y no hay aviso de que la respuesta es generada por IA y puede equivocarse. Las únicas salvaguardas son instrucciones en el prompt (prompt.ts:157 'No inventes cifras'; prompt.ts:160 'No des asesoría legal ni tributaria específica'), que el modelo puede ignorar; chat.ts:257 guarda la respuesta sin moderación alguna. Se agrava con la inyección de prompt ya registrada (prompt.ts:82-84 y :127-129 interpolan campos del usuario sin escapar, tarea S1-08 pendiente): un título de transacción puede reescribir el system prompt y no hay filtro después.

(g) REVISOR. Para probarla de punta a punta hoy el equipo de Play no puede: el AAB ni siquiera se sube (firma debug, build.gradle.kts:38) y, si se subiera, la app no tendría red (falta INTERNET en el manifiesto main). Resueltos esos dos, el registro con correo y contraseña es abierto y sin verificación de correo, así que técnicamente un revisor puede crear su propia cuenta — pero llegaría a un dashboard vacío sin nada que evaluar. RECOMENDACIÓN: sí hace falta cuenta de demostración con datos precargados (perfil completo, valor hora calculado, 15-20 transacciones de varios meses, 8-10 ítems de inventario y una conversación de chat), con credenciales en Play Console → Acceso a la app, más una nota al revisor explicando que el asistente consume cuota diaria (30 mensajes en plan free, chat.ts:26) y que el plan Pro aún no es comprable. Añadir: que el botón 'Continuar con Apple' no funciona (welcome_screen.dart:250-253) y que en Android el único acceso es correo y contraseña, porque Google Sign-In solo está en web (google_auth_service.dart:20).

(h) OTROS. Contenido de usuario: no hay contenido público ni compartido entre usuarios; todo cuelga de `users/{uid}` con reglas de propietario, así que no aplica la política de UGC — salvo por la salida del modelo, cubierta en (f). Publicidad: ninguna, ni SDK ni identificador publicitario; se declara 'no' y no hace falta política de familias. Compras dentro de la app: hoy no existen, pero el campo `plan: free|pro` ya está en el contrato (ARQUITECTURA.md:34), el backend ya diferencia cuotas (chat.ts:26) y la UI YA lo vende (ai_service.dart:89 'pasa a Pro', ayuda_screen.dart:244, distintivo PRO en perfil_tab.dart:63) sin que exista ninguna forma de comprarlo: ninguna función escribe `plan` y las reglas se lo prohíben al cliente (firestore.rules:86-92). Cuando se active, el Pro es contenido digital consumido dentro de la app y la política de Pagos obliga a Google Play Billing con validación de recibo en el servidor; cobrarlo por fuera es causa de suspensión de la cuenta de desarrollador. Mientras tanto, lo correcto es quitar las menciones.

### Tests, CI y red de seguridad

RED DE SEGURIDAD: TODO VERDE Y CASI VACIA

Ejecutado hoy contra el HEAD de `arquitectura-segura`: `flutter analyze` = 'No issues found' (57,8 s), `flutter test` = 15/15 en verde, `tsc --noEmit` sobre los tests de functions = limpio. El problema no es que algo este roto, es que lo que esta cubierto es justo lo que no se va a romper.

(a) QUE CUBREN HOY LOS SEIS ARCHIVOS DE TEST
Flutter, 15 tests: widget_test.dart (2) prueba que `PagatePrimaryButton` muestra su etiqueta, responde al tap y que en `isLoading` muestra un spinner y no responde. bootstrap_error_app_test.dart (2) prueba que la pantalla de error de arranque muestra titulo, detalle y boton, y que el boton invoca `onRetry`. firebase_options_test.dart (3) prueba que en Android devuelve las constantes de google-services.json, que iOS/macOS/Windows/Linux lanzan `UnsupportedError`, y que `webIsConfigured` es false. welcome_screen_test.dart (1) busca dos literales de copy. finances_provider_test.dart (3) es el unico test serio del proyecto: con un `FakeFinancesRepository` comprueba que el provider expone los meses del stream y selecciona el primero, que `selectMonth` se resuscribe al monthKey correcto e ignora indices fuera de rango, y que un `permission-denied` produce mensaje de error y `retry()` vuelve a suscribirse. calculate_hourly_rate_test.dart (4) cubre el caso de uso puro, incluida la division por cero.
Functions, 31 casos: prompt.test.ts (6 `it`) sobre `buildSystemPrompt` y `formatMoney` — secciones presentes, usuario sin perfil, moneda del perfil, tope de 10 transacciones. rules.test.ts (25 `it`) contra el emulador — propiedad de `users/{uid}`, campos desconocidos, `plan` no escalable, moneda CLP/USD, amount<=0, monthKey mal formado, colecciones solo-backend (months, conversations, messages, meta/usage), waitlist inaccesible y bloqueo sin autenticacion. Es, con diferencia, la mejor parte de la suite.
Fuera de esos seis, landing tiene 6 casos sobre el fetch del waitlist y cero sobre componentes.

(b) LOS HUECOS QUE IMPORTAN PARA PUBLICAR
Cuatro fallos pueden llegar a produccion sin que absolutamente nada los detecte: (1) que el AAB de release no compile — CI nunca construye Android, solo web; (2) que el enrutado de sesion mande a un usuario con perfil de vuelta al onboarding o lo deje en el splash — `AuthGate`/`ProfileGate` no tienen tests y no se pueden escribir, porque `FirebaseAuthService` toca `FirebaseAuth.instance` en su constructor; (3) que `recalcMonth` corrompa los totales mensuales, que son todas las cifras que muestra la app, sin test alguno; (4) que una pantalla desborde en un telefono de 360 dp tras el rediseno. Las cinco pantallas a redisenar suman 2.143 lineas con una sola asercion entre todas, y esa asercion es sobre un texto que el rediseno va a cambiar.

(c) CI: ci.yml verifica de verdad (analyze, test, build web, functions con emulador, landing lint+test+build) pero no construye Android, no comprueba formato y usa el beta movil de Flutter. deploy-web.yml no ejecuta un solo test antes de desplegar reglas de Firestore y functions, y ninguno de los dos declara `permissions:`. landing-pages.yml solo dispara en `main` mientras el trabajo vive en `arquitectura-segura`, y corre `npm ci` con `contents: write`. Ninguna action esta pineada a SHA, incluida la que recibe la service account.

(d) LINTS Y FORMATO: `dart format` cambiaria 56 de 85 archivos (55 de 79 en lib/, 1 de 6 en test/) — es la deriva al estilo 'tall' de Dart 3.7+, y nada la comprueba. En lints, medido sobre una copia del arbol: `discarded_futures` 26 violaciones (la unica con volumen real y con bugs de verdad dentro), `avoid_catches_without_on_clauses` 24, `directives_ordering` 12, `use_decorated_box` 8, resto trivial. En cambio `cancel_subscriptions`, `close_sinks`, `avoid_dynamic_calls`, `require_trailing_commas`, `prefer_final_locals`, `strict-casts`, `strict-raw-types` y `deprecated_member_use: error` dan CERO violaciones: se pueden activar hoy mismo gratis, y son justo las que protegen los providers durante el rediseno.

(e) HOOKS: no existe ninguno. `.git/hooks/` vacio, `core.hooksPath` sin valor, sin `.githooks/`, husky ni lefthook. La regla de AGENTS.md:92 es una nota de documentacion.

(f) GOLDENS: no los hagas. Sin `flutter_test_config.dart` los tests renderizan con Ahem en vez de Manrope; CI es ubuntu y el desarrollo Windows, asi que nunca coincidirian; y los candidatos naturales son las pantallas que mas van a cambiar, con lo que acabarian regenerandose a ciegas en cada PR — que es exactamente cuando dejan de detectar nada.

CONJUNTO MINIMO DE TESTS NUEVOS, POR VALOR DESCENDENTE
1. Humo estructural de las cinco pantallas (test/features/**/..._smoke_test.dart, ~200 lineas). Pumpear bienvenida, registro, onboarding, inicio y finanzas con fakes a 360x640, 412x915 y 800x1280, afirmando `tester.takeException() == null` y presencia por `find.byType`, nunca por texto. ATRAPA: overflows y excepciones de build en telefonos pequenos tras el rediseno, que es la regresion numero uno de un cambio visual masivo y la queja numero uno en Play.
2. Enrutado de sesion (test/features/auth/profile_gate_test.dart). Requiere primero hacer `FirebaseAuthService` construible sin Firebase, copiando el patron perezoso que ya usa google_auth_service.dart:15-17. Cuatro casos: isLoading -> Splash, error con profile null -> SessionErrorView, profile null -> SetupInicial, profile presente -> Dashboard. ATRAPA: que un usuario ya registrado vuelva al onboarding o se quede en el splash para siempre.
3. functions/test/months.test.ts contra el emulador ya cableado. Sembrar transacciones, invocar `recalcMonth`, verificar totales, el caso de cambio de monthKey (recalculo de ambos meses) y el mes que queda a cero. ATRAPA: corrupcion silenciosa de todas las cifras de todos los usuarios.
4. Serializacion de los cinco modelos (~100 lineas, puros). Documento completo, con campos ausentes y con tipos incorrectos. ATRAPA: el `as num` sin null-check de hourly_rate_model.dart:12 que convierte el stream en error permanente, y el `fromSnapshot` que devuelve null y reenvia al onboarding.
5. functions/test/waitlist.test.ts puro sobre `validateWaitlistBody` e `isRateLimited`. ATRAPA: perder todos los leads de la landing, o un rate limiter que bloquea a todos.
6. Humo del dashboard a dos anchos, cruzando 720 px. ATRAPA: la perdida de estado entre `_pages[_currentIndex]` (linea 195) e `IndexedStack` (linea 208).
7. `dayKeyOf` de chat.ts en la frontera de medianoche. ATRAPA: la cuota diaria reiniciandose a las 21:00 hora de Chile y bloqueando al usuario a media tarde.
8. Test de WaitlistForm con jsdom, que ya esta instalado sin usarse.
Y tres puertas en CI que valen mas que muchos tests: `dart format --set-exit-if-changed`, `flutter build appbundle --release`, y `needs:` de los jobs de test en el workflow de deploy.

---

## 5. Descartados al refutar

La fase de refutación adversarial tumbó estos hallazgos:

- **El AAB de release se construye sin permiso INTERNET: el revisor recibirá una app que no conecta con nada**
  - La premisa central es falsa y el auditor leyó el archivo equivocado. Es cierto que android/app/src/main/AndroidManifest.xml no declara INTERNET y que sí está en debug/AndroidManifest.xml:6 y profile/AndroidManifest.xml:6. Pero la afirmación 'ninguna dependencia lo aporta' se cae con el informe de blame del merger, build/app/outputs/logs/manifest-merger-debug-report.txt:182-188:   uses-permission#android.permission.INTERNET   ADDED from ...\src\debug\AndroidManifest.xml:6:5-66   MERGED from [com.google.firebase:firebase-auth:23.2.1] ...\AndroidManifest.xml:25:5-67   MERGED from [com.google.firebase:firebase-firestore:25.1.4] ...\AndroidManifest.xml:11:5-67   MERGED from [com.google.firebase:firebase-functions:21.2.1] ...\AndroidManifest.xml:9:5-67 Abrí los tres AAR transformados en ~/.gradle/caches/8.14/transforms/ y cada uno declara literalmente `<uses-permission android:name="android.p…
- **`AuthGate`, `UserScope` y `ProfileGate` son intesteables porque `FirebaseAuthService` toca `FirebaseAuth.instance` en su constructor**
  - El gancho de inyección YA existe y funciona. `lib/core/services/firebase_auth_service.dart:16-17`: `FirebaseAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance {`. En Dart `??` solo evalúa el operando derecho cuando el izquierdo es null, así que `FirebaseAuthService(auth: FakeAuth())` nunca toca `FirebaseAuth.instance`. Y `grep -n 'FirebaseAuth.instance' lib/core/services/firebase_auth_service.dart` devuelve UNA sola línea en las 70 del archivo: la 17. Lo que el constructor ejecuta después (`_user = _auth.currentUser` en `:18`, `_auth.userChanges().listen(...)` en `:19`) va contra la instancia inyectada. Tampoco hace falta mocktail/firebase_auth_mocks: en `firebase_auth-5.7.0/lib/src/firebase_auth.dart:9` la declaración es `class FirebaseAuth extends FirebasePluginPlatform {`, sin `final`/`base`/`sealed`, así que `class FakeAuth implements FirebaseAuth` con `noSuch…
