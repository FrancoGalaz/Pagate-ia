// Pie de la landing.
//
// Tenía once enlaces apuntando a `href: '#'`: Changelog, Blog, Guías,
// Calculadora, Ayuda, Sobre nosotros, Contacto, Trabaja con nosotros y los
// tres iconos de redes sociales. Ninguno de esos destinos existe. Se quedan
// solo los que llevan a algún sitio real, y se añade el bloque Legal, que
// Google Play exige enlazado desde la web pública donde vive la ficha.
//
// Regla para quien amplíe esto: ninguna entrada nueva con `href: '#'`. Si el
// destino no existe todavía, no se lista.

import PagateLogo from './PagateLogo';
import { LEGAL_ROUTES, siteUrl } from '../content/legal-meta';

const footerLinks = {
  Producto: [
    { label: 'Funcionalidades', href: '#features' },
    { label: 'Cómo funciona', href: '#how-it-works' },
    { label: 'Qué viene después', href: '#roadmap' },
    { label: 'Lista de espera', href: '#cta' },
  ],
  Legal: [
    { label: 'Política de privacidad', href: siteUrl(LEGAL_ROUTES.privacidad) },
    { label: 'Términos de servicio', href: siteUrl(LEGAL_ROUTES.terminos) },
    { label: 'Eliminar cuenta y datos', href: siteUrl(LEGAL_ROUTES.eliminarCuenta) },
  ],
};

export default function Footer() {
  return (
    <footer className="bg-dark-surface border-t border-white/5 pt-16 pb-8">
      <div className="max-w-7xl mx-auto px-6 lg:px-8">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-8 lg:gap-12 mb-12">
          {/* Brand */}
          <div className="sm:col-span-2 mb-4 lg:mb-0">
            <a href={siteUrl(LEGAL_ROUTES.inicio)} className="flex items-center gap-2 mb-4">
              <PagateLogo className="w-10 h-10" />
              <span className="font-display font-bold text-xl tracking-tight text-white">
                Pagate
              </span>
            </a>
            <p className="text-sm text-text-muted leading-relaxed max-w-xs">
              La app inteligente que calcula tu valor hora real y organiza tu negocio para que crezcas con claridad.
            </p>
          </div>

          {/* Links */}
          {Object.entries(footerLinks).map(([category, links]) => (
            <div key={category}>
              <h4 className="font-display font-semibold text-sm text-white mb-4">
                {category}
              </h4>
              <ul className="space-y-3">
                {links.map((link) => (
                  <li key={link.label}>
                    <a
                      href={link.href}
                      className="text-sm text-text-muted hover:text-brand transition-colors"
                    >
                      {link.label}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        {/* Bottom */}
        <div className="pt-8 border-t border-white/5 flex flex-col md:flex-row items-center justify-between gap-4">
          <p className="text-sm text-text-muted">
            © {new Date().getFullYear()} Pagate. Todos los derechos reservados.
          </p>
          <div className="flex items-center gap-2 text-sm text-text-muted">
            <svg className="w-4 h-4 text-brand" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
            </svg>
            Asistente financiero para artesanos y creadores.
          </div>
        </div>
      </div>
    </footer>
  );
}
