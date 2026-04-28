import { motion, useInView } from 'framer-motion';
import { useRef } from 'react';
import { UserPlus, Sliders, Rocket } from 'lucide-react';

const steps = [
  {
    number: '01',
    icon: UserPlus,
    title: 'Crea tu perfil',
    description:
      'Regístrate en menos de 2 minutos. Ingresa tus costos fijos, metas de ingreso y tipo de actividad.',
  },
  {
    number: '02',
    icon: Sliders,
    title: 'Configura tu operación',
    description:
      'Añade tu inventario, define servicios y conecta tus fuentes de ingreso para un seguimiento completo.',
  },
  {
    number: '03',
    icon: Rocket,
    title: 'Toma decisiones con datos',
    description:
      'Obtén tu valor hora real, visualiza métricas clave y descubre oportunidades para optimizar tu negocio.',
  },
];

export default function HowItWorks() {
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: '-80px' });

  return (
    <section id="how-it-works" ref={ref} className="py-24 lg:py-32 bg-surface">
      <div className="max-w-7xl mx-auto px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.6 }}
          className="text-center max-w-3xl mx-auto mb-16"
        >
          <span className="inline-block px-4 py-1.5 rounded-full bg-brand-light text-brand-dark text-sm font-semibold mb-4 border border-brand/10">
            En 3 pasos
          </span>
          <h2 className="font-display text-4xl lg:text-5xl font-bold tracking-tight text-text-primary">
            Empieza a trabajar{' '}
            <span className="text-brand">más inteligente</span>
          </h2>
          <p className="mt-4 text-lg text-text-secondary">
            No necesitas ser experto en finanzas. Pagate-ia hace los cálculos por ti.
          </p>
        </motion.div>

        <div className="grid md:grid-cols-3 gap-8 lg:gap-12 relative">
          {/* Connector line (desktop) */}
          <div className="hidden md:block absolute top-16 left-[16.67%] right-[16.67%] h-0.5 bg-border">
            <motion.div
              initial={{ scaleX: 0 }}
              animate={isInView ? { scaleX: 1 } : {}}
              transition={{ duration: 1.2, ease: 'easeInOut', delay: 0.3 }}
              className="h-full bg-brand origin-left"
            />
          </div>

          {steps.map((step, index) => (
            <motion.div
              key={step.number}
              initial={{ opacity: 0, y: 30 }}
              animate={isInView ? { opacity: 1, y: 0 } : {}}
              transition={{ duration: 0.5, delay: index * 0.2 }}
              className="relative text-center"
            >
              <div className="relative z-10 inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-brand text-white shadow-lg shadow-brand/25 mb-6">
                <step.icon className="w-7 h-7" />
              </div>
              <div className="absolute top-0 left-1/2 -translate-x-1/2 -translate-y-1/2 md:hidden">
                <span className="inline-flex items-center justify-center w-8 h-8 rounded-full bg-brand text-white text-xs font-bold">
                  {step.number}
                </span>
              </div>
              <h3 className="font-display text-xl font-bold text-text-primary mb-3">
                {step.title}
              </h3>
              <p className="text-text-secondary leading-relaxed max-w-xs mx-auto">
                {step.description}
              </p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
