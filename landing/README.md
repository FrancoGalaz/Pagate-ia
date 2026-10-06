# landing

Sitio público de Págate-IA: Vite + React + TypeScript + Tailwind.

Se publica en GitHub Pages bajo el prefijo `/Pagate-ia/landing-page/`, que está
fijado en `base` de `vite.config.ts`. El build que se sirve vive en
`landing-page/` en la raíz del repo y **lo regenera el workflow
`.github/workflows/landing-pages.yml`, no se edita a mano**.

## Comandos

```bash
npm ci                  # dependencias
npm run dev             # servidor de desarrollo
npm run lint            # eslint
npm test                # vitest
npm run build           # tsc -b && vite build  →  dist/
npm run preview         # sirve dist/ respetando el prefijo de base
```

El bloque de verificación completo, que es el que tiene que estar en verde antes
de commitear, es:

```bash
npm --prefix landing run lint && npm --prefix landing test && npm --prefix landing run build
```

## Es un sitio multipágina, no una SPA

GitHub Pages sirve archivos estáticos y no sabe reescribir rutas hacia un
`index.html` único, así que cada página es un documento HTML propio declarado en
`build.rollupOptions.input` de `vite.config.ts`:

| URL publicada | Documento de entrada | Módulo |
|---|---|---|
| `/` | `index.html` | `src/main.tsx` → `src/App.tsx` |
| `/privacidad/` | `privacidad/index.html` | `src/pages/entries/privacidad.tsx` |
| `/terminos/` | `terminos/index.html` | `src/pages/entries/terminos.tsx` |
| `/eliminar-cuenta/` | `eliminar-cuenta/index.html` | `src/pages/entries/eliminar-cuenta.tsx` |

Las páginas legales viven en subdirectorios para que la URL quede limpia
(`/privacidad/` y no `/privacidad.html`) en GitHub Pages, Firebase Hosting y
Vercel por igual, sin reescrituras de servidor.

**Al añadir una página nueva hay que tocar tres sitios:** el `input` de
`vite.config.ts`, el array `content` de `tailwind.config.js` (si no, Tailwind no
ve sus clases y la página sale sin estilos) y el enlace que lleve a ella.

Para enlazar entre páginas se usa `siteUrl()` de `src/content/legal-meta.ts`, que
antepone `import.meta.env.BASE_URL`. **No escribas `/privacidad/` a mano**: en
GitHub Pages esa ruta no existe, y las rutas relativas cambian de significado
según la profundidad de la página.

## Las tres páginas legales son obligatorias para Google Play

No son contenido de relleno. Play exige una URL pública de política de privacidad
declarada en la ficha, y además una URL pública de solicitud de eliminación de
cuenta accesible sin iniciar sesión. Las tres direcciones se declaran en Play
Console, así que **no se pueden mover ni renombrar sin actualizar la ficha**.

Los datos del responsable (razón social, RUT, domicilio y correos de contacto)
están centralizados en `src/content/legal-meta.ts` y hoy son **marcadores entre
corchetes sin rellenar**. Una política publicada con corchetes visibles es motivo
de rechazo: el inventario de lo que falta está en
`../docs/SEGURIDAD-DATOS-PLAY.md` §4.1.

Si cambia el modelo de datos de la app, hay que actualizar el inventario de la
sección 2 de `src/pages/PrivacidadPage.tsx`. El formulario de Seguridad de los
datos de Play tiene que coincidir con lo que dice esa página.

## Qué hacen los tests

- `src/services/waitlist-service.test.ts` — el `POST` a la función `waitlist`:
  cuerpo, errores 400/429, fallo de red y URL sin configurar.
- `src/pages/legal.test.tsx` (jsdom) — que las tres páginas legales siguen
  declarando lo que Play exige: el inventario de datos, el envío a OpenRouter, la
  negación de ser asesoría y de procesar pagos, el plazo de borrado y que no
  queda ningún enlace muerto.
- `src/honestidad.test.ts` — lee el código fuente y falla si reaparecen las
  métricas y los testimonios inventados que se eliminaron, un `href="#"` o una
  animación en bucle infinito. Ignora los comentarios a propósito, porque varios
  archivos explican en su cabecera qué se quitó y por qué.

Los tests corren bajo `tsconfig.test.json`, un proyecto aparte: `honestidad.test.ts`
necesita `node:fs` y los tipos de Node no deben entrar en el código del navegador.

## Variables de entorno

| Variable | Para qué | Dónde |
|---|---|---|
| `VITE_WAITLIST_URL` | URL de la Cloud Function `waitlist` | `.env.example`, `.env.production` |

Solo URLs públicas. **Nunca un secreto**: todo lo que entra por `VITE_` acaba en
el bundle que se descarga el navegador.

## Estado conocido

El formulario de la lista de espera **no funciona en producción hoy**: apunta a
una Cloud Function que no está desplegada, porque el proyecto de Firebase está
vacío. Ver `../docs/PLAN-PUBLICIDAD.md` §0.
