# Sistema de Guía + Flujos de Acción Rápida — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar el bloque "Qué hacer ahora" (6 estados P0–P5), el strip quick-sell, la pantalla Nueva Venta simplificada, el bottom sheet de stock desde QHA, el flujo de crear producto con post-save accionable, y los empty states + hints contextuales.

**Architecture:** Todo vive en `index.html` (archivo único, ~8500 líneas). Las funciones nuevas se agregan en secciones lógicas del mismo archivo. Los datos se leen desde `skuDB` y `ventasDB` que ya están en memoria — no se hacen queries adicionales a Supabase para calcular el estado QHA. Las actualizaciones tras cada acción son optimistas: primero se actualiza la UI y luego confirma Supabase.

**Tech Stack:** HTML + CSS + JS puro, Supabase JS SDK v2, archivo único `index.html`

**Specs de referencia:**
- `docs/superpowers/specs/2026-04-26-sistema-guia-dashboard-design.md`
- `docs/superpowers/specs/2026-04-26-flujos-accion-rapida-design.md`

---

## Mapa de cambios en index.html

| Elemento | Tipo | Ubicación actual |
|----------|------|-----------------|
| `calcQHA()` | Nueva función | Agregar antes de `renderDashboard()` (~línea 3054) |
| `renderQHA(state)` | Nueva función | Agregar después de `calcQHA()` |
| Bloque acciones en `renderDashboard()` | Reemplazar | Líneas 3162–3312 |
| HTML quick-sell strip | Nuevo HTML | Entre `#dash-acciones-section` y `#dash-actividad-wrap` (~línea 1273) |
| `renderQuickSellStrip()` | Nueva función | Agregar después de `renderDashboard()` |
| `quickSell(varianteId)` | Nueva función | Agregar después de `renderQuickSellStrip()` |
| `toastConDeshacer(msg, fn, ms)` | Nueva función | Junto a `toast()` (~línea 5317) |
| `getVentasRecientes(limit)` | Nueva función | Junto a helpers de venta (~línea 5340) |
| `ventaRenderInventario()` | Modificar | Línea 5381 — agregar sección recientes |
| `ventaSelProduct()` | Modificar | Línea 5462 — sin-precio + sin-costo |
| `recalcVenta()` | Modificar | Línea 5627 — warning sobre-stock |
| `ventaConfirmar()` | Modificar | Línea 5712 — quitar hard block de stock |
| HTML screen-venta | Modificar | Líneas 1357–1361 — quitar steps indicator |
| `abrirAddStockQHA(varianteId)` | Nueva función | Junto a `invAbrirAddStock()` (~línea 5286) |
| `guardarAddStockQHA()` | Nueva función | Después de `abrirAddStockQHA()` |
| `qhaStockActualizar()` | Nueva función | Helper para estimación dinámica |
| `guardarQuickProd()` post-save | Modificar | Línea 2600 — pantalla post-creación |
| Empty states dashboard/stock/historial/analisis | Modificar | Dentro de cada renderX() |
| Hints contextuales | Agregar | Stock, Análisis, Nueva Venta |

---

## Task 1: calcQHA() + renderQHA() — Bloque "Qué hacer ahora"

**Files:**
- Modify: `index.html` — agregar dos funciones antes de `renderDashboard()` (~línea 3054) y reemplazar el bloque de acciones dentro de `renderDashboard()` (líneas 3162–3312)

- [ ] **Step 1: Agregar `calcQHA()` antes de `renderDashboard()`**

Insertar inmediatamente antes de `function renderDashboard()` (línea 3054):

```javascript
// ══════════════════════════════════════════════════════
//  BLOQUE "QUÉ HACER AHORA" — P0 a P5
// ══════════════════════════════════════════════════════
function calcQHA() {
  const hace30 = new Date();
  hace30.setDate(hace30.getDate() - 30);
  const hace30ISO = hace30.toISOString();
  const localId = localFiltro();

  const skus = localId ? skuDB.filter(s => s.local_id === localId) : skuDB;
  const v30 = ventasDB.filter(v =>
    !v.nombre.startsWith('↩️') &&
    v.fecha_raw && v.fecha_raw >= hace30ISO &&
    (!localId || v.local_id === localId)
  );
  const skuConVentas30d  = new Set(v30.map(v => v.sku));
  const skuConVentasEver = new Set(
    ventasDB.filter(v => !v.nombre.startsWith('↩️')).map(v => v.sku)
  );

  // ── P1: sin stock con ventas recientes ──
  const p1 = skus.filter(s => s.stock === 0 && skuConVentas30d.has(s.sku));
  if (p1.length > 0) {
    const mejor = p1.sort((a, b) => {
      const tA = Math.max(0, ...v30.filter(v => v.sku === a.sku).map(v => new Date(v.fecha_raw).getTime()));
      const tB = Math.max(0, ...v30.filter(v => v.sku === b.sku).map(v => new Date(v.fecha_raw).getTime()));
      return tB - tA;
    })[0];
    const vv = v30.filter(v => v.sku === mejor.sku);
    const tasa = vv.length / 4;
    const ganProm = vv.length > 0 ? vv.reduce((s, v) => s + v.gan / Math.max(1, v.cantidad), 0) / vv.length : 0;
    return {
      prioridad: 'P1',
      varianteId: mejor.id,
      nombre: mejor.nombre,
      talla_color: mejor.variante,
      perdida_estimada: ganProm > 0 ? Math.round((tasa * ganProm) / 1000) * 1000 : 0,
      cantidad_sugerida: Math.max(1, Math.ceil(tasa * 3)),
    };
  }

  // ── P2: stock bajo ──
  const p2 = skus.filter(s => s.stock > 0 && s.stock <= (s.stock_minimo || 2));
  if (p2.length > 0) {
    const mejor = p2.sort((a, b) => (a.stock / (a.stock_minimo || 2)) - (b.stock / (b.stock_minimo || 2)))[0];
    const vv = v30.filter(v => v.sku === mejor.sku);
    const tasaDia = vv.length / 30;
    const diasR = tasaDia > 0 ? Math.max(1, Math.floor(mejor.stock / tasaDia)) : null;
    const ganProm = vv.length > 0 ? vv.reduce((s, v) => s + v.gan / Math.max(1, v.cantidad), 0) / vv.length : 0;
    const tasa = vv.length / 4;
    const sugerida = Math.max(1, Math.ceil(tasa * 3) - mejor.stock);
    return {
      prioridad: 'P2',
      varianteId: mejor.id,
      nombre: mejor.nombre,
      talla_color: mejor.variante,
      stock_actual: mejor.stock,
      dias_restantes: diasR,
      perdida_estimada: ganProm > 0 ? Math.round((tasa * ganProm) / 1000) * 1000 : 0,
      cantidad_sugerida: sugerida,
      tasa_semanal: tasa,
    };
  }

  // ── P3: producto sin costo con ventas alguna vez ──
  const prodsSinCosto = [...new Set(
    skus.filter(s => (!s.costo || s.costo === 0) && skuConVentasEver.has(s.sku))
        .map(s => s.producto_id)
  )].filter(Boolean);
  if (prodsSinCosto.length > 0) return { prioridad: 'P3', count: prodsSinCosto.length };

  // ── P4: capital parado ──
  const p4 = skus.filter(s =>
    s.stock > 0 && s.costo > 0 &&
    !skuConVentas30d.has(s.sku) &&
    s.stock * s.costo >= 10000
  );
  if (p4.length > 0) {
    const totalCap = p4.reduce((sum, s) => sum + s.stock * s.costo, 0);
    const top = p4.sort((a, b) => (b.stock * b.costo) - (a.stock * a.costo))[0];
    const vTop = ventasDB.filter(v => v.sku === top.sku && v.fecha_raw);
    const ultFecha = vTop.length > 0 ? new Date(Math.max(...vTop.map(v => new Date(v.fecha_raw)))) : null;
    const dias = ultFecha ? Math.round((new Date() - ultFecha) / 86400000) : 999;
    return { prioridad: 'P4', nombre: top.nombre, capital_total: totalCap, dias_sin_venta: dias };
  }

  // ── P5: oportunidad de canal ──
  const porCanal = {};
  v30.forEach(v => {
    if (!porCanal[v.canal]) porCanal[v.canal] = { gan: 0, cnt: 0 };
    porCanal[v.canal].gan += v.gan;
    porCanal[v.canal].cnt++;
  });
  const canales = Object.entries(porCanal)
    .filter(([_, d]) => d.cnt >= 3)
    .map(([canal, d]) => ({ canal, prom: Math.round(d.gan / d.cnt) }))
    .sort((a, b) => b.prom - a.prom);

  if (canales.length >= 2 && (canales[0].prom - canales[1].prom) >= 1000) {
    return {
      prioridad: 'P5',
      canal_mejor: canales[0].canal,
      canal_segundo: canales[1].canal,
      diferencia: canales[0].prom - canales[1].prom,
    };
  }

  // ── P0: todo en orden ──
  return {
    prioridad: 'P0',
    canal_mejor: canales.length >= 2 ? canales[0].canal : null,
    canal_segundo: canales.length >= 2 ? canales[1].canal : null,
  };
}
```

- [ ] **Step 2: Agregar `renderQHA(state)` después de `calcQHA()`**

```javascript
function renderQHA(state) {
  const wrap    = document.getElementById('dash-acciones');
  const section = document.getElementById('dash-acciones-section');
  if (!wrap || !section) return;
  section.style.display = '';

  const { prioridad } = state;
  const talla = t => (t && t !== '—') ? ` ${t}` : '';
  const btnS  = (color, lbl, fn) =>
    `<button onclick="${fn}" style="display:inline-block;background:${color};color:${color==='var(--accent)'?'var(--text)':'#fff'};border:none;border-radius:9px;padding:9px 16px;font-size:12px;font-weight:700;cursor:pointer;font-family:'Archivo',sans-serif;">${lbl}</button>`;
  const lnkS  = (lbl, fn) =>
    `<span onclick="${fn}" style="font-size:12px;font-weight:700;color:var(--text);text-decoration:underline;text-underline-offset:2px;cursor:pointer;">${lbl}</span>`;
  const hdr   = (color) =>
    `<div style="font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:1px;color:${color};margin-bottom:6px;">Qué hacer ahora</div>`;
  const stat  = (val, color) =>
    `<div style="font-family:'Archivo Black',sans-serif;font-size:32px;color:${color};line-height:1;">${val}</div>`;
  const ctx   = (txt) =>
    `<div style="font-size:13px;font-weight:600;margin-top:2px;margin-bottom:6px;">${txt}</div>`;
  const sub   = (txt) =>
    `<div style="font-size:11px;color:var(--muted);margin-bottom:8px;">${txt}</div>`;
  const sug   = (color, txt) =>
    `<div style="font-size:11px;font-weight:700;color:${color};background:${color}1a;padding:7px 10px;border-radius:8px;margin-bottom:12px;">💡 ${txt}</div>`;

  if (prioridad === 'P1') {
    const nom = `${state.nombre}${talla(state.talla_color)}`;
    const perd = state.perdida_estimada > 0
      ? ` Sin stock, podrías perder ~$${fmt(state.perdida_estimada)} esta semana.` : '';
    wrap.innerHTML = `<div style="border-left:3px solid var(--red);padding:12px 0 12px 14px;">
      ${hdr('var(--red)')}${stat('Sin stock','var(--red)')}${ctx(`${nom} se agotó`)}
      ${sub(`Tenías ventas regulares.${perd}`)}
      ${sug('var(--red)',`Repone ${state.cantidad_sugerida} unidades para cubrir 2–3 semanas`)}
      ${btnS('var(--red)','Agregar stock ahora →',`abrirAddStockQHA(${state.varianteId})`)}
    </div>`;

  } else if (prioridad === 'P2') {
    const nom  = `${state.nombre}${talla(state.talla_color)}`;
    const dias = state.dias_restantes
      ? ` — se acaba en ${state.dias_restantes} día${state.dias_restantes!==1?'s':''}` : '';
    const perd = state.perdida_estimada > 0
      ? `Podrías perder ~$${fmt(state.perdida_estimada)} en ventas esta semana.` : '';
    wrap.innerHTML = `<div style="border-left:3px solid var(--orange);padding:12px 0 12px 14px;">
      ${hdr('var(--orange)')}${stat(`${state.stock_actual} unidades`,'var(--orange)')}${ctx(`${nom}${dias}`)}
      ${sub(perd)}
      ${sug('var(--orange)',`Repone ${state.cantidad_sugerida} unidades para cubrir 2–3 semanas`)}
      ${btnS('var(--orange)','Agregar stock ahora →',`abrirAddStockQHA(${state.varianteId})`)}
    </div>`;

  } else if (prioridad === 'P3') {
    wrap.innerHTML = `<div style="border-left:3px solid var(--orange);padding:12px 0 12px 14px;">
      ${hdr('var(--muted)')}${stat(`${state.count} productos`,'var(--text)')}${ctx('sin costo registrado')}
      ${sub('No sabes si estás ganando plata en esos productos. Agrega el costo y Cuanti calcula tu ganancia real.')}
      ${btnS('var(--accent)','Completar ahora →',"goTo('inventario')")}
    </div>`;

  } else if (prioridad === 'P4') {
    const diasStr = state.dias_sin_venta > 365 ? 'más de 1 año' : `${state.dias_sin_venta} días`;
    wrap.innerHTML = `<div style="border-left:3px solid var(--bd2);padding:12px 0 12px 14px;">
      ${hdr('var(--muted)')}${stat(`$${fmt(state.capital_total)} parados`,'var(--text)')}${ctx(`${state.nombre} — ${diasStr} sin venderse`)}
      ${sub('Estás dejando plata parada. Considera bajar el precio para moverlo.')}
      ${lnkS('Revisar precios →',"goTo('inventario')")}
    </div>`;

  } else if (prioridad === 'P5') {
    wrap.innerHTML = `<div style="border-left:3px solid var(--bd2);padding:12px 0 12px 14px;">
      ${hdr('var(--muted)')}${stat(`$${fmt(state.diferencia)} más`,'var(--text)')}${ctx(`por venta en ${state.canal_mejor} vs ${state.canal_segundo}`)}
      ${sub('Prioriza ese canal para ganar más sin vender más.')}
      ${lnkS('Ver análisis →',"goTo('analisis')")}
    </div>`;

  } else { // P0
    const micro = state.canal_mejor && state.canal_segundo
      ? `${state.canal_mejor} te deja más ganancia que ${state.canal_segundo}. Si priorizas ese canal, puedes ganar más sin vender más. <span onclick="goTo('analisis')" style="font-weight:700;text-decoration:underline;cursor:pointer;">Ver análisis →</span>`
      : 'Sigue registrando ventas — con más datos Cuanti puede decirte qué productos empujar y cuándo reponer.';
    wrap.innerHTML = `<div style="padding:12px 0;">
      ${hdr('var(--muted)')}${stat('Todo en orden 👌','var(--text)')}
      <div style="font-size:11px;color:var(--muted);margin-top:4px;">No hay nada urgente ahora.</div>
      <div style="font-size:11px;color:var(--muted);margin-top:8px;">${micro}</div>
    </div>`;
  }
}
```

- [ ] **Step 3: Reemplazar bloque acciones en `renderDashboard()`**

Dentro de `renderDashboard()`, encontrar el bloque completo desde:
```javascript
  // ── Acciones: urgencia diferenciada con CTA ──
  const accionesWrap    = document.getElementById('dash-acciones');
```
hasta el cierre:
```javascript
    }
  }
```
(incluye todo el bloque de items, sorting y render — aproximadamente líneas 3162 a 3312)

Reemplazar TODO ese bloque con:
```javascript
  // ── Bloque "Qué hacer ahora" ──
  renderQHA(calcQHA());
```

- [ ] **Step 4: Verificar manualmente en el browser**

Abrir la app. El dashboard debe mostrar el bloque "Qué hacer ahora" con:
- Si hay variante sin stock con ventas recientes → "Sin stock" en rojo con botón
- Si no → bajar por la cadena P2, P3, P4, P5, P0
- El bloque no tiene border-radius ni sombra — es solo un borde izquierdo de color

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: bloque QHA con calcQHA + renderQHA — P0 a P5 desde datos en memoria"
```

---

## Task 2: Nueva Venta — Jerarquía simplificada + validaciones

**Files:**
- Modify: `index.html` — HTML de screen-venta + funciones ventaSelProduct, recalcVenta, ventaConfirmar, ventaRenderInventario

- [ ] **Step 1: Quitar el indicador de pasos del HTML**

Localizar en `screen-venta` (línea ~1357):
```html
  <!-- indicador de pasos -->
  <div class="steps" id="venta-steps">
    <div class="sdot on" id="sd1">1</div><div class="sline" id="sl1"></div>
    <div class="sdot" id="sd2">2</div><div class="sline" id="sl2"></div>
    <div class="sdot" id="sd3">3</div>
  </div>
```
Eliminar ese bloque completo. El flujo sigue usando `ventaSetPaso()` pero sin el indicador visual.

- [ ] **Step 2: Agregar sección "Recientes" en vs1**

Dentro de `#vs1` (después del campo de búsqueda y antes de `#venta-inv-lista`), agregar:
```html
    <div id="venta-recientes-wrap" style="display:none;margin-bottom:14px;">
      <div style="font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:1px;color:var(--muted2);margin-bottom:8px;">Recientes</div>
      <div id="venta-recientes-lista"></div>
      <div style="height:1px;background:var(--bd);margin:12px 0 10px;"></div>
    </div>
```

- [ ] **Step 3: Agregar aviso sin-precio y sin-costo en vs2**

Dentro de `#vs2`, después del bloque de ganancia preview (`#v-gan-preview`), agregar:
```html
    <!-- Aviso sin precio -->
    <div id="v-sin-precio-aviso" style="display:none;background:rgba(216,75,75,.08);border:1px solid rgba(216,75,75,.2);border-radius:10px;padding:10px 12px;margin-bottom:12px;display:flex;align-items:center;justify-content:space-between;">
      <span style="font-size:12px;color:var(--red);font-weight:600;">Sin precio — no puedes registrar esta venta</span>
      <span onclick="goTo('inventario')" style="font-size:11px;font-weight:700;color:var(--red);text-decoration:underline;cursor:pointer;white-space:nowrap;margin-left:8px;">Agregar precio →</span>
    </div>
    <!-- Aviso sin costo -->
    <div id="v-sin-costo-aviso" style="display:none;background:rgba(228,106,46,.07);border:1px solid rgba(228,106,46,.2);border-radius:10px;padding:10px 12px;margin-bottom:12px;">
      <span style="font-size:12px;color:var(--orange);">Sin costo registrado — la ganancia puede no ser exacta</span>
    </div>
    <!-- Aviso sobre-stock -->
    <div id="v-sobre-stock-aviso" style="display:none;background:rgba(228,106,46,.07);border:1px solid rgba(228,106,46,.2);border-radius:10px;padding:10px 12px;margin-bottom:12px;">
      <span id="v-sobre-stock-txt" style="font-size:12px;color:var(--orange);"></span>
    </div>
```

- [ ] **Step 4: Agregar `getVentasRecientes(limit)` junto a los helpers de venta (~línea 5340)**

```javascript
function getVentasRecientes(limit = 5) {
  const seen = new Set();
  const res  = [];
  const lid  = localFiltro();
  for (const v of ventasDB) {
    if (res.length >= limit) break;
    if (v.nombre.startsWith('↩️') || seen.has(v.sku)) continue;
    const s = skuDB.find(sk => sk.sku === v.sku && (!lid || sk.local_id === lid));
    if (!s) continue;
    seen.add(v.sku);
    res.push(s);
  }
  return res;
}
```

- [ ] **Step 5: Actualizar `ventaRenderInventario()` para mostrar recientes**

Al inicio de `ventaRenderInventario(filter='')` (línea ~5381), después de obtener `lista` y `res`, agregar la renderización de recientes cuando no hay filtro:

```javascript
  // Recientes: solo cuando no hay filtro activo
  const recientesWrap = document.getElementById('venta-recientes-wrap');
  const recientesLista = document.getElementById('venta-recientes-lista');
  if (recientesWrap && recientesLista) {
    if (!q) {
      const recientes = getVentasRecientes(5);
      if (recientes.length > 0) {
        recientesWrap.style.display = '';
        recientesLista.innerHTML = recientes.map(s => {
          const noStock = s.stock <= 0;
          const sinPrecio = !s.precio || s.precio === 0;
          const enc = safeEncode(s);
          const sc = s.stock <= 1 ? 'var(--red)' : s.stock <= 3 ? 'var(--orange)' : 'var(--green)';
          return `<div class="vprod-item" onclick="ventaSelProductEncoded('${enc}')" style="opacity:${sinPrecio?'.5':'1'};">
            <div class="vprod-icon">${s.icon}</div>
            <div class="vprod-info">
              <div class="vprod-name">${s.nombre}</div>
              <div class="vprod-sub">${s.variante && s.variante!=='—' ? s.variante : ''}${noStock?' · <span style="color:var(--red)">Sin stock</span>':''}</div>
            </div>
            <div class="vprod-right">
              <div class="vprod-price">${s.precio?'$'+fmt(s.precio):'Sin precio'}</div>
              <div class="vprod-stock" style="color:${noStock?'var(--red)':sc};">${noStock?'Sin stock':s.stock+' ud.'}</div>
            </div>
          </div>`;
        }).join('');
      } else {
        recientesWrap.style.display = 'none';
      }
    } else {
      recientesWrap.style.display = 'none';
    }
  }
```

- [ ] **Step 6: Actualizar `ventaSelProduct()` — sin-precio, sin-costo, jerarquía**

En `ventaSelProduct(s)` (línea ~5462), después de asignar precio y cantidad, agregar:

```javascript
  // Sin precio: bloquear CTA
  const sinPrecio = !fresh.precio || fresh.precio === 0;
  const sinCosto  = !fresh.costo  || fresh.costo  === 0;

  const sinPrecioEl = document.getElementById('v-sin-precio-aviso');
  const sinCostoEl  = document.getElementById('v-sin-costo-aviso');
  const confirmarBtn = document.getElementById('venta-confirmar-btn');

  if (sinPrecioEl) sinPrecioEl.style.display = sinPrecio ? '' : 'none';
  if (sinCostoEl)  sinCostoEl.style.display  = sinCosto && !sinPrecio ? '' : 'none';
  if (confirmarBtn) {
    confirmarBtn.disabled = sinPrecio;
    confirmarBtn.style.opacity = sinPrecio ? '0.4' : '1';
    confirmarBtn.style.cursor  = sinPrecio ? 'not-allowed' : 'pointer';
  }
```

- [ ] **Step 7: Actualizar `recalcVenta()` — warning sobre-stock**

Al final de `recalcVenta()` (línea ~5627), después del cálculo de ganancia, agregar:

```javascript
  // Warning sobre-stock
  const sobreStockEl  = document.getElementById('v-sobre-stock-aviso');
  const sobreStockTxt = document.getElementById('v-sobre-stock-txt');
  if (sobreStockEl && ventaState.sku) {
    const liveStock = skuDB.find(i => i.sku === ventaState.sku.sku)?.stock ?? 0;
    const sobreStock = cant > liveStock && liveStock >= 0;
    sobreStockEl.style.display = sobreStock ? '' : 'none';
    if (sobreStockTxt && sobreStock) {
      sobreStockTxt.textContent = `Estás vendiendo más stock del que tienes registrado (${liveStock} ud. disponibles)`;
    }
  }
```

- [ ] **Step 8: Modificar `ventaConfirmar()` — quitar hard block de stock**

En `ventaConfirmar()` (línea ~5712), reemplazar:
```javascript
  const liveStock = liveItem ? liveItem.stock : 0;
  if(cant > liveStock) { toast(`Solo quedan ${liveStock} unidad${liveStock!==1?'es':''} disponibles.`,'err'); return; }
```
Con:
```javascript
  const liveStock = liveItem ? liveItem.stock : 0;
  // No bloquear — se permite vender aunque el stock sea menor (puede ser error de conteo)
  // El warning visual ya está visible en recalcVenta()
```

- [ ] **Step 9: Verificar manualmente**

1. Abrir Nueva Venta — debe mostrar sección "Recientes" con los últimos 5 productos vendidos
2. Seleccionar producto sin precio → CTA bloqueado (gris, cursor not-allowed), aviso rojo visible
3. Seleccionar producto sin costo → CTA habilitado, aviso naranja visible
4. Ingresar cantidad mayor al stock → aviso naranja "Estás vendiendo más stock del que tienes registrado"
5. Registrar venta con cantidad mayor al stock → debe funcionar sin error

- [ ] **Step 10: Commit**

```bash
git add index.html
git commit -m "feat: nueva venta — recientes, validación sin-precio/sin-costo, warning sobre-stock"
```

---

## Task 3: Quick-sell strip en dashboard + toastConDeshacer

**Files:**
- Modify: `index.html` — HTML del dashboard + nuevas funciones

- [ ] **Step 1: Agregar HTML del strip en el dashboard**

En `screen-dashboard`, entre el cierre de `#dash-acciones-section` y `#dash-actividad-wrap` (línea ~1273), agregar:

```html
  <!-- QUICK-SELL STRIP -->
  <div id="dash-qs-wrap" style="display:none;margin-bottom:24px;">
    <div class="sec-hdr" style="margin-bottom:10px;">
      <div class="sec-title">Vender rápido</div>
    </div>
    <div id="dash-qs-strip" style="display:flex;gap:8px;overflow-x:auto;-webkit-overflow-scrolling:touch;padding-bottom:4px;scrollbar-width:none;"></div>
  </div>
```

- [ ] **Step 2: Agregar `toastConDeshacer()` junto a `toast()` (~línea 5317)**

```javascript
function toastConDeshacer(msg, onDeshacer, duracion = 2500) {
  const prev = document.getElementById('_toast_undo');
  if (prev) prev.remove();

  const t = document.createElement('div');
  t.id = '_toast_undo';
  t.style.cssText = 'position:fixed;bottom:90px;left:50%;transform:translateX(-50%) translateY(20px);background:var(--sf);border:1px solid var(--bd2);border-radius:12px;padding:10px 14px;z-index:9999;opacity:0;transition:all .25s;max-width:340px;width:calc(100% - 32px);box-shadow:0 8px 24px rgba(0,0,0,.35);display:flex;align-items:center;gap:10px;';

  const msgEl = document.createElement('span');
  msgEl.style.cssText = 'flex:1;font-size:13px;font-weight:600;color:var(--text);';
  msgEl.textContent   = msg;

  const deshEl = document.createElement('span');
  deshEl.style.cssText = 'font-size:12px;font-weight:700;color:var(--blue);cursor:pointer;white-space:nowrap;flex-shrink:0;';
  deshEl.textContent   = 'Deshacer';

  const xEl = document.createElement('span');
  xEl.style.cssText = 'font-size:13px;color:var(--muted2);cursor:pointer;flex-shrink:0;line-height:1;';
  xEl.textContent   = '✕';

  t.appendChild(msgEl);
  t.appendChild(deshEl);
  t.appendChild(xEl);
  document.body.appendChild(t);

  requestAnimationFrame(() => { t.style.opacity='1'; t.style.transform='translateX(-50%) translateY(0)'; });

  const cerrar = () => { t.style.opacity='0'; t.style.transform='translateX(-50%) translateY(10px)'; setTimeout(()=>t.remove(), 280); };
  const timer  = setTimeout(cerrar, duracion);

  xEl.addEventListener('click',   () => { clearTimeout(timer); cerrar(); });
  deshEl.addEventListener('click', () => {
    clearTimeout(timer);
    cerrar();
    if (onDeshacer) onDeshacer();
  });
}
```

- [ ] **Step 3: Agregar `renderQuickSellStrip()` después de `renderDashboard()`**

```javascript
function renderQuickSellStrip() {
  const wrap  = document.getElementById('dash-qs-wrap');
  const strip = document.getElementById('dash-qs-strip');
  if (!wrap || !strip) return;

  const lid = localFiltro();
  const seen = new Set();
  const items = [];

  for (const v of ventasDB) {
    if (items.length >= 5) break;
    if (v.nombre.startsWith('↩️') || seen.has(v.sku)) continue;
    const s = skuDB.find(sk => sk.sku === v.sku && (!lid || sk.local_id === lid));
    if (!s || s.stock <= 0 || !s.precio || s.precio === 0) continue;
    seen.add(v.sku);
    items.push(s);
  }

  if (items.length === 0) { wrap.style.display = 'none'; return; }
  wrap.style.display = '';

  strip.innerHTML = items.map(s => {
    const varLabel = s.variante && s.variante !== '—' ? s.variante : '';
    const nom = s.nombre.length > 9 ? s.nombre.slice(0, 8) + '…' : s.nombre;
    return `<div id="qs-item-${s.id}" style="flex-shrink:0;width:82px;background:var(--sf);border:1px solid var(--bd);border-radius:14px;padding:10px 6px 8px;display:flex;flex-direction:column;align-items:center;gap:3px;transition:border-color .15s;" onmouseenter="this.style.borderColor='var(--bd2)'" onmouseleave="this.style.borderColor='var(--bd)'">
      <div style="width:36px;height:36px;background:var(--sf2);border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:700;color:var(--muted);">${s.icon}</div>
      <div style="font-size:10px;font-weight:600;text-align:center;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:70px;color:var(--text);">${nom}</div>
      ${varLabel?`<div style="font-size:9px;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:70px;">${varLabel}</div>`:''}
      <button id="qs-btn-${s.id}" onclick="quickSell(${s.id})" style="margin-top:2px;width:28px;height:28px;background:var(--accent);border:none;border-radius:50%;font-size:16px;font-weight:700;cursor:pointer;display:flex;align-items:center;justify-content:center;color:var(--text);line-height:1;">+</button>
    </div>`;
  }).join('');
}
```

- [ ] **Step 4: Agregar `quickSell(varianteId)` después de `renderQuickSellStrip()`**

```javascript
async function quickSell(varianteId) {
  const s = skuDB.find(sk => sk.id === varianteId);
  if (!s || !s.precio) { toast('Agrega un precio para vender rápido', 'warn'); return; }

  const btn = document.getElementById('qs-btn-' + varianteId);
  if (btn) { btn.innerHTML = '✓'; btn.style.background = 'var(--green)'; btn.disabled = true; }

  // Registrar en Supabase (el _ultimaVenta queda seteado para el Deshacer)
  const ventaId = await registrarVentaDB(varianteId, s.precio, s.costo || 0, 'Presencial', null, null, 1);

  if (!ventaId) {
    if (btn) { btn.innerHTML = '+'; btn.style.background = 'var(--accent)'; btn.disabled = false; }
    toast('Error al guardar. Intenta de nuevo.', 'err');
    return;
  }

  // Actualizar cache local
  const skuItem = skuDB.find(sk => sk.id === varianteId);
  if (skuItem) skuItem.stock = Math.max(0, skuItem.stock - 1);

  const com = calcComisionMonto(s.precio, 1, 'Presencial');
  const gan = s.precio - (s.costo || 0) - com;
  ventasDB.unshift({
    id: ventaId, venta_id: ventaId,
    sku: s.sku, nombre: s.nombre, variante: s.variante, icon: s.icon,
    cantidad: 1, precio: s.precio, costo: s.costo || 0, com, gan,
    canal: 'Presencial', pago: null, envio: null,
    fecha: `Hoy · ${nowHHMM()}`, fecha_raw: new Date().toISOString(),
    local_id: _currentUser?.local_id,
    _qs_nueva: true,
  });

  // Re-render componentes afectados
  renderQHA(calcQHA());
  renderQuickSellStrip();
  _renderDashActividad();
  _refreshDashMetrics();

  // Flash feedback: restaurar botón tras 1.5s
  setTimeout(() => {
    const b = document.getElementById('qs-btn-' + varianteId);
    if (b) { b.innerHTML = '+'; b.style.background = 'var(--accent)'; b.disabled = false; }
  }, 1500);

  // Toast con Deshacer — usa _ultimaVenta que ya quedó seteado por registrarVentaDB
  const nomCorto = `${s.nombre}${s.variante && s.variante !== '—' ? ' · ' + s.variante : ''}`;
  const ganStr   = gan >= 0 ? `+$${fmt(gan)}` : `−$${fmt(Math.abs(gan))}`;
  toastConDeshacer(`${nomCorto} × 1 — ${ganStr}`, async () => {
    await anularUltimaVenta();
    renderQHA(calcQHA());
    renderQuickSellStrip();
    _renderDashActividad();
    _refreshDashMetrics();
  });
}
```

- [ ] **Step 5: Llamar `renderQuickSellStrip()` desde `renderDashboard()`**

Al final de `renderDashboard()`, antes del cierre de la función (línea ~3569), agregar:

```javascript
  renderQuickSellStrip();
```

- [ ] **Step 6: Verificar manualmente**

1. El strip aparece debajo del bloque QHA con los últimos productos vendidos
2. Tocar "+" muestra flash verde (✓) por 1.5s, luego vuelve a "+"
3. Toast aparece arriba del strip con "Deshacer" — dura 2.5s y se puede cerrar con ✕
4. Tocar "Deshacer" revierte el stock y elimina la venta
5. Si el producto se agota, desaparece del strip en el siguiente render

- [ ] **Step 7: Commit**

```bash
git add index.html
git commit -m "feat: quick-sell strip en dashboard + toastConDeshacer con Deshacer"
```

---

## Task 4: Bottom sheet Agregar stock desde QHA

**Files:**
- Modify: `index.html` — agregar funciones cerca de `invAbrirAddStock()` (~línea 5286)

- [ ] **Step 1: Agregar `abrirAddStockQHA(varianteId)`**

Insertar después de `invCerrarSheet()` (línea ~5153):

```javascript
// ── Agregar stock rápido desde QHA ──
function abrirAddStockQHA(varianteId) {
  const s = skuDB.find(sk => sk.id === varianteId);
  if (!s) return;

  const hace30 = new Date(); hace30.setDate(hace30.getDate() - 30);
  const vv = ventasDB.filter(v => v.sku === s.sku && v.fecha_raw && new Date(v.fecha_raw) >= hace30);
  const tasa = vv.length / 4; // por semana

  const sugerida = tasa > 0
    ? Math.max(1, Math.ceil(tasa * 3) - s.stock)
    : 5;

  const varStr = s.variante && s.variante !== '—' ? ` · ${s.variante}` : '';

  // Guardar contexto para callbacks
  window._qhaStockCtx = { varianteId, stockActual: s.stock, tasa };

  document.getElementById('inv-sheet-body').innerHTML = `
    <div style="padding:4px 0 8px;">
      <div style="width:36px;height:4px;background:var(--bd2);border-radius:2px;margin:0 auto 20px;"></div>
      <div style="font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.8px;color:var(--muted);margin-bottom:4px;">Agregar stock</div>
      <div style="font-family:'Archivo',sans-serif;font-weight:700;font-size:17px;letter-spacing:-.3px;margin-bottom:2px;">${s.nombre}${varStr}</div>
      <div style="font-size:12px;color:var(--muted);margin-bottom:20px;">Stock actual: <strong style="color:var(--text);">${s.stock} unidades</strong></div>

      <div style="font-size:12px;font-weight:600;color:var(--muted);margin-bottom:8px;">Cantidad a agregar</div>
      <div style="display:flex;align-items:center;gap:0;border:1px solid var(--bd2);border-radius:12px;overflow:hidden;margin-bottom:10px;">
        <button onclick="window._qhaStockDec()" style="width:48px;height:48px;background:var(--sf2);border:none;font-size:20px;cursor:pointer;color:var(--text);flex-shrink:0;">−</button>
        <input id="qha-cant" type="number" inputmode="numeric" min="1" value="${sugerida}" oninput="window._qhaStockCalc()" style="flex:1;border:none;text-align:center;font-family:'Archivo Black',sans-serif;font-size:22px;color:var(--text);outline:none;padding:4px 0;background:var(--sf);">
        <button onclick="window._qhaStockInc()" style="width:48px;height:48px;background:var(--sf2);border:none;font-size:20px;cursor:pointer;color:var(--text);flex-shrink:0;">+</button>
      </div>
      <div id="qha-estimado" style="font-size:12px;color:var(--muted);margin-bottom:20px;min-height:18px;"></div>

      <button onclick="guardarAddStockQHA()" style="width:100%;background:var(--accent);border:none;border-radius:12px;padding:14px;font-family:'Archivo',sans-serif;font-weight:700;font-size:14px;color:var(--text);cursor:pointer;margin-bottom:10px;">Guardar</button>
      <div onclick="invCerrarSheet()" style="text-align:center;font-size:13px;color:var(--muted);cursor:pointer;padding:6px;">Cancelar</div>
    </div>`;

  // Helpers de incr/decr disponibles globalmente para los onclick inline
  window._qhaStockDec = () => {
    const el = document.getElementById('qha-cant');
    if (el) { el.value = Math.max(1, (parseInt(el.value) || 1) - 1); window._qhaStockCalc(); }
  };
  window._qhaStockInc = () => {
    const el = document.getElementById('qha-cant');
    if (el) { el.value = (parseInt(el.value) || 0) + 1; window._qhaStockCalc(); }
  };
  window._qhaStockCalc = () => {
    const ctx = window._qhaStockCtx;
    if (!ctx) return;
    const cant    = parseInt(document.getElementById('qha-cant')?.value) || 0;
    const el      = document.getElementById('qha-estimado');
    if (!el) return;
    if (ctx.tasa > 0) {
      const semanas = Math.floor((ctx.stockActual + cant) / ctx.tasa);
      el.textContent = semanas > 0 ? `Con esto te duran ~${semanas} semana${semanas!==1?'s':''}` : 'Cantidad muy baja para el ritmo de ventas';
    } else {
      el.textContent = `Quedarás con ${ctx.stockActual + cant} unidades`;
    }
  };

  // Calcular estimado inicial
  window._qhaStockCalc();
  invAbrirSheet();
}
```

- [ ] **Step 2: Agregar `guardarAddStockQHA()`**

```javascript
async function guardarAddStockQHA() {
  const ctx  = window._qhaStockCtx;
  if (!ctx) return;
  const cant = parseInt(document.getElementById('qha-cant')?.value) || 0;
  if (cant <= 0) { toast('Ingresa una cantidad mayor a 0', 'err'); return; }

  const btn = document.querySelector('#inv-sheet .btn, #inv-sheet button[onclick="guardarAddStockQHA()"]');

  // Operación mínima: actualizar stock_actual en Supabase
  const skuItem = skuDB.find(s => s.id === ctx.varianteId);
  const nuevoStock = (skuItem?.stock || 0) + cant;

  const { error: eStock } = await sb
    .from('variantes')
    .update({ stock_actual: nuevoStock })
    .eq('id', ctx.varianteId);

  if (eStock) { toast('Error al actualizar stock. Intenta de nuevo.', 'err'); return; }

  // Actualizar cache local
  if (skuItem) skuItem.stock = nuevoStock;

  // Crear registro de compra (best-effort, no bloquea si falla)
  sb.from('compras').insert({
    fecha: todayStr(),
    origen: 'reposicion_rapida',
    local_destino_id: _currentUser?.local_id || 1,
    usuario_id: _currentUser?.id || null,
    total_pagado_clp: null,
    notas: 'Reposición rápida desde QHA',
  }).select('id').single().then(({ data: compra }) => {
    if (compra?.id) {
      sb.from('detalle_compras').insert({
        compra_id: compra.id,
        variante_id: ctx.varianteId,
        cantidad: cant,
        costo_unitario: skuItem?.costo || null,
      });
    }
  });

  // Actualizar UI
  invCerrarSheet();
  renderQHA(calcQHA());
  renderQuickSellStrip();
  toast(`Stock actualizado — ${skuItem?.nombre || 'producto'} ahora tiene ${nuevoStock} unidades`, 'ok');
}
```

- [ ] **Step 3: Verificar manualmente**

1. Con un producto en P1 o P2 en el bloque QHA, tocar "Agregar stock ahora →"
2. El bottom sheet debe abrir con el nombre del producto, stock actual, cantidad sugerida pre-cargada
3. Los botones − y + deben ajustar la cantidad
4. El texto de estimación debe actualizarse al cambiar la cantidad (ej: "Con esto te duran ~3 semanas")
5. Tocar "Guardar" → sheet se cierra, el QHA re-evalúa y debe desaparecer P1/P2 si el stock ya superó el mínimo

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: bottom sheet agregar stock desde QHA con cantidad sugerida y estimación dinámica"
```

---

## Task 5: Crear producto — post-save con acciones siguientes

**Files:**
- Modify: `index.html` — `guardarQuickProd()` (línea ~2543) y HTML del qprod-sheet

- [ ] **Step 1: Quitar el campo stock inicial del formulario quick-prod**

En el HTML del `#qprod-sheet`, localizar el campo:
```html
<input id="qp-stock" ...>
```
o cualquier label/input que haga referencia a "stock inicial" o "stock". Eliminar ese campo y su label. El producto se crea con `stock_actual: 0`.

- [ ] **Step 2: Modificar `guardarQuickProd()` — post-save con acciones**

Reemplazar el bloque post-save (cerca de línea 2600):
```javascript
  await cargarInventario();
  cerrarQuickProd();
  const esPrimerProd = skuDB.length === 1;
  toast(esPrimerProd ? `¡${nombre} listo! Ahora registra tu primera venta` : `¡${nombre} creado!`, 'ok');
  renderDashboard();
  renderInventario();
```

Con:
```javascript
  await cargarInventario();
  const nuevaVariante = skuDB.find(s => s.producto_id === prod.id);
  const varianteId    = nuevaVariante?.id;

  // Mostrar pantalla post-creación dentro del sheet
  const sheetBody = document.getElementById('qprod-sheet-body') || document.querySelector('#qprod-sheet > div');
  if (sheetBody && varianteId) {
    sheetBody.innerHTML = `
      <div style="padding:24px 0 8px;text-align:center;">
        <div style="font-size:32px;margin-bottom:10px;">✓</div>
        <div style="font-family:'Archivo Black',sans-serif;font-size:19px;letter-spacing:-.3px;margin-bottom:6px;">${nombre}</div>
        <div style="font-size:12px;color:var(--muted);margin-bottom:28px;">Producto creado</div>
        <button onclick="cerrarQuickProd();goTo('venta');ventaSelProductById(${varianteId});"
          style="width:100%;background:var(--accent);border:none;border-radius:12px;padding:14px;font-family:'Archivo',sans-serif;font-weight:700;font-size:14px;color:var(--text);cursor:pointer;margin-bottom:10px;">
          Registrar venta
        </button>
        <button onclick="cerrarQuickProd();abrirAddStockQHA(${varianteId});"
          style="width:100%;background:var(--sf);border:1px solid var(--bd2);border-radius:12px;padding:13px;font-family:'Archivo',sans-serif;font-weight:700;font-size:13px;color:var(--text);cursor:pointer;margin-bottom:14px;">
          Agregar stock
        </button>
        <div onclick="cerrarQuickProd();goTo('inventario');" style="font-size:12px;color:var(--muted);cursor:pointer;text-decoration:underline;text-underline-offset:2px;">
          Ver en inventario
        </div>
      </div>`;
    if (btn) { btn.textContent = 'Crear producto →'; btn.disabled = false; }
  } else {
    cerrarQuickProd();
    toast(`${nombre} creado`, 'ok');
  }
  renderDashboard();
  renderInventario();
```

- [ ] **Step 3: Agregar `ventaSelProductById(varianteId)` junto a `ventaSelProduct()`**

```javascript
function ventaSelProductById(varianteId) {
  const s = skuDB.find(sk => sk.id === varianteId);
  if (s) ventaSelProduct(s);
}
```

- [ ] **Step 4: Verificar manualmente**

1. Abrir "Nuevo producto" desde el inventario
2. Ingresar nombre y precio (sin costo) → pantalla post-save debe mostrar "✓ + nombre + Producto creado"
3. Botones: "Registrar venta" → abre Nueva Venta con ese producto pre-seleccionado, "Agregar stock" → abre bottom sheet, "Ver en inventario" → navega al inventario
4. Crear producto sin precio → botón "Crear" deshabilitado con mensaje

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: crear producto — post-save con acciones Registrar venta / Agregar stock"
```

---

## Task 6: _refreshDashMetrics() + _renderDashActividad()

**Files:**
- Modify: `index.html` — extraer helpers livianos de `renderDashboard()` para actualización parcial

- [ ] **Step 1: Agregar `_refreshDashMetrics()` después de `renderDashboard()`**

```javascript
// Actualizar solo las métricas numéricas del dashboard (sin re-renderizar todo)
function _refreshDashMetrics() {
  const hoy       = new Date();
  const ventasMes = ventasDB.filter(v => esVentaMes(v) && !v.nombre.startsWith('↩️'));
  const ganMes    = ventasMes.reduce((s, v) => s + v.gan, 0);
  const gastosMes = calcGastosMes();
  const gananciaR = ganMes - gastosMes;

  const heroEl = document.getElementById('dash-hero-gan');
  if (heroEl) {
    heroEl.textContent = (gananciaR < 0 ? '−' : '') + '$' + fmt(Math.abs(gananciaR));
    heroEl.style.color = gananciaR < 0 ? 'var(--red)' : 'var(--text)';
  }

  const gastosSubEl = document.getElementById('dash-hero-gastos-sub');
  if (gastosSubEl) {
    if (gastosMes > 0) {
      gastosSubEl.style.display = '';
      gastosSubEl.textContent   = `Ventas $${fmt(ganMes)} — Gastos $${fmt(gastosMes)}`;
    } else {
      gastosSubEl.style.display = 'none';
    }
  }
}
```

- [ ] **Step 2: Agregar `_renderDashActividad()` después de `_refreshDashMetrics()`**

```javascript
// Re-renderizar solo la sección "Últimas ventas" del dashboard
function _renderDashActividad(markNewFirst = false) {
  const wrap = document.getElementById('dash-last-sales');
  if (!wrap) return;

  const ventasReales = ventasDB.filter(v => !v.nombre.startsWith('↩️'));
  if (ventasReales.length === 0) return;

  const ultimas = ventasReales.slice(0, 8);
  const grupos  = {};
  const orden   = [];
  ultimas.forEach(v => {
    const dia = v.fecha.split(' · ')[0];
    if (!grupos[dia]) { grupos[dia] = { items: [], gan: 0 }; orden.push(dia); }
    grupos[dia].items.push(v);
    grupos[dia].gan += v.gan;
  });

  wrap.innerHTML = orden.map(dia => {
    const g = grupos[dia];
    const esCurr = dia === 'Hoy';
    return `
      <div style="display:flex;align-items:center;justify-content:space-between;margin:10px 0 6px;">
        <div style="font-family:'DM Mono',monospace;font-size:9px;letter-spacing:1.5px;text-transform:uppercase;color:${esCurr?'var(--text)':'var(--muted)'};">${dia}</div>
        <div style="font-family:'DM Mono',monospace;font-size:10px;color:${g.gan>=0?'var(--green)':'var(--red)'};font-weight:600;">${g.gan>=0?'+':'−'}$${fmt(Math.abs(g.gan))}</div>
      </div>
      ${g.items.map((v, idx) => {
        const isNew = markNewFirst && dia === 'Hoy' && idx === 0 && v._qs_nueva;
        return `<div style="display:flex;align-items:center;gap:10px;padding:10px 2px;border-bottom:1px solid var(--bd);cursor:pointer;" onclick="goTo('historial')">
          <div style="width:32px;height:32px;background:var(--sf2);border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:13px;font-weight:700;color:var(--muted);flex-shrink:0;">${v.icon}</div>
          <div style="flex:1;min-width:0;">
            <div style="font-size:12px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${v.nombre}${isNew?'<span style="margin-left:6px;font-size:9px;font-weight:700;background:var(--accent);color:var(--text);padding:2px 6px;border-radius:4px;letter-spacing:.3px;">nueva</span>':''}</div>
            <div style="font-size:10px;color:var(--muted);">${v.fecha.split(' · ').slice(1).join(' · ')} · ${v.canal||'—'}</div>
          </div>
          <div style="text-align:right;flex-shrink:0;">
            <div style="font-size:11px;color:${v.gan>=0?'var(--green)':'var(--red)'};font-family:'DM Mono',monospace;font-weight:600;">${v.gan>=0?'+':'−'}$${fmt(Math.abs(v.gan))}</div>
            <div style="font-size:10px;color:var(--muted);font-family:'DM Mono',monospace;">$${fmt(v.precio)}</div>
          </div>
        </div>`;
      }).join('')}`;
  }).join('') + `<div style="padding:12px 0;text-align:center;"><span style="font-size:11px;color:var(--muted);cursor:pointer;" onclick="goTo('historial')">Ver todas las ventas →</span></div>`;
}
```

- [ ] **Step 3: Verificar que quick-sell y nueva-venta usan estas funciones**

Confirmar que:
- `quickSell()` llama `_renderDashActividad(true)` y `_refreshDashMetrics()`
- `ventaConfirmar()` al final también llama `renderQHA(calcQHA())` (además del `renderDashboard()` que ya tiene)

Actualizar el final de `ventaConfirmar()` (línea ~5884):
```javascript
  ventaSetPaso(3);
  renderHistorial();
  renderDashboard(); // esto ya actualiza todo el dashboard incluyendo QHA
  updateInventarioStock();
```
El `renderDashboard()` ya llama `renderQHA(calcQHA())` internamente después de Task 1, así que no hay cambio requerido aquí.

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "refactor: _refreshDashMetrics + _renderDashActividad para actualizaciones parciales"
```

---

## Task 7: Empty states + hints contextuales

**Files:**
- Modify: `index.html` — dentro de `renderDashboard()`, `renderInventario()`, `renderHistorial()`, `renderAnalisis()`

- [ ] **Step 1: Empty state dashboard — cuando no hay productos ni ventas**

En `renderDashboard()`, en el bloque que renderiza `#dash-last-sales` (línea ~3318), el bloque cuando `ventasReales.length === 0 && !skuDB.length` ya existe. Verificar que diga exactamente:

```javascript
    if (ventasReales.length === 0) {
      wrap.innerHTML = skuDB.length > 0
        ? `<div style="padding:12px 0 16px;text-align:center;">
            <div style="font-size:12px;color:var(--muted);line-height:1.6;">Aún no hay ventas registradas. Cuando hagas tu primera, aparece acá.</div>
           </div>`
        : `<div style="padding:28px 0 16px;text-align:center;">
            <div style="font-size:32px;margin-bottom:10px;">👋</div>
            <div style="font-family:'Archivo',sans-serif;font-weight:700;font-size:17px;margin-bottom:8px;letter-spacing:-.3px;">¡Bienvenido a Cuanti!</div>
            <div style="font-size:12px;color:var(--muted);margin-bottom:18px;line-height:1.7;max-width:260px;margin-inline:auto;">Para empezar, agrega tu primer producto y registra una venta. Cuanti hará el resto.</div>
            <button class="btn" style="width:auto;padding:13px 28px;font-size:13px;margin:0;" onclick="abrirQuickProdSheet()">Agregar producto →</button>
           </div>`;
```

Si el texto actual es diferente, actualizarlo al texto del spec.

- [ ] **Step 2: Empty state Stock — sin productos**

En `renderInventario()` (línea ~4339), localizar el bloque que renderiza cuando `items.length === 0` y no hay query. Reemplazar con:

```javascript
    contenido = `<div style="padding:44px 16px 24px;text-align:center;">
      <div style="font-size:44px;margin-bottom:14px;">📦</div>
      <div style="font-family:'Archivo',sans-serif;font-weight:700;font-size:17px;margin-bottom:8px;letter-spacing:-.3px;">Todavía no tienes productos</div>
      <div style="font-size:12px;color:var(--muted);margin-bottom:22px;line-height:1.7;max-width:260px;margin-inline:auto;">Agrega los productos que vendes con su precio y costo. Así Cuanti puede calcular cuánto ganas.</div>
      <button class="btn" style="width:auto;padding:13px 28px;font-size:13px;margin:0;" onclick="abrirQuickProdSheet()">Nuevo producto →</button>
    </div>`;
```

- [ ] **Step 3: Empty state Historial — sin ventas**

En `renderHistorial()` (línea ~3572), localizar el bloque cuando no hay ventas. Reemplazar con:

```javascript
    wrap.innerHTML = `<div style="padding:48px 16px 24px;text-align:center;">
      <div style="font-size:44px;margin-bottom:14px;">🧾</div>
      <div style="font-family:'Archivo',sans-serif;font-weight:700;font-size:17px;margin-bottom:8px;letter-spacing:-.3px;">Todavía no hay ventas</div>
      <div style="font-size:12px;color:var(--muted);margin-bottom:22px;line-height:1.7;max-width:260px;margin-inline:auto;">Cuando registres una venta, aparecerá aquí con su ganancia calculada.</div>
      <button class="btn" style="width:auto;padding:13px 28px;font-size:13px;margin:0;" onclick="goTo('venta')">Registrar venta →</button>
    </div>`;
```

- [ ] **Step 4: Empty state Análisis — sin ventas**

En `renderAnalisis()` (línea ~1632 y función JS), localizar el bloque de análisis vacío. Agregar o reemplazar con:

```javascript
  if (ventasDB.filter(v => !v.nombre.startsWith('↩️')).length === 0) {
    // render empty state
    const body = document.getElementById('analisis-body') || document.querySelector('#screen-analisis .tab-body');
    if (body) body.innerHTML = `<div style="padding:56px 16px 24px;text-align:center;">
      <div style="font-size:44px;margin-bottom:14px;">📊</div>
      <div style="font-family:'Archivo',sans-serif;font-weight:700;font-size:17px;margin-bottom:8px;letter-spacing:-.3px;">Aún no hay suficiente información</div>
      <div style="font-size:12px;color:var(--muted);margin-bottom:22px;line-height:1.7;max-width:260px;margin-inline:auto;">El análisis aparece cuando tienes ventas registradas. Registra la primera para ver cómo va tu negocio.</div>
      <button class="btn" style="width:auto;padding:13px 28px;font-size:13px;margin:0;" onclick="goTo('venta')">Registrar venta →</button>
    </div>`;
    return;
  }
```

- [ ] **Step 5: Hint Stock — productos sin costo**

En `renderInventario()`, al inicio de la función (o al final antes del return), agregar:

```javascript
  // Hint: productos sin costo
  const hintStockEl = document.getElementById('inv-hint-costo');
  if (!hintStockEl) {
    // Crear elemento hint si no existe
    const hintDiv = document.createElement('div');
    hintDiv.id = 'inv-hint-costo';
    hintDiv.style.cssText = 'display:none;background:rgba(228,106,46,.07);border:1px solid rgba(228,106,46,.2);border-radius:10px;padding:10px 12px;margin-bottom:12px;font-size:12px;color:var(--orange);';
    const screen = document.getElementById('screen-inventario');
    const firstChild = screen?.querySelector('.search-row') || screen?.firstElementChild;
    if (firstChild) screen.insertBefore(hintDiv, firstChild);
  }
  const hintEl = document.getElementById('inv-hint-costo');
  if (hintEl) {
    const sinCostoCount = skuDB.filter(s => (!s.costo || s.costo === 0)).length;
    if (sinCostoCount > 0) {
      hintEl.style.display = '';
      hintEl.textContent   = `💡 ${sinCostoCount} producto${sinCostoCount!==1?'s':''} no tienen costo registrado. Sin eso, la ganancia puede estar inflada.`;
    } else {
      hintEl.style.display = 'none';
    }
  }
```

- [ ] **Step 6: Hint Análisis — pocos datos**

En `renderAnalisis()`, al inicio (después del early return de empty state), agregar:

```javascript
  // Hint: pocos datos
  const totalVentas = ventasDB.filter(v => !v.nombre.startsWith('↩️')).length;
  const primeraVenta = ventasDB.filter(v => v.fecha_raw && !v.nombre.startsWith('↩️'))
    .reduce((m, v) => v.fecha_raw < m ? v.fecha_raw : m, new Date().toISOString());
  const diasDesde = Math.round((new Date() - new Date(primeraVenta)) / 86400000);
  const pocosData = totalVentas < 10 || diasDesde < 14;

  const hintAnalisisEl = document.getElementById('analisis-hint-datos');
  if (hintAnalisisEl) {
    hintAnalisisEl.style.display = pocosData ? '' : 'none';
    if (pocosData) hintAnalisisEl.textContent = '📈 Con más ventas, aquí vas a ver cuáles productos te dejan más ganancia y cuáles conviene dejar de vender.';
  }
```

Agregar el elemento en el HTML de `#screen-analisis`, antes del contenido principal:
```html
<div id="analisis-hint-datos" style="display:none;background:rgba(37,99,235,.06);border:1px solid rgba(37,99,235,.2);border-radius:10px;padding:10px 12px;margin-bottom:12px;font-size:12px;color:var(--blue);"></div>
```

- [ ] **Step 7: Hint Nueva Venta — primer uso**

En `ventaRenderInventario()`, cuando no hay filtro y `ventasDB` está vacío, mostrar un hint encima de la lista:

```javascript
  // Hint primera vez
  const hintNvEl = document.getElementById('venta-hint-primero');
  if (hintNvEl) {
    const sinVentas = ventasDB.filter(v => !v.nombre.startsWith('↩️')).length === 0;
    hintNvEl.style.display = (!q && sinVentas) ? '' : 'none';
  }
```

Agregar en el HTML de `#vs1`, antes de `#venta-recientes-wrap`:
```html
    <div id="venta-hint-primero" style="display:none;background:rgba(37,99,235,.06);border:1px solid rgba(37,99,235,.2);border-radius:10px;padding:10px 12px;margin-bottom:12px;font-size:12px;color:var(--blue);">
      👆 Busca el producto por nombre o escanea el código de barras. Canal y método de pago son opcionales.
    </div>
```

- [ ] **Step 8: Verificar manualmente**

1. Crear un usuario sin productos: dashboard debe mostrar "👋 ¡Bienvenido a Cuanti!"
2. Inventario sin productos: debe mostrar "📦 Todavía no tienes productos"
3. Historial sin ventas: "🧾 Todavía no hay ventas"
4. Análisis sin ventas: "📊 Aún no hay suficiente información"
5. Inventario con producto sin costo: hint naranja visible
6. Análisis con < 10 ventas: hint azul visible
7. Primera venta: hint azul en Nueva Venta visible

- [ ] **Step 9: Commit**

```bash
git add index.html
git commit -m "feat: empty states (4 pantallas) + hints contextuales (stock, análisis, nueva venta)"
```

---

## Checklist de spec coverage

Verificar que cada requisito de los specs tiene una tarea que lo implementa:

| Requisito | Tarea |
|-----------|-------|
| P1 sin stock con ventas recientes | Task 1 |
| P2 stock bajo con días restantes | Task 1 |
| P3 sin costo con ventas ever | Task 1 |
| P4 capital parado ≥ $10.000 | Task 1 |
| P5 diferencia de canal ≥ $1.000 | Task 1 |
| P0 con micro-acción de canal | Task 1 |
| Solo 1 estado visible | Task 1 (`calcQHA` retorna 1) |
| CTA sólido P1-P3, link P4-P5 | Task 1 (`btnS` vs `lnkS`) |
| Sin border-radius en contenedor QHA | Task 1 (solo `border-left`) |
| P0 durante carga inicial (placeholder) | Task 1 (renderQHA llamado al inicio con P0) |
| Recientes en Nueva Venta | Task 2 |
| Sin precio → bloquear CTA | Task 2 |
| Sin costo → aviso, no bloquear | Task 2 |
| Cantidad > stock → aviso naranja, no bloquear | Task 2 |
| Quick-sell strip 4-5 variantes | Task 3 |
| Flash ✓ verde 1.5s | Task 3 |
| Toast no bloqueante 2.5s con Deshacer + X | Task 3 |
| Deshacer revierte venta y stock | Task 3 (usa `anularUltimaVenta()`) |
| Strip filtra por precio > 0 y stock > 0 | Task 3 (`renderQuickSellStrip`) |
| Strip muestra variantes, no solo productos | Task 3 (itera sobre skuDB, no agrupado) |
| Bottom sheet stock con variante pre-seleccionada | Task 4 |
| Cantidad sugerida editable | Task 4 |
| Texto estimado dinámico | Task 4 (`_qhaStockCalc`) |
| Solo actualiza stock_actual (mínimo obligatorio) | Task 4 (`guardarAddStockQHA`) |
| Compra registrada best-effort | Task 4 |
| Post-crear producto: Registrar venta + Agregar stock | Task 5 |
| 3 campos visibles + variantes colapsadas | Task 5 (verificar en HTML del sheet) |
| Actualización inmediata dashboard tras acciones | Task 6 |
| Empty state dashboard | Task 7 |
| Empty state stock | Task 7 |
| Empty state historial | Task 7 |
| Empty state análisis | Task 7 |
| Hint stock productos sin costo | Task 7 |
| Hint análisis pocos datos | Task 7 |
| Hint nueva venta primer uso | Task 7 |
| Insights (P5) solo con ventas con costo confirmado | Task 1 (calcQHA usa `v.gan` que es 0 si sin costo) |

---

## Notas de implementación

**Sobre `ventasDB.gan` y ganancia "sin confirmar":**  
`cargarVentas()` calcula `gan = (precio_unitario - costo_unitario) * cantidad - com`. Si `costo_unitario` es null, el resultado incluye el precio completo como ganancia. Esto afecta P5 y los insights. Para la versión actual, esto es aceptable — el sistema usa los datos disponibles. El badge "sin confirmar" en la ganancia del mes es una mejora futura.

**Sobre `localFiltro()`:**  
Ya existe en el código (~línea 3008). Retorna `null` para el Dueño (ve todos los locales) y el `local_id` para vendedores.

**Sobre el ID de `qprod-sheet-body`:**  
El sheet de quick-prod puede no tener un `id` en el body interno. Verificar en el HTML y agregar `id="qprod-sheet-body"` si es necesario.

**Sobre `todayStr()`:**  
Ya existe en el código (línea 3332). Retorna la fecha en formato `YYYY-MM-DD`.
