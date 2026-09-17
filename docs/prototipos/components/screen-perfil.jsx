// Perfil tab — avatar hero, PRO badge, stats row, menu items

const PerfilScreen = () => {
  const profile = {
    name: 'Carlos Mendoza',
    businessName: 'Taller Mendoza',
    initials: 'CM',
    currency: 'MXN',
    goal: 35000,
    isPro: true,
  };

  return (
    <PhoneShell>
      <ScreenBody>
        <div style={{ padding: '24px 24px 0' }}>
          {/* Avatar + identity */}
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            <div style={{
              width: 88, height: 88, borderRadius: '50%',
              background: T.brandGradient, boxShadow: T.shadowBrandStrong,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: '#fff', fontWeight: 800, fontSize: 28,
            }}>{profile.initials}</div>
            <div style={{ fontSize: 20, fontWeight: 800, color: T.textPrimaryDark, marginTop: 16 }}>
              {profile.name}
            </div>
            <div style={{ fontSize: 14, color: T.textSecondaryDark, marginTop: 4 }}>{profile.businessName}</div>
            {profile.isPro && (
              <div style={{
                marginTop: 8, padding: '3px 16px', borderRadius: 100,
                background: T.brandGradient,
                fontSize: 11, fontWeight: 800, color: '#fff', letterSpacing: 1.2,
              }}>PRO</div>
            )}
          </div>

          {/* Stats row */}
          <div style={{
            marginTop: 32, padding: 24, borderRadius: 32,
            background: T.surfaceDark, border: `1px solid ${T.borderDark}`,
            display: 'flex', alignItems: 'center',
          }}>
            <StatItem label="Moneda" value={profile.currency} />
            <div style={{ width: 1, height: 40, background: T.borderDark }}/>
            <StatItem label="Meta" value={`$${(profile.goal/1000).toFixed(0)}K`} />
            <div style={{ width: 1, height: 40, background: T.borderDark }}/>
            <StatItem label="Negocio" value="Taller" />
          </div>

          {/* Menu */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 24 }}>
            <MenuItem icon={I.settings} label="Configuración" />
            <MenuItem icon={I.help}     label="Ayuda e Ideas" />
            <MenuItem icon={I.star}     label="Calificar la App" />
            <MenuItem icon={I.share}    label="Compartir Págate-IA" />
            <div style={{ height: 16 }} />
            <MenuItem icon={I.logout}   label="Cerrar Sesión" destructive />
          </div>

          <div style={{ textAlign: 'center', fontSize: 12, color: T.textTertiaryDark, marginTop: 32 }}>
            Págate-IA v1.0.0 · MVP
          </div>
          <div style={{ height: 24 }} />
        </div>
      </ScreenBody>
      <BottomNav active="profile" />
    </PhoneShell>
  );
};

const StatItem = ({ label, value }) => (
  <div style={{ flex: 1, textAlign: 'center' }}>
    <div style={{ fontSize: 16, fontWeight: 700, color: T.textPrimaryDark }}>{value}</div>
    <div style={{ fontSize: 12, color: T.textSecondaryDark, marginTop: 2 }}>{label}</div>
  </div>
);

const MenuItem = ({ icon: Cmp, label, destructive }) => (
  <div style={{
    padding: 16, borderRadius: 24,
    background: T.surfaceDark,
    border: `1px solid ${destructive ? T.error + '4D' : T.borderDark}`,
    display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer',
  }}>
    <div style={{
      width: 36, height: 36, borderRadius: 12,
      background: destructive ? T.error + '1F' : T.surfaceDark2,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>
      <Cmp size={18} color={destructive ? T.error : T.textSecondaryDark} />
    </div>
    <div style={{ flex: 1, fontSize: 14, fontWeight: 600,
      color: destructive ? T.error : T.textPrimaryDark }}>{label}</div>
    <I.chevron size={20} color={destructive ? T.error : T.textSecondaryDark} />
  </div>
);

window.PerfilScreen = PerfilScreen;
