# Carga Masiva de Stock — Design Spec

**Fecha:** 2026-04-20  
**Alcance:** Pantalla para ingresar stock de múltiples productos en una sola sesión, sin ir producto por producto desde el escáner

---

## Objetivo

Permitir que el usuario ingrese una carga completa (ej. un lote nuevo de compras) de forma rápida: selecciona o crea productos, define cantidades y costos, y confirma todo junto.

---

## Ubicación en la UI

- Botón **"Carga masiva"** en la pantalla de Inventario (en la barra de acciones superior, junto a los filtros)
- También accesible desde Configuración como acción secundaria

---

## Flujo general

```
[Inventario] → [+ Carga masiva]
    ↓
Pantalla "Carga masiva"
  Lista de líneas vacía
  [+ Agregar producto]
    ↓ sheet selector
  Buscar producto existente  O  Crear nuevo
    ↓
  Línea en el lote con: nombre · variante · qty · costo
    ↓
  [Confirmar carga] → actualiza stock + costo en Supabase → toast "Lote ingresado"
```

---

## Pantalla principal — Lote en construcción

```
← Carga masiva                    [Confirmar]

Sin productos aún
[+ Agregar producto]

─────────────────────
 Zapatilla Air Max · Talla 42
 qty  [3]   costo $[45.000]
 × eliminar
─────────────────────
 Polera Básica · Blanca
 qty  [5]   costo $[8.000]
 × eliminar
─────────────────────

[+ Agregar producto]     [Confirmar carga →]
```

- Cada línea es editable directamente (qty y costo son inputs numéricos)
- El botón Confirmar está deshabilitado si no hay líneas o alguna línea tiene qty=0
- El local de destino es el local activo del usuario (no se cambia en esta pantalla)

---

## Sheet "Agregar producto"

### Opción A — Producto existente

- Campo de búsqueda por nombre o SKU
- Lista de resultados con: inicial·nombre·variante·stock actual
- Al seleccionar → pide qty y costo (un mini-form inline en la línea)
- Si el producto ya está en el lote → suma la cantidad (no duplica la línea)

### Opción B — Producto nuevo

```
Nombre *         [________________]
Categoría *      [selector o + Nueva]
Marca *          [selector o + Nueva]
Variantes *      [Talla 38][Talla 40][+ agregar]
Precio venta *   [________] 
  └ helper: Costo [_____] + Margen [__]% = $___
Stock inicial    [___] (por variante si hay múltiples)
Costo unitario   [___] (por variante si hay múltiples)
```

#### Creación inline de Categoría/Marca nueva

Al tocar "+ Nueva" en categoría o marca:
1. Input de nombre aparece inline
2. Al escribir → búsqueda fuzzy contra las existentes (normalización: sin tildes, minúsculas, trim)
3. Si hay match similar (distancia ≤ 2 caracteres) → muestra: *"¿Quisiste decir [X]?"* con opción de seleccionarla o continuar creando
4. Si no hay match → crea directamente al confirmar el producto

**Sin emojis.** Las categorías no tienen ícono — se muestra la inicial del nombre del producto como avatar en toda la app.

---

## Lógica de datos

### Productos existentes
- Solo se actualiza: `stock_actual += qty` y `costo_ultima_compra = costo` (por variante)
- **No se toca** `precio_base` del producto existente

### Productos nuevos
1. INSERT en `productos`: nombre, categoria_id, marca_id, precio_base, activo=true
2. INSERT en `variantes` (una por cada variante definida): sku auto-generado (15 dígitos), producto_id, talla_color, local_id=_activeLocal, stock_actual=qty, stock_minimo=0, costo_ultima_compra=costo, activa=true

### Precio base
- `precio_base` vive en `productos` (nivel producto, no variante)
- El helper de margen calcula: precio = costo / (1 - margen/100)
- Si el producto tiene múltiples variantes con costos distintos → el precio se define una vez para todas (promedio o el que el usuario ingresa)

### Confirmación
- Todas las operaciones se ejecutan en secuencia (no en paralelo para evitar conflictos)
- Toast de éxito: "X productos ingresados al inventario"
- Recarga `skuDB` y navega de vuelta a Inventario

---

## Detección de duplicados en categoría/marca

Algoritmo fuzzy:
```js
function normalizar(str) {
  return str.trim().toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}
// Distancia de Levenshtein ≤ 2 → sugerir existente
```

---

## Validaciones

- Nombre de producto: requerido, mínimo 2 caracteres
- Categoría y marca: requeridas
- Al menos una variante con qty > 0 y costo > 0
- Precio > 0

---

## Archivos a modificar

- `index.html` únicamente:
  - HTML: pantalla `#screen-carga-masiva`, sheet `#cm-agregar-sheet`
  - CSS: estilos de la pantalla y sheet
  - JS: `abrirCargaMasiva()`, `cmAgregarProducto()`, `cmCrearNuevo()`, `cmConfirmar()`, fuzzy matching

---

## Lo que NO incluye

- Importar desde CSV o Excel
- Registrar el costo total del lote (eso va en Compras)
- Ajustar precio de productos existentes (es deliberado — se cambia en el producto individual)
- Asignar a múltiples locales en una sola carga
