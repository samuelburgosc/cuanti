# Clientes con historial — Diseño

**Fecha:** 2026-04-13  
**Estado:** Aprobado

---

## Resumen

Agregar un sistema de clientes que permite asignar un comprador a cada venta (opcional), ver el historial completo de compras por cliente y contactarlos por WhatsApp. El teléfono es el identificador único por local.

---

## Base de datos

### Nueva tabla `clientes`

```sql
CREATE TABLE clientes (
  id          bigserial PRIMARY KEY,
  nombre      text NOT NULL,
  telefono    text,
  local_id    bigint REFERENCES locales(id),
  activo      boolean DEFAULT true,
  created_at  timestamptz DEFAULT now(),
  UNIQUE (telefono, local_id)
);
```

### Modificación a `ventas`

```sql
ALTER TABLE ventas
  ADD COLUMN IF NOT EXISTS cliente_id bigint REFERENCES clientes(id);
```

---

## Pantalla Clientes

Nueva pantalla `screen-clientes` accesible desde el nav (ícono 👥, entre Historial y Análisis o al final).

### Lista principal (tab "Clientes" en Historial)
- Buscador por nombre o teléfono en la parte superior
- Lista de clientes ordenada por total gastado (descendente)
- Cada card muestra:
  - Nombre (grande) + teléfono (pequeño, si existe)
  - Número de compras + total gastado (en verde, fuente DM Mono)
- Si no hay clientes → estado vacío: "Aún no tienes clientes registrados. Asígnalos al hacer una venta."
- Botón "+ Nuevo cliente" al final de la lista para crear uno manualmente

### Pantalla de detalle de cliente
- Header: nombre, teléfono, botón WhatsApp (si tiene teléfono → abre `https://wa.me/56XXXXXXXXX`)
- Stats: total gastado, # compras, última compra
- Lista de compras del cliente (misma estructura que el historial general)

---

## Paso 2 de la venta — campo opcional

Debajo del bloque de método de pago, campo "¿Quién compra?" colapsado por defecto (mismo patrón que el toggle de descuento).

### Comportamiento
- Al tocar el toggle, aparece un input de texto con autocomplete
- Al escribir 2+ caracteres, busca en `clientesDB` (cache local) por nombre o teléfono
- Muestra sugerencias como lista desplegable (nombre + teléfono)
- Si el usuario selecciona una sugerencia → el cliente queda asignado
- Si escribe un nombre que no existe → al confirmar la venta, se crea un cliente nuevo con ese nombre (sin teléfono)
- Si se deja vacío → venta sin cliente

### Estado
- `ventaState.clienteId` (número o null) — cliente existente seleccionado
- `ventaState.clienteNombre` (string o null) — nombre escrito si es nuevo

---

## Historial

- Las ventas que tienen cliente asignado muestran el nombre en gris pequeño debajo del nombre del producto

---

## Cache local

Se agrega array `clientesDB` cargado al inicio desde la tabla `clientes`. Al crear un cliente nuevo (desde venta o manualmente), se agrega al cache sin recargar todo.

---

## Navegación

No se agrega pantalla separada ni nuevo ítem al nav. La vista de Clientes vive como una **segunda tab en la pantalla Historial**:
- Tab "Ventas" (existente, comportamiento actual)
- Tab "Clientes" (nueva) — muestra la lista de clientes con su historial

El nav y `ALL_SCREENS` no cambian. La topbar de Historial muestra el selector de tabs.

---

## Lógica de creación automática de cliente

Al confirmar una venta con nombre escrito pero sin cliente seleccionado:
1. Buscar en `clientesDB` si ya existe un cliente con ese nombre exacto (case-insensitive) en el mismo local
2. Si existe → usar ese `cliente_id`
3. Si no existe → crear en BD, agregar al cache, usar el nuevo `id`

---

## Fuera de alcance

- Editar o eliminar clientes
- Notas o etiquetas por cliente
- Clientes compartidos entre locales
- Importar lista de clientes
