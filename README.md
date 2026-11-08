# Págate-IA

[Landing page](https://francogalaz.github.io/Pagate-ia/landing-page/) · [Privacidad](https://francogalaz.github.io/Pagate-ia/landing-page/privacidad/) · [Términos](https://francogalaz.github.io/Pagate-ia/landing-page/terminos/) · [Eliminar cuenta](https://francogalaz.github.io/Pagate-ia/landing-page/eliminar-cuenta/)

Asistente financiero con IA para artesanos y creadores independientes. App Flutter + Firebase.

AI-powered financial assistant for artisans and independent makers. Flutter + Firebase app.

---

## Español

Págate-IA ayuda a quien vive de lo que hace con sus manos (cerámica, textil, joyería, madera, repostería, etc.) a saber cuánto vale su hora, cuánto cobrar por cada pieza, llevar el inventario de materiales y productos, y registrar ingresos y gastos. Una IA responde preguntas concretas sobre el negocio usando esos datos.

### Estado actual

Auditoría técnica y plan de trabajo por fases: [`docs/AUDITORIA-2026-09.md`](docs/AUDITORIA-2026-09.md) y [`docs/PLAN.md`](docs/PLAN.md).

MVP funcional. Flujo completo: registro → configuración del taller → dashboard con finanzas, inventario y chat con IA. El valor hora es opcional y se configura desde Inicio. Todavía no es un producto terminado.

### Arquitectura

El contrato completo (modelo de datos, API del backend, convenciones del cliente) está en [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md). Resumen:

- **Cliente:** Flutter (Dart, canal beta), estado con `provider`, estructura `features/<feature>/{data,domain,presentation}`. Lee Firestore con streams (`snapshots()`); los providers exponen `error` y `retry()`.
- **Datos:** todo cuelga de `users/{uid}` (perfil, `inventory`, `transactions`, `fixedExpenses`, `months`, `conversations/{id}/messages`, `meta/usage`). Una sola regla de propiedad cubre el árbol. `months/*`, `conversations/*` y `meta/usage` los escribe **solo el backend**. `waitlist/*` no es accesible desde el cliente.
- **Backend:** Cloud Functions 2ª gen (TypeScript, Node 22, región `southamerica-west1`):
  - `chat` (callable): valida auth y cuota (`free` 25 mensajes de por vida / `pro` 300 al día), arma el prompt en el servidor con el contexto del usuario, llama a OpenRouter con el secreto `OPENROUTER_API_KEY` y persiste la conversación.
  - `onTransactionWritten` (trigger Firestore): recalcula `users/{uid}/months/{yyyy-MM}` con consultas agregadas. Idempotente.
  - `waitlist` (HTTP): recibe `{name, email, source}` desde la landing y escribe en `waitlist/{id}`. CORS limitado a los dominios de la landing y límite por IP.
- **Seguridad:** ningún secreto viaja en el cliente. App Check (Play Integrity en Android, reCAPTCHA v3 en web) se activa con `--dart-define=APP_CHECK_SITE_KEY=...` y se exige en el backend con el parámetro `ENFORCE_APP_CHECK=true`.

### Correr en local

Requisitos: Flutter beta (`.metadata` → `channel: beta`), Node 22, Java 21 (para el emulador de Firestore).

```bash
# 1. Dependencias
flutter pub get
npm --prefix functions ci

# 2. Emuladores (Auth 9099, Firestore 8080, Functions 5001, UI 4000)
./scripts/dev.sh          # equivale a: npm --prefix functions exec -- firebase emulators:start

# 3. App apuntando a los emuladores (en otra terminal)
flutter run --dart-define=PAGATE_ENV=dev
```

Sin `PAGATE_ENV=dev` la app usa el proyecto real (`prod`). En el emulador de Android los emuladores se resuelven en `10.0.2.2`.

Para el chat en local hay que definir el secreto también en el emulador: crea `functions/.secret.local` con `OPENROUTER_API_KEY=sk-or-...` (está ignorado por git).

Copia también `functions/.env.local.example` a `functions/.env.local` (ignorado por git). El emulador carga ese archivo por encima de `functions/.env` y deja `ENFORCE_APP_CHECK=false`, así que en local los callables siguen funcionando cuando producción exija App Check:

```bash
cp functions/.env.local.example functions/.env.local
```

### Verificar

```bash
flutter analyze
flutter test
npm --prefix functions run build && npm --prefix functions test   # levanta el emulador de Firestore
npm --prefix landing run lint && npm --prefix landing test && npm --prefix landing run build
```

CI (`.github/workflows/ci.yml`) ejecuta exactamente esos tres bloques en paralelo en cada push y pull request.

### Desplegar

Manual, desde una máquina con sesión iniciada (`npm --prefix functions exec -- firebase login`):

```bash
APP_CHECK_SITE_KEY=6Lc... ./scripts/deploy-web.sh   # hosting + reglas de Firestore + functions
```

Automático: el workflow `.github/workflows/deploy-web.yml` corre con `workflow_dispatch` o al crear un tag `v*`. Secretos que hay que crear en GitHub (Settings → Secrets and variables → Actions):

| Secreto | Contenido |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT` | JSON completo de una cuenta de servicio del proyecto `pagate-17211` con roles *Firebase Hosting Admin*, *Cloud Functions Admin*, *Firebase Rules Admin*, *Service Account User*, *Cloud Run Admin* y *Artifact Registry Administrator* (o simplemente *Editor* para empezar). `firebase init hosting:github` la genera con permisos de hosting; hay que ampliarlos para functions. |
| `APP_CHECK_SITE_KEY` | Site key de reCAPTCHA v3 registrada en App Check para la app web. Si no existe, el build sigue pero App Check queda desactivado en web. |

**Landing (GitHub Pages).** Es un sitio **multipágina**: además de la portada (`index.html`) publica
`/privacidad/`, `/terminos/` y `/eliminar-cuenta/`, cada una con su propio punto de entrada declarado en
`landing/vite.config.ts`. Esas tres URLs son obligatorias para Google Play y van declaradas en la ficha, así
que no se pueden mover sin actualizar Play Console. Los datos del responsable (razón social, RUT, domicilio y
correos) viven en `landing/src/content/legal-meta.ts` **con marcadores entre corchetes sin rellenar**, aunque
las páginas ya **no los muestran**: eligen otra redacción cuando el dato falta, y el botón `mailto:` de la
página de eliminación de cuenta no se renderiza mientras no haya buzón. El inventario de lo que hay que
rellenar, con línea y constante, está en **`docs/FICHA-PLAY.md` §8**.

`landing-page/` lo regenera el workflow `.github/workflows/landing-pages.yml` en cada push a `main` que toque `landing/` (lint + test + build y commit automático de `landing-page/`). La URL de la función `waitlist` viene de `landing/.env.production` (o de la variable de repositorio `VITE_WAITLIST_URL`). **Como el workflow solo dispara en `main` y el trabajo vive en ramas, hay que regenerarlo a mano con los mismos pasos que hace el workflow:**

```bash
npm --prefix landing run lint && npm --prefix landing test && npm --prefix landing run build
rm -rf landing-page && mkdir landing-page && cp -r landing/dist/. landing-page/
```

**No editar nunca un archivo de `landing-page/` a mano.** Si el sitio público y `landing/src/` dejan de coincidir, lo que la gente lee es el build viejo: eso ya ocurrió, y el sitio publicado siguió mostrando métricas y testimonios inventados semanas después de haberlos borrado del código.

### Checklist de configuración en consola (solo el dueño del proyecto)

Estas tareas requieren acceso a la consola de Firebase / Google Cloud y no puede hacerlas un agente:

1. **App web en Firebase.** Consola → Project settings → *Add app* → Web. Copiar la configuración generada en `lib/firebase_options.dart` (`web` y, si aplica, `android`). Habilitar Google como proveedor en Authentication → Sign-in method.
2. **Plan Blaze.** Cloud Functions 2ª gen y los secretos requieren facturación. Activar el plan y crear **alertas de presupuesto** en Google Cloud → Billing → Budgets (p. ej. USD 5 y USD 20).
3. **Secreto de OpenRouter.** Crear una clave nueva en OpenRouter y guardarla con:
   ```bash
   npm --prefix functions exec -- firebase functions:secrets:set OPENROUTER_API_KEY
   ```
   **Rotar (revocar) la clave antigua** que se compiló en versiones anteriores del cliente con `--dart-define=OPENROUTER_API_KEY`: cualquier build anterior la expone.
4. **App Check.** Consola → App Check → registrar la app Android con *Play Integrity* (subir SHA-256 del keystore de release) y la app web con *reCAPTCHA v3* (crear la clave en Google Cloud → reCAPTCHA, dominio `pagate-17211.web.app`). Guardar la site key como secreto `APP_CHECK_SITE_KEY` (GitHub) y usarla en `scripts/deploy-web.sh`. Cuando ambas apps reporten tokens válidos en el panel de App Check, cambiar el parámetro de Functions `ENFORCE_APP_CHECK` a `true` (archivo `functions/.env` o en el deploy) y volver a desplegar.
5. **Restringir las API keys** en Google Cloud → APIs & Services → Credentials:
   - Clave Android: restricción por aplicación Android (paquete `com.pagate.apppagate`, el `applicationId` de `android/app/build.gradle.kts`) + SHA-1 de debug y release.
   - Clave web: restricción por *HTTP referrer* (`https://pagate-17211.web.app/*`, `https://pagate-17211.firebaseapp.com/*`, `http://localhost:*` para desarrollo).
   - En ambas, limitar las APIs a las que usa Firebase (Identity Toolkit, Firestore, Cloud Functions, Firebase App Check, Token Service).
6. **Cuenta de servicio para CI** (ver tabla de secretos más arriba).
7. **Dominio de la landing** en el CORS de `waitlist` (`functions/src`) si cambia de `francogalaz.github.io`.
8. **Datos del responsable para los textos legales.** Rellenar los cinco marcadores de
   `landing/src/content/legal-meta.ts` (razón social o nombre, RUT, domicilio, correo de privacidad y correo de
   soporte). Las páginas ya no muestran corchetes, pero sin estos datos la política identifica al responsable
   por descripción y no por nombre. El inventario, con número de línea, está en **`docs/FICHA-PLAY.md` §8**.
9. **Correo de soporte real.** El `soporte@pagate-ia.com` que muestra la app usa un dominio que no se controla.
   Tiene que ser el mismo correo en la app, en los textos legales y en la ficha de Play.
10. **Tipo de cuenta de desarrollador.** Si la cuenta de Play es personal y se creó después del 13 de noviembre
    de 2023, hace falta una prueba cerrada con **un mínimo de 12 probadores inscritos de forma continua durante
    al menos 14 días** antes de poder publicar en producción, y después hay que **solicitar** el acceso
    ([documentación oficial](https://support.google.com/googleplay/android-developer/answer/14151465),
    transcrita en `docs/FICHA-PLAY.md` §7). Los 14 días son de calendario y los más recientes: si en algún
    momento bajas de 12 probadores, la cuenta empieza otra vez. Comprobarlo antes de comprometer una fecha.
11. **Política de datos en la cuenta de OpenRouter.** Fijar la más restrictiva (sin registro, sin entrenamiento).
    Hasta que exista además un acuerdo de tratamiento, el envío al asistente se declara en Play como
    *compartido con terceros*; el razonamiento está en `docs/SEGURIDAD-DATOS-PLAY.md` §0.2.

### Estructura del repo

```
lib/            app Flutter (features/<feature>/{data,domain,presentation})
functions/      Cloud Functions (TypeScript)
firestore.rules reglas de seguridad
landing/        landing page (Vite + React); build publicado en landing-page/
landing-page/   build estático servido por GitHub Pages (no editar a mano; lo regenera landing-pages.yml)
docs/           ARQUITECTURA.md (contrato), auditoría, sistema visual, prototipos HTML/JSX
                SEGURIDAD-DATOS-PLAY.md  respuestas al formulario de Seguridad de los datos
                FICHA-PLAY.md            textos y recursos gráficos de la ficha
                COMPETENCIA.md           competidores reales con fuentes
                PLAN-PUBLICIDAD.md       plan de difusión sin presupuesto
scripts/        dev.sh (emuladores) y deploy-web.sh
test/           tests de Flutter
```

### Autor

Franco Galaz — estudiante de Ingeniería, Universidad Andrés Bello (Chile).

---

## English

Págate-IA helps people who make a living with their hands (ceramics, textiles, jewelry, woodwork, baking, etc.) figure out what their hour is worth, how much to charge per piece, keep track of materials and products, and log income and expenses. An AI answers concrete questions about the business using that data.

### Current status

Working MVP. Full flow: sign up → workshop setup → dashboard with finances, inventory and AI chat. The hourly rate is optional and is set up from Home. Not a finished product yet.

### Architecture

See [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md) (Spanish) for the full contract. In short: Flutter client reading Firestore through streams; every user document lives under `users/{uid}`; monthly aggregates, conversations and usage counters are written only by the backend; Cloud Functions 2nd gen (`chat`, `onTransactionWritten`, `waitlist`) in `southamerica-west1`; the OpenRouter key lives in Secret Manager; App Check enforced once `ENFORCE_APP_CHECK=true`.

### Run locally

```bash
flutter pub get && npm --prefix functions ci
./scripts/dev.sh                                  # Firebase emulators
flutter run --dart-define=PAGATE_ENV=dev          # app against the emulators
```

### Deploy

`APP_CHECK_SITE_KEY=... ./scripts/deploy-web.sh`, or run the `Deploy` GitHub workflow (needs the `FIREBASE_SERVICE_ACCOUNT` and `APP_CHECK_SITE_KEY` secrets).

### Author

Franco Galaz — Engineering student at Universidad Andrés Bello (Chile).
