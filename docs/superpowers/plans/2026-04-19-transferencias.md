# Transferencias entre Locales — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir mover stock entre locales desde el escáner, con confirmación de recepción y historial completo.

**Architecture:** Todo en `index.html`. Nueva tabla `transferencias` en Supabase. Nuevo cache `_transDB`. El escáner inicia el traspaso (stock baja en origen), la pantalla Locales muestra pendientes y permite confirmar (stock sube en destino, creando variante si no existe). El dashboard muestra alertas de pendientes.

**Tech Stack:** HTML/CSS/JS vanilla, Supabase JS SDK (`sb` global), tabla `transferencias` nueva en Supabase.

---

## Archivos a modificar

- **Modificar:** `index.html` (único archivo)
  - CSS (~línea 890): estilos `.badge-transito`, tarjetas de traspaso, historial
  - Globals (~línea 38): `let _transDB = []`
  - Nueva función `cargarTransferencias()` después de `cargarLocales()`
  - `cargarDatos()` (~línea 6445): agregar `cargarTransferencias()` al `Promise.all`
  - `#ap-transfer` HTML (~línea 1777): reemplazar placeholder con formulario real
  - `scAccion()` (~línea 6188): branch `transfer` para poblar formulario
  - Nueva función `scIniciarTransferencia()`
  - `renderInventario()` (~línea 3421): mostrar etiqueta en tránsito
  - `renderLocales()` (~línea 5164): sección "Por recibir" + historial
  - Nuevas funciones `confirmarTransferencia(id)`, `cancelarTransferencia(id)`
  - `renderDashboard()`: urgency item para traspasos pendientes entrantes

## Prerequisito: crear tabla en Supabase

Antes de ejecutar los tasks, crear la tabla en el SQL editor de Supabase:

```sql
CREATE TABLE transferencias (
  id                  serial primary key,
  fecha_creacion      timestamptz default now(),
  variante_id         integer references variantes(id),
  local_origen_id     integer references locales(id),
  local_destino_id    integer references locales(id),
  cantidad            integer not null,
  costo_unitario      numeric not null,
  estado              text default 'pendiente',
  usuario_origen_id   integer references usuarios(id),
  usuario_destino_id  integer references usuarios(id),
  fecha_confirmacion  timestamptz
);
```

---

## Task 1: CSS + globals + `cargarTransferencias()`

**Files:**
- Modify: `index.html` — bloque CSS, sección globals, función de carga

- [ ] **Step 1: Agregar `_transDB` a los globals**

Localizar:
```js
let _localesDB    = [];    // [{ id, nombre, direccion, activo, color }]
```

Agregar inmediatamente después:
```js
let _transDB      = [];    // transferencias pendientes y recientes
```

- [ ] **Step 2: Agregar CSS para componentes de transferencias**

Buscar `/* ─── MULTI-LOCAL ─── */` en el CSS y agregar ANTES:

```css
/* ─── TRANSFERENCIAS ─── */
.badge-transito{display:inline-flex;align-items:center;gap:3px;font-size:10px;font-weight:700;color:var(--blue);background:rgba(37,99,235,.08);border:1px solid rgba(37,99,235,.15);border-radius:20px;padding:2px 7px;margin-left:6px;}
.trans-pending-card{background:var(--sf);border:1px solid var(--bd);border-radius:12px;padding:13px 14px;margin-bottom:8px;}
.trans-pending-top{display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:6px;}
.trans-pending-nombre{font-size:13px;font-weight:600;}
.trans-pending-meta{font-size:11px;color:var(--muted);margin-top:2px;}
.trans-pending-actions{display:flex;gap:8px;margin-top:10px;}
.trans-hist-item{display:flex;align-items:center;gap:10px;padding:10px 0;border-bottom:1px solid var(--sf3);}
.trans-hist-item:last-child{border-bottom:none;}
.trans-hist-icon{font-size:14px;flex-shrink:0;}
.trans-hist-info{flex:1;}
.trans-hist-nombre{font-size:12px;font-weight:600;}
.trans-hist-meta{font-size:10px;color:var(--muted);}
.trans-hist-badge{font-size:10px;font-weight:700;padding:2px 8px;border-radius:20px;flex-shrink:0;}
.trans-hist-badge.ok{background:var(--gdim);color:var(--green-fg);}
.trans-hist-badge.pending{background:rgba(37,99,235,.08);color:var(--blue);}
.trans-hist-badge.cancelled{background:var(--sf2);color:var(--muted);}
```

- [ ] **Step 3: Agregar función `cargarTransferencias()` después de `cargarLocales()`**

Localizar el cierre de `cargarLocales()` y agregar inmediatamente después:

```js
async function cargarTransferencias() {
  const { data, error } = await sb
    .from('transferencias')
    .select(`
      id, fecha_creacion, variante_id, local_origen_id, local_destino_id,
      cantidad, costo_unitario, estado, usuario_origen_id, usuario_destino_id, fecha_confirmacion,
      variantes ( talla_color, productos ( nombre ) ),
      local_origen:locales!local_origen_id ( nombre ),
      local_destino:locales!local_destino_id ( nombre )
    `)
    .order('fecha_creacion', { ascending: false })
    .limit(100);
  if (error) { console.error('Error cargando transferencias:', error); return; }
  _transDB = data || [];
}
```

- [ ] **Step 4: Agregar `cargarTransferencias()` al `Promise.all` en `cargarDatos()`**

Localizar:
```js
    await Promise.all([
      cargarInventario(),
      cargarVentas(),
      cargarClientes(),
      cargarGastos(),
      cargarLocales(),
    ]);
```

Reemplazar con:
```js
    await Promise.all([
      cargarInventario(),
      cargarVentas(),
      cargarClientes(),
      cargarGastos(),
      cargarLocales(),
      cargarTransferencias(),
    ]);
```

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: globals _transDB, CSS transferencias, cargarTransferencias()"
```

---

## Task 2: HTML `#ap-transfer` — formulario real

**Files:**
- Modify: `index.html` — panel HTML del escáner

- [ ] **Step 1: Reemplazar el contenido del panel `#ap-transfer`**

Localizar el contenido completo de `#ap-transfer`:
```html
  <div class="action-panel" id="ap-transfer">
    <div class="action-panel-title">🔄 Transferir entre locales</div>
    <div style="background:var(--sf2);border:1px solid var(--bd);border-radius:10px;padding:14px;text-align:center;margin-bottom:12px;">
      <div style="font-size:24px;margin-bottom:8px;">🏪</div>
      <div style="font-size:13px;font-weight:600;margin-bottom:4px;">Solo tienes un local activo</div>
      <div style="font-size:11px;color:var(--muted);line-height:1.5;">Para transferir entre locales necesitas tener más de uno configurado. La gestión multi-local estará disponible próximamente.</div>
    </div>
    <button class="btn sec" onclick="scCerrarPanel()" style="margin-top:4px;">Cerrar</button>
  </div>
```

Reemplazar con:
```html
  <div class="action-panel" id="ap-transfer">
    <div class="action-panel-title">🔄 Transferir entre locales</div>
    <div id="ap-transfer-body">
      <!-- Producto info -->
      <div style="background:var(--sf2);border:1px solid var(--bd);border-radius:10px;padding:11px 13px;margin-bottom:12px;">
        <div style="font-size:12px;font-weight:600;" id="tr-prod-nombre">—</div>
        <div style="font-size:11px;color:var(--muted);margin-top:2px;" id="tr-prod-stock">—</div>
      </div>
      <!-- Selector destino -->
      <div class="field" style="margin-bottom:10px;">
        <label>Local destino</label>
        <select id="tr-destino-select" style="width:100%;"></select>
      </div>
      <!-- Cantidad -->
      <div class="field" style="margin-bottom:14px;">
        <label>Cantidad a transferir</label>
        <input id="tr-cantidad" type="number" inputmode="numeric" min="1" value="1" style="width:100%;">
      </div>
      <button class="btn" id="tr-enviar-btn" onclick="scIniciarTransferencia()">Enviar →</button>
    </div>
    <!-- Estado: sin locales destino disponibles -->
    <div id="ap-transfer-nolocal" style="display:none;text-align:center;padding:16px;">
      <div style="font-size:11px;color:var(--muted);">No hay otros locales activos para transferir.</div>
    </div>
    <button class="btn sec" onclick="scCerrarPanel()" style="margin-top:8px;">Cancelar</button>
  </div>
```

- [ ] **Step 2: Commit**

```bash
git add index.html
git commit -m "feat: HTML panel #ap-transfer con formulario real de traspaso"
```

---

## Task 3: `scAccion('transfer')` + `scIniciarTransferencia()`

**Files:**
- Modify: `index.html` — función `scAccion()` y nueva función de traspaso

- [ ] **Step 1: Agregar branch `transfer` en `scAccion()`**

Localizar en `scAccion()`:
```js
  if(tipo === 'precio') {
```

Agregar ANTES de ese bloque:
```js
  if (tipo === 'transfer') {
    const activos = _localesDB.filter(l => l.activo !== false);
    const origenId = _scItem.local_id;
    const destinos = activos.filter(l => l.id !== origenId);
    const body     = document.getElementById('ap-transfer-body');
    const noLocal  = document.getElementById('ap-transfer-nolocal');

    if (destinos.length === 0) {
      if (body)    body.style.display    = 'none';
      if (noLocal) noLocal.style.display = '';
    } else {
      if (body)    body.style.display    = '';
      if (noLocal) noLocal.style.display = 'none';

      // Info del producto
      const pendSal = _transDB.filter(t => t.variante_id === _scItem.id && t.estado === 'pendiente').reduce((s,t)=>s+t.cantidad, 0);
      const stockEl = document.getElementById('tr-prod-stock');
      document.getElementById('tr-prod-nombre').textContent = `${_scItem.nombre} · ${_scItem.variante}`;
      stockEl.textContent = `Stock: ${_scItem.stock} ud.${pendSal > 0 ? ` · ↗ ${pendSal} en tránsito` : ''}`;
      stockEl.style.color = pendSal > 0 ? 'var(--blue)' : 'var(--muted)';

      // Poblar selector de destinos
      const sel = document.getElementById('tr-destino-select');
      sel.innerHTML = destinos.map(l => `<option value="${l.id}">${esc(l.nombre)}</option>`).join('');

      // Resetear cantidad
      const cantEl = document.getElementById('tr-cantidad');
      if (cantEl) cantEl.value = 1;

      // Bloquear botón si stock 0
      const btn = document.getElementById('tr-enviar-btn');
      if (btn) {
        const disponible = _scItem.stock - pendSal;
        btn.disabled = disponible <= 0;
        btn.textContent = disponible <= 0 ? 'Sin stock disponible' : 'Enviar →';
      }
    }
  }

```

- [ ] **Step 2: Agregar función `scIniciarTransferencia()` después de `scAccion()`**

Localizar después del cierre de `scAccion()` (buscar `function scSelCanal`) y agregar ANTES:

```js
async function scIniciarTransferencia() {
  if (!_scItem) return;
  const destId  = parseInt(document.getElementById('tr-destino-select')?.value, 10);
  const cantidad = parseInt(document.getElementById('tr-cantidad')?.value, 10);
  if (!destId || isNaN(cantidad) || cantidad < 1) { toast('Completa todos los campos.', 'err'); return; }
  if (cantidad > _scItem.stock) { toast(`Stock insuficiente — solo hay ${_scItem.stock} ud.`, 'err'); return; }

  const btn = document.getElementById('tr-enviar-btn');
  if (btn) { btn.disabled = true; btn.textContent = '⏳ Enviando…'; }

  // 1. INSERT transferencia
  const { data: trans, error: errTrans } = await sb.from('transferencias').insert({
    variante_id:       _scItem.id,
    local_origen_id:   _scItem.local_id,
    local_destino_id:  destId,
    cantidad,
    costo_unitario:    _scItem.costo || 0,
    estado:            'pendiente',
    usuario_origen_id: _currentUser?.id,
  }).select(`
    id, fecha_creacion, variante_id, local_origen_id, local_destino_id,
    cantidad, costo_unitario, estado, usuario_origen_id, usuario_destino_id, fecha_confirmacion,
    variantes ( talla_color, productos ( nombre ) ),
    local_origen:locales!local_origen_id ( nombre ),
    local_destino:locales!local_destino_id ( nombre )
  `).single();

  if (errTrans) {
    toast('Error al crear el traspaso.', 'err');
    console.error(errTrans);
    if (btn) { btn.disabled = false; btn.textContent = 'Enviar →'; }
    return;
  }

  // 2. Decrementar stock en origen
  const nuevoStock = _scItem.stock - cantidad;
  const { error: errStock } = await sb.from('variantes').update({ stock_actual: nuevoStock }).eq('id', _scItem.id);
  if (errStock) { console.error('Error actualizando stock origen:', errStock); }

  // 3. Actualizar caches
  _transDB.unshift(trans);
  const skuItem = skuDB.find(s => s.id === _scItem.id);
  if (skuItem) skuItem.stock = nuevoStock;
  _scItem = { ..._scItem, stock: nuevoStock };

  // 4. Feedback y cerrar
  const destNom = _localesDB.find(l => l.id === destId)?.nombre || 'el otro local';
  toast(`Traspaso enviado a ${destNom}. Esperando confirmación.`, 'ok');
  scCerrarPanel();

  renderInventario();
  renderDashboard();
}

```

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: scAccion transfer pobla formulario, scIniciarTransferencia() crea el traspaso"
```

---

## Task 4: `renderInventario()` — etiqueta en tránsito

**Files:**
- Modify: `index.html` — función `renderInventario()`

- [ ] **Step 1: Agregar etiqueta "en tránsito" en las tarjetas del inventario**

Localizar en `renderInventario()`:
```js
    const stockColor  = totalStock === 0 ? 'var(--red)' : totalStock <= 3 ? 'var(--orange)' : 'var(--green)';
    const stockLabel  = totalStock === 0 ? 'Agotado' : `${totalStock} ud.`;
```

Reemplazar con:
```js
    const stockColor  = totalStock === 0 ? 'var(--red)' : totalStock <= 3 ? 'var(--orange)' : 'var(--green)';
    const stockLabel  = totalStock === 0 ? 'Agotado' : `${totalStock} ud.`;
    const varIds = g.variantes.map(v => v.id);
    const enTransito = _transDB
      .filter(t => varIds.includes(t.variante_id) && t.estado === 'pendiente')
      .reduce((s, t) => s + t.cantidad, 0);
    const transitoBadge = enTransito > 0
      ? `<span class="badge-transito">↗ ${enTransito} en tránsito</span>`
      : '';
```

Luego localizar:
```js
          <div style="font-family:'DM Mono',monospace;font-size:11px;font-weight:700;color:${stockColor};margin-top:3px;">${stockLabel}</div>
```

Reemplazar con:
```js
          <div style="font-family:'DM Mono',monospace;font-size:11px;font-weight:700;color:${stockColor};margin-top:3px;">${stockLabel}${transitoBadge}</div>
```

- [ ] **Step 2: Commit**

```bash
git add index.html
git commit -m "feat: inventario muestra badge 'en tránsito' cuando hay traspasos pendientes salientes"
```

---

## Task 5: `renderLocales()` — sección "Por recibir" + historial

**Files:**
- Modify: `index.html` — función `renderLocales()`

- [ ] **Step 1: Agregar helper `fmtTimeAgo()` antes de `renderLocales()`**

Localizar la línea:
```js
function renderLocales() {
```

Agregar ANTES:
```js
function fmtTimeAgo(isoStr) {
  const diff = Date.now() - new Date(isoStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 60)  return `Hace ${mins || 1} min`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24)   return `Hace ${hrs}h`;
  const days = Math.floor(hrs / 24);
  return `Hace ${days}d`;
}

```

- [ ] **Step 2: Agregar sección "Por recibir" al inicio de `renderLocales()`**

Localizar al comienzo de `renderLocales()` (justo después de `let html = '';`):
```js
  let html = '';

  // ── Sección gestión de locales (solo Dueño) ──────────────
```

Reemplazar con:
```js
  let html = '';

  // ── Sección "Por recibir" — traspasos pendientes entrantes ──
  const miLocalId = _currentUser?.rol === 'Dueño' ? null : _currentUser?.local_id;
  const pendEntrantes = _transDB.filter(t =>
    t.estado === 'pendiente' &&
    (miLocalId === null ? true : t.local_destino_id === miLocalId)
  );
  if (pendEntrantes.length > 0) {
    html += `<div style="font-family:'Barlow',sans-serif;font-weight:700;font-size:14px;margin-bottom:10px;">
      Por recibir <span style="font-size:12px;font-weight:400;color:var(--blue);margin-left:4px;">${pendEntrantes.length}</span>
    </div>`;
    pendEntrantes.forEach(t => {
      const nomProd = t.variantes?.productos?.nombre || '—';
      const varNom  = t.variantes?.talla_color || '';
      const origen  = t.local_origen?.nombre || '—';
      const destino = t.local_destino?.nombre || '—';
      const esMio   = t.usuario_origen_id === _currentUser?.id || _currentUser?.rol === 'Dueño';
      html += `<div class="trans-pending-card">
        <div class="trans-pending-top">
          <div>
            <div class="trans-pending-nombre">${esc(nomProd)}${varNom ? ` · ${esc(varNom)}` : ''}</div>
            <div class="trans-pending-meta">${t.cantidad} ud. · desde ${esc(origen)} → ${esc(destino)}</div>
            <div class="trans-pending-meta" style="margin-top:2px;">${fmtTimeAgo(t.fecha_creacion)}</div>
          </div>
        </div>
        <div class="trans-pending-actions">
          <button class="btn" style="flex:1;padding:9px;font-size:12px;" onclick="confirmarTransferencia(${t.id})">✅ Confirmar recepción</button>
          ${esMio ? `<button class="btn sec" style="padding:9px 12px;font-size:12px;" onclick="cancelarTransferencia(${t.id})">Cancelar</button>` : ''}
        </div>
      </div>`;
    });
    html += '<div class="divider"></div>';
  }

  // ── Sección gestión de locales (solo Dueño) ──────────────
```

- [ ] **Step 3: Agregar sección "Historial de traspasos" al final de `renderLocales()`**

Localizar la línea final de `renderLocales()`:
```js
  bodyEl.innerHTML = html;
}
```

Reemplazar con:
```js
  // ── Historial de traspasos ──
  const historial = _transDB.filter(t => t.estado !== 'pendiente' || pendEntrantes.some(p => p.id === t.id));
  const histAll   = _transDB.slice(0, 30);
  if (histAll.length > 0) {
    html += `<div style="font-family:'Barlow',sans-serif;font-weight:700;font-size:14px;margin:16px 0 10px;">Historial de traspasos</div>`;
    histAll.forEach(t => {
      const nomProd  = t.variantes?.productos?.nombre || '—';
      const esEnvio  = t.local_origen_id === (miLocalId ?? t.local_origen_id);
      const otroNom  = esEnvio ? (t.local_destino?.nombre || '—') : (t.local_origen?.nombre || '—');
      const flecha   = esEnvio ? '→' : '←';
      const badgeCls = t.estado === 'recibida' ? 'ok' : t.estado === 'pendiente' ? 'pending' : 'cancelled';
      const badgeTxt = t.estado === 'recibida' ? '✅ Recibida' : t.estado === 'pendiente' ? '⏳ Pendiente' : '❌ Cancelada';
      html += `<div class="trans-hist-item">
        <div class="trans-hist-icon">${esEnvio ? '📤' : '📥'}</div>
        <div class="trans-hist-info">
          <div class="trans-hist-nombre">${esc(nomProd)} · ${t.cantidad} ud. ${flecha} ${esc(otroNom)}</div>
          <div class="trans-hist-meta">${fmtTimeAgo(t.fecha_creacion)}</div>
        </div>
        <span class="trans-hist-badge ${badgeCls}">${badgeTxt}</span>
      </div>`;
    });
  }

  bodyEl.innerHTML = html;
}
```

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: renderLocales() muestra traspasos pendientes y historial"
```

---

## Task 6: `confirmarTransferencia()` + `cancelarTransferencia()`

**Files:**
- Modify: `index.html` — nuevas funciones después de las CRUD de locales

- [ ] **Step 1: Agregar las dos funciones después del bloque de CRUD de locales**

Localizar `async function eliminarLocalConfirm()` y agregar después de su cierre `}`:

```js
// ── TRANSFERENCIAS ─────────────────────────────────────────
async function confirmarTransferencia(id) {
  const t = _transDB.find(x => x.id === id);
  if (!t || t.estado !== 'pendiente') return;

  const btn = document.querySelector(`[onclick="confirmarTransferencia(${id})"]`);
  if (btn) { btn.disabled = true; btn.textContent = '⏳ Confirmando…'; }

  // Buscar variante de origen en skuDB para obtener producto_id y talla_color
  const origSku = skuDB.find(s => s.id === t.variante_id);
  if (!origSku) {
    // Si no está en cache, obtener desde Supabase
    const { data: v } = await sb.from('variantes').select('producto_id, talla_color').eq('id', t.variante_id).single();
    if (!v) { toast('Error al confirmar: variante de origen no encontrada.', 'err'); if(btn){btn.disabled=false;btn.textContent='✅ Confirmar recepción';} return; }
    origSku.producto_id = v.producto_id;
    origSku.variante    = v.talla_color;
  }

  // Buscar variante en destino (mismo producto_id + talla_color + local_id = destino)
  let destVarianteId = null;
  const destSku = skuDB.find(s =>
    s.producto_id === origSku.producto_id &&
    s.variante    === origSku.variante &&
    s.local_id    === t.local_destino_id
  );

  if (destSku) {
    // Variante existe: incrementar stock
    const nuevoStock = destSku.stock + t.cantidad;
    const { error: errUpd } = await sb.from('variantes').update({ stock_actual: nuevoStock }).eq('id', destSku.id);
    if (errUpd) { toast('Error al actualizar stock destino.', 'err'); console.error(errUpd); if(btn){btn.disabled=false;btn.textContent='✅ Confirmar recepción';} return; }
    destSku.stock    = nuevoStock;
    destVarianteId   = destSku.id;
  } else {
    // Variante no existe en destino: crearla
    const { data: nueva, error: errIns } = await sb.from('variantes').insert({
      producto_id:          origSku.producto_id,
      talla_color:          origSku.variante,
      local_id:             t.local_destino_id,
      stock_actual:         t.cantidad,
      stock_minimo:         0,
      costo_ultima_compra:  t.costo_unitario,
      activa:               true,
    }).select('id').single();
    if (errIns) { toast('Error al crear variante en destino.', 'err'); console.error(errIns); if(btn){btn.disabled=false;btn.textContent='✅ Confirmar recepción';} return; }
    destVarianteId = nueva.id;
    // Recargar skuDB para incluir la nueva variante
    await cargarInventario();
  }

  // Marcar transferencia como recibida
  const { error: errTrans } = await sb.from('transferencias').update({
    estado:               'recibida',
    usuario_destino_id:   _currentUser?.id,
    fecha_confirmacion:   new Date().toISOString(),
  }).eq('id', id);
  if (errTrans) { console.error('Error actualizando transferencia:', errTrans); }

  // Actualizar cache _transDB
  const idx = _transDB.findIndex(x => x.id === id);
  if (idx >= 0) {
    _transDB[idx].estado             = 'recibida';
    _transDB[idx].usuario_destino_id = _currentUser?.id;
    _transDB[idx].fecha_confirmacion = new Date().toISOString();
  }

  toast('Recepción confirmada. Stock actualizado.', 'ok');
  renderLocales();
  renderInventario();
  renderDashboard();
}

async function cancelarTransferencia(id) {
  const t = _transDB.find(x => x.id === id);
  if (!t || t.estado !== 'pendiente') return;
  if (!confirm('¿Cancelar este traspaso? El stock volverá al local de origen.')) return;

  // Restaurar stock en origen
  const origSku = skuDB.find(s => s.id === t.variante_id);
  if (origSku) {
    const stockRestaurado = origSku.stock + t.cantidad;
    const { error: errStock } = await sb.from('variantes').update({ stock_actual: stockRestaurado }).eq('id', t.variante_id);
    if (errStock) { toast('Error al restaurar stock.', 'err'); return; }
    origSku.stock = stockRestaurado;
  }

  // Marcar como cancelada
  const { error: errTrans } = await sb.from('transferencias').update({ estado: 'cancelada' }).eq('id', id);
  if (errTrans) { toast('Error al cancelar el traspaso.', 'err'); console.error(errTrans); return; }

  const idx = _transDB.findIndex(x => x.id === id);
  if (idx >= 0) _transDB[idx].estado = 'cancelada';

  toast('Traspaso cancelado. Stock restaurado.', 'ok');
  renderLocales();
  renderInventario();
  renderDashboard();
}
```

- [ ] **Step 2: Commit**

```bash
git add index.html
git commit -m "feat: confirmarTransferencia() y cancelarTransferencia() con actualización de stock"
```

---

## Task 7: Dashboard — urgency item para traspasos pendientes

**Files:**
- Modify: `index.html` — función `renderDashboard()`

- [ ] **Step 1: Agregar traspasos pendientes entrantes a los urgency items**

En `renderDashboard()`, localizar donde se construye el array de urgencias. Buscar la línea que contiene:
```js
  const urgItems = [];
```

Y localizar dónde se hace `push` de ítems de urgencia. Buscar este patrón típico:
```js
  if (stockCritico.length)
    urgItems.push(`...`);
```

Agregar UN bloque adicional junto a los otros urgency items (no importa el orden exacto dentro del grupo):

```js
  // Traspasos pendientes entrantes
  const miLocalIdDash = _currentUser?.rol === 'Dueño' ? null : _currentUser?.local_id;
  const transEntrantes = _transDB.filter(t =>
    t.estado === 'pendiente' &&
    (miLocalIdDash === null ? true : t.local_destino_id === miLocalIdDash)
  );
  if (transEntrantes.length > 0) {
    urgItems.push(`<div class="urgency-item" onclick="goTo('locales')" style="cursor:pointer;">
      <span style="font-size:15px;">🔄</span>
      <div class="ui-text">
        <b>${transEntrantes.length} traspaso${transEntrantes.length !== 1 ? 's' : ''} pendiente${transEntrantes.length !== 1 ? 's' : ''} de confirmar</b>
        <span class="ui-sub">Toca para ver y confirmar</span>
      </div>
    </div>`);
  }
```

- [ ] **Step 2: Verificar que `urgency-item` y `ui-text`/`ui-sub` ya existen en el CSS**

Buscar en el CSS:
```bash
grep -n "urgency-item\|\.ui-text\|\.ui-sub" index.html | head -5
```

Si los estilos existen: continuar. Si no existen: agregar al bloque CSS (junto a los otros estilos de urgencia):
```css
.urgency-item{display:flex;align-items:flex-start;gap:10px;padding:10px 0;border-bottom:1px solid var(--sf3);}
.urgency-item:last-child{border-bottom:none;}
.ui-text{display:flex;flex-direction:column;gap:2px;font-size:12px;}
.ui-sub{color:var(--muted);font-size:11px;}
```

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: dashboard muestra urgency item cuando hay traspasos pendientes de confirmar"
```

---

## Task 8: Push y verificación final

- [ ] **Step 1: Push a producción**

```bash
git push origin main
```

- [ ] **Step 2: Verificar en cuanti-two.vercel.app**

Checklist:
- [ ] Escáner: escanear producto → acción "Transferir" → panel muestra producto + stock + selector de destinos
- [ ] Si stock = 0 → botón "Sin stock disponible" deshabilitado
- [ ] Enviar traspaso → toast "Enviado a [Local]", stock baja en inventario, badge "↗ X en tránsito" visible
- [ ] Dashboard → urgency item "X traspasos pendientes" aparece, toque → navega a Locales
- [ ] Locales → sección "Por recibir" muestra el traspaso pendiente con botón "Confirmar recepción"
- [ ] Confirmar → stock sube en destino, historial muestra "✅ Recibida"
- [ ] Si producto no existía en destino → se crea automáticamente, aparece en inventario del destino
- [ ] Cancelar → stock vuelve al origen, historial muestra "❌ Cancelada"
- [ ] Inventario → ya no muestra "en tránsito" después de confirmar o cancelar
- [ ] Historial → muestra todos los traspasos con estado correcto (→ enviados, ← recibidos)

---

## Self-Review

**Cobertura del spec:**
- ✅ Nueva tabla `transferencias` — Prerequisito (SQL)
- ✅ Stock baja al iniciar → Task 3 (`scIniciarTransferencia`)
- ✅ Stock sube al confirmar → Task 6 (`confirmarTransferencia`)
- ✅ Stock restaura al cancelar → Task 6 (`cancelarTransferencia`)
- ✅ Variante auto-creada en destino → Task 6
- ✅ `#ap-transfer` formulario real → Task 2
- ✅ Panel se puebla con `_scItem` → Task 3
- ✅ Badge "en tránsito" en inventario → Task 4
- ✅ Sección "Por recibir" en Locales → Task 5
- ✅ Historial en Locales → Task 5
- ✅ Dashboard urgency item → Task 7
- ✅ Vendedor solo ve su local → Tasks 5 y 7 usan `miLocalId`
- ✅ Dueño ve todos → `miLocalId === null` sin filtro
- ✅ Solo origen/Dueño puede cancelar → Task 5 (condición `esMio`)

**Consistencia de nombres:**
- `confirmarTransferencia(id)` — definida Task 6, llamada Task 5 (botón HTML)
- `cancelarTransferencia(id)` — definida Task 6, llamada Task 5 (botón HTML)
- `scIniciarTransferencia()` — definida Task 3, llamada Task 2 (HTML botón `tr-enviar-btn`)
- `fmtTimeAgo(isoStr)` — definida Task 5 (antes de `renderLocales`), usada Task 5
- `_transDB` — definida Task 1, usada Tasks 3, 4, 5, 6, 7
- `esc()` — ya existe en el archivo desde multi-local
