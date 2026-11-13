// Waitlist service: envía el registro a la Cloud Function `waitlist`.
//
// Contrato (docs/ARQUITECTURA.md):
//   POST { name: string, email: string, source?: string }
//   200 { ok: true } | 400 { error } | 429 { error }
//
// La URL se configura con VITE_WAITLIST_URL (ver .env.example).

export interface WaitlistEntry {
  name: string;
  email: string;
  source: string;
}

export const WAITLIST_NOT_CONFIGURED = 'Lista de espera no configurada';

function messageForStatus(status: number): string {
  if (status === 429) return 'Demasiados intentos. Espera un momento y vuelve a probar.';
  if (status === 400) return 'Revisa tu nombre y correo e inténtalo de nuevo.';
  return `No pudimos registrarte (error ${status}). Inténtalo más tarde.`;
}

export async function saveWaitlistEntry(entry: WaitlistEntry): Promise<void> {
  const url = import.meta.env.VITE_WAITLIST_URL;
  if (!url) {
    throw new Error(WAITLIST_NOT_CONFIGURED);
  }

  let response: Response;
  try {
    response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: entry.name,
        email: entry.email,
        source: entry.source,
      }),
    });
  } catch {
    throw new Error('No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.');
  }

  if (response.ok) return;

  let message = messageForStatus(response.status);
  try {
    const body = (await response.json()) as { error?: unknown };
    if (typeof body?.error === 'string' && body.error.trim()) {
      message = body.error;
    }
  } catch {
    // Cuerpo no JSON: se usa el mensaje por estado.
  }
  throw new Error(message);
}
