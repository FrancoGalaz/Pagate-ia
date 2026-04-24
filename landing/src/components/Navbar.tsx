import { useState, useEffect } from 'react';
import { Menu, X, ChevronDown } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import PagateLogo from './PagateLogo';

const links = [
  { label: 'Funcionalidades', href: '#features', hasDropdown: true },
  { label: 'Cómo funciona', href: '#how-it-works', hasDropdown: false },
  { label: 'Precios', href: '#cta', hasDropdown: false },
];

export default function Navbar() {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [scrollDirection, setScrollDirection] = useState<'up' | 'down' | null>(null);
  const [lastScrollY, setLastScrollY] = useState(0);
  const [isAtTop, setIsAtTop] = useState(true);

  useEffect(() => {
    const handleScroll = () => {
      const currentScrollY = window.scrollY;

      setIsAtTop(currentScrollY < 10);

      if (currentScrollY > lastScrollY && currentScrollY > 80) {
        setScrollDirection('down');
      } else if (currentScrollY < lastScrollY) {
        setScrollDirection('up');
      }

      setLastScrollY(currentScrollY);
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, [lastScrollY]);

  const isVisible = isAtTop || scrollDirection === 'up';

  return (
    <>
      {/* Main navbar - AgendaPro smart behavior */}
      <motion.header
        initial={{ y: 0 }}
        animate={{
          y: isVisible ? 0 : -100,
        }}
        transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
        className="fixed top-0 left-0 right-0 z-50 flex justify-center px-4 pt-4"
      >
        <nav
          className={`flex items-center gap-1 px-5 py-4 rounded-full transition-all duration-300 ${
            isAtTop
              ? 'bg-transparent shadow-none border-transparent'
              : 'bg-surface/95 backdrop-blur-xl shadow-lg shadow-black/5 border border-black/10'
          }`}
        >
          {/* Logo */}
          <a href="#" className="flex items-center pl-1 pr-4 group">
            <PagateLogo className="h-8 lg:h-9 group-hover:scale-105 transition-transform" />
          </a>

          {/* Desktop nav */}
          <div className="hidden lg:flex items-center">
            {links.map((link) => (
              <a
                key={link.href}
                href={link.href}
                className={`flex items-center gap-1 px-4 py-2 rounded-full text-sm font-medium transition-all ${
                  isAtTop
                    ? 'text-text-secondary hover:text-text-primary hover:bg-white/60'
                    : 'text-text-secondary hover:text-text-primary hover:bg-surface-secondary'
                }`}
              >
                {link.label}
                {link.hasDropdown && (
                  <ChevronDown className="w-3.5 h-3.5 opacity-50" />
                )}
              </a>
            ))}
          </div>

          {/* Divider */}
          <div className="hidden lg:block w-px h-6 bg-border mx-1" />

          {/* Desktop CTAs */}
          <div className="hidden lg:flex items-center gap-1 pr-1">
            <a
              href="#cta"
              className={`px-4 py-2 rounded-full text-sm font-medium transition-all ${
                isAtTop
                  ? 'text-text-secondary hover:text-text-primary hover:bg-white/60'
                  : 'text-text-secondary hover:text-text-primary hover:bg-surface-secondary'
              }`}
            >
              Iniciar sesión
            </a>
            <a
              href="#cta"
              className="inline-flex items-center justify-center px-5 py-2.5 rounded-full bg-brand text-white text-sm font-semibold shadow-md shadow-brand/20 hover:bg-brand-dark hover:shadow-brand/30 transition-all"
            >
              Empieza gratis
            </a>
          </div>

          {/* Mobile toggle */}
          <button
            className={`lg:hidden p-2 rounded-full transition-colors ${
              isAtTop ? 'hover:bg-white/60' : 'hover:bg-surface-secondary'
            }`}
            onClick={() => setMobileOpen(!mobileOpen)}
            aria-label="Toggle menu"
          >
            {mobileOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
          </button>
        </nav>
      </motion.header>

      {/* Mobile menu */}
      <AnimatePresence>
        {mobileOpen && (
          <motion.div
            initial={{ opacity: 0, y: -10, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -10, scale: 0.95 }}
            transition={{ duration: 0.2 }}
            className="fixed top-24 left-4 right-4 z-40 lg:hidden bg-surface rounded-2xl shadow-xl border border-border overflow-hidden"
          >
            <div className="px-4 py-4 space-y-1">
              {links.map((link) => (
                <a
                  key={link.href}
                  href={link.href}
                  onClick={() => setMobileOpen(false)}
                  className="flex items-center justify-between px-4 py-3 rounded-xl text-base font-medium text-text-secondary hover:text-text-primary hover:bg-surface-secondary transition-all"
                >
                  {link.label}
                  {link.hasDropdown && (
                    <ChevronDown className="w-4 h-4 opacity-50" />
                  )}
                </a>
              ))}
              <div className="pt-3 mt-3 border-t border-border flex flex-col gap-2">
                <a
                  href="#cta"
                  onClick={() => setMobileOpen(false)}
                  className="text-center px-4 py-3 rounded-xl text-sm font-medium text-text-secondary hover:bg-surface-secondary transition-colors"
                >
                  Iniciar sesión
                </a>
                <a
                  href="#cta"
                  onClick={() => setMobileOpen(false)}
                  className="inline-flex items-center justify-center px-5 py-3 rounded-xl bg-brand text-white text-sm font-semibold shadow-md shadow-brand/20"
                >
                  Empieza gratis
                </a>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
