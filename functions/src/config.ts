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

/** Exigir App Check en `chat`. Se activa cuando App Check esté configurado en consola. */
export const ENFORCE_APP_CHECK = defineBoolean('ENFORCE_APP_CHECK', {
  default: false,
  description: 'Rechazar llamadas a chat sin token válido de App Check',
});
