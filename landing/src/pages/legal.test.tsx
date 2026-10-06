// @vitest-environment jsdom
//
// Estos tests no comprueban estilos: comprueban que las tres páginas legales
// siguen diciendo lo que Google Play exige que digan. Si alguien recorta la
// política de privacidad y borra la divulgación del envío a OpenRouter, o
// quita de los términos la frase de que la app no procesa pagos, la revisión
// de Play se cae semanas después y nadie sabrá por qué. Esto lo detecta antes.

import { render } from '@testing-library/react';
import { afterEach, describe, expect, it } from 'vitest';
import PrivacidadPage from './PrivacidadPage';
import TerminosPage from './TerminosPage';
import EliminarCuentaPage from './EliminarCuentaPage';

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
      'contador de uso diario',
      'lista de espera',
    ]) {
      expect(text).toContain(dato);
    }
  });

  it('divulga qué se envía a OpenRouter y al proveedor del modelo', () => {
    const text = textOf(<PrivacidadPage />);
    expect(text).toContain('OpenRouter');
    expect(text).toContain('últimas 10 transacciones');
    expect(text).toContain('últimos 20 mensajes');
    expect(text).toContain('valor hora calculado');
    // La advertencia sobre nombres de clientes en el título de la transacción.
    expect(text).toContain('nombre de un cliente');
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
    const mailto = container.querySelector('a[href^="mailto:"]');
    expect(mailto).not.toBeNull();
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
