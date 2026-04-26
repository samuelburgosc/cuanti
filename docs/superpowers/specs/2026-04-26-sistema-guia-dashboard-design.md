# Spec: Sistema de guía — Bloque "Qué hacer ahora" + Empty States

**Fecha:** 2026-04-26  
**Estado:** Aprobado para implementación  
**Diseño de referencia:** dashboard-bloque-v6.html

---

## 1. Qué es este sistema

El dashboard de Cuanti tiene un bloque principal llamado **"Qué hacer ahora"** que le dice al usuario exactamente qué acción tomar en este momento. No muestra datos — toma una decisión por el usuario.

El bloque es siempre visible en el dashboard. Tiene 6 estados posibles ordenados por urgencia. Solo muestra uno a la vez. Desaparece (o cambia de estado) automáticamente cuando el problema se resuelve en la base de datos.

---

## 2. Los 6 estados — condiciones exactas

### P1 — Sin stock (máxima urgencia)

**Condición:**
```
variante.stock_actual === 0
AND EXISTS ventas de esa variante en los últimos 30 días
AND variante.activa = true
```

**Por qué la condición de ventas recientes:** un producto con stock = 0 que nunca se vendió no es urgente. Solo es urgente si había demanda activa.

**Qué mostrar:**
- Stat: `Sin stock`
- Contexto: `{producto.nombre} {variante.talla_color} se agotó`
- Sub: `Tenías ventas regulares. Sin stock, podrías perder ~{pérdida_estimada} esta semana.`
- CTA: `Agregar stock ahora →`

**Cálculo de pérdida estimada:**
```
ventas_30d = COUNT(detalle_ventas de esa variante en últimos 30 días)
tasa_semanal = ventas_30d / 4
ganancia_prom = AVG((precio_unitario - costo_unitario) * cantidad - comision) de esas ventas
perdida_estimada = ROUND(tasa_semanal * ganancia_prom, -3)  // redondear a miles
```
Si `ventas_30d = 0` o `ganancia_prom` no se puede calcular → omitir la parte de pérdida estimada, solo mostrar el mensaje base.

**Selección de variante a mostrar:** la que tenga la venta más reciente entre todas las que cumplen la condición.

---

### P2 — Stock bajo

**Condición:**
```
variante.stock_actual > 0
AND variante.stock_actual <= variante.stock_minimo
AND variante.activa = true
```
Si `variante.stock_minimo` es 0 o nulo → usar 2 como mínimo por defecto.

**Qué mostrar:**
- Stat: `{stock_actual} unidades`
- Contexto: `{producto.nombre} {talla_color} — se acaba en {dias_restantes} días`
- Sub: `Podrías perder ~{pérdida_estimada} en ventas esta semana.`
- CTA: `Agregar stock ahora →`

**Cálculo de días restantes:**
```
ventas_30d = COUNT(detalle_ventas de esa variante en últimos 30 días)
IF ventas_30d > 0:
  tasa_diaria = ventas_30d / 30
  dias_restantes = FLOOR(variante.stock_actual / tasa_diaria)
  dias_restantes = MAX(1, dias_restantes)  // nunca mostrar 0 días
ELSE:
  NO mostrar "se acaba en X días" — solo mostrar "quedan {stock_actual} unidades"
```

**Cálculo de pérdida estimada:** igual que P1.

**Selección de variante:** la que tenga menor `stock_actual / stock_minimo` (más cerca de agotarse).

---

### P3 — Sin costo registrado

**Condición:**
```
COUNT(DISTINCT variante.producto_id donde:
  (costo_ultima_compra IS NULL OR costo_ultima_compra = 0)
  AND activa = true
  AND EXISTS al menos 1 venta de cualquier variante de ese producto ever
) > 0
```

La condición "al menos 1 venta ever" es importante: un producto recién creado sin costo no es urgente. Lo urgente es que se está vendiendo sin saber el margen.

El count es de **productos distintos**, no de variantes. Un producto con 5 tallas sin costo cuenta como 1, no como 5.

**Qué mostrar:**
- Stat: `{count} productos`
- Contexto: `sin costo registrado`
- Sub: `No sabes si estás ganando plata en esos productos. Agrega el costo y Cuanti calcula tu ganancia real.`
- CTA: `Completar ahora →`

**Nota en métricas:** cuando P3 está activo, la ganancia del mes en la barra inferior se muestra como `$X?` con subtexto "sin confirmar" en naranja.

---

### P4 — Capital parado

**Condición:**
```
variante.stock_actual > 0
AND variante.costo_ultima_compra > 0
AND (fecha_ultima_venta IS NULL OR fecha_ultima_venta < NOW() - 30 días)
AND (variante.stock_actual * variante.costo_ultima_compra) >= 10.000  // umbral mínimo en CLP
AND variante.activa = true
```

**Qué mostrar:**
- Stat: `${capital_total_parado} parados`
- Contexto: `{producto.nombre} — {días_sin_venta} días sin venderse`
- Sub: `Estás dejando plata parada. Considera bajar el precio para moverlo.`
- CTA: `Ver productos →` (link, no botón sólido)

**Cálculos:**
```
capital_variante = variante.stock_actual * variante.costo_ultima_compra
capital_total = SUM(capital_variante) de TODAS las variantes que cumplen la condición
dias_sin_venta = DATEDIFF(NOW(), fecha_ultima_venta) de la variante con más capital parado
```

La variante que se muestra en el contexto es la de mayor capital inmovilizado.

---

### P5 — Oportunidad de venta

**Condición:**
```
Existen al menos 2 canales con ventas en los últimos 30 días
AND cada canal tiene al menos 3 ventas en ese período
AND diferencia de ganancia promedio entre mejor y segundo canal >= 1.000 CLP
```

**Qué mostrar:**
- Stat: `${diferencia} más`
- Contexto: `por venta en {canal_mejor} vs {canal_segundo}`
- Sub: `Prioriza ese canal para ganar más sin vender más.`
- CTA: `Ver análisis →` (link)

**Cálculo:**
```
Para cada canal con ventas en los últimos 30 días:
  ganancia_prom_canal = AVG(
    (precio_unitario - costo_unitario) * cantidad - comision_sotos
  ) agrupado por venta

comision_sotos = canal === 'Sotos' ? MIN(precio * 0.15, 10000) : 0

diferencia = ganancia_prom_mejor - ganancia_prom_segundo
```

---

### P0 — Todo en orden (estado base)

**Condición:** ninguna de las condiciones P1–P5 se cumple.

**Qué mostrar:**
- Stat: `Todo en orden 👌`
- Sub: `No hay nada urgente ahora.`
- Sugerencia accionable: si hay datos de canal → `{canal_mejor} te deja más ganancia que {canal_segundo}. Si priorizas ese canal, puedes ganar más sin vender más.` + link `Ver análisis →`
- Si no hay suficientes datos de canal → `Sigue registrando ventas — con más datos Cuanti puede decirte qué productos empujar y cuándo reponer.`

---

## 3. Regla de prioridad

```
P1 > P2 > P3 > P4 > P5 > P0
```

Si se cumplen múltiples condiciones simultáneamente, **siempre gana la de mayor prioridad**. No se acumulan, no se apilan. Un solo mensaje.

**Ejemplos:**
- Sin stock + sin costo → muestra P1 (Sin stock)
- Stock bajo + capital parado → muestra P2 (Stock bajo)
- Sin costo + oportunidad → muestra P3 (Sin costo)

---

## 4. Definición de cada CTA

### "Agregar stock ahora →" (P1 y P2)
- Acción: navegar a la pantalla `ingresar-compra`
- Pre-seleccionar la variante afectada si es posible (pasar `varianteId` como contexto)
- No es un modal — es la pantalla de ingresar compra existente

### "Completar ahora →" (P3)
- Acción: navegar a `stock` (inventario)
- Aplicar filtro automático: mostrar solo productos con costo = 0 o nulo
- El usuario ve la lista filtrada y puede editar cada uno

### "Ver productos →" (P4)
- Acción: navegar a `stock` (inventario)
- Aplicar filtro: ordenar por días sin venta (descendente)
- No pre-filtrar — solo cambiar el orden por defecto

### "Ver análisis →" (P5 y P0)
- Acción: navegar a `analisis`
- Abrir en tab `Resumen` (tab del mes actual) que ya muestra comparación por canal en la sección de canales
- Si ese tab no existe aún → navegar a `analisis` sin tab específico y dejar que el plan de implementación lo resuelva

---

## 5. Empty states — pantallas sin datos

Regla general: cuando una pantalla no tiene datos, muestra un mensaje que explica qué hacer para que aparezcan. Sin tablas vacías, sin spinners solos, sin pantallas en blanco.

### Dashboard — sin productos ni ventas
```
Icono: 👋
Título: ¡Bienvenido a Cuanti!
Cuerpo: Para empezar, agrega tu primer producto y registra una venta. Cuanti hará el resto.
CTA: Agregar producto →  (navega a nuevo-producto)
```

### Stock — sin productos
```
Icono: 📦
Título: Todavía no tienes productos
Cuerpo: Agrega los productos que vendes con su precio y costo. Así Cuanti puede calcular cuánto ganas.
CTA: Nuevo producto →
```

### Historial — sin ventas
```
Icono: 🧾
Título: Todavía no hay ventas
Cuerpo: Cuando registres una venta, aparecerá aquí con su ganancia calculada.
CTA: Registrar venta →  (abre flujo nueva venta)
```

### Análisis — sin ventas
```
Icono: 📊
Título: Aún no hay suficiente información
Cuerpo: El análisis aparece cuando tienes ventas registradas. Registra la primera para ver cómo va tu negocio.
CTA: Registrar venta →
```

---

## 6. Hints contextuales — máx. 1 por pantalla

Aparecen cuando hay datos pero hay algo importante que el usuario debería saber. Se basan 100% en datos — no en localStorage ni dismiss manual. Desaparecen solos cuando la condición se resuelve.

### Pantalla Stock — productos sin costo
```
Condición: COUNT(variantes sin costo AND activas) > 0
Hint: "💡 {N} productos no tienen costo registrado. Sin eso, la ganancia puede estar inflada."
Desaparece: cuando todos los productos activos tienen costo > 0
```

### Pantalla Análisis — pocos datos
```
Condición: ventas_totales < 10 OR fecha_primera_venta > NOW() - 14 días
Hint: "📈 Con más ventas, aquí vas a ver cuáles productos te dejan más ganancia y cuáles conviene dejar de vender."
Desaparece: cuando ventas_totales >= 10 AND han pasado 14 días desde la primera venta

ventas_totales = COUNT(ventas) del local activo, sin filtro de fecha
fecha_primera_venta = MIN(ventas.fecha_hora) del local activo
```

### Pantalla Nueva Venta — primer uso
```
Condición: ventas_totales === 0
ventas_totales = COUNT(ventas) del local activo
Hint: "👆 Busca el producto por nombre o escanea el código de barras. Canal y método de pago son opcionales."
Desaparece: después de la primera venta registrada
```

---

## 7. Datos necesarios y de dónde vienen

| Dato | Tabla | Campo |
|------|-------|-------|
| Stock actual | `variantes` | `stock_actual` |
| Stock mínimo | `variantes` | `stock_minimo` |
| Costo | `variantes` | `costo_ultima_compra` |
| Nombre producto | `productos` | `nombre` |
| Talla/color | `variantes` | `talla_color` |
| Fecha de ventas | `ventas` | `fecha_hora` |
| Canal de venta | `ventas` | `canal` |
| Precio unitario | `detalle_ventas` | `precio_unitario` |
| Costo unitario | `detalle_ventas` | `costo_unitario` |
| Cantidad | `detalle_ventas` | `cantidad` |

Todas las queries necesarias para el bloque "Qué hacer ahora" se ejecutan al cargar el dashboard. Los datos se cachean en memoria durante la sesión — no se re-consultan en cada render.

---

## 8. Reglas de implementación

1. **Solo 1 estado visible** — no acumular, no apilar
2. **Desaparición automática** — basada en datos, sin localStorage ni dismiss manual
3. **Sin lenguaje técnico** — nunca: "KPI", "margen bruto", "rotación", "stock crítico"
4. **Lenguaje directo** — siempre: "se agotó", "no sabes cuánto ganas", "estás dejando plata parada"
5. **El bloque no es una card** — sin border-radius en el contenedor principal, sin sombras, sin fondo coloreado en P3–P5
6. **Métricas subordinadas** — la barra de ganancia/ventas va debajo del bloque y tiene peso visual mínimo
7. **Un número dominante por estado** — número + contexto se leen como una sola unidad
8. **CTA botón sólido solo para P1–P3** — P4 y P5 usan link (menor urgencia)

---

## 9. Comportamiento durante la carga inicial

Mientras se cargan los datos de Supabase:
- Mostrar el estado P0 ("Todo en orden") como placeholder silencioso
- No mostrar spinner en el bloque — evita que parezca roto
- Una vez que llegan los datos, renderizar el estado correcto

---

## 10. Prioridad vs roadmap

Este spec cubre únicamente:
- El bloque "Qué hacer ahora" en el dashboard
- Los empty states de las 4 pantallas principales
- Los 3 hints contextuales

**Fuera de scope en esta versión:**
- Notificaciones push de alertas de stock
- Historial de alertas pasadas
- Configuración de umbrales por el usuario
- Estimaciones basadas en tendencias de más de 30 días
