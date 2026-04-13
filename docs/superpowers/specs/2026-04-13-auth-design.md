# Autenticación real — Cuanti

**Fecha:** 2026-04-13  
**Estado:** Aprobado

---

## Contexto

Cuanti necesita autenticación para soportar múltiples usuarios con distintos roles. El dueño (Samu) ve y controla todo. Los vendedores solo pueden registrar ventas y ver inventario — sin acceso a costos, ganancias ni configuración.

---

## Decisiones de diseño

- **Método de auth:** Supabase Auth (`signInWithPassword` / `signUp`)
- **Control de acceso:** client-side por rol (no RLS en esta fase)
- **Creación de vendedores:** el dueño los crea desde Configuración con email + contraseña temporal
- **Sesiones:** persistentes via localStorage (Supabase default)

---

## Arquitectura

### Estado global

```js
let _currentUser = null;
// { id, nombre, email, rol: 'dueño' | 'vendedor', local_id }
```

### Flujo de inicio

1. App carga → `initAuth()` se ejecuta antes que `initDB()`
2. `sb.auth.getSession()` — si hay sesión activa, saltar login
3. Sin sesión → mostrar `screen-login`, ocultar todo lo demás
4. Login exitoso → buscar en `usuarios` por email → setear `_currentUser`
5. Email no encontrado en `usuarios` → error "Usuario no autorizado"
6. Aplicar restricciones de rol → cargar datos → mostrar app

---

## Pantallas

### `screen-login` (nueva)

- Pantalla completa, dark, logo Cuanti centrado
- Campos: email + contraseña
- Botón "Entrar →" (accent amarillo)
- Estado de carga mientras se verifica
- Mensaje de error si credenciales incorrectas
- Sin registro público (solo el dueño crea cuentas)

### Configuración — sección "Equipo" (nueva)

- Solo visible para rol `dueño`
- Lista de usuarios actuales con nombre, email y rol
- Formulario: nombre + email + contraseña → crea cuenta en Supabase Auth + insert en `usuarios`
- Botón desactivar usuario (cambia `activo = false` en `usuarios`)

---

## Permisos por rol

| Pantalla | Dueño | Vendedor |
|----------|-------|----------|
| Dashboard | ✅ | ❌ → redirige a Inventario |
| Inventario | ✅ | ✅ (ocultar columna costo) |
| Nueva Venta | ✅ | ✅ |
| Escáner | ✅ | ✅ |
| Historial | ✅ | ❌ |
| Análisis | ✅ | ❌ |
| SKUs y Etiquetas | ✅ | ❌ |
| Compras | ✅ | ❌ |
| Configuración | ✅ | ❌ |

### Nav bar por rol

- **Dueño:** nav completo (Dashboard, Inventario, Análisis, SKUs)
- **Vendedor:** solo Inventario + FAB escáner. Nueva Venta accesible desde el FAB o inventario.

### Modificación a `goTo()`

```js
const SOLO_DUENO = ['dashboard','historial','analisis','skus','compras','config'];
function goTo(id) {
  if(_currentUser?.rol !== 'dueño' && SOLO_DUENO.includes(id)) {
    id = 'inventario'; // redirigir silenciosamente
  }
  // ... resto del código existente
}
```

### Inventario para vendedor

- Ocultar columna/dato de costo en la lista de variantes
- Ocultar ganancia potencial en cualquier tarjeta

---

## Logout

- Botón "Cerrar sesión" en Configuración (dueño)
- Ícono o botón pequeño en el topbar para vendedor
- Llama `sb.auth.signOut()` → limpia `_currentUser` → muestra `screen-login`

---

## Creación de vendedores

```js
async function crearVendedor(nombre, email, password) {
  // 1. Crear en Supabase Auth
  const { data, error } = await sb.auth.signUp({ email, password });
  if (error) throw error;

  // 2. Insertar en tabla usuarios
  await sb.from('usuarios').insert({
    nombre,
    email,
    rol: 'vendedor',
    local_id: 1,
    activo: true
  });
}
```

El dueño comunica las credenciales al vendedor por WhatsApp. El vendedor puede cambiar su contraseña desde Supabase si es necesario (futuro: pantalla de cambio de contraseña).

---

## Verificación (cómo probar)

1. Abrir la app sin sesión → debe aparecer solo el login
2. Login con credenciales incorrectas → mensaje de error claro
3. Login como dueño → acceso completo, nav completo
4. Login como vendedor → solo ve Inventario + FAB + Nueva Venta
5. Vendedor intenta navegar a Dashboard manualmente → redirige a Inventario
6. Crear vendedor desde Config → cuenta creada, aparece en lista
7. Cerrar sesión → vuelve al login, sesión limpiada
8. Reabrir app → si había sesión activa, entra sin login
