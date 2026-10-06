// Marco común de las tres páginas legales de la landing.
//
// No reutiliza el Navbar ni el Footer de la portada a propósito: esas piezas
// arrastran GSAP, Framer Motion y Lenis, y estas páginas tienen que abrirse
// rápido y sin JavaScript decorativo. Un revisor de Google Play las visita
// desde la ficha, a veces con mala conexión, y lo único que necesita es leer.

import type { ReactNode } from 'react';
import PagateLogo from '../components/PagateLogo';
import {
  APP_NAME,
  LEGAL_ROUTES,
  LEGAL_VERSION,
  siteUrl,
} from '../content/legal-meta';

interface LegalLayoutProps {
  /** Título visible y encabezado de nivel 1 de la página. */
  title: string;
  /** Resumen de una o dos frases que se muestra bajo el título. */
  intro: string;
  children: ReactNode;
}

/** Enlaces cruzados entre las tres páginas legales. */
const legalNav = [
  { label: 'Política de privacidad', href: siteUrl(LEGAL_ROUTES.privacidad) },
  { label: 'Términos de servicio', href: siteUrl(LEGAL_ROUTES.terminos) },
  { label: 'Eliminar cuenta y datos', href: siteUrl(LEGAL_ROUTES.eliminarCuenta) },
];

export default function LegalLayout({ title, intro, children }: LegalLayoutProps) {
  return (
    <div className="min-h-screen bg-bg font-sans text-text-primary">
      <header className="border-b border-border bg-surface">
        <div className="max-w-3xl mx-auto px-6 py-5 flex items-center justify-between gap-4">
          <a
            href={siteUrl(LEGAL_ROUTES.inicio)}
            className="flex items-center gap-2"
            aria-label={`Volver al inicio de ${APP_NAME}`}
          >
            <PagateLogo className="h-9" />
          </a>
          <a
            href={siteUrl(LEGAL_ROUTES.inicio)}
            className="text-sm font-semibold text-text-secondary hover:text-brand transition-colors"
          >
            Volver al inicio
          </a>
        </div>
      </header>

      <main className="max-w-3xl mx-auto px-6 py-12">
        <h1 className="font-display text-3xl lg:text-4xl font-bold tracking-tight">
          {title}
        </h1>
        <p className="mt-4 text-base text-text-secondary leading-relaxed">{intro}</p>
        <p className="mt-2 text-sm text-text-muted">
          Versión {LEGAL_VERSION.version} · Última actualización:{' '}
          {LEGAL_VERSION.updatedAt}
        </p>

        {/* `prose` no está disponible (no hay @tailwindcss/typography), así que
            el ritmo vertical del documento se fija aquí una sola vez. */}
        <div className="mt-10 space-y-8 text-base leading-relaxed text-text-secondary">
          {children}
        </div>
      </main>

      <footer className="border-t border-border bg-surface">
        <div className="max-w-3xl mx-auto px-6 py-8">
          <nav aria-label="Documentos legales">
            <ul className="flex flex-col sm:flex-row gap-3 sm:gap-6">
              {legalNav.map((link) => (
                <li key={link.href}>
                  <a
                    href={link.href}
                    className="text-sm text-text-secondary hover:text-brand transition-colors"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </nav>
          <p className="mt-6 text-sm text-text-muted">
            {APP_NAME} · Asistente financiero para artesanos y microemprendedores.
          </p>
        </div>
      </footer>
    </div>
  );
}

/** Sección con encabezado de nivel 2. Normaliza el espaciado del documento. */
export function LegalSection({
  id,
  title,
  children,
}: {
  id: string;
  title: string;
  children: ReactNode;
}) {
  return (
    <section id={id} className="space-y-3">
      <h2 className="font-display text-xl font-bold text-text-primary">{title}</h2>
      {children}
    </section>
  );
}

/** Lista con viñetas con el mismo estilo en todas las páginas. */
export function LegalList({ items }: { items: ReactNode[] }) {
  return (
    <ul className="list-disc pl-6 space-y-2">
      {items.map((item, i) => (
        // Los elementos son texto fijo redactado a mano, no datos que se
        // reordenen: el índice como key es estable aquí.
        <li key={i}>{item}</li>
      ))}
    </ul>
  );
}
