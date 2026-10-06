// ═══════════════════════════════════════════════════════════════════════
// ENLACES PÚBLICOS DE LA APP
// ═══════════════════════════════════════════════════════════════════════
// Las tres direcciones que la app abre en el navegador. Estaban dentro de
// `welcome_screen.dart`, pero ahora las usan dos pantallas (Bienvenida y
// Configuración) y la de borrado la exige también la ficha de Play, así que
// viven en un sitio único.
//
// Son las rutas que YA existen en el build publicado (`landing-page/`):
// `terminos/`, `privacidad/` y `eliminar-cuenta/`, cada una con su
// `index.html`. Mientras el dueño no publique esa carpeta en GitHub Pages
// devolverán 404, y `abrirEnlaceExterno` lo detecta y lo dice en vez de
// dejar al usuario mirando una página de error.
// ═══════════════════════════════════════════════════════════════════════

/// Base de la landing publicada en GitHub Pages.
const String kUrlLandingBase =
    'https://francogalaz.github.io/Pagate-ia/landing-page';

/// Términos de uso.
const String kUrlTerminos = '$kUrlLandingBase/terminos/';

/// Política de privacidad. Es la URL que pide la ficha de Play.
const String kUrlPrivacidad = '$kUrlLandingBase/privacidad/';

/// Instrucciones públicas de borrado de cuenta.
///
/// Google Play exige una URL accesible SIN instalar la app, además del
/// borrado desde dentro (que está en Configuración → Cuenta).
const String kUrlBorradoCuenta = '$kUrlLandingBase/eliminar-cuenta/';
