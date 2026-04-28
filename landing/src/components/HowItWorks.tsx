import { useEffect, useRef } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { User, Settings, Lightbulb } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

const steps = [
  {
    number: '01',
    icon: User,
    title: 'Crea tu perfil',
    description: 'Regístrate en menos de 2 minutos. Ingresa tus costos fijos, metas de ingreso y tipo de actividad.',
    color: 'bg-brand',
  },
  {
    number: '02',
    icon: Settings,
    title: 'Configura tu operación',
    description: 'Añade tu inventario, define servicios y conecta tus fuentes de ingreso para un seguimiento completo.',
    color: 'bg-accent',
  },
  {
    number: '03',
    icon: Lightbulb,
    title: 'Toma decisiones con datos',
    description: 'Obtén tu valor hora real, visualiza métricas clave y descubre oportunidades para optimizar tu negocio.',
    color: 'bg-blue-500',
  },
];

export default function HowItWorks() {
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
      gsap.from('.hiw-title', {
        y: 50,
        opacity: 0,
        duration: 1,
        ease: 'power3.out',
        scrollTrigger: {
          trigger: sectionRef.current,
          start: 'top 80%',
        },
      });

      gsap.from('.hiw-step', {
        y: 60,
        opacity: 0,
        duration: 0.8,
        stagger: 0.2,
        ease: 'power3.out',
        scrollTrigger: {
          trigger: '.hiw-steps',
          start: 'top 80%',
        },
      });

      // Line animation
      gsap.from('.hiw-line', {
        scaleX: 0,
        duration: 1.5,
        ease: 'power3.inOut',
        scrollTrigger: {
          trigger: '.hiw-steps',
          start: 'top 75%',
        },
      });
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section ref={sectionRef} id="how-it-works" className="py-24 lg:py-32 bg-surface relative overflow-hidden">
      <div className="max-w-7xl mx-auto px-6 lg:px-8">
        {/* Header */}
        <div className="hiw-title text-center max-w-3xl mx-auto mb-20">
          <span className="inline-block px-4 py-1.5 rounded-full bg-brand-light text-brand-dark text-sm font-semibold mb-4 border border-brand/10">
            En 3 pasos
          </span>
          <h2 className="font-display text-4xl lg:text-5xl font-bold tracking-tight text-text-primary">
            Empieza a trabajar{' '}
            <span className="text-brand">más inteligente</span>
          </h2>
          <p className="mt-4 text-lg text-text-secondary">
            No necesitas ser experto en finanzas. Pagate hace los cálculos por ti.
          </p>
        </div>

        {/* Steps */}
        <div className="hiw-steps relative">
          {/* Connecting line - desktop only */}
          <div className="hiw-line hidden md:block absolute top-16 left-[16.67%] right-[16.67%] h-0.5 bg-gradient-to-r from-brand via-accent to-blue-500 origin-left" />

          <div className="grid md:grid-cols-3 gap-12 lg:gap-16 relative">
            {steps.map((step) => {
              const Icon = step.icon;
              return (
                <div key={step.number} className="hiw-step relative text-center">
                  {/* Number badge */}
                  <div className="relative z-10 inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-white shadow-lg shadow-brand/10 mb-8">
                    <Icon className="w-7 h-7 text-brand" />
                    <span className={`absolute -top-2 -right-2 w-6 h-6 ${step.color} text-white text-xs font-bold rounded-full flex items-center justify-center`}>
                      {step.number}
                    </span>
                  </div>

                  <h3 className="font-display text-xl font-bold text-text-primary mb-3">
                    {step.title}
                  </h3>
                  <p className="text-text-secondary leading-relaxed max-w-xs mx-auto">
                    {step.description}
                  </p>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}
