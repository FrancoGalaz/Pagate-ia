// Guardia contra la vuelta del contenido inventado.
//
// La landing pública es la URL que el revisor de Google Play abre cuando
// comprueba la política de privacidad de la ficha. Lo que vio en su momento
// fue «8.500 freelancers activos», «98 % satisfacción» y tres testimonios
// firmados con nombre y cinco estrellas de un producto sin lanzar: el caso de
// manual de la política de Tergiversación. Esas secciones se eliminaron.
//
// Este test lee el código fuente de la landing y falla si alguna de esas
// cadenas vuelve a aparecer. Es deliberadamente tonto y deliberadamente
// literal: no comprueba intenciones, comprueba que nadie copie y pegue de
// vuelta el bloque que ya nos costó un hallazgo crítico de auditoría.

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { describe, expect, it } from 'vitest';

const SRC = join(import.meta.dirname, '.');

/** Devuelve todos los .ts/.tsx de src/, excepto los propios tests. */
function sourceFiles(dir: string, acc: string[] = []): string[] {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) {
      sourceFiles(full, acc);
    } else if (/\.tsx?$/.test(entry) && !/\.test\.tsx?$/.test(entry)) {
      acc.push(full);
    }
  }
  return acc;
}

/**
 * Quita los comentarios antes de buscar.
 *
 * Varios archivos explican en su cabecera qué contenido inventado se eliminó y
 * por qué, y para eso tienen que nombrarlo. Esas notas son justo lo que impide
 * que alguien lo reintroduzca, así que el guardia no puede dispararse con
 * ellas: solo mira el código y el texto que se renderiza.
 *
 * Borra bloques `/* ... *\/` (incluidos los comentarios JSX `{/* ... *\/}`) y
 * las líneas que empiezan por `//`. No toca un `//` a mitad de línea, para no
 * mutilar URLs dentro de cadenas.
 */
function stripComments(src: string): string {
  return src
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .split('\n')
    .filter((line) => !line.trimStart().startsWith('//'))
    .join('\n');
}

/**
 * Cadenas prohibidas. Cada una corresponde a un hallazgo concreto de
 * docs/AUDITORIA-2026-09-29.md, sección «Políticas, privacidad y datos».
 */
const PROHIBIDAS: Array<{ needle: string; porque: string }> = [
  { needle: '8.500', porque: 'métrica de usuarios inventada (Stats.tsx)' },
  { needle: 'Freelancers activos', porque: 'métrica de usuarios inventada' },
  { needle: 'Satisfacción de usuarios', porque: 'medición que nunca se hizo' },
  { needle: 'Horas facturadas al mes', porque: 'métrica inventada' },
  { needle: '42.8k', porque: 'promedio de valor hora inventado' },
  { needle: 'María González', porque: 'testimonio inventado' },
  { needle: 'Carlos Martínez', porque: 'testimonio inventado' },
  { needle: 'Ana Silva', porque: 'testimonio inventado' },
  { needle: 'Testimonios', porque: 'no hay usuarios reales a quienes citar' },
  { needle: 'Cancela cuando quieras', porque: 'no existe suscripción que cancelar' },
  { needle: 'Roadmap 2025', porque: 'año pasado presentado como plan vigente' },
  {
    needle: "status: 'En desarrollo'",
    porque: 'ninguna función del roadmap tiene código escrito',
  },
  { needle: 'Promedio mercado', porque: 'la app no tiene datos de mercado' },
  { needle: '+24% de productividad', porque: 'resultado medido que nunca se midió' },
  { needle: 'disponible en versión beta', porque: 'la app no está publicada' },
];

describe('la landing no vuelve a inventar datos', () => {
  const files = sourceFiles(SRC);

  it('encuentra el código fuente de la landing', () => {
    expect(files.length).toBeGreaterThan(5);
  });

  for (const { needle, porque } of PROHIBIDAS) {
    it(`no contiene "${needle}" (${porque})`, () => {
      const culpables = files.filter((f) =>
        stripComments(readFileSync(f, 'utf8')).includes(needle),
      );
      expect(
        culpables.map((f) => relative(SRC, f)),
        `"${needle}" reapareció: ${porque}`,
      ).toEqual([]);
    });
  }

  it('no quedan enlaces muertos href="#" en los componentes', () => {
    const culpables = files.filter((f) =>
      /href="#"/.test(stripComments(readFileSync(f, 'utf8'))),
    );
    expect(culpables.map((f) => relative(SRC, f))).toEqual([]);
  });

  it('la portada enlaza a privacidad, términos y eliminación de cuenta', () => {
    const footer = readFileSync(join(SRC, 'components', 'Footer.tsx'), 'utf8');
    expect(footer).toContain('LEGAL_ROUTES.privacidad');
    expect(footer).toContain('LEGAL_ROUTES.terminos');
    expect(footer).toContain('LEGAL_ROUTES.eliminarCuenta');
  });

  it('no queda ninguna animación decorativa en bucle infinito', () => {
    // `repeat: -1` en GSAP y `animate-ping` en Tailwind son bucles perpetuos.
    // La dirección visual del proyecto los prohíbe explícitamente.
    const culpables = files.filter((f) => {
      const src = stripComments(readFileSync(f, 'utf8'));
      return /repeat:\s*-1/.test(src) || /animate-ping/.test(src);
    });
    expect(culpables.map((f) => relative(SRC, f))).toEqual([]);
  });
});
