import { Zap, Code2, MessageCircle, Users } from 'lucide-react';
import PagateLogo from './PagateLogo';

const footerLinks = {
  Producto: [
    { label: 'Funcionalidades', href: '#features' },
    { label: 'Cómo funciona', href: '#how-it-works' },
    { label: 'Precios', href: '#cta' },
    { label: 'Changelog', href: '#' },
  ],
  Recursos: [
    { label: 'Blog', href: '#' },
    { label: 'Guías', href: '#' },
    { label: 'Calculadora valor hora', href: '#' },
    { label: 'Centro de ayuda', href: '#' },
  ],
  Empresa: [
    { label: 'Sobre nosotros', href: '#' },
    { label: 'Contacto', href: '#' },
    { label: 'Trabaja con nosotros', href: '#' },
  ],
  Legal: [
    { label: 'Términos y condiciones', href: '#' },
    { label: 'Política de privacidad', href: '#' },
  ],
};

export default function Footer() {
  return (
    <footer className="bg-dark-surface border-t border-white/5 pt-16 pb-8">
      <div className="max-w-7xl mx-auto px-6 lg:px-8">
        <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-5 gap-8 lg:gap-12 mb-12">
          <div className="col-span-2 md:col-span-4 lg:col-span-1 mb-4 lg:mb-0">
            <a href="#" className="flex items-center gap-2 mb-4">
              <PagateLogo className="w-10 h-10" />
              <span className="font-display font-bold text-xl tracking-tight text-white">
                Pagate
              </span>
            </a>
            <p className="text-sm text-text-muted leading-relaxed max-w-xs">
              La app inteligente que calcula tu valor hora real y organiza tu negocio para que crezcas con claridad.
            </p>
            <div className="flex items-center gap-3 mt-6">
              <a href="#" className="w-9 h-9 rounded-lg bg-white/5 flex items-center justify-center text-text-muted hover:text-white hover:bg-white/10 transition-colors">
                <MessageCircle className="w-4 h-4" />
              </a>
              <a href="#" className="w-9 h-9 rounded-lg bg-white/5 flex items-center justify-center text-text-muted hover:text-white hover:bg-white/10 transition-colors">
                <Users className="w-4 h-4" />
              </a>
              <a href="#" className="w-9 h-9 rounded-lg bg-white/5 flex items-center justify-center text-text-muted hover:text-white hover:bg-white/10 transition-colors">
                <Code2 className="w-4 h-4" />
              </a>
            </div>
          </div>

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

        <div className="pt-8 border-t border-white/5 flex flex-col md:flex-row items-center justify-between gap-4">
          <p className="text-sm text-text-muted">
            © {new Date().getFullYear()} Pagate. Todos los derechos reservados.
          </p>
          <div className="flex items-center gap-2 text-sm text-text-muted">
            <Zap className="w-4 h-4 text-brand" />
            Asistente financiero para artesanos y creadores.
          </div>
        </div>
      </div>
    </footer>
  );
}
