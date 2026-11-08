# Checklist de publicación

Pasos que solo puede hacer el dueño del proyecto en las consolas. El resto de
lo que falta para Google Play está en `docs/PLAN.md` y `docs/FICHA-PLAY.md`.

## App Check (Play Integrity)

El backend ya rechaza llamadas sin token de App Check en `chat`, `scanReceipt`
y `deleteAccount` cuando `ENFORCE_APP_CHECK=true`. Hoy el interruptor está en
`false` (`functions/.env`) y no debe cambiarse hasta completar los pasos 1 a 7:
si se exige antes, toda llamada desde Android falla.

1. **Requisitos previos.** El proyecto `pagate-17211` configurado (app Android
   en Firebase) y la app creada en Play Console.
2. **Vincular Play Integrity.** Play Console → Integridad de la app → API Play
   Integrity → vincular el proyecto de Google Cloud `pagate-17211`.
3. **Registrar la app en App Check.** Firebase → App Check → app Android →
   Play Integrity, con el SHA-256 del **certificado de firma de la app** que
   muestra Play Console (no el de la clave de subida).
4. **Tokens de depuración.** Firebase → App Check → app → Administrar tokens de
   depuración: agregar el token que imprime logcat en cada teléfono o emulador
   de desarrollo que use un build debug contra producción. Contra los
   emuladores locales no hace falta (ver README, `functions/.env.local`).
5. **Probar con un build de Play.** Subir un build a una pista de prueba interna
   e instalarlo desde Play. Play Integrity no valida un APK instalado a mano.
6. **Medir.** Esperar a que las métricas de App Check muestren casi todas las
   solicitudes como verificadas.
7. **Firestore, por separado.** La exigencia de App Check en Firestore es otro
   interruptor de la consola y no forma parte de este cambio. No activarlo sin
   revisar antes sus métricas.
8. **Último paso: activar la exigencia en los callables.** Cambiar
   `ENFORCE_APP_CHECK=true` en `functions/.env` y volver a desplegar las
   functions. Solo después de los pasos 1 a 6.

## Copias de seguridad (teléfono real)

La app desactiva las copias de seguridad de Android (`allowBackup=false` y
`res/xml/data_extraction_rules.xml`). Comprobarlo en un teléfono real con la
app instalada y la sesión iniciada:

```bash
adb shell bmgr backupnow com.pagate.apppagate
```

No debe respaldar nada: el paquete no tiene que terminar con una copia
correcta (`Success`).
