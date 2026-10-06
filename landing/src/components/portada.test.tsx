// @vitest-environment jsdom
//
// Para qué existe este archivo: comprobar que las dos secciones de la portada
// que se reescribieron **montan de verdad** y dicen lo que tienen que decir.
//
// El resto de los tests de la landing leen el código fuente como texto, que es
// barato y suficiente para vigilar que no vuelva contenido inventado. Pero un
// test de texto no detecta que un componente reviente al renderizar, y la
// portada es la URL que el revisor de Google Play abre al comprobar la política
// de privacidad de la ficha: si no carga, no hay ficha.
//
// Nota sobre `matchMedia`: jsdom no lo implementa y ScrollTrigger lo llama al
// registrarse. En un navegador real existe, así que el stub de abajo no tapa un
// fallo, solo completa el entorno. Tiene que ejecutarse ANTES de importar los
// componentes, de ahí los `import()` dinámicos.

import { fireEvent, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it } from 'vitest';

window.matchMedia = ((query: string) => ({
  matches: false,
  media: query,
  onchange: null,
  addListener: () => {},
  removeListener: () => {},
  addEventListener: () => {},
  removeEventListener: () => {},
  dispatchEvent: () => false,
})) as unknown as typeof window.matchMedia;

const ContextoChile = (await import('./ContextoChile')).default;
const Features = (await import('./Features')).default;

afterEach(() => {
  document.body.innerHTML = '';
});

/** Texto plano del componente, con los espacios normalizados. */
function textoDe(ui: Parameters<typeof render>[0]): string {
  const { container } = render(ui);
  return (container.textContent ?? '').replace(/\s+/g, ' ');
}

describe('Sección «por qué ahora»', () => {
  it('monta y muestra el contexto y las dos mitades del mensaje', () => {
    const texto = textoDe(<ContextoChile />);
    expect(texto).toContain('Servicio de Impuestos Internos');
    expect(texto).toContain('inicio de actividades');
    expect(texto).toContain('Lo que hace');
    expect(texto).toContain('Lo que no hace');
    // La negación del impuesto nuevo es lo que impide que el texto sea
    // alarmista, y es literal en la fuente del Gobierno (ver FICHA-PLAY §3).
    expect(texto).toContain('No porque haya un impuesto nuevo');
  });

  it('cierra con el descargo de que no es asesoría', () => {
    expect(textoDe(<ContextoChile />)).toContain(
      'No es asesoría contable, financiera ni tributaria',
    );
  });
});

describe('Sección de funcionalidades', () => {
  it('ofrece exactamente las cuatro funciones que la app tiene', () => {
    const { container } = render(<Features />);
    const pestanas = [...container.querySelectorAll('button')].map(
      (b) => b.textContent,
    );
    // Cuatro, y estas cuatro. Si alguien añade una quinta tiene que existir
    // antes en `lib/features/`.
    expect(pestanas).toEqual([
      'Valor hora',
      'Inventario',
      'Ingresos y gastos',
      'Asistente',
    ]);
  });

  it('rotula las cifras de las maquetas como ilustración', () => {
    // Las maquetas muestran montos. Sin el rótulo se leen como datos reales de
    // un usuario, que es contenido engañoso.
    expect(textoDe(<Features />)).toContain('Ejemplo ilustrativo de la interfaz');
  });

  it('avisa de que las respuestas del asistente las genera una IA', () => {
    // La sección solo pinta la descripción de la pestaña activa, y la primera
    // es «Valor hora». Hay que abrir «Asistente» para ver su texto, que es
    // donde vive el aviso.
    const { container } = render(<Features />);
    fireEvent.click(screen.getByRole('button', { name: 'Asistente' }));
    const texto = (container.textContent ?? '').replace(/\s+/g, ' ');
    expect(texto).toContain('modelo de inteligencia artificial');
    expect(texto).toContain('no son asesoría contable ni tributaria');
    // Y la maqueta de la conversación lleva su propio rótulo, porque una
    // captura de chat sin él se lee como una afirmación de la app.
    expect(texto).toContain('Respuesta generada por IA');
  });
});
