// Home tab — dashboard with balance card, quick actions, recent activity
// Mirrors features/dashboard/presentation/pages/tabs/home_tab.dart

const fmtK = (v) => v >= 1000 ? `${(v/1000).toFixed(1)}K` : `${v.toFixed(0)}`;

const homeMock = {
  user: { name: 'Carlos', businessName: 'Taller Mendoza', avatarInitials: 'CM' },
  month: 'Marzo 2025',
  income: 23800,
  expenses: 8300,
  goal: 35000,
  progress: 0.68,
  activity: [
    { type: 'income',  title: 'Servicio de frenos', amount: '+$850',   time: 'Hoy, 10:30' },
    { type: 'expense', title: 'Aceite motor 5W-30', amount: '-$320',   time: 'Hoy, 09:15' },
    { type: 'income',  title: 'Cambio de clutch',   amount: '+$2,200', time: 'Ayer, 16:45' },
    { type: 'income',  title: 'Afinación general',  amount: '+$1,100', time: 'Ayer, 14:20' },
    { type: 'expense', title: 'Renta local',        amount: '-$5,000', time: '13 mar' },
  ],
};

const HomeScreen = () => {
  const m = homeMock;
  const balance = m.income - m.expenses;
  return (
    <PhoneShell>
      <ScreenBody>
        <div style={{ padding: '24px 24px 0' }}>
          {/* Header */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{
              width: 44, height: 44, borderRadius: '50%',
              background: T.brandGradient,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: '#fff', fontWeight: 800, fontSize: 14,
            }}>{m.user.avatarInitials}</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 16, fontWeight: 700, color: T.textPrimaryDark }}>
                Hola, {m.user.name} 👋
              </div>
              <div style={{ fontSize: 12, color: T.textSecondaryDark }}>{m.user.businessName}</div>
            </div>
            <div style={{ position: 'relative', width: 40, height: 40,
              display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <I.bell size={24} color={T.textSecondaryDark} />
              <div style={{
                position: 'absolute', top: 8, right: 8, width: 8, height: 8,
                borderRadius: '50%', background: T.error,
              }}/>
            </div>
          </div>

          {/* Balance card */}
          <div style={{
            marginTop: 16, padding: 24, borderRadius: 32,
            background: T.brandGradient, boxShadow: T.shadowBrandStrong, color: '#fff',
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div style={{ fontSize: 12, fontWeight: 600, color: 'rgba(255,255,255,0.8)', letterSpacing: 0.5 }}>
                BALANCE DEL MES
              </div>
              <div style={{
                padding: '3px 12px', borderRadius: 100,
                background: 'rgba(255,255,255,0.2)',
                fontSize: 11, fontWeight: 600, letterSpacing: 0.5,
              }}>{m.month}</div>
            </div>
            <div style={{ fontSize: 36, fontWeight: 800, letterSpacing: -1, marginTop: 6 }}>
              ${fmtK(balance)}
            </div>

            <div style={{ display: 'flex', gap: 24, marginTop: 16 }}>
              <MiniStat label="Ingresos" amount={m.income} up />
              <MiniStat label="Gastos" amount={m.expenses} />
            </div>

            <div style={{ marginTop: 16, height: 6, borderRadius: 100,
              background: 'rgba(255,255,255,0.25)', overflow: 'hidden' }}>
              <div style={{ width: `${m.progress * 100}%`, height: '100%', background: '#fff' }}/>
            </div>
            <div style={{ marginTop: 6, fontSize: 12, color: 'rgba(255,255,255,0.8)' }}>
              Meta: ${fmtK(m.goal)} · {Math.round(m.progress * 100)}% completado
            </div>
          </div>

          {/* Quick actions */}
          <div style={{ marginTop: 24 }}>
            <div style={{ fontSize: 16, fontWeight: 700, color: T.textPrimaryDark }}>Acciones Rápidas</div>
            <div style={{ display: 'flex', marginTop: 16, gap: 4 }}>
              <QuickAction icon={I.plus}      label="Venta"        color={T.brand} filled />
              <QuickAction icon={I.minus}     label="Gasto"        color={T.error} filled />
              <QuickAction icon={I.inventory} label="Inventario"   color={T.info} />
              <QuickAction icon={I.bot}       label="Preguntar IA" color={T.accent} />
            </div>
          </div>

          {/* Recent activity */}
          <div style={{ marginTop: 24 }}>
            <div style={{ fontSize: 16, fontWeight: 700, color: T.textPrimaryDark }}>Actividad Reciente</div>
            <div style={{
              marginTop: 16, borderRadius: 32, background: T.surfaceDark,
              border: `1px solid ${T.borderDark}`, overflow: 'hidden',
            }}>
              {m.activity.map((it, i) => (
                <ActivityRow key={i} item={it} isLast={i === m.activity.length - 1} />
              ))}
            </div>
          </div>

          <div style={{ height: 24 }} />
        </div>
      </ScreenBody>
      <BottomNav active="home" />
    </PhoneShell>
  );
};

const MiniStat = ({ label, amount, up }) => {
  const ArrowCmp = up ? I.arrowUp : I.arrowDown;
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
      <ArrowCmp size={14} color="rgba(255,255,255,0.8)" />
      <div>
        <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.8)' }}>{label}</div>
        <div style={{ fontSize: 14, fontWeight: 700, color: '#fff' }}>${fmtK(amount)}</div>
      </div>
    </div>
  );
};

const QuickAction = ({ icon: Cmp, label, color, filled }) => (
  <div style={{ flex: 1, display: 'flex', flexDirection: 'column',
    alignItems: 'center', gap: 6, cursor: 'pointer' }}>
    <div style={{
      width: 52, height: 52, borderRadius: 20,
      background: color + '26', // 15%
      border: `1px solid ${color}4D`, // 30%
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>
      <Cmp size={24} color={color} filled={filled} />
    </div>
    <div style={{ fontSize: 11, fontWeight: 600, color: T.textSecondaryDark,
      letterSpacing: 0.3, textAlign: 'center' }}>{label}</div>
  </div>
);

const ActivityRow = ({ item, isLast }) => {
  const isIncome = item.type === 'income';
  const color = isIncome ? T.success : T.error;
  const ArrowCmp = isIncome ? I.arrowUp : I.arrowDown;
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center',
        padding: '12px 16px', gap: 12 }}>
        <div style={{
          width: 36, height: 36, borderRadius: '50%', background: color + '1F',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <ArrowCmp size={16} color={color} />
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 14, fontWeight: 600, color: T.textPrimaryDark }}>{item.title}</div>
          <div style={{ fontSize: 12, color: T.textSecondaryDark }}>{item.time}</div>
        </div>
        <div style={{ fontSize: 14, fontWeight: 700, color }}>{item.amount}</div>
      </div>
      {!isLast && <div style={{ height: 1, background: T.borderDark, margin: '0 16px' }}/>}
    </div>
  );
};

window.HomeScreen = HomeScreen;
