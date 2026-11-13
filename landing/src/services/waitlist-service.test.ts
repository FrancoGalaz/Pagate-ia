import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { saveWaitlistEntry, WAITLIST_NOT_CONFIGURED } from './waitlist-service';

const URL = 'https://example.test/waitlist';
const entry = { name: 'Ana', email: 'ana@example.com', source: 'landing-page' };

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

describe('saveWaitlistEntry', () => {
  const fetchMock = vi.fn<typeof fetch>();

  beforeEach(() => {
    vi.stubEnv('VITE_WAITLIST_URL', URL);
    vi.stubGlobal('fetch', fetchMock);
    fetchMock.mockReset();
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
  });

  it('hace POST JSON con name, email y source', async () => {
    fetchMock.mockResolvedValue(jsonResponse(200, { ok: true }));

    await expect(saveWaitlistEntry(entry)).resolves.toBeUndefined();

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe(URL);
    expect(init?.method).toBe('POST');
    expect(init?.headers).toEqual({ 'Content-Type': 'application/json' });
    expect(JSON.parse(String(init?.body))).toEqual(entry);
  });

  it('usa el mensaje de error del servidor en 400', async () => {
    fetchMock.mockResolvedValue(jsonResponse(400, { error: 'Email inválido' }));

    await expect(saveWaitlistEntry(entry)).rejects.toThrow('Email inválido');
  });

  it('usa el mensaje de error del servidor en 429', async () => {
    fetchMock.mockResolvedValue(jsonResponse(429, { error: 'Demasiadas solicitudes' }));

    await expect(saveWaitlistEntry(entry)).rejects.toThrow('Demasiadas solicitudes');
  });

  it('cae a un mensaje por estado si el cuerpo no es JSON', async () => {
    fetchMock.mockResolvedValue(new Response('boom', { status: 500 }));

    await expect(saveWaitlistEntry(entry)).rejects.toThrow('error 500');
  });

  it('traduce fallos de red a un error legible', async () => {
    fetchMock.mockRejectedValue(new TypeError('Failed to fetch'));

    await expect(saveWaitlistEntry(entry)).rejects.toThrow('No se pudo conectar');
  });

  it('falla con un error claro si VITE_WAITLIST_URL no está definida', async () => {
    vi.stubEnv('VITE_WAITLIST_URL', '');

    await expect(saveWaitlistEntry(entry)).rejects.toThrow(WAITLIST_NOT_CONFIGURED);
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
