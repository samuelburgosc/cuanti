# Spec: Flujos de acción rápida — Vender, Agregar stock, Crear producto

**Fecha:** 2026-04-26  
**Estado:** Aprobado para implementación  
**Diseño de referencia:** flujos-v2.html  
**Spec relacionado:** 2026-04-26-sistema-guia-dashboard-design.md

---

## 1. Qué son estos flujos

Cuanti es un sistema de decisión, no un formulario. Los tres flujos de acción más frecuentes del usuario deben poder ejecutarse sin pensar:

- **Venta rápida** desde el dashboard (1 tap)
- **Nueva venta** con búsqueda (pantalla dedicada)
- **Agregar stock** desde el bloque "Qué hacer ahora"
- **Crear producto** desde cualquier punto de entrada

El principio rector: **cada acción alimenta el sistema de decisiones.** Una venta actualiza la ganancia del mes, el stock, y el estado del bloque "Qué hacer ahora". Un producto nuevo sin costo activa inmediatamente P3.

---

## 2. Quick-sell — Venta rápida desde el dashboard

### Qué es

Un strip horizontal de 4–5 productos recientes debajo del bloque "Qué hacer ahora". Permite registrar una venta de 1 unidad con un solo toque.

### Condiciones de visibilidad

- Solo se muestra si hay al menos 1 producto con precio válido vendido en los últimos 30 días
- Si no hay datos → no mostrar el strip (el dashboard no colapsa, simplemente el strip no aparece)

### Selección de productos en el strip

```
Orden: los 4–5 productos/variantes con fecha_hora de venta más reciente
Fuente: detalle_ventas JOIN variantes JOIN productos
Filtro: variante.activa = true AND variante.stock_actual > 0 AND productos.precio_base > 0
```

`precio_base` del producto, no `precio_unitario` de ventas pasadas — para reflejar el precio actual y no un precio histórico que puede haber cambiado.

**El strip muestra variantes individuales, no productos.** Si Jordan 1 Retro tiene talla 40 y talla 42, ambas aparecen como items separados en el strip. El usuario puede vender T40 o T42 de forma independiente. El nombre en el strip muestra: `{producto.nombre}` + `{variante.talla_color}` si existe.

Solo mostrar variantes que tengan stock disponible y precio cargado. Si una variante se agota, sale del strip automáticamente en la próxima carga del dashboard.

### Comportamiento al tocar "+"

**Condición previa — validaciones:**

| Situación | Comportamiento |
|-----------|---------------|
| Tiene precio y stock | Registrar venta inmediatamente |
| Sin precio (precio = 0 o NULL) | No hacer nada. Mostrar tooltip: "Agrega un precio para vender rápido" |
| Sin stock (stock = 0) | No debería aparecer en el strip (ver filtro arriba). Si aparece por error de caché → ignorar tap |
| Sin costo | Permitir venta. Ganancia registrada como "sin confirmar" |

**Datos que se registran:**

```javascript
{
  venta: {
    fecha_hora: NOW(),
    usuario_id: usuario_activo.id,
    local_id: local_activo.id,
    canal: 'Presencial',     // canal por defecto para venta rápida
    metodo_pago: null,       // no se captura en venta rápida
    tipo_envio: null,
    estado: 'completada'
  },
  detalle_ventas: {
    variante_id: variante.id,
    cantidad: 1,
    precio_unitario: producto.precio_base,    // precio del producto, no de la variante — variantes no tienen precio propio
    costo_unitario: variante.costo_ultima_compra  // null si no tiene costo
  }
}
```

Después de insertar: `UPDATE variantes SET stock_actual = stock_actual - 1 WHERE id = variante.id`

### Feedback visual al tocar "+"

**Secuencia:**
1. Al tocar "+": el botón del item se convierte en ✓ verde (1.5s)
2. Toast aparece arriba del strip: `"Venta registrada — {nombre} × 1"` con botón **Deshacer** (2.5s visible, luego se cierra solo)
3. El ✓ vuelve a "+" al terminar la animación
4. El toast tiene también un **X** para cerrarlo manualmente antes de los 2.5s

El toast es no bloqueante: el usuario puede seguir navegando o tocar otro "+" mientras está visible.

**Si el usuario toca "Deshacer":**
- Eliminar la venta registrada (DELETE venta + detalle)
- Revertir el stock (-1 revertido a +1)
- Cerrar el toast
- Revertir las métricas del dashboard

### Actualización del dashboard tras venta rápida

Inmediatamente después de registrar (sin reload de página):

| Elemento | Qué actualizar |
|----------|----------------|
| Bloque "Qué hacer ahora" | Re-evaluar condiciones P1–P5. Si el stock bajó a 0 → activar P1. Si bajó a ≤ mínimo → activar P2. |
| Strip quick-sell | Mover el item vendido al primer lugar. Si stock llegó a 0 → sacarlo del strip. |
| Últimas ventas | Agregar la nueva venta al inicio de la lista. Badge "nueva" por 30s. |
| Ganancia del mes | Sumar la ganancia de esta venta al total visible. Si sin costo → mostrar con "?" |
| Ventas del mes | +1 al contador |

Las actualizaciones son **optimistas** (actualizar UI antes de confirmar Supabase). Si falla la inserción → revertir y mostrar error.

---

## 3. Nueva Venta — pantalla completa

### Cuándo se usa

Cuando el usuario quiere:
- Buscar un producto específico que no está en el strip
- Registrar una venta con canal/método de pago/envío específico
- Vender más de 1 unidad
- El bloque P1/P2 lleva al usuario aquí con variante pre-seleccionada (en ese caso, el flujo abre directamente en panel de confirmación)

### Estructura — pantalla única

No hay pasos separados. Todo vive en una sola pantalla que tiene dos estados:

**Estado 1 — Búsqueda**
- Campo de búsqueda visible al inicio
- Debajo: "Recientes" (últimas 4–5 variantes vendidas)
- Debajo: lista de todos los productos/variantes activos

**Estado 2 — Confirmación (después de seleccionar un producto)**

El panel de confirmación ocupa la pantalla reemplazando la búsqueda. Jerarquía visual:

```
[Nombre del producto + variante]  ← grande, prominente
[Control cantidad: − [1] +]       ← claro y táctil
[Precio: $XX.XXX]                 ← secundario, gris
[Ganancia: $X.XXX]                ← secundario, verde pequeño
                                   (o "$X.XXX sin confirmar" en naranja si sin costo)

[Registrar venta]                  ← CTA dominante, amarillo

[Opciones extra — collapsed]       ← "Canal · Pago · Envío" como texto link
```

Un toque en cualquier parte fuera del panel = volver a búsqueda.

### Validaciones

| Situación | Comportamiento |
|-----------|---------------|
| Sin precio (precio = 0 o NULL) | Mostrar producto seleccionable. Panel aparece, pero botón "Registrar venta" está deshabilitado (gris). Aparece link "Agregar precio →" que navega a edición del producto. |
| Sin costo (costo = 0 o NULL) | Permitir venta normalmente. Mostrar hint amarillo inline: "Sin costo registrado — la ganancia puede no ser exacta". No bloquear el CTA. |
| Stock = 0 | Mostrar variante en lista con badge "Sin stock". Permitir seleccionarla. No bloquear CTA — el usuario puede vender aunque no haya stock registrado (puede ser error de conteo). Mostrar advertencia en el panel: `"Estás vendiendo más stock del que tienes registrado"` en naranja. |
| Cantidad > stock | Permitir. Mostrar aviso naranja en el panel: `"Estás vendiendo más stock del que tienes registrado"`. El stock puede quedar en negativo — registrar igual y dejar que el usuario corrija el inventario. |

### Datos que se registran

```javascript
{
  venta: {
    fecha_hora: NOW(),
    usuario_id: usuario_activo.id,
    local_id: local_activo.id,
    canal: canal_seleccionado || 'Presencial',
    metodo_pago: metodo_seleccionado || null,
    tipo_envio: envio_seleccionado || null,
    estado: 'completada'
  },
  detalle_ventas: {
    variante_id: variante.id,
    cantidad: cantidad_ingresada,
    precio_unitario: precio_del_panel,
    costo_unitario: variante.costo_ultima_compra
  }
}
```

### Post-venta

Después de registrar:
- Mostrar pantalla de confirmación breve ("Venta registrada") con ganancia real
- Botón "Nueva venta" + botón "Ir al dashboard"
- Actualizar dashboard en background (mismas métricas que venta rápida)

---

## 4. Agregar stock — bottom sheet

### Cuándo aparece

Se activa desde:
- CTA "Agregar stock ahora →" en P1 (sin stock) del bloque QHA
- CTA "Agregar stock ahora →" en P2 (stock bajo) del bloque QHA

La variante afectada se pasa como contexto al abrir el bottom sheet.

### Estructura del bottom sheet

```
[Handle de arrastre]

[Nombre producto + variante]   ← encabezado del sheet
[Stock actual: {N} unidades]   ← contexto actual

[Cantidad a agregar]
  Valor sugerido: {cantidad_sugerida}  ← editable, pre-cargado
  Control: − [N] +  (o campo numérico táctil)

[Texto estimado: "Con esto te duran ~{semanas} semanas"]  ← dinámico

[Guardar]   ← CTA amarillo, ancho completo

[Cancelar]  ← link, no botón
```

### Cálculo de cantidad sugerida

```
ventas_30d = COUNT(detalle_ventas de esta variante en últimos 30 días)
IF ventas_30d > 0:
  tasa_semanal = ventas_30d / 4
  semanas_objetivo = 3   // cubrir 3 semanas por defecto
  cantidad_sugerida = CEIL(tasa_semanal * semanas_objetivo) - stock_actual
  cantidad_sugerida = MAX(1, cantidad_sugerida)
ELSE:
  cantidad_sugerida = 5  // fallback si no hay datos de venta
```

El valor sugerido se pre-carga como valor inicial del campo. El usuario puede cambiarlo libremente.

### Texto dinámico de estimación

```
IF ventas_30d > 0:
  semanas_con_nuevo_stock = FLOOR((stock_actual + cantidad_ingresada) / tasa_semanal)
  texto = "Con esto te duran ~{semanas_con_nuevo_stock} semanas"
ELSE:
  NO mostrar estimación — solo mostrar "Quedarás con {stock_actual + cantidad_ingresada} unidades"
```

El texto se actualiza en tiempo real conforme el usuario cambia la cantidad.

### Datos que se registran

La prioridad del flujo rápido es actualizar el stock. El registro de compra es secundario y no debe bloquear la acción.

**Operación mínima obligatoria:**
```sql
UPDATE variantes SET stock_actual = stock_actual + :cantidad WHERE id = :variante_id
```

**Registro de compra (best-effort, no bloquea si falla):**
```javascript
{
  compra: {
    fecha: TODAY(),
    origen: 'reposicion_rapida',
    local_destino_id: local_activo.id,
    usuario_id: usuario_activo.id,
    total_pagado_clp: null,
    proveedor: null,
    referencia: null,
    notas: 'Reposición rápida desde dashboard'
  },
  detalle_compras: {
    compra_id: compra.id,
    variante_id: variante.id,
    cantidad: cantidad_ingresada,
    costo_unitario: variante.costo_ultima_compra
  }
}
```

Si el insert de compra falla, el stock ya fue actualizado — no revertir. El usuario verá el stock correcto aunque no quede historial de esa reposición.

### Lo que NO incluye este flujo

- Proveedor
- Número de lote o referencia
- Costo nuevo (usa el último costo registrado)
- Tipo de cambio (no es compra internacional)

Para registrar una compra completa con todos esos datos → el usuario va a la pantalla "Ingresar compra" por su cuenta.

### Post-guardar

- Cerrar bottom sheet
- Re-evaluar QHA: si el stock nuevo supera el mínimo → P1/P2 desaparece
- Actualizar stock en el strip quick-sell si el producto estaba ahí

---

## 5. Crear producto — formulario mínimo

### Cuándo aparece

- Botón "Nuevo producto" desde pantalla Stock
- CTA en empty state del dashboard o stock
- (Futuro) escaneo de código de barras sin match → proponer crear producto

### Estructura

**Campos visibles (siempre):**

```
Nombre del producto *
Precio de venta *
Costo (opcional)
```

**Toggle colapsado (secundario):**

```
[ ] Tiene tallas o colores diferentes
```

Al activar el toggle aparecen los campos de variantes. Por defecto, colapsado.

Subtexto debajo del formulario: `"Puedes agregar fotos y tallas después desde el inventario"`

### Validaciones

| Situación | Comportamiento |
|-----------|---------------|
| Sin nombre | No permitir guardar. Campo con borde rojo. |
| Sin precio | No permitir guardar como producto vendible. Mostrar: "Sin precio no puedes registrar ventas de este producto." |
| Sin costo | Permitir guardar. Mostrar advertencia suave: "Sin costo no sabrás cuánto ganas. Puedes agregarlo después." El producto se crea con `costo_ultima_compra = null`. |
| Precio = 0 | Equivalente a sin precio. No permitir. |

### Datos que se crean

```javascript
{
  producto: {
    nombre: nombre_ingresado,
    precio_base: precio_ingresado,
    activo: true,
    tiene_tallas: toggle_activo
  },
  variante: {  // se crea automáticamente una variante base
    producto_id: producto.id,
    local_id: local_activo.id,
    talla_color: null,         // sin talla para producto simple
    stock_actual: 0,
    stock_minimo: 2,           // valor por defecto
    costo_ultima_compra: costo_ingresado || null,
    activa: true
    // sku: auto-generado (15 dígitos)
  }
}
```

### Post-guardar

En vez de redirigir al inventario, mostrar una pantalla de confirmación con acciones siguientes:

```
✓ Producto creado

[Registrar venta]       ← CTA amarillo (navega a Nueva Venta con este producto pre-seleccionado)
[Agregar stock]         ← CTA secundario (abre bottom sheet de stock para este producto)
[Ver en inventario]     ← link, no botón
```

El usuario que acaba de crear un producto lo más probable es que quiera vender o reponer stock — llevarlos al inventario no tiene sentido en ese momento.

Si el producto fue creado sin costo → el dashboard evaluará P3 en su próxima carga.

---

## 6. Ganancia "sin confirmar"

Cuando se registra una venta (rápida o normal) sin costo conocido:

- `costo_unitario` en `detalle_ventas` = null
- Ganancia calculada = `precio_unitario * cantidad - comision` (sin restar costo)
- En el dashboard, la ganancia del mes se muestra con `$X?` y subtexto `"sin confirmar"` en naranja
- En el historial, esa venta muestra ganancia con `"?"` o badge naranja

Esta marca desaparece automáticamente cuando el usuario agrega un costo al producto. Los datos históricos no se recalculan retroactivamente — solo las ventas futuras usarán el nuevo costo.

### Impacto en insights del sistema

Las ventas con `costo_unitario = null` **no se usan** para calcular:
- Qué canal deja más ganancia (P5 del bloque QHA)
- Qué producto es más rentable
- Cualquier comparación de margen entre productos o canales

Si el porcentaje de ventas sin costo es alto (> 30% de las ventas del período), los insights de canal y rentabilidad se muestran con advertencia: `"Algunos productos no tienen costo registrado — el análisis puede no ser preciso"`. Umbral exacto a definir en la implementación del bloque QHA.

---

## 7. Reglas de UX transversales

1. **Sin formularios largos en flujos de acción.** Los flujos de vender, reponer y crear deben poder completarse con 1–3 toques. Los campos opcionales van colapsados.

2. **Feedback inmediato.** Toda acción tiene respuesta visual antes de que Supabase confirme. Si falla la sincronización → revertir y avisar.

3. **Sin bloqueos innecesarios.** Solo se bloquea lo que es estrictamente imposible (sin precio = no puedes vender). Sin costo = advertencia, no bloqueo.

4. **Toda acción actualiza el sistema.** Venta → ganancia + stock + QHA. Stock → QHA. Producto → QHA (si aplica P3). El usuario ve que sus acciones tienen efecto real.

5. **Canal por defecto en venta rápida = Presencial.** Sin preguntar. El usuario puede cambiarlo en el flujo completo de Nueva Venta.

6. **Deshacer siempre disponible** en venta rápida (2.5s). Sin diálogos de confirmación previos — la confirmación es posterior.

7. **Lenguaje directo.** Nunca: "margen", "costo unitario", "SKU". Siempre: "cuánto ganas", "precio de compra", "código".

---

## 8. Datos necesarios por flujo

### Quick-sell
| Dato | Tabla | Campo |
|------|-------|-------|
| Últimas variantes vendidas | `detalle_ventas` JOIN `variantes` | `fecha_hora` |
| Precio válido | `productos` | `precio_base` |
| Stock disponible | `variantes` | `stock_actual` |
| Costo (para ganancia) | `variantes` | `costo_ultima_compra` |

### Agregar stock
| Dato | Tabla | Campo |
|------|-------|-------|
| Stock actual de la variante | `variantes` | `stock_actual` |
| Ventas últimos 30 días | `detalle_ventas` | `cantidad`, `fecha_hora` |
| Costo para mantener | `variantes` | `costo_ultima_compra` |

### Crear producto
- Solo inputs del usuario → insert en `productos` + insert en `variantes`

---

## 9. Orden de implementación

Los flujos se implementan en este orden. Cada uno es funcional e independiente — no hay dependencias duras entre ellos.

| Orden | Flujo | Razón |
|-------|-------|-------|
| 1 | Nueva venta simplificada | Es el flujo más usado. Simplificar la pantalla actual genera valor inmediato. |
| 2 | Quick-sell en dashboard | Depende de que haya ventas registradas — va después de arreglar Nueva Venta. |
| 3 | Agregar stock rápido desde QHA | Depende del bloque QHA. Se implementa cuando QHA esté listo. |
| 4 | Crear producto simple | Mejora el flujo actual, sin dependencias. |
| 5 | Actualización inmediata de dashboard/QHA | Es la capa de integración — une todos los flujos anteriores con el sistema de decisiones. |

El bloque QHA (spec: 2026-04-26-sistema-guia-dashboard-design.md) se implementa en paralelo o antes de los flujos 3 y 5.

---

## 10. Fuera de scope en esta versión

- Selección de canal/pago/envío en venta rápida (solo flujo completo)
- Cambio de precio al momento de vender (precio fijo del producto)
- Descuentos
- Múltiples items en una sola venta rápida (solo 1 item × 1 unidad)
- Agregar fotos al crear producto desde el flujo rápido
- Recalcular ganancia histórica al agregar costo
- Proveedor / lote en flujo rápido de stock
