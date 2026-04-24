import { motion } from 'framer-motion';
import { ArrowRight, Play, TrendingUp, Wallet, Package } from 'lucide-react';
import PagateLogo from './PagateLogo';

const easeOutExpo = [0.22, 1, 0.36, 1] as [number, number, number, number];

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.15, delayChildren: 0.2 },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 30 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.7, ease: easeOutExpo } },
};

export default function Hero() {
  return (
    <section className="relative pt-28 pb-20 lg:pt-32 lg:pb-28 overflow-hidden">
      {/* Background subtle pattern */}
      <div className="absolute inset-0 -z-10">
        <div className="absolute top-0 right-0 w-[600px] h-[600px] bg-brand/5 rounded-full blur-3xl -translate-y-1/2 translate-x-1/3" />
        <div className="absolute bottom-0 left-0 w-[500px] h-[500px] bg-accent/5 rounded-full blur-3xl translate-y-1/3 -translate-x-1/4" />
      </div>

      <div className="max-w-7xl mx-auto px-6 lg:px-8">
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-16 items-center">
          {/* Text */}
          <motion.div
            variants={containerVariants}
            initial="hidden"
            animate="visible"
          >
            <motion.div
              variants={itemVariants}
              className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-brand-light text-brand-dark text-sm font-semibold mb-6 border border-brand/10"
            >
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-brand opacity-75" />
                <span className="relative inline-flex rounded-full h-2 w-2 bg-brand" />
              </span>
              Ahora disponible en versión beta
            </motion.div>

            <motion.h1
              variants={itemVariants}
              className="font-display text-5xl lg:text-6xl xl:text-7xl font-bold leading-[1.1] tracking-tight text-text-primary"
            >
              Conoce tu{' '}
              <span className="text-brand">verdadero valor</span>{' '}
              y gestiona tu negocio
            </motion.h1>

            <motion.p
              variants={itemVariants}
              className="mt-6 text-lg lg:text-xl text-text-secondary leading-relaxed max-w-xl"
            >
              Pagate calcula cuánto vale realmente tu hora, controla tu inventario
              y organiza tus finanzas para que tomes decisiones con claridad.
            </motion.p>

            <motion.div
              variants={itemVariants}
              className="mt-10 flex flex-wrap items-center gap-4"
            >
              <a
                href="#cta"
                className="inline-flex items-center gap-2 px-8 py-4 rounded-full bg-brand text-white font-semibold text-base shadow-xl shadow-brand/25 hover:bg-brand-dark hover:shadow-brand/40 hover:-translate-y-0.5 transition-all"
              >
                Crear cuenta gratis
                <ArrowRight className="w-5 h-5" />
              </a>
              <a
                href="#how-it-works"
                className="inline-flex items-center gap-2 px-6 py-4 rounded-full bg-surface text-text-primary font-semibold text-base border border-border hover:border-brand/30 hover:bg-brand-subtle transition-all"
              >
                <Play className="w-5 h-5 text-brand" />
                Ver cómo funciona
              </a>
            </motion.div>

            <motion.p variants={itemVariants} className="mt-6 text-sm text-text-muted">
              Sin tarjeta de crédito · Configuración en 2 minutos
            </motion.p>
          </motion.div>

          {/* Visual mockup */}
          <motion.div
            initial={{ opacity: 0, scale: 0.9, x: 40 }}
            animate={{ opacity: 1, scale: 1, x: 0 }}
            transition={{ duration: 0.9, ease: easeOutExpo, delay: 0.3 }}
            className="relative"
          >
            <div className="relative z-10 bg-surface rounded-3xl shadow-2xl shadow-text-primary/5 border border-border/50 p-6 lg:p-8">
              {/* Header mock */}
              <div className="flex items-center justify-between mb-8">
                <div className="flex items-center gap-3">
                  <PagateLogo className="w-10 h-10" />
                  <div>
                    <p className="text-sm font-semibold text-text-primary">Resumen mensual</p>
                    <p className="text-xs text-text-muted">Abril 2026</p>
                  </div>
                </div>
                <div className="px-3 py-1 rounded-full bg-success/10 text-success text-xs font-semibold">
                  +12.5%
                </div>
              </div>

              {/* Cards */}
              <div className="grid grid-cols-2 gap-4">
                <div className="p-4 rounded-2xl bg-brand-light border border-brand/10">
                  <div className="w-8 h-8 rounded-lg bg-brand/10 flex items-center justify-center mb-3">
                    <TrendingUp className="w-4 h-4 text-brand" />
                  </div>
                  <p className="text-xs text-text-secondary font-medium">Valor hora real</p>
                  <p className="text-xl font-display font-bold text-text-primary mt-1">$42.800</p>
                </div>
                <div className="p-4 rounded-2xl bg-accent-light border border-accent/10">
                  <div className="w-8 h-8 rounded-lg bg-accent/10 flex items-center justify-center mb-3">
                    <Wallet className="w-4 h-4 text-accent" />
                  </div>
                  <p className="text-xs text-text-secondary font-medium">Ingresos netos</p>
                  <p className="text-xl font-display font-bold text-text-primary mt-1">$1.284.000</p>
                </div>
                <div className="p-4 rounded-2xl bg-surface-secondary border border-border">
                  <div className="w-8 h-8 rounded-lg bg-text-primary/5 flex items-center justify-center mb-3">
                    <Package className="w-4 h-4 text-text-secondary" />
                  </div>
                  <p className="text-xs text-text-secondary font-medium">Inventario</p>
                  <p className="text-xl font-display font-bold text-text-primary mt-1">87 items</p>
                </div>
                <div className="p-4 rounded-2xl bg-surface-secondary border border-border">
                  <div className="w-8 h-8 rounded-lg bg-text-primary/5 flex items-center justify-center mb-3">
                    <svg className="w-4 h-4 text-text-secondary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  </div>
                  <p className="text-xs text-text-secondary font-medium">Horas facturadas</p>
                  <p className="text-xl font-display font-bold text-text-primary mt-1">126 h</p>
                </div>
              </div>

              {/* Mini chart bar */}
              <div className="mt-6">
                <div className="flex items-end justify-between gap-2 h-24">
                  {[40, 65, 45, 80, 55, 90, 70].map((h, i) => (
                    <div
                      key={i}
                      className="flex-1 rounded-t-lg bg-brand/10 hover:bg-brand/30 transition-colors"
                      style={{ height: `${h}%` }}
                    />
                  ))}
                </div>
                <div className="flex justify-between mt-2 text-[10px] text-text-muted">
                  <span>Lun</span><span>Mar</span><span>Mie</span><span>Jue</span><span>Vie</span><span>Sab</span><span>Dom</span>
                </div>
              </div>
            </div>

            {/* Floating decoration cards */}
            <motion.div
              animate={{ y: [0, -10, 0] }}
              transition={{ duration: 4, repeat: Infinity, ease: 'easeInOut' }}
              className="absolute -top-6 -right-6 bg-surface rounded-2xl shadow-xl shadow-text-primary/5 border border-border/50 p-4 hidden lg:block"
            >
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-success/10 flex items-center justify-center">
                  <TrendingUp className="w-5 h-5 text-success" />
                </div>
                <div>
                  <p className="text-xs text-text-muted">Productividad</p>
                  <p className="text-sm font-bold text-text-primary">+24% este mes</p>
                </div>
              </div>
            </motion.div>

            <motion.div
              animate={{ y: [0, 10, 0] }}
              transition={{ duration: 5, repeat: Infinity, ease: 'easeInOut', delay: 1 }}
              className="absolute -bottom-4 -left-8 bg-surface rounded-2xl shadow-xl shadow-text-primary/5 border border-border/50 p-4 hidden lg:block"
            >
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-accent/10 flex items-center justify-center">
                  <Wallet className="w-5 h-5 text-accent" />
                </div>
                <div>
                  <p className="text-xs text-text-muted">Meta mensual</p>
                  <p className="text-sm font-bold text-text-primary">92% alcanzado</p>
                </div>
              </div>
            </motion.div>
          </motion.div>
        </div>
      </div>
    </section>
  );
}

