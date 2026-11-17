/**
 * Tests de la lista de espera (S-04). No necesitan emulador: se prueban las
 * funciones puras del endpoint.
 */

import { beforeEach, describe, expect, it } from 'vitest';
import type { Request } from 'firebase-functions/v2/https';
import { clientIp, isRateLimited, resetRateLimit, validateWaitlistBody, waitlistDocId } from '../src/waitlist';

/** Construye lo mínimo de un Request que usa `clientIp`. */
function req(headers: Record<string, string | string[] | undefined>, ip?: string): Request {
  return { headers, ip } as unknown as Request;
}

describe('clientIp', () => {
  it('toma el ÚLTIMO salto de X-Forwarded-For, no el primero', () => {
    // El primer valor es el que el cliente puede inventar; el último lo añade
    // la infraestructura.
    expect(clientIp(req({ 'x-forwarded-for': '1.2.3.4, 203.0.113.7' }))).toBe('203.0.113.7');
    expect(clientIp(req({ 'x-forwarded-for': 'falso, otro, 198.51.100.9' }))).toBe('198.51.100.9');
  });

  it('un atacante que cambia la cabecera en cada petición sigue cayendo en la misma clave', () => {
    const real = '203.0.113.7';
    const ips = ['1.1.1.1', '2.2.2.2', '3.3.3.3'].map((spoof) =>
      clientIp(req({ 'x-forwarded-for': `${spoof}, ${real}` })),
    );
    expect(new Set(ips).size).toBe(1);
    expect(ips[0]).toBe(real);
  });

  it('tolera espacios, valores vacíos y la cabecera repetida como array', () => {
    expect(clientIp(req({ 'x-forwarded-for': '  1.2.3.4 ,  203.0.113.7  ' }))).toBe('203.0.113.7');
    expect(clientIp(req({ 'x-forwarded-for': '1.2.3.4,,' }))).toBe('1.2.3.4');
    expect(clientIp(req({ 'x-forwarded-for': ['1.2.3.4', '203.0.113.7'] }))).toBe('203.0.113.7');
  });

  it('cae a req.ip cuando no hay cabecera', () => {
    expect(clientIp(req({}, '203.0.113.1'))).toBe('203.0.113.1');
    expect(clientIp(req({ 'x-forwarded-for': '   ' }, '203.0.113.1'))).toBe('203.0.113.1');
    expect(clientIp(req({}))).toBe('unknown');
  });
});

describe('isRateLimited', () => {
  beforeEach(() => {
    resetRateLimit();
  });

  it('permite 5 por hora y bloquea la sexta', () => {
    const t = Date.parse('2026-09-29T10:00:00Z');
    for (let i = 0; i < 5; i++) {
      expect(isRateLimited('ip-a', t + i * 1000), `la petición ${i + 1} debería pasar`).toBe(false);
    }
    expect(isRateLimited('ip-a', t + 6000)).toBe(true);
  });

  it('la ventana es deslizante: una hora después vuelve a permitir', () => {
    const t = Date.parse('2026-09-29T10:00:00Z');
    for (let i = 0; i < 5; i++) isRateLimited('ip-b', t + i * 1000);
    expect(isRateLimited('ip-b', t + 10_000)).toBe(true);
    expect(isRateLimited('ip-b', t + 60 * 60 * 1000 + 1)).toBe(false);
  });

  it('cada IP cuenta por separado', () => {
    const t = Date.parse('2026-09-29T10:00:00Z');
    for (let i = 0; i < 5; i++) isRateLimited('ip-c', t + i);
    expect(isRateLimited('ip-c', t + 10)).toBe(true);
    expect(isRateLimited('ip-d', t + 10)).toBe(false);
  });
});

describe('waitlistDocId', () => {
  it('es determinista: el mismo correo da el mismo id', () => {
    expect(waitlistDocId('ana@ejemplo.cl')).toBe(waitlistDocId('ana@ejemplo.cl'));
  });

  it('es un sha256 en hexadecimal', () => {
    expect(waitlistDocId('ana@ejemplo.cl')).toMatch(/^[0-9a-f]{64}$/);
  });

  it('correos distintos dan ids distintos', () => {
    expect(waitlistDocId('ana@ejemplo.cl')).not.toBe(waitlistDocId('beto@ejemplo.cl'));
  });

  it('el id sale del correo ya normalizado por validateWaitlistBody', () => {
    const a = validateWaitlistBody({ name: 'Ana', email: '  ANA@Ejemplo.CL ' });
    const b = validateWaitlistBody({ name: 'Ana', email: 'ana@ejemplo.cl' });
    expect(a.ok && b.ok).toBe(true);
    if (a.ok && b.ok) {
      expect(waitlistDocId(a.value.email)).toBe(waitlistDocId(b.value.email));
    }
  });
});

describe('validateWaitlistBody', () => {
  it('acepta un cuerpo válido y normaliza el correo', () => {
    const res = validateWaitlistBody({ name: '  Ana  ', email: ' ANA@Ejemplo.CL ', source: ' instagram ' });
    expect(res.ok).toBe(true);
    if (res.ok) {
      expect(res.value).toEqual({ name: 'Ana', email: 'ana@ejemplo.cl', source: 'instagram' });
    }
  });

  it('pone source en "landing" cuando falta o viene vacío', () => {
    for (const source of [undefined, null, '   ']) {
      const res = validateWaitlistBody({ name: 'Ana', email: 'ana@ejemplo.cl', source });
      expect(res.ok).toBe(true);
      if (res.ok) expect(res.value.source).toBe('landing');
    }
  });

  it('rechaza cuerpos que no son objetos', () => {
    for (const body of [null, undefined, 'texto', 42, []]) {
      const res = validateWaitlistBody(body);
      expect(res.ok).toBe(false);
      if (!res.ok) expect(res.error).toMatch(/objeto JSON/);
    }
  });

  it('rechaza nombres vacíos o demasiado largos', () => {
    expect(validateWaitlistBody({ name: '', email: 'ana@ejemplo.cl' }).ok).toBe(false);
    expect(validateWaitlistBody({ name: '   ', email: 'ana@ejemplo.cl' }).ok).toBe(false);
    expect(validateWaitlistBody({ name: 7, email: 'ana@ejemplo.cl' }).ok).toBe(false);
    expect(validateWaitlistBody({ name: 'a'.repeat(101), email: 'ana@ejemplo.cl' }).ok).toBe(false);
    expect(validateWaitlistBody({ name: 'a'.repeat(100), email: 'ana@ejemplo.cl' }).ok).toBe(true);
  });

  it('rechaza correos inválidos', () => {
    for (const email of ['', 'ana', 'ana@', '@ejemplo.cl', 'ana@ejemplo', 'ana @ejemplo.cl', `${'a'.repeat(200)}@x.cl`]) {
      expect(validateWaitlistBody({ name: 'Ana', email }).ok, `debería rechazar ${email}`).toBe(false);
    }
  });

  it('rechaza source demasiado largo o de otro tipo', () => {
    expect(validateWaitlistBody({ name: 'Ana', email: 'ana@ejemplo.cl', source: 'x'.repeat(51) }).ok).toBe(false);
    expect(validateWaitlistBody({ name: 'Ana', email: 'ana@ejemplo.cl', source: 9 }).ok).toBe(false);
  });
});
