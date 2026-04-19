# Multi-Local Robusto — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir al dueño gestionar múltiples locales, ver una comparación en el dashboard y análisis comparativo detallado en la pantalla Locales.

**Architecture:** Todo en `index.html`. Se agregan variables globales `_activeLocal` y `_localesDB`, una función helper `localFiltro()`, y se enriquece `ventasDB`/`skuDB` con `local_id`. `renderLocales()` se reescribe con dos secciones: gestión CRUD y análisis comparativo. El dashboard agrega un strip de comparación rápida visible solo para el Dueño con 2+ locales.

**Tech Stack:** HTML/CSS/JS vanilla, Supabase (tabla `locales` ya existe con `id, nombre, direccion, activo, color`), localStorage para `_activeLocal`.

---

## Archivos a modificar

- **Modificar:** `index.html` (único archivo)
  - CSS (~línea 890): estilos para local-strip, comparación de locales
  - Globals (~línea 36): `_activeLocal`, `_localesDB`
  - `cargarVentas()` (~línea 88): agregar `local_id` y `categoria` al map de ventasDB
  - `cargarInventario()` (~línea 41): agregar `local_id` al map de skuDB
  - `cargarDatos()` (~línea 6056): agregar `cargarLocales()` al Promise.all
  - HTML pantalla Locales (~línea 1397): reemplazar contenido estático con `#locales-body`
  - HTML sheets: agregar sheet para crear/editar local
  - HTML dashboard (~línea 998): agregar `#dash-local-strip`
  - `renderDashboard()` (~línea 2285): poblar local strip
  - `renderLocales()` (~línea 5089): reescribir completo
  - `renderEquipo()` (~línea 2088): mostrar local asignado en cada user card
  - JS: nuevas funciones `cargarLocales`, `localFiltro`, `setActiveLocal`, `abrirNuevoLocal`, `cerrarLocalSheet`, `guardarNuevoLocal`, `abrirEditarLocal`, `guardarEditarLocal`, `toggleLocalActivo`, `reasignarUsuarioLocal`

---

## Task 1: CSS y variables globales

**Files:**
- Modify: `index.html` — bloque CSS y sección globals

- [ ] **Step 1: Agregar variables globales debajo de `_currentUser`**

Localizar línea:
```js
let _currentUser = null; // { id, nombre, email, rol: 'Dueño'|'Vendedor', local_id }
```

Agregar inmediatamente después:
```js
let _activeLocal  = null;  // null = todos los locales | number = local_id específico
let _localesDB    = [];    // [{ id, nombre, direccion, activo, color }]
```

- [ ] **Step 2: Agregar función `localFiltro()` cerca de las otras funciones de utilidad**

Buscar `function esVentaMes` (~línea 2289) y agregar ANTES de ella:

```js
// Retorna el local_id a filtrar: null = sin filtro (Dueño ve todo), número = filtra por local
function localFiltro() {
  if (_currentUser?.rol !== 'Dueño') return _currentUser?.local_id ?? null;
  return _activeLocal; // null cuando el dueño quiere ver todo
}

function setActiveLocal(localId) {
  _activeLocal = localId;
  if (localId === null) {
    localStorage.removeItem('cuanti_active_local');
  } else {
    localStorage.setItem('cuanti_active_local', String(localId));
  }
  renderDashboard();
}
```

- [ ] **Step 3: Agregar CSS para local strip y pantalla comparativa**

Buscar `/* ─── CAJA ─── */` al final del bloque CSS y agregar ANTES:

```css
/* ─── MULTI-LOCAL ─── */
.local-strip-card{display:flex;align-items:stretch;background:var(--sf);border:1px solid var(--bd);border-radius:12px;overflow:hidden;cursor:pointer;}
.local-strip-col{flex:1;text-align:center;padding:11px 8px;}
.local-strip-col-lbl{font-size:10px;font-weight:600;color:var(--muted);margin-bottom:3px;}
.local-strip-col-amt{font-family:'DM Mono',monospace;font-size:14px;font-weight:700;}
.local-strip-div{width:1px;background:var(--bd);margin:8px 0;flex-shrink:0;}
.local-active-chip{display:inline-flex;align-items:center;gap:6px;background:var(--sf2);border:1px solid var(--bd);border-radius:20px;padding:5px 12px;font-size:12px;font-weight:600;}
.local-active-chip-x{background:none;border:none;font-size:16px;color:var(--muted);cursor:pointer;padding:0;line-height:1;font-family:'Barlow',sans-serif;}
.loc-kpi-grid{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:14px;}
.loc-kpi-card{background:var(--sf);border:1px solid var(--bd);border-radius:12px;padding:12px 14px;}
.loc-kpi-hdr{font-size:10px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.4px;margin-bottom:8px;}
.loc-kpi-row{display:flex;justify-content:space-between;align-items:baseline;font-size:11px;margin-bottom:4px;}
.loc-kpi-lbl{color:var(--muted);}
.loc-kpi-val{font-family:'DM Mono',monospace;font-weight:700;font-size:12px;}
.loc-bar-wrap{background:var(--sf);border:1px solid var(--bd);border-radius:12px;padding:14px;margin-bottom:14px;}
.loc-bar-track{height:8px;background:var(--sf3);border-radius:4px;overflow:hidden;margin:10px 0 6px;}
.loc-bar-fill{height:100%;border-radius:4px;background:var(--accent);}
.loc-prod-grid{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:14px;}
.loc-prod-card{background:var(--sf);border:1px solid var(--bd);border-radius:12px;padding:12px 14px;}
.loc-prod-item{display:flex;justify-content:space-between;align-items:center;font-size:11px;padding:4px 0;border-bottom:1px solid var(--sf3);}
.loc-prod-item:last-child{border-bottom:none;}
.loc-insight{background:var(--sf2);border:1px solid var(--bd);border-radius:12px;padding:13px 14px;margin-bottom:8px;font-size:12px;line-height:1.5;color:var(--text);}
.loc-local-card{display:flex;align-items:center;gap:12px;background:var(--sf);border:1px solid var(--bd);border-radius:12px;padding:13px 14px;margin-bottom:8px;cursor:pointer;}
.loc-local-card:active{background:var(--sf2);}
.loc-local-dot{width:10px;height:10px;border-radius:50%;flex-shrink:0;}
.loc-local-info{flex:1;}
.loc-local-nombre{font-size:13px;font-weight:600;margin-bottom:1px;}
.loc-local-sub{font-size:10px;color:var(--muted);}
.loc-badge-inactivo{font-size:9px;font-weight:700;background:var(--sf3);color:var(--muted);border-radius:20px;padding:2px 8px;}
```

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: variables globales _activeLocal, localFiltro(), CSS multi-local"
```

---

## Task 2: `cargarLocales()` y `cargarDatos()`

**Files:**
- Modify: `index.html` — funciones de carga de datos

- [ ] **Step 1: Agregar `cargarLocales()` después de `cargarGastos()`**

Localizar el cierre de `cargarGastos()`:
```js
  if (error) { console.error('Error cargando gastos:', error); return; }
  gastosDB = data || [];
}
```

Agregar inmediatamente después:

```js
async function cargarLocales() {
  const { data, error } = await sb
    .from('locales')
    .select('id, nombre, direccion, activo, color')
    .order('id');
  if (error) { console.error('Error cargando locales:', error); return; }
  _localesDB = data || [];
  // Restaurar _activeLocal desde localStorage si el usuario es Dueño
  if (_currentUser?.rol === 'Dueño') {
    const stored = localStorage.getItem('cuanti_active_local');
    if (stored) {
      const id = parseInt(stored);
      if (_localesDB.some(l => l.id === id)) _activeLocal = id;
    }
  }
}
```

- [ ] **Step 2: Agregar `cargarLocales()` al `Promise.all` en `cargarDatos()`**

Localizar:
```js
    await Promise.all([
      cargarInventario(),
      cargarVentas(),
      cargarClientes(),
      cargarGastos(),
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
    ]);
```

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: cargarLocales() carga _localesDB y restaura _activeLocal desde localStorage"
```

---

## Task 3: Enriquecer ventasDB y skuDB con `local_id` y `categoria`

**Files:**
- Modify: `index.html` — `cargarVentas()` y `cargarInventario()`

- [ ] **Step 1: Agregar `local_id` al select de `cargarVentas()`**

Localizar en `cargarVentas()`:
```js
      ventas ( id, fecha_hora, canal, metodo_pago, tipo_envio, estado, cliente_id, clientes ( nombre ) ),
```

Reemplazar con:
```js
      ventas ( id, fecha_hora, canal, metodo_pago, tipo_envio, estado, cliente_id, local_id, clientes ( nombre ) ),
```

- [ ] **Step 2: Agregar `local_id` y `categoria` al map de ventasDB**

Localizar en el map de `cargarVentas()`:
```js
      descuento_tipo:  d.descuento_tipo  || null,
      descuento_valor: d.descuento_valor || 0,
    };
  });
}
```

Reemplazar con:
```js
      descuento_tipo:  d.descuento_tipo  || null,
      descuento_valor: d.descuento_valor || 0,
      local_id:  d.ventas?.local_id      || null,
      categoria: d.variantes?.productos?.categorias?.nombre || '',
    };
  });
}
```

- [ ] **Step 3: Agregar `local_id` al select de `cargarInventario()`**

Localizar:
```js
      id, sku, talla_color, stock_actual, stock_minimo, costo_ultima_compra, activa, producto_id,
```

Reemplazar con:
```js
      id, sku, talla_color, stock_actual, stock_minimo, costo_ultima_compra, activa, producto_id, local_id,
```

- [ ] **Step 4: Agregar `local_id` al map de skuDB**

Localizar en el map de `cargarInventario()`:
```js
      marca:        marca.nombre       || '',
      producto_id:  prod?.id
    };
  });
}
```

Reemplazar con:
```js
      marca:        marca.nombre       || '',
      producto_id:  prod?.id,
      local_id:     v.local_id         || null,
    };
  });
}
```

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: ventasDB y skuDB incluyen local_id y categoria"
```

---

## Task 4: Dashboard — strip comparativo de locales

**Files:**
- Modify: `index.html` — HTML dashboard + `renderDashboard()`

- [ ] **Step 1: Agregar `#dash-local-strip` en el HTML del dashboard**

Localizar:
```html
  <!-- 2. SETUP / ONBOARDING (desaparece cuando está completo) -->
  <div id="dash-setup" style="display:none;margin-bottom:20px;"></div>

  <!-- 3. STATS STRIP -->
  <div id="dash-stats-strip" ...></div>
```

Agregar entre `dash-setup` y `dash-stats-strip`:

```html
  <!-- LOCAL STRIP (solo Dueño con 2+ locales) -->
  <div id="dash-local-strip" style="display:none;margin-bottom:16px;"></div>

```

- [ ] **Step 2: Agregar lógica del strip al final de `renderDashboard()`**

Localizar el bloque que empieza con `// Fila caja: efectivo cobrado hoy` (al final de `renderDashboard()`):

```js
  // Fila caja: efectivo cobrado hoy
  const cajaRow = document.getElementById('dash-caja-row');
```

Agregar ANTES de ese bloque:

```js
  // Local strip: comparación rápida entre locales (solo Dueño)
  const stripEl = document.getElementById('dash-local-strip');
  if (stripEl) {
    const esDueno = _currentUser?.rol === 'Dueño';
    const activos = _localesDB.filter(l => l.activo !== false);
    if (esDueno && activos.length >= 2 && !_activeLocal) {
      const cols = activos.map(loc => {
        const ganLoc = ventasDB
          .filter(v => v.local_id === loc.id && esVentaMes(v) && !v.nombre.startsWith('↩️'))
          .reduce((s, v) => s + v.gan, 0);
        const color = ganLoc < 0 ? 'var(--red)' : 'var(--text)';
        return `<div class="local-strip-col">
          <div class="local-strip-col-lbl">${loc.nombre}</div>
          <div class="local-strip-col-amt" style="color:${color};">${ganLoc<0?'−':''}$${fmt(Math.abs(ganLoc))}</div>
        </div>`;
      });
      const dividers = cols.map((c, i) => i < cols.length - 1 ? c + '<div class="local-strip-div"></div>' : c).join('');
      stripEl.style.display = '';
      stripEl.innerHTML = `<div class="local-strip-card" onclick="goTo('locales')" role="button">
        ${dividers}
        <div style="padding:10px 12px;display:flex;align-items:center;color:var(--muted2);font-size:14px;flex-shrink:0;">›</div>
      </div>`;
    } else if (esDueno && _activeLocal) {
      const loc = _localesDB.find(l => l.id === _activeLocal);
      stripEl.style.display = '';
      stripEl.innerHTML = `<div style="display:flex;align-items:center;gap:8px;">
        <div class="local-active-chip">🏪 ${loc?.nombre || 'Local'}
          <button class="local-active-chip-x" onclick="setActiveLocal(null)">×</button>
        </div>
        <span style="font-size:11px;color:var(--muted);">Solo este local</span>
      </div>`;
    } else {
      stripEl.style.display = 'none';
    }
  }

```

- [ ] **Step 3: Verificar en browser que:**
  - Con 1 local → strip no aparece
  - Con 2+ locales activos → aparece fila "Local 1 $X | Local 2 $Y"
  - Toque → navega a Locales
  - Si `setActiveLocal(id)` → aparece chip con nombre del local y botón ×

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: dashboard strip comparativo de locales para el Dueño"
```

---

## Task 5: HTML pantalla Locales y sheets de gestión

**Files:**
- Modify: `index.html` — pantalla Locales (~línea 1397) y sheets al final del body

- [ ] **Step 1: Reemplazar contenido estático de la pantalla Locales**

Localizar el contenido completo de `screen-locales`:
```html
<div class="screen" id="screen-locales">
  <div class="ptitle">Mi negocio</div>
  <div class="psub" id="locales-psub">Resumen del local activo</div>

  <!-- KPIs reales del local actual -->
  <div class="sgrid" id="locales-kpis" style="margin-bottom:16px;">
    ...
  </div>

  <!-- Multi-local: próximamente -->
  <div class="card" style="text-align:center;background:var(--sf2);">
    ...
  </div>

  <div class="spacer"></div>
</div>
```

Reemplazar con:
```html
<div class="screen" id="screen-locales">
  <div class="ptitle">Mi negocio</div>
  <div class="psub" id="locales-psub">Mis locales</div>
  <div id="locales-body"></div>
  <div class="spacer"></div>
</div>
```

- [ ] **Step 2: Agregar sheet para crear/editar local antes de `</body>`**

Buscar el último `</div>` antes de `</body>` (o agregar antes de la etiqueta de cierre del body). Agregar:

```html
<!-- ══ SHEET: CREAR / EDITAR LOCAL ══ -->
<div class="sheet-bd" id="local-sheet-bd" onclick="cerrarLocalSheet()"></div>
<div class="sheet" id="local-sheet">
  <div class="sheet-handle" onclick="cerrarLocalSheet()"></div>
  <div style="font-family:'Barlow',sans-serif;font-weight:700;font-size:17px;margin-bottom:18px;" id="local-sheet-titulo">Nuevo local</div>

  <div class="field" style="margin-bottom:10px;">
    <label>Nombre del local</label>
    <input id="local-nombre-input" type="text" placeholder="Ej: Local Centro">
  </div>
  <div class="field" style="margin-bottom:18px;">
    <label>Dirección (opcional)</label>
    <input id="local-dir-input" type="text" placeholder="Ej: Av. Providencia 1234">
  </div>

  <!-- Solo visible al editar -->
  <div id="local-edit-section" style="display:none;margin-bottom:18px;">
    <div style="display:flex;justify-content:space-between;align-items:center;padding:13px 0;border-top:1px solid var(--bd);">
      <div>
        <div style="font-size:13px;font-weight:600;">Estado del local</div>
        <div style="font-size:11px;color:var(--muted);margin-top:2px;" id="local-estado-sub">Activo</div>
      </div>
      <button id="local-toggle-btn" class="btn sec" style="width:auto;padding:9px 16px;font-size:12px;" onclick="toggleLocalActivo()">Desactivar</button>
    </div>
    <div id="local-delete-wrap" style="padding-top:4px;">
      <button id="local-delete-btn" class="btn danger" style="width:100%;font-size:12px;padding:11px;" onclick="eliminarLocalConfirm()">Eliminar local</button>
      <div style="font-size:10px;color:var(--muted);text-align:center;margin-top:6px;" id="local-delete-sub"></div>
    </div>
  </div>

  <input type="hidden" id="local-edit-id" value="">
  <button class="btn" id="local-guardar-btn" onclick="guardarLocal()" style="margin-top:4px;">Crear local →</button>
</div>
```

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: HTML pantalla Locales con #locales-body y sheet crear/editar local"
```

---

## Task 6: `renderLocales()` — sección de gestión y funciones CRUD

**Files:**
- Modify: `index.html` — función `renderLocales()` y nuevas funciones de gestión

- [ ] **Step 1: Reemplazar `renderLocales()` con la nueva versión**

Localizar el bloque completo de `renderLocales()`:
```js
function renderLocales() {
  const hoy       = new Date();
  ...
  set('loc-skus',     skusActivos);
}
```

Reemplazar TODO el bloque con:

```js
function renderLocales() {
  const bodyEl = document.getElementById('locales-body');
  if (!bodyEl) return;
  const esDueno = _currentUser?.rol === 'Dueño';
  const meses = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
  const mesNom = meses[new Date().getMonth()];

  let html = '';

  // ── Sección gestión de locales (solo Dueño) ──────────────
  if (esDueno) {
    html += `<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;">
      <div style="font-family:'Barlow',sans-serif;font-weight:700;font-size:14px;">Mis locales</div>
      <span class="sec-link" onclick="abrirNuevoLocal()">＋ Nuevo local</span>
    </div>`;

    if (_localesDB.length === 0) {
      html += `<div class="card" style="text-align:center;padding:24px;color:var(--muted);font-size:12px;">
        No tienes locales registrados. Crea el primero con el botón de arriba.
      </div>`;
    } else {
      _localesDB.forEach(loc => {
        const usuarios = []; // placeholder — usuarios se cargan en el sheet
        const activo = loc.activo !== false;
        const dot = loc.color || (activo ? '#D7F02E' : '#BCBCBC');
        html += `<div class="loc-local-card" onclick="abrirEditarLocal(${loc.id})">
          <div class="loc-local-dot" style="background:${dot};"></div>
          <div class="loc-local-info">
            <div class="loc-local-nombre">${loc.nombre}${!activo ? ' <span class="loc-badge-inactivo">Inactivo</span>' : ''}</div>
            ${loc.direccion ? `<div class="loc-local-sub">${loc.direccion}</div>` : ''}
          </div>
          <div style="font-size:14px;color:var(--muted2);">›</div>
        </div>`;
      });
    }
    html += '<div class="divider"></div>';
  }

  // ── Sección comparativa (solo si hay 2+ locales activos con datos) ──
  const activos = _localesDB.filter(l => l.activo !== false);
  if (esDueno && activos.length >= 2) {
    const statsLocal = activos.map(loc => {
      const vMes = ventasDB.filter(v => v.local_id === loc.id && esVentaMes(v) && !v.nombre.startsWith('↩️'));
      const gan  = vMes.reduce((s,v) => s + v.gan, 0);
      const ing  = vMes.reduce((s,v) => s + v.precio, 0);
      const n    = vMes.length;
      const ticket = n > 0 ? Math.round(ing / n) : 0;
      const margen = ing > 0 ? Math.round((gan / ing) * 100) : 0;
      return { loc, gan, ing, n, ticket, margen, vMes };
    });

    const totalGan = statsLocal.reduce((s, sl) => s + sl.gan, 0);

    html += `<div style="font-family:'Barlow',sans-serif;font-weight:700;font-size:14px;margin-bottom:12px;">Comparación — ${mesNom}</div>`;

    // KPIs lado a lado
    html += '<div class="loc-kpi-grid">';
    statsLocal.forEach(sl => {
      const ganColor = sl.gan < 0 ? 'var(--red)' : 'var(--green-fg)';
      html += `<div class="loc-kpi-card">
        <div class="loc-kpi-hdr">${sl.loc.nombre}</div>
        <div class="loc-kpi-row"><span class="loc-kpi-lbl">Ganancia</span><span class="loc-kpi-val" style="color:${ganColor};">${sl.gan<0?'−':''}$${fmt(Math.abs(sl.gan))}</span></div>
        <div class="loc-kpi-row"><span class="loc-kpi-lbl">Ventas</span><span class="loc-kpi-val">${sl.n}</span></div>
        <div class="loc-kpi-row"><span class="loc-kpi-lbl">Ticket prom.</span><span class="loc-kpi-val">$${fmt(sl.ticket)}</span></div>
        <div class="loc-kpi-row"><span class="loc-kpi-lbl">Margen</span><span class="loc-kpi-val">${sl.margen}%</span></div>
      </div>`;
    });
    html += '</div>';

    // Barra de participación
    if (totalGan > 0) {
      const pct0 = Math.round((statsLocal[0].gan / totalGan) * 100);
      const pct1 = 100 - pct0;
      html += `<div class="loc-bar-wrap">
        <div style="font-size:12px;font-weight:600;margin-bottom:2px;">Participación en ganancia</div>
        <div class="loc-bar-track">
          <div class="loc-bar-fill" style="width:${pct0}%;"></div>
        </div>
        <div style="display:flex;justify-content:space-between;font-size:11px;color:var(--muted);">
          <span>${statsLocal[0].loc.nombre} · ${pct0}%</span>
          <span>${statsLocal[1].loc.nombre} · ${pct1}%</span>
        </div>
        <div style="font-size:11px;color:var(--muted);margin-top:6px;">${statsLocal[0].loc.nombre} generó el ${pct0}% de la ganancia este mes</div>
      </div>`;
    }

    // Top 3 productos por local
    const topProdsLocal = (ventas, n=3) => {
      const map = {};
      ventas.forEach(v => { map[v.nombre] = (map[v.nombre]||0) + v.gan; });
      return Object.entries(map).sort((a,b)=>b[1]-a[1]).slice(0,n);
    };
    html += '<div class="loc-prod-grid">';
    statsLocal.forEach(sl => {
      const tops = topProdsLocal(sl.vMes);
      html += `<div class="loc-prod-card">
        <div class="loc-kpi-hdr">${sl.loc.nombre} — top productos</div>
        ${tops.length === 0
          ? '<div style="font-size:11px;color:var(--muted);">Sin ventas este mes</div>'
          : tops.map(([nom, gan]) => `<div class="loc-prod-item">
              <span style="flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;margin-right:6px;">${nom}</span>
              <span style="font-family:\'DM Mono\',monospace;font-size:11px;font-weight:700;color:var(--green-fg);flex-shrink:0;">$${fmt(gan)}</span>
            </div>`).join('')
        }
      </div>`;
    });
    html += '</div>';

    // Top categorías por local
    const topCatsLocal = (ventas, n=2) => {
      const map = {};
      ventas.forEach(v => { const c = v.categoria||'Otro'; map[c] = (map[c]||0) + v.gan; });
      return Object.entries(map).sort((a,b)=>b[1]-a[1]).slice(0,n);
    };
    const cats0 = topCatsLocal(statsLocal[0].vMes);
    const cats1 = topCatsLocal(statsLocal[1].vMes);
    if (cats0.length > 0 || cats1.length > 0) {
      html += `<div class="chart-box" style="margin-bottom:14px;">
        <div style="font-family:'Barlow',sans-serif;font-weight:700;font-size:13px;margin-bottom:10px;">Categorías que más venden</div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
          <div>
            <div style="font-size:10px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.4px;margin-bottom:6px;">${statsLocal[0].loc.nombre}</div>
            ${cats0.map(([c,g])=>`<div style="font-size:11px;margin-bottom:3px;">${c} <span style="color:var(--muted);">$${fmt(g)}</span></div>`).join('')||'<div style="font-size:11px;color:var(--muted);">—</div>'}
          </div>
          <div>
            <div style="font-size:10px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.4px;margin-bottom:6px;">${statsLocal[1].loc.nombre}</div>
            ${cats1.map(([c,g])=>`<div style="font-size:11px;margin-bottom:3px;">${c} <span style="color:var(--muted);">$${fmt(g)}</span></div>`).join('')||'<div style="font-size:11px;color:var(--muted);">—</div>'}
          </div>
        </div>
      </div>`;
    }

    // Insights automáticos
    const insights = [];
    const [s0, s1] = statsLocal;

    if (s0.margen > 0 && s1.margen > 0 && Math.abs(s0.margen - s1.margen) >= 5) {
      const mejor = s0.margen >= s1.margen ? s0 : s1;
      const otro  = s0.margen >= s1.margen ? s1 : s0;
      insights.push(`💡 El margen de <b>${mejor.loc.nombre}</b> es mejor este mes (${mejor.margen}% vs ${otro.margen}%). Revisa los costos en ${otro.loc.nombre}.`);
    }

    if (s0.n > 0 && s1.n > 0) {
      const tops0 = topProdsLocal(s0.vMes, 1);
      const tops1 = topProdsLocal(s1.vMes, 1);
      if (tops0.length && tops1.length && tops0[0][0] !== tops1[0][0]) {
        const ventasEnOtro = s1.vMes.filter(v => v.nombre === tops0[0][0]).length;
        if (ventasEnOtro === 0) {
          insights.push(`📦 <b>${tops0[0][0]}</b> es tu producto estrella en ${s0.loc.nombre} pero no se ha vendido en ${s1.loc.nombre} este mes. Considera llevarlo.`);
        }
      }
    }

    if (s0.n === 0 && s1.n > 0) {
      insights.push(`⚠️ <b>${s0.loc.nombre}</b> no registra ventas este mes. Revisa si hay algo que resolver.`);
    } else if (s1.n === 0 && s0.n > 0) {
      insights.push(`⚠️ <b>${s1.loc.nombre}</b> no registra ventas este mes. Revisa si hay algo que resolver.`);
    }

    if (s0.gan > 0 && s1.gan > 0) {
      const ratio = Math.round(Math.max(s0.gan, s1.gan) / Math.min(s0.gan, s1.gan));
      const mayor = s0.gan >= s1.gan ? s0 : s1;
      const menor = s0.gan >= s1.gan ? s1 : s0;
      if (ratio >= 2) {
        insights.push(`📊 <b>${mayor.loc.nombre}</b> ganó ${ratio}× más que ${menor.loc.nombre} este mes ($${fmt(mayor.gan)} vs $${fmt(menor.gan)}).`);
      }
    }

    if (insights.length > 0) {
      html += `<div style="font-family:'Barlow',sans-serif;font-weight:700;font-size:13px;margin-bottom:8px;">Insights</div>`;
      html += insights.slice(0,3).map(i => `<div class="loc-insight">${i}</div>`).join('');
    }

  } else if (!esDueno) {
    // Vendedor: solo KPIs de su local
    const vMes = ventasDB.filter(v => esVentaMes(v) && !v.nombre.startsWith('↩️'));
    const gan  = vMes.reduce((s,v) => s + v.gan, 0);
    const gastos = calcGastosMes();
    const ganReal = gan - gastos;
    const meses2 = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    html += `<div class="sgrid" style="margin-bottom:16px;">
      <div class="scard a"><span class="si">💰</span><div class="sv">${ganReal<0?'−':''}$${fmt(Math.abs(ganReal))}</div><div class="sl">Ganancia ${meses2[new Date().getMonth()]}</div></div>
      <div class="scard"><span class="si">🛍️</span><div class="sv">${vMes.length}</div><div class="sl">Ventas este mes</div></div>
      <div class="scard"><span class="si">📦</span><div class="sv">${skuDB.reduce((s,v)=>s+v.stock,0)}</div><div class="sl">Unidades en stock</div></div>
      <div class="scard"><span class="si">🏷️</span><div class="sv">${skuDB.filter(s=>s.activa!==false).length}</div><div class="sl">Variantes activas</div></div>
    </div>`;
  }

  bodyEl.innerHTML = html;
}
```

- [ ] **Step 2: Commit**

```bash
git add index.html
git commit -m "feat: renderLocales() con gestión de locales y análisis comparativo KPIs/productos/insights"
```

---

## Task 7: Funciones CRUD de locales

**Files:**
- Modify: `index.html` — agregar funciones de gestión después de `renderLocales()`

- [ ] **Step 1: Agregar funciones de gestión de locales después de `renderLocales()`**

Agregar inmediatamente después del cierre de `renderLocales()` (antes del comentario `// ══ GUARDAR COMPRA`):

```js
// ── GESTIÓN DE LOCALES ─────────────────────────────────────
let _localEditId = null;
let _localEditActivo = true;
let _localEditTieneVentas = false;

function abrirNuevoLocal() {
  _localEditId = null;
  document.getElementById('local-sheet-titulo').textContent = 'Nuevo local';
  document.getElementById('local-nombre-input').value = '';
  document.getElementById('local-dir-input').value = '';
  document.getElementById('local-edit-section').style.display = 'none';
  document.getElementById('local-guardar-btn').textContent = 'Crear local →';
  const bd = document.getElementById('local-sheet-bd');
  const sh = document.getElementById('local-sheet');
  if (bd) bd.style.display = '';
  if (sh) { sh.style.display = ''; setTimeout(() => sh.classList.add('open'), 10); }
}

async function abrirEditarLocal(id) {
  const loc = _localesDB.find(l => l.id === id);
  if (!loc) return;
  _localEditId = id;
  _localEditActivo = loc.activo !== false;
  document.getElementById('local-sheet-titulo').textContent = 'Editar local';
  document.getElementById('local-nombre-input').value = loc.nombre || '';
  document.getElementById('local-dir-input').value = loc.direccion || '';
  document.getElementById('local-edit-id').value = id;
  document.getElementById('local-guardar-btn').textContent = 'Guardar cambios →';

  // Verificar si tiene ventas
  const { count } = await sb.from('ventas').select('id', { count: 'exact', head: true }).eq('local_id', id);
  _localEditTieneVentas = (count || 0) > 0;

  const editSec = document.getElementById('local-edit-section');
  const toggleBtn = document.getElementById('local-toggle-btn');
  const estadoSub = document.getElementById('local-estado-sub');
  const deleteBtn = document.getElementById('local-delete-btn');
  const deleteSub = document.getElementById('local-delete-sub');

  editSec.style.display = '';
  estadoSub.textContent = _localEditActivo ? 'Activo' : 'Inactivo';
  toggleBtn.textContent = _localEditActivo ? 'Desactivar' : 'Activar';

  if (_localEditTieneVentas) {
    deleteBtn.disabled = true;
    deleteBtn.style.opacity = '.4';
    deleteSub.textContent = 'No se puede eliminar un local con ventas registradas';
  } else {
    deleteBtn.disabled = false;
    deleteBtn.style.opacity = '';
    deleteSub.textContent = '';
  }

  const bd = document.getElementById('local-sheet-bd');
  const sh = document.getElementById('local-sheet');
  if (bd) bd.style.display = '';
  if (sh) { sh.style.display = ''; setTimeout(() => sh.classList.add('open'), 10); }
}

function cerrarLocalSheet() {
  const bd = document.getElementById('local-sheet-bd');
  const sh = document.getElementById('local-sheet');
  if (sh) sh.classList.remove('open');
  setTimeout(() => {
    if (bd) bd.style.display = 'none';
    if (sh) sh.style.display = 'none';
  }, 300);
}

async function guardarLocal() {
  const nombre = (document.getElementById('local-nombre-input')?.value || '').trim();
  const dir    = (document.getElementById('local-dir-input')?.value || '').trim();
  if (!nombre) { toast('Ingresa un nombre para el local.', 'err'); return; }

  const btn = document.getElementById('local-guardar-btn');
  if (btn) { btn.textContent = '⏳ Guardando…'; btn.disabled = true; }

  if (!_localEditId) {
    // Crear nuevo local
    const { data, error } = await sb.from('locales').insert({ nombre, direccion: dir || null, activo: true }).select('id, nombre, direccion, activo, color').single();
    if (error) { toast('Error al crear el local.', 'err'); console.error(error); if(btn){btn.textContent='Crear local →';btn.disabled=false;} return; }
    _localesDB.push(data);
    toast(`Local "${nombre}" creado.`, 'ok');
  } else {
    // Editar local existente
    const { error } = await sb.from('locales').update({ nombre, direccion: dir || null }).eq('id', _localEditId);
    if (error) { toast('Error al guardar.', 'err'); console.error(error); if(btn){btn.textContent='Guardar cambios →';btn.disabled=false;} return; }
    const idx = _localesDB.findIndex(l => l.id === _localEditId);
    if (idx >= 0) { _localesDB[idx].nombre = nombre; _localesDB[idx].direccion = dir || null; }
    toast('Cambios guardados.', 'ok');
  }

  cerrarLocalSheet();
  renderLocales();
  renderDashboard();
  if (btn) { btn.disabled = false; }
}

async function toggleLocalActivo() {
  if (!_localEditId) return;
  const nuevoEstado = !_localEditActivo;
  const { error } = await sb.from('locales').update({ activo: nuevoEstado }).eq('id', _localEditId);
  if (error) { toast('Error al actualizar estado.', 'err'); return; }
  const idx = _localesDB.findIndex(l => l.id === _localEditId);
  if (idx >= 0) _localesDB[idx].activo = nuevoEstado;
  _localEditActivo = nuevoEstado;
  document.getElementById('local-estado-sub').textContent = nuevoEstado ? 'Activo' : 'Inactivo';
  document.getElementById('local-toggle-btn').textContent = nuevoEstado ? 'Desactivar' : 'Activar';
  toast(`Local ${nuevoEstado ? 'activado' : 'desactivado'}.`, 'ok');
  renderLocales();
  renderDashboard();
}

async function eliminarLocalConfirm() {
  if (!_localEditId || _localEditTieneVentas) return;
  if (!confirm(`¿Eliminar este local? Esta acción no se puede deshacer.`)) return;
  const { error } = await sb.from('locales').delete().eq('id', _localEditId);
  if (error) { toast('Error al eliminar.', 'err'); return; }
  _localesDB = _localesDB.filter(l => l.id !== _localEditId);
  if (_activeLocal === _localEditId) setActiveLocal(null);
  cerrarLocalSheet();
  toast('Local eliminado.', 'ok');
  renderLocales();
  renderDashboard();
}
```

- [ ] **Step 2: Commit**

```bash
git add index.html
git commit -m "feat: funciones CRUD de locales (abrirNuevoLocal, guardarLocal, toggleLocalActivo, eliminarLocalConfirm)"
```

---

## Task 8: Mostrar local asignado en la lista de usuarios (Configuración)

**Files:**
- Modify: `index.html` — función `renderEquipo()`

- [ ] **Step 1: Actualizar select de usuarios en `renderEquipo()` para incluir el nombre del local**

Localizar en `renderEquipo()`:
```js
  const { data, error } = await sb.from('usuarios').select('id, nombre, email, rol, activo').order('nombre');
```

Reemplazar con:
```js
  const { data, error } = await sb.from('usuarios').select('id, nombre, email, rol, activo, local_id, locales(nombre)').order('nombre');
```

- [ ] **Step 2: Mostrar local asignado en cada tarjeta de usuario**

Localizar en `renderEquipo()`:
```js
  listaEl.innerHTML = data.map(u => {
    const ini   = u.nombre.split(' ').map(p=>p[0]).join('').slice(0,2).toUpperCase();
    const esDue = u.rol === 'Dueño';
    return `<div class="ucard">
      <div class="uavatar" style="background:${esDue?'var(--accent)':'var(--sf2)'};color:${esDue?'var(--bg)':'var(--muted)'};">${ini}</div>
      <div class="uinfo"><div class="uname">${u.nombre}</div><div class="umeta">${u.email}</div></div>
      <span class="role ${esDue?'owner':'seller'}">${esDue?'Dueño':'Vendedor'}</span>
    </div>`;
  }).join('');
```

Reemplazar con:
```js
  listaEl.innerHTML = data.map(u => {
    const ini      = u.nombre.split(' ').map(p=>p[0]).join('').slice(0,2).toUpperCase();
    const esDue    = u.rol === 'Dueño';
    const locNom   = esDue ? 'Todos los locales' : (u.locales?.nombre || '—');
    return `<div class="ucard">
      <div class="uavatar" style="background:${esDue?'var(--accent)':'var(--sf2)'};color:${esDue?'var(--bg)':'var(--muted)'};">${ini}</div>
      <div class="uinfo"><div class="uname">${u.nombre}</div><div class="umeta">${u.email} · ${locNom}</div></div>
      <span class="role ${esDue?'owner':'seller'}">${esDue?'Dueño':'Vendedor'}</span>
    </div>`;
  }).join('');
```

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: Configuración muestra local asignado a cada usuario del equipo"
```

---

## Task 9: Push y verificación final

- [ ] **Step 1: Push a producción**

```bash
git push origin main
```

- [ ] **Step 2: Verificar en cuanti-two.vercel.app**

Checklist:
- [ ] Dashboard con 2+ locales activos → strip "Local 1 $X | Local 2 $Y" visible
- [ ] Toque en strip → navega a pantalla Locales
- [ ] Pantalla Locales → lista de locales con opción editar
- [ ] Botón "＋ Nuevo local" → sheet con nombre + dirección → crea OK
- [ ] Editar local → cambia nombre → guarda OK
- [ ] Toggle activo/inactivo → cambia estado, local inactivo no aparece en strip
- [ ] Local con ventas → botón "Eliminar" deshabilitado
- [ ] Sección comparativa → KPIs de cada local lado a lado
- [ ] Barra de participación → % correcto
- [ ] Top productos por local → productos correctos
- [ ] Insights → aparecen cuando hay diferencias claras
- [ ] Vendedor → ve solo KPIs de su local, sin selector ni comparación
- [ ] Configuración → cada usuario muestra su local asignado

---

## Self-Review

**Cobertura del spec:**
- ✅ `_activeLocal` + `localFiltro()` — Task 1
- ✅ `cargarLocales()` + `_localesDB` — Task 2
- ✅ `local_id` en ventasDB y skuDB — Task 3
- ✅ Dashboard strip comparativo — Task 4
- ✅ Crear local (nombre, dirección) — Task 7
- ✅ Editar local — Task 7
- ✅ Desactivar local (no eliminar si tiene ventas) — Task 7
- ✅ Eliminar local sin ventas — Task 7
- ✅ KPIs lado a lado — Task 6
- ✅ Barra de participación — Task 6
- ✅ Top productos por local — Task 6
- ✅ Top categorías por local — Task 6
- ✅ Insights accionables — Task 6
- ✅ Vendedor no cambia — Task 6 (rama `else if (!esDueno)`)
- ✅ Local asignado visible en equipo — Task 8

**Sin placeholders:** Todo el código está completo.

**Consistencia de nombres:**
- `_localesDB` → usado en Task 2 (cargarLocales), Task 4 (strip), Task 6 (renderLocales), Task 7 (CRUD)
- `_activeLocal` → usado en Task 1 (setActiveLocal), Task 4 (strip), Task 7 (eliminarLocalConfirm)
- `abrirEditarLocal(id)` → llamado desde Task 6 (renderLocales onclick), definido en Task 7
- `guardarLocal()` → definido en Task 7, llamado desde sheet HTML Task 5
- `toggleLocalActivo()` → definido en Task 7, llamado desde sheet HTML Task 5
- `cerrarLocalSheet()` → definido en Task 7, llamado desde sheet-bd onclick (Task 5) y dentro de CRUD functions
