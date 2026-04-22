// IA tab — chat with assistant: header, bubbles, suggestions, input

const IaScreen = () => {
  const suggestions = [
    '¿Cuál es mi margen de ganancia este mes?',
    'Sugiere cómo bajar mis gastos fijos',
    '¿Cuándo llegaré a mi meta mensual?',
    '¿Qué productos tienen mejor margen?',
  ];
  const messages = [
    { isAi: true, text: '¡Hola! Soy tu asistente de IA para Págate-IA. Puedo ayudarte a analizar tus finanzas, dar sugerencias de precios, y optimizar tu inventario. ¿En qué te ayudo hoy?' },
  ];

  return (
    <PhoneShell>
      <div style={{ position: 'absolute', inset: 0, top: 54, bottom: 98,
        display: 'flex', flexDirection: 'column' }}>
        {/* Header */}
        <div style={{ padding: '24px 24px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{
            width: 44, height: 44, borderRadius: 20,
            background: T.brandGradient,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <I.bot size={22} color="#fff" />
          </div>
          <div>
            <div style={{ fontSize: 24, fontWeight: 800, color: T.textPrimaryDark, letterSpacing: -0.3 }}>
              Asistente IA
            </div>
            <div style={{ fontSize: 12, color: T.brand }}>Powered by Págate-IA</div>
          </div>
        </div>

        {/* Messages */}
        <div style={{ flex: 1, overflowY: 'auto', padding: '0 24px' }}>
          {messages.map((m, i) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'flex-start', gap: 8,
              marginBottom: 12,
              justifyContent: m.isAi ? 'flex-start' : 'flex-end',
            }}>
              {m.isAi && (
                <div style={{
                  width: 30, height: 30, borderRadius: '50%', flexShrink: 0,
                  background: T.brandGradient,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <I.bot size={16} color="#fff" />
                </div>
              )}
              <div style={{
                maxWidth: 280, padding: 12, borderRadius: 20,
                background: m.isAi ? T.surfaceDark : T.brand + '26',
                border: `1px solid ${m.isAi ? T.borderDark : T.brand + '4D'}`,
                fontSize: 14, lineHeight: 1.4, color: T.textPrimaryDark,
              }}>{m.text}</div>
            </div>
          ))}
        </div>

        {/* Suggestions */}
        <div style={{ padding: '4px 0 8px' }}>
          <div style={{ display: 'flex', gap: 8, overflowX: 'auto', padding: '0 24px' }}>
            {suggestions.map((s, i) => (
              <div key={i} style={{
                flexShrink: 0, padding: '6px 12px', borderRadius: 100,
                background: T.surfaceDark, border: `1px solid ${T.borderDark}`,
                fontSize: 12, color: T.textSecondaryDark,
                whiteSpace: 'nowrap', cursor: 'pointer',
              }}>{s}</div>
            ))}
          </div>
        </div>

        {/* Input */}
        <div style={{ padding: '8px 24px 24px', display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{
            flex: 1, height: 48, borderRadius: 32,
            background: T.surfaceDark, border: `1px solid ${T.borderDark}`,
            display: 'flex', alignItems: 'center', padding: '0 16px',
            color: T.textSecondaryDark, fontSize: 14,
          }}>Escribe una pregunta...</div>
          <div style={{
            width: 48, height: 48, borderRadius: '50%',
            background: T.brandGradient,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer',
          }}>
            <I.send size={20} color="#fff" />
          </div>
        </div>
      </div>

      <BottomNav active="ia" />
    </PhoneShell>
  );
};

window.IaScreen = IaScreen;
