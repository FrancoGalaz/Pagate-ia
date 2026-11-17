// Afirmaciones de la sección «por qué ahora» de la portada.
//
// Para qué existe este archivo: vive separado del componente que las pinta
// (`src/components/ContextoChile.tsx`) por dos razones. La primera es técnica:
// el lint del proyecto (`react-refresh/only-export-components`) no permite que
// un archivo de componente exporte constantes. La segunda es la que importa:
// estas dos listas son el contrato de honestidad de la sección, las comprueba
// `contexto-chile.test.ts` y conviene poder leerlas sin atravesar 150 líneas de
// JSX.
//
// Regla de oro: cada línea de [SI_HACE] tiene que corresponder a código que
// existe hoy en `lib/`, y [NO_HACE] no es letra pequeña, es la mitad del
// mensaje. La app REGISTRA Y MUESTRA; no ASESORA.

/**
 * Lo que la app sí hace.
 *
 * Verificado contra `lib/features/`: `finances` (transacciones y gastos fijos),
 * `months/` lo agrega el trigger `onTransactionWritten`, `inventory` y
 * `hourly_value`. Nada más entra en esta lista.
 */
export const SI_HACE: readonly string[] = [
  'Anota lo que vendes y lo que gastas, con fecha y categoría.',
  'Arma solo el resumen de cada mes: lo que entró, lo que salió y el balance.',
  'Guarda tus gastos fijos y tu inventario con precio y stock.',
  'Te dice cuánto tiene que valer tu hora para llegar a la meta del mes.',
];

/**
 * Lo que la app no hace.
 *
 * Es el límite que no se cruza, y va con el mismo tamaño que la otra mitad:
 * calcular impuestos a pagar, decir cuánto declarar o dar una recomendación
 * tributaria sería asesoría, con la responsabilidad legal que eso arrastra.
 */
export const NO_HACE: readonly string[] = [
  'No declara impuestos ni calcula cuánto tienes que pagar.',
  'No emite boletas ni facturas ante el Servicio de Impuestos Internos.',
  'No se conecta a tu banco ni lee tus movimientos reales.',
  'No te dice qué hacer con el SII: eso lo ve tu contador.',
];
