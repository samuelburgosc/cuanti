# Gastos Generales — Diseño

**Fecha:** 2026-04-13  
**Estado:** Aprobado

---

## Resumen

Permitir registrar gastos generales del negocio (arriendo, transporte, packaging, etc.) para que el dashboard muestre la ganancia real (ventas menos gastos). La tabla `gastos_generales` ya existe en la BD.

---

## Base de datos

La tabla ya existe. No se requiere migración.

```sql
-- ya existe:
gastos_generales (id, fecha, descripcion, categoria_gasto, monto, local_id, usuario_id, notas)
```

---

## Categorías predefinidas

```javascript
const CATEGORIAS_GASTO = [
  { id: 'arriendo',    label: 'Arriendo',    icon: '🏠' },
  { id: 'transporte',  label: 'Transporte',  icon: '🚚' },
  { id: 'packaging',   label: 'Packaging',   icon: '📦' },
  { id: 'publicidad',  label: 'Publicidad',  icon: '📣' },
  { id: 'servicios',   label: 'Servicios',   icon: '📱' },
  { id: 'comisiones',  label: 'Comisiones',  icon: '💸' },
  { id: 'otro',        label: 'Otro',        icon: '✏️' },
];
```

Si la categoría es "Otro", se muestra un campo adicional "¿Cuál?" para escribir la descripción libre.

---

## Dashboard — Hero

El hero del dashboard pasa de mostrar solo ganancia bruta a mostrar **ganancia real**:

- Etiqueta: "Ganancia real este mes" (en lugar de "Ganancia este mes")
- Número principal `dash-hero-gan`: ganancia de ventas **menos** gastos del mes
- Nueva línea debajo: "Ventas $X — Gastos $Y" en gris pequeño (id: `dash-hero-gastos-sub`)

Si no hay gastos registrados, el número es igual que antes y la línea de gastos no aparece.

## Dashboard — Botón registrar gasto

Después del stats strip (`dash-stats-strip`), antes de "Atención ahora", agregar un botón compacto:

```html
<button onclick="abrirRegistrarGasto()" class="btn sec" 
  style="width:100%;margin-bottom:20px;font-size:13px;">
  ＋ Registrar gasto
</button>
```

Solo visible para el Dueño (misma lógica de roles que el resto de la app).

## Modal / Sheet de registro de gasto

Al tocar "Registrar gasto", aparece un bottom sheet (mismo patrón que el sheet de inventario existente) con:

1. **Categoría** — grid de pills con las 7 categorías. Una seleccionada a la vez.
2. **Descripción** — campo de texto (obligatorio si categoría es "Otro", opcional para las demás)
3. **Monto** — campo numérico con prefijo $
4. **Fecha** — por defecto hoy, editable (input type=date)
5. **Botón "Guardar gasto →"**

Al guardar:
- INSERT en `gastos_generales`
- Agregar al cache `gastosDB`
- Actualizar el hero del dashboard
- Toast de confirmación

---

## Análisis — Tab "Gastos"

Se agrega una nueva tab "Gastos" al final del selector de períodos en Análisis (`#analisis-tabs`).

Al seleccionar esta tab, se muestra:

- **Resumen del mes**: total gastado (grande, en rojo), número de gastos registrados
- **Por categoría**: barras proporcionales mostrando cuánto se gastó en cada categoría
- **Lista de gastos**: cada ítem muestra icono de categoría, descripción, fecha y monto
- **Estado vacío**: "Sin gastos registrados este mes. Agrega uno desde el Dashboard."

La tab de Gastos siempre muestra el mes actual (no cambia según el período seleccionado en las otras tabs).

---

## Cache `gastosDB`

Nuevo array global `gastosDB` cargado al inicio con:
```javascript
async function cargarGastos() {
  // carga los últimos 200 gastos_generales ordenados por fecha descendente
  // limit 200 es suficiente para una micropyme con años de historia
}
```

Se carga en `cargarDatos()` e `initDB()`.

---

## Cálculo de ganancia real

```javascript
function calcGastosMes() {
  const hoy = new Date();
  return gastosDB
    .filter(g => {
      const d = new Date(g.fecha);
      return d.getMonth() === hoy.getMonth() && d.getFullYear() === hoy.getFullYear();
    })
    .reduce((s, g) => s + g.monto, 0);
}
```

`gananciaReal = ganMes - calcGastosMes()`

---

## Fuera de alcance

- Editar o eliminar gastos registrados
- Gastos recurrentes automáticos
- Múltiples meses en la tab de Gastos
- Separar gastos por local
