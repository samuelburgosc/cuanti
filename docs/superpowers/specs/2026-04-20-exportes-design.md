# Exportes — Design Spec

**Fecha:** 2026-04-20  
**Alcance:** Exportar datos de ventas, inventario y gastos en CSV desde Configuración

---

## Objetivo

Permitir que el usuario descargue respaldos de sus datos operativos en CSV, compatibles con Excel y Google Sheets. Sin pantallas nuevas, sin llamadas a Supabase — todo desde los caches en memoria.

---

## Ubicación en la UI

Sección nueva **"Exportar datos"** en la pantalla de Configuración, debajo de la sección de equipo.

---

## UI

```
Exportar datos

Período
[Este mes]  [Mes anterior]  [Personalizado ▾]
            (desde [mes ▾]  hasta [mes ▾])

[↓ Ventas CSV]   [↓ Inventario CSV]   [↓ Gastos CSV]
```

- Los chips "Este mes" / "Mes anterior" / "Personalizado" controlan el rango.
- "Personalizado" muestra dos `<input type="month">` (desde / hasta).
- El filtro de período aplica a Ventas y Gastos. Inventario ignora el período (es snapshot del estado actual).
- Los tres botones están siempre habilitados. Si no hay datos en el rango, muestran un toast "No hay datos para exportar en ese período."

---

## Exports

### Ventas CSV

**Columnas:** fecha, hora, vendedor, producto, variante, SKU, cantidad, precio_unitario, costo_unitario, ganancia, canal, pago, local  
**Filtro:** ventas cuya `fecha_hora` cae dentro del período seleccionado  
**Nombre:** `cuanti-ventas-YYYY-MM.csv` (si período = un mes) o `cuanti-ventas-YYYY-MM-DD_YYYY-MM-DD.csv` (personalizado)  
**Fuente:** `ventasDB` + `detalle_ventas` ya cargados en memoria

### Inventario CSV

**Columnas:** SKU, producto, variante, local, stock_actual, stock_minimo, costo_ultima_compra, precio_venta  
**Filtro:** ninguno (snapshot del momento de descarga)  
**Nombre:** `cuanti-inventario-YYYY-MM-DD.csv`  
**Fuente:** `skuDB` en memoria

### Gastos CSV

**Columnas:** fecha, descripcion, categoria, monto, local  
**Filtro:** gastos cuya `fecha` cae dentro del período seleccionado  
**Nombre:** `cuanti-gastos-YYYY-MM.csv` o con rango personalizado  
**Fuente:** `gastosDB` en memoria

---

## Lógica de período

```js
// "Este mes": desde el 1ro del mes actual hasta hoy
// "Mes anterior": desde el 1ro del mes anterior hasta el último día de ese mes
// "Personalizado": desde el 1ro del mes "desde" hasta el último día del mes "hasta"
```

La comparación se hace contra `fecha_hora` (ventas) y `fecha` (gastos) parseados como Date.

---

## Formato CSV

- BOM (`\ufeff`) para compatibilidad con Excel en Windows/Mac
- Separador: coma
- Strings con coma o comillas: envueltos en `"..."` con comillas escapadas como `""`
- Fechas: `YYYY-MM-DD`
- Números: sin separador de miles, punto decimal

---

## Archivos a modificar

- `index.html` únicamente:
  - HTML: sección "Exportar datos" en `#screen-config`
  - CSS: chips de período, layout de botones
  - JS: `exportarVentasCSV()` (extender con filtro período + columna vendedor), `exportarInventarioCSV()`, `exportarGastosCSV()`, `_exportPeriodo` state

---

## Lo que NO incluye

- Export en PDF
- Export de compras
- Pantalla separada de Exportes en el nav
- Envío por email o WhatsApp
- Reporte de desempeño por vendedor separado (la columna vendedor en Ventas CSV permite este análisis en Excel)
