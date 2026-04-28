import { useEffect, useRef } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { ArrowRight, Play } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

export default function Hero() {
  const sectionRef = useRef<HTMLElement>(null);
  const textRef = useRef<HTMLDivElement>(null);
  const visualRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
      // Entrance animations
      gsap.from('.hero-badge', {
        y: 20,
        opacity: 0,
        duration: 0.8,
        ease: 'power3.out',
        delay: 0.2,
      });

      gsap.from('.hero-title', {
        y: 40,
        opacity: 0,
        duration: 1,
        ease: 'power3.out',
        delay: 0.4,
      });

      gsap.from('.hero-subtitle', {
        y: 30,
        opacity: 0,
        duration: 0.8,
        ease: 'power3.out',
        delay: 0.6,
      });

      gsap.from('.hero-buttons', {
        y: 20,
        opacity: 0,
        duration: 0.8,
        ease: 'power3.out',
        delay: 0.8,
      });

      gsap.from('.hero-visual', {
        scale: 0.9,
        opacity: 0,
        duration: 1.2,
        ease: 'power3.out',
        delay: 0.5,
      });

      // Floating cards animation
      gsap.to('.float-card-1', {
        y: -15,
        duration: 3,
        ease: 'sine.inOut',
        repeat: -1,
        yoyo: true,
      });

      gsap.to('.float-card-2', {
        y: 15,
        duration: 4,
        ease: 'sine.inOut',
        repeat: -1,
        yoyo: true,
        delay: 1,
      });
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section
      ref={sectionRef}
      className="relative min-h-[100svh] flex items-center overflow-hidden"
    >
      {/* Background gradient */}
      <div className="absolute inset-0 -z-10">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[1200px] h-[800px] bg-gradient-to-b from-brand/5 via-transparent to-transparent rounded-full blur-3xl" />
        <div className="absolute bottom-0 right-0 w-[600px] h-[600px] bg-accent/5 rounded-full blur-3xl translate-y-1/3" />
      </div>

      <div className="max-w-7xl mx-auto px-6 lg:px-8 w-full py-20 lg:py-0">
        <div className="grid lg:grid-cols-2 gap-16 lg:gap-24 items-center">
          {/* Text */}
          <div ref={textRef} className="max-w-2xl">
            <div className="hero-badge inline-flex items-center gap-2 px-4 py-2 rounded-full bg-brand-light text-brand-dark text-sm font-semibold mb-8 border border-brand/10">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-brand opacity-75" />
                <span className="relative inline-flex rounded-full h-2 w-2 bg-brand" />
              </span>
              Ahora disponible en versión beta
            </div>

            <h1 className="hero-title font-display text-6xl lg:text-7xl xl:text-[5.5rem] font-bold leading-[0.95] tracking-[-0.03em] text-text-primary">
              Conoce tu{' '}
              <span className="text-brand">verdadero valor</span>{' '}
              y gestiona tu negocio
            </h1>

            <p className="hero-subtitle mt-8 text-xl lg:text-2xl text-text-secondary leading-relaxed max-w-lg">
              Pagate calcula cuánto vale realmente tu hora, controla tu inventario
              y organiza tus finanzas para que tomes decisiones con claridad.
            </p>

            <div className="hero-buttons mt-10 flex flex-wrap items-center gap-4">
              <a
                href="#cta"
                className="inline-flex items-center gap-2 px-8 py-4 rounded-full bg-brand text-white font-semibold text-base shadow-xl shadow-brand/25 hover:bg-brand-dark hover:shadow-brand/40 hover:-translate-y-0.5 transition-all"
              >
                Crear cuenta gratis
                <ArrowRight className="w-5 h-5" />
              </a>
              <a
                href="#how-it-works"
                className="inline-flex items-center gap-2 px-6 py-4 rounded-full bg-white text-text-primary font-semibold text-base border border-border hover:border-brand/30 hover:bg-brand-subtle transition-all"
              >
                <Play className="w-5 h-5 text-brand" />
                Ver cómo funciona
              </a>
            </div>

            <p className="mt-6 text-sm text-text-muted">
              Sin tarjeta de crédito · Configuración en 2 minutos
            </p>
          </div>

          {/* Visual mockup with video placeholder */}
          <div ref={visualRef} className="hero-visual relative lg:h-[600px] flex items-center justify-center">
            {/* Phone mockup frame */}
            <div className="relative z-10 w-[300px] lg:w-[340px] bg-text-primary rounded-[3rem] p-3 shadow-2xl shadow-text-primary/20">
              <div className="bg-bg rounded-[2.5rem] overflow-hidden aspect-[9/19]">
                {/* Video placeholder */}
                <div className="w-full h-full bg-gradient-to-b from-surface to-bg flex flex-col items-center justify-center relative">
                  {/* App screen mockup */}
                  <div className="absolute inset-0 p-4">
                    {/* Status bar */}
                    <div className="flex justify-between items-center text-[10px] text-text-primary mb-6">
                      <span>9:41</span>
                      <div className="flex gap-1">
                        <div className="w-3 h-3 bg-text-primary rounded-full" />
                        <div className="w-3 h-3 bg-text-primary rounded-full" />
                      </div>
                    </div>
                    
                    {/* App header */}
                    <div className="flex items-center gap-2 mb-6">
                      <div className="w-8 h-8 rounded-full bg-brand flex items-center justify-center">
                        <span className="text-white text-xs font-bold">P</span>
                      </div>
                      <div>
                        <p className="text-xs font-semibold">Pagate</p>
                        <p className="text-[10px] text-text-muted">Resumen</p>
                      </div>
                    </div>

                    {/* Stats cards */}
                    <div className="space-y-3">
                      <div className="bg-surface rounded-xl p-3 shadow-sm">
                        <p className="text-[10px] text-text-muted">Valor hora real</p>
                        <p className="text-lg font-bold text-brand">$42.800</p>
                      </div>
                      <div className="bg-surface rounded-xl p-3 shadow-sm">
                        <p className="text-[10px] text-text-muted">Ingresos netos</p>
                        <p className="text-lg font-bold text-text-primary">$1.284.000</p>
                      </div>
                      <div className="grid grid-cols-2 gap-2">
                        <div className="bg-surface rounded-xl p-3 shadow-sm">
                          <p className="text-[10px] text-text-muted">Inventario</p>
                          <p className="text-sm font-bold">87 items</p>
                        </div>
                        <div className="bg-surface rounded-xl p-3 shadow-sm">
                          <p className="text-[10px] text-text-muted">Horas</p>
                          <p className="text-sm font-bold">126h</p>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Video play overlay */}
                  <div className="absolute inset-0 bg-black/40 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity cursor-pointer">
                    <div className="w-16 h-16 rounded-full bg-white/90 flex items-center justify-center">
                      <Play className="w-6 h-6 text-brand ml-1" />
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Floating decoration cards */}
            <div className="float-card-1 absolute -top-4 -right-4 lg:right-0 z-20 bg-surface rounded-2xl shadow-xl shadow-text-primary/5 border border-border/50 p-4 hidden lg:block">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-accent/10 flex items-center justify-center">
                  <svg className="w-5 h-5 text-accent" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <div>
                  <p className="text-xs text-text-muted">Meta mensual</p>
                  <p className="text-sm font-bold text-text-primary">92% alcanzado</p>
                </div>
              </div>
            </div>

            <div className="float-card-2 absolute -bottom-4 -left-4 lg:left-0 z-20 bg-surface rounded-2xl shadow-xl shadow-text-primary/5 border border-border/50 p-4 hidden lg:block">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-success/10 flex items-center justify-center">
                  <svg className="w-5 h-5 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
                  </svg>
                </div>
                <div>
                  <p className="text-xs text-text-muted">Productividad</p>
                  <p className="text-sm font-bold text-text-primary">+24% este mes</p>
                </div>
              </div>
            </div>

            {/* Decorative ring */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] border border-brand/10 rounded-full -z-10" />
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[400px] h-[400px] border border-accent/10 rounded-full -z-10" />
          </div>
        </div>
      </div>
    </section>
  );
}
