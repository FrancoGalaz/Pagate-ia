// Datos del responsable y fechas que usan las tres páginas legales
// (privacidad, términos y eliminación de cuenta).
//
// Está en un módulo propio a propósito: los textos legales repiten los mismos
// datos de contacto tres veces, y tenerlos en un solo sitio evita que queden
// desincronizados. Cuando el dueño tenga razón social, domicilio y correo
// definitivos, basta con editar ESTE archivo.
//
// Los valores entre corchetes son MARCADORES sin rellenar: hay que
// reemplazarlos antes de declarar las URLs en Google Play Console, porque una
// política de privacidad con marcadores visibles es motivo de rechazo.
// El inventario de marcadores pendientes está en docs/SEGURIDAD-DATOS-PLAY.md.

/** Nombre comercial de la app tal como aparecerá en Google Play. */
export const APP_NAME = 'Págate-IA';

/** Identificador del paquete Android. Fuente: android/app/build.gradle.kts. */
export const ANDROID_PACKAGE = 'com.pagate.apppagate';

/**
 * Responsable del tratamiento. PENDIENTE: el dueño debe decidir si publica
 * como persona natural o como sociedad, y con qué domicilio.
 */
export const RESPONSIBLE = {
  legalName: '[RAZÓN SOCIAL O NOMBRE COMPLETO DEL RESPONSABLE]',
  taxId: '[RUT DEL RESPONSABLE]',
  address: '[DOMICILIO: calle, número, comuna, región, Chile]',
  country: 'Chile',
} as const;

/**
 * Correos de contacto. PENDIENTE: hoy no existe ningún buzón operativo.
 * El `soporte@pagate-ia.com` que muestra la app usa un dominio que el dueño
 * NO controla (verificado en docs/AUDITORIA-2026-09-29.md), así que no se
 * reutiliza aquí. El correo de privacidad y el de la ficha de Play deben ser
 * el mismo y estar atendido antes de publicar.
 */
export const CONTACT = {
  privacy: '[CORREO DE CONTACTO DE PRIVACIDAD]',
  support: '[CORREO DE SOPORTE DECLARADO EN GOOGLE PLAY]',
} as const;

/**
 * Fecha de la última revisión de los textos legales. Se escribe a mano: no se
 * usa `new Date()` porque un documento legal no puede cambiar su fecha de
 * vigencia cada vez que se recompila la landing.
 */
export const LEGAL_VERSION = {
  version: '1.0',
  updatedAt: '6 de octubre de 2026',
} as const;

/**
 * Rutas públicas de las páginas legales, relativas a la raíz del sitio.
 * Son directorios con `index.html` para que la URL quede limpia
 * (`/privacidad/`) en GitHub Pages, Firebase Hosting y Vercel por igual.
 */
export const LEGAL_ROUTES = {
  privacidad: 'privacidad/',
  terminos: 'terminos/',
  eliminarCuenta: 'eliminar-cuenta/',
  inicio: '',
} as const;

/**
 * Convierte una ruta de [LEGAL_ROUTES] en un href absoluto.
 *
 * La landing se publica bajo un prefijo (`/Pagate-ia/landing-page/` en GitHub
 * Pages, `/` en Vercel), así que no se puede escribir `/privacidad/` a mano ni
 * usar rutas relativas, que cambiarían de significado según la profundidad de
 * la página. `BASE_URL` lo inyecta Vite desde `base` en vite.config.ts.
 */
export function siteUrl(route: string): string {
  return `${import.meta.env.BASE_URL}${route}`;
}

/**
 * Plazo comprometido para atender una solicitud de eliminación. 30 días es el
 * plazo de referencia que usa la política de eliminación de datos de Google
 * Play; no se promete menos de lo que una persona sola puede cumplir.
 */
export const DELETION_SLA_DAYS = 30;

/**
 * Días que pueden tardar en expirar las copias de respaldo de Firestore tras
 * el borrado. Se declara porque afirmar borrado instantáneo sería falso.
 */
export const BACKUP_RETENTION_DAYS = 90;
