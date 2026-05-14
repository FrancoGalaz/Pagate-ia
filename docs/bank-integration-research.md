# Integración Bancaria Chile — Investigación Técnica

## Contexto
Pagate-IA necesita sincronización automática de gastos bancarios para
independientes chilenos. Esta investigación evalúa opciones viables.

---

## 1. Belvo (Recomendado) — Open Finance Platform

**Cobertura Chile:** Sí — soporta Banco de Chile, Santander, BCI,
Scotiabank, BancoEstado, Itaú, y más.

**Qué ofrece:**
- Transacciones detalladas (fecha, monto, comercio, categoría)
- Saldos de cuenta
- Categorización automática de transacciones
- Verificación de ingresos
- Widget Connect (UI embebible para que usuarios vinculen sus bancos)

**Requisitos:**
- Contrato comercial con Belvo
- Plan gratuito: Sandbox con límites (100 links/mes aprox.)
- Plan Pro: ~$1,500-3,000 USD/año (dependiendo de volumen)
- Integración REST API (funciona con cualquier stack, incluye SDKs)

**Integración técnica:**
- REST API estándar (POST/GET)
- Widget Connect embebible en Web/Mobile
- Webhook para sincronización en tiempo real
- En Flutter: usar paquete `http` o el widget webview

**Ventajas:**
- Cobertura real en Chile
- Widget listo para integrar (no diseñar UI bancaria)
- Categorización automática incluida
- Cumple con regulación (es Partner Fintech registrado)

**Desventajas:**
- Costo recurrente
- Dependencia de tercero
- El usuario debe autenticarse en el banco via widget

---

## 2. Ley Fintech Chile (CMF) — APIs Reguladas

**Estado:** La Ley 21.521 (Ley Fintech) entró en vigencia Feb 2023.
El Reglamento de Interoperabilidad (open banking) está en
implementación gradual.

**Lo que permitirá:**
- APIs estandarizadas de bancos para compartir datos transaccionales
- Acceso con consentimiento del usuario
- Estándares definidos por CMF

**Estado actual (2026):**
- Implementación parcial por algunos bancos
- No hay un agregador universal consolidado como en Brasil/México
- Varios bancos aún no tienen APIs públicas funcionales

**Conclusión:** Prometedor a mediano plazo, pero no listo para
producción hoy como única solución para una app fintech.

---

## 3. FinGenius (antes Finerio, ahora parte de FinGenius)

**Cobertura:** Principalmente México. Cobertura Chile limitada o
nula.

**Qué ofrece:**
- Agregación de cuentas bancarias
- Categorización de transacciones
- Enrichment de datos

**Ventajas:**
- Enfoque LatAm
- SDK móvil

**Desventajas:**
- Cobertura Chile no confirmada
- Proceso de onboarding lento

---

## 4. Plaid

**Cobertura:** Estados Unidos, Canadá, Europa. **No tiene
cobertura en Chile.**

---

## 5. Scraping Bancario (No recomendado)

Algunas apps chilenas han usado scraping (simular login del
usuario en el banco y extraer datos del HTML).

**Riesgos:**
- Viola términos de servicio de los bancos
- Frágil (cualquier cambio en el sitio del banco rompe la integración)
- Riesgo legal (Ley de Delitos Informáticos)
- Sin categorización automática

**No recomendado para producción.**

---

## 6. Alternativa: Carga Manual Asistida

Para la Fase 1 de bank sync, considerar:

- Permitir al usuario **subir PDF/extracto bancario**
- Parsear automáticamente las transacciones
- Categorizar con IA (OpenRouter)

**Ventajas:**
- Sin integración bancaria
- El usuario controla sus datos
- Implementación rápida (días, no meses)
- Sin costos recurrentes de API

**Desventajas:**
- No es automático
- Depende de que el usuario descargue su extracto

---

## Recomendación para Pagate-IA

### Fase 1 (Inmediata, 1-2 semanas): Carga Manual Asistida
- Agregar pantalla "Importar extracto"
- Parsear PDF/CSV bancario (formato BancoEstado, Santander, etc.)
- Usar OpenRouter AI para categorizar transacciones automáticamente
- Confirmación manual antes de guardar

### Fase 2 (Mediano plazo, 1-2 meses): Belvo Connect
- Contratar plan Belvo adecuado
- Integrar Connect Widget
- Vincular automáticamente transacciones a Firestore
- Sincronización periódica (diaria/semanal)

### Fase 3 (Largo plazo, 6-12 meses): APIs CMF
- Cuando la regulación chilena esté madura
- Posible migración de Belvo a APIs directas
- Reducción de costos

---

## Referencias
- Belvo: https://belvo.com
- Belvo Docs: https://docs.belvo.com
- Ley Fintech Chile (CMF): https://www.cmfchile.cl
- FinGenius: https://fingenius.com
