// Sección «qué viene después».
//
// Dos cosas que había aquí y no deben volver: una barra de progreso con
// porcentajes (60 %, 30 %, 15 %) derivados del texto del estado, que es una
// cifra inventada presentada como medición, y el rótulo «Roadmap 2025», que
// además es un año pasado. Los estados que quedan son los únicos dos
// honestos: nada de esta lista tiene código escrito todavía, así que ninguna
// función puede figurar «en desarrollo».

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
    status: 'Previsto',
    lightColor: 'bg-brand-light',
    textColor: 'text-brand',
  },
  {
    icon: Users,
    title: 'Gestión de clientes',
    description: 'CRM integrado para llevar seguimiento de tus clientes, proyectos y facturación por contacto.',
    status: 'En evaluación',
    lightColor: 'bg-accent-light',
    textColor: 'text-accent',
  },
  {
    icon: Calendar,
    title: 'Calendario de proyectos',
    description: 'Planifica tus proyectos, establece deadlines y recibe alertas de tus entregas pendientes.',
    status: 'En evaluación',
    lightColor: 'bg-blue-50',
    textColor: 'text-blue-600',
  },
  {
    icon: Sparkles,
    title: 'IA para presupuestos',
    description: 'Inteligencia artificial que te sugiere precios óptimos basados en tu historial y el mercado.',
    status: 'En evaluación',
    lightColor: 'bg-purple-50',
    textColor: 'text-purple-600',
  },
  {
    icon: TrendingUp,
    title: 'Reportes avanzados',
    description: 'Dashboards detallados con proyecciones financieras, análisis de tendencias y exportación a Excel/PDF.',
    status: 'Previsto',
    lightColor: 'bg-orange-50',
    textColor: 'text-orange-600',
  },
  {
    icon: Shield,
    title: 'Multi-usuario y equipos',
    description: 'Invita a tu equipo, asigna roles y permisos, y colabora en proyectos compartidos.',
    status: 'En evaluación',
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
    <section ref={sectionRef} id="roadmap" className="py-24 lg:py-32 bg-surface relative overflow-hidden">
      {/* Background decoration */}
      <div className="absolute top-0 left-0 w-[600px] h-[600px] bg-gradient-to-br from-brand/5 to-transparent rounded-full blur-3xl -translate-y-1/2 -translate-x-1/4" />
      <div className="absolute bottom-0 right-0 w-[600px] h-[600px] bg-gradient-to-tl from-accent/5 to-transparent rounded-full blur-3xl translate-y-1/2 translate-x-1/4" />

      <div className="max-w-7xl mx-auto px-6 lg:px-8 relative">
        {/* Header */}
        <div className="roadmap-title text-center max-w-3xl mx-auto mb-16">
          <span className="inline-block px-4 py-1.5 rounded-full bg-brand-light text-brand-dark text-sm font-semibold mb-4 border border-brand/10">
            Qué viene después
          </span>
          <h2 className="font-display text-4xl lg:text-5xl font-bold tracking-tight text-text-primary">
            Futuras{' '}
            <span className="text-brand">funcionalidades</span>
          </h2>
          <p className="mt-6 text-lg text-text-secondary">
            Ninguna de estas funciones existe todavía. Las publicamos para que
            sepas hacia dónde va la app y puedas decirnos qué priorizar.
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
              </div>
            );
          })}
        </div>

        {/* CTA */}
        <div className="mt-16 text-center">
          {/* Antes apuntaba a `#`, un enlace muerto. El único canal que
              existe hoy es la lista de espera, así que ahí va. */}
          <p className="text-text-secondary mb-4">
            ¿Tienes una idea o una prioridad distinta? Déjanos tu correo y te
            escribimos para preguntártelo.
          </p>
          <a
            href="#cta"
            className="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-brand text-white font-semibold text-sm shadow-lg shadow-brand/25 hover:bg-brand-dark transition-all hover:scale-105"
          >
            Unirme a la lista de espera
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 8l4 4m0 0l-4 4m4-4H3" />
            </svg>
          </a>
        </div>
      </div>
    </section>
  );
}
