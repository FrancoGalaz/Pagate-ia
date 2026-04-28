import { useState, useEffect, useRef } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { TrendingUp, Wallet, Package, BarChart3, Clock, Zap } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

const features = [
  {
    id: 'valor-hora',
    icon: TrendingUp,
    label: 'Valor Hora',
    title: 'Calcula tu valor real',
    description: 'Descubre cuánto debes cobrar por tu tiempo considerando gastos fijos, variables y tus metas de ingreso.',
    color: 'bg-brand',
    lightColor: 'bg-brand-light',
    textColor: 'text-brand',
  },
  {
    id: 'inventario',
    icon: Package,
    label: 'Inventario',
    title: 'Control total de stock',
    description: 'Registra productos, monitorea stock en tiempo real y recibe alertas antes de quedarte sin unidades.',
    color: 'bg-accent',
    lightColor: 'bg-accent-light',
    textColor: 'text-accent',
  },
  {
    id: 'finanzas',
    icon: BarChart3,
    label: 'Finanzas',
    title: 'Gestión financiera clara',
    description: 'Visualiza ingresos, egresos y rentabilidad en dashboards claros que te ayudan a tomar mejores decisiones.',
    color: 'bg-blue-500',
    lightColor: 'bg-blue-50',
    textColor: 'text-blue-600',
  },
  {
    id: 'tiempo',
    icon: Clock,
    label: 'Tiempo',
    title: 'Seguimiento de horas',
    description: 'Registra tu tiempo de trabajo, calcula horas facturables y mejora tu productividad diaria.',
    color: 'bg-purple-500',
    lightColor: 'bg-purple-50',
    textColor: 'text-purple-600',
  },
  {
    id: 'ahorro',
    icon: Wallet,
    label: 'Ahorro',
    title: 'Metas de ahorro',
    description: 'Define objetivos de ahorro, haz seguimiento de tu progreso y alcanza tus metas financieras.',
    color: 'bg-orange-500',
    lightColor: 'bg-orange-50',
    textColor: 'text-orange-600',
  },
  {
    id: 'productividad',
    icon: Zap,
    label: 'Productividad',
    title: '+24% de productividad',
    description: 'Analiza tu rendimiento, identifica patrones y optimiza tu tiempo para maximizar resultados.',
    color: 'bg-green-500',
    lightColor: 'bg-green-50',
    textColor: 'text-green-600',
  },
];

export default function Features() {
  const [activeTab, setActiveTab] = useState(0);
  const sectionRef = useRef<HTMLElement>(null);
  const tabsRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
      gsap.from('.features-title', {
        y: 50,
        opacity: 0,
        duration: 1,
        ease: 'power3.out',
        scrollTrigger: {
          trigger: sectionRef.current,
          start: 'top 80%',
        },
      });

      gsap.from('.feature-tab', {
        y: 30,
        opacity: 0,
        duration: 0.6,
        stagger: 0.1,
        ease: 'power3.out',
        scrollTrigger: {
          trigger: tabsRef.current,
          start: 'top 85%',
        },
      });

      gsap.from('.feature-content', {
        x: 50,
        opacity: 0,
        duration: 0.8,
        ease: 'power3.out',
        scrollTrigger: {
          trigger: '.feature-content',
          start: 'top 80%',
        },
      });
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  const activeFeature = features[activeTab];
  const Icon = activeFeature.icon;

  return (
    <section ref={sectionRef} id="features" className="py-24 lg:py-32 bg-bg relative overflow-hidden">
      {/* Background decoration */}
      <div className="absolute top-0 right-0 w-[600px] h-[600px] bg-gradient-to-bl from-brand/5 to-transparent rounded-full blur-3xl -translate-y-1/2 translate-x-1/4" />

      <div className="max-w-7xl mx-auto px-6 lg:px-8 relative">
        {/* Header */}
        <div className="features-title text-center max-w-3xl mx-auto mb-16">
          <span className="inline-block px-4 py-1.5 rounded-full bg-brand-light text-brand-dark text-sm font-semibold mb-4 border border-brand/10">
            Funcionalidades
          </span>
          <h2 className="font-display text-4xl lg:text-6xl font-bold tracking-tight text-text-primary leading-[1.1]">
            Todo lo que necesitas para{' '}
            <span className="text-brand">crecer</span>
          </h2>
          <p className="mt-6 text-lg text-text-secondary">
            Herramientas pensadas para freelancers y pymes que quieren dejar de adivinar y empezar a medir.
          </p>
        </div>

        {/* Tabs Navigation */}
        <div ref={tabsRef} className="flex flex-wrap justify-center gap-3 mb-16">
          {features.map((feature, index) => {
            const TabIcon = feature.icon;
            return (
              <button
                key={feature.id}
                onClick={() => setActiveTab(index)}
                className={`feature-tab flex items-center gap-2 px-5 py-3 rounded-full text-sm font-semibold transition-all duration-300 ${
                  activeTab === index
                    ? `${feature.lightColor} ${feature.textColor} shadow-lg`
                    : 'bg-white text-text-secondary hover:text-text-primary hover:bg-surface-secondary border border-border'
                }`}
              >
                <TabIcon className="w-4 h-4" />
                {feature.label}
              </button>
            );
          })}
        </div>

        {/* Feature Content */}
        <div className="feature-content grid lg:grid-cols-2 gap-12 lg:gap-20 items-center">
          {/* Text */}
          <div className="order-2 lg:order-1">
            <div className={`inline-flex items-center justify-center w-16 h-16 rounded-2xl ${activeFeature.lightColor} mb-6`}>
              <Icon className={`w-8 h-8 ${activeFeature.textColor}`} />
            </div>
            <h3 className="font-display text-3xl lg:text-4xl font-bold text-text-primary mb-4">
              {activeFeature.title}
            </h3>
            <p className="text-lg text-text-secondary leading-relaxed mb-8">
              {activeFeature.description}
            </p>
            <a
              href="#cta"
              className="inline-flex items-center gap-2 text-brand font-semibold hover:gap-3 transition-all"
            >
              Explorar funcionalidad
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 8l4 4m0 0l-4 4m4-4H3" />
              </svg>
            </a>
          </div>

          {/* Visual */}
          <div className="order-1 lg:order-2 relative">
            <div className="relative bg-surface rounded-3xl shadow-xl border border-border/50 p-8 lg:p-10">
              {/* Mock feature card */}
              <div className={`${activeFeature.lightColor} rounded-2xl p-6 border border-opacity-10`}>
                <div className="flex items-center gap-3 mb-4">
                  <div className={`w-10 h-10 rounded-xl ${activeFeature.color} flex items-center justify-center`}>
                    <Icon className="w-5 h-5 text-white" />
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-text-primary">{activeFeature.label}</p>
                    <p className="text-xs text-text-muted">Actualizado ahora</p>
                  </div>
                </div>
                
                {/* Dynamic mock content based on feature */}
                {activeTab === 0 && (
                  <div className="space-y-3">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-text-secondary">Tu valor hora</span>
                      <span className="text-2xl font-bold text-brand">$42.800</span>
                    </div>
                    <div className="h-2 bg-white/50 rounded-full overflow-hidden">
                      <div className="h-full w-[75%] bg-brand rounded-full" />
                    </div>
                    <div className="flex justify-between text-xs text-text-muted">
                      <span>Promedio mercado: $35.000</span>
                      <span className="text-success font-semibold">+22% arriba</span>
                    </div>
                  </div>
                )}
                {activeTab === 1 && (
                  <div className="space-y-3">
                    <div className="grid grid-cols-3 gap-2">
                      <div className="bg-white rounded-xl p-3 text-center">
                        <p className="text-lg font-bold text-text-primary">87</p>
                        <p className="text-[10px] text-text-muted">Items</p>
                      </div>
                      <div className="bg-white rounded-xl p-3 text-center">
                        <p className="text-lg font-bold text-accent">12</p>
                        <p className="text-[10px] text-text-muted">Bajos</p>
                      </div>
                      <div className="bg-white rounded-xl p-3 text-center">
                        <p className="text-lg font-bold text-success">$2.4M</p>
                        <p className="text-[10px] text-text-muted">Valor</p>
                      </div>
                    </div>
                  </div>
                )}
                {activeTab >= 2 && (
                  <div className="space-y-3">
                    <div className="flex items-end justify-between gap-2 h-20">
                      {[65, 40, 80, 55, 90, 70, 85].map((h, i) => (
                        <div
                          key={i}
                          className={`flex-1 rounded-t-lg ${activeFeature.color} opacity-20 hover:opacity-40 transition-opacity`}
                          style={{ height: `${h}%` }}
                        />
                      ))}
                    </div>
                    <div className="flex justify-between text-[10px] text-text-muted">
                      <span>Lun</span><span>Mar</span><span>Mie</span><span>Jue</span><span>Vie</span><span>Sab</span><span>Dom</span>
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* Floating accent */}
            <div className="absolute -bottom-4 -right-4 w-24 h-24 bg-gradient-to-br from-brand/10 to-accent/10 rounded-full blur-2xl" />
          </div>
        </div>
      </div>
    </section>
  );
}
