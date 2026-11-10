/**
 * Callable `scanReceipt`: ordena el texto de una boleta de compra como una
 * lista de artículos para el inventario.
 *
 * ---------------------------------------------------------------------------
 * LO QUE ESTA FUNCIÓN NO RECIBE: LA IMAGEN
 * ---------------------------------------------------------------------------
 * Recibe TEXTO. Nunca una foto, nunca un PDF, nunca bytes. El reconocimiento
 * de texto corre en el teléfono con ML Kit (en el dispositivo, sin conexión y
 * gratis) y la imagen se borra ahí mismo, haya ido bien o mal. Lo único que
 * sale del teléfono es el texto ya extraído.
 *
 * No es una decisión de implementación, es la decisión de producto sobre la que
 * está construida la función, y es la que hace que no haya Firebase Storage en
 * el proyecto, ni fotos que declarar en Seguridad de Datos de Google Play, ni
 * imágenes que borrar cuando alguien borra su cuenta. Si algún día esta función
 * aceptara una imagen, todo eso volvería a aparecer de golpe.
 *
 * ---------------------------------------------------------------------------
 * LO QUE EL MODELO APORTA, Y LO QUE NO
 * ---------------------------------------------------------------------------
 * El cliente SIEMPRE ordena la lista él solo primero, con una heurística local
 * que funciona sin conexión y sin cuota. Esta función es el repaso: sobre texto
 * limpio, un modelo de texto acierta mucho más que una regla, sobre todo con la
 * descripción partida en dos renglones de una boleta térmica.
 *
 * Consecuencias de que sea un repaso y no el camino único:
 *   - Un fallo de aquí no rompe nada: el cliente se queda con su lista local.
 *   - `resource-exhausted` (cuota agotada) NO es un error para el cliente, es
 *     información: la lista ya está en pantalla.
 *   - Nada de lo que devuelve esta función se guarda sin que el usuario lo
 *     revise. La app propone, el usuario confirma.
 *
 * ---------------------------------------------------------------------------
 * POR QUÉ LA LÓGICA ESTÁ EN `handleScanReceipt` Y NO EN EL `onCall`
 * ---------------------------------------------------------------------------
 * Misma estructura que `chat.ts`, y por la misma razón, que en este proyecto
 * salió caro aprender: con la lógica dentro del `onCall`, probarla exige una
 * clave de OpenRouter y salir a la red, así que no se prueba, y `chat` estuvo
 * MUERTA con la suite entera en verde. Con las dependencias inyectadas, el
 * flujo completo se ejercita contra el emulador sin clave y sin red.
 */

import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import {
  ENFORCE_APP_CHECK,
  OPENROUTER_API_KEY,
  OPENROUTER_SCAN_MODEL,
  REGION,
  callableCors,
} from './config';
import { OpenRouterError, askOpenRouter, type OpenRouterResult } from './openrouter';
import { buildScanMessages, type ScanSource } from './scanPrompt';
import { refundScanQuota, reserveScanQuota } from './quota';

/**
 * Tope del texto de entrada.
 *
 * Una boleta chilena de 40 artículos leída con OCR ronda los 2.000 caracteres;
 * una factura larga con cabecera y pie puede llegar a 4.000. 8.000 deja margen
 * de sobra y acota el coste: es lo que el usuario puede meter en los tokens de
 * entrada de cada llamada.
 */
export const MAX_SCAN_TEXT_CHARS = 8_000;

/** Artículos como máximo en la respuesta. Por encima se recorta. */
export const MAX_SCAN_ITEMS = 40;

/**
 * `temperature: 0`. No se quiere creatividad: se quiere que el mismo texto dé
 * la misma lista. Con la temperatura del chat (0,7) la misma boleta leída dos
 * veces podía dar precios distintos.
 */
export const SCAN_TEMPERATURE = 0;

/** Tope de salida: 40 artículos de JSON caben de sobra en 1.500 tokens. */
export const SCAN_MAX_TOKENS = 1_500;

/**
 * Espera máxima de OpenRouter. Por debajo del `timeoutSeconds: 60` del
 * callable, para que el plazo lo decida esta función (y pueda devolver la
 * cuota) en vez de morir con la instancia.
 */
const OPENROUTER_TIMEOUT_MS = 40_000;

/**
 * Rangos de cada campo.
 *
 * El esquema que viaja a OpenRouter se GENERA a partir de estas constantes (ver
 * `SCAN_RESPONSE_FORMAT`), así que el esquema y la validación no pueden
 * divergir: cambiar un tope aquí lo cambia en los dos sitios.
 */
export const SCAN_LIMITS = {
  nameChars: 120,
  unitChars: 20,
  codeChars: 40,
  supplierChars: 120,
  documentNumberChars: 40,
  /** Una cantidad de 0 no es un artículo comprado, y 10.000 ya es un error de OCR. */
  minQuantity: 1,
  maxQuantity: 10_000,
  /** En pesos chilenos no hay precios por debajo de 1, y 100 millones es el techo. */
  minUnitPrice: 1,
  maxUnitPrice: 100_000_000,
} as const;

/** Unidad por defecto cuando la boleta no dice ninguna. */
export const DEFAULT_UNIT = 'unidades';

export interface ScanReceiptRequest {
  /** Texto del OCR. Tope `MAX_SCAN_TEXT_CHARS`. */
  text: string;
  /** De dónde salió, solo para el registro y para matizar el prompt. */
  source?: ScanSource;
}

export interface ScanReceiptItem {
  name: string;
  quantity: number;
  unit: string;
  unitPrice: number;
  code: string | null;
}

export interface ScanReceiptResponse {
  items: ScanReceiptItem[];
  supplier: string | null;
  documentNumber: string | null;
  total: number | null;
  /** `true` si se recortaron artículos por el tope de `MAX_SCAN_ITEMS`. */
  truncated: boolean;
}

/**
 * Lo único que la llamada necesita del `CallableRequest`. Subconjunto
 * estructural, igual que en `chat.ts`: el `CallableRequest` real encaja sin
 * conversiones y un test puede construir una llamada con un objeto plano.
 */
export interface ScanCall {
  auth?: { uid: string; token?: { email_verified?: boolean } } | null;
  app?: unknown;
  data: unknown;
}

/** Dependencias de `handleScanReceipt`. Todas inyectables para poder probarlo. */
export interface ScanDeps {
  db: Firestore;
  /** Llamada al modelo. En los tests se sustituye por un doble. */
  ask: (opts: {
    apiKey: string;
    model: string;
    messages: Array<{ role: 'system' | 'user' | 'assistant'; content: string }>;
    timeoutMs?: number;
    temperature?: number;
    maxTokens?: number;
    responseFormat?: unknown;
  }) => Promise<OpenRouterResult>;
  apiKey: string;
  model: string;
  enforceAppCheck: boolean;
  /** Reloj. Fija el día de la cuota; por defecto, ahora. */
  now?: Date;
}

// ───────────────────────────────────────────────────────────────────────────
// Esquema de salida estructurada
// ───────────────────────────────────────────────────────────────────────────

/**
 * `response_format` de OpenRouter, en modo `json_schema` estricto.
 *
 * Se genera a partir de `SCAN_LIMITS` para que no pueda desalinearse de la
 * validación de abajo. Y la validación existe IGUAL: el esquema es una petición
 * al proveedor, no una garantía. Un proveedor que lo ignore (o un modelo sin
 * soporte de `structured_outputs`) devolvería texto libre, y entonces lo único
 * que separa al inventario del usuario de un precio inventado es el código de
 * `parseModelOutput`.
 */
export const SCAN_RESPONSE_FORMAT = {
  type: 'json_schema',
  json_schema: {
    name: 'articulos_de_boleta',
    strict: true,
    schema: {
      type: 'object',
      additionalProperties: false,
      required: ['items', 'supplier', 'documentNumber', 'total'],
      properties: {
        supplier: { type: ['string', 'null'], maxLength: SCAN_LIMITS.supplierChars },
        documentNumber: { type: ['string', 'null'], maxLength: SCAN_LIMITS.documentNumberChars },
        total: { type: ['number', 'null'] },
        items: {
          type: 'array',
          maxItems: MAX_SCAN_ITEMS,
          items: {
            type: 'object',
            additionalProperties: false,
            required: ['name', 'quantity', 'unit', 'unitPrice', 'code'],
            properties: {
              name: { type: 'string', maxLength: SCAN_LIMITS.nameChars },
              quantity: { type: 'number' },
              unit: { type: 'string', maxLength: SCAN_LIMITS.unitChars },
              unitPrice: { type: 'number' },
              code: { type: ['string', 'null'], maxLength: SCAN_LIMITS.codeChars },
            },
          },
        },
      },
    },
  },
} as const;

// ───────────────────────────────────────────────────────────────────────────
// Entrada
// ───────────────────────────────────────────────────────────────────────────

/** Valores admitidos de `source`. */
const SOURCES: readonly string[] = ['photo', 'pdf'];

/**
 * `source` solo matiza el prompt y el registro. Un valor desconocido se ignora
 * en vez de rechazar la llamada: perder una lectura entera por una pista de
 * registro mal escrita (una versión vieja del cliente, un campo renombrado)
 * sería un mal cambio.
 */
function toSource(value: unknown): ScanSource | undefined {
  return typeof value === 'string' && SOURCES.includes(value) ? (value as ScanSource) : undefined;
}

/**
 * Valida la entrada ANTES de reservar cuota. Un texto vacío o demasiado largo
 * no puede gastarle al usuario una de sus lecturas.
 */
export function parseScanInput(data: unknown): { text: string; source?: ScanSource } {
  if (typeof data !== 'object' || data === null) {
    throw new HttpsError('invalid-argument', 'Se esperaba un objeto con el campo text.');
  }
  const { text, source } = data as Record<string, unknown>;

  // El mensaje es el MISMO para "vacío", "no es texto" y "demasiado largo" a
  // propósito: es lo que el cliente muestra, y los tres casos son el mismo
  // problema visto desde el teléfono (de esa imagen no sale una lista). El
  // registro de abajo sí distingue, que es donde hace falta.
  const invalido = 'El texto de la boleta está vacío o es demasiado largo.';
  if (typeof text !== 'string') {
    throw new HttpsError('invalid-argument', invalido);
  }
  const trimmed = text.trim();
  if (trimmed.length === 0 || trimmed.length > MAX_SCAN_TEXT_CHARS) {
    throw new HttpsError('invalid-argument', invalido);
  }
  const parsed = toSource(source);
  return parsed ? { text: trimmed, source: parsed } : { text: trimmed };
}

// ───────────────────────────────────────────────────────────────────────────
// Salida del modelo
// ───────────────────────────────────────────────────────────────────────────

/**
 * La salida del modelo no se pudo interpretar en absoluto (no es JSON, no es un
 * objeto, `items` no es una lista). Se distingue de "la lista venía vacía"
 * porque lo primero es un fallo del proveedor —se devuelve la cuota— y lo
 * segundo es una respuesta legítima.
 */
export class ScanOutputError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ScanOutputError';
  }
}

/**
 * Texto de un campo del modelo: aplanado a una línea, sin los caracteres con
 * los que se construye marcado, y recortado.
 *
 * Es el mismo criterio que `sanitizeField` de `prompt.ts`, pero aplicado en la
 * dirección contraria: allí se protege el prompt de los datos del usuario, aquí
 * se protege el inventario del usuario de lo que devuelva el modelo. De aquí
 * sale un documento de Firestore.
 */
function cleanText(value: unknown, max: number): string {
  if (typeof value !== 'string') return '';
  const flat = value
    .replace(/[`#<>]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return flat.length <= max ? flat : flat.slice(0, max).trimEnd();
}

function cleanNullableText(value: unknown, max: number): string | null {
  const text = cleanText(value, max);
  return text.length === 0 ? null : text;
}

function finiteNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

/** Por qué se descartó un artículo. Va al registro, no al usuario. */
type RejectReason = 'no-es-objeto' | 'nombre-vacio' | 'cantidad' | 'precio';

function parseItem(raw: unknown): ScanReceiptItem | RejectReason {
  if (typeof raw !== 'object' || raw === null) return 'no-es-objeto';
  const d = raw as Record<string, unknown>;

  const name = cleanText(d.name, SCAN_LIMITS.nameChars);
  if (name.length === 0) return 'nombre-vacio';

  // La cantidad puede ser fraccionaria (`2,5 kg`): aquí NO se redondea. El
  // inventario guarda enteros (`isCount` de firestore.rules exige `int`), y el
  // redondeo lo hace el cliente, delante del usuario y diciéndoselo en la ficha
  // de revisión. Redondear en silencio aquí le cambiaría el número sin avisar.
  const quantity = finiteNumber(d.quantity);
  if (quantity === null || quantity < SCAN_LIMITS.minQuantity || quantity > SCAN_LIMITS.maxQuantity) {
    return 'cantidad';
  }

  const unitPrice = finiteNumber(d.unitPrice);
  if (unitPrice === null || unitPrice < SCAN_LIMITS.minUnitPrice || unitPrice > SCAN_LIMITS.maxUnitPrice) {
    return 'precio';
  }

  // La unidad NO descarta el artículo: un artículo con nombre, cantidad y
  // precio correctos es útil aunque la unidad venga vacía o rara, y la unidad
  // por defecto es la que ya usa el formulario manual.
  const unit = cleanText(d.unit, SCAN_LIMITS.unitChars).toLowerCase() || DEFAULT_UNIT;

  return { name, quantity, unit, unitPrice, code: cleanNullableText(d.code, SCAN_LIMITS.codeChars) };
}

export interface ParsedScanOutput {
  response: ScanReceiptResponse;
  /** Cuántos artículos se descartaron y por qué, para el registro. */
  rejected: RejectReason[];
}

/**
 * Interpreta y VALIDA la respuesta del modelo campo por campo.
 *
 * No se confía en el esquema. Es el mismo criterio que `parseUsage` de
 * `openrouter.ts`, que no se cree el bloque `usage` que manda la API, y aquí la
 * apuesta es más alta: de estos números salen los precios que el usuario va a
 * usar para poner los suyos.
 *
 * @throws ScanOutputError si la salida es irrecuperable.
 */
export function parseModelOutput(raw: string): ParsedScanOutput {
  // Algunos proveedores devuelven el JSON dentro de una valla de código
  // markdown aunque se les pida `json_schema`. Quitar la valla no es adivinar
  // nada: el contenido sigue siendo exactamente el que mandaron.
  const text = raw
    .trim()
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/, '')
    .trim();

  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch (err) {
    throw new ScanOutputError(`no es JSON: ${err instanceof Error ? err.message : String(err)}`);
  }
  if (typeof json !== 'object' || json === null || Array.isArray(json)) {
    throw new ScanOutputError('la raíz no es un objeto');
  }
  const root = json as Record<string, unknown>;
  if (!Array.isArray(root.items)) {
    throw new ScanOutputError('items no es una lista');
  }

  const items: ScanReceiptItem[] = [];
  const rejected: RejectReason[] = [];
  let truncated = false;
  for (const raw of root.items) {
    if (items.length >= MAX_SCAN_ITEMS) {
      truncated = true;
      break;
    }
    const item = parseItem(raw);
    if (typeof item === 'string') rejected.push(item);
    else items.push(item);
  }

  // El total se acota a un rango razonable, pero no se usa para cuadrar nada:
  // es informativo. Un total que no cuadra con la suma de los artículos NO se
  // corrige aquí ni se usa para rellenar precios; el cliente lo compara con lo
  // que el usuario ve y el usuario decide.
  const total = finiteNumber(root.total);
  const totalOk = total !== null && total >= 0 && total <= SCAN_LIMITS.maxUnitPrice ? total : null;

  return {
    response: {
      items,
      supplier: cleanNullableText(root.supplier, SCAN_LIMITS.supplierChars),
      documentNumber: cleanNullableText(root.documentNumber, SCAN_LIMITS.documentNumberChars),
      total: totalOk,
      truncated,
    },
    rejected,
  };
}

// ───────────────────────────────────────────────────────────────────────────
// Flujo
// ───────────────────────────────────────────────────────────────────────────

/**
 * Cuerpo del callable `scanReceipt`, con las dependencias inyectadas.
 *
 * Exportado para `test/scan.test.ts`: es la única forma de ejercitar el flujo
 * completo (auth, App Check, validación, cuota, modelo, validación de la salida
 * y devolución de cuota) contra el emulador sin clave de OpenRouter y sin red.
 */
export async function handleScanReceipt(request: ScanCall, deps: ScanDeps): Promise<ScanReceiptResponse> {
  // 1. Autenticación y App Check.
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Inicia sesión para leer boletas.');
  }
  if (deps.enforceAppCheck && !request.app) {
    throw new HttpsError('unauthenticated', 'Se requiere una verificación válida de App Check.');
  }
  // Correo verificado, antes de la cuota. El cliente trata el rechazo como
  // cualquier fallo: se queda con la lista local.
  if (request.auth.token?.email_verified !== true) {
    throw new HttpsError('failed-precondition', 'Verifica tu correo para leer boletas con el asistente.');
  }
  const uid = request.auth.uid;

  // 2. Entrada. Antes de la cuota: un texto inválido no gasta una lectura.
  const { text, source } = parseScanInput(request.data);

  const { db } = deps;
  const now = deps.now ?? new Date();

  // 3. Cuota propia del lector, separada de la del asistente. Lanza
  // `resource-exhausted` si no queda, y el cliente lo trata como información:
  // la lista local ya está en pantalla.
  const reservation = await reserveScanQuota(db, uid, now);

  // Devuelve la lectura cuando el fallo no es imputable al usuario. Nunca
  // lanza: el error que se le responde es el original.
  const rollback = async (reason: string) => {
    try {
      await refundScanQuota(db, uid, reservation.dayKey);
    } catch (err) {
      logger.error('scan.rollback.error', { uid, reason, error: String(err) });
    }
  };

  // 4. El modelo.
  const { model } = deps;
  let result: OpenRouterResult;
  try {
    result = await deps.ask({
      apiKey: deps.apiKey,
      model,
      messages: buildScanMessages(text, source),
      timeoutMs: OPENROUTER_TIMEOUT_MS,
      temperature: SCAN_TEMPERATURE,
      maxTokens: SCAN_MAX_TOKENS,
      responseFormat: SCAN_RESPONSE_FORMAT,
    });
  } catch (err) {
    logger.error('scan.openrouter.error', { uid, model, source: source ?? null, error: String(err) });
    await rollback('openrouter');
    // El plazo agotado se distingue del resto para que el cliente pueda decir
    // "tardó demasiado" en vez de "no responde"; los dos son recuperables
    // reintentando, y ninguno le ha costado una lectura.
    const timeout = err instanceof OpenRouterError && /tiempo de espera/i.test(err.message);
    throw new HttpsError(
      timeout ? 'deadline-exceeded' : 'unavailable',
      'El lector no responde. Intenta de nuevo.',
    );
  }

  // 5. Validación de la salida.
  let parsed: ParsedScanOutput;
  try {
    parsed = parseModelOutput(result.text);
  } catch (err) {
    // Irrecuperable: ni JSON, ni objeto, ni lista de artículos. Es un fallo del
    // proveedor (el esquema pedido es estricto), no algo que el usuario pueda
    // arreglar, así que se le devuelve la lectura. Se registra un recorte del
    // texto para poder diagnosticarlo sin volcar la respuesta entera al log.
    logger.error('scan.salida.irrecuperable', {
      uid,
      model,
      error: String(err),
      muestra: result.text.slice(0, 300),
    });
    await rollback('salida');
    throw new HttpsError('internal', 'No pude ordenar la boleta.');
  }

  // 6. Registro del gasto real. Es el único dato con el que el dueño puede
  // calcular lo que cuesta la función y montar una alerta.
  logger.info('scan.usage', {
    uid,
    model,
    plan: reservation.plan,
    source: source ?? null,
    textChars: text.length,
    promptTokens: result.usage?.promptTokens ?? null,
    completionTokens: result.usage?.completionTokens ?? null,
    totalTokens: result.usage?.totalTokens ?? null,
    items: parsed.response.items.length,
    rejected: parsed.rejected.length,
    rejectedReasons: parsed.rejected,
    truncated: parsed.response.truncated,
    usedLifetime: reservation.usedLifetime,
  });

  // 7. `items: []` es una respuesta, no un error.
  //
  // Puede ser correcta (la foto no era una boleta de compra) o puede ser que
  // todos los artículos hayan caído en la validación. En los dos casos el
  // cliente se queda con su lista local y el usuario no se queda sin nada.
  //
  // Y NO se devuelve la cuota aquí, aunque el usuario no haya recibido nada
  // útil. El motivo es que el texto de entrada lo controla entero quien llama:
  // si una respuesta vacía devolviera la lectura, bastaría con mandar texto que
  // no produzca artículos para hacer llamadas al modelo sin límite, y las paga
  // el dueño. La cuota se devuelve solo cuando falla el proveedor, que es lo
  // que el usuario no puede provocar.
  return parsed.response;
}

export const scanReceipt = onCall<ScanReceiptRequest, Promise<ScanReceiptResponse>>(
  {
    region: REGION,
    secrets: [OPENROUTER_API_KEY],
    timeoutSeconds: 60,
    memory: '256MiB',
    // Tope de gasto: evita escalado descontrolado ante abuso o picos.
    maxInstances: 5,
    cors: callableCors(),
  },
  // Los parámetros y el secreto se resuelven AQUÍ, en la envoltura: así
  // `handleScanReceipt` no depende de Secret Manager ni de `defineString`, y
  // por eso se puede probar contra el emulador.
  (request) =>
    handleScanReceipt(request, {
      db: getFirestore(),
      ask: askOpenRouter,
      apiKey: OPENROUTER_API_KEY.value(),
      model: OPENROUTER_SCAN_MODEL.value(),
      enforceAppCheck: ENFORCE_APP_CHECK.value(),
    }),
);
