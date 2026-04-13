# Descuentos — Diseño

**Fecha:** 2026-04-13  
**Estado:** Aprobado

---

## Resumen

Permitir aplicar descuentos (porcentaje o monto fijo) al registrar una venta. Los vendedores pueden descontar hasta un límite configurado por el dueño. El descuento se refleja en el historial y en los análisis.

---

## Flujo de venta (Paso 2)

- Debajo del bloque precio/cantidad, aparece un toggle colapsado: "Aplicar descuento +"
- Al tocarlo, se expande una sección con:
  - Selector de tipo: `%` o `$` (pills, igual que canal/pago)
  - Campo numérico para el valor del descuento
- El preview de ganancia ("Ganancia estimada") se recalcula en tiempo real
- Si el vendedor ingresa un valor que supera el límite máximo configurado, el campo muestra un mensaje de error: "Límite máximo: X%" y bloquea el botón de confirmar
- El dueño no tiene límite

## Paso 3 — Resultado

- En el desglose de ganancia se agrega una línea: "Descuento: −$X" (solo si hubo descuento)
- La ganancia final ya incluye el descuento descontado

## Historial

- Cada venta que tuvo descuento muestra una línea adicional en el detalle: "Descuento: −$X" en color naranja
- Los totales de ganancia reflejan el descuento automáticamente (el precio efectivo ya es el reducido)

## Configuración

- En la pantalla de Configuración, se agrega una nueva sección "Ventas" donde el dueño puede fijar el "Descuento máximo para vendedores" (0–100%)
- Valor por defecto: 0% (sin descuentos permitidos para vendedores)
- Se guarda en `localStorage` bajo la clave `cuanti_descuento_max_pct`
- El dueño nunca está limitado, independientemente de este valor

---

## Base de datos

Se agregan dos columnas a `detalle_ventas`:

```sql
ALTER TABLE detalle_ventas
  ADD COLUMN descuento_tipo text CHECK (descuento_tipo IN ('porcentaje', 'monto')) DEFAULT NULL,
  ADD COLUMN descuento_valor numeric DEFAULT 0;
```

- `descuento_tipo`: `'porcentaje'` o `'monto'`; `NULL` si no hubo descuento
- `descuento_valor`: el número ingresado (ej. `10` para 10%, `2000` para $2.000)

El `precio_unitario` guardado en `detalle_ventas` es el precio **después** del descuento, para que todos los cálculos de ganancia existentes sigan funcionando sin cambios.

---

## Lógica de cálculo

```javascript
// Aplicar descuento al precio
let precioFinal = precio;
if (descuentoTipo === 'porcentaje') {
  precioFinal = Math.round(precio * (1 - descuentoValor / 100));
} else if (descuentoTipo === 'monto') {
  precioFinal = Math.max(0, precio - descuentoValor);
}

// Validar límite para vendedores
const pctEfectivo = ((precio - precioFinal) / precio) * 100;
if (rolActual === 'Vendedor' && pctEfectivo > descuentoMaxPct) {
  // bloquear confirmación
}

// Ganancia (igual que siempre, pero con precioFinal)
const comision = canal === 'Sotos' ? Math.min(Math.round(precioFinal * 0.15), 10000) : 0;
const ganancia = (precioFinal - costo) * cantidad - comision;
```

---

## Lo que NO cambia

- La lógica de comisión Sotos se aplica sobre el precio final (ya con descuento)
- El stock se descuenta igual
- El flujo de 3 pasos no cambia en estructura

---

## Fuera de alcance

- Descuentos automáticos por volumen o cliente frecuente
- Códigos de cupón
- Descuentos a nivel de pedido completo (multi-producto)
