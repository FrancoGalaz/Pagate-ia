/**
 * Punto de entrada del backend. Solo inicializa el Admin SDK y reexporta las
 * funciones; toda la lógica vive en los módulos.
 */

import { initializeApp } from 'firebase-admin/app';

initializeApp();

export { deleteAccount } from './account';
export { deleteChatHistory } from './chatHistory';
export { chat } from './chat';
export { onTransactionWritten } from './months';
export { scanReceipt } from './scan';
export { waitlist } from './waitlist';
