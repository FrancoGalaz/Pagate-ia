// Welcome screen — light theme, matches features/auth/presentation/pages/welcome_screen.dart

const WelcomeScreen = () => (
  <PhoneShell dark={false} bg={T.bgLight}>
    {/* Brand glow */}
    <div style={{
      position: 'absolute', top: -100, left: -50, width: 400, height: 400,
      borderRadius: '50%', background: 'rgba(0,194,184,0.08)',
      filter: 'blur(80px)', pointerEvents: 'none',
    }} />

    <div style={{ position: 'absolute', inset: 0, top: 54, bottom: 0,
      display: 'flex', flexDirection: 'column', padding: '0 0 34px' }}>
      {/* Logo header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center',
        gap: 8, paddingTop: 24, paddingBottom: 12 }}>
        <div style={{
          width: 32, height: 32, borderRadius: '50%', background: T.brand,
          boxShadow: T.shadowBrand,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="12" r="9"/><path d="M12 7v10M9 10h4.5a2 2 0 010 4H9"/>
          </svg>
        </div>
        <div style={{ fontWeight: 800, fontSize: 18, letterSpacing: -0.5, color: T.textPrimary }}>Págate-IA</div>
      </div>

      {/* Hero */}
      <div style={{ flex: 1, padding: '0 24px', overflowY: 'auto' }}>
        <div style={{ height: 20 }} />
        <div style={{ position: 'relative', width: 340, height: 300, margin: '0 auto' }}>
          <div style={{
            position: 'absolute', inset: 10, borderRadius: '50%',
            background: 'linear-gradient(135deg, #FFFFFF 0%, rgba(0,194,184,0.06) 100%)',
            border: '1px solid rgba(255,255,255,0.5)',
            boxShadow: '0 20px 40px rgba(0,0,0,0.08)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <I.handyman size={80} color="rgba(148,163,184,0.3)" strokeWidth={1.5} />
          </div>
          {/* Floating card: Ganancia */}
          <div style={{
            position: 'absolute', right: 10, top: 80,
            background: '#fff', borderRadius: 16, padding: '8px 12px',
            boxShadow: '0 4px 10px rgba(0,0,0,0.08)',
            display: 'flex', alignItems: 'center', gap: 8,
          }}>
            <div style={{ width: 26, height: 26, borderRadius: 8, background: T.brand,
              display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <I.trending size={14} color="#fff" />
            </div>
            <div>
              <div style={{ fontSize: 10, color: T.textTertiary, fontWeight: 600, letterSpacing: 0.5 }}>GANANCIA</div>
              <div style={{ fontSize: 14, fontWeight: 700, color: T.textPrimary }}>+24%</div>
            </div>
          </div>
          {/* Floating card: Stock */}
          <div style={{
            position: 'absolute', left: 0, bottom: 60,
            background: '#fff', borderRadius: 16, padding: '8px 12px',
            boxShadow: '0 4px 10px rgba(0,0,0,0.08)',
            display: 'flex', alignItems: 'center', gap: 8,
          }}>
            <div style={{ width: 26, height: 26, borderRadius: 8, background: T.accentLight,
              display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <I.inventory size={14} color={T.accent} />
            </div>
            <div>
              <div style={{ fontSize: 10, color: T.textTertiary, fontWeight: 600, letterSpacing: 0.5 }}>STOCK</div>
              <div style={{ fontSize: 14, fontWeight: 700, color: T.textPrimary }}>Optimizado</div>
            </div>
          </div>
        </div>

        <div style={{
          fontSize: 30, fontWeight: 800, letterSpacing: -0.75, lineHeight: 1.15,
          color: T.textPrimary, textAlign: 'center', marginTop: 8,
        }}>
          Tu talento crea,<br/>
          <span style={{
            color: T.brand,
            borderBottom: `2px solid ${T.brand}`,
            paddingBottom: 2,
          }}>nosotros calculamos.</span>
        </div>

        <div style={{
          fontSize: 16, fontWeight: 400, color: T.textSecondary, textAlign: 'center',
          marginTop: 16, lineHeight: 1.5,
        }}>
          La primera herramienta financiera<br/>diseñada por y para artesanos.
        </div>
      </div>

      {/* Footer actions */}
      <div style={{ padding: '0 24px' }}>
        <button style={{
          width: '100%', height: 56, borderRadius: 100, border: 'none',
          background: T.brand, color: '#fff',
          fontFamily: T.font, fontSize: 16, fontWeight: 700, letterSpacing: 0.3,
          cursor: 'pointer', boxShadow: T.shadowBrand,
        }}>Empezar ahora (Gratis)</button>

        <div style={{ height: 12 }} />
        <SocialButton label="Continuar con Google" kind="google" />
        <div style={{ height: 8 }} />
        <SocialButton label="Continuar con Apple" kind="apple" />

        <div style={{ height: 20 }} />
        <div style={{ textAlign: 'center', fontSize: 14, color: T.textTertiary }}>
          ¿Ya eres parte de la comunidad?{' '}
          <span style={{ color: T.brand, fontWeight: 700 }}>Inicia Sesión</span>
        </div>
        <div style={{ textAlign: 'center', fontSize: 10, color: T.textTertiary, marginTop: 12 }}>
          Al continuar, aceptas nuestros Términos y Privacidad.
        </div>
      </div>
    </div>
  </PhoneShell>
);

const SocialButton = ({ label, kind }) => (
  <button style={{
    width: '100%', height: 56, borderRadius: 100,
    background: '#fff', border: `1px solid ${T.border}`,
    display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
    fontFamily: T.font, fontSize: 16, fontWeight: 600, color: T.textPrimary,
    cursor: 'pointer',
  }}>
    {kind === 'google' ? (
      <svg width="22" height="22" viewBox="0 0 24 24">
        <path d="M21.8 12.2c0-.7-.1-1.4-.2-2H12v3.8h5.5a4.7 4.7 0 01-2 3.1v2.6h3.3c2-1.8 3-4.5 3-7.5z" fill="#4285F4"/>
        <path d="M12 22c2.7 0 5-.9 6.7-2.4l-3.3-2.6a6 6 0 01-9-3.1H3v2.7A10 10 0 0012 22z" fill="#34A853"/>
        <path d="M6.4 13.9a6 6 0 010-3.8V7.4H3a10 10 0 000 9.2l3.4-2.7z" fill="#FBBC05"/>
        <path d="M12 6a5.4 5.4 0 013.8 1.5l2.9-2.9A10 10 0 003 7.4l3.4 2.7A6 6 0 0112 6z" fill="#EA4335"/>
      </svg>
    ) : <I.apple size={22} color="#000" />}
    {label}
  </button>
);

window.WelcomeScreen = WelcomeScreen;
