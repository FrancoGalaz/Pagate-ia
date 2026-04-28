import { useEffect, useRef } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

gsap.registerPlugin(ScrollTrigger);

const stats = [
  { value: '$42.8k', label: 'Valor hora promedio calculado', suffix: '' },
  { value: '150', label: 'Horas facturadas al mes', suffix: 'M+' },
  { value: '8.500', label: 'Freelancers activos', suffix: '+' },
  { value: '98', label: 'Satisfacción de usuarios', suffix: '%' },
];

export default function Stats() {
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
      gsap.from('.stat-card', {
        y: 50,
        opacity: 0,
        duration: 0.8,
        stagger: 0.15,
        ease: 'power3.out',
        scrollTrigger: {
          trigger: sectionRef.current,
          start: 'top 80%',
        },
      });

      // Counter animation
      const counters = document.querySelectorAll('.stat-value');
      counters.forEach((counter) => {
        const target = counter.getAttribute('data-value') || '0';
        
        gsap.from(counter, {
          textContent: 0,
          duration: 2,
          ease: 'power2.out',
          snap: { textContent: 1 },
          scrollTrigger: {
            trigger: counter,
            start: 'top 85%',
          },
          onUpdate: function() {
            const current = Math.floor(parseFloat(counter.textContent || '0'));
            if (target.includes('$')) {
              counter.textContent = '$' + current + 'k';
            } else {
              counter.textContent = current.toString();
            }
          },
        });
      });
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section ref={sectionRef} className="py-20 bg-surface border-y border-border/50 relative overflow-hidden">
      {/* Background gradient */}
      <div className="absolute inset-0 bg-gradient-to-r from-brand/5 via-transparent to-accent/5" />

      <div className="max-w-7xl mx-auto px-6 lg:px-8 relative">
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-6 lg:gap-8">
          {stats.map((stat) => (
            <div
              key={stat.label}
              className="stat-card group relative bg-white rounded-2xl p-6 lg:p-8 border border-border/50 hover:border-brand/20 hover:shadow-lg hover:shadow-brand/5 transition-all duration-300"
            >
              {/* Gradient accent on hover */}
              <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-brand to-accent rounded-t-2xl opacity-0 group-hover:opacity-100 transition-opacity" />
              
              <div className="stat-value font-display font-bold text-4xl lg:text-5xl text-text-primary mb-2" data-value={stat.value}>
                {stat.value}
              </div>
              <p className="text-sm text-text-secondary font-medium leading-snug">
                {stat.label}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
