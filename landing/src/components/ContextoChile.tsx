// Sección «por qué ahora»: el contexto chileno que vuelve urgente llevar las
// cuentas ordenadas.
//
// Para qué existe este archivo: la landing no tenía ninguna razón de *por qué
// ahora*. Las tres que están aquí son hechos verificables de la normativa
// chilena vigente, y afectan exactamente al público de la app —quien hace algo
// con sus manos, lo vende por Instagram y cobra por transferencia—. Las fuentes
// oficiales están citadas en `docs/FICHA-PLAY.md §3`: en la landing no se citan
// a propósito, porque una página de producto con pies de página de circulares
// del SII asusta más de lo que informa.
//
// Tres reglas que gobiernan el texto de esta sección y que no se pueden
// relajar:
//
//  1. SIN ALARMISMO. No se dice «te van a fiscalizar», no se habla de multas y
//     no se pone una cuenta atrás. Se describe lo que la norma obliga a los
//     bancos y a las plataformas, que es lo que de verdad dice.
//  2. SIN PROMETER NADA TRIBUTARIO. La app registra y muestra; NO declara, NO
//     emite boletas, NO calcula impuestos y NO asesora. El bloque «Lo que no
//     hace» no es letra pequeña: es la mitad del mensaje, y va con el mismo
//     tamaño que la otra mitad.
//  3. SOLO FUNCIONES QUE EXISTEN. Nada de «clasifica tus ventas por tipo de
//     documento» ni «descuenta la comisión del medio de pago»: eso está en el
//     contrato C-3 y todavía no tiene una línea de código en `lib/`. Lo que se
//     promete aquí es lo que la app hace hoy: anotar, agrupar por mes y
//     mostrar.

import { useEffect, useRef } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { Check, X } from 'lucide-react';
import { NO_HACE, SI_HACE } from '../content/contexto-chile';

gsap.registerPlugin(ScrollTrigger);

export default function ContextoChile() {
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
      // Una sola entrada, sin bucles: la dirección visual del proyecto prohíbe
      // el movimiento perpetuo (ver la cabecera de Hero.tsx).
      gsap.from('.chile-reveal', {
        y: 40,
        opacity: 0,
        duration: 0.9,
        stagger: 0.12,
        ease: 'power3.out',
        scrollTrigger: {
          trigger: sectionRef.current,
          start: 'top 80%',
        },
      });
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section
      ref={sectionRef}
      id="por-que-ahora"
      className="py-24 lg:py-32 bg-bg relative overflow-hidden"
    >
      <div className="absolute bottom-0 left-0 w-[520px] h-[520px] bg-gradient-to-tr from-brand/5 to-transparent rounded-full blur-3xl translate-y-1/3 -translate-x-1/4" />

      <div className="max-w-5xl mx-auto px-6 lg:px-8 relative">
        <div className="chile-reveal max-w-3xl">
          <span className="inline-block px-4 py-1.5 rounded-full bg-brand-light text-brand-dark text-sm font-semibold mb-4 border border-brand/10">
            Hecha en Chile
          </span>
          <h2 className="font-display text-4xl lg:text-5xl font-bold tracking-tight text-text-primary leading-[1.1]">
            Tener las cuentas claras{' '}
            <span className="text-brand">dejó de ser opcional</span>
          </h2>
        </div>

        <div className="chile-reveal mt-8 max-w-3xl space-y-5 text-lg text-text-secondary leading-relaxed">
          <p>
            En Chile, los bancos tienen que informarle al Servicio de Impuestos
            Internos cuántos abonos recibe una cuenta cuando pasa de 50
            transferencias de 50 personas distintas en un mes. Las plataformas de
            pago y los marketplaces, por su parte, están obligados a exigir
            inicio de actividades antes de intermediar un cobro.
          </p>
          <p>
            Si haces algo con tus manos, lo vendes por Instagram y te pagan por
            transferencia, esto te toca de cerca. No porque haya un impuesto
            nuevo —no lo hay—, sino porque llegó el momento en que conviene tener
            a mano, y ordenado, lo que vendiste y lo que gastaste.
          </p>
          <p className="text-text-primary font-semibold">
            Para eso sirve Págate-IA: para que, cuando te lo pregunten —tu
            contador, el banco o tú misma—, la respuesta ya esté escrita.
          </p>
        </div>

        <div className="chile-reveal mt-12 grid md:grid-cols-2 gap-6">
          <div className="rounded-2xl bg-surface border border-border/60 p-6 lg:p-7">
            <h3 className="font-display text-lg font-bold text-text-primary mb-4">
              Lo que hace
            </h3>
            <ul className="space-y-3">
              {SI_HACE.map((linea) => (
                <li key={linea} className="flex gap-3 text-text-secondary">
                  <Check
                    className="w-5 h-5 shrink-0 mt-0.5 text-brand"
                    aria-hidden="true"
                  />
                  <span>{linea}</span>
                </li>
              ))}
            </ul>
          </div>

          <div className="rounded-2xl bg-surface border border-border/60 p-6 lg:p-7">
            <h3 className="font-display text-lg font-bold text-text-primary mb-4">
              Lo que no hace
            </h3>
            <ul className="space-y-3">
              {NO_HACE.map((linea) => (
                <li key={linea} className="flex gap-3 text-text-secondary">
                  <X
                    className="w-5 h-5 shrink-0 mt-0.5 text-text-muted"
                    aria-hidden="true"
                  />
                  <span>{linea}</span>
                </li>
              ))}
            </ul>
          </div>
        </div>

        <p className="chile-reveal mt-8 max-w-3xl text-sm text-text-muted leading-relaxed">
          Págate-IA es una herramienta de registro. No es asesoría contable,
          financiera ni tributaria, y no reemplaza a un contador ni a los
          sistemas oficiales del Servicio de Impuestos Internos.
        </p>
      </div>
    </section>
  );
}
