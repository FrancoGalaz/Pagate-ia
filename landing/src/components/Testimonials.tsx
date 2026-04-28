import { useEffect, useRef } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { Star, Quote } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

const testimonials = [
  {
    name: 'María González',
    role: 'Diseñadora Freelance',
    content: 'Pagate me ayudó a descubrir que estaba cobrando 40% menos de lo que debería. Ahora mis presupuestos son justos y rentables.',
    rating: 5,
    gradient: 'from-brand/10 to-blue-50',
  },
  {
    name: 'Carlos Martínez',
    role: 'Desarrollador Web',
    content: 'El control de inventario es increíble. Antes usaba spreadsheets, ahora tengo todo automatizado y me avisa cuando reponer stock.',
    rating: 5,
    gradient: 'from-accent/10 to-orange-50',
  },
  {
    name: 'Ana Silva',
    role: 'Consultora de Marketing',
    content: 'En 2 semanas pude ver exactamente cuánto valía mi hora real. Cambió completamente cómo cobro por mis proyectos.',
    rating: 5,
    gradient: 'from-purple-50 to-pink-50',
  },
];

export default function Testimonials() {
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
      gsap.from('.testimonials-title', {
        y: 50,
        opacity: 0,
        duration: 1,
        ease: 'power3.out',
        scrollTrigger: {
          trigger: sectionRef.current,
          start: 'top 80%',
        },
      });

      gsap.from('.testimonial-card', {
        y: 60,
        opacity: 0,
        duration: 0.8,
        stagger: 0.2,
        ease: 'power3.out',
        scrollTrigger: {
          trigger: '.testimonial-card',
          start: 'top 85%',
        },
      });
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section ref={sectionRef} className="py-24 lg:py-32 bg-bg relative overflow-hidden">
      {/* Background decoration */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-gradient-to-r from-brand/5 to-accent/5 rounded-full blur-3xl" />

      <div className="max-w-7xl mx-auto px-6 lg:px-8 relative">
        {/* Header */}
        <div className="testimonials-title text-center max-w-3xl mx-auto mb-16">
          <span className="inline-block px-4 py-1.5 rounded-full bg-accent-light text-accent-dark text-sm font-semibold mb-4 border border-accent/10">
            Testimonios
          </span>
          <h2 className="font-display text-4xl lg:text-5xl font-bold tracking-tight text-text-primary">
            Lo que dicen quienes ya usan{' '}
            <span className="text-brand">Pagate</span>
          </h2>
        </div>

        {/* Testimonial cards */}
        <div className="grid md:grid-cols-3 gap-8">
          {testimonials.map((testimonial) => (
            <div
              key={testimonial.name}
              className={`testimonial-card group relative bg-white rounded-3xl p-8 border border-border/50 hover:shadow-xl hover:shadow-text-primary/5 hover:-translate-y-2 transition-all duration-300`}
            >
              {/* Gradient background on hover */}
              <div className={`absolute inset-0 rounded-3xl bg-gradient-to-br ${testimonial.gradient} opacity-0 group-hover:opacity-100 transition-opacity -z-10`} />
              
              {/* Quote icon */}
              <div className="w-10 h-10 rounded-full bg-brand/10 flex items-center justify-center mb-6">
                <Quote className="w-5 h-5 text-brand" />
              </div>

              {/* Stars */}
              <div className="flex gap-1 mb-4">
                {Array.from({ length: testimonial.rating }).map((_, i) => (
                  <Star key={i} className="w-4 h-4 text-yellow-400 fill-yellow-400" />
                ))}
              </div>

              {/* Content */}
              <p className="text-text-secondary leading-relaxed mb-6">
                "{testimonial.content}"
              </p>

              {/* Author */}
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-gradient-to-br from-brand to-accent flex items-center justify-center text-white font-bold text-sm">
                  {testimonial.name.charAt(0)}
                </div>
                <div>
                  <p className="text-sm font-semibold text-text-primary">{testimonial.name}</p>
                  <p className="text-xs text-text-muted">{testimonial.role}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
