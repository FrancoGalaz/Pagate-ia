// Phone shell + shared chrome (status bar, bottom nav, home indicator)
// Page is 402 × 874 logical, same as the ios_frame starter.

const PhoneShell = ({ children, dark = true, bg }) => (
  <div style={{
    width: 402, height: 874, borderRadius: 48, overflow: 'hidden',
    position: 'relative',
    background: bg || (dark ? T.bgDark : T.bgLight),
    boxShadow: '0 40px 80px rgba(0,0,0,0.18), 0 0 0 1px rgba(0,0,0,0.12)',
    fontFamily: T.font, WebkitFontSmoothing: 'antialiased',
    color: dark ? T.textPrimaryDark : T.textPrimary,
  }}>
    {/* Dynamic island */}
    <div style={{
      position: 'absolute', top: 11, left: '50%', transform: 'translateX(-50%)',
      width: 126, height: 37, borderRadius: 24, background: '#000', zIndex: 50,
    }} />
    {/* Status bar */}
    <PhoneStatusBar dark={dark} />
    {children}
    {/* Home indicator */}
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 60,
      height: 34, display: 'flex', justifyContent: 'center', alignItems: 'flex-end',
      paddingBottom: 8, pointerEvents: 'none',
    }}>
      <div style={{
        width: 139, height: 5, borderRadius: 100,
        background: dark ? 'rgba(255,255,255,0.7)' : 'rgba(0,0,0,0.25)',
      }} />
    </div>
  </div>
);

const PhoneStatusBar = ({ dark = true }) => {
  const c = dark ? '#fff' : '#000';
  return (
    <div style={{
      position: 'absolute', top: 0, left: 0, right: 0, zIndex: 40,
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '18px 32px 0', height: 54, boxSizing: 'border-box',
      fontFamily: '-apple-system, "SF Pro", system-ui',
    }}>
      <span style={{ fontWeight: 600, fontSize: 17, color: c }}>9:41</span>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <svg width="19" height="12" viewBox="0 0 19 12">
          <rect x="0" y="7.5" width="3.2" height="4.5" rx="0.7" fill={c}/>
          <rect x="4.8" y="5" width="3.2" height="7" rx="0.7" fill={c}/>
          <rect x="9.6" y="2.5" width="3.2" height="9.5" rx="0.7" fill={c}/>
          <rect x="14.4" y="0" width="3.2" height="12" rx="0.7" fill={c}/>
        </svg>
        <svg width="17" height="12" viewBox="0 0 17 12">
          <path d="M8.5 3.2C10.8 3.2 12.9 4.1 14.4 5.6L15.5 4.5C13.7 2.7 11.2 1.5 8.5 1.5C5.8 1.5 3.3 2.7 1.5 4.5L2.6 5.6C4.1 4.1 6.2 3.2 8.5 3.2Z" fill={c}/>
          <path d="M8.5 6.8C9.9 6.8 11.1 7.3 12 8.2L13.1 7.1C11.8 5.9 10.2 5.1 8.5 5.1C6.8 5.1 5.2 5.9 3.9 7.1L5 8.2C5.9 7.3 7.1 6.8 8.5 6.8Z" fill={c}/>
          <circle cx="8.5" cy="10.5" r="1.5" fill={c}/>
        </svg>
        <svg width="27" height="13" viewBox="0 0 27 13">
          <rect x="0.5" y="0.5" width="23" height="12" rx="3.5" stroke={c} strokeOpacity="0.35" fill="none"/>
          <rect x="2" y="2" width="20" height="9" rx="2" fill={c}/>
        </svg>
      </div>
    </div>
  );
};

// Bottom nav — shared across Home/Finanzas/Inventario/IA/Perfil
const BottomNav = ({ active = 'home' }) => {
  const items = [
    { k: 'home', icon: I.home, label: 'Inicio' },
    { k: 'finance', icon: I.chart, label: 'Finanzas' },
    { k: 'inv', icon: I.inventory, label: 'Inventario' },
    { k: 'ia', icon: I.bot, label: 'IA' },
    { k: 'profile', icon: I.user, label: 'Perfil' },
  ];
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0, zIndex: 30,
      background: T.surfaceDark,
      borderTop: `1px solid ${T.borderDark}`,
      paddingBottom: 34,
    }}>
      <div style={{ display: 'flex', height: 64 }}>
        {items.map(it => {
          const on = it.k === active;
          const Cmp = it.icon;
          return (
            <div key={it.k} style={{
              flex: 1, display: 'flex', flexDirection: 'column',
              alignItems: 'center', justifyContent: 'center', gap: 3,
            }}>
              <Cmp size={24} color={on ? T.brand : T.textSecondaryDark}
                   filled={on && it.k !== 'bot'} strokeWidth={on ? 2.2 : 1.8} />
              <div style={{
                fontSize: 10, fontWeight: on ? 700 : 500,
                color: on ? T.brand : T.textSecondaryDark,
                letterSpacing: 0.2,
              }}>{it.label}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

// Screen body scroll area — sits between status bar and bottom nav
const ScreenBody = ({ children, padBottom = 98 }) => (
  <div style={{
    position: 'absolute', inset: 0, top: 54, bottom: 0,
    paddingBottom: padBottom, overflow: 'hidden',
  }}>
    <div style={{ height: '100%', overflowY: 'auto' }}>
      {children}
    </div>
  </div>
);

Object.assign(window, { PhoneShell, PhoneStatusBar, BottomNav, ScreenBody });
