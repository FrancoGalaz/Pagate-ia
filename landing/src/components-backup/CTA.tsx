import { motion, useInView } from 'framer-motion';
import { useRef } from 'react';
import { ArrowRight, Sparkles } from 'lucide-react';

export default function CTA() {
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: '-80px' });

  return (
    <section id="cta" ref={ref} className="py-24 lg:py-32 bg-dark-bg relative overflow-hidden">
      {/* Decorative blur orbs */}
      <div className="absolute top-0 left-1/4 w-96 h-96 bg-brand/10 rounded-full blur-3xl" />
      <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-accent/10 rounded-full blur-3xl" />

      <div className="max-w-4xl mx-auto px-6 lg:px-8 text-center relative z-10">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.6 }}
        >
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 border border-white/10 text-brand-light text-sm font-semibold mb-6">
            <Sparkles className="w-4 h-4" />
            Versión beta gratuita
          </div>

          <h2 className="font-display text-4xl lg:text-6xl font-bold tracking-tight text-white">
            Deja de{' '}
            <span className="text-brand">cobrar de menos</span>
          </h2>

          <p className="mt-6 text-lg lg:text-xl text-text-muted max-w-2xl mx-auto leading-relaxed">
            Únete a miles de freelancers y pymes que ya descubrieron su valor real.
            Sin compromisos, sin tarjeta de crédito.
          </p>

          <div className="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
            <a
              href="#"
              className="inline-flex items-center gap-2 px-8 py-4 rounded-full bg-accent text-white font-semibold text-base shadow-xl shadow-accent/25 hover:bg-accent-dark hover:shadow-accent/40 hover:-translate-y-0.5 transition-all"
            >
              Crear cuenta gratis
              <ArrowRight className="w-5 h-5" />
            </a>
            <a
              href="#features"
              className="inline-flex items-center gap-2 px-8 py-4 rounded-full bg-white/5 text-white font-semibold text-base border border-white/10 hover:bg-white/10 transition-all"
            >
              Conocer más
            </a>
          </div>

          <p className="mt-6 text-sm text-text-muted">
            Configuración en 2 minutos · Cancela cuando quieras
          </p>
        </motion.div>
      </div>
    </section>
  );
}
