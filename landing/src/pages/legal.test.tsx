// @vitest-environment jsdom
//
// Estos tests no comprueban estilos: comprueban que las tres páginas legales
// siguen diciendo lo que Google Play exige que digan. Si alguien recorta la
// política de privacidad y borra la divulgación del envío a OpenRouter, o
// quita de los términos la frase de que la app no procesa pagos, la revisión
// de Play se cae semanas después y nadie sabrá por qué. Esto lo detecta antes.

import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { render } from '@testing-library/react';
import { afterEach, describe, expect, it } from 'vitest';
import PrivacidadPage from './PrivacidadPage';
import TerminosPage from './TerminosPage';
import EliminarCuentaPage from './EliminarCuentaPage';
import { BUZON, CANAL_ALTERNATIVO } from '../content/legal-meta';

/** Texto plano de la página, normalizado para buscar frases sin pelear con el markup. */
function textOf(ui: Parameters<typeof render>[0]): string {
  const { container } = render(ui);
  return (container.textContent ?? '').replace(/\s+/g, ' ');
}

afterEach(() => {
  document.body.innerHTML = '';
});

describe('Política de privacidad', () => {
  it('declara el inventario completo de datos que recoge la app', () => {
    const text = textOf(<PrivacidadPage />);
    // Un elemento por cada tipo de dato verificado en el código.
    for (const dato of [
      'Correo electrónico y contraseña',
      'Nombre del negocio',
      'Moneda',
      'meta mensual de ingresos',
      'Cálculo de tu valor hora',
      'Transacciones',
      'Gastos fijos',
      'Inventario',
      'Resúmenes mensuales',
      // Antes decía 'contador de uso diario'. La cuota del plan free NO es
      // diaria: son mensajes DE POR VIDA (`FREE_LIFETIME_QUOTA` en
      // functions/src/quota.ts) y el contador guarda los dos números.
      'contador de mensajes',
      'en total desde que creaste la cuenta',
      // El reporte de respuestas de la IA (`users/{uid}/aiReports`) es un dato
      // que la app recoge y que la política no nombraba.
      'reportas una respuesta',
      'lista de espera',
    ]) {
      expect(text).toContain(dato);
    }
  });

  it('divulga qué se envía a OpenRouter y al proveedor del modelo', () => {
    const text = textOf(<PrivacidadPage />);
    expect(text).toContain('OpenRouter');
    expect(text).toContain('valor hora calculado');
    // La advertencia sobre nombres de clientes en el título de la transacción.
    expect(text).toContain('nombre de un cliente');
  });

  it('los límites que divulga coinciden con los del backend', () => {
    // Este test decía `toContain('últimos 20 mensajes')` y pasaba en verde
    // mientras `HISTORY_LIMIT` valía 6: estaba fijando una cifra falsa en una
    // política de privacidad publicada, y el verde la defendía.
    //
    // Ahora las dos cifras se LEEN de functions/src/chat.ts, que es su única
    // fuente. Si alguien las cambia ahí, este test falla y nombra el párrafo de
    // la política que hay que corregir, en vez de dejarlo mintiendo.
    const chat = readFileSync(
      join(import.meta.dirname, '..', '..', '..', 'functions', 'src', 'chat.ts'),
      'utf8',
    );
    const leer = (constante: string): number => {
      const m = chat.match(new RegExp(`${constante}\\s*=\\s*(\\d+)`));
      expect(m, `no se encontró ${constante} en functions/src/chat.ts`).not.toBeNull();
      return Number(m![1]);
    };

    const historial = leer('HISTORY_LIMIT');
    const transacciones = leer('RECENT_TRANSACTIONS_LIMIT');

    const text = textOf(<PrivacidadPage />);
    expect(text).toContain(`últimos ${historial} mensajes`);
    expect(text).toContain(`últimas ${transacciones} transacciones`);
  });

  it('indica dónde se guardan los datos y que van cifrados en tránsito', () => {
    const text = textOf(<PrivacidadPage />);
    expect(text).toContain('Firebase Authentication');
    expect(text).toContain('Cloud Firestore');
    expect(text).toContain('TLS');
  });

  it('declara retención, derechos y un contacto', () => {
    const text = textOf(<PrivacidadPage />);
    expect(text).toContain('Cuánto tiempo los conservamos');
    expect(text).toContain('Tus derechos y cómo ejercerlos');
    expect(text).toContain('Contacto');
  });

  it('afirma que no hay publicidad ni analítica', () => {
    const text = textOf(<PrivacidadPage />);
    expect(text).toContain('No hay publicidad');
    expect(text).toContain('No hay SDK de analítica');
  });
});

describe('Términos de servicio', () => {
  it('niega ser asesoría profesional y niega mover dinero', () => {
    const text = textOf(<TerminosPage />);
    expect(text).toContain('No es asesoría financiera, contable ni tributaria profesional');
    expect(text).toContain('No mueve dinero y no procesa pagos');
    expect(text).toContain('No se conecta a tus cuentas bancarias');
    expect(text).toContain('No es un sistema de facturación electrónica');
  });

  it('advierte que las respuestas del asistente pueden equivocarse', () => {
    const text = textOf(<TerminosPage />);
    expect(text).toContain('Pueden contener errores');
  });

  it('declara que hoy no hay suscripción ni cobro', () => {
    const text = textOf(<TerminosPage />);
    expect(text).toContain('no existe ninguna función de pago ni suscripción activa');
  });
});

describe('Eliminar cuenta y datos', () => {
  it('nombra la app y su identificador de paquete', () => {
    const text = textOf(<EliminarCuentaPage />);
    expect(text).toContain('Págate-IA');
    expect(text).toContain('com.pagate.apppagate');
  });

  it('enumera qué se borra y qué no', () => {
    const text = textOf(<EliminarCuentaPage />);
    expect(text).toContain('Qué se borra');
    expect(text).toContain('Qué no se borra');
    expect(text).toContain('conversaciones con el asistente');
  });

  it('indica el plazo de borrado', () => {
    const text = textOf(<EliminarCuentaPage />);
    expect(text).toContain('30 días');
  });

  it('ofrece un canal de solicitud sin pedir iniciar sesión', () => {
    const { container } = render(<EliminarCuentaPage />);
    // El botón `mailto:` solo existe cuando hay un buzón publicado. Mientras
    // `CONTACT.privacy` sea un marcador, `BUZON.privacidad` vale `null` y la
    // página describe el canal en texto en lugar de ofrecer un enlace roto.
    // Lo que se exige siempre es que haya ALGÚN canal, nunca un `mailto`
    // inválido.
    const mailto = container.querySelector('a[href^="mailto:"]');
    if (BUZON.privacidad) {
      expect(mailto?.getAttribute('href')).toContain(BUZON.privacidad);
    } else {
      expect(mailto).toBeNull();
      expect(container.textContent).toContain(CANAL_ALTERNATIVO);
    }
    // No debe haber ningún campo de entrada: un formulario público que acepte
    // un correo ajeno permitiría pedir el borrado de la cuenta de otra persona.
    expect(container.querySelectorAll('input, textarea').length).toBe(0);
  });
});

describe('Enlaces cruzados entre las páginas legales', () => {
  it('cada página enlaza a las otras dos y al inicio', () => {
    for (const ui of [<PrivacidadPage />, <TerminosPage />, <EliminarCuentaPage />]) {
      const { container } = render(ui);
      const hrefs = Array.from(container.querySelectorAll('a')).map((a) =>
        a.getAttribute('href'),
      );
      expect(hrefs.some((h) => h?.includes('privacidad/'))).toBe(true);
      expect(hrefs.some((h) => h?.includes('terminos/'))).toBe(true);
      expect(hrefs.some((h) => h?.includes('eliminar-cuenta/'))).toBe(true);
      document.body.innerHTML = '';
    }
  });

  it('ninguna página muestra un marcador entre corchetes', () => {
    // Una política de privacidad publicada con `[RAZÓN SOCIAL…]` a la vista es
    // motivo de rechazo en Google Play. Este test renderiza las tres páginas y
    // busca corchetes en el texto resultante, que es exactamente lo que vería
    // el revisor. Da igual si el dueño rellenó o no los datos: en los dos
    // estados el documento tiene que leerse como prosa.
    for (const ui of [<PrivacidadPage />, <TerminosPage />, <EliminarCuentaPage />]) {
      expect(textOf(ui)).not.toMatch(/\[[^\]]+\]/);
      document.body.innerHTML = '';
    }
  });

  it('ningún enlace mailto apunta a un destinatario con corchetes', () => {
    for (const ui of [<PrivacidadPage />, <TerminosPage />, <EliminarCuentaPage />]) {
      const { container } = render(ui);
      for (const a of container.querySelectorAll('a[href^="mailto:"]')) {
        expect(a.getAttribute('href')).not.toMatch(/[[\]]/);
      }
      document.body.innerHTML = '';
    }
  });

  it('ningún enlace queda apuntando a «#»', () => {
    for (const ui of [<PrivacidadPage />, <TerminosPage />, <EliminarCuentaPage />]) {
      const { container } = render(ui);
      const dead = Array.from(container.querySelectorAll('a')).filter(
        (a) => a.getAttribute('href') === '#',
      );
      expect(dead).toHaveLength(0);
      document.body.innerHTML = '';
    }
  });
});
