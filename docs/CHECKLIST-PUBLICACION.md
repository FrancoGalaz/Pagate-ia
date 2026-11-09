# Checklist de publicación

Pasos que solo puede hacer el dueño del proyecto en las consolas, en orden de
dependencia: cada paso necesita los anteriores. Cada uno termina con
**Verificar**, que dice cómo comprobar que quedó bien. El contexto de cada punto
está en `docs/PLAN.md` y `docs/FICHA-PLAY.md`.

Los comandos `firebase` se corren desde la raíz del repo con
`npm --prefix functions exec -- firebase …`, después de `firebase login`.

## 1. Nombre del paquete

`com.pagate.apppagate` no se puede cambiar después de la primera subida a Play.
Decidir si es el definitivo antes de crear nada en las consolas que dependa de
él (app Android en Firebase, Play Console, App Check).

**Verificar:** los tres lugares dicen lo mismo.

```bash
grep -n 'applicationId' android/app/build.gradle.kts
grep -o '"package_name": "[^"]*"' android/app/google-services.json
grep -n 'ANDROID_PACKAGE' landing/src/content/legal-meta.ts
```

## 2. Firebase (proyecto `pagate-17211`)

1. **Plan Blaze** con una alerta de presupuesto. Las functions de 2.ª
   generación lo exigen.
2. **Authentication:** habilitar el proveedor Correo/contraseña. En Android es
   el único (Google solo existe en web).
3. **Plantilla del correo de verificación:** Authentication → Plantillas →
   Verificación de dirección de correo electrónico. Cambiar el idioma a
   español y revisar el remitente y el asunto. `chat` y `scanReceipt` exigen el
   correo verificado.
4. **Firestore:** crear la base `(default)` en `southamerica-west1`. La región
   no se puede cambiar después.

**Verificar:**

- Uso y facturación muestra el plan Blaze y la alerta.
- La lista de bases muestra `(default)` con `locationId: southamerica-west1`:

  ```bash
  npm --prefix functions exec -- firebase firestore:databases:list
  ```

- La plantilla del correo aparece en español en la consola. La prueba completa
  del correo va en el paso 7.

## 3. OpenRouter

1. Crear una clave nueva con límite de crédito en `openrouter.ai → Keys`.
2. Cargarla como secreto (pide el valor sin mostrarlo en pantalla):

   ```bash
   npm --prefix functions exec -- firebase functions:secrets:set OPENROUTER_API_KEY
   ```

3. **Revocar la clave antigua**, la que quedó en builds viejos.

**Verificar:**

- Este comando lista la versión del secreto sin mostrar su valor:

  ```bash
  npm --prefix functions exec -- firebase functions:secrets:get OPENROUTER_API_KEY
  ```

- En `openrouter.ai → Keys` solo queda la clave nueva.
- La prueba de que el asistente responde va en el paso 7.

## 4. Desplegar reglas y functions

`functions/.env` debe seguir con `ENFORCE_APP_CHECK=false` (ver el paso 8).

```bash
npm --prefix functions exec -- firebase deploy --only firestore,functions
```

`scripts/deploy-web.sh` también publica el hosting web, que está fuera de
alcance por ahora.

**Verificar:**

- `firebase functions:list` muestra `chat`, `scanReceipt`, `deleteAccount`,
  `deleteChatHistory`, `onTransactionWritten` y `waitlist` en
  `southamerica-west1`.
- La prueba de humo pasa las dos primeras líneas (reglas y `chat`). Las de la
  landing fallan hasta el paso 5:

  ```bash
  ./scripts/smoke-prod.sh
  ```

### Prueba de humo (`scripts/smoke-prod.sh`)

No usa credenciales: solo lee o llama sin sesión. Comprueba:

| Chequeo | Qué espera |
|---|---|
| Reglas de Firestore | Leer `users/x` sin sesión da 403 `PERMISSION_DENIED`, sin `reason`. Con la API deshabilitada Google también da 403, pero con `"reason": "SERVICE_DISABLED"`, y el script lo cuenta como falla. |
| Functions | `chat` sin sesión, en `southamerica-west1`, da 401 `UNAUTHENTICATED`. |
| Landing | `/`, `/privacidad/`, `/terminos/` y `/eliminar-cuenta/` responden 200. |
| Marcadores publicados | `/privacidad/` y los `.js` que carga no tienen marcadores como `[RUT DEL RESPONSABLE]`. La página la pinta el JS y oculta los corchetes al mostrarla, así que no basta con mirar el HTML. |
| `legal-meta.ts` | No tiene marcadores en sus valores. |

Sale con 0 si todo pasa. Para otra URL de la landing (o para probar contra los
emuladores) acepta `LANDING_URL`, `FIRESTORE_URL` y `FUNCTIONS_URL`:

```bash
LANDING_URL=https://otra-url/ ./scripts/smoke-prod.sh
```

## 5. Datos legales y landing

1. Rellenar en `landing/src/content/legal-meta.ts` los cinco valores entre
   corchetes: razón social o nombre, RUT, domicilio, correo de privacidad y
   correo de soporte. El correo de soporte debe estar atendido y ser el mismo
   que se declara en Play.
2. Publicar la landing. `.github/workflows/landing-pages.yml` la reconstruye y
   la publica en GitHub Pages cuando un cambio en `landing/` llega a `main`
   (o con `workflow_dispatch`).

**Verificar:** la prueba de humo completa da «Todo OK».

```bash
./scripts/smoke-prod.sh
```

## 6. Keystore de subida

1. Generar el keystore definitivo, fuera del repo y con respaldo. La identidad
   de la app queda atada a esa clave.
2. Copiar `android/key.properties.example` a `android/key.properties` y
   rellenar los cuatro valores. Ese archivo no se versiona.
3. Compilar: `flutter build appbundle --release`.

**Verificar:**

- `git status` no muestra `key.properties` ni el `.jks`.
- El bundle está firmado con tu clave y no con la de depuración: el `Owner` no
  dice `Android Debug`.

  ```bash
  keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
  ```

## 7. Play Console

1. Crear la app con `com.pagate.apppagate` y la firma de apps de Google Play.
2. Ficha: textos de `docs/FICHA-PLAY.md`, capturas en 9:16 y la URL de
   `/privacidad/`.
3. **Seguridad de los datos:** las respuestas están en
   `docs/SEGURIDAD-DATOS-PLAY.md`. Hay que declarar que los datos financieros
   viajan a OpenRouter.
4. Subir el bundle del paso 6 a la pista de prueba interna e instalarlo desde
   Play en un teléfono real.

**Verificar:**

- Panel → Configurar la app no tiene tareas pendientes.
- **Correo de verificación:** con el build de Play, registrar una cuenta
  nueva. El correo llega en español. Abrir el enlace y tocar «Ya lo verifiqué»
  en Inicio: el aviso desaparece y el asistente responde, lo que confirma
  también la clave de OpenRouter.
- **Copias de seguridad:** con la app instalada y la sesión iniciada, esto no
  debe terminar con `Success` para el paquete:

  ```bash
  adb shell bmgr backupnow com.pagate.apppagate
  ```

## 8. App Check (Play Integrity)

El backend ya rechaza llamadas sin token de App Check en `chat`, `scanReceipt`,
`deleteAccount` y `deleteChatHistory` cuando `ENFORCE_APP_CHECK=true`. Hoy el
interruptor está en `false` (`functions/.env`) y no se cambia hasta el último
punto de esta sección: si se exige antes, toda llamada desde Android falla.

1. **Vincular Play Integrity.** Play Console → Integridad de la app → API Play
   Integrity → vincular el proyecto de Google Cloud `pagate-17211`.
2. **Registrar la app en App Check.** Firebase → App Check → app Android →
   Play Integrity, con el SHA-256 del **certificado de firma de la app** que
   muestra Play Console (no el de la clave de subida).
3. **Tokens de depuración.** Firebase → App Check → app → Administrar tokens de
   depuración: agregar el token que imprime logcat en cada teléfono o emulador
   que use un build debug contra producción. Contra los emuladores locales no
   hace falta (ver README, `functions/.env.local`).
4. **Probar con un build de Play,** instalado desde la pista interna. Play
   Integrity no valida un APK instalado a mano.
5. **Medir.** Esperar a que las métricas de App Check muestren casi todas las
   solicitudes como verificadas.
6. **Firestore, por separado.** La exigencia de App Check en Firestore es otro
   interruptor de la consola. No activarlo sin revisar antes sus métricas.
7. **Último punto: exigirlo en los callables.** Cambiar
   `ENFORCE_APP_CHECK=true` en `functions/.env` y volver a desplegar las
   functions (paso 4).

**Verificar:**

- Antes de activar: las métricas de App Check muestran casi todo como
  verificado.
- Después de activar: el asistente sigue respondiendo en el build de Play, y
  `./scripts/smoke-prod.sh` sigue en «Todo OK» (`chat` sin sesión sigue dando
  `UNAUTHENTICATED`).

## 9. 12 probadores durante 14 días

Si la cuenta de desarrollador es personal y posterior a noviembre de 2023, Play
exige una prueba cerrada con al menos 12 probadores durante 14 días seguidos
antes de pedir acceso a producción. Son días de calendario.

1. Crear la pista de prueba cerrada con el bundle firmado.
2. Invitar a los probadores y pedirles que acepten e instalen desde Play.

**Verificar:** el panel de la prueba cerrada muestra al menos 12 probadores
aceptados y 14 días cumplidos. Recién entonces se habilita la solicitud de
acceso a producción.
