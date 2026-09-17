import { describe, expect, it } from 'vitest';
import { buildSystemPrompt, formatMoney, type PromptContext } from '../src/prompt';

const fullContext: PromptContext = {
  profile: {
    name: 'Marta',
    businessName: 'Taller Luna',
    businessType: 'Cerámica',
    currency: 'CLP',
    monthlyGoal: 800000,
    plan: 'pro',
    hourlyRate: { desiredMonthlySalary: 600000, availableHoursPerMonth: 120, hourlyValue: 5000 },
  },
  latestMonth: { monthKey: '2026-09', totalIncome: 450000, totalExpenses: 120000, transactionCount: 7 },
  recentTransactions: [
    { title: 'Venta taza', amount: 15000, type: 'income', category: 'Ventas', date: new Date('2026-09-15T12:00:00Z') },
    { title: 'Arcilla', amount: 20000, type: 'expense', category: 'Materiales', date: new Date('2026-09-10T12:00:00Z') },
  ],
  inventory: { products: 12, materials: 5 },
  today: new Date('2026-09-17T15:00:00Z'),
};

describe('buildSystemPrompt', () => {
  it('incluye todas las secciones con datos completos', () => {
    const prompt = buildSystemPrompt(fullContext);

    expect(prompt).toContain('## Rol');
    expect(prompt).toContain('## Perfil del negocio');
    expect(prompt).toContain('## Valor hora');
    expect(prompt).toContain('## Resumen del último mes');
    expect(prompt).toContain('## Últimas transacciones');
    expect(prompt).toContain('## Inventario');
    expect(prompt).toContain('## Instrucciones de respuesta');

    expect(prompt).toContain('Marta');
    expect(prompt).toContain('Taller Luna');
    expect(prompt).toContain('Cerámica');
    expect(prompt).toContain('Plan: pro');
    expect(prompt).toContain('2026-09');
    expect(prompt).toContain('Movimientos registrados: 7');
    expect(prompt).toContain('Venta taza');
    expect(prompt).toContain('Arcilla');
    expect(prompt).toContain('2026-09-15');
    expect(prompt).toContain('Productos registrados: 12');
    expect(prompt).toContain('Materiales registrados: 5');
    expect(prompt).toContain('Fecha de hoy: 2026-09-17');
    expect(prompt).toContain(formatMoney(5000, 'CLP'));
    expect(prompt).toContain(formatMoney(450000, 'CLP'));
  });

  it('incluye instrucciones de concisión y de no inventar datos', () => {
    const prompt = buildSystemPrompt(fullContext);
    expect(prompt).toMatch(/máximo 3 párrafos/i);
    expect(prompt).toMatch(/No inventes/i);
    expect(prompt).toMatch(/español neutro/i);
  });

  it('maneja usuario sin perfil ni datos', () => {
    const prompt = buildSystemPrompt({
      profile: null,
      latestMonth: null,
      recentTransactions: [],
      inventory: { products: 0, materials: 0 },
    });
    expect(prompt).toContain('todavía no completó su perfil');
    expect(prompt).toContain('aún no calculó su valor hora');
    expect(prompt).toContain('No hay meses con movimientos');
    expect(prompt).toContain('Sin transacciones registradas');
    expect(prompt).toContain('Expresa los montos en CLP');
  });

  it('respeta la moneda del perfil y limita a 10 transacciones', () => {
    const many = Array.from({ length: 15 }, (_, i) => ({
      title: `Tx ${i}`,
      amount: 100 + i,
      type: 'income' as const,
      category: '',
      date: null,
    }));
    const prompt = buildSystemPrompt({
      profile: { name: 'Ana', currency: 'ARS' },
      latestMonth: null,
      recentTransactions: many,
      inventory: { products: 0, materials: 0 },
    });
    expect(prompt).toContain('Moneda: ARS');
    expect(prompt).toContain('Tx 9');
    expect(prompt).not.toContain('Tx 10');
  });
});

describe('formatMoney', () => {
  it('formatea CLP sin decimales', () => {
    expect(formatMoney(15000, 'CLP')).toMatch(/15\.000/);
  });

  it('no explota con moneda inválida', () => {
    expect(formatMoney(100, 'XXXX')).toContain('XXXX');
  });
});
