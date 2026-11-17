/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** URL de la Cloud Function `waitlist` (POST JSON). */
  readonly VITE_WAITLIST_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
