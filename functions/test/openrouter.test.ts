/**
 * Tests del cliente de OpenRouter.
 *
 * ---------------------------------------------------------------------------
 * POR QUÉ ESTE ARCHIVO EXISTE AHORA
 * ---------------------------------------------------------------------------
 * `scanReceipt` depende de que `response_format` LLEGUE AL CUERPO de la
 * petición. Si no llega, nada falla a la vista: el modelo contesta un párrafo
 * en prosa, `parseModelOutput` lo rechaza como irrecuperable y el usuario ve
 * «No pude ordenar la boleta» en cada lectura, con la cuota devuelta y los
 * tests del callable en verde, porque el doble del modelo sí recibía el campo.
 *
 * Es exactamente la forma del fallo que en este proyecto ya dejó MUERTA la
 * función insignia con la suite entera en verde. Así que el campo se comprueba
 * donde de verdad se escribe: en el cuerpo que viaja por `fetch`.
 *
 * `fetch` se sustituye por un doble. No se sale a la red y no hace falta clave.
 */

import { afterEach, describe, expect, it, vi } from 'vitest';
import { OpenRouterError, askOpenRouter, parseUsage } from '../src/openrouter';

/** Cuerpos que recibió el doble de `fetch`, ya parseados. */
interface Peticion {
  url: string;
  body: Record<string, unknown>;
  headers: Record<string, string>;
}

function stubFetch(
  respuesta: unknown = { choices: [{ message: { content: 'hola' } }] },
  init: { status?: number; json?: boolean } = {},
): Peticion[] {
  const peticiones: Peticion[] = [];
  vi.stubGlobal('fetch', async (url: string, opts: RequestInit) => {
    peticiones.push({
      url,
      body: JSON.parse(String(opts.body)) as Record<string, unknown>,
      headers: opts.headers as Record<string, string>,
    });
    const status = init.status ?? 200;
    return {
      ok: status >= 200 && status < 300,
      status,
      json: async () => {
        if (init.json === false) throw new Error('Unexpected token < in JSON');
        return respuesta;
      },
      text: async () => JSON.stringify(respuesta),
    } as unknown as Response;
  });
  return peticiones;
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('askOpenRouter: el cuerpo que viaja de verdad', () => {
  it('manda response_format tal cual cuando se pide', async () => {
    const formato = { type: 'json_schema', json_schema: { name: 'x', strict: true, schema: {} } };
    const peticiones = stubFetch();

    await askOpenRouter({
      apiKey: 'k',
      model: 'm',
      messages: [{ role: 'user', content: 'hola' }],
      responseFormat: formato,
      temperature: 0,
      maxTokens: 1500,
    });

    expect(peticiones).toHaveLength(1);
    expect(peticiones[0].body.response_format).toEqual(formato);
    expect(peticiones[0].body.temperature).toBe(0);
    expect(peticiones[0].body.max_tokens).toBe(1500);
  });

  it('NO manda response_format cuando no se pide: el chat viaja como siempre', async () => {
    const peticiones = stubFetch();

    await askOpenRouter({ apiKey: 'k', model: 'm', messages: [{ role: 'user', content: 'hola' }] });

    // Ausente, no `null`: un `response_format: null` podría ser un 400 según el
    // proveedor, y entonces el campo nuevo rompería el asistente.
    expect('response_format' in peticiones[0].body).toBe(false);
    expect(peticiones[0].body.temperature).toBe(0.7);
    expect(peticiones[0].body.max_tokens).toBe(1024);
  });

  it('devuelve el texto recortado y los tokens reportados', async () => {
    stubFetch({
      choices: [{ message: { content: '  respuesta  ' } }],
      usage: { prompt_tokens: 10, completion_tokens: 4, total_tokens: 14 },
    });

    const res = await askOpenRouter({ apiKey: 'k', model: 'm', messages: [] });
    expect(res.text).toBe('respuesta');
    expect(res.usage).toEqual({ promptTokens: 10, completionTokens: 4, totalTokens: 14 });
  });

  it('un HTTP de error se convierte en OpenRouterError con el estado', async () => {
    stubFetch({ error: { message: 'no autorizado' } }, { status: 401 });
    await expect(askOpenRouter({ apiKey: 'k', model: 'm', messages: [] })).rejects.toThrow(OpenRouterError);
  });

  it('una respuesta vacía del modelo es un error, no una cadena vacía', async () => {
    stubFetch({ choices: [{ message: { content: '   ' } }] });
    await expect(askOpenRouter({ apiKey: 'k', model: 'm', messages: [] })).rejects.toThrow(/respuesta vacía/i);
  });

  it('un cuerpo que no es JSON válido se envuelve en OpenRouterError', async () => {
    stubFetch({}, { json: false });
    await expect(askOpenRouter({ apiKey: 'k', model: 'm', messages: [] })).rejects.toThrow(/no es JSON válido/i);
  });

  it('el plazo agotado dice "Tiempo de espera", que es lo que scan.ts detecta', async () => {
    // `scan.ts` distingue `deadline-exceeded` de `unavailable` buscando ese
    // texto en el mensaje: si cambia aquí, allí deja de distinguirse.
    vi.stubGlobal('fetch', async () => {
      const err = new Error('abortada');
      err.name = 'AbortError';
      throw err;
    });
    await expect(askOpenRouter({ apiKey: 'k', model: 'm', messages: [], timeoutMs: 5 })).rejects.toThrow(
      /Tiempo de espera agotado/i,
    );
  });
});

describe('parseUsage', () => {
  it('no se cree un bloque usage ausente o vacío', () => {
    expect(parseUsage(undefined)).toBeNull();
    expect(parseUsage({})).toBeNull();
    expect(parseUsage({ prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 })).toBeNull();
  });

  it('calcula el total cuando el proveedor no lo manda', () => {
    expect(parseUsage({ prompt_tokens: 7, completion_tokens: 3 })).toEqual({
      promptTokens: 7,
      completionTokens: 3,
      totalTokens: 10,
    });
  });
});
