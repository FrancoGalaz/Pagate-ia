// Inventario tab — search, tabs (productos/materiales), item list w/ stock badge

const inventoryMock = [
  { name: 'Aceite Motor 5W-30',   type: 'material', price: 89.50,  stock: 24, unit: 'litros', status: 'ok' },
  { name: 'Filtro de Aceite',     type: 'material', price: 45.00,  stock: 3,  unit: 'piezas', status: 'low' },
  { name: 'Pastillas de Freno',   type: 'product',  price: 280.00, stock: 0,  unit: 'juegos', status: 'critical' },
  { name: 'Líquido de Frenos',    type: 'material', price: 65.00,  stock: 18, unit: 'litros', status: 'ok' },
  { name: 'Bujías NGK Premium',   type: 'product',  price: 95.00,  stock: 2,  unit: 'piezas', status: 'low' },
  { name: 'Kit de Embrague',      type: 'product',  price: 1850,   stock: 7,  unit: 'juegos', status: 'ok' },
];

const statusColor = { ok: T.success, low: T.warning, critical: T.error };
const statusLabel = { ok: 'OK', low: 'Bajo', critical: 'Sin stock' };

const InventarioScreen = () => {
  const [tab, setTab] = React.useState('product');
  const [q, setQ] = React.useState('');
  const items = inventoryMock.filter(i => i.type === tab &&
    i.name.toLowerCase().includes(q.toLowerCase()));

  return (
    <PhoneShell>
      <ScreenBody>
        <div style={{ padding: '24px 24px 0' }}>
          <div style={{ fontSize: 24, fontWeight: 800, color: T.textPrimaryDark, letterSpacing: -0.3 }}>
            Inventario
          </div>

          {/* Search */}
          <div style={{
            marginTop: 16, height: 48, borderRadius: 20,
            background: T.surfaceDark, border: `1px solid ${T.borderDark}`,
            display: 'flex', alignItems: 'center', padding: '0 16px', gap: 8,
          }}>
            <I.search size={20} color={T.textSecondaryDark} />
            <input value={q} onChange={e => setQ(e.target.value)}
              placeholder="Buscar producto o material..."
              style={{
                flex: 1, background: 'transparent', border: 'none', outline: 'none',
                color: T.textPrimaryDark, fontFamily: T.font, fontSize: 14,
              }} />
          </div>

          {/* Tabs */}
          <div style={{ display: 'flex', gap: 8, marginTop: 16 }}>
            {[{k: 'product', l: 'Productos'}, {k: 'material', l: 'Materiales'}].map(t => {
              const on = t.k === tab;
              return (
                <div key={t.k} onClick={() => setTab(t.k)} style={{
                  padding: '6px 20px', borderRadius: 100, cursor: 'pointer',
                  background: on ? T.brand : T.surfaceDark,
                  border: `1px solid ${on ? T.brand : T.borderDark}`,
                  color: on ? '#fff' : T.textSecondaryDark,
                  fontSize: 12, fontWeight: 600,
                  transition: 'all 200ms',
                }}>{t.l}</div>
              );
            })}
          </div>

          {/* Items */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 16 }}>
            {items.map((it, i) => (
              <div key={i} style={{
                padding: 16, borderRadius: 24,
                background: T.surfaceDark, border: `1px solid ${T.borderDark}`,
                display: 'flex', alignItems: 'center', gap: 12,
              }}>
                <div style={{
                  width: 44, height: 44, borderRadius: 16,
                  background: T.brand + '1F',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <I.inventory size={22} color={T.brand} />
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 14, fontWeight: 600, color: T.textPrimaryDark }}>{it.name}</div>
                  <div style={{ fontSize: 12, color: T.textSecondaryDark }}>
                    {it.stock} {it.unit} · ${it.price.toFixed(2)}
                  </div>
                </div>
                <div style={{
                  padding: '3px 10px', borderRadius: 100,
                  background: statusColor[it.status] + '1F',
                  fontSize: 11, fontWeight: 700, color: statusColor[it.status],
                  letterSpacing: 0.3,
                }}>{statusLabel[it.status]}</div>
              </div>
            ))}
          </div>

          <div style={{ height: 80 }} />
        </div>
      </ScreenBody>

      {/* FAB */}
      <div style={{
        position: 'absolute', right: 24, bottom: 112, zIndex: 25,
        width: 56, height: 56, borderRadius: '50%',
        background: T.brand, boxShadow: T.shadowBrandStrong,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        cursor: 'pointer',
      }}>
        <I.plus size={24} color="#fff" strokeWidth={2.5} />
      </div>

      <BottomNav active="inv" />
    </PhoneShell>
  );
};

window.InventarioScreen = InventarioScreen;
