# Descuentos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agregar la posibilidad de aplicar descuentos (% o monto fijo) al registrar una venta, con límite configurable por el dueño para los vendedores.

**Architecture:** Todo el trabajo es sobre `index.html` (archivo único) más una migración SQL en Supabase. El descuento se almacena en `detalle_ventas` como `descuento_tipo` y `descuento_valor`. El `precio_unitario` guardado es siempre el precio final ya con descuento, por lo que toda la lógica de ganancia existente no cambia.

**Tech Stack:** HTML/CSS/JS vanilla, Supabase (PostgreSQL). No hay framework de tests — la verificación es manual en el navegador.

---

## Archivos a modificar

- `index.html` — único archivo de la app
  - `cargarVentas()` (línea 72): agregar campos de descuento al SELECT y al objeto mapeado
  - `registrarVentaDB()` (línea 126): recibir y guardar `descuentoTipo` y `descuentoValor`
  - Pantalla Config HTML (línea 1297–1304): agregar sección "Ventas" con input de límite
  - Paso 2 HTML (línea 978–1017): agregar bloque toggle de descuento
  - `recalcVenta()` (línea 2852): leer campos de descuento y recalcular
  - `ventaConfirmar()` (línea 2871): leer descuento, validar límite, pasar a registrarVentaDB y actualizar Paso 3
  - `renderHistorial()` — función filas (línea 2331): mostrar línea de descuento si aplica

---

## Task 1: Migración de base de datos

**Archivos:**
- No hay archivo — ejecutar SQL en el panel de Supabase (https://supabase.com → SQL Editor)

- [ ] **Step 1: Ejecutar la migración en Supabase SQL Editor**

```sql
ALTER TABLE detalle_ventas
  ADD COLUMN IF NOT EXISTS descuento_tipo text
    CHECK (descuento_tipo IN ('porcentaje', 'monto')),
  ADD COLUMN IF NOT EXISTS descuento_valor numeric DEFAULT 0;
```

- [ ] **Step 2: Verificar que las columnas existen**

En el SQL Editor de Supabase, ejecutar:
```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'detalle_ventas'
  AND column_name IN ('descuento_tipo', 'descuento_valor');
```
Resultado esperado: 2 filas, una con `text` y otra con `numeric`.

- [ ] **Step 3: Commit**

```bash
git commit --allow-empty -m "db: agregar descuento_tipo y descuento_valor a detalle_ventas"
```

---

## Task 2: Cargar descuento desde la BD al cache local

**Archivos:**
- Modify: `index.html:72-122` (función `cargarVentas`)

- [ ] **Step 1: Agregar `descuento_tipo` y `descuento_valor` al SELECT**

Localizar la línea 75 donde está el `.select(...)`. Cambiar:

```javascript
      id, cantidad, precio_unitario, costo_unitario,
```
por:
```javascript
      id, cantidad, precio_unitario, costo_unitario, descuento_tipo, descuento_valor,
```

- [ ] **Step 2: Agregar los campos al objeto mapeado**

En el `return { ... }` dentro del `.map(d => { ... })` (línea ~106), agregar después de `fecha_raw`:

```javascript
      descuento_tipo:  d.descuento_tipo  || null,
      descuento_valor: d.descuento_valor || 0,
```

- [ ] **Step 3: Verificar en consola del navegador**

Abrir la app, abrir DevTools → Console, escribir `ventasDB[0]` y verificar que el objeto tiene las propiedades `descuento_tipo` y `descuento_valor`.

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat: cargar descuento_tipo y descuento_valor desde BD"
```

---

## Task 3: Configuración — sección "Ventas" con límite de descuento

**Archivos:**
- Modify: `index.html:1297-1304` (pantalla Config, después de la sección "Preferencias")

El dueño puede fijar un porcentaje máximo de descuento para vendedores. Se guarda en `localStorage` bajo la clave `cuanti_descuento_max_pct`. El dueño no tiene límite.

- [ ] **Step 1: Agregar helper functions para leer y guardar el límite**

Buscar el bloque de funciones de Config (cerca de la función `renderEquipo`, línea ~1772). Agregar estas dos funciones antes de `renderEquipo`:

```javascript
function getDescuentoMaxPct() {
  return parseInt(localStorage.getItem('cuanti_descuento_max_pct') || '0', 10);
}
function setDescuentoMaxPct(val) {
  const n = Math.min(100, Math.max(0, parseInt(val) || 0));
  localStorage.setItem('cuanti_descuento_max_pct', String(n));
}
```

- [ ] **Step 2: Agregar sección "Ventas" en el HTML de Config**

Localizar la línea 1297 (`<div class="divider"></div>` antes de la sección "Preferencias") y agregar el siguiente bloque ANTES de ese divider:

```html
  <div class="divider"></div>
  <div class="sec-hdr" id="ventas-config-section" style="display:none;"><div class="sec-title">Ventas</div></div>
  <div class="card" id="ventas-config-card" style="display:none;">
    <div class="tgl-row" style="border-bottom:none;">
      <div>
        <div class="tgl-lbl">Descuento máximo para vendedores</div>
        <div class="tgl-sub">Los vendedores no pueden superar este porcentaje</div>
      </div>
      <div style="display:flex;align-items:center;gap:4px;">
        <input id="descuento-max-input" type="number" min="0" max="100" value="0"
          style="width:52px;text-align:center;font-family:'DM Mono',monospace;font-size:14px;font-weight:600;border:1px solid var(--bd);border-radius:8px;padding:6px 4px;background:var(--sf2);"
          oninput="setDescuentoMaxPct(this.value)">
        <span style="font-size:13px;color:var(--muted);">%</span>
      </div>
    </div>
  </div>
```

- [ ] **Step 3: Mostrar la sección solo para el Dueño y cargar el valor guardado**

Localizar la función `renderEquipo` (línea ~1772). Al final de esa función, antes del cierre `}`, agregar:

```javascript
  // Mostrar sección Ventas solo para el dueño
  const esVentas = _currentUser?.rol === 'Dueño';
  const ventasSection = document.getElementById('ventas-config-section');
  const ventasCard    = document.getElementById('ventas-config-card');
  if (ventasSection) ventasSection.style.display = esVentas ? '' : 'none';
  if (ventasCard)    ventasCard.style.display    = esVentas ? '' : 'none';
  const inputMax = document.getElementById('descuento-max-input');
  if (inputMax) inputMax.value = getDescuentoMaxPct();
```

- [ ] **Step 4: Verificar en el navegador**

1. Iniciar sesión como Dueño → ir a Configuración → debe aparecer sección "Ventas" con el input de porcentaje.
2. Cambiar el valor a `20` → recargar la página → el input debe mostrar `20`.
3. Iniciar sesión como Vendedor → ir a Configuración → la sección "Ventas" no debe aparecer.

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: sección Ventas en Config con límite de descuento para vendedores"
```

---

## Task 4: UI Paso 2 — toggle de descuento

**Archivos:**
- Modify: `index.html:978-1017` (bloque Paso 2 de la pantalla venta)

- [ ] **Step 1: Agregar el bloque HTML del toggle**

Localizar el bloque del "precio y cantidad" en el Paso 2 (línea 978–987). Después del cierre de ese bloque `</div>` (línea 987), insertar el siguiente bloque ANTES del bloque "canal":

```html
    <!-- descuento (toggle opcional) -->
    <div style="margin-bottom:18px;">
      <div id="v-desc-toggle" onclick="ventaToggleDescuento()"
        style="display:flex;align-items:center;justify-content:space-between;padding:10px 12px;background:var(--sf2);border:1px dashed var(--bd2);border-radius:10px;cursor:pointer;">
        <span style="font-size:12px;color:var(--muted);">Aplicar descuento</span>
        <span id="v-desc-toggle-icon" style="font-size:18px;color:var(--accent);font-weight:700;line-height:1;">＋</span>
      </div>
      <div id="v-desc-panel" style="display:none;margin-top:8px;">
        <div style="display:flex;gap:8px;align-items:flex-end;">
          <div class="field" style="flex:1;margin-bottom:0;">
            <label>Descuento</label>
            <input id="v-desc-valor" type="number" min="0" placeholder="0" oninput="recalcVenta()">
          </div>
          <div style="display:flex;background:var(--sf2);border:1px solid var(--bd);border-radius:10px;overflow:hidden;margin-bottom:1px;">
            <div id="v-desc-pct-btn" onclick="ventaSelDescTipo('porcentaje')"
              style="padding:10px 14px;font-size:13px;font-weight:700;cursor:pointer;background:var(--accent);color:var(--bg);">%</div>
            <div id="v-desc-monto-btn" onclick="ventaSelDescTipo('monto')"
              style="padding:10px 14px;font-size:13px;font-weight:700;cursor:pointer;color:var(--muted);">$</div>
          </div>
        </div>
        <div id="v-desc-error" style="display:none;font-size:11px;color:var(--red);margin-top:6px;padding:0 4px;"></div>
      </div>
    </div>
```

- [ ] **Step 2: Agregar las funciones de control del toggle**

Buscar la función `ventaVolver()` (línea ~2842) y agregar ANTES de ella:

```javascript
function ventaToggleDescuento() {
  const panel  = document.getElementById('v-desc-panel');
  const icon   = document.getElementById('v-desc-toggle-icon');
  const toggle = document.getElementById('v-desc-toggle');
  const abierto = panel.style.display !== 'none';
  panel.style.display = abierto ? 'none' : '';
  icon.textContent    = abierto ? '＋' : '−';
  toggle.style.borderColor = abierto ? 'var(--bd2)' : 'var(--accent)';
  if (abierto) {
    const input = document.getElementById('v-desc-valor');
    if (input) input.value = '';
    document.getElementById('v-desc-error').style.display = 'none';
    recalcVenta();
  }
}

function ventaSelDescTipo(tipo) {
  ventaState.descTipo = tipo;
  const pctBtn   = document.getElementById('v-desc-pct-btn');
  const montoBtn = document.getElementById('v-desc-monto-btn');
  if (!pctBtn || !montoBtn) return;
  const activo   = 'background:var(--accent);color:var(--bg);';
  const inactivo = 'background:transparent;color:var(--muted);';
  pctBtn.style.cssText   += tipo === 'porcentaje' ? activo : inactivo;
  montoBtn.style.cssText += tipo === 'monto'      ? activo : inactivo;
  recalcVenta();
}
```

- [ ] **Step 3: Inicializar `descTipo` en `ventaState`**

Localizar línea 2685 (`const ventaState = {`). Cambiar:

```javascript
const ventaState = {
  sku:   null,
  canal: 'Sotos',
  pago:  'Transferencia',
};
```
por:
```javascript
const ventaState = {
  sku:      null,
  canal:    'Sotos',
  pago:     'Transferencia',
  descTipo: 'porcentaje',
};
```

- [ ] **Step 4: Resetear el toggle al resetear la venta**

Localizar `resetVenta()` (línea ~2990). Al inicio de esa función, agregar:

```javascript
  // Ocultar panel de descuento
  const descPanel  = document.getElementById('v-desc-panel');
  const descIcon   = document.getElementById('v-desc-toggle-icon');
  const descToggle = document.getElementById('v-desc-toggle');
  const descInput  = document.getElementById('v-desc-valor');
  const descError  = document.getElementById('v-desc-error');
  if (descPanel)  descPanel.style.display  = 'none';
  if (descIcon)   descIcon.textContent     = '＋';
  if (descToggle) descToggle.style.borderColor = 'var(--bd2)';
  if (descInput)  descInput.value          = '';
  if (descError)  descError.style.display  = 'none';
  ventaState.descTipo = 'porcentaje';
```

- [ ] **Step 5: Verificar en el navegador**

1. Ir a Nueva Venta → Paso 2.
2. El toggle "Aplicar descuento" debe estar visible y colapsado.
3. Al tocarlo, debe expandirse mostrando el input y los botones `%` / `$`.
4. Al tocarlo de nuevo, debe colapsarse.
5. El botón `%` debe estar destacado en amarillo por defecto.
6. Al tocar `$`, el botón `$` queda en amarillo y `%` en gris.

- [ ] **Step 6: Commit**

```bash
git add index.html
git commit -m "feat: toggle de descuento en Paso 2 de nueva venta"
```

---

## Task 5: Recalcular ganancia con descuento en tiempo real

**Archivos:**
- Modify: `index.html:2852-2868` (función `recalcVenta`)

- [ ] **Step 1: Reemplazar la función `recalcVenta()`**

Reemplazar completamente la función (líneas 2852–2868):

```javascript
function recalcVenta() {
  const precio = parseInt(document.getElementById('v-precio').value) || 0;
  const cant   = Math.max(1, parseInt(document.getElementById('v-cant').value) || 1);
  const canal  = ventaState.canal;
  const costo  = ventaState.sku ? (ventaState.sku.costo || 0) : 0;

  // Descuento
  const descPanel  = document.getElementById('v-desc-panel');
  const descAbierto = descPanel && descPanel.style.display !== 'none';
  const descValor  = descAbierto ? (parseInt(document.getElementById('v-desc-valor')?.value) || 0) : 0;
  const descTipo   = ventaState.descTipo || 'porcentaje';
  let precioFinal  = precio;
  if (descAbierto && descValor > 0) {
    if (descTipo === 'porcentaje') {
      precioFinal = Math.round(precio * (1 - descValor / 100));
    } else {
      precioFinal = Math.max(0, precio - descValor);
    }
  }

  const com  = canal === 'Sotos' ? Math.min(Math.round(precioFinal * 0.15), 10000) : 0;
  const gan  = (precioFinal - com) * cant - costo * cant;

  const ganEl   = document.getElementById('vs-gan');
  const preview = document.getElementById('v-gan-preview');
  if (!ganEl || !preview) return;
  const negativo = precio > 0 && gan < 0;
  ganEl.textContent = precio > 0 ? '$'+fmt(gan) : '$—';
  ganEl.style.color = negativo ? 'var(--red)' : 'var(--green)';
  preview.style.background  = negativo ? 'var(--rdim)' : 'var(--gdim)';
  preview.style.borderColor = negativo ? 'rgba(216,75,75,.2)' : 'rgba(30,158,99,.2)';
}
```

- [ ] **Step 2: Verificar en el navegador**

1. Ir a Nueva Venta → Paso 2, ingresar precio $10.000.
2. Abrir el toggle de descuento, ingresar `10` con tipo `%`.
3. El preview de ganancia debe actualizarse en tiempo real usando precio efectivo $9.000.
4. Cambiar a tipo `$` e ingresar `2000` → ganancia debe usar precio efectivo $8.000.
5. Cerrar el toggle → la ganancia vuelve a calcularse sin descuento.

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: recalcVenta considera descuento en tiempo real"
```

---

## Task 6: Confirmar venta con descuento — validación y Paso 3

**Archivos:**
- Modify: `index.html:2871-2988` (función `ventaConfirmar`)

- [ ] **Step 1: Leer el descuento y validar el límite al inicio de `ventaConfirmar()`**

Después de la línea que lee `const envio = 'Presencial';` (línea ~2879), agregar:

```javascript
  // Leer descuento
  const descPanel   = document.getElementById('v-desc-panel');
  const descAbierto = descPanel && descPanel.style.display !== 'none';
  const descValor   = descAbierto ? (parseInt(document.getElementById('v-desc-valor')?.value) || 0) : 0;
  const descTipo    = ventaState.descTipo || 'porcentaje';
  let   precioFinal = precio;
  if (descAbierto && descValor > 0) {
    if (descTipo === 'porcentaje') {
      precioFinal = Math.round(precio * (1 - descValor / 100));
    } else {
      precioFinal = Math.max(0, precio - descValor);
    }
  }

  // Validar límite de descuento para vendedores
  if (_currentUser?.rol === 'Vendedor' && descAbierto && descValor > 0) {
    const maxPct     = getDescuentoMaxPct();
    const pctEfectivo = precio > 0 ? Math.round(((precio - precioFinal) / precio) * 100) : 0;
    if (pctEfectivo > maxPct) {
      const errEl = document.getElementById('v-desc-error');
      if (errEl) { errEl.textContent = `Límite máximo: ${maxPct}%`; errEl.style.display = ''; }
      toast(`Descuento máximo permitido: ${maxPct}%`, 'err');
      return;
    }
  }
```

- [ ] **Step 2: Usar `precioFinal` en lugar de `precio` para los cálculos de la venta**

En `ventaConfirmar()`, localizar la línea:
```javascript
  const com  = canal==='Sotos' ? Math.min(Math.round(precio*0.15), 10000) : 0;
  const neto = (precio - com) * cant;
  const gan  = neto - (s.costo||0) * cant;
```
Reemplazar con:
```javascript
  const com  = canal==='Sotos' ? Math.min(Math.round(precioFinal*0.15), 10000) : 0;
  const neto = (precioFinal - com) * cant;
  const gan  = neto - (s.costo||0) * cant;
```

- [ ] **Step 3: Pasar descuento a `registrarVentaDB`**

Localizar la línea que llama a `registrarVentaDB`:
```javascript
  const ok = await registrarVentaDB(s.id, precio, s.costo||0, canal, pago, envio, cant);
```
Reemplazar con:
```javascript
  const ok = await registrarVentaDB(s.id, precioFinal, s.costo||0, canal, pago, envio, cant,
    descAbierto && descValor > 0 ? descTipo : null,
    descAbierto ? descValor : 0);
```

- [ ] **Step 4: Actualizar el desglose del Paso 3 para mostrar el descuento**

Localizar el bloque `let rows = ...` dentro del `if(desgloseEl)` (línea ~2934). El bloque actual:

```javascript
    let rows = row(`Precio de venta${cant>1?' ×'+cant:''}`, '$'+fmt(precio*cant), 'var(--text)');
    rows += row('Costo del producto', '−$'+fmt((s.costo||0)*cant));
    if(com > 0) rows += row('Comisión Sotos', '−$'+fmt(com*cant));
    rows += sep;
    rows += row('Tu ganancia', '$'+fmt(gan), gan>=0?'var(--green)':'var(--red)');
```
Reemplazar con:
```javascript
    let rows = row(`Precio de venta${cant>1?' ×'+cant:''}`, '$'+fmt(precio*cant), 'var(--text)');
    if (descAbierto && descValor > 0) {
      const descMonto = (precio - precioFinal) * cant;
      const descLbl   = descTipo === 'porcentaje' ? `Descuento ${descValor}%` : 'Descuento';
      rows += row(descLbl, '−$'+fmt(descMonto), 'var(--orange)');
    }
    rows += row('Costo del producto', '−$'+fmt((s.costo||0)*cant));
    if(com > 0) rows += row('Comisión Sotos', '−$'+fmt(com*cant));
    rows += sep;
    rows += row('Tu ganancia', '$'+fmt(gan), gan>=0?'var(--green)':'var(--red)');
```

- [ ] **Step 5: Guardar el precio original en el cache local para el historial**

Localizar el bloque `ventasDB.unshift({ ... })` (línea ~2903). Agregar `descuento_tipo` y `descuento_valor` al objeto:
```javascript
  ventasDB.unshift({
    id: -Date.now(), sku:s.sku, nombre:s.nombre, variante:s.variante,
    icon:s.icon, precio: precioFinal, costo:s.costo||0, com, canal, pago, envio, gan,
    fecha: `Hoy · ${nowHHMM()}`,
    descuento_tipo:  descAbierto && descValor > 0 ? descTipo : null,
    descuento_valor: descAbierto ? descValor : 0
  });
```
(Notar que `precio` cambia a `precioFinal` en el cache también.)

- [ ] **Step 6: Verificar en el navegador**

1. Registrar una venta con descuento del 10% — Paso 3 debe mostrar "Descuento 10%" en naranja en el desglose.
2. Registrar una venta con descuento de $2.000 — Paso 3 debe mostrar "Descuento −$2.000" en naranja.
3. Con un usuario Vendedor y límite del 20%: intentar descuento del 30% → debe bloquear con toast de error.
4. Registrar una venta sin descuento — el desglose no debe mostrar ninguna línea de descuento.

- [ ] **Step 7: Commit**

```bash
git add index.html
git commit -m "feat: ventaConfirmar aplica descuento, valida límite por rol, muestra en Paso 3"
```

---

## Task 7: Guardar descuento en la base de datos

**Archivos:**
- Modify: `index.html:126-151` (función `registrarVentaDB`)

- [ ] **Step 1: Actualizar la firma y el insert de `registrarVentaDB`**

Reemplazar la línea de declaración y el insert del detalle:

**Firma** — cambiar:
```javascript
async function registrarVentaDB(varianteId, precio, costo, canal, pago, envio, cantidad=1) {
```
por:
```javascript
async function registrarVentaDB(varianteId, precio, costo, canal, pago, envio, cantidad=1, descuentoTipo=null, descuentoValor=0) {
```

**Insert del detalle** — cambiar:
```javascript
  const { error: e2 } = await sb
    .from('detalle_ventas')
    .insert({ venta_id: venta.id, variante_id: varianteId, cantidad, precio_unitario: precio, costo_unitario: costo });
```
por:
```javascript
  const detalle = { venta_id: venta.id, variante_id: varianteId, cantidad, precio_unitario: precio, costo_unitario: costo };
  if (descuentoTipo) {
    detalle.descuento_tipo  = descuentoTipo;
    detalle.descuento_valor = descuentoValor;
  }
  const { error: e2 } = await sb.from('detalle_ventas').insert(detalle);
```

- [ ] **Step 2: Verificar en Supabase**

Registrar una venta con descuento desde la app. En Supabase → Table Editor → `detalle_ventas`, verificar que el registro más reciente tiene `descuento_tipo` y `descuento_valor` con los valores correctos.

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: registrarVentaDB guarda descuento_tipo y descuento_valor en BD"
```

---

## Task 8: Mostrar descuento en el historial

**Archivos:**
- Modify: `index.html:2331-2351` (función `renderHistorial`, bloque de filas)

- [ ] **Step 1: Agregar línea de descuento en el render de cada venta**

Localizar la función `renderHistorial` y el bloque donde se construye cada fila (línea ~2334). Después de la línea que construye `meta`:
```javascript
      const meta  = [hora, v.variante && v.variante !== '—' ? v.variante : null].filter(Boolean).join(' · ');
```
Agregar:
```javascript
      const descLabel = v.descuento_tipo && v.descuento_valor > 0
        ? (v.descuento_tipo === 'porcentaje'
            ? `−${v.descuento_valor}% dto.`
            : `−$${fmt(v.descuento_valor)} dto.`)
        : null;
```

Luego, dentro del HTML de la fila, después del div de `meta` (la línea con `${meta ? ...}`), agregar:
```javascript
            ${descLabel ? `<span style="font-size:10px;color:var(--orange);">${descLabel}</span>` : ''}
```

- [ ] **Step 2: Verificar en el navegador**

1. Ir al historial después de registrar una venta con descuento.
2. La venta debe mostrar "−$X dto." en naranja debajo del nombre del producto.
3. Las ventas sin descuento no deben mostrar nada adicional.

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: historial muestra descuento aplicado en cada venta"
```

---

## Task 9: Verificación final

- [ ] **Step 1: Prueba completa del flujo**

Realizar las siguientes pruebas en el navegador:

| Escenario | Resultado esperado |
|-----------|-------------------|
| Venta sin descuento | Flujo igual que antes, sin cambios visibles |
| Venta con 10% de descuento | Paso 3 muestra línea "Descuento 10% −$X" en naranja |
| Venta con $2.000 de descuento | Paso 3 muestra línea "Descuento −$2.000" en naranja |
| Vendedor intenta 30% con límite 20% | Toast de error, no se registra la venta |
| Dueño aplica 50% | Se registra sin restricción |
| Historial | Ventas con descuento muestran "−$X dto." en naranja |
| Config como Dueño | Sección "Ventas" visible con input de % |
| Config como Vendedor | Sección "Ventas" oculta |
| Comisión Sotos con descuento | La comisión se calcula sobre el precio ya descontado |

- [ ] **Step 2: Commit final y push**

```bash
git add index.html
git commit -m "feat: descuentos completo — toggle en Paso 2, límite por rol, historial y config"
git push origin main
```
