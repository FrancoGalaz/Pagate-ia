// ═══════════════════════════════════════════════════════════════════════
// NOMBRE DE LA APP — UN SOLO SITIO
// ═══════════════════════════════════════════════════════════════════════
// Había TRES nombres y DOS logotipos para la misma app, todos a la vista en
// el primer minuto de uso:
//
//   · Bienvenida:  "Págate"     + cuadrado sólido de marca.
//   · Login:       "Págate-IA"  + un rayo (`Icons.bolt_rounded`) sobre un
//                                 degradado con glow verde.
//   · Splash:      "Págate-IA"  + el mismo rayo.
//   · Rail de escritorio: "Págate".
//   · Lanzador de Android: "Págate-IA" (res/values/strings.xml).
//
// GANA «Págate-IA», con tilde, y no por gusto: es el nombre que el usuario
// ve bajo el icono en su teléfono, el que figura en los tres documentos
// legales ya publicados en la landing (privacidad, términos y borrado de
// cuenta), el de `pubspec.yaml` y el que tiene que escribirse igual en la
// ficha de Play Console. El nombre de una app instalada tiene que coincidir
// con el de sus términos: cambiar los cuatro sitios de la app es una línea
// cada uno, cambiar un documento legal publicado no.
//
// Se descartó alinear todo a "Págate" justamente por eso.
// ═══════════════════════════════════════════════════════════════════════

/// Nombre de la app, tal como lo ve el usuario.
///
/// Es el mismo literal que `android/app/src/main/res/values/strings.xml`
/// declara en `app_name` y que el lanzador pinta bajo el icono.
const String kAppName = 'Págate-IA';
