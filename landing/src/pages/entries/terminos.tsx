// Punto de entrada de la página /terminos/.
//
// Es un documento HTML propio, no una ruta de un enrutador: la landing se
// publica en GitHub Pages, que sirve archivos estáticos y no sabe reescribir
// rutas hacia un index.html único.

import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '../../index.css';
import TerminosPage from '../TerminosPage';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <TerminosPage />
  </StrictMode>,
);
