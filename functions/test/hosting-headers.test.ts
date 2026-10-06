/**
 * Propósito: impedir que una cabecera de seguridad de `firebase.json` vuelva a
 * romper el inicio de sesión con Google en la web.
 *
 * EL PROBLEMA QUE ESTE TEST VIGILA
 * --------------------------------
 * El mismo sitio de hosting sirve `pagate-17211.web.app` y
 * `pagate-17211.firebaseapp.com`, y el segundo es el `authDomain` del proyecto.
 * El SDK de Auth, que es lo que usa `signInWithPopup` por debajo (también en
 * Flutter web), METE EN UN IFRAME la ruta `/__/auth/iframe` de ese authDomain
 * para recibir los eventos de autenticación.
 *
 * `X-Frame-Options: DENY` sobre `**` se aplicaba también a `/__/**`, así que el
 * navegador se negaba a cargar ese iframe y el login quedaba colgado. Lo mismo
 * haría `frame-ancestors 'none'` de la CSP el día que deje de ser
 * `Report-Only`. Y `SAMEORIGIN` no sirve como arreglo: la página está en
 * `web.app` y el iframe en `firebaseapp.com`, que son orígenes distintos.
 *
 * POR QUÉ LA SOLUCIÓN ES LA QUE ES
 * --------------------------------
 * Una cabecera configurada no se puede "quitar" para una ruta: `headers` solo
 * sabe PONER valores. Así que el único arreglo posible es que el patrón que la
 * pone no llegue a casar con `/__/**`. De ahí los tres `source` del archivo:
 * `/`, `/!(__)` y `/!(__)/**`, que entre los tres cubren todo menos el
 * namespace reservado. El resto de las cabeceras de seguridad (HSTS, nosniff,
 * Referrer-Policy, Permissions-Policy) siguen en `**`, porque ninguna estorba
 * en `/__/`.
 *
 * Este test no despliega nada: comprueba la configuración con el mismo tipo de
 * glob que usa Hosting (`path.matchesGlob`, que es el extglob de Node) sobre una
 * lista de rutas reales de la app.
 */

import { readFileSync } from 'node:fs';
import { matchesGlob, resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

interface HeaderEntry {
  key: string;
  value: string;
}

interface HeaderBlock {
  source: string;
  headers: HeaderEntry[];
}

const config = JSON.parse(
  readFileSync(resolve(__dirname, '../../firebase.json'), 'utf8'),
) as { hosting: { headers: HeaderBlock[] } };

const blocks = config.hosting.headers;

/** Rutas del namespace reservado de Firebase Hosting que NO deben enmarcarse. */
const RESERVED_PATHS = [
  '/__/auth/iframe',
  '/__/auth/iframe.js',
  '/__/auth/handler',
  '/__/firebase/init.js',
];

/** Rutas reales de la app, incluidas las de navegación que reescriben a index.html. */
const APP_PATHS = [
  '/',
  '/index.html',
  '/main.dart.js',
  '/flutter_bootstrap.js',
  '/manifest.json',
  '/dashboard',
  '/assets/fonts/Manrope%5Bwght%5D.ttf',
  '/canvaskit/canvaskit.wasm',
  '/icons/Icon-192.png',
];

/** Cabeceras que efectivamente se aplicarían a una ruta, con "la última gana". */
function headersFor(path: string): Map<string, string> {
  const out = new Map<string, string>();
  for (const block of blocks) {
    if (!matchesGlob(path, block.source)) continue;
    for (const h of block.headers) out.set(h.key.toLowerCase(), h.value);
  }
  return out;
}

describe('firebase.json: cabeceras de hosting', () => {
  it('ninguna cabecera de enmarcado alcanza el namespace reservado /__/', () => {
    for (const path of RESERVED_PATHS) {
      const headers = headersFor(path);
      expect(headers.get('x-frame-options'), path).toBeUndefined();
      const csp = headers.get('content-security-policy-report-only') ?? '';
      expect(csp, path).not.toContain('frame-ancestors');
    }
  });

  it('la app sí queda protegida contra clickjacking, incluidas las rutas SPA', () => {
    for (const path of APP_PATHS) {
      const headers = headersFor(path);
      expect(headers.get('x-frame-options'), path).toBe('DENY');
      expect(headers.get('content-security-policy-report-only'), path).toContain(
        "frame-ancestors 'none'",
      );
    }
  });

  it('las cabeceras de seguridad que no estorban en /__/ siguen en todas las rutas', () => {
    for (const path of [...APP_PATHS, ...RESERVED_PATHS]) {
      const headers = headersFor(path);
      expect(headers.get('strict-transport-security'), path).toContain('max-age=31536000');
      expect(headers.get('x-content-type-options'), path).toBe('nosniff');
      expect(headers.get('referrer-policy'), path).toBe('strict-origin-when-cross-origin');
      expect(headers.get('permissions-policy'), path).toContain('geolocation=()');
    }
  });

  it('ningún bloque con cabeceras de enmarcado usa un source que case con /__/', () => {
    // Red de seguridad por si alguien añade un bloque nuevo: se comprueba el
    // patrón, no solo las rutas de ejemplo de más arriba.
    const framing = blocks.filter((b) =>
      b.headers.some(
        (h) =>
          h.key.toLowerCase() === 'x-frame-options' ||
          (h.key.toLowerCase().startsWith('content-security-policy') &&
            h.value.includes('frame-ancestors')),
      ),
    );
    expect(framing.length).toBeGreaterThan(0);
    for (const block of framing) {
      for (const path of RESERVED_PATHS) {
        expect(matchesGlob(path, block.source), `${block.source} casa con ${path}`).toBe(false);
      }
    }
  });
});
