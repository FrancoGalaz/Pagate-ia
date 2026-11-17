// Punto de entrada de la página /privacidad/.
//
// Es un documento HTML propio, no una ruta de un enrutador: la landing se
// publica en GitHub Pages, que sirve archivos estáticos y no sabe reescribir
// rutas hacia un index.html único.

import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '../../index.css';
import PrivacidadPage from '../PrivacidadPage';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <PrivacidadPage />
  </StrictMode>,
);
