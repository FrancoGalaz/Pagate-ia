# Estado del proyecto — Págate-IA

Actualizado el 2026-10-06. Rama `arquitectura-segura`. **Nada subido a GitHub**: el remoto
sigue en `f6d3a8d` de mayo. Todo el trabajo está en commits locales.

Documentos: [AUDITORIA-2026-09-29.md](AUDITORIA-2026-09-29.md) (272 hallazgos) ·
[DISENO-v2.md](DISENO-v2.md) (sistema visual) · [FICHA-PLAY.md](FICHA-PLAY.md) (ficha y
checklist del dueño) · [SEGURIDAD-DATOS-PLAY.md](SEGURIDAD-DATOS-PLAY.md) ·
[COMPETENCIA.md](COMPETENCIA.md) · [PLAN-PUBLICIDAD.md](PLAN-PUBLICIDAD.md)

## Verificación actual

```
flutter analyze    No issues found!
flutter test       312 passed
functions test     212 passed
landing test        63 passed
```

Los cuatro criterios de cierre del sistema visual, comprobados con grep sobre `lib/`:
cero tokens con sufijo `Dark`, cero `AppShadows`, cero gradientes, cero `Color(0x` fuera de
`app_constants.dart`.

## Qué se hizo

| Área | Estado |
|---|---|
| Sistema visual | Tema claro único, tipografía con pesos reales, moneda y meses en español de Chile |
| Mercado chileno | Tipo de documento (boleta de venta, honorarios, sin documento), comisión del medio de pago, valor hora **neto**, categorías del oficio |
| Asistente de IA | Resucitado: moría por un escaneo descendente de claves que Firestore rechaza. 36 tests nuevos donde había cero |
| Cuota de IA | De por vida (25 mensajes en el plan gratuito) en vez de diaria, historial recortado a 6, con devolución de cuota si el modelo falla |
| Requisitos de Play | Borrado de cuenta dentro de la app y por web, aviso de contenido generado por IA, botón de reporte, permisos limpios |
| Backend | Reglas con topes y límites, prompt a prueba de inyección, agregados con reintento |
| Errores | Dejaron de ser invisibles: el aviso se pintaba detrás de la hoja modal |
| Landing | Sin cifras ni testimonios inventados, con privacidad, términos y borrado de cuenta |
| Firma | Cadena verificada de punta a punta con keystore de demostración |

## Lo que falta, y es todo tuyo

Nada de esto es programación. Son tus cuentas.

### En la consola de Firebase, proyecto `pagate-17211`

1. **Habilitar Authentication** y activar Correo/contraseña. Comprobado hoy: responde
   `CONFIGURATION_NOT_FOUND`, así que nadie puede registrarse, el revisor de Google incluido.
   Es la causa número uno de rechazo.
2. **Crear la base de Firestore** en `southamerica-west1`. La región debe ser compatible con
   la del trigger y **no se puede cambiar después**.
3. **Plan Blaze** con alertas de presupuesto. Las funciones de 2ª generación lo exigen.
4. **Desplegar**: `APP_CHECK_SITE_KEY=... ./scripts/deploy-web.sh`

### Claves

5. **Clave de OpenRouter** con límite de crédito, en `openrouter.ai → Keys`. Cárgala con
   `firebase functions:secrets:set OPENROUTER_API_KEY`. Para probar en local va en
   `functions/.secret.local`, que ya tiene el hueco marcado. Sin ella el asistente no responde.
   **Revoca la clave antigua**, la que se compiló en builds viejos.
6. **Keystore real de subida**, fuera del repo y con respaldo. El actual es de demostración y
   su contraseña está en claro. La identidad de la app queda atada a esa clave **para siempre**.

### Publicación

7. **Publicar la landing**. Hoy las tres URL legales dan 404 y Play **exige** que la de
   privacidad responda. Rechazo casi automático si no.
8. **Cinco datos de identidad legal** en `landing/src/legal-meta.ts` y un correo de soporte
   atendido de verdad.
9. **12 probadores durante 14 días seguidos** si tu cuenta de desarrollador es personal y
   posterior a noviembre de 2023. Son días de calendario: conviene empezar ya.
10. **Formulario de Seguridad de los Datos** en Play Console. Las respuestas están en
    [SEGURIDAD-DATOS-PLAY.md](SEGURIDAD-DATOS-PLAY.md). Declarar que los datos financieros
    viajan a OpenRouter no es opcional.
11. **Capturas en 9:16**. Las del emulador salen en 9:20.

### Una decisión irreversible

12. Confirmar que `com.pagate.apppagate` es el identificador definitivo. **No se puede cambiar
    después de la primera subida.**

## Riesgos de rechazo, por probabilidad

| Riesgo | Por qué |
|---|---|
| El revisor no puede entrar | Authentication sin inicializar |
| Enlaces legales rotos | Las tres URL devuelven 404 |
| Función anunciada que no responde | Sin clave de OpenRouter, el asistente siempre falla |
| Seguridad de Datos incompleta | Hay datos financieros y van a un tercero |

## Orden sugerido

Primero el punto 1, que desbloquea todo lo demás y permite comprobar que la app funciona de
verdad contra producción. Después 2, 3, 5 y 4 para tener backend vivo. Luego 7 y 8, que son
los que Play revisa desde fuera. El 9 en paralelo desde el primer día, porque es calendario.
Lo último, 6 y el envío.
