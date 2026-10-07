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

import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, relative, sep } from 'node:path';
import { describe, expect, it } from 'vitest';
import { FUNCIONES_APP } from './content/legal-meta';

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

/** Todos los `.dart` bajo un directorio, recursivamente. */
function dartSources(dir: string, acc: string[] = []): string[] {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) {
      dartSources(full, acc);
    } else if (entry.endsWith('.dart')) {
      acc.push(full);
    }
  }
  return acc;
}

/**
 * Funciones que los documentos legales describen, con la señal que las delata en
 * el código del cliente.
 *
 * Esto existe porque la landing y la app son dos builds distintos: el documento
 * legal se publica desde `landing/` y las funciones que describe viven en `lib/`,
 * así que nada impedía que el texto afirmara cosas que la app no hacía. Y las
 * afirmó: que el usuario podía anotar proveedor y código interno en el inventario
 * y editar su ficha «cuando quiera», cuando el formulario no pedía ninguno de los
 * dos campos y ninguna pantalla llamaba a `updateItem`.
 *
 * `declarado` es lo que dice `FUNCIONES_APP` en `content/legal-meta.ts`, que es
 * lo que la página redacta. `detectar()` va a mirar el cliente. Si no coinciden,
 * este test falla en las DOS direcciones: con la función ya en `lib/` y el
 * booleano en `false` los documentos se quedan cortos, y al contrario prometen lo
 * que no existe, que es el caso grave.
 *
 * Si un carril implementa una de estas funciones con otra librería o en otra
 * carpeta, lo que hay que corregir es la señal de aquí, no el booleano.
 */
const FUNCIONES_DECLARADAS: Array<{
  clave: keyof typeof FUNCIONES_APP;
  descripcion: string;
  queAfirma: string;
  detectar: (repo: string) => boolean;
}> = [
  {
    clave: 'fichaInventarioCompleta',
    descripcion: 'proveedor, código interno y pantalla de editar la ficha',
    queAfirma:
      'la política nombra proveedor y código y dice que la ficha de inventario se puede editar',
    detectar: (repo) => {
      // Se mira `presentation/` y se deja fuera `providers/`: el provider declara
      // `updateItem` y acepta `supplier:` desde siempre, así que buscar ahí daría
      // por hecha una función a la que el usuario no llega. Lo que determina si
      // existe es que una PANTALLA la use.
      const dir = join(repo, 'lib', 'features', 'inventory', 'presentation');
      if (!existsSync(dir)) return false;
      const dart = dartSources(dir)
        .filter((f) => !f.includes(`${sep}providers${sep}`))
        .map((f) => readFileSync(f, 'utf8'))
        .join('\n');
      return dart.includes('supplier:') && dart.includes('updateItem(');
    },
  },
  {
    clave: 'lectorBoletas',
    descripcion: 'lector de boletas por foto, galería o documento compartido',
    queAfirma:
      'la política describe el lector como una función disponible, sin el aviso de que todavía no está',
    detectar: (repo) => {
      // La dependencia de reconocimiento de texto es la señal más estable: sin
      // ella no hay lector, y vive en un archivo que no se toca por accidente.
      const pubspec = readFileSync(join(repo, 'pubspec.yaml'), 'utf8');
      return /mlkit_text_recognition/.test(pubspec);
    },
  },
];

describe('lo que los documentos legales describen coincide con la app', () => {
  const repo = join(SRC, '..', '..');

  for (const { clave, descripcion, queAfirma, detectar } of FUNCIONES_DECLARADAS) {
    it(`${descripcion}: lo declarado coincide con lib/`, () => {
      const declarado = FUNCIONES_APP[clave];
      const detectado = detectar(repo);
      expect(
        { clave, declarado, detectado },
        declarado
          ? `FUNCIONES_APP.${clave} está en true, así que ${queAfirma}, y en el ` +
              'cliente no se encuentra. Ponlo en false, o corrige la señal de ' +
              'FUNCIONES_DECLARADAS si el carril la implementó de otra forma.'
          : `la función ya está en el cliente y FUNCIONES_APP.${clave} sigue en ` +
              'false, así que los documentos legales se quedan cortos. Ponlo en ' +
              'true en landing/src/content/legal-meta.ts.',
      ).toEqual({ clave, declarado, detectado: declarado });
    });
  }

  it('las señales detectan de verdad: ninguna está ciega en silencio', () => {
    // Sin esto, el test de arriba es el quinto falso verde de este proyecto. Una
    // señal mal escrita —una ruta que ya no existe, una expresión que no engancha—
    // devuelve `false` para siempre, coincide con un booleano en `false` y deja
    // pasar en verde una política que promete de más el día que el carril aterrice.
    //
    // Así que se le da un cliente de mentira que SÍ tiene las dos funciones y se
    // exige que las vea. Si una señal deja de enganchar, falla aquí.
    const conFunciones = mkdtempSync(join(tmpdir(), 'pagate-senal-si-'));
    const pages = join(conFunciones, 'lib', 'features', 'inventory', 'presentation', 'pages');
    mkdirSync(pages, { recursive: true });
    writeFileSync(
      join(pages, 'editar_item_screen.dart'),
      'await provider.updateItem(item.copyWith(supplier: _proveedor.text));\n',
    );
    writeFileSync(
      join(conFunciones, 'pubspec.yaml'),
      'dependencies:\n  google_mlkit_text_recognition: ^0.17.1\n',
    );

    try {
      for (const { clave, detectar } of FUNCIONES_DECLARADAS) {
        expect(
          detectar(conFunciones),
          `la señal de ${clave} no ve una app que sí tiene la función: está ciega`,
        ).toBe(true);
      }
    } finally {
      rmSync(conFunciones, { recursive: true, force: true });
    }

    // Y el falso positivo contrario: con las dos cadenas SOLO en `providers/`, que
    // es donde han estado siempre, la ficha de inventario no está implementada.
    // Este es el error que daba por buena la afirmación de la política.
    const soloProvider = mkdtempSync(join(tmpdir(), 'pagate-senal-no-'));
    const providers = join(
      soloProvider, 'lib', 'features', 'inventory', 'presentation', 'providers',
    );
    mkdirSync(providers, { recursive: true });
    writeFileSync(
      join(providers, 'inventory_provider.dart'),
      'Future<void> updateItem(final InventoryItemEntity item) => _repository.updateItem(item);\n' +
        '  final String? supplier;\n  addItem(supplier: supplier);\n',
    );
    writeFileSync(join(soloProvider, 'pubspec.yaml'), 'dependencies:\n  provider: ^6.1.2\n');

    try {
      const ficha = FUNCIONES_DECLARADAS.find(
        (f) => f.clave === 'fichaInventarioCompleta',
      )!;
      expect(
        ficha.detectar(soloProvider),
        'la señal se conforma con el provider: daría por hecha una función a la que el usuario no llega',
      ).toBe(false);
    } finally {
      rmSync(soloProvider, { recursive: true, force: true });
    }
  });

  it('la política describe el lector de boletas y lo esencial de su privacidad', () => {
    // El apartado no puede desaparecer: Google pide que la política cubra la
    // función ANTES de publicarla, y el aviso de «todavía no está» es lo que hace
    // honesto describirla por adelantado. Estas cinco frases son el núcleo: si
    // alguien recorta el apartado, lo que queda publicado es una app que lee
    // boletas sin explicar qué hace con la imagen.
    const privacidad = readFileSync(join(SRC, 'pages', 'PrivacidadPage.tsx'), 'utf8');
    expect(privacidad).toContain('La imagen no se guarda');
    expect(privacidad).toContain('El texto se lee dentro de tu teléfono');
    expect(privacidad).toContain('Lo único que puede salir del teléfono es el texto');
    expect(privacidad).toContain('Nada entra a tu inventario sin que tú lo confirmes');
    // La advertencia por los datos del tercero que emitió la boleta.
    expect(privacidad).toContain('Una boleta puede llevar datos de otra persona');
    // Y el aviso de función no disponible, que solo se renderiza mientras lo esté.
    expect(privacidad).toContain('!FUNCIONES_APP.lectorBoletas');
  });
});

describe('la descripción de la ficha de Play cabe y dice lo que afirma', () => {
  // La descripción completa de Play tiene un límite duro de 4.000 caracteres, y
  // `docs/FICHA-PLAY.md` lleva el texto exacto que se pega más la cuenta escrita a
  // mano. Esa combinación ya salió mal dos veces en este repositorio: el documento
  // afirmaba que dieciséis palabras clave estaban «comprobado buscándolas una por
  // una» y una no estaba, y el primer recuento de la revisión del lector de boletas
  // dijo 3.998 cuando el texto medía 3.984.
  //
  // Una cuenta escrita a mano en un documento no se puede comprobar leyéndola. Así
  // que se mide aquí: el límite, el número que el documento afirma y la lista de
  // palabras clave, que se LEE del propio documento en vez de copiarse, para que
  // el test siga afirmando lo que el documento afirma y no otra cosa.
  const ficha = readFileSync(
    join(SRC, '..', '..', 'docs', 'FICHA-PLAY.md'),
    'utf8',
  );

  /** El bloque que se pega tal cual en Play Console. */
  const bloque = /```\n(¿Sabes cuánto vale realmente[\s\S]*?)\n```/.exec(ficha);

  it('el documento sigue llevando el bloque que se pega en Play', () => {
    expect(
      bloque,
      'no se encontró la descripción completa en docs/FICHA-PLAY.md: si se movió, hay que arreglar este test, no borrarlo',
    ).not.toBeNull();
  });

  it('no pasa de los 4.000 caracteres que admite Play', () => {
    const largo = bloque![1].trim().length;
    expect(largo, `la descripción mide ${largo} caracteres`).toBeLessThanOrEqual(4000);
  });

  it('el número que el documento afirma es el que mide el texto', () => {
    const afirmado = /\*\*([\d.]+) caracteres de los 4\.000\*\*/.exec(ficha);
    expect(afirmado, 'el documento ya no dice cuántos caracteres tiene').not.toBeNull();
    // El documento escribe los miles con punto, como se escriben en Chile.
    const cifra = Number(afirmado![1].replace(/\./g, ''));
    expect(
      cifra,
      'la cuenta escrita en docs/FICHA-PLAY.md no coincide con el texto que lleva debajo',
    ).toBe(bloque![1].trim().length);
  });

  it('contiene las palabras clave que el propio documento da por presentes', () => {
    // Se lee la lista de la sección «Palabras que la ficha tiene que contener»,
    // solo el párrafo de las presentes: el documento deja aparte, y a propósito,
    // las que NO quiere («ganancias», «punto de venta»).
    const marca = '**Presentes en el texto de arriba**';
    const desde = ficha.indexOf(marca);
    expect(desde, `no se encontró «${marca}» en docs/FICHA-PLAY.md`).toBeGreaterThan(-1);
    const parrafo = ficha.slice(desde).split('\n\n')[1] ?? '';
    const claves = [...parrafo.matchAll(/`([^`]+)`/g)].map((m) => m[1]);

    expect(claves.length, 'la lista de palabras clave se quedó vacía').toBeGreaterThan(10);
    const texto = bloque![1].toLowerCase();
    expect(
      claves.filter((k) => !texto.includes(k.toLowerCase())),
      'el documento da estas palabras por presentes y no están en la descripción',
    ).toEqual([]);
  });
});

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
