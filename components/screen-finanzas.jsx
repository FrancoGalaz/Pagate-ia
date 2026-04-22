// Finanzas tab — month pills, summary card, goal progress, fixed expenses

const financesMock = {
  months: [
    { month: 'Marzo 2025',   totalIncome: 23800, totalExpenses: 8300, monthlyGoal: 35000 },
    { month: 'Febrero 2025', totalIncome: 31200, totalExpenses: 9100, monthlyGoal: 35000 },
    { month: 'Enero 2025',   totalIncome: 28500, totalExpenses: 7800, monthlyGoal: 30000 },
  ],
  fixed: [
    { name: 'Renta del local',     category: 'Infraestructura', amount: 5000 },
    { name: 'Electricidad',        category: 'Servicios',       amount: 850 },
    { name: 'Internet y teléfono', category: 'Servicios',       amount: 450 },
  ],
};

const fmtMoney = (v) =>
  '$' + v.toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',');

const FinanzasScreen = () => {
  const [selIdx, setSelIdx] = React.useState(0);
  const sel = financesMock.months[selIdx];
  const balance = sel.totalIncome - sel.totalExpenses;
  const progress = Math.min(1, sel.totalIncome / sel.monthlyGoal);

  return (
    <PhoneShell>
      <ScreenBody>
        <div style={{ padding: '24px 24px 0' }}>
          <div style={{ fontSize: 24, fontWeight: 800, letterSpacing: -0.3, color: T.textPrimaryDark }}>
            Finanzas
          </div>

          {/* Month selector */}
          <div style={{ display: 'flex', gap: 8, marginTop: 16, overflowX: 'auto', paddingBottom: 4 }}>
            {financesMock.months.map((m, i) => {
              const on = i === selIdx;
              return (
                <div key={i} onClick={() => setSelIdx(i)} style={{
                  padding: '6px 16px', borderRadius: 100,
                  background: on ? T.brand : T.surfaceDark,
                  border: `1px solid ${on ? T.brand : T.borderDark}`,
                  fontSize: 12, fontWeight: 600,
                  color: on ? '#fff' : T.textSecondaryDark,
                  whiteSpace: 'nowrap', cursor: 'pointer',
                  transition: 'all 200ms',
                }}>{m.month}</div>
              );
            })}
          </div>

          {/* Summary card */}
          <div style={{
            marginTop: 24, padding: 24, borderRadius: 32,
            background: T.surfaceDark, border: `1px solid ${T.borderDark}`,
          }}>
            <StatRow label="Ingresos" value={sel.totalIncome} color={T.success} Arrow={I.arrowUp} />
            <div style={{ height: 1, background: T.borderDark, margin: '20px 0' }}/>
            <StatRow label="Gastos" value={sel.totalExpenses} color={T.error} Arrow={I.arrowDown} />
            <div style={{ height: 1, background: T.borderDark, margin: '20px 0' }}/>
            <StatRow label="Balance" value={balance} color={balance >= 0 ? T.brand : T.error}
              Arrow={I.wallet} bold />
          </div>

          {/* Goal progress */}
          <div style={{
            marginTop: 24, padding: 24, borderRadius: 32,
            background: T.surfaceDark, border: `1px solid ${T.borderDark}`,
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <div style={{ fontSize: 14, fontWeight: 700, color: T.textPrimaryDark }}>Meta Mensual</div>
              <div style={{ fontSize: 14, fontWeight: 700, color: T.brand }}>
                {Math.round(progress * 100)}%
              </div>
            </div>
            <div style={{ height: 10, borderRadius: 100, background: T.surfaceDark2,
              marginTop: 12, overflow: 'hidden' }}>
              <div style={{ width: `${progress * 100}%`, height: '100%', background: T.brand }}/>
            </div>
            <div style={{ fontSize: 12, color: T.textSecondaryDark, marginTop: 8 }}>
              Objetivo: ${sel.monthlyGoal.toLocaleString()}
            </div>
          </div>

          {/* Fixed expenses */}
          <div style={{ marginTop: 24 }}>
            <div style={{ fontSize: 16, fontWeight: 700, color: T.textPrimaryDark }}>Gastos Fijos</div>
            <div style={{
              marginTop: 16, borderRadius: 32,
              background: T.surfaceDark, border: `1px solid ${T.borderDark}`,
              overflow: 'hidden',
            }}>
              {financesMock.fixed.map((e, i) => (
                <div key={i}>
                  <div style={{ display: 'flex', alignItems: 'center',
                    padding: '12px 16px', gap: 12 }}>
                    <div style={{
                      width: 36, height: 36, borderRadius: 12,
                      background: T.error + '1F',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                    }}>
                      <I.receipt size={16} color={T.error} />
                    </div>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontSize: 14, fontWeight: 600, color: T.textPrimaryDark }}>{e.name}</div>
                      <div style={{ fontSize: 12, color: T.textSecondaryDark }}>{e.category}</div>
                    </div>
                    <div style={{ fontSize: 14, fontWeight: 700, color: T.error }}>
                      -${e.amount.toLocaleString()}
                    </div>
                  </div>
                  {i < financesMock.fixed.length - 1 &&
                    <div style={{ height: 1, background: T.borderDark, margin: '0 16px' }}/>}
                </div>
              ))}
            </div>
          </div>
          <div style={{ height: 24 }} />
        </div>
      </ScreenBody>
      <BottomNav active="finance" />
    </PhoneShell>
  );
};

const StatRow = ({ label, value, color, Arrow, bold }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
    <div style={{
      width: 32, height: 32, borderRadius: 12, background: color + '1F',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>
      <Arrow size={16} color={color} />
    </div>
    <div style={{ flex: 1, fontSize: 14, fontWeight: bold ? 700 : 500, color: T.textSecondaryDark }}>
      {label}
    </div>
    <div style={{ fontSize: 16, fontWeight: 700, color: bold ? color : T.textPrimaryDark }}>
      {fmtMoney(Math.abs(value))}
    </div>
  </div>
);

window.FinanzasScreen = FinanzasScreen;
