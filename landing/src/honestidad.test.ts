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
  // Tres pestañas de Features.tsx anunciaban funciones que no existen en la
  // app. Verificado: `lib/features/` solo tiene auth, dashboard, finances,
  // hourly_value, inventory, onboarding y user_profile. No hay registro de
  // horas, ni metas de ahorro, ni analítica de productividad.
  { needle: 'Seguimiento de horas', porque: 'la app no registra horas trabajadas' },
  { needle: 'horas facturables', porque: 'la app no calcula horas facturables' },
  { needle: 'Metas de ahorro', porque: 'la app no tiene metas de ahorro' },
  { needle: "label: 'Tiempo'", porque: 'pestaña de una función inexistente' },
  { needle: "label: 'Ahorro'", porque: 'pestaña de una función inexistente' },
  { needle: "label: 'Productividad'", porque: 'pestaña de una función inexistente' },
  // La app no recibe pagos. Afirmarlo la arrastra a la política de remesas y
  // servicios financieros de Google Play.
  { needle: 'recibir pagos', porque: 'la app no recibe ni procesa pagos' },
  { needle: 'punto de venta', porque: 'la app no es un POS' },
  // Los dos campos del contrato C-3 («boleta de honorarios» y «comisión del
  // medio de pago») estuvieron aquí, prohibidos, porque entonces no existían en
  // `lib/` y la landing no podía anunciarlos. Ya existen, así que la prohibición
  // se volvió lo contrario de lo que este archivo defiende: un guardia que
  // impedía decir la verdad. Lo que ocupa su sitio es el test
  // «los campos chilenos que nombra la política existen en la app», más abajo:
  // no prohíbe la frase, exige que el código la respalde.
];

/**
 * Campos del contrato C-3 que la política de privacidad nombra, con el valor
 * exacto que tienen que tener en el cliente para que nombrarlos sea verdad.
 *
 * `wire` es el literal que viaja a Firestore, no la etiqueta de la interfaz:
 * una etiqueta se puede traducir, y lo que determina si el dato existe es el
 * campo.
 */
const CAMPOS_C3: Array<{ wire: string; donde: string }> = [
  { wire: 'boleta_honorarios', donde: 'docType de una transacción' },
  { wire: 'boleta_venta', donde: 'docType de una transacción' },
  { wire: 'platformFee', donde: 'la comisión del medio de pago' },
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

  it('los campos chilenos que nombra la política existen en la app', () => {
    // Este test sustituye a dos prohibiciones que se volvieron falsas (ver la
    // nota al final de PROHIBIDAS). La política de privacidad dice hoy que el
    // asistente recibe el tipo de documento y la comisión del medio de pago de
    // cada ingreso. Eso solo es verdad si los campos existen en el cliente, así
    // que se comprueba en el cliente y no se da por bueno.
    //
    // Se leen los archivos de `lib/` desde aquí a propósito: la landing y la app
    // son dos builds distintos, y esta afirmación cruza las dos. Si alguien
    // retira el contrato C-3 del cliente, el que queda mintiendo es un documento
    // legal publicado, y este es el único test que lo ve.
    const repo = join(SRC, '..', '..');
    const entity = readFileSync(
      join(repo, 'lib', 'features', 'finances', 'domain', 'entities', 'finances_transaction_entity.dart'),
      'utf8',
    );
    const ausentes = CAMPOS_C3.filter(({ wire }) => !entity.includes(wire));
    expect(
      ausentes.map(({ wire, donde }) => `${wire} (${donde})`),
      'la política de privacidad nombra campos que ya no están en el cliente',
    ).toEqual([]);

    // Y que la política los siga nombrando: si se borran de la página, el
    // formulario de Seguridad de los datos de Play deja de coincidir con la app.
    const privacidad = readFileSync(join(SRC, 'pages', 'PrivacidadPage.tsx'), 'utf8');
    expect(privacidad).toContain('boleta de honorarios');
    expect(privacidad).toContain('comisión que te descontó el medio de pago');
  });

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

  it('ningún texto renderizado deja un marcador entre corchetes', () => {
    // Un `[RAZÓN SOCIAL…]` visible en una página legal es motivo de rechazo en
    // Google Play. Los marcadores viven SOLO en legal-meta.ts, que es el
    // archivo que el dueño rellena; ninguna página los imprime (ver el aviso
    // de LegalLayout.tsx y las dos redacciones de cada página).
    const culpables = files
      .filter((f) => !/legal-meta\.ts$/.test(f))
      .filter((f) => /\[[A-ZÁÉÍÓÚÑ][^\]]{4,}\]/.test(stripComments(readFileSync(f, 'utf8'))));
    expect(culpables.map((f) => relative(SRC, f))).toEqual([]);
  });

  it('ningún enlace mailto se construye con un dato sin rellenar', () => {
    // `mailto:[CORREO…]` abre el cliente de correo con un destinatario
    // inválido, que es peor que no ofrecer el enlace. Las páginas usan `BUZON`,
    // que vale `null` mientras el correo siga siendo un marcador.
    const culpables = files.filter((f) => {
      const src = stripComments(readFileSync(f, 'utf8'));
      return /mailto:\$\{CONTACT\./.test(src) || /mailto:\[/.test(src);
    });
    expect(culpables.map((f) => relative(SRC, f))).toEqual([]);
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
