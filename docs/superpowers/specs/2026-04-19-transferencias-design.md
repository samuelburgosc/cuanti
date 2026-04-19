# Transferencias entre Locales — Design Spec

**Fecha:** 2026-04-19
**Alcance:** Mover stock físico entre locales con trazabilidad completa y confirmación de recepción

---

## Objetivo

Permitir que un usuario envíe stock de un local a otro, que quede registrado, y que el local destino confirme la recepción. El sistema refleja el movimiento de stock en tiempo real sin crear conflictos operativos.

**Preguntas que responde:**
- "¿Cuánto de este artículo mandé al otro local esta semana?"
- "¿Qué traspasos están esperando confirmación?"
- "¿Por qué bajó el stock de este artículo en mi local?"

---

## Usuarios

**Dueño:** puede iniciar traspasos desde cualquier local hacia cualquier otro. Ve todos los traspasos de todos los locales. Puede confirmar recepción en cualquier local.

**Vendedor:** puede iniciar traspasos solo desde su propio local. Ve solo los traspasos que involucran su local. Puede confirmar recepción en su local.

---

## Tabla nueva: `transferencias`

```sql
transferencias (
  id               serial primary key,
  fecha_creacion   timestamptz default now(),
  variante_id      integer references variantes(id),
  local_origen_id  integer references locales(id),
  local_destino_id integer references locales(id),
  cantidad         integer not null,
  costo_unitario   numeric not null,       -- copiado de variante al momento del envío
  estado           text default 'pendiente', -- 'pendiente' | 'recibida' | 'cancelada'
  usuario_origen_id   integer references usuarios(id),
  usuario_destino_id  integer references usuarios(id), -- null hasta confirmar
  fecha_confirmacion  timestamptz                      -- null hasta confirmar
)
```

---

## Flujo de stock

### Al iniciar el traspaso
- Se crea un registro en `transferencias` con `estado = 'pendiente'`
- Se decrementa `stock_actual` en la variante de origen (`UPDATE variantes SET stock_actual = stock_actual - cantidad WHERE id = variante_id`)
- La variante de origen muestra etiqueta *"X en tránsito →"* en el inventario

### Al confirmar la recepción
- Se busca una variante con mismo `producto_id` + `talla_color` + `local_id = local_destino_id`
- **Si existe:** `stock_actual += cantidad`
- **Si no existe:** se crea nueva variante con `stock_actual = cantidad`, `costo_ultima_compra = costo_unitario` del traspaso, `stock_minimo = 0`, `activa = true`, SKU auto-generado (INSERT → Supabase trigger genera el SKU de 15 dígitos)
- Se actualiza `transferencias`: `estado = 'recibida'`, `usuario_destino_id`, `fecha_confirmacion = now()`
- Se recarga `skuDB` para reflejar el inventario actualizado

### Al cancelar (solo mientras está `pendiente`)
- Solo puede cancelar el usuario que inició o el Dueño
- Se restaura el stock: `stock_actual += cantidad` en la variante de origen
- Se actualiza `transferencias`: `estado = 'cancelada'`

---

## UI — Escáner (iniciar traspaso)

El panel `#ap-transfer` ya existe pero está vacío. Se reemplaza con:

```
🔄 Transferir entre locales

[Producto: Nike Air Max 42 — Stock: 5]
[⚠️ 2 en tránsito →]  ← visible si hay traspasos pendientes salientes

Destino:  [ Local Centro ▾ ]
Cantidad: [ 1 ]

[ Enviar → ]
```

**Lógica:**
- El selector de destino muestra todos los locales activos excepto el actual
- Si `cantidad > stock_actual`, el botón se deshabilita con texto *"Stock insuficiente"*
- Al presionar "Enviar →": INSERT en `transferencias`, UPDATE stock origen, toast *"Traspaso enviado a [Local]. Esperando confirmación."*
- El Dueño tiene además un selector "Origen" para elegir desde qué local envía

---

## UI — Inventario (etiqueta en tránsito)

En la vista de inventario, si una variante tiene traspasos `pendiente` salientes:
- Junto al stock aparece: `<span class="badge-transito">↗ X en tránsito</span>`
- Color: azul sutil (`--blue` con opacity baja), sin alarma — es información, no problema

---

## UI — Pantalla Locales (pendientes e historial)

### Badge en el nav
Si hay traspasos `pendiente` entrantes para el local activo del usuario: badge numérico rojo en el ícono de Locales en el nav.

### Sección "Por recibir"
Visible solo si hay traspasos pendientes entrantes. Aparece al tope del contenido de Locales.

```
Por recibir  (2)

┌─────────────────────────────────────────┐
│ Nike Air Max 42          Hace 2 horas   │
│ 3 unidades · desde Local Centro         │
│                    [ Confirmar recepción ] │
└─────────────────────────────────────────┘
```

- Botón "Confirmar recepción" → confirmar flujo descrito arriba
- Botón "Cancelar" (solo el Dueño o quien inició) aparece como texto pequeño debajo

### Sección "Historial de traspasos"
Siempre visible. Lista cronológica descendente.

```
Historial de traspasos

Nike Air Max 42      3 uds  →  Local Centro   ✅ Recibida    Ayer
Jordan 1 Talla 40    1 ud   →  Local Sur       ⏳ Pendiente   Hace 3h
Hoodie Negro M       2 uds  ←  Local Centro   ✅ Recibida    Lunes
Gorra Negra          1 ud   →  Local Centro   ❌ Cancelada   Semana pasada
```

- Flecha `→` = enviado desde este local. Flecha `←` = recibido en este local.
- Dueño ve todos con filtro por local. Vendedor ve solo los de su local.
- Sin paginación en MVP — muestra los últimos 30 registros.

---

## Datos en memoria

Nuevo cache `_transDB = []` cargado en `cargarDatos()`:

```js
async function cargarTransferencias() {
  const { data, error } = await sb
    .from('transferencias')
    .select(`
      id, fecha_creacion, variante_id, local_origen_id, local_destino_id,
      cantidad, costo_unitario, estado, usuario_origen_id, usuario_destino_id, fecha_confirmacion,
      variantes ( talla_color, productos ( nombre ) ),
      locales_origen:locales!local_origen_id ( nombre ),
      locales_destino:locales!local_destino_id ( nombre )
    `)
    .order('fecha_creacion', { ascending: false })
    .limit(100);
  if (error) { console.error('Error cargando transferencias:', error); return; }
  _transDB = data || [];
}
```

---

## Archivos a modificar

- `index.html` únicamente:
  - CSS: `.badge-transito`, tarjetas de traspaso pendiente, historial
  - JS globals: `_transDB = []`
  - `cargarTransferencias()` + agregado al `Promise.all` de `cargarDatos()`
  - `renderInventario()`: mostrar etiqueta "en tránsito" si hay traspasos pendientes salientes
  - `#ap-transfer` HTML: reemplazar placeholder con formulario real
  - `scIniciarTransferencia()`: INSERT + UPDATE stock origen
  - `renderLocales()`: agregar sección "Por recibir" + "Historial de traspasos"
  - `confirmarTransferencia(id)`: UPDATE stock destino (o INSERT variante) + marcar recibida + reload skuDB
  - `cancelarTransferencia(id)`: restaurar stock origen + marcar cancelada
  - Nav badge: lógica para mostrar badge en ícono Locales

---

## Lo que NO incluye

- Notificaciones push cuando llega un traspaso (el usuario refresca la app)
- Traspasos parciales (se confirma la cantidad completa o se cancela)
- Historial de más de 100 registros en memoria (los datos siguen en Supabase)
- Reasignación de traspasos a otro local destino (cancelar y crear nuevo)

---

## Criterios de éxito

1. El vendedor escanea un artículo, lo manda al otro local en menos de 30 segundos
2. El local destino ve el badge y confirma con un toque
3. Los stocks de ambos locales están correctos después del flujo
4. El historial muestra quién mandó qué, cuándo y si fue recibido
5. Si hay un traspaso pendiente, el inventario lo muestra claramente
6. La operación diaria de ventas no se ve interrumpida en ningún momento
