import { motion, useInView } from 'framer-motion';
import { useRef } from 'react';
import { Calculator, Package, PieChart, User, ArrowRight } from 'lucide-react';

const features = [
  {
    icon: Calculator,
    title: 'Calculadora de Valor Hora',
    description:
      'Descubre cuánto debes cobrar realmente por tu tiempo considerando gastos fijos, variables y tus metas de ingreso.',
    color: 'bg-brand-light text-brand',
    border: 'border-brand/10',
    href: '#cta',
  },
  {
    icon: Package,
    title: 'Control de Inventario',
    description:
      'Registra productos, monitorea stock en tiempo real y recibe alertas antes de quedarte sin unidades.',
    color: 'bg-accent-light text-accent',
    border: 'border-accent/10',
    href: '#cta',
  },
  {
    icon: PieChart,
    title: 'Gestión Financiera',
    description:
      'Visualiza ingresos, egresos y rentabilidad en dashboards claros que te ayudan a tomar mejores decisiones.',
    color: 'bg-blue-50 text-blue-600',
    border: 'border-blue-100',
    href: '#cta',
  },
  {
    icon: User,
    title: 'Perfil Profesional',
    description:
      'Centraliza tu información profesional, servicios y tarifas en un solo lugar para compartir con clientes.',
    color: 'bg-purple-50 text-purple-600',
    border: 'border-purple-100',
    href: '#cta',
  },
];

export default function Features() {
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: '-80px' });

  return (
    <section id="features" ref={ref} className="py-24 lg:py-32 bg-bg">
      <div className="max-w-7xl mx-auto px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.6 }}
          className="text-center max-w-3xl mx-auto mb-16"
        >
          <span className="inline-block px-4 py-1.5 rounded-full bg-brand-light text-brand-dark text-sm font-semibold mb-4 border border-brand/10">
            Funcionalidades
          </span>
          <h2 className="font-display text-4xl lg:text-5xl font-bold tracking-tight text-text-primary">
            Todo lo que necesitas para{' '}
            <span className="text-brand">crecer</span>
          </h2>
          <p className="mt-4 text-lg text-text-secondary">
            Herramientas pensadas para freelancers y pymes que quieren dejar de adivinar y empezar a medir.
          </p>
        </motion.div>

        <div className="grid md:grid-cols-2 gap-6 lg:gap-8">
          {features.map((feature, index) => (
            <motion.a
              href={feature.href}
              key={feature.title}
              initial={{ opacity: 0, y: 30 }}
              animate={isInView ? { opacity: 1, y: 0 } : {}}
              transition={{ duration: 0.5, delay: index * 0.12 }}
              className={`group relative p-8 rounded-3xl bg-surface border ${feature.border} hover:shadow-xl hover:shadow-text-primary/5 hover:-translate-y-1 transition-all duration-300`}
            >
              <div className={`w-14 h-14 rounded-2xl ${feature.color} flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-300`}>
                <feature.icon className="w-7 h-7" />
              </div>
              <h3 className="font-display text-xl font-bold text-text-primary mb-3">
                {feature.title}
              </h3>
              <p className="text-text-secondary leading-relaxed mb-6">
                {feature.description}
              </p>
              <span className="inline-flex items-center gap-2 text-sm font-semibold text-brand group-hover:gap-3 transition-all">
                Explorar funcionalidad
                <ArrowRight className="w-4 h-4" />
              </span>
            </motion.a>
          ))}
        </div>
      </div>
    </section>
  );
}
