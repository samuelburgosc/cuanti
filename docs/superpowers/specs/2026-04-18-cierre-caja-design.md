# Cierre de Caja — Design Spec

**Fecha:** 2026-04-18
**Alcance:** POS básico — resumen diario de caja sin turnos formales

---

## Objetivo

Permitir que el microemprendedor sepa al final del día cuánto tiene en caja y si cuadra con lo que registró en la app. Sin flujos de apertura/cierre formal, sin terminología contable.

**Pregunta que responde:** "¿Cuánto tengo en caja ahora y cuadra?"

---

## Lo que se construye

### 1. Dashboard — fila de caja rápida

Una fila que aparece **solo si hay ventas en efectivo hoy**. Se ubica debajo del stats strip. Muestra el monto de efectivo cobrado hoy. Al tocarlo navega al Tab Hoy de Análisis.

**HTML:** `<div id="dash-caja-row">` debajo de `#dash-stats-strip`

**Lógica:** `renderDashboard()` calcula efectivo del día (ventas con `metodo_pago === 'Efectivo'` y fecha hoy). Si > 0, muestra el row; si no, lo oculta.

---

### 2. Tab Hoy — Cierre de caja elevado y expandido

El bloque "Cierre de caja" que hoy está dentro del expandible `#hoy-detalle` se mueve **arriba del expandible**, visible siempre. Se enriquece con:

**a) Resumen por método de pago** (ya existe, se mantiene igual)

**b) Sección "¿Cuadró la caja?"** — nueva, debajo del resumen de pagos:
- Dos botones: `✅ Cuadró` / `⚠️ Hay diferencia`
- Si selecciona "Hay diferencia": aparece input numérico para anotar cuánto falta/sobra + textarea opcional "¿Qué pasó?"
- Botón "Guardar nota" → persiste en `localStorage` por fecha
- Estado persistente en `localStorage` por fecha: si ya cuadró hoy, muestra badge verde "✅ Cuadró hoy"

**No se crea tabla nueva. No afecta el cálculo de ganancia.** La diferencia es informativa — un registro de lo que pasó, no un ajuste contable.

---

## Datos

| Campo | Fuente | Notas |
|-------|--------|-------|
| Efectivo cobrado | `ventasDB` filtrado por hoy + `metodo_pago === 'Efectivo'` | Ya disponible |
| Transferencia cobrada | `ventasDB` filtrado por hoy + `metodo_pago === 'Transferencia'` | Ya disponible |
| Tarjeta cobrada | `ventasDB` filtrado por hoy + `metodo_pago` includes 'Tarjeta' | Ya disponible |
| Estado "cuadró" | `localStorage` key `cuanti_caja_YYYY-MM-DD` | `"ok"` / `JSON: {diff, nota}` |

---

## UI — comportamiento

**Dashboard fila caja:**
```
🪙 En caja hoy   $12.500 efectivo   →
```
Toque → `goTo('analisis')` + activa tab Hoy

**Tab Hoy — cierre de caja (siempre visible):**
```
┌─────────────────────────────────┐
│ Cierre de caja                  │
│ Lo que cobraste hoy             │
│                                 │
│ 💵 Efectivo         $12.500     │
│ 📲 Transferencia    $45.000     │
│ 💳 Tarjeta          $8.000      │
│                                 │
│ 💵 En tu caja: $12.500 ←solo efectivo
│                                 │
│ [✅ Cuadró]  [⚠️ Hay diferencia] │
└─────────────────────────────────┘
```

Si ya se marcó "Cuadró" hoy → badge verde en lugar de botones.
Si se marcó diferencia → muestra el monto registrado + opción editar.

---

## Archivos a modificar

- `index.html` únicamente:
  - HTML dashboard: agregar `#dash-caja-row`
  - `renderDashboard()`: calcular efectivo y poblar el row
  - `renderAnalisis()` tab Hoy: mover cierre de caja fuera del expandible, agregar sección "¿Cuadró?"
  - Nuevas funciones: `cajaMarcarOk()`, `cajaAbrirDiferencia()`, `cajaGuardarDiferencia()`
  - CSS: estilos para caja-row en dashboard y botones de cuadre

---

## Lo que NO incluye

- Apertura formal de turno / monto inicial
- Historial de cierres de caja (queda para fase multi-local)
- Integración con impresora o ticket de caja
- Reporte exportable de caja

---

## Criterios de éxito

1. El microemprendedor abre la app y ve cuánto tiene en efectivo sin navegar
2. Al final del día puede marcar "cuadró" en 2 taps
3. Si hay diferencia, queda registrada con nota
4. Todo funciona en móvil, sin scroll horizontal, sin texto cortado
