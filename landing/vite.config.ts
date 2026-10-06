import { resolve } from 'node:path'
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  // La landing se publica en GitHub Pages bajo este prefijo. Las páginas
  // enlazan entre sí con `import.meta.env.BASE_URL` (ver
  // src/content/legal-meta.ts) para no depender de rutas escritas a mano.
  base: '/Pagate-ia/landing-page/',
  plugins: [react()],
  css: {
    postcss: './postcss.config.js',
  },
  build: {
    rollupOptions: {
      // Sitio multipágina: cada documento HTML es un punto de entrada propio.
      // Las tres páginas legales viven en subdirectorios para que la URL
      // publicada quede limpia (`/privacidad/`) en GitHub Pages, Firebase
      // Hosting y Vercel sin necesitar reescrituras de servidor. Google Play
      // exige esas URLs públicas y estables en la ficha.
      input: {
        main: resolve(__dirname, 'index.html'),
        privacidad: resolve(__dirname, 'privacidad/index.html'),
        terminos: resolve(__dirname, 'terminos/index.html'),
        'eliminar-cuenta': resolve(__dirname, 'eliminar-cuenta/index.html'),
      },
    },
  },
  test: {
    // Node por defecto: los tests del servicio de lista de espera no necesitan
    // DOM. Los tests de componentes piden jsdom con un comentario
    // `@vitest-environment jsdom` en su cabecera.
    environment: 'node',
    include: ['src/**/*.test.{ts,tsx}'],
  },
})
