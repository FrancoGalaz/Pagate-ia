/**
 * Endpoint HTTP `waitlist`: alta en la lista de espera desde la landing.
 *
 * Lo consume `landing/src/services/waitlist-service.ts`.
 *
 * Contrato: `POST { name, email, source? }` → `200 {ok:true}` |
 * `400/403/405/429/500 {error}`.
 */

import { onRequest, type Request } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { createHash } from 'node:crypto';
import type { Response } from 'express';
import { REGION, waitlistOrigins } from './config';

const RATE_WINDOW_MS = 60 * 60 * 1000; // 1 hora
const RATE_MAX_PER_WINDOW = 5;
const RATE_MAX_TRACKED_IPS = 10_000;

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const NAME_MAX = 100;
const EMAIL_MAX = 200;
const SOURCE_MAX = 50;

/** Límite simple por IP en memoria de la instancia (se pierde al reiniciar; suficiente para una landing). */
const hitsByIp = new Map<string, number[]>();

export function isRateLimited(ip: string, now: number = Date.now()): boolean {
  const since = now - RATE_WINDOW_MS;
  const recent = (hitsByIp.get(ip) ?? []).filter((t) => t > since);
  if (recent.length >= RATE_MAX_PER_WINDOW) {
    hitsByIp.set(ip, recent);
    return true;
  }
  recent.push(now);
  hitsByIp.set(ip, recent);

  if (hitsByIp.size > RATE_MAX_TRACKED_IPS) {
    for (const [key, times] of hitsByIp) {
      if (!times.some((t) => t > since)) hitsByIp.delete(key);
    }
  }
  return false;
}

/** Solo para los tests: vacía el mapa del límite por IP. */
export function resetRateLimit(): void {
  hitsByIp.clear();
}

/**
 * IP del cliente a efectos del límite de tasa (S-04).
 *
 * Antes se tomaba el PRIMER valor de `X-Forwarded-For`, que es exactamente el
 * que controla quien llama: con `curl -H 'X-Forwarded-For: 1.2.3.4'` y un valor
 * distinto en cada petición, `isRateLimited` nunca disparaba porque el mapa se
 * indexaba por esa cadena inventada.
 *
 * Se toma el ÚLTIMO salto. La infraestructura de Cloud Run (donde corren las
 * funciones de 2ª generación) AÑADE la IP real al final de la cabecera cuando el
 * cliente ya mandó una, así que el último elemento es el único valor de la lista
 * que el cliente no puede escribir.
 *
 * Aviso para quien ponga un balanceador de carga HTTP(S) propio delante de esta
 * función: en ese caso el balanceador añade `IP-del-cliente, IP-del-balanceador`
 * y el último elemento pasa a ser la IP del balanceador, igual para todo el
 * mundo. Si eso llega a pasar, hay que tomar el penúltimo.
 */
export function clientIp(req: Request): string {
  const forwarded = req.headers['x-forwarded-for'];
  const raw = Array.isArray(forwarded) ? forwarded.join(',') : forwarded;
  if (typeof raw === 'string' && raw.trim()) {
    const hops = raw
      .split(',')
      .map((h) => h.trim())
      .filter((h) => h.length > 0);
    if (hops.length > 0) return hops[hops.length - 1];
  }
  return req.ip ?? 'unknown';
}

/**
 * Id determinista del documento: sha256 del correo ya normalizado.
 *
 * Antes se usaba `.add()`, que genera un id nuevo en cada llamada: el mismo
 * correo podía entrar mil veces. Con un id derivado del correo, reenviar el
 * formulario es idempotente.
 */
export function waitlistDocId(normalizedEmail: string): string {
  return createHash('sha256').update(normalizedEmail, 'utf8').digest('hex');
}

interface WaitlistInput {
  name: string;
  email: string;
  source: string;
}

export function validateWaitlistBody(body: unknown): { ok: true; value: WaitlistInput } | { ok: false; error: string } {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    return { ok: false, error: 'El cuerpo debe ser un objeto JSON.' };
  }
  const { name, email, source } = body as Record<string, unknown>;

  if (typeof name !== 'string' || name.trim().length < 1 || name.trim().length > NAME_MAX) {
    return { ok: false, error: `El nombre es obligatorio y debe tener entre 1 y ${NAME_MAX} caracteres.` };
  }
  if (typeof email !== 'string' || email.trim().length > EMAIL_MAX || !EMAIL_RE.test(email.trim())) {
    return { ok: false, error: 'El correo no es válido.' };
  }
  if (source !== undefined && source !== null) {
    if (typeof source !== 'string' || source.length > SOURCE_MAX) {
      return { ok: false, error: `El campo source debe ser un texto de hasta ${SOURCE_MAX} caracteres.` };
    }
  }

  return {
    ok: true,
    value: {
      name: name.trim(),
      email: email.trim().toLowerCase(),
      source: typeof source === 'string' && source.trim() ? source.trim() : 'landing',
    },
  };
}

function applyCors(req: Request, res: Response): boolean {
  const origin = req.headers.origin;
  if (typeof origin !== 'string' || !waitlistOrigins().has(origin)) {
    return false;
  }
  res.set('Access-Control-Allow-Origin', origin);
  res.set('Vary', 'Origin');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  res.set('Access-Control-Max-Age', '3600');
  return true;
}

export const waitlist = onRequest(
  {
    region: REGION,
    memory: '256MiB',
    timeoutSeconds: 15,
    maxInstances: 2,
  },
  async (req, res) => {
    const originAllowed = applyCors(req, res);

    if (req.method === 'OPTIONS') {
      res.status(originAllowed ? 204 : 403).send('');
      return;
    }
    if (req.method !== 'POST') {
      res.set('Allow', 'POST, OPTIONS');
      res.status(405).json({ error: 'Método no permitido.' });
      return;
    }
    // Si viene un Origin y no está en la lista, se rechaza. Sin Origin (curl, server-to-server) se acepta.
    if (typeof req.headers.origin === 'string' && !originAllowed) {
      res.status(403).json({ error: 'Origen no permitido.' });
      return;
    }

    const ip = clientIp(req);
    if (isRateLimited(ip)) {
      res.status(429).json({ error: 'Demasiadas solicitudes. Intenta de nuevo en una hora.' });
      return;
    }

    let body: unknown = req.body;
    if (typeof body === 'string') {
      try {
        body = JSON.parse(body);
      } catch {
        res.status(400).json({ error: 'JSON inválido.' });
        return;
      }
    }

    const parsed = validateWaitlistBody(body);
    if (!parsed.ok) {
      res.status(400).json({ error: parsed.error });
      return;
    }

    try {
      const db = getFirestore();
      const ref = db.collection('waitlist').doc(waitlistDocId(parsed.value.email));
      // Transacción para que `createdAt` sea la PRIMERA vez y no se sobrescriba
      // en cada reenvío, y para contar los reenvíos sin perder el original.
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (snap.exists) {
          tx.set(
            ref,
            {
              name: parsed.value.name,
              source: parsed.value.source,
              updatedAt: FieldValue.serverTimestamp(),
              submissions: FieldValue.increment(1),
            },
            { merge: true },
          );
        } else {
          tx.set(ref, {
            ...parsed.value,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
            submissions: 1,
          });
        }
      });
      res.status(200).json({ ok: true });
    } catch (err) {
      logger.error('No se pudo guardar en waitlist', { err: String(err) });
      res.status(500).json({ error: 'No se pudo registrar. Intenta más tarde.' });
    }
  },
);
