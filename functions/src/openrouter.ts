/**
 * Cliente mínimo de OpenRouter (API compatible con OpenAI chat/completions).
 * Usa `fetch` nativo de Node 22; sin dependencias externas.
 *
 * Además del texto devuelve el bloque `usage` que manda la API (tokens de
 * entrada y de salida). Sin él no hay forma de saber lo que cuesta cada
 * llamada: el precio depende del modelo configurado en `OPENROUTER_MODEL` y
 * solo OpenRouter lo conoce, así que lo que hacemos aquí es dejar los tokens
 * reales registrados para que el dueño pueda multiplicarlos por la tarifa de su
 * modelo y, si quiere, montar una alerta en Cloud Logging.
 */

export type ChatRole = 'system' | 'user' | 'assistant';

export interface ChatMessage {
  role: ChatRole;
  content: string;
}

export interface OpenRouterOptions {
  apiKey: string;
  model: string;
  messages: ChatMessage[];
  /** Tiempo máximo de espera. Por defecto 30 s. */
  timeoutMs?: number;
  temperature?: number;
  maxTokens?: number;
}

/** Tokens consumidos por la llamada, tal como los reporta OpenRouter. */
export interface OpenRouterUsage {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
}

export interface OpenRouterResult {
  text: string;
  /** `null` si el modelo no reportó `usage`. */
  usage: OpenRouterUsage | null;
}

export class OpenRouterError extends Error {
  constructor(
    message: string,
    public readonly status?: number,
  ) {
    super(message);
    this.name = 'OpenRouterError';
  }
}

interface OpenRouterResponse {
  choices?: Array<{ message?: { content?: string | null } }>;
  error?: { message?: string };
  usage?: { prompt_tokens?: number; completion_tokens?: number; total_tokens?: number };
}

const ENDPOINT = 'https://openrouter.ai/api/v1/chat/completions';
const DEFAULT_TIMEOUT_MS = 30_000;

function int(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? Math.max(0, Math.round(value)) : 0;
}

export function parseUsage(raw: OpenRouterResponse['usage']): OpenRouterUsage | null {
  if (!raw || typeof raw !== 'object') return null;
  const promptTokens = int(raw.prompt_tokens);
  const completionTokens = int(raw.completion_tokens);
  const totalTokens = int(raw.total_tokens) || promptTokens + completionTokens;
  if (promptTokens === 0 && completionTokens === 0 && totalTokens === 0) return null;
  return { promptTokens, completionTokens, totalTokens };
}

export async function askOpenRouter(opts: OpenRouterOptions): Promise<OpenRouterResult> {
  const timeoutMs = opts.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    let res: Response;
    try {
      res = await fetch(ENDPOINT, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${opts.apiKey}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://pagate-17211.web.app',
          'X-Title': 'Pagate-IA',
        },
        body: JSON.stringify({
          model: opts.model,
          messages: opts.messages,
          temperature: opts.temperature ?? 0.7,
          max_tokens: opts.maxTokens ?? 1024,
        }),
        signal: controller.signal,
      });
    } catch (err) {
      if (err instanceof Error && err.name === 'AbortError') {
        throw new OpenRouterError(`Tiempo de espera agotado (${timeoutMs} ms)`);
      }
      throw new OpenRouterError(`Error de red: ${err instanceof Error ? err.message : String(err)}`);
    }

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new OpenRouterError(`HTTP ${res.status}: ${body.slice(0, 300)}`, res.status);
    }

    // `res.json()` puede fallar si la respuesta no es JSON válido (proxy caído,
    // HTML de error). Se envuelve para no propagar un error ajeno al dominio.
    let json: OpenRouterResponse;
    try {
      json = (await res.json()) as OpenRouterResponse;
    } catch (err) {
      throw new OpenRouterError(
        `Respuesta no es JSON válido: ${err instanceof Error ? err.message : String(err)}`,
        res.status,
      );
    }

    if (json.error?.message) {
      throw new OpenRouterError(json.error.message, res.status);
    }
    const content = json.choices?.[0]?.message?.content;
    if (typeof content !== 'string' || content.trim().length === 0) {
      throw new OpenRouterError('El modelo devolvió una respuesta vacía', res.status);
    }
    return { text: content.trim(), usage: parseUsage(json.usage) };
  } finally {
    clearTimeout(timer);
  }
}
