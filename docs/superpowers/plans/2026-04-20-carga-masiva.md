# Carga Masiva de Stock — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agregar una pantalla "Carga masiva" que permite ingresar stock de múltiples productos en una sola sesión, con soporte para productos existentes y creación de productos nuevos con categoría/marca inline.

**Architecture:** Pantalla nueva `#screen-carga-masiva` en `index.html`. Estado del lote en `_cmLote[]` (array en memoria). Al confirmar, ejecuta updates/inserts en Supabase secuencialmente y recarga `skuDB`. El sheet de agregar producto reutiliza el patrón sheet existente (`.sheet` / `.sheet-bd`), pero con su propio par de divs (`#cm-sheet` / `#cm-sheet-bd`).

**Tech Stack:** HTML + CSS + Vanilla JS + Supabase JS v2 · `index.html` único

---

## Contexto del codebase

- **Archivo único:** `index.html` (~6800 líneas). Todo el HTML, CSS y JS está ahí.
- **Globals relevantes:** `skuDB[]`, `_currentUser`, `_activeLocal`, `_localesDB`
- **Navegación:** `goTo(id)` — añadir `'carga-masiva'` a `ALL_SCREENS` (línea ~2265) y manejar el caso en la función.
- **Toast:** `toast(msg, tipo)` — tipo `'ok'` (default) o `'err'`.
- **Patrones Supabase usados:**
  - Update stock: `sb.from('variantes').update({ stock_actual: nuevo, costo_ultima_compra: costo }).eq('id', varId)`
  - Insert variante: `sb.from('variantes').insert({ producto_id, talla_color, local_id, stock_actual, stock_minimo:0, costo_ultima_compra, activa:true })`
  - SKU de variante: lo genera Supabase automáticamente (trigger en DB), no se envía en el insert.
- **Sheet pattern:** `.sheet-bd` (backdrop) + `.sheet` (contenedor) con `.sheet.open` para mostrar.
- **CSS design tokens:** `--bg #F5F5F2`, `--sf #FFFFFF`, `--sf2 #F2F2EE`, `--bd #E6E3DD`, `--accent #D7F02E`, `--text #171717`, `--muted #595959`.
- **Tipografías:** `'Barlow'` para cuerpo/títulos, `'DM Mono'` para números/SKUs.
- **Chips activos:** clase `.sel` (no `.on`) para chips de selección en formularios.

---

## File Structure

Solo `index.html` se modifica:

| Sección | Qué cambia |
|---------|-----------|
| HTML — `ALL_SCREENS` (~línea 2265) | Añadir `'carga-masiva'` |
| HTML — `PANTALLAS_SOLO_DUENO` (~línea 2266) | Añadir `'carga-masiva'` |
| HTML — `#screen-inventario` (~línea 1132) | Añadir botón "Carga masiva" en acciones rápidas |
| HTML — Nueva pantalla después de `#screen-inventario` | `#screen-carga-masiva` |
| HTML — Nuevo sheet después de `#inv-sheet` | `#cm-sheet` + `#cm-sheet-bd` |
| CSS — Bloque nuevo | Estilos `.cm-*` |
| JS — `goTo()` (~línea 2352) | Añadir caso `carga-masiva` |
| JS — `screenTitles` (~línea 2338) | Añadir `'carga-masiva': 'Carga masiva'` |
| JS — Nuevo bloque de funciones | `_cmLote`, `abrirCargaMasiva()`, `cmRenderLote()`, `cmAbrirSheet()`, `cmCerrarSheet()`, `cmBuscar()`, `cmSelExistente()`, `cmMostrarNuevo()`, `cmCatSeleccionar()`, `cmMarcaSeleccionar()`, `cmAgregarVariante()`, `cmActualizarPrecio()`, `cmGuardarNuevo()`, `cmEliminarLinea()`, `cmConfirmar()`, `levenshtein()`, `cmNormalizar()`, `cmSugerirDuplicado()` |

---

## Task 1: CSS + HTML shell de pantalla y sheet

**Files:**
- Modify: `index.html` — CSS block (~línea 670 después del bloque SKU), HTML nueva pantalla, HTML nuevo sheet

- [ ] **Step 1: Localizar el punto de inserción CSS**

Busca el bloque `/* ─── SKU / ETIQUETAS ─── */` (~línea 658). Añade el bloque CSS de carga masiva justo después del cierre de ese bloque.

- [ ] **Step 2: Insertar CSS**

Añade este bloque CSS después de la línea `.sku-price-tag{...}`:

```css
/* ─── CARGA MASIVA ─── */
.cm-line{background:var(--sf);border:1px solid var(--bd);border-radius:12px;padding:14px;margin-bottom:8px;}
.cm-line-header{display:flex;align-items:flex-start;justify-content:space-between;gap:8px;margin-bottom:10px;}
.cm-line-nombre{font-family:'Barlow',sans-serif;font-weight:700;font-size:14px;color:var(--text);flex:1;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}
.cm-line-variante{font-size:11px;color:var(--muted);margin-top:1px;}
.cm-line-del{background:none;border:none;color:var(--muted2);font-size:18px;cursor:pointer;padding:0;line-height:1;flex-shrink:0;}
.cm-line-inputs{display:grid;grid-template-columns:1fr 1fr;gap:8px;}
.cm-input-wrap{display:flex;flex-direction:column;gap:4px;}
.cm-input-lbl{font-size:10px;font-weight:600;color:var(--muted);letter-spacing:.5px;text-transform:uppercase;}
.cm-input{width:100%;background:var(--sf2);border:1px solid var(--bd);border-radius:9px;padding:10px 12px;font-family:'DM Mono',monospace;font-size:14px;color:var(--text);outline:none;box-sizing:border-box;}
.cm-input:focus{border-color:var(--bd2);}
.cm-empty{text-align:center;padding:40px 0 20px;color:var(--muted);font-size:13px;}
.cm-search{width:100%;background:var(--sf2);border:1px solid var(--bd);border-radius:10px;padding:11px 14px;font-size:14px;color:var(--text);outline:none;box-sizing:border-box;margin-bottom:12px;}
.cm-search:focus{border-color:var(--bd2);}
.cm-res-item{display:flex;align-items:center;gap:10px;padding:10px 2px;border-bottom:1px solid var(--bd);cursor:pointer;}
.cm-res-item:active{opacity:.6;}
.cm-res-icon{width:34px;height:34px;background:var(--sf2);border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:13px;font-weight:700;color:var(--muted);flex-shrink:0;}
.cm-res-nombre{font-size:13px;font-weight:600;color:var(--text);}
.cm-res-meta{font-size:11px;color:var(--muted);}
.cm-tabs{display:flex;gap:6px;margin-bottom:16px;}
.cm-tab{flex:1;text-align:center;padding:9px;border-radius:9px;font-size:13px;font-weight:600;cursor:pointer;background:var(--sf2);color:var(--muted);border:1px solid var(--bd);}
.cm-tab.sel{background:var(--text);color:var(--bg);}
.cm-field{margin-bottom:14px;}
.cm-label{font-size:11px;font-weight:600;color:var(--muted);letter-spacing:.5px;text-transform:uppercase;margin-bottom:5px;}
.cm-sel-btn{width:100%;text-align:left;background:var(--sf2);border:1px solid var(--bd);border-radius:9px;padding:10px 14px;font-size:14px;color:var(--text);cursor:pointer;display:flex;align-items:center;justify-content:space-between;}
.cm-sel-btn .placeholder{color:var(--muted);}
.cm-sel-list{background:var(--sf2);border:1px solid var(--bd);border-radius:9px;overflow:hidden;margin-top:4px;display:none;}
.cm-sel-list.open{display:block;}
.cm-sel-opt{padding:10px 14px;font-size:13px;cursor:pointer;border-bottom:1px solid var(--bd);}
.cm-sel-opt:last-child{border-bottom:none;}
.cm-sel-opt:active{background:var(--sf3);}
.cm-sel-opt.sel{font-weight:600;color:var(--text);}
.cm-new-input{width:100%;background:var(--sf);border:1px solid var(--accent);border-radius:9px;padding:10px 14px;font-size:14px;color:var(--text);outline:none;box-sizing:border-box;margin-top:6px;}
.cm-sugerencia{font-size:12px;color:var(--muted);margin-top:4px;padding:8px 10px;background:var(--sf2);border-radius:8px;display:none;}
.cm-sugerencia.show{display:block;}
.cm-variantes-wrap{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:8px;}
.cm-variante-chip{padding:7px 12px;background:var(--sf2);border:1px solid var(--bd);border-radius:8px;font-size:12px;font-weight:600;cursor:pointer;display:flex;align-items:center;gap:6px;}
.cm-variante-chip .rm{font-size:14px;color:var(--muted2);line-height:1;}
.cm-margen-helper{display:flex;align-items:center;gap:6px;margin-top:6px;flex-wrap:wrap;}
.cm-margen-helper span{font-size:11px;color:var(--muted);}
.cm-margen-helper .resultado{font-family:'DM Mono',monospace;font-size:13px;font-weight:600;color:var(--text);}
.cm-confirm-btn{width:100%;background:var(--accent);border:none;border-radius:12px;padding:14px;font-family:'Barlow',sans-serif;font-weight:700;font-size:15px;color:var(--text);cursor:pointer;margin-top:4px;}
.cm-confirm-btn:disabled{opacity:.35;cursor:default;}
```

- [ ] **Step 3: Insertar HTML — nueva pantalla**

Localiza el cierre del bloque `#screen-inventario` (busca `</div>` que sigue a `<div id="inv-lista"></div>`) y añade la pantalla nueva inmediatamente después:

```html
<!-- ════════════════════════════ CARGA MASIVA ════════════════════════════ -->
<div class="screen" id="screen-carga-masiva">
  <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;">
    <button onclick="goTo('inventario')" style="background:none;border:none;font-size:22px;color:var(--text);cursor:pointer;padding:0;line-height:1;">←</button>
    <div style="font-family:'Barlow',sans-serif;font-weight:700;font-size:18px;letter-spacing:-.3px;">Carga masiva</div>
    <button id="cm-confirm-top" onclick="cmConfirmar()" disabled style="background:var(--accent);border:none;border-radius:9px;padding:8px 14px;font-family:'Barlow',sans-serif;font-weight:700;font-size:13px;color:var(--text);cursor:pointer;opacity:.35;">Confirmar</button>
  </div>

  <div id="cm-lote-list"></div>

  <button onclick="cmAbrirSheet()" style="width:100%;background:var(--sf2);border:1px dashed var(--bd2);border-radius:12px;padding:13px;font-family:'Barlow',sans-serif;font-weight:600;font-size:14px;color:var(--muted);cursor:pointer;margin-top:4px;">+ Agregar producto</button>

  <div id="cm-confirm-bottom-wrap" style="display:none;margin-top:16px;">
    <button onclick="cmConfirmar()" class="cm-confirm-btn" id="cm-confirm-bottom">Confirmar carga →</button>
  </div>
</div>
```

- [ ] **Step 4: Insertar HTML — sheet agregar producto**

Localiza `<!-- ── BOTTOM SHEET INVENTARIO ── -->` (~línea 1913) y añade el sheet de carga masiva inmediatamente después del cierre del sheet de inventario (`</div>` que sigue a `id="inv-sheet"`):

```html
<!-- ── BOTTOM SHEET CARGA MASIVA ── -->
<div class="sheet-bd" id="cm-sheet-bd" onclick="cmCerrarSheet()"></div>
<div class="sheet" id="cm-sheet">
  <div class="sheet-handle"></div>
  <div id="cm-sheet-body"></div>
</div>
```

- [ ] **Step 5: Verificar visualmente**

Abre el archivo en navegador. Navega a `goTo('carga-masiva')` desde la consola. Debe mostrar pantalla con header "Carga masiva", botón "← " y botón "+ Agregar producto". No debe haber errores JS en consola.

- [ ] **Step 6: Commit**

```bash
git add index.html
git commit -m "feat: HTML + CSS shell pantalla carga masiva"
```

---

## Task 2: Estado global + Navegación

**Files:**
- Modify: `index.html` — JS globals, `ALL_SCREENS`, `PANTALLAS_SOLO_DUENO`, `goTo()`, botón en inventario

- [ ] **Step 1: Añadir variable global `_cmLote`**

Localiza la línea `let gastosDB = [];` (~línea 25) y añade después:

```js
let _cmLote = []; // [{ tipo:'existente'|'nuevo', varId, prodId, nombre, variante, qty, costo, _esNuevo, _prod }]
```

- [ ] **Step 2: Actualizar `ALL_SCREENS`**

Localiza (~línea 2265):
```js
const ALL_SCREENS = ['dashboard','inventario','venta','compras','nueva-compra','historial','analisis','locales','config','notifs','skus','scanner'];
```
Cámbiala a:
```js
const ALL_SCREENS = ['dashboard','inventario','venta','compras','nueva-compra','historial','analisis','locales','config','notifs','skus','scanner','carga-masiva'];
```

- [ ] **Step 3: Actualizar `PANTALLAS_SOLO_DUENO`**

Localiza (~línea 2266):
```js
const PANTALLAS_SOLO_DUENO = ['dashboard','historial','analisis','skus','compras','config','locales','notifs'];
```
Cámbiala a:
```js
const PANTALLAS_SOLO_DUENO = ['dashboard','historial','analisis','skus','compras','config','locales','notifs','carga-masiva'];
```

- [ ] **Step 4: Añadir `'carga-masiva'` a `screenTitles` en `goTo()`**

Localiza el objeto `screenTitles` dentro de `goTo()` (~línea 2338):
```js
const screenTitles = {
    dashboard: null,
    inventario: 'Inventario', venta: 'Nueva venta', ...
```
Añade `'carga-masiva': 'Carga masiva',` a ese objeto (en cualquier posición).

- [ ] **Step 5: Añadir inicialización en `goTo()` para 'carga-masiva'**

Localiza el bloque de acciones al entrar en `goTo()` (~línea 2352, después de `if(id === 'config')`). Añade:
```js
if(id === 'carga-masiva') abrirCargaMasiva();
```

- [ ] **Step 6: Añadir botón "Carga masiva" en inventario**

Localiza en `#screen-inventario` (~línea 1137):
```html
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;">
      <div class="inv-act-btn" onclick="goTo('skus')"><div class="inv-act-icon">📦</div><div class="inv-act-lbl">+ Producto</div></div>
      <div class="inv-act-btn" onclick="goTo('compras')"><div class="inv-act-icon">🧾</div><div class="inv-act-lbl">+ Compra</div></div>
    </div>
```
Cámbiala a:
```html
    <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px;">
      <div class="inv-act-btn" onclick="goTo('skus')"><div class="inv-act-icon">📦</div><div class="inv-act-lbl">+ Producto</div></div>
      <div class="inv-act-btn" onclick="goTo('compras')"><div class="inv-act-icon">🧾</div><div class="inv-act-lbl">+ Compra</div></div>
      <div class="inv-act-btn" onclick="goTo('carga-masiva')"><div class="inv-act-icon">📥</div><div class="inv-act-lbl">Carga masiva</div></div>
    </div>
```

- [ ] **Step 7: Añadir función `abrirCargaMasiva()`**

Localiza el bloque JS de inventario (busca `function invAbrirSheet()` ~línea 3761). Añade antes de esa función:

```js
// ══════════════════════════════════════════════════════
//  CARGA MASIVA
// ══════════════════════════════════════════════════════

function abrirCargaMasiva() {
  _cmLote = [];
  cmRenderLote();
}

function cmRenderLote() {
  const list = document.getElementById('cm-lote-list');
  const confirmTop = document.getElementById('cm-confirm-top');
  const confirmBottomWrap = document.getElementById('cm-confirm-bottom-wrap');
  if (!list) return;

  if (_cmLote.length === 0) {
    list.innerHTML = `<div class="cm-empty">Todavía no agregaste productos.<br>Toca "+ Agregar producto" para empezar.</div>`;
    if (confirmTop) { confirmTop.disabled = true; confirmTop.style.opacity = '.35'; }
    if (confirmBottomWrap) confirmBottomWrap.style.display = 'none';
    return;
  }

  list.innerHTML = _cmLote.map((linea, i) => `
    <div class="cm-line">
      <div class="cm-line-header">
        <div>
          <div class="cm-line-nombre">${esc(linea.nombre)}</div>
          <div class="cm-line-variante">${esc(linea.variante)}${linea._esNuevo ? ' · <em style="color:var(--accent);font-style:normal;">Nuevo</em>' : ''}</div>
        </div>
        <button class="cm-line-del" onclick="cmEliminarLinea(${i})">×</button>
      </div>
      <div class="cm-line-inputs">
        <div class="cm-input-wrap">
          <div class="cm-input-lbl">Cantidad</div>
          <input class="cm-input" type="number" inputmode="numeric" min="1" value="${linea.qty}"
            onchange="_cmLote[${i}].qty = Math.max(1, parseInt(this.value)||1); cmRenderLote();">
        </div>
        <div class="cm-input-wrap">
          <div class="cm-input-lbl">Costo unit. $</div>
          <input class="cm-input" type="number" inputmode="decimal" min="0" value="${linea.costo}"
            onchange="_cmLote[${i}].costo = Math.max(0, parseFloat(this.value)||0); cmRenderLote();">
        </div>
      </div>
    </div>
  `).join('');

  const hayInvalidas = _cmLote.some(l => l.qty < 1);
  if (confirmTop) { confirmTop.disabled = hayInvalidas; confirmTop.style.opacity = hayInvalidas ? '.35' : '1'; }
  if (confirmBottomWrap) confirmBottomWrap.style.display = 'block';
}

function cmEliminarLinea(i) {
  _cmLote.splice(i, 1);
  cmRenderLote();
}
```

- [ ] **Step 8: Verificar navegación**

1. Abre la app en el navegador (o recarga).
2. Ir a Inventario → debe verse el botón "Carga masiva" en la grilla de acciones.
3. Toca "Carga masiva" → debe navegar a la pantalla con el mensaje vacío "Todavía no agregaste productos."
4. El botón "Confirmar" en la cabecera debe estar deshabilitado (opaco).
5. Toca "← " → debe volver a Inventario.

- [ ] **Step 9: Commit**

```bash
git add index.html
git commit -m "feat: navegación + estado carga masiva"
```

---

## Task 3: Sheet — Agregar producto existente

**Files:**
- Modify: `index.html` — JS funciones `cmAbrirSheet()`, `cmCerrarSheet()`, `cmBuscar()`, `cmSelExistente()`

- [ ] **Step 1: Añadir funciones de sheet y búsqueda**

Localiza las funciones `abrirCargaMasiva` / `cmRenderLote` / `cmEliminarLinea` que acabas de añadir. Añade estas funciones justo después:

```js
function cmAbrirSheet() {
  const bd = document.getElementById('cm-sheet-bd');
  const sh = document.getElementById('cm-sheet');
  if (!bd || !sh) return;
  bd.style.display = 'block';
  requestAnimationFrame(() => sh.classList.add('open'));
  cmRenderSheetInicio();
}

function cmCerrarSheet() {
  const sh = document.getElementById('cm-sheet');
  const bd = document.getElementById('cm-sheet-bd');
  if (!sh) return;
  sh.classList.remove('open');
  setTimeout(() => { if (bd) bd.style.display = 'none'; }, 300);
}

function cmRenderSheetInicio() {
  const body = document.getElementById('cm-sheet-body');
  if (!body) return;
  body.innerHTML = `
    <div style="font-family:'Barlow',sans-serif;font-weight:700;font-size:17px;letter-spacing:-.3px;margin-bottom:14px;">Agregar producto</div>
    <div class="cm-tabs">
      <div class="cm-tab sel" id="cm-tab-existente" onclick="cmTabSeleccionar('existente')">Existente</div>
      <div class="cm-tab" id="cm-tab-nuevo" onclick="cmTabSeleccionar('nuevo')">Nuevo</div>
    </div>
    <div id="cm-tab-content"></div>
  `;
  cmRenderTabExistente();
}

function cmTabSeleccionar(tab) {
  document.getElementById('cm-tab-existente')?.classList.toggle('sel', tab === 'existente');
  document.getElementById('cm-tab-nuevo')?.classList.toggle('sel', tab === 'nuevo');
  if (tab === 'existente') cmRenderTabExistente();
  else cmRenderTabNuevo();
}

function cmRenderTabExistente() {
  const cont = document.getElementById('cm-tab-content');
  if (!cont) return;
  cont.innerHTML = `
    <input class="cm-search" id="cm-buscar-input" type="text" placeholder="Busca producto o SKU…"
      oninput="cmBuscar(this.value)" autocomplete="off">
    <div id="cm-buscar-resultados"></div>
  `;
  document.getElementById('cm-buscar-input')?.focus();
  cmBuscar('');
}

function cmBuscar(q) {
  const cont = document.getElementById('cm-buscar-resultados');
  if (!cont) return;
  const norm = q.trim().toLowerCase();
  const lf = localFiltro();
  const resultados = skuDB.filter(s => {
    if (lf !== null && s.local_id !== lf) return false;
    return !norm ||
      s.nombre.toLowerCase().includes(norm) ||
      s.variante.toLowerCase().includes(norm) ||
      s.sku.includes(norm);
  }).slice(0, 30);

  if (resultados.length === 0) {
    cont.innerHTML = `<div style="color:var(--muted);font-size:13px;text-align:center;padding:20px 0;">Sin resultados</div>`;
    return;
  }

  cont.innerHTML = resultados.map(s => `
    <div class="cm-res-item" onclick="cmSelExistente('${s.sku}')">
      <div class="cm-res-icon">${esc(s.icon)}</div>
      <div style="flex:1;min-width:0;">
        <div class="cm-res-nombre">${esc(s.nombre)}</div>
        <div class="cm-res-meta">${esc(s.variante)} · SKU ${esc(s.sku)} · ${s.stock} ud.</div>
      </div>
    </div>
  `).join('');
}

function cmSelExistente(sku) {
  const s = skuDB.find(x => x.sku === sku);
  if (!s) return;

  // Si ya está en el lote, no duplicar
  const yaExiste = _cmLote.find(l => l.varId === s.id);
  if (yaExiste) {
    toast('Ya está en el lote — ajustá la cantidad directamente.', 'err');
    return;
  }

  _cmLote.push({
    tipo: 'existente',
    varId: s.id,
    prodId: s.prod_id,
    nombre: s.nombre,
    variante: s.variante,
    qty: 1,
    costo: s.costo || 0,
    _esNuevo: false,
  });
  cmCerrarSheet();
  cmRenderLote();
}
```

- [ ] **Step 2: Verificar que `skuDB` tiene `id` y `prod_id`**

Busca la función `cargarInventario()` (~línea 55) y verifica que el map devuelva `id` y `prod_id`. Debe existir algo como:

```js
return {
  id: v.id,         // id de variante
  prod_id: v.producto_id || v.productos?.id,  // id de producto
  nombre: nomProd,
  ...
```

Si no existe `prod_id`, localiza el map y añade `prod_id: v.producto_id,` junto a los otros campos.

- [ ] **Step 3: Verificar en navegador**

1. Ir a Carga masiva.
2. Tocar "+ Agregar producto" → debe abrir sheet con tabs "Existente" / "Nuevo".
3. La lista inicial muestra todos los productos de `skuDB` (o los del local activo).
4. Buscar "air" → filtra correctamente.
5. Seleccionar un producto → cierra el sheet y aparece como línea en el lote.
6. Intentar agregar el mismo producto de nuevo → toast "Ya está en el lote".
7. Tocar "×" en la línea → la elimina.

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: sheet agregar producto existente en carga masiva"
```

---

## Task 4: Sheet — Crear producto nuevo (parte 1: categoría, marca, nombre)

**Files:**
- Modify: `index.html` — JS funciones `cmRenderTabNuevo()`, `levenshtein()`, `cmNormalizar()`, `cmSugerirDuplicado()`, `cmCatSeleccionar()`, `cmMarcaSeleccionar()`, y estado `_cmNuevo`

- [ ] **Step 1: Añadir estado `_cmNuevo` global**

Localiza `let _cmLote = [];` (la línea que agregaste en Task 2 Step 1). Añade justo después:

```js
let _cmNuevo = {}; // estado temporal para el form de producto nuevo
```

- [ ] **Step 2: Añadir funciones fuzzy matching**

Añade estas funciones al bloque de Carga Masiva (antes de `cmAbrirSheet`):

```js
function cmNormalizar(str) {
  return String(str).trim().toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

function levenshtein(a, b) {
  const m = a.length, n = b.length;
  const dp = Array.from({ length: m + 1 }, (_, i) =>
    Array.from({ length: n + 1 }, (_, j) => i === 0 ? j : j === 0 ? i : 0)
  );
  for (let i = 1; i <= m; i++)
    for (let j = 1; j <= n; j++)
      dp[i][j] = a[i-1] === b[j-1] ? dp[i-1][j-1]
        : 1 + Math.min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]);
  return dp[m][n];
}

function cmSugerirDuplicado(inputVal, lista) {
  // lista: [{ id, nombre }]
  const norm = cmNormalizar(inputVal);
  if (norm.length < 2) return null;
  let mejor = null, mejorDist = Infinity;
  for (const item of lista) {
    const d = levenshtein(norm, cmNormalizar(item.nombre));
    if (d < mejorDist && d <= 2) { mejorDist = d; mejor = item; }
  }
  return mejor;
}
```

- [ ] **Step 3: Añadir función `cmRenderTabNuevo()`**

Añade esta función después de `cmRenderTabExistente()`:

```js
async function cmRenderTabNuevo() {
  const cont = document.getElementById('cm-tab-content');
  if (!cont) return;
  cont.innerHTML = `<div style="color:var(--muted);font-size:13px;text-align:center;padding:16px 0;">Cargando…</div>`;

  const [{ data: cats }, { data: marcas }] = await Promise.all([
    sb.from('categorias').select('id, nombre').order('nombre'),
    sb.from('marcas').select('id, nombre').order('nombre'),
  ]);

  _cmNuevo = {
    cats: cats || [],
    marcas: marcas || [],
    catId: null, catNuevaNombre: null,
    marcaId: null, marcaNuevaNombre: null,
    variantes: [], // [{ talla_color, qty, costo }]
    precio: 0,
  };

  cont.innerHTML = `
    <div class="cm-field">
      <div class="cm-label">Nombre del producto *</div>
      <input id="cm-nuevo-nombre" class="cm-new-input" type="text" placeholder="ej. Zapatilla Air Max" autocomplete="off">
    </div>

    <div class="cm-field">
      <div class="cm-label">Categoría *</div>
      <button class="cm-sel-btn" id="cm-cat-btn" onclick="cmToggleLista('cat')">
        <span class="placeholder" id="cm-cat-txt">Seleccionar…</span><span>▾</span>
      </button>
      <div class="cm-sel-list" id="cm-cat-list">
        ${(cats||[]).map(c => `<div class="cm-sel-opt" onclick="cmCatSeleccionar(${c.id}, '${esc(c.nombre)}')">${esc(c.nombre)}</div>`).join('')}
        <div class="cm-sel-opt" style="color:var(--muted);font-style:italic;" onclick="cmMostrarNuevaCat()">+ Nueva categoría</div>
      </div>
      <div id="cm-nueva-cat-wrap" style="display:none;">
        <input id="cm-nueva-cat-input" class="cm-new-input" type="text" placeholder="Nombre de categoría" oninput="cmCheckDupCat(this.value)">
        <div class="cm-sugerencia" id="cm-cat-sug"></div>
      </div>
    </div>

    <div class="cm-field">
      <div class="cm-label">Marca *</div>
      <button class="cm-sel-btn" id="cm-marca-btn" onclick="cmToggleLista('marca')">
        <span class="placeholder" id="cm-marca-txt">Seleccionar…</span><span>▾</span>
      </button>
      <div class="cm-sel-list" id="cm-marca-list">
        ${(marcas||[]).map(m => `<div class="cm-sel-opt" onclick="cmMarcaSeleccionar(${m.id}, '${esc(m.nombre)}')">${esc(m.nombre)}</div>`).join('')}
        <div class="cm-sel-opt" style="color:var(--muted);font-style:italic;" onclick="cmMostrarNuevaMarca()">+ Nueva marca</div>
      </div>
      <div id="cm-nueva-marca-wrap" style="display:none;">
        <input id="cm-nueva-marca-input" class="cm-new-input" type="text" placeholder="Nombre de marca" oninput="cmCheckDupMarca(this.value)">
        <div class="cm-sugerencia" id="cm-marca-sug"></div>
      </div>
    </div>

    <div id="cm-variantes-seccion"></div>
    <div id="cm-precio-seccion"></div>

    <button onclick="cmGuardarNuevo()" style="width:100%;background:var(--text);border:none;border-radius:10px;padding:12px;font-family:'Barlow',sans-serif;font-weight:700;font-size:14px;color:var(--bg);cursor:pointer;margin-top:8px;">Agregar al lote →</button>
  `;

  cmRenderVariantesSeccion();
  cmRenderPrecioSeccion();
}

function cmToggleLista(cual) {
  const lista = document.getElementById(`cm-${cual}-list`);
  if (!lista) return;
  lista.classList.toggle('open');
}

function cmCatSeleccionar(id, nombre) {
  _cmNuevo.catId = id;
  _cmNuevo.catNuevaNombre = null;
  const txt = document.getElementById('cm-cat-txt');
  if (txt) { txt.textContent = nombre; txt.classList.remove('placeholder'); }
  const lista = document.getElementById('cm-cat-list');
  if (lista) lista.classList.remove('open');
  const wrap = document.getElementById('cm-nueva-cat-wrap');
  if (wrap) wrap.style.display = 'none';
}

function cmMarcaSeleccionar(id, nombre) {
  _cmNuevo.marcaId = id;
  _cmNuevo.marcaNuevaNombre = null;
  const txt = document.getElementById('cm-marca-txt');
  if (txt) { txt.textContent = nombre; txt.classList.remove('placeholder'); }
  const lista = document.getElementById('cm-marca-list');
  if (lista) lista.classList.remove('open');
  const wrap = document.getElementById('cm-nueva-marca-wrap');
  if (wrap) wrap.style.display = 'none';
}

function cmMostrarNuevaCat() {
  _cmNuevo.catId = null;
  const lista = document.getElementById('cm-cat-list');
  if (lista) lista.classList.remove('open');
  const wrap = document.getElementById('cm-nueva-cat-wrap');
  if (wrap) wrap.style.display = 'block';
  document.getElementById('cm-nueva-cat-input')?.focus();
}

function cmMostrarNuevaMarca() {
  _cmNuevo.marcaId = null;
  const lista = document.getElementById('cm-marca-list');
  if (lista) lista.classList.remove('open');
  const wrap = document.getElementById('cm-nueva-marca-wrap');
  if (wrap) wrap.style.display = 'block';
  document.getElementById('cm-nueva-marca-input')?.focus();
}

function cmCheckDupCat(val) {
  const sug = document.getElementById('cm-cat-sug');
  if (!sug) return;
  _cmNuevo.catNuevaNombre = val.trim() || null;
  _cmNuevo.catId = null;
  const match = cmSugerirDuplicado(val, _cmNuevo.cats);
  if (match) {
    sug.innerHTML = `¿Quisiste decir <strong>${esc(match.nombre)}</strong>? <span onclick="cmCatSeleccionar(${match.id},'${esc(match.nombre)}')" style="text-decoration:underline;cursor:pointer;color:var(--blue);">Usar esta</span>`;
    sug.classList.add('show');
  } else {
    sug.classList.remove('show');
  }
}

function cmCheckDupMarca(val) {
  const sug = document.getElementById('cm-marca-sug');
  if (!sug) return;
  _cmNuevo.marcaNuevaNombre = val.trim() || null;
  _cmNuevo.marcaId = null;
  const match = cmSugerirDuplicado(val, _cmNuevo.marcas);
  if (match) {
    sug.innerHTML = `¿Quisiste decir <strong>${esc(match.nombre)}</strong>? <span onclick="cmMarcaSeleccionar(${match.id},'${esc(match.nombre)}')" style="text-decoration:underline;cursor:pointer;color:var(--blue);">Usar esta</span>`;
    sug.classList.add('show');
  } else {
    sug.classList.remove('show');
  }
}
```

- [ ] **Step 4: Verificar en navegador**

1. Ir a Carga masiva → Agregar producto → Tab "Nuevo".
2. Debe mostrar el form con Nombre, Categoría, Marca.
3. Al tocar "Seleccionar…" en Categoría → despliega lista con las categorías de Supabase + "Nueva categoría".
4. Seleccionar una → cierra lista y muestra el nombre seleccionado.
5. Tocar "+ Nueva categoría" → muestra el input de nombre.
6. Escribir "zapatilla" → si existe "Zapatillas" → debe mostrar sugerencia "¿Quisiste decir Zapatillas? Usar esta".
7. Tocar "Usar esta" → selecciona la categoría existente y oculta el input.

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: form nuevo producto — nombre, categoría, marca con fuzzy matching"
```

---

## Task 5: Sheet — Crear producto nuevo (parte 2: variantes y precio)

**Files:**
- Modify: `index.html` — JS funciones `cmRenderVariantesSeccion()`, `cmAgregarVariante()`, `cmEliminarVariante()`, `cmRenderPrecioSeccion()`, `cmActualizarPrecio()`

- [ ] **Step 1: Añadir funciones de variantes y precio**

Añade estas funciones al bloque de Carga Masiva (después de `cmCheckDupMarca`):

```js
function cmRenderVariantesSeccion() {
  const sec = document.getElementById('cm-variantes-seccion');
  if (!sec) return;
  sec.innerHTML = `
    <div class="cm-field">
      <div class="cm-label">Variantes *</div>
      <div class="cm-variantes-wrap" id="cm-variantes-chips">
        ${_cmNuevo.variantes.map((v, i) => `
          <div class="cm-variante-chip">
            <span>${esc(v.talla_color)}</span>
            <span class="rm" onclick="cmEliminarVariante(${i})">×</span>
          </div>
        `).join('')}
      </div>
      <div style="display:flex;gap:8px;">
        <input id="cm-var-input" class="cm-new-input" type="text" placeholder="ej. Talla 42 / Negro"
          style="flex:1;" autocomplete="off">
        <button onclick="cmAgregarVariante()" style="background:var(--sf2);border:1px solid var(--bd);border-radius:9px;padding:10px 14px;font-weight:700;font-size:13px;cursor:pointer;">+</button>
      </div>
    </div>
    <div class="cm-field" id="cm-var-stock-section"></div>
  `;
  cmRenderVarStockSection();
}

function cmAgregarVariante() {
  const inp = document.getElementById('cm-var-input');
  if (!inp) return;
  const val = inp.value.trim();
  if (!val) return;
  if (_cmNuevo.variantes.find(v => cmNormalizar(v.talla_color) === cmNormalizar(val))) {
    toast('Esa variante ya existe.', 'err'); return;
  }
  _cmNuevo.variantes.push({ talla_color: val, qty: 1, costo: 0 });
  inp.value = '';
  cmRenderVariantesSeccion();
}

function cmEliminarVariante(i) {
  _cmNuevo.variantes.splice(i, 1);
  cmRenderVariantesSeccion();
}

function cmRenderVarStockSection() {
  const sec = document.getElementById('cm-var-stock-section');
  if (!sec || _cmNuevo.variantes.length === 0) { if(sec) sec.innerHTML=''; return; }
  sec.innerHTML = `
    <div class="cm-label">Stock y costo por variante</div>
    ${_cmNuevo.variantes.map((v, i) => `
      <div style="display:grid;grid-template-columns:1fr 80px 90px;gap:6px;align-items:center;margin-bottom:6px;">
        <div style="font-size:13px;font-weight:600;color:var(--text);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${esc(v.talla_color)}</div>
        <input class="cm-input" type="number" inputmode="numeric" min="1" placeholder="Qty" value="${v.qty}"
          onchange="_cmNuevo.variantes[${i}].qty = Math.max(1, parseInt(this.value)||1);">
        <input class="cm-input" type="number" inputmode="decimal" min="0" placeholder="Costo $" value="${v.costo||''}"
          onchange="_cmNuevo.variantes[${i}].costo = Math.max(0, parseFloat(this.value)||0); cmActualizarPrecio();">
      </div>
    `).join('')}
  `;
}

function cmRenderPrecioSeccion() {
  const sec = document.getElementById('cm-precio-seccion');
  if (!sec) return;
  sec.innerHTML = `
    <div class="cm-field">
      <div class="cm-label">Precio de venta *</div>
      <input id="cm-precio-input" class="cm-new-input" type="number" inputmode="decimal" min="0"
        placeholder="ej. 89.990" value="${_cmNuevo.precio || ''}"
        oninput="_cmNuevo.precio = parseFloat(this.value)||0;">
      <div class="cm-margen-helper">
        <span>Costo</span>
        <input id="cm-helper-costo" type="number" inputmode="decimal" min="0" placeholder="0"
          style="width:70px;background:var(--sf2);border:1px solid var(--bd);border-radius:7px;padding:6px 8px;font-size:12px;color:var(--text);outline:none;"
          oninput="cmActualizarPrecio()">
        <span>+ Margen</span>
        <input id="cm-helper-margen" type="number" inputmode="decimal" min="0" max="99" placeholder="0"
          style="width:50px;background:var(--sf2);border:1px solid var(--bd);border-radius:7px;padding:6px 8px;font-size:12px;color:var(--text);outline:none;"
          oninput="cmActualizarPrecio()">
        <span>%</span>
        <span>=</span>
        <span class="resultado" id="cm-helper-resultado">$—</span>
      </div>
    </div>
  `;
}

function cmActualizarPrecio() {
  const costo = parseFloat(document.getElementById('cm-helper-costo')?.value) || 0;
  const margen = parseFloat(document.getElementById('cm-helper-margen')?.value) || 0;
  const res = document.getElementById('cm-helper-resultado');
  if (!res) return;
  if (costo > 0 && margen > 0 && margen < 100) {
    const precio = Math.round(costo / (1 - margen / 100));
    res.textContent = `$${precio.toLocaleString('es-CL')}`;
    const inp = document.getElementById('cm-precio-input');
    if (inp) { inp.value = precio; _cmNuevo.precio = precio; }
  } else {
    res.textContent = '$—';
  }
}
```

- [ ] **Step 2: Verificar en navegador**

1. Ir a Tab "Nuevo" en el sheet.
2. Completar nombre, categoría, marca.
3. Agregar variantes "Talla 38", "Talla 40" → aparecen como chips, no duplica.
4. Eliminar una variante → desaparece.
5. La sección "Stock y costo por variante" aparece con inputs de qty y costo por cada variante.
6. En el helper de precio: costo=45000 + margen=40 → resultado $75.000 y se completa automáticamente en el campo precio.

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: form nuevo producto — variantes, stock, precio con helper de margen"
```

---

## Task 6: Guardar producto nuevo en lote + Confirmar carga

**Files:**
- Modify: `index.html` — JS funciones `cmGuardarNuevo()`, `cmConfirmar()`

- [ ] **Step 1: Añadir función `cmGuardarNuevo()`**

Añade después de `cmActualizarPrecio()`:

```js
function cmGuardarNuevo() {
  const nombre = document.getElementById('cm-nuevo-nombre')?.value.trim();
  if (!nombre || nombre.length < 2) { toast('Escribe el nombre del producto (mín. 2 caracteres).', 'err'); return; }

  const catId = _cmNuevo.catId;
  const catNueva = _cmNuevo.catNuevaNombre;
  if (!catId && !catNueva) { toast('Selecciona o crea una categoría.', 'err'); return; }

  const marcaId = _cmNuevo.marcaId;
  const marcaNueva = _cmNuevo.marcaNuevaNombre;
  if (!marcaId && !marcaNueva) { toast('Selecciona o crea una marca.', 'err'); return; }

  if (_cmNuevo.variantes.length === 0) { toast('Agrega al menos una variante.', 'err'); return; }
  const sinCosto = _cmNuevo.variantes.some(v => v.qty < 1);
  if (sinCosto) { toast('Cada variante debe tener cantidad ≥ 1.', 'err'); return; }

  if (!_cmNuevo.precio || _cmNuevo.precio <= 0) { toast('Ingresa el precio de venta.', 'err'); return; }

  // Agregar cada variante como línea en el lote con _esNuevo=true
  _cmNuevo.variantes.forEach(v => {
    _cmLote.push({
      tipo: 'nuevo',
      varId: null, prodId: null,
      nombre,
      variante: v.talla_color,
      qty: v.qty,
      costo: v.costo,
      _esNuevo: true,
      _prod: {
        nombre,
        catId, catNuevaNombre: catNueva,
        marcaId, marcaNuevaNombre: marcaNueva,
        precio: _cmNuevo.precio,
      },
    });
  });

  cmCerrarSheet();
  cmRenderLote();
}
```

- [ ] **Step 2: Añadir función `cmConfirmar()`**

Añade después de `cmGuardarNuevo()`:

```js
async function cmConfirmar() {
  if (_cmLote.length === 0) return;
  const btn1 = document.getElementById('cm-confirm-top');
  const btn2 = document.getElementById('cm-confirm-bottom');
  if (btn1) { btn1.disabled = true; btn1.textContent = '…'; }
  if (btn2) { btn2.disabled = true; btn2.textContent = 'Guardando…'; }

  // Agrupar productos nuevos por nombre para crear solo un producto por nombre+cat+marca
  const productosCreadosMap = {}; // key: nombre → prodId creado

  let errores = 0;
  const localId = localFiltro() ?? _currentUser?.local_id ?? 1;

  for (const linea of _cmLote) {
    if (linea.tipo === 'existente') {
      // Update variante existente
      const skuItem = skuDB.find(s => s.id === linea.varId);
      const nuevoStock = (skuItem?.stock ?? 0) + linea.qty;
      const { error } = await sb.from('variantes')
        .update({ stock_actual: nuevoStock, costo_ultima_compra: linea.costo })
        .eq('id', linea.varId);
      if (error) { console.error('Error update variante', error); errores++; continue; }
      if (skuItem) { skuItem.stock = nuevoStock; skuItem.costo = linea.costo; }

    } else {
      // Producto nuevo: crear producto si no fue creado ya en este lote
      const p = linea._prod;
      const keyProd = cmNormalizar(p.nombre);
      let prodId = productosCreadosMap[keyProd];

      if (!prodId) {
        // Resolver categoría
        let catId = p.catId;
        if (!catId && p.catNuevaNombre) {
          const { data: newCat, error: eCat } = await sb.from('categorias')
            .insert({ nombre: p.catNuevaNombre, icono: '', activa: true })
            .select('id').single();
          if (eCat) { console.error('Error cat:', eCat); errores++; continue; }
          catId = newCat.id;
        }

        // Resolver marca
        let marcaId = p.marcaId;
        if (!marcaId && p.marcaNuevaNombre) {
          const { data: newMarca, error: eMarca } = await sb.from('marcas')
            .insert({ nombre: p.marcaNuevaNombre, activa: true })
            .select('id').single();
          if (eMarca) { console.error('Error marca:', eMarca); errores++; continue; }
          marcaId = newMarca.id;
        }

        // Crear producto
        const { data: newProd, error: eProd } = await sb.from('productos')
          .insert({ nombre: p.nombre, categoria_id: catId, marca_id: marcaId, precio_base: p.precio, activo: true })
          .select('id').single();
        if (eProd) { console.error('Error producto:', eProd); errores++; continue; }
        prodId = newProd.id;
        productosCreadosMap[keyProd] = prodId;
      }

      // Crear variante
      const { error: eVar } = await sb.from('variantes').insert({
        producto_id: prodId,
        talla_color: linea.variante,
        local_id: localId,
        stock_actual: linea.qty,
        stock_minimo: 0,
        costo_ultima_compra: linea.costo,
        activa: true,
      });
      if (eVar) { console.error('Error variante:', eVar); errores++; continue; }
    }
  }

  if (errores > 0) {
    toast(`${errores} error(es) al guardar. Revisa la consola.`, 'err');
  } else {
    const total = _cmLote.length;
    toast(`${total} producto${total !== 1 ? 's' : ''} ingresado${total !== 1 ? 's' : ''} al inventario`);
  }

  _cmLote = [];
  await cargarInventario();
  goTo('inventario');
}
```

- [ ] **Step 3: Verificar flujo completo con producto existente**

1. Ir a Carga masiva.
2. Agregar un producto existente (ej. con stock = 3).
3. Cambiar qty a 5 y costo a 20000.
4. Tocar "Confirmar carga →".
5. Debe mostrar toast "1 producto ingresado al inventario" y navegar a Inventario.
6. En Inventario ese producto debe tener stock = 3 + 5 = 8.
7. Verificar en Supabase que `costo_ultima_compra` se actualizó a 20000.

- [ ] **Step 4: Verificar flujo completo con producto nuevo**

1. Ir a Carga masiva → Agregar producto → Tab "Nuevo".
2. Completar: nombre "Polera Test", categoría existente, marca existente, variante "Talla M", qty=2, costo=5000, precio=12000.
3. Tocar "Agregar al lote →" → aparece en el lote con badge "Nuevo".
4. Tocar "Confirmar carga →".
5. Toast éxito → navegar a Inventario.
6. En Inventario debe aparecer "Polera Test" con variante "Talla M" y stock 2.
7. Verificar en Supabase que se crearon producto + variante correctamente.

- [ ] **Step 5: Verificar flujo con categoría/marca nueva**

1. Ir a Carga masiva → Tab "Nuevo".
2. Nombre "Gorro Test", + Nueva categoría "Gorras Test", + Nueva marca "Adidas Test", variante "Uni", qty=1, costo=3000, precio=8000.
3. Confirmar → en Supabase deben aparecer nueva categoría, nueva marca, nuevo producto, nueva variante.

- [ ] **Step 6: Commit final**

```bash
git add index.html
git commit -m "feat: confirmar carga masiva — update existentes + create nuevos con categoría/marca inline"
git push origin main
```

---

## Self-Review

**Spec coverage:**

| Requisito spec | Task |
|---|---|
| Pantalla con lote editable (qty/costo) | Task 1, 2 |
| Botón en Inventario | Task 2 |
| Sheet con tabs Existente / Nuevo | Task 3 |
| Búsqueda por nombre/SKU para existentes | Task 3 |
| No duplicar línea si ya está en el lote | Task 3 |
| Form nuevo: nombre, categoría, marca | Task 4 |
| Creación inline de categoría/marca | Task 4 |
| Fuzzy matching (Levenshtein ≤ 2) | Task 4 |
| Form nuevo: variantes con chips | Task 5 |
| Stock y costo por variante | Task 5 |
| Helper precio = costo / (1 - margen%) | Task 5 |
| `cmGuardarNuevo()` — validaciones | Task 6 |
| `cmConfirmar()` — update existentes | Task 6 |
| `cmConfirmar()` — insert productos nuevos | Task 6 |
| `cmConfirmar()` — insert variantes nuevas | Task 6 |
| Crear categoría/marca nueva en Supabase | Task 6 |
| Toast éxito + recarga + navega a Inventario | Task 6 |
| Solo Dueño puede acceder | Task 2 (`PANTALLAS_SOLO_DUENO`) |
| Local destino = local activo del usuario | Task 6 (`localId = localFiltro()`) |

**Placeholders:** Ninguno.

**Type consistency:** `_cmNuevo.variantes[i].talla_color` usado en Task 5 y 6 — consistente. `_cmLote[i].varId` usado en Task 3 y 6 — consistente. `_cmLote[i]._prod.catId` / `.catNuevaNombre` definido en Task 6 `cmGuardarNuevo()` y consumido en `cmConfirmar()` — consistente.
