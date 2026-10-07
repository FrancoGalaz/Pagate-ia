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
  FREE_LIFETIME_SCAN_QUOTA,
  PRO_DAILY_QUOTA,
  PRO_DAILY_SCAN_QUOTA,
  dayKeyOf,
  freeQuotaExhaustedMessage,
  freeScanQuotaExhaustedMessage,
  parseAiLimits,
  planOf,
  refundChatQuota,
  refundScanQuota,
  reserveChatQuota,
  reserveScanQuota,
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
      freeLifetimeScanQuota: FREE_LIFETIME_SCAN_QUOTA,
      proDailyScanQuota: PRO_DAILY_SCAN_QUOTA,
      globalDailyCapEnabled: false,
      globalDailyCap: DEFAULT_GLOBAL_DAILY_CAP,
    });
  });

  it('ignora campos malformados en vez de quedarse sin límite', () => {
    const limits = parseAiLimits({
      freeLifetimeQuota: 'muchos',
      proDailyQuota: -4,
      freeLifetimeScanQuota: 'cuarenta',
      proDailyScanQuota: null,
      globalDailyCap: null,
      globalDailyCapEnabled: 'sí',
    });
    expect(limits.freeLifetimeQuota).toBe(FREE_LIFETIME_QUOTA);
    expect(limits.proDailyQuota).toBe(PRO_DAILY_QUOTA);
    expect(limits.freeLifetimeScanQuota).toBe(FREE_LIFETIME_SCAN_QUOTA);
    expect(limits.proDailyScanQuota).toBe(PRO_DAILY_SCAN_QUOTA);
    expect(limits.globalDailyCap).toBe(DEFAULT_GLOBAL_DAILY_CAP);
    // Solo el booleano exacto `true` activa el tope: un string no lo activa.
    expect(limits.globalDailyCapEnabled).toBe(false);
  });

  it('respeta los valores que ponga el dueño', () => {
    const limits = parseAiLimits({
      freeLifetimeQuota: 5,
      proDailyQuota: 50,
      freeLifetimeScanQuota: 7,
      proDailyScanQuota: 70,
      globalDailyCapEnabled: true,
      globalDailyCap: 10,
    });
    expect(limits).toEqual({
      freeLifetimeQuota: 5,
      proDailyQuota: 50,
      freeLifetimeScanQuota: 7,
      proDailyScanQuota: 70,
      globalDailyCapEnabled: true,
      globalDailyCap: 10,
    });
  });

  it('las dos cuotas se configuran por separado', () => {
    // Bajar la del lector no puede bajar la del asistente, ni al revés: son
    // dos gastos distintos y el dueño los mueve por separado.
    const soloScan = parseAiLimits({ freeLifetimeScanQuota: 1 });
    expect(soloScan.freeLifetimeScanQuota).toBe(1);
    expect(soloScan.freeLifetimeQuota).toBe(FREE_LIFETIME_QUOTA);

    const soloChat = parseAiLimits({ freeLifetimeQuota: 1 });
    expect(soloChat.freeLifetimeQuota).toBe(1);
    expect(soloChat.freeLifetimeScanQuota).toBe(FREE_LIFETIME_SCAN_QUOTA);
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

    // ...pero el de por vida no, así que el siguiente mensaje se rechaza con el
    // texto exacto que lee el usuario.
    await expect(reserveChatQuota(db, UID)).rejects.toThrow(
      freeQuotaExhaustedMessage(FREE_LIFETIME_QUOTA),
    );
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

  it('no borra los demás campos de meta/usage al reservar', async () => {
    const db = adminDb();
    await seedProfile('free');
    // Campo ajeno a la cuota que ya vivía en el documento. La reserva escribía
    // con `set` sin merge, así que lo borraba en cada mensaje del asistente.
    await db.doc(`users/${UID}/meta/usage`).set({ campoAjeno: 'no me borres', chatCountLifetime: 2 });

    const res = await reserveChatQuota(db, UID);
    expect(res.usedLifetime).toBe(3);
    expect(await usage()).toMatchObject({
      campoAjeno: 'no me borres',
      chatCountLifetime: 3,
      dayKey: res.dayKey,
    });
  });

  it('respeta una cuota free reconfigurada por el dueño sin desplegar', async () => {
    const db = adminDb();
    await seedProfile('free');
    await db.doc(AI_CONFIG_DOC).set({ freeLifetimeQuota: 1 });

    await expect(reserveChatQuota(db, UID)).resolves.toMatchObject({ usedLifetime: 1 });
    // El texto se arma con el valor reconfigurado, no con el default.
    await expect(reserveChatQuota(db, UID)).rejects.toThrow(freeQuotaExhaustedMessage(1));
  });
});

/**
 * El texto que lee el usuario cuando se le acaban los mensajes.
 *
 * POR QUÉ TIENE SUS PROPIOS TESTS: el anterior decía «Cambia a Pro para seguir
 * conversando con el asistente» y no hay ningún plan Pro que se pueda comprar
 * (no existe `in_app_purchase` ni integración de facturación en el proyecto).
 * Era falso, y además anunciar dentro de la app un plan de pago que no pasa por
 * la facturación de Google Play incumple su política. Estos tests son el candado
 * para que no vuelva a aparecer una promesa así.
 */
describe('freeQuotaExhaustedMessage', () => {
  it('no ofrece ningún plan de pago ni invita a comprar nada', () => {
    const msg = freeQuotaExhaustedMessage(FREE_LIFETIME_QUOTA).toLowerCase();
    // Se compara palabra por palabra, y no con una expresión regular con
    // límites de palabra, para que 'pro' no se dé por encontrado dentro de
    // 'propio' o 'próximo'.
    const palabras = msg.split(/[^a-záéíóúñ]+/).filter(Boolean);
    expect(palabras).not.toContain('pro');
    for (const prohibido of ['plan', 'planes', 'pago', 'pagar', 'paga', 'comprar', 'compra', 'premium']) {
      expect(palabras, `el mensaje no debe decir "${prohibido}"`).not.toContain(prohibido);
    }
    for (const raiz of ['suscri', 'mejora', 'upgrade']) {
      expect(msg, `el mensaje no debe contener "${raiz}"`).not.toContain(raiz);
    }
  });

  it('dice la verdad sobre la cuota: es un total y no se renueva', () => {
    const msg = freeQuotaExhaustedMessage(25);
    expect(msg).toContain('25 en total');
    expect(msg).toMatch(/no por día/i);
    expect(msg).toMatch(/no se renuevan/i);
    // Y no manda a volver mañana, que es lo que sí vale para el plan pro.
    expect(msg).not.toMatch(/vuelve mañana/i);
  });

  it('se lee bien con cualquier cuota que ponga el dueño, incluido 1', () => {
    // `system/aiConfig.freeLifetimeQuota` lo edita el dueño sin desplegar, así
    // que la frase no puede depender de que el número sea plural.
    expect(freeQuotaExhaustedMessage(1)).toContain('incluye 1 en total');
    expect(freeQuotaExhaustedMessage(0)).toContain('incluye 0 en total');
    expect(freeQuotaExhaustedMessage(300)).toContain('incluye 300 en total');
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

/**
 * La cuota del lector de boletas.
 *
 * ---------------------------------------------------------------------------
 * EL TEST QUE IMPIDE QUE LA SEPARACIÓN SE ROMPA EN SILENCIO
 * ---------------------------------------------------------------------------
 * Las dos cuotas viven en el MISMO documento (`users/{uid}/meta/usage`) y
 * comparten el MISMO campo `dayKey`. Es justo la clase de vecindad en la que un
 * `set` sin merge, o un reinicio de día mal puesto, borra o avala el contador
 * del vecino sin que nada falle a la vista: el usuario simplemente se queda sin
 * asistente después de fotografiar unas boletas, o al revés.
 *
 * Por eso aquí no se comprueba solo que la cuota del lector funcione, sino que
 * gastarla entera deje la del chat EXACTAMENTE como estaba, y que el cambio de
 * día no avale el contador de ayer de la otra.
 */
describe('reserveScanQuota', () => {
  beforeEach(async () => {
    const db = adminDb();
    await wipeUser(db, UID);
    await wipeAiSystem(db);
  });

  async function scanCalls(dayKey: string): Promise<number> {
    const snap = await adminDb().doc(AI_USAGE_DOC).collection(AI_USAGE_DAYS).doc(dayKey).get();
    const value = snap.data()?.scanCalls;
    return typeof value === 'number' ? value : 0;
  }

  it('cuenta en sus propios campos, no en los del chat', async () => {
    const db = adminDb();
    await seedProfile('free');

    const res = await reserveScanQuota(db, UID);

    expect(res.usedLifetime).toBe(1);
    const u = await usage();
    expect(u).toMatchObject({ dayKey: res.dayKey, scanCountDay: 1, scanCountLifetime: 1 });
    // Los del chat ni aparecen.
    expect(u?.chatCountDay).toBeUndefined();
    expect(u?.chatCountLifetime).toBeUndefined();
    // Y el contador global del día va en su campo.
    expect(await scanCalls(res.dayKey)).toBe(1);
    expect(await globalCalls(res.dayKey)).toBe(0);
  });

  it('GASTAR TODA la cuota de escaneo deja intacta la de chat', async () => {
    const db = adminDb();
    await seedProfile('free');
    await db.doc(AI_CONFIG_DOC).set({ freeLifetimeScanQuota: 3 });

    for (let i = 0; i < 3; i++) await reserveScanQuota(db, UID);
    await expect(reserveScanQuota(db, UID)).rejects.toThrow(freeScanQuotaExhaustedMessage(3));

    // Y el asistente sigue entero: sus mensajes sin tocar.
    const res = await reserveChatQuota(db, UID);
    expect(res.usedLifetime).toBe(1);
    expect(await usage()).toMatchObject({ scanCountLifetime: 3, chatCountLifetime: 1 });
  });

  it('GASTAR TODA la cuota de chat deja intacta la del lector', async () => {
    const db = adminDb();
    await seedProfile('free');
    await db.doc(AI_CONFIG_DOC).set({ freeLifetimeQuota: 2 });

    await reserveChatQuota(db, UID);
    await reserveChatQuota(db, UID);
    await expect(reserveChatQuota(db, UID)).rejects.toThrow(freeQuotaExhaustedMessage(2));

    await expect(reserveScanQuota(db, UID)).resolves.toMatchObject({ usedLifetime: 1 });
  });

  it('plan free: corta en la lectura 41 y no se reinicia al día siguiente', async () => {
    const db = adminDb();
    await seedProfile('free');
    await db
      .doc(`users/${UID}/meta/usage`)
      .set({ dayKey: '2000-01-01', scanCountDay: 999, scanCountLifetime: FREE_LIFETIME_SCAN_QUOTA - 1 });

    const ok = await reserveScanQuota(db, UID);
    expect(ok.usedLifetime).toBe(FREE_LIFETIME_SCAN_QUOTA);
    // El diario se reinició porque cambió el día...
    expect(ok.usedDay).toBe(1);
    // ...pero el de por vida no.
    await expect(reserveScanQuota(db, UID)).rejects.toThrow(
      freeScanQuotaExhaustedMessage(FREE_LIFETIME_SCAN_QUOTA),
    );
  });

  it('plan pro: la cuota de lecturas es diaria y el histórico no le afecta', async () => {
    const db = adminDb();
    await seedProfile('pro');
    await db.doc(`users/${UID}/meta/usage`).set({ dayKey: dayKeyOf(), scanCountLifetime: 99_999, scanCountDay: 0 });

    await expect(reserveScanQuota(db, UID)).resolves.toMatchObject({ plan: 'pro', usedDay: 1 });

    await db
      .doc(`users/${UID}/meta/usage`)
      .set({ dayKey: dayKeyOf(), scanCountDay: PRO_DAILY_SCAN_QUOTA }, { merge: true });
    await expect(reserveScanQuota(db, UID)).rejects.toThrow(/lecturas de boleta del día/i);
  });

  /**
   * LA TRAMPA DEL `dayKey` COMPARTIDO.
   *
   * Hay un solo campo `dayKey` para los dos contadores diarios, así que
   * escribirlo por una de las dos cuotas AVALA el contador de la otra. Si al
   * cambiar el día una lectura escribiera `{ dayKey: hoy, scanCountDay: 1 }`
   * sin tocar `chatCountDay`, el `chatCountDay` de AYER pasaría a leerse como
   * el de HOY y un usuario pro se quedaría sin asistente sin haber escrito un
   * solo mensaje.
   */
  it('al cambiar el día, una lectura reinicia también el contador diario del chat', async () => {
    const db = adminDb();
    await seedProfile('pro');
    // Ayer agotó su cuota diaria de mensajes.
    await db
      .doc(`users/${UID}/meta/usage`)
      .set({ dayKey: '2000-01-01', chatCountDay: PRO_DAILY_QUOTA, chatCountLifetime: PRO_DAILY_QUOTA });

    // Hoy lee una boleta: eso escribe el `dayKey` de hoy.
    await reserveScanQuota(db, UID);
    expect(await usage()).toMatchObject({ dayKey: dayKeyOf(), scanCountDay: 1, chatCountDay: 0 });

    // Y el asistente sigue disponible, que es lo que estaba en juego.
    await expect(reserveChatQuota(db, UID)).resolves.toMatchObject({ usedDay: 1 });
  });

  it('al cambiar el día, un mensaje reinicia también el contador diario del lector', async () => {
    const db = adminDb();
    await seedProfile('pro');
    await db
      .doc(`users/${UID}/meta/usage`)
      .set({ dayKey: '2000-01-01', scanCountDay: PRO_DAILY_SCAN_QUOTA, scanCountLifetime: 5 });

    await reserveChatQuota(db, UID);
    expect(await usage()).toMatchObject({ dayKey: dayKeyOf(), chatCountDay: 1, scanCountDay: 0 });

    await expect(reserveScanQuota(db, UID)).resolves.toMatchObject({ usedDay: 1 });
  });

  it('DENTRO del mismo día, reservar una cuota no pisa el contador de la otra', async () => {
    const db = adminDb();
    await seedProfile('pro');
    const dayKey = dayKeyOf();
    await db.doc(`users/${UID}/meta/usage`).set({ dayKey, chatCountDay: 4, scanCountDay: 6 });

    await reserveScanQuota(db, UID);
    expect(await usage()).toMatchObject({ chatCountDay: 4, scanCountDay: 7 });

    await reserveChatQuota(db, UID);
    expect(await usage()).toMatchObject({ chatCountDay: 5, scanCountDay: 7 });
  });

  it('no borra los demás campos de meta/usage al reservar', async () => {
    const db = adminDb();
    await seedProfile('free');
    await db.doc(`users/${UID}/meta/usage`).set({ campoAjeno: 'no me borres', scanCountLifetime: 2 });

    const res = await reserveScanQuota(db, UID);
    expect(res.usedLifetime).toBe(3);
    expect(await usage()).toMatchObject({
      campoAjeno: 'no me borres',
      scanCountLifetime: 3,
      dayKey: res.dayKey,
    });
  });

  /**
   * EL TOPE GLOBAL ES EL FRENO DE GASTO DEL DUEÑO, Y EL GASTO ES LA SUMA.
   *
   * Si contara solo `calls`, el lector sería un camino para gastar sin pasar
   * por el freno de mano: exactamente lo que el tope existe para evitar.
   */
  it('el tope global cuenta los mensajes MÁS las lecturas', async () => {
    const db = adminDb();
    await seedProfile('free');
    const dayKey = dayKeyOf();
    await db.doc(AI_CONFIG_DOC).set({ globalDailyCapEnabled: true, globalDailyCap: 5 });

    // Tres mensajes y dos lecturas ya son los cinco del tope.
    await db.doc(AI_USAGE_DOC).collection(AI_USAGE_DAYS).doc(dayKey).set({ calls: 3, scanCalls: 2 });

    await expect(reserveScanQuota(db, UID)).rejects.toThrow(/lector de boletas/i);
    await expect(reserveChatQuota(db, UID)).rejects.toThrow(/El asistente está temporalmente/i);

    // Con el tope por encima de la suma, las dos pasan.
    await db.doc(AI_CONFIG_DOC).set({ globalDailyCapEnabled: true, globalDailyCap: 7 });
    await expect(reserveScanQuota(db, UID)).resolves.toMatchObject({ plan: 'free' });
    await expect(reserveChatQuota(db, UID)).resolves.toMatchObject({ plan: 'free' });
    // Y cada una sumó en su propio campo.
    expect(await scanCalls(dayKey)).toBe(3);
    expect(await globalCalls(dayKey)).toBe(4);
  });

  it('el mensaje del tope global del lector dice que la lista local sigue sirviendo', async () => {
    const db = adminDb();
    await seedProfile('free');
    await db.doc(AI_CONFIG_DOC).set({ globalDailyCapEnabled: true, globalDailyCap: 0 });

    await expect(reserveScanQuota(db, UID)).rejects.toThrow(/ordenó tu teléfono/i);
  });
});

/**
 * El texto que lee el usuario cuando se le acaban las lecturas.
 *
 * Mismo candado que `freeQuotaExhaustedMessage`: no puede ofrecer ningún plan
 * de pago, porque no existe ninguno que comprar y anunciarlo dentro de la app
 * incumpliría la política de pagos de Google Play.
 */
describe('freeScanQuotaExhaustedMessage', () => {
  it('no ofrece ningún plan de pago ni invita a comprar nada', () => {
    const msg = freeScanQuotaExhaustedMessage(FREE_LIFETIME_SCAN_QUOTA).toLowerCase();
    const palabras = msg.split(/[^a-záéíóúñ]+/).filter(Boolean);
    expect(palabras).not.toContain('pro');
    for (const prohibido of ['plan', 'planes', 'pago', 'pagar', 'paga', 'comprar', 'compra', 'premium']) {
      expect(palabras, `el mensaje no debe decir "${prohibido}"`).not.toContain(prohibido);
    }
    for (const raiz of ['suscri', 'upgrade']) {
      expect(msg, `el mensaje no debe contener "${raiz}"`).not.toContain(raiz);
    }
  });

  it('dice la verdad: la cuota es un total, no se renueva, y la lectura NO se perdió', () => {
    const msg = freeScanQuotaExhaustedMessage(40);
    expect(msg).toContain('40 en total');
    expect(msg).toMatch(/no por día/i);
    expect(msg).toMatch(/no se renuevan/i);
    // No manda a volver mañana (eso solo vale para el plan pro) y sí explica
    // que la lista que tiene en pantalla la ordenó el teléfono.
    expect(msg).not.toMatch(/vuelve mañana/i);
    expect(msg).toMatch(/ordenó tu teléfono/i);
  });

  it('se lee bien con cualquier cuota que ponga el dueño, incluido 1', () => {
    expect(freeScanQuotaExhaustedMessage(1)).toContain('incluye 1 en total');
    expect(freeScanQuotaExhaustedMessage(0)).toContain('incluye 0 en total');
  });
});

describe('refundScanQuota', () => {
  beforeEach(async () => {
    const db = adminDb();
    await wipeUser(db, UID);
    await wipeAiSystem(db);
  });

  it('devuelve la lectura reservada y deja los contadores como estaban', async () => {
    const db = adminDb();
    await seedProfile('free');

    const res = await reserveScanQuota(db, UID);
    await refundScanQuota(db, UID, res.dayKey);

    expect(await usage()).toMatchObject({ scanCountDay: 0, scanCountLifetime: 0 });
    const snap = await db.doc(AI_USAGE_DOC).collection(AI_USAGE_DAYS).doc(res.dayKey).get();
    expect(snap.data()?.scanCalls).toBe(0);
  });

  it('devolver una lectura NO devuelve un mensaje del asistente', async () => {
    const db = adminDb();
    await seedProfile('free');

    const chat = await reserveChatQuota(db, UID);
    const scan = await reserveScanQuota(db, UID);
    expect(scan.dayKey).toBe(chat.dayKey);

    await refundScanQuota(db, UID, scan.dayKey);

    // La lectura volvió; el mensaje del asistente sigue gastado.
    expect(await usage()).toMatchObject({
      scanCountLifetime: 0,
      scanCountDay: 0,
      chatCountLifetime: 1,
      chatCountDay: 1,
    });
    expect(await globalCalls(chat.dayKey)).toBe(1);
  });

  it('un fallo del proveedor no le gasta al usuario su última lectura', async () => {
    const db = adminDb();
    await seedProfile('free');
    await db.doc(AI_CONFIG_DOC).set({ freeLifetimeScanQuota: 1 });

    const res = await reserveScanQuota(db, UID);
    await refundScanQuota(db, UID, res.dayKey);

    await expect(reserveScanQuota(db, UID)).resolves.toMatchObject({ usedLifetime: 1 });
  });

  it('nunca deja los contadores en negativo', async () => {
    const db = adminDb();
    const dayKey = dayKeyOf();
    await db.doc(`users/${UID}/meta/usage`).set({ dayKey, scanCountDay: 0, scanCountLifetime: 0 });

    await refundScanQuota(db, UID, dayKey);
    expect(await usage()).toMatchObject({ scanCountDay: 0, scanCountLifetime: 0 });
  });

  it('no descuenta del día si el día ya cambió', async () => {
    const db = adminDb();
    await db.doc(`users/${UID}/meta/usage`).set({ dayKey: dayKeyOf(), scanCountDay: 7, scanCountLifetime: 7 });

    await refundScanQuota(db, UID, '2000-01-01');
    expect(await usage()).toMatchObject({ scanCountDay: 7, scanCountLifetime: 6 });
  });
});
