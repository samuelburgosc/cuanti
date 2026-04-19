# Multi-Local Robusto — Design Spec

**Fecha:** 2026-04-18
**Alcance:** Gestión de locales, vista consolidada para el Dueño, análisis comparativo entre locales

---

## Objetivo

Permitir que el dueño de una pyme con 2+ locales gestione todo desde una sola app: ver qué pasa en cada local, comparar rendimiento, identificar qué productos venden más en cada uno, y tomar decisiones de crecimiento con datos claros.

**Preguntas que responde:**
- "¿A cuál de mis locales le fue mejor este mes?"
- "¿Qué vende cada local que el otro no vende?"
- "¿Cómo están los números de cada local comparados?"

---

## Usuarios

**Dueño:** ve todos los locales consolidados. Puede filtrar por local específico. Gestiona locales y usuarios.

**Vendedor:** ve y opera solo su propio local (`_currentUser.local_id` fijo). No tiene selector de local. No cambia nada de su experiencia actual.

---

## Arquitectura

### Variable `_activeLocal`

Nueva variable global (junto a `_currentUser`):

```js
let _activeLocal = null; // null = todos | number = local_id específico
```

- Solo el Dueño puede modificarla
- Se persiste en `localStorage` con clave `cuanti_active_local`
- Al cargar la app: se restaura desde localStorage si el usuario es Dueño
- Todas las queries del Dueño aplican `.eq('local_id', _activeLocal)` cuando no es null
- Cuando es null: no se agrega filtro de local → trae datos de todos los locales

### Cambios en queries existentes

Funciones afectadas por `_activeLocal`:
- `cargarDatos()` → `cargarInventario()`, `cargarVentas()`, `cargarGastos()`

**Lógica de filtro por local:**
```js
// Dueño con local activo → filtra por ese local
// Dueño sin local activo (null) → no filtra, trae todos los locales
// Vendedor → siempre filtra por su propio local_id
function localFiltro() {
  if (_currentUser?.rol !== 'Dueño') return _currentUser?.local_id;
  return _activeLocal; // null = sin filtro (todos)
}
```

En las queries: si `localFiltro()` retorna un valor, se agrega `.eq('local_id', localFiltro())`. Si retorna `null`, no se agrega el filtro.

**El Vendedor no cambia:** `localFiltro()` siempre retorna su `local_id`. Su experiencia es idéntica a hoy.

### Sin cambios de schema

La tabla `locales` ya tiene todos los campos necesarios:
```sql
locales (id, nombre, direccion, activo, color)
```
No se crean tablas nuevas ni se agregan columnas.

---

## Lo que se construye

### 1. Gestión de locales (pantalla Locales — parte superior)

**Lista de locales:**
- Nombre, dirección, badge activo/inactivo, avatares de usuarios asignados
- Cada item es tocable → abre sheet "Editar local"
- Botón "＋ Nuevo local" (solo Dueño)

**Sheet "Nuevo local":**
- Campo: Nombre (obligatorio)
- Campo: Dirección (opcional)
- Botón "Crear" → `INSERT` en tabla `locales`, `activo: true`

**Sheet "Editar local":**
- Campo: Nombre
- Campo: Dirección
- Toggle: Activo / Inactivo
  - Si tiene ventas registradas: solo puede desactivarse, no eliminarse (botón "Eliminar" deshabilitado con tooltip explicativo)
  - Si no tiene ventas: puede eliminarse con confirmación
- Sección "Usuarios": lista de usuarios asignados a este local con opción de reasignar a otro local (`UPDATE usuarios SET local_id = ? WHERE id = ?`)

**Reasignar usuario:** también disponible desde Configuración → Usuarios (sheet de usuario agrega selector de local).

---

### 2. Dashboard — strip comparativo

**Visible solo para:** Dueño con 2+ locales activos.

**Posición:** debajo del hero de ganancia, antes del stats strip.

**Estado normal (sin filtro activo):**
```
🏪 Local 1   $120.000   |   Local 2   $85.000
```
Muestra ganancia del mes de cada local. Toque → navega a pantalla Locales.

**Estado con filtro activo (`_activeLocal` !== null):**
```
[Local 1 ×]   Mostrando datos de Local 1
```
Chip con el nombre del local activo + botón × para limpiar el filtro (volver a "Todos").

**HTML:** `<div id="dash-local-strip">` entre el hero y el stats strip.

**Lógica:** `renderDashboard()` calcula ganancia del mes por local desde `ventasDB` agrupando por `local_id`, pobla el strip.

---

### 3. Pantalla Locales — análisis comparativo (parte inferior)

Debajo de la sección de gestión. Visible solo si hay 2+ locales activos con datos.

#### a) KPIs lado a lado

Dos columnas (una por local), mismas métricas:

| Métrica | Local 1 | Local 2 |
|---------|---------|---------|
| Ganancia mes | $120.000 | $85.000 |
| Ventas | 34 | 21 |
| Ticket prom. | $3.529 | $4.047 |
| Margen | 42% | 38% |

#### b) Barra de participación

```
Local 1 ████████░░ 59%   Local 2 ██████░░░░ 41%
```
Texto: "Local 1 generó el 59% de la ganancia este mes"

#### c) Top 3 productos por local

Dos listas paralelas ordenadas por ganancia del mes. Si un producto no aparece en un local, se muestra vacío en esa columna.

#### d) Top categorías por local

Qué categoría genera más ganancia en cada local (agrupando por `categorias.nombre` via join).

#### e) Insights accionables

Generados automáticamente comparando los datos de ambos locales. Máximo 3 insights, ordenados por relevancia:

- **Diferencia de margen:** "El margen de Local 1 es mejor ($X vs $Y por venta)"
- **Producto exclusivo:** "El producto más vendido en Local 1 casi no se vende en Local 2 — podrías expandirlo"
- **Categoría dominante:** "Local 2 vende 3× más streetwear que Local 1"
- **Sin ventas recientes:** "Local 2 no registra ventas en los últimos 3 días"

---

## Datos

| Campo | Fuente | Notas |
|-------|--------|-------|
| Ganancia por local | `ventasDB` agrupado por `local_id` | Ya disponible en cache |
| Nombre del local | `_localesDB` (nuevo cache) | `SELECT * FROM locales WHERE activo = true` |
| Usuarios por local | `usuarios` filtrado por `local_id` | Carga bajo demanda en sheet de gestión |
| `_activeLocal` | `localStorage` key `cuanti_active_local` | Restaurado al iniciar si rol === 'Dueño' |

**Nuevo cache `_localesDB`:** array de locales activos cargado en `cargarDatos()`. Se usa en el strip del dashboard y en la pantalla Locales.

---

## Archivos a modificar

- `index.html` únicamente:
  - CSS: estilos para strip comparativo, KPIs lado a lado, barra de participación
  - HTML dashboard: agregar `#dash-local-strip`
  - `cargarDatos()`: agregar `cargarLocales()` al `Promise.all`
  - `renderDashboard()`: poblar strip comparativo
  - Queries existentes: aplicar `_activeLocal` como filtro opcional para el Dueño
  - Pantalla Locales: reescribir `renderLocales()` con gestión + análisis comparativo
  - Nuevas funciones: `abrirNuevoLocal()`, `guardarNuevoLocal()`, `abrirEditarLocal(id)`, `guardarEditarLocal()`, `desactivarLocal(id)`, `reasignarUsuario(userId, localId)`
  - Configuración → Usuarios: agregar selector de local en sheet de usuario

---

## Lo que NO incluye

- Roles distintos por local (el Dueño es dueño de todo)
- Permisos granulares por local
- Historial de cambios de local por usuario
- Transferencias entre locales (spec separado, depende de este)
- Exportes (spec separado, independiente)

---

## Criterios de éxito

1. El dueño abre la app y en el dashboard ve en 2 segundos cuánto ganó cada local
2. Puede ir a Locales y ver una comparación clara de KPIs, productos y categorías
3. Los insights le dicen algo accionable, no solo datos
4. Puede crear un local nuevo en menos de 1 minuto
5. Puede desactivar un local sin perder su historial
6. El vendedor no nota ningún cambio en su experiencia
