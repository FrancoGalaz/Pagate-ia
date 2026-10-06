import { defineBoolean, defineSecret, defineString } from 'firebase-functions/params';

/** Región única para todas las funciones (contrato v1). */
export const REGION = 'southamerica-west1';

/** Clave de OpenRouter: vive en Secret Manager, nunca en el cliente. */
export const OPENROUTER_API_KEY = defineSecret('OPENROUTER_API_KEY');

// Los valores de producción de los parámetros no secretos (defineString/defineBoolean)
// viven en `functions/.env` (versionado y desplegado). Los secretos (defineSecret)
// solo en Secret Manager. Sin `.env`, se usan los `default` declarados aquí.

/** Modelo usado por el asistente. */
export const OPENROUTER_MODEL = defineString('OPENROUTER_MODEL', {
  default: 'deepseek/deepseek-v4-flash',
  description: 'Modelo de OpenRouter para el chat',
});

/**
 * Exigir App Check en los callables (`chat` y `deleteAccount`). Se activa cuando
 * App Check esté configurado en consola.
 */
export const ENFORCE_APP_CHECK = defineBoolean('ENFORCE_APP_CHECK', {
  default: false,
  description: 'Rechazar llamadas a chat y deleteAccount sin token válido de App Check',
});

/**
 * `true` cuando el código corre dentro del emulador de Functions. La variable la
 * pone el propio emulador; en producción no existe.
 */
export const IS_EMULATOR = process.env.FUNCTIONS_EMULATOR === 'true';

/** Orígenes web de producción: el hosting de la app. */
const PRODUCTION_ORIGINS = ['https://pagate-17211.web.app', 'https://pagate-17211.firebaseapp.com'];

/** Origen de desarrollo: `flutter run -d chrome` sirve en un puerto cualquiera. */
const LOCALHOST_ORIGIN = /^http:\/\/localhost(:\d+)?$/;

/**
 * Lista CORS de los callables (S-08).
 *
 * El regex de localhost se añade SOLO bajo el emulador. Antes estaba fijo en la
 * lista de `chat`, también en producción: cualquier página servida desde
 * `http://localhost` en la máquina de la víctima podía llamar a la función con
 * sus credenciales. El valor se evalúa al cargar el módulo y el despliegue nunca
 * define `FUNCTIONS_EMULATOR`, así que lo que se despliega no lleva localhost.
 */
export function callableCors(): Array<string | RegExp> {
  return IS_EMULATOR ? [...PRODUCTION_ORIGINS, LOCALHOST_ORIGIN] : [...PRODUCTION_ORIGINS];
}

/**
 * Orígenes permitidos en el endpoint HTTP `waitlist` (S-04). Igual que arriba:
 * el `localhost:5173` de Vite solo cuenta bajo el emulador.
 */
export function waitlistOrigins(): Set<string> {
  const origins = ['https://francogalaz.github.io', ...PRODUCTION_ORIGINS];
  return new Set(IS_EMULATOR ? [...origins, 'http://localhost:5173'] : origins);
}
