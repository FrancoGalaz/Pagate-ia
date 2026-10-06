// Portada de la landing de Págate-IA.
//
// Nota para quien edite esto: la portada tuvo dos secciones más, `Stats` y
// `Testimonials`, que se eliminaron a propósito. La primera mostraba cuatro
// métricas inventadas («8.500 freelancers activos», «98 % satisfacción») y la
// segunda tres testimonios firmados con nombre y cinco estrellas, en un
// producto que no se ha lanzado. Eso es el caso de manual de la política de
// Tergiversación de Google Play, y además esta es la URL que el revisor abre
// al comprobar la política de privacidad de la ficha. No las reintroduzcas sin
// datos reales y verificables detrás.

import { useEffect } from 'react';
import Lenis from 'lenis';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import Navbar from './components/Navbar';
import Hero from './components/Hero';
import Features from './components/Features';
import HowItWorks from './components/HowItWorks';
import Roadmap from './components/Roadmap';
import CTA from './components/CTA';
import Footer from './components/Footer';

gsap.registerPlugin(ScrollTrigger);

function App() {
  useEffect(() => {
    const lenis = new Lenis({
      duration: 1.2,
      easing: (t: number) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
      orientation: 'vertical',
      gestureOrientation: 'vertical',
      smoothWheel: true,
    });

    lenis.on('scroll', ScrollTrigger.update);

    gsap.ticker.add((time) => {
      lenis.raf(time * 1000);
    });

    gsap.ticker.lagSmoothing(0);

    return () => {
      lenis.destroy();
    };
  }, []);

  return (
    <div className="min-h-screen bg-bg font-sans text-text-primary overflow-x-hidden">
      <Navbar />
      <main>
        <Hero />
        <Features />
        <HowItWorks />
        <Roadmap />
        <CTA />
      </main>
      <Footer />
    </div>
  );
}

export default App;
