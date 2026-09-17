/**
 * Cliente mínimo de OpenRouter (API compatible con OpenAI chat/completions).
 * Usa `fetch` nativo de Node 22; sin dependencias externas.
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
}

const ENDPOINT = 'https://openrouter.ai/api/v1/chat/completions';
const DEFAULT_TIMEOUT_MS = 30_000;

export async function askOpenRouter(opts: OpenRouterOptions): Promise<string> {
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

    const json = (await res.json()) as OpenRouterResponse;
    if (json.error?.message) {
      throw new OpenRouterError(json.error.message, res.status);
    }
    const content = json.choices?.[0]?.message?.content;
    if (typeof content !== 'string' || content.trim().length === 0) {
      throw new OpenRouterError('El modelo devolvió una respuesta vacía', res.status);
    }
    return content.trim();
  } finally {
    clearTimeout(timer);
  }
}
