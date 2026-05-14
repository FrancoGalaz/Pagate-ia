import { useState, type FormEvent } from 'react';
import { ArrowRight, CheckCircle2, Loader2 } from 'lucide-react';
import { saveWaitlistEntry } from '../services/waitlist-service';

type FormStatus = 'idle' | 'submitting' | 'success' | 'error';

export default function WaitlistForm() {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [status, setStatus] = useState<FormStatus>('idle');
  const [errorMsg, setErrorMsg] = useState('');

  const isValid = email.trim().length > 0 && email.includes('@');

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!isValid || status === 'submitting') return;

    setStatus('submitting');
    setErrorMsg('');

    try {
      await saveWaitlistEntry({
        name: name.trim(),
        email: email.trim(),
        createdAt: new Date().toISOString(),
        source: 'landing-page',
      });
      setStatus('success');
    } catch (err) {
      setStatus('error');
      setErrorMsg(err instanceof Error ? err.message : 'Error al registrarte');
    }
  };

  if (status === 'success') {
    return (
      <div className="text-center py-6">
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-success/20 mb-4">
          <CheckCircle2 className="w-8 h-8 text-success" />
        </div>
        <h3 className="text-xl font-bold text-white mb-2">
          ¡Estás en la lista!
        </h3>
        <p className="text-text-muted">
          Te avisaremos cuando Pagate esté disponible.{'\n'}
          Mientras tanto, síguenos para novedades.
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="w-full max-w-md">
      <div className="flex flex-col sm:flex-row gap-3">
        <div className="flex-1 space-y-3 sm:space-y-0 sm:flex sm:gap-3">
          <input
            type="text"
            placeholder="Tu nombre"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="w-full sm:w-auto flex-1 px-4 py-3 rounded-xl bg-white/10 border border-white/10 text-white placeholder-text-muted text-sm outline-none focus:border-brand-light focus:ring-1 focus:ring-brand-light transition-all"
            disabled={status === 'submitting'}
          />
          <input
            type="email"
            required
            placeholder="tu@email.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full sm:w-auto flex-1 px-4 py-3 rounded-xl bg-white/10 border border-white/10 text-white placeholder-text-muted text-sm outline-none focus:border-brand-light focus:ring-1 focus:ring-brand-light transition-all"
            disabled={status === 'submitting'}
          />
        </div>
        <button
          type="submit"
          disabled={!isValid || status === 'submitting'}
          className="inline-flex items-center justify-center gap-2 px-6 py-3 rounded-xl bg-accent text-white font-semibold text-sm shadow-lg shadow-accent/25 hover:bg-accent-dark transition-all hover:scale-105 active:scale-95 disabled:opacity-50 disabled:hover:scale-100 disabled:cursor-not-allowed whitespace-nowrap"
        >
          {status === 'submitting' ? (
            <>
              <Loader2 className="w-4 h-4 animate-spin" />
              Enviando...
            </>
          ) : (
            <>
              Unirme
              <ArrowRight className="w-4 h-4" />
            </>
          )}
        </button>
      </div>

      {status === 'error' && (
        <p className="mt-2 text-sm text-red-300">{errorMsg}</p>
      )}

      <p className="mt-3 text-xs text-text-muted">
        Sin spam. Solo te escribiremos cuando lancemos.
      </p>
    </form>
  );
}
