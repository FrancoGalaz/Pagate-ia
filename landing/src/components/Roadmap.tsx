import { useEffect, useRef } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { Rocket, Calendar, Users, Sparkles, TrendingUp, Shield } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

const roadmapItems = [
  {
    icon: Rocket,
    title: 'Integración bancaria',
    description: 'Conecta tus cuentas bancarias para sincronización automática de ingresos y egresos.',
    status: 'Próximamente',
    color: 'bg-brand',
    lightColor: 'bg-brand-light',
    textColor: 'text-brand',
  },
  {
    icon: Users,
    title: 'Gestión de clientes',
    description: 'CRM integrado para llevar seguimiento de tus clientes, proyectos y facturación por contacto.',
    status: 'En desarrollo',
    color: 'bg-accent',
    lightColor: 'bg-accent-light',
    textColor: 'text-accent',
  },
  {
    icon: Calendar,
    title: 'Calendario de proyectos',
    description: 'Planifica tus proyectos, establece deadlines y recibe alertas de tus entregas pendientes.',
    status: 'Próximamente',
    color: 'bg-blue-500',
    lightColor: 'bg-blue-50',
    textColor: 'text-blue-600',
  },
  {
    icon: Sparkles,
    title: 'IA para presupuestos',
    description: 'Inteligencia artificial que te sugiere precios óptimos basados en tu historial y el mercado.',
    status: 'En investigación',
    color: 'bg-purple-500',
    lightColor: 'bg-purple-50',
    textColor: 'text-purple-600',
  },
  {
    icon: TrendingUp,
    title: 'Reportes avanzados',
    description: 'Dashboards detallados con proyecciones financieras, análisis de tendencias y exportación a Excel/PDF.',
    status: 'Próximamente',
    color: 'bg-orange-500',
    lightColor: 'bg-orange-50',
    textColor: 'text-orange-600',
  },
  {
    icon: Shield,
    title: 'Multi-usuario y equipos',
    description: 'Invita a tu equipo, asigna roles y permisos, y colabora en proyectos compartidos.',
    status: 'En desarrollo',
    color: 'bg-green-500',
    lightColor: 'bg-green-50',
    textColor: 'text-green-600',
  },
];

export default function Roadmap() {
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
      gsap.from('.roadmap-title', {
        y: 50,
        opacity: 0,
        duration: 1,
        ease: 'power3.out',
        scrollTrigger: {
          trigger: sectionRef.current,
          start: 'top 80%',
        },
      });

      gsap.from('.roadmap-card', {
        y: 60,
        opacity: 0,
        duration: 0.8,
        stagger: 0.1,
        ease: 'power3.out',
        scrollTrigger: {
          trigger: '.roadmap-grid',
          start: 'top 85%',
        },
      });
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section ref={sectionRef} className="py-24 lg:py-32 bg-surface relative overflow-hidden">
      {/* Background decoration */}
      <div className="absolute top-0 left-0 w-[600px] h-[600px] bg-gradient-to-br from-brand/5 to-transparent rounded-full blur-3xl -translate-y-1/2 -translate-x-1/4" />
      <div className="absolute bottom-0 right-0 w-[600px] h-[600px] bg-gradient-to-tl from-accent/5 to-transparent rounded-full blur-3xl translate-y-1/2 translate-x-1/4" />

      <div className="max-w-7xl mx-auto px-6 lg:px-8 relative">
        {/* Header */}
        <div className="roadmap-title text-center max-w-3xl mx-auto mb-16">
          <span className="inline-block px-4 py-1.5 rounded-full bg-brand-light text-brand-dark text-sm font-semibold mb-4 border border-brand/10">
            Roadmap 2025
          </span>
          <h2 className="font-display text-4xl lg:text-5xl font-bold tracking-tight text-text-primary">
            Futuras{' '}
            <span className="text-brand">funcionalidades</span>
          </h2>
          <p className="mt-6 text-lg text-text-secondary">
            Estamos construyendo Pagate contigo. Esto es lo que viene próximamente.
          </p>
        </div>

        {/* Roadmap Grid */}
        <div className="roadmap-grid grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {roadmapItems.map((item) => {
            const Icon = item.icon;
            return (
              <div
                key={item.title}
                className="roadmap-card group relative bg-white rounded-2xl p-6 border border-border/50 hover:shadow-lg hover:shadow-text-primary/5 hover:-translate-y-1 transition-all duration-300"
              >
                {/* Status badge */}
                <div className="absolute top-4 right-4">
                  <span className={`inline-block px-3 py-1 rounded-full text-xs font-semibold ${item.lightColor} ${item.textColor}`}>
                    {item.status}
                  </span>
                </div>

                {/* Icon */}
                <div className={`inline-flex items-center justify-center w-12 h-12 rounded-xl ${item.lightColor} mb-4`}>
                  <Icon className={`w-6 h-6 ${item.textColor}`} />
                </div>

                {/* Content */}
                <h3 className="font-display text-lg font-bold text-text-primary mb-2 pr-20">
                  {item.title}
                </h3>
                <p className="text-sm text-text-secondary leading-relaxed">
                  {item.description}
                </p>

                {/* Progress indicator */}
                <div className="mt-4 flex items-center gap-2">
                  <div className="flex-1 h-1.5 bg-border rounded-full overflow-hidden">
                    <div
                      className={`h-full rounded-full ${item.color} opacity-60`}
                      style={{
                        width: item.status === 'En desarrollo' ? '60%' : item.status === 'En investigación' ? '30%' : '15%',
                      }}
                    />
                  </div>
                  <span className="text-xs text-text-muted font-medium">
                    {item.status === 'En desarrollo' ? '60%' : item.status === 'En investigación' ? '30%' : '15%'}
                  </span>
                </div>
              </div>
            );
          })}
        </div>

        {/* CTA */}
        <div className="mt-16 text-center">
          <p className="text-text-secondary mb-4">
            ¿Tienes una idea o sugerencia? Nos encantaría escucharte.
          </p>
          <a
            href="#"
            className="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-brand text-white font-semibold text-sm shadow-lg shadow-brand/25 hover:bg-brand-dark transition-all hover:scale-105"
          >
            Sugerir una función
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 8l4 4m0 0l-4 4m4-4H3" />
            </svg>
          </a>
        </div>
      </div>
    </section>
  );
}
