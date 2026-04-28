import { useEffect, useRef } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { ArrowRight, Download } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

export default function CTA() {
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
      gsap.from('.cta-content', {
        y: 50,
        opacity: 0,
        duration: 1,
        ease: 'power3.out',
        scrollTrigger: {
          trigger: sectionRef.current,
          start: 'top 80%',
        },
      });

      gsap.from('.cta-phone', {
        y: 80,
        opacity: 0,
        scale: 0.9,
        duration: 1.2,
        ease: 'power3.out',
        scrollTrigger: {
          trigger: sectionRef.current,
          start: 'top 70%',
        },
      });
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section
      ref={sectionRef}
      id="cta"
      className="py-24 lg:py-32 bg-dark-bg relative overflow-hidden"
    >
      {/* Gradient backgrounds */}
      <div className="absolute top-0 left-1/4 w-96 h-96 bg-brand/20 rounded-full blur-3xl" />
      <div className="absolute bottom-0 right-1/4 w-96 h-96 bg-accent/20 rounded-full blur-3xl" />
      
      {/* Grid pattern overlay */}
      <div className="absolute inset-0 bg-[linear-gradient(rgba(255,255,255,0.03)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.03)_1px,transparent_1px)] bg-[size:64px_64px]" />

      <div className="max-w-7xl mx-auto px-6 lg:px-8 relative">
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-20 items-center">
          {/* Text */}
          <div className="cta-content">
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 border border-white/10 text-brand-light text-sm font-semibold mb-6">
              <Download className="w-4 h-4" />
              Versión beta gratuita
            </div>

            <h2 className="font-display text-4xl lg:text-6xl font-bold tracking-tight text-white leading-[1.1]">
              Deja de{' '}
              <span className="text-brand">cobrar de menos</span>
            </h2>

            <p className="mt-6 text-lg lg:text-xl text-text-muted max-w-xl leading-relaxed">
              Únete a miles de freelancers y pymes que ya descubrieron su valor real. 
              Sin compromisos, sin tarjeta de crédito.
            </p>

            <div className="mt-10 flex flex-col sm:flex-row items-start sm:items-center gap-4">
              <a
                href="#"
                className="group inline-flex items-center gap-3 px-8 py-4 rounded-full bg-accent text-white font-semibold text-base shadow-xl shadow-accent/25 hover:bg-accent-dark hover:shadow-accent/40 transition-all hover:scale-105 active:scale-95"
              >
                Crear cuenta gratis
                <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
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
          </div>

          {/* Phone mockup */}
          <div className="cta-phone relative flex justify-center lg:justify-end">
            <div className="relative w-[260px] bg-text-primary rounded-[3rem] p-3 shadow-2xl shadow-black/40">
              <div className="bg-bg rounded-[2.5rem] overflow-hidden aspect-[9/19]">
                <div className="absolute inset-0 bg-gradient-to-b from-brand/20 via-transparent to-accent/20" />
                
                {/* App screen */}
                <div className="absolute inset-0 p-5 flex flex-col items-center justify-center">
                  <div className="w-16 h-16 rounded-2xl bg-brand flex items-center justify-center mb-4 shadow-lg shadow-brand/40">
                    <span className="text-white text-2xl font-bold">P</span>
                  </div>
                  <p className="text-lg font-bold text-text-primary mb-1">Pagate</p>
                  <p className="text-sm text-text-muted mb-6">Tu negocio, en control</p>
                  
                  <div className="w-full space-y-3">
                    <div className="bg-surface rounded-xl p-4 shadow-sm">
                      <p className="text-xs text-text-muted">Valor hora real</p>
                      <p className="text-2xl font-bold text-brand">$42.800</p>
                    </div>
                    <div className="bg-surface rounded-xl p-4 shadow-sm">
                      <p className="text-xs text-text-muted">Meta mensual</p>
                      <div className="flex items-center gap-2">
                        <div className="flex-1 h-2 bg-border rounded-full overflow-hidden">
                          <div className="h-full w-[92%] bg-accent rounded-full" />
                        </div>
                        <span className="text-sm font-bold">92%</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Floating elements */}
            <div className="absolute top-8 right-0 lg:right-8 bg-white/10 backdrop-blur-lg rounded-2xl p-4 border border-white/10 hidden lg:block">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-success/20 flex items-center justify-center">
                  <svg className="w-5 h-5 text-success" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                </div>
                <div>
                  <p className="text-xs text-white/60">Estado</p>
                  <p className="text-sm font-bold text-white">Todo en orden</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
