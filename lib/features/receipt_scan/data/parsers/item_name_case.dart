// ═══════════════════════════════════════════════════════════════════════
// LA CAJA DEL NOMBRE: DE LA BOLETA A LA FICHA
// ═══════════════════════════════════════════════════════════════════════
// EL DEFECTO QUE ARREGLA, VISTO EN PANTALLA. Una boleta chilena se imprime
// entera en mayúsculas, así que el reconocimiento devuelve `ARCILLA GRES
// 25K` y eso es lo que entraba al inventario. En la lista de Materiales
// quedaba al lado de `Caolín` y de `Esmalte transparente`, que los escribió
// el usuario, y la pestaña parecía dos inventarios distintos pegados.
//
// POR QUÉ NO ES UN `toLowerCase()` Y YA. Porque hay tres cosas que NO se
// pueden tocar y las tres están en la boleta de prueba:
//
//   · LAS MEDIDAS Y LOS CÓDIGOS. `25K`, `250G`, `N6`, `400`. Llevan
//     dígitos, así que se reconocen sin tener que listarlos: una palabra
//     con un número dentro se deja tal cual.
//   · LAS SIGLAS DE MATERIAL. `PVC`, `MDF`, `EVA`. Un `pvc` en minúscula
//     no es una errata menor: es que la ficha deja de poder buscarse por
//     como la llama todo el mundo. Van en una lista corta y explícita.
//   · LAS FORMAS SOCIALES DEL PROVEEDOR. `LTDA`, `SpA`, `EIRL`. Esta misma
//     función normaliza el proveedor, que es un nombre legal.
//
// NO SE INVENTAN ACENTOS, Y ES UNA REGLA DURA. El reconocimiento de texto
// pierde las tildes de las mayúsculas con mucha frecuencia, así que
// `OXIDO` sale sin tilde. Se queda `Oxido`, NO `Óxido`: poner la tilde
// obligaría a tener un diccionario del español, y un diccionario se
// equivoca en nombres propios y en marcas. El usuario corrige el nombre en
// la hoja de revisión si quiere, y lo que escriba ahí se respeta sin pasar
// por aquí.
//
// ES IDEMPOTENTE, Y ESO ES LO QUE PERMITE APLICARLA EN LOS DOS CAMINOS. Una
// palabra que ya trae minúsculas no se toca, así que `Arcilla gres` pasa
// intacta. Por eso se puede llamar también sobre lo que devuelve el modelo
// —que normalmente ya viene bien escrito— sin que el resultado dependa de
// qué camino armó la lista.
// ═══════════════════════════════════════════════════════════════════════

/// Siglas y abreviaturas de material que se quedan en mayúscula.
///
/// Lista corta y a propósito: cada entrada es algo que un artesano compra y
/// que escribiría así. Bajarlas a minúscula no es una errata de estilo, es
/// que la ficha deja de parecerse a como se llama el material.
const Set<String> _siglas = {
  'PVC', 'MDF', 'MDP', 'HDF', 'OSB', 'ABS', 'PET', 'PLA', 'PP', 'PE', 'PU',
  'EVA', 'TNT', 'LED', 'UV', 'USB', 'CD', 'DVD', 'XS', 'XL', 'XXL',
  // Del encabezado de la boleta, para el proveedor: no son mercadería pero
  // sí aparecen en una razón social.
  'SII', 'IVA', 'RUT', 'SA', 'EIRL',
};

/// Formas sociales con su caja canónica.
///
/// `SpA` se escribe así en Chile (sociedad por acciones) y ni `SPA` ni
/// `spa` son correctos, así que es el único caso donde la caja de salida no
/// es ni la de entrada ni la minúscula.
const Map<String, String> _formasSociales = {
  'LTDA': 'Ltda',
  'LTDA.': 'Ltda.',
  'SPA': 'SpA',
  'LIMITADA': 'Limitada',
};

/// Palabras de una sola letra que SÍ son palabras del español y bajan a
/// minúscula. El resto de las letras sueltas (`L` de litro, `N` de número)
/// se quedan como estaban.
const Set<String> _letrasQueSonPalabras = {'Y', 'O', 'A', 'E', 'U'};

final RegExp _espacios = RegExp(r'\s+');
final RegExp _tieneDigito = RegExp(r'\d');

/// Pasa un nombre leído de una boleta a la caja que usa el inventario.
///
/// Minúscula para las palabras corrientes, mayúscula inicial en la primera,
/// y sin tocar medidas, códigos ni siglas. Nunca lanza y devuelve la cadena
/// recortada; una cadena vacía sale vacía.
String normalizarCajaDeNombre(final String bruto) {
  final texto = bruto.replaceAll(_espacios, ' ').trim();
  if (texto.isEmpty) return '';

  final palabras = [for (final p in texto.split(' ')) _palabra(p)];
  return _conInicialMayuscula(palabras.join(' '));
}

/// Una palabra, decidida por sí sola.
String _palabra(final String palabra) {
  if (palabra.isEmpty) return palabra;

  // Ya trae minúsculas: la escribió una persona o el modelo, y no es asunto
  // de esta función reescribirla.
  if (!_estaEnMayusculas(palabra)) return palabra;

  final forma = _formasSociales[palabra];
  if (forma != null) return forma;

  // Medidas y códigos: `25K`, `250G`, `N6`, `10.20O`. No hace falta listar
  // ninguno, el dígito los delata.
  if (_tieneDigito.hasMatch(palabra)) return palabra;

  // Siglas con puntos: `S.A.`, `E.I.R.L.`, `P.V.C.`. Bajarlas a minúscula
  // deja `s.a.`, que no es una sigla, es ruido.
  if (palabra.contains('.')) return palabra;

  if (_siglas.contains(_soloLetras(palabra))) return palabra;

  if (palabra.length == 1) {
    return _letrasQueSonPalabras.contains(palabra)
        ? palabra.toLowerCase()
        : palabra;
  }

  return palabra.toLowerCase();
}

/// `true` si la palabra tiene letras y TODAS están en mayúscula.
///
/// Una palabra sin letras (`25`, `-`) devuelve `false` y por tanto se deja
/// tal cual, que es lo que hay que hacer con ella.
bool _estaEnMayusculas(final String palabra) =>
    palabra == palabra.toUpperCase() && palabra != palabra.toLowerCase();

/// La palabra sin signos, para buscarla en la lista de siglas.
String _soloLetras(final String palabra) =>
    palabra.replaceAll(RegExp('[^A-Za-zÁÉÍÓÚÜÑ]'), '');

/// Mayúscula en el primer carácter si es una letra minúscula.
///
/// Se mira solo el primer carácter y no la primera LETRA: en `25K arcilla`
/// la mayúscula iría dentro del nombre, y `25K Arcilla` no es caja de
/// frase, es un título a medias.
String _conInicialMayuscula(final String texto) {
  if (texto.isEmpty) return texto;
  final primera = texto[0];
  if (primera == primera.toUpperCase()) return texto;
  return primera.toUpperCase() + texto.substring(1);
}
