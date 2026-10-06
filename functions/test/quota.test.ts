/**
 * Tests de la cuota del asistente (S-06 y límite de IA) contra el emulador.
 *
 * Cubren: la clave del día en hora de Chile, la cuota de por vida del plan free,
 * la cuota diaria del plan pro, el tope global con interruptor y la devolución
 * de cuota cuando la llamada falla.
 */

import { beforeEach, describe, expect, it } from 'vitest';
import { FieldValue } from 'firebase-admin/firestore';
import {
  AI_CONFIG_DOC,
  AI_USAGE_DAYS,
  AI_USAGE_DOC,
  DEFAULT_GLOBAL_DAILY_CAP,
  FREE_LIFETIME_QUOTA,
  PRO_DAILY_QUOTA,
  dayKeyOf,
  parseAiLimits,
  planOf,
  refundChatQuota,
  reserveChatQuota,
} from '../src/quota';
import { adminDb, wipeAiSystem, wipeUser } from './helpers/admin';

const UID = 'cuotas';

async function seedProfile(plan: 'free' | 'pro'): Promise<void> {
  const db = adminDb();
  await db.doc(`users/${UID}`).set({
    name: 'Cuota',
    currency: 'CLP',
    plan,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

async function usage(): Promise<Record<string, unknown> | undefined> {
  return (await adminDb().doc(`users/${UID}/meta/usage`).get()).data();
}

async function globalCalls(dayKey: string): Promise<number> {
  const snap = await adminDb().doc(AI_USAGE_DOC).collection(AI_USAGE_DAYS).doc(dayKey).get();
  const value = snap.data()?.calls;
  return typeof value === 'number' ? value : 0;
}

describe('dayKeyOf', () => {
  it('usa la zona de Chile, no UTC', () => {
    // 02:30 UTC del 10 de marzo son las 23:30 del 9 de marzo en Santiago
    // (horario de verano, UTC-3). En UTC la cuota se habría reiniciado ya.
    const verano = new Date('2026-03-10T02:30:00Z');
    expect(dayKeyOf(verano)).toBe('2026-03-09');
    expect(verano.toISOString().slice(0, 10)).toBe('2026-03-10');

    // 02:30 UTC del 1 de julio son las 22:30 del 30 de junio (invierno, UTC-4).
    const invierno = new Date('2026-07-01T02:30:00Z');
    expect(dayKeyOf(invierno)).toBe('2026-06-30');
    expect(invierno.toISOString().slice(0, 10)).toBe('2026-07-01');
  });

  it('devuelve el formato yyyy-MM-dd', () => {
    expect(dayKeyOf(new Date('2026-09-29T15:00:00Z'))).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it('cambia de día justo al pasar la medianoche de Santiago', () => {
    // 03:30Z y 02:30Z del 10 de marzo caen a los dos lados de la medianoche
    // local del horario de verano chileno.
    expect(dayKeyOf(new Date('2026-03-10T02:59:00Z'))).toBe('2026-03-09');
    expect(dayKeyOf(new Date('2026-03-10T03:01:00Z'))).toBe('2026-03-10');
  });
});

describe('parseAiLimits', () => {
  it('cae a los valores por defecto sin documento', () => {
    expect(parseAiLimits(undefined)).toEqual({
      freeLifetimeQuota: FREE_LIFETIME_QUOTA,
      proDailyQuota: PRO_DAILY_QUOTA,
      globalDailyCapEnabled: false,
      globalDailyCap: DEFAULT_GLOBAL_DAILY_CAP,
    });
  });

  it('ignora campos malformados en vez de quedarse sin límite', () => {
    const limits = parseAiLimits({
      freeLifetimeQuota: 'muchos',
      proDailyQuota: -4,
      globalDailyCap: null,
      globalDailyCapEnabled: 'sí',
    });
    expect(limits.freeLifetimeQuota).toBe(FREE_LIFETIME_QUOTA);
    expect(limits.proDailyQuota).toBe(PRO_DAILY_QUOTA);
    expect(limits.globalDailyCap).toBe(DEFAULT_GLOBAL_DAILY_CAP);
    // Solo el booleano exacto `true` activa el tope: un string no lo activa.
    expect(limits.globalDailyCapEnabled).toBe(false);
  });

  it('respeta los valores que ponga el dueño', () => {
    const limits = parseAiLimits({ freeLifetimeQuota: 5, proDailyQuota: 50, globalDailyCapEnabled: true, globalDailyCap: 10 });
    expect(limits).toEqual({
      freeLifetimeQuota: 5,
      proDailyQuota: 50,
      globalDailyCapEnabled: true,
      globalDailyCap: 10,
    });
  });
});

describe('planOf', () => {
  it('solo reconoce pro escrito exactamente', () => {
    expect(planOf({ plan: 'pro' })).toBe('pro');
    expect(planOf({ plan: 'PRO' })).toBe('free');
    expect(planOf({})).toBe('free');
    expect(planOf(undefined)).toBe('free');
  });
});

describe('reserveChatQuota', () => {
  beforeEach(async () => {
    const db = adminDb();
    await wipeUser(db, UID);
    await wipeAiSystem(db);
  });

  it('cuenta los dos contadores en la primera llamada', async () => {
    const db = adminDb();
    await seedProfile('free');
    const res = await reserveChatQuota(db, UID);

    expect(res.plan).toBe('free');
    expect(res.usedLifetime).toBe(1);
    expect(res.usedDay).toBe(1);
    expect(await usage()).toMatchObject({ dayKey: res.dayKey, chatCountDay: 1, chatCountLifetime: 1 });
    expect(await globalCalls(res.dayKey)).toBe(1);
  });

  it('plan free: corta en la llamada 26 y NO se reinicia al día siguiente', async () => {
    const db = adminDb();
    await seedProfile('free');
    // Ya gastó 24 de los 25 mensajes de por vida, con la clave de ayer para
    // demostrar que el contador de por vida no depende del día.
    await db.doc(`users/${UID}/meta/usage`).set({ dayKey: '2000-01-01', chatCountDay: 999, chatCountLifetime: 24 });

    const ok = await reserveChatQuota(db, UID);
    expect(ok.usedLifetime).toBe(FREE_LIFETIME_QUOTA);
    // El contador diario se reinició porque la clave del día cambió...
    expect(ok.usedDay).toBe(1);

    // ...pero el de por vida no, así que el siguiente mensaje se rechaza.
    await expect(reserveChatQuota(db, UID)).rejects.toThrow(/plan gratuito/i);
    expect(await usage()).toMatchObject({ chatCountLifetime: FREE_LIFETIME_QUOTA });
  });

  it('plan pro: la cuota es diaria y el contador de por vida no le afecta', async () => {
    const db = adminDb();
    await seedProfile('pro');
    await db.doc(`users/${UID}/meta/usage`).set({ dayKey: '2000-01-01', chatCountDay: 5, chatCountLifetime: 99_999 });

    // Con 99.999 mensajes históricos, un pro sigue pudiendo escribir.
    const ok = await reserveChatQuota(db, UID);
    expect(ok.plan).toBe('pro');
    expect(ok.usedDay).toBe(1);

    // Al llegar al tope del día, se corta.
    await db.doc(`users/${UID}/meta/usage`).set(
      { dayKey: dayKeyOf(), chatCountDay: PRO_DAILY_QUOTA },
      { merge: true },
    );
    await expect(reserveChatQuota(db, UID)).rejects.toThrow(/límite de 300 mensajes del día/i);
  });

  it('el tope global corta a todo el mundo, y solo cuando está activado', async () => {
    const db = adminDb();
    await seedProfile('free');
    const dayKey = dayKeyOf();

    // Desactivado: aunque el contador global esté muy por encima, pasa.
    await db.doc(AI_CONFIG_DOC).set({ globalDailyCapEnabled: false, globalDailyCap: 1 });
    await db.doc(AI_USAGE_DOC).collection(AI_USAGE_DAYS).doc(dayKey).set({ calls: 500 });
    await expect(reserveChatQuota(db, UID)).resolves.toMatchObject({ plan: 'free' });

    // Activado: corta, y el mensaje habla del servicio, no de la cuota del usuario.
    await db.doc(AI_CONFIG_DOC).set({ globalDailyCapEnabled: true, globalDailyCap: 1 });
    await expect(reserveChatQuota(db, UID)).rejects.toThrow(/tope de uso del día/i);
  });

  it('respeta una cuota free reconfigurada por el dueño sin desplegar', async () => {
    const db = adminDb();
    await seedProfile('free');
    await db.doc(AI_CONFIG_DOC).set({ freeLifetimeQuota: 1 });

    await expect(reserveChatQuota(db, UID)).resolves.toMatchObject({ usedLifetime: 1 });
    await expect(reserveChatQuota(db, UID)).rejects.toThrow(/1 mensajes incluidos/i);
  });
});

describe('refundChatQuota', () => {
  beforeEach(async () => {
    const db = adminDb();
    await wipeUser(db, UID);
    await wipeAiSystem(db);
  });

  it('devuelve el mensaje reservado y deja los contadores como estaban', async () => {
    const db = adminDb();
    await seedProfile('free');

    const res = await reserveChatQuota(db, UID);
    expect(await usage()).toMatchObject({ chatCountDay: 1, chatCountLifetime: 1 });
    expect(await globalCalls(res.dayKey)).toBe(1);

    await refundChatQuota(db, UID, res.dayKey);
    expect(await usage()).toMatchObject({ chatCountDay: 0, chatCountLifetime: 0 });
    expect(await globalCalls(res.dayKey)).toBe(0);
  });

  it('un fallo de OpenRouter no le gasta al usuario su último mensaje', async () => {
    const db = adminDb();
    await seedProfile('free');
    await db.doc(AI_CONFIG_DOC).set({ freeLifetimeQuota: 1 });

    // Gasta el único mensaje... y la llamada "falla": se devuelve.
    const res = await reserveChatQuota(db, UID);
    await refundChatQuota(db, UID, res.dayKey);

    // Sigue pudiendo escribir.
    await expect(reserveChatQuota(db, UID)).resolves.toMatchObject({ usedLifetime: 1 });
  });

  it('nunca deja los contadores en negativo', async () => {
    const db = adminDb();
    await seedProfile('free');
    const dayKey = dayKeyOf();
    await db.doc(`users/${UID}/meta/usage`).set({ dayKey, chatCountDay: 0, chatCountLifetime: 0 });

    await refundChatQuota(db, UID, dayKey);
    expect(await usage()).toMatchObject({ chatCountDay: 0, chatCountLifetime: 0 });
    expect(await globalCalls(dayKey)).toBe(0);
  });

  it('no descuenta del día si el día ya cambió', async () => {
    const db = adminDb();
    await db.doc(`users/${UID}/meta/usage`).set({ dayKey: dayKeyOf(), chatCountDay: 7, chatCountLifetime: 7 });

    // La reserva se hizo "ayer": solo se devuelve el contador de por vida.
    await refundChatQuota(db, UID, '2000-01-01');
    expect(await usage()).toMatchObject({ chatCountDay: 7, chatCountLifetime: 6 });
  });
});
