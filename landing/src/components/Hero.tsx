import { useEffect, useRef } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { ArrowRight, Play, TrendingUp, Wallet, Package, Clock } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

export default function Hero() {
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
      const tl = gsap.timeline({ defaults: { ease: 'power3.out' } });

      tl.from('.hero-badge', { y: 30, opacity: 0, duration: 0.8 }, 0.2)
        .from('.hero-title', { y: 60, opacity: 0, duration: 1.2 }, 0.4)
        .from('.hero-subtitle', { y: 40, opacity: 0, duration: 1 }, 0.6)
        .from('.hero-buttons', { y: 30, opacity: 0, duration: 0.8 }, 0.8)
        .from('.hero-visual', { scale: 0.85, opacity: 0, duration: 1.4 }, 0.5);

      // Floating cards with more dramatic animation
      gsap.to('.float-card-1', {
        y: -20,
        x: 5,
        rotation: 2,
        duration: 4,
        ease: 'sine.inOut',
        repeat: -1,
        yoyo: true,
      });

      gsap.to('.float-card-2', {
        y: 20,
        x: -5,
        rotation: -2,
        duration: 5,
        ease: 'sine.inOut',
        repeat: -1,
        yoyo: true,
        delay: 1,
      });

      // Decorative elements pulse
      gsap.to('.decor-ring', {
        scale: 1.05,
        opacity: 0.6,
        duration: 3,
        ease: 'sine.inOut',
        repeat: -1,
        yoyo: true,
      });
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section
      ref={sectionRef}
      className="relative min-h-[100svh] flex items-center overflow-hidden"
    >
      {/* Animated gradient background */}
      <div className="absolute inset-0 -z-10">
        <div className="absolute top-[-20%] left-1/2 -translate-x-1/2 w-[1400px] h-[900px] bg-gradient-to-b from-brand/8 via-transparent to-transparent rounded-full blur-3xl" />
        <div className="absolute bottom-[-10%] right-[-10%] w-[700px] h-[700px] bg-gradient-to-tl from-accent/8 via-transparent to-transparent rounded-full blur-3xl" />
        <div className="absolute top-[40%] left-[-10%] w-[500px] h-[500px] bg-gradient-to-br from-brand/5 via-transparent to-transparent rounded-full blur-3xl" />
      </div>

      <div className="max-w-7xl mx-auto px-6 lg:px-8 w-full py-24 lg:py-0">
        <div className="grid lg:grid-cols-2 gap-16 lg:gap-20 items-center">
          {/* Text */}
          <div className="max-w-2xl">
            <div className="hero-badge inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-brand-light text-brand-dark text-sm font-semibold mb-10 border border-brand/10">
              <span className="relative flex h-2.5 w-2.5">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-brand opacity-75" />
                <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-brand" />
              </span>
              Ahora disponible en versión beta
            </div>

            <h1 className="hero-title font-display text-6xl lg:text-7xl xl:text-[5.5rem] font-bold leading-[0.95] tracking-[-0.03em] text-text-primary">
              Conoce tu{' '}
              <span className="relative inline-block">
                <span className="relative z-10 text-brand">verdadero valor</span>
                <span className="absolute bottom-2 left-0 w-full h-4 bg-brand/10 -z-0 rounded-sm" />
              </span>{' '}
              y gestiona tu negocio
            </h1>

            <p className="hero-subtitle mt-8 text-xl lg:text-2xl text-text-secondary leading-relaxed max-w-lg">
              Pagate calcula cuánto vale realmente tu hora, controla tu inventario
              y organiza tus finanzas para que tomes decisiones con claridad.
            </p>

            <div className="hero-buttons mt-12 flex flex-wrap items-center gap-4">
              <a
                href="#cta"
                className="group inline-flex items-center gap-3 px-8 py-4 rounded-full bg-brand text-white font-semibold text-base shadow-xl shadow-brand/25 hover:bg-brand-dark hover:shadow-brand/40 transition-all hover:scale-105 active:scale-95"
              >
                Crear cuenta gratis
                <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
              </a>
              <a
                href="#how-it-works"
                className="group inline-flex items-center gap-3 px-6 py-4 rounded-full bg-white text-text-primary font-semibold text-base border border-border hover:border-brand/30 hover:bg-brand-subtle transition-all"
              >
                <span className="w-10 h-10 rounded-full bg-brand/10 flex items-center justify-center group-hover:bg-brand/20 transition-colors">
                  <Play className="w-4 h-4 text-brand ml-0.5" />
                </span>
                Ver cómo funciona
              </a>
            </div>

            <p className="mt-8 text-sm text-text-muted">
              Sin tarjeta de crédito · Configuración en 2 minutos
            </p>
          </div>

          {/* Visual mockup */}
          <div className="hero-visual relative lg:h-[650px] flex items-center justify-center">
            {/* Decorative rings */}
            <div className="decor-ring absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[550px] h-[550px] border border-brand/10 rounded-full -z-10" />
            <div className="decor-ring absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[450px] h-[450px] border border-accent/10 rounded-full -z-10" style={{ animationDelay: '1s' }} />
            <div className="decor-ring absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[350px] h-[350px] border border-brand/5 rounded-full -z-10" style={{ animationDelay: '2s' }} />

            {/* Phone mockup frame */}
            <div className="relative z-10 w-[280px] lg:w-[320px] bg-text-primary rounded-[3.5rem] p-3 shadow-2xl shadow-text-primary/25 hover:shadow-text-primary/30 transition-shadow duration-500">
              <div className="bg-bg rounded-[3rem] overflow-hidden aspect-[9/19.5] relative">
                {/* App content */}
                <div className="absolute inset-0 p-5">
                  {/* Status bar */}
                  <div className="flex justify-between items-center text-[11px] text-text-primary mb-8">
                    <span className="font-semibold">9:41</span>
                    <div className="flex gap-1.5">
                      <div className="w-4 h-4 bg-text-primary rounded-full" />
                      <div className="w-4 h-4 bg-text-primary rounded-full opacity-60" />
                    </div>
                  </div>
                  
                  {/* App header */}
                  <div className="flex items-center gap-3 mb-8">
                    <div className="w-10 h-10 rounded-xl bg-brand flex items-center justify-center shadow-lg shadow-brand/30">
                      <span className="text-white text-sm font-bold">P</span>
                    </div>
                    <div>
                      <p className="text-sm font-bold">Pagate</p>
                      <p className="text-[11px] text-text-muted">Resumen mensual</p>
                    </div>
                    <div className="ml-auto px-3 py-1 rounded-full bg-success/10 text-success text-[10px] font-bold">
                      +12.5%
                    </div>
                  </div>

                  {/* Stats cards */}
                  <div className="space-y-3">
                    <div className="bg-surface rounded-2xl p-4 shadow-sm border border-border/50">
                      <div className="flex items-center gap-2 mb-2">
                        <div className="w-6 h-6 rounded-lg bg-brand/10 flex items-center justify-center">
                          <TrendingUp className="w-3 h-3 text-brand" />
                        </div>
                        <p className="text-[10px] text-text-muted font-medium">Valor hora real</p>
                      </div>
                      <p className="text-2xl font-bold text-brand">$42.800</p>
                    </div>
                    
                    <div className="bg-surface rounded-2xl p-4 shadow-sm border border-border/50">
                      <div className="flex items-center gap-2 mb-2">
                        <div className="w-6 h-6 rounded-lg bg-accent/10 flex items-center justify-center">
                          <Wallet className="w-3 h-3 text-accent" />
                        </div>
                        <p className="text-[10px] text-text-muted font-medium">Ingresos netos</p>
                      </div>
                      <p className="text-2xl font-bold text-text-primary">$1.284.000</p>
                    </div>
                    
                    <div className="grid grid-cols-2 gap-3">
                      <div className="bg-surface rounded-2xl p-3 shadow-sm border border-border/50">
                        <div className="w-6 h-6 rounded-lg bg-text-primary/5 flex items-center justify-center mb-2">
                          <Package className="w-3 h-3 text-text-secondary" />
                        </div>
                        <p className="text-[10px] text-text-muted">Inventario</p>
                        <p className="text-lg font-bold">87</p>
                      </div>
                      <div className="bg-surface rounded-2xl p-3 shadow-sm border border-border/50">
                        <div className="w-6 h-6 rounded-lg bg-text-primary/5 flex items-center justify-center mb-2">
                          <Clock className="w-3 h-3 text-text-secondary" />
                        </div>
                        <p className="text-[10px] text-text-muted">Horas</p>
                        <p className="text-lg font-bold">126h</p>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Video play overlay - appears on hover */}
                <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent opacity-0 hover:opacity-100 transition-opacity duration-500 cursor-pointer flex items-end justify-center pb-16">
                  <div className="w-14 h-14 rounded-full bg-white/90 backdrop-blur-sm flex items-center justify-center shadow-lg hover:scale-110 transition-transform">
                    <Play className="w-5 h-5 text-brand ml-1" />
                  </div>
                </div>
              </div>
            </div>

            {/* Floating decoration cards */}
            <div className="float-card-1 absolute top-8 -right-8 lg:right-[-2rem] z-20 bg-surface rounded-2xl shadow-xl shadow-text-primary/5 border border-border/50 p-4 hidden lg:block">
              <div className="flex items-center gap-3">
                <div className="w-11 h-11 rounded-full bg-accent/10 flex items-center justify-center">
                  <Wallet className="w-5 h-5 text-accent" />
                </div>
                <div>
                  <p className="text-[11px] text-text-muted font-medium">Meta mensual</p>
                  <p className="text-sm font-bold text-text-primary">92% alcanzado</p>
                </div>
              </div>
            </div>

            <div className="float-card-2 absolute bottom-12 -left-8 lg:left-[-2rem] z-20 bg-surface rounded-2xl shadow-xl shadow-text-primary/5 border border-border/50 p-4 hidden lg:block">
              <div className="flex items-center gap-3">
                <div className="w-11 h-11 rounded-full bg-success/10 flex items-center justify-center">
                  <TrendingUp className="w-5 h-5 text-success" />
                </div>
                <div>
                  <p className="text-[11px] text-text-muted font-medium">Productividad</p>
                  <p className="text-sm font-bold text-text-primary">+24% este mes</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
