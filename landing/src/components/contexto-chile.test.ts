// Guardia del límite legal de la sección «por qué ahora».
//
// Para qué existe este archivo: la sección ContextoChile.tsx habla de normativa
// tributaria chilena, y ahí hay una línea que no se puede cruzar. La app
// REGISTRA Y MUESTRA; no ASESORA. Calcular impuestos a pagar, decir cuánto
// declarar o dar una recomendación tributaria convertiría la landing en
// asesoría: es responsabilidad legal del dueño y endurece la clasificación de
// la app en Google Play.
//
// El test no comprueba estilo ni maquetación. Comprueba dos cosas, y las dos
// son verificables leyendo el archivo:
//   1. que las cuatro negaciones sigan ahí (impuestos, boletas, banco, SII), y
//   2. que nadie meta en el texto un verbo de asesoría.
//
// Si alguien reescribe la sección y borra las negaciones, esto falla aquí y no
// semanas después en la revisión de Play.

import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { NO_HACE, SI_HACE } from '../content/contexto-chile';

/**
 * Las dos piezas de la sección: el componente que la pinta y el módulo con las
 * afirmaciones. Se concatenan porque el límite legal se puede cruzar desde
 * cualquiera de los dos.
 */
const FUENTE = [
  join(import.meta.dirname, 'ContextoChile.tsx'),
  join(import.meta.dirname, '..', 'content', 'contexto-chile.ts'),
]
  .map((f) => readFileSync(f, 'utf8'))
  .join('\n');

/** Quita comentarios: la cabecera del componente nombra lo que prohíbe. */
function sinComentarios(src: string): string {
  return src
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .split('\n')
    .filter((line) => !line.trimStart().startsWith('//'))
    .join('\n');
}

/**
 * Fuente sin comentarios y con los espacios normalizados.
 *
 * Lo segundo importa: el JSX parte las frases en varias líneas, así que buscar
 * «50 transferencias de 50 personas distintas» en el archivo crudo falla por un
 * salto de línea. Se colapsa todo el espacio en blanco a un espacio, que es
 * como el navegador va a pintar el párrafo de todas formas.
 */
const TEXTO = sinComentarios(FUENTE).replace(/\s+/g, ' ');

/**
 * Lo mismo, pero quitando además las negaciones de [NO_HACE].
 *
 * El bloque «Lo que no hace» es el único sitio donde «calcula cuánto tienes que
 * pagar» es correcto, porque va precedido de un «No». Si el escáner de verbos
 * de asesoría mirara también esas líneas, se dispararía justo con el texto que
 * existe para evitar el problema.
 */
const TEXTO_SIN_NEGACIONES = NO_HACE.reduce(
  (acc, linea) => acc.replace(linea.replace(/\s+/g, ' '), ''),
  TEXTO,
);

describe('la sección chilena no cruza a la asesoría tributaria', () => {
  it('niega declarar impuestos, emitir boletas, conectarse al banco y asesorar', () => {
    const todo = NO_HACE.join(' ');
    expect(todo).toContain('No declara impuestos');
    expect(todo).toContain('No emite boletas');
    expect(todo).toContain('No se conecta a tu banco');
    expect(todo).toContain('No te dice qué hacer con el SII');
  });

  it('solo promete funciones que existen en la app', () => {
    // Cuatro afirmaciones, una por función real verificada en `lib/features/`:
    // transacciones, resumen mensual, inventario y valor hora.
    expect(SI_HACE).toHaveLength(4);
    const todo = SI_HACE.join(' ');
    expect(todo).toContain('Anota lo que vendes');
    expect(todo).toContain('resumen de cada mes');
    expect(todo).toContain('inventario');
    expect(todo).toContain('valer tu hora');
    // Nada del contrato C-3, que todavía no tiene código en `lib/`.
    expect(todo).not.toMatch(/boleta de (?:venta|honorarios)/i);
    expect(todo).not.toMatch(/comisi[óo]n/i);
  });

  it('no contiene ningún verbo de asesoría tributaria en el texto visible', () => {
    // Cada patrón es una forma concreta de cruzar el límite. Están escritos
    // para no dispararse con las negaciones («no declara», «no calcula»).
    const prohibidos: Array<{ patron: RegExp; porque: string }> = [
      { patron: /(?<!no )declara tus impuestos/i, porque: 'la app no declara' },
      {
        patron: /cu[áa]nto (?:tienes que |debes )?(?:pagar|declarar)/i,
        porque: 'calcular el impuesto a pagar es asesoría',
      },
      { patron: /te ahorras? impuestos/i, porque: 'promesa fiscal' },
      { patron: /regulariza tu situaci[óo]n/i, porque: 'consejo tributario' },
      { patron: /multa/i, porque: 'alarmismo: la norma citada no impone multas al usuario' },
      { patron: /fiscalizaci[óo]n|te van a fiscalizar/i, porque: 'alarmismo' },
      { patron: /nuevo impuesto/i, porque: 'falso: la ley no crea un impuesto nuevo' },
    ];
    for (const { patron, porque } of prohibidos) {
      expect(
        TEXTO_SIN_NEGACIONES,
        `${patron} apareció: ${porque}`,
      ).not.toMatch(patron);
    }
  });

  it('dice explícitamente que no es asesoría', () => {
    expect(TEXTO).toContain('No es asesoría contable');
    expect(TEXTO).toContain('no reemplaza a un contador');
  });

  it('no afirma un umbral distinto del verificado', () => {
    // El umbral real que informan los bancos al SII es «más de 50 abonos de 50
    // personas o entidades distintas en un mismo día, semana o mes» (o al menos
    // 100 de 100 distintas en un semestre). Las fuentes están en
    // docs/FICHA-PLAY.md §3. Si alguien redondea la cifra, esto lo detecta.
    expect(TEXTO).toContain('50 transferencias de 50 personas distintas');
    expect(TEXTO).not.toMatch(/\b(?:20|30|40|60|100)\s*transferencias/);
  });
});
