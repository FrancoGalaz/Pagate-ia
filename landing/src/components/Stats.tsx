import { motion } from 'framer-motion';
import { useInView } from 'framer-motion';
import { useRef } from 'react';

const stats = [
  { value: '$42.8k', label: 'Valor hora promedio calculado', suffix: '' },
  { value: '150', label: 'Horas facturadas al mes', suffix: 'M+' },
  { value: '8.500', label: 'Freelancers activos', suffix: '+' },
  { value: '98', label: 'Satisfacción de usuarios', suffix: '%' },
];

function AnimatedNumber({ value, suffix }: { value: string; suffix: string }) {
  return (
    <span className="font-display font-bold text-4xl lg:text-5xl text-text-primary">
      {value}
      <span className="text-brand">{suffix}</span>
    </span>
  );
}

export default function Stats() {
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: '-100px' });

  return (
    <section ref={ref} className="py-16 bg-surface border-y border-border/50">
      <div className="max-w-7xl mx-auto px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.6 }}
          className="grid grid-cols-2 lg:grid-cols-4 gap-8 lg:gap-12"
        >
          {stats.map((stat, index) => (
            <motion.div
              key={stat.label}
              initial={{ opacity: 0, y: 20 }}
              animate={isInView ? { opacity: 1, y: 0 } : {}}
              transition={{ duration: 0.5, delay: index * 0.1 }}
              className="text-center"
            >
              <AnimatedNumber value={stat.value} suffix={stat.suffix} />
              <p className="mt-2 text-sm text-text-secondary font-medium">{stat.label}</p>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
