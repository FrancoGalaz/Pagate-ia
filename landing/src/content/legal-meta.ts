// Datos del responsable y fechas que usan las tres páginas legales
// (privacidad, términos y eliminación de cuenta).
//
// Está en un módulo propio a propósito: los textos legales repiten los mismos
// datos de contacto tres veces, y tenerlos en un solo sitio evita que queden
// desincronizados. Cuando el dueño tenga razón social, domicilio y correo
// definitivos, basta con editar ESTE archivo.
//
// Los valores entre corchetes son MARCADORES sin rellenar. Las páginas legales
// NO los imprimen tal cual: `esMarcador()` los detecta y cada página muestra en
// su lugar una frase en castellano, porque una política publicada con corchetes
// a la vista es motivo de rechazo en Google Play y delata una plantilla sin
// revisar. Eso evita el rechazo por corchetes, pero NO rellena el dato: el
// inventario de lo que el dueño tiene que decidir está en docs/FICHA-PLAY.md §8
// y en docs/SEGURIDAD-DATOS-PLAY.md §4.1.

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
  updatedAt: '8 de noviembre de 2026',
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

// ─────────────────────────────────────────────────────────────────────────────
// Marcadores sin rellenar
// ─────────────────────────────────────────────────────────────────────────────
//
// Lo que sigue existe por una sola razón: el visitante no puede ver un corchete.
// Google Play rechaza una política de privacidad con marcadores de plantilla a
// la vista, y mientras el dueño no decida razón social, RUT, domicilio y
// correos, esos datos siguen siendo marcadores. La salida honesta no es
// inventarlos: es que cada página redacte la frase que corresponde al estado
// real del dato y que avise, en castellano, de que falta.

/**
 * ¿El valor sigue siendo un marcador sin rellenar?
 *
 * La convención del archivo es escribir los pendientes entre corchetes
 * (`[RUT DEL RESPONSABLE]`). Basta con encontrar un par de corchetes con algo
 * dentro: ningún dato legítimo —ni un nombre, ni un RUT, ni un correo— lleva
 * corchetes.
 */
export function esMarcador(value: string): boolean {
  return /\[[^\]]+\]/.test(value);
}

/**
 * Correos listos para usar en un enlace `mailto:`, o `null` mientras el valor
 * siga siendo un marcador.
 *
 * Se expone aparte de [CONTACT] a propósito: un `mailto:[CORREO…]` es un enlace
 * roto que abre el cliente de correo con un destinatario inválido, que es peor
 * que no ofrecer el enlace. Con `null`, la página renderiza el camino
 * alternativo en lugar del botón.
 */
export const BUZON = {
  privacidad: esMarcador(CONTACT.privacy) ? null : CONTACT.privacy,
  soporte: esMarcador(CONTACT.support) ? null : CONTACT.support,
} as const;

/** ¿Está publicada la identidad completa del responsable? */
export const RESPONSABLE_IDENTIFICADO =
  !esMarcador(RESPONSIBLE.legalName) &&
  !esMarcador(RESPONSIBLE.taxId) &&
  !esMarcador(RESPONSIBLE.address);

/**
 * Canal al que se deriva al visitante mientras no haya un correo publicado.
 *
 * No es un invento: Google Play obliga a publicar en la ficha un correo de
 * contacto del desarrollador y lo muestra en la propia página de la app, así
 * que ese canal existe siempre, incluso antes de que este archivo tenga un
 * buzón propio.
 */
export const CANAL_ALTERNATIVO =
  `la dirección de contacto del desarrollador que aparece en la ficha de ` +
  `${APP_NAME} en Google Play`;

/**
 * Frase que describe al responsable cuando su identidad todavía no está
 * publicada. Dice lo que sí se sabe —quién es, aunque no cómo se llama— y no
 * finge un nombre ni un RUT.
 */
export const RESPONSABLE_SIN_IDENTIFICAR =
  `el titular de la cuenta de desarrollador con la que se publica ${APP_NAME} ` +
  `en Google Play, con domicilio en ${RESPONSIBLE.country}`;

/**
 * Datos que el dueño todavía tiene que publicar, en el orden en que aparecen en
 * las páginas. Lo usa el aviso visible de las páginas legales: si la lista está
 * vacía, el aviso no se renderiza y desaparece solo.
 */
export const DATOS_PENDIENTES: readonly string[] = [
  esMarcador(RESPONSIBLE.legalName) ? 'nombre completo o razón social' : null,
  esMarcador(RESPONSIBLE.taxId) ? 'RUT' : null,
  esMarcador(RESPONSIBLE.address) ? 'domicilio' : null,
  esMarcador(CONTACT.privacy) ? 'correo de privacidad' : null,
  esMarcador(CONTACT.support) ? 'correo de soporte' : null,
].filter((x): x is string => x !== null);

// ─────────────────────────────────────────────────────────────────────────────
// Funciones de la app que estos documentos describen
// ─────────────────────────────────────────────────────────────────────────────
//
// La política de privacidad describe funciones que viven en `lib/`, y la landing
// es un build distinto que no puede leer el código de la app. Eso ya nos mordió:
// el documento afirmaba que el usuario podía anotar proveedor y código interno
// en el inventario y editar su ficha «cuando quiera», y en la app no existía ni
// el campo en el formulario ni la pantalla de editar. Un documento legal
// publicado que promete de más es exactamente el hallazgo que retira una ficha.
//
// La salida no es escribir el texto optimista y esperar: es declarar aquí, con
// un booleano, qué funciones están de verdad en la app, y que un test compruebe
// esa declaración contra `lib/`. Mientras el booleano sea `false`, cada página
// redacta la versión que corresponde al estado real.
//
// SI VIENES DE INTEGRAR UN CARRIL DE CLIENTE: pon el booleano en `true`. El test
// «las funciones que la política describe coinciden con la app» de
// `landing/src/honestidad.test.ts` falla —y dice qué poner— cuando una función
// entra en `lib/` y aquí sigue declarada como ausente, y también al contrario.
export const FUNCIONES_APP = {
  /**
   * Ficha de inventario completa: los campos de **proveedor** y **código
   * interno** en el formulario de alta, y la pantalla de **editar** una ficha ya
   * creada (hoy solo se puede ajustar el stock o borrarla).
   *
   * Señal en el código: `supplier:` y `updateItem(` en
   * `lib/features/inventory/presentation/`, fuera de `providers/`.
   */
  fichaInventarioCompleta: true,

  /**
   * Lector de boletas: tomar una foto, elegir una imagen de la galería, o
   * compartir a la app una imagen o un PDF desde WhatsApp, el correo o la app
   * de Archivos del teléfono, y que de ahí salgan los artículos para revisarlos
   * antes de meterlos al inventario. El reconocimiento de texto ocurre **en el
   * teléfono** y la imagen no se guarda en ninguna parte.
   *
   * Son TRES entradas, no cuatro: compartir es un único camino
   * (`ACTION_SEND`/`ACTION_SEND_MULTIPLE` en `AndroidManifest.xml`), y un
   * archivo del propio teléfono llega por él, desde Archivos. La app no tiene
   * selector de archivos propio y el contrato del repositorio lo dice:
   * «Las tres entradas se reducen a [ReceiptDocument]».
   *
   * EL ENVÍO DEL TEXTO A UN TERCERO DEPENDE DE QUE EL CALLABLE ESTÉ
   * DESPLEGADO. Ordenar la lista lo hace `scanReceipt`, y hoy ese callable no
   * está en producción. Mientras no lo esté, el texto no sale del teléfono:
   * `remote_line_item_parser.dart` trata cualquier fallo —incluido «no está
   * desplegado»— como degradación, conserva la lista que armó el propio
   * teléfono y la pantalla lo dice en palabras. Por eso los documentos
   * redactan la salida del texto como condicional, no como un hecho: esta
   * bandera dice que la función existe, no que el envío esté activo.
   *
   * Señal en el código: la dependencia de reconocimiento de texto en
   * `pubspec.yaml`.
   */
  lectorBoletas: true,

  /**
   * ¿Está desplegado el paso que SACA EL TEXTO DEL TELÉFONO?
   *
   * Es una bandera aparte de [lectorBoletas] porque son dos hechos distintos y
   * el documento legal necesita los dos. Que el lector exista (arriba) no
   * implica que salga texto hacia un tercero: eso solo pasa cuando el callable
   * `scanReceipt` está desplegado en producción, y hoy no lo está.
   *
   * Mientras siga en `false`, el texto reconocido NO sale del teléfono en
   * ningún momento. `remote_line_item_parser.dart` trata cualquier fallo del
   * callable —y «no está desplegado» es uno— como degradación: conserva la
   * lista que armó el propio teléfono y la pantalla de revisión lo dice en
   * palabras («Ordené la lista yo sola, sin el asistente»). La función no se
   * cae; baja de calidad y lo admite.
   *
   * POR QUÉ ESTA NO LA VIGILA `FUNCIONES_DECLARADAS` de honestidad.test.ts.
   * Las otras dos se comprueban leyendo `lib/`, porque son hechos del código.
   * Esta no es un hecho del código: el cliente llama al callable igual, esté
   * desplegado o no, así que no hay señal en el repositorio que un test pueda
   * leer. Es un hecho del despliegue, y vive en la consola de Firebase.
   *
   * QUIÉN LA PONE EN `true`: quien despliegue `functions`. Un documento que
   * dice «el texto no sale» con el callable ya sirviendo es exactamente la
   * clase de mentira que este archivo existe para evitar, solo en la otra
   * dirección: por defecto.
   */
  ordenadoDeBoletasEnServidor: false,
} as const;
