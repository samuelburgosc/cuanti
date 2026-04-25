-- ═══════════════════════════════════════════════════
--  CUANTI — Row Level Security (RLS)
--  Ejecutar en Supabase > SQL Editor
--  Propósito: solo usuarios autenticados en la tabla
--  `usuarios` pueden acceder a los datos.
-- ═══════════════════════════════════════════════════

-- ── 1. CREAR FUNCIONES HELPER ──────────────────────

-- Devuelve el rol del usuario actual ('Dueño' | 'Vendedor' | null)
CREATE OR REPLACE FUNCTION get_my_rol()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT rol
  FROM usuarios
  WHERE email = auth.email()
    AND activo = true
  LIMIT 1;
$$;

-- Devuelve el local_id del usuario actual
CREATE OR REPLACE FUNCTION get_my_local_id()
RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT local_id
  FROM usuarios
  WHERE email = auth.email()
    AND activo = true
  LIMIT 1;
$$;

-- Devuelve true si el usuario actual está en la tabla usuarios
CREATE OR REPLACE FUNCTION is_cuanti_user()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM usuarios
    WHERE email = auth.email()
      AND activo = true
  );
$$;

-- ── 2. HABILITAR RLS EN TODAS LAS TABLAS ──────────

ALTER TABLE locales          ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuarios         ENABLE ROW LEVEL SECURITY;
ALTER TABLE categorias       ENABLE ROW LEVEL SECURITY;
ALTER TABLE marcas           ENABLE ROW LEVEL SECURITY;
ALTER TABLE productos        ENABLE ROW LEVEL SECURITY;
ALTER TABLE variantes        ENABLE ROW LEVEL SECURITY;
ALTER TABLE ventas           ENABLE ROW LEVEL SECURITY;
ALTER TABLE detalle_ventas   ENABLE ROW LEVEL SECURITY;
ALTER TABLE compras          ENABLE ROW LEVEL SECURITY;
ALTER TABLE detalle_compras  ENABLE ROW LEVEL SECURITY;
ALTER TABLE gastos_generales ENABLE ROW LEVEL SECURITY;

-- También para las tablas que se agregaron después:
ALTER TABLE clientes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE transferencias   ENABLE ROW LEVEL SECURITY;

-- ── 3. POLÍTICAS — TABLAS COMPARTIDAS (solo lectura para todos) ──

-- categorias: todos los usuarios de Cuanti pueden leer
CREATE POLICY "Cuanti users can read categorias"
  ON categorias FOR SELECT
  USING (is_cuanti_user());

-- marcas: todos pueden leer
CREATE POLICY "Cuanti users can read marcas"
  ON marcas FOR SELECT
  USING (is_cuanti_user());

-- locales: todos pueden leer
CREATE POLICY "Cuanti users can read locales"
  ON locales FOR SELECT
  USING (is_cuanti_user());

-- Solo dueño puede modificar locales
CREATE POLICY "Dueno can modify locales"
  ON locales FOR ALL
  USING (get_my_rol() = 'Dueño');

-- ── 4. POLÍTICAS — USUARIOS ──────────────────────

-- Todos los usuarios de Cuanti pueden ver la lista de usuarios (para equipo)
CREATE POLICY "Cuanti users can read usuarios"
  ON usuarios FOR SELECT
  USING (is_cuanti_user());

-- Solo dueño puede insertar/modificar usuarios
CREATE POLICY "Dueno can manage usuarios"
  ON usuarios FOR ALL
  USING (get_my_rol() = 'Dueño');

-- ── 5. POLÍTICAS — PRODUCTOS Y VARIANTES ─────────

-- Todos los usuarios de Cuanti pueden leer productos
CREATE POLICY "Cuanti users can read productos"
  ON productos FOR SELECT
  USING (is_cuanti_user());

-- Solo dueño puede modificar productos
CREATE POLICY "Dueno can manage productos"
  ON productos FOR ALL
  USING (get_my_rol() = 'Dueño');

-- Variantes: dueño ve todas, vendedor ve solo las de su local
CREATE POLICY "Dueno can read all variantes"
  ON variantes FOR SELECT
  USING (get_my_rol() = 'Dueño');

CREATE POLICY "Vendedor can read own local variantes"
  ON variantes FOR SELECT
  USING (
    get_my_rol() = 'Vendedor'
    AND local_id = get_my_local_id()
  );

-- Solo dueño puede modificar variantes (stock, costo)
CREATE POLICY "Dueno can modify variantes"
  ON variantes FOR ALL
  USING (get_my_rol() = 'Dueño');

-- Vendedor puede actualizar stock (al vender)
CREATE POLICY "Vendedor can update own local variantes"
  ON variantes FOR UPDATE
  USING (
    get_my_rol() = 'Vendedor'
    AND local_id = get_my_local_id()
  );

-- ── 6. POLÍTICAS — VENTAS ────────────────────────

-- Dueño ve todas las ventas
CREATE POLICY "Dueno can read all ventas"
  ON ventas FOR SELECT
  USING (get_my_rol() = 'Dueño');

-- Vendedor ve solo las ventas de su local
CREATE POLICY "Vendedor can read own local ventas"
  ON ventas FOR SELECT
  USING (
    get_my_rol() = 'Vendedor'
    AND local_id = get_my_local_id()
  );

-- Todos los usuarios de Cuanti pueden registrar ventas
CREATE POLICY "Cuanti users can insert ventas"
  ON ventas FOR INSERT
  WITH CHECK (is_cuanti_user());

-- Solo puede actualizar sus propias ventas (ej: anular)
CREATE POLICY "Users can update own ventas"
  ON ventas FOR UPDATE
  USING (
    is_cuanti_user()
    AND (
      get_my_rol() = 'Dueño'
      OR local_id = get_my_local_id()
    )
  );

-- ── 7. POLÍTICAS — DETALLE_VENTAS ────────────────

-- Hereda el acceso de ventas (join necesario)
CREATE POLICY "Dueno can read all detalle_ventas"
  ON detalle_ventas FOR SELECT
  USING (get_my_rol() = 'Dueño');

CREATE POLICY "Vendedor can read own detalle_ventas"
  ON detalle_ventas FOR SELECT
  USING (
    get_my_rol() = 'Vendedor'
    AND EXISTS (
      SELECT 1 FROM ventas v
      WHERE v.id = venta_id
        AND v.local_id = get_my_local_id()
    )
  );

CREATE POLICY "Cuanti users can insert detalle_ventas"
  ON detalle_ventas FOR INSERT
  WITH CHECK (is_cuanti_user());

CREATE POLICY "Cuanti users can update detalle_ventas"
  ON detalle_ventas FOR UPDATE
  USING (is_cuanti_user());

-- ── 8. POLÍTICAS — COMPRAS ───────────────────────

-- Solo dueño puede ver y registrar compras
CREATE POLICY "Dueno can manage compras"
  ON compras FOR ALL
  USING (get_my_rol() = 'Dueño');

CREATE POLICY "Dueno can manage detalle_compras"
  ON detalle_compras FOR ALL
  USING (get_my_rol() = 'Dueño');

-- ── 9. POLÍTICAS — GASTOS ────────────────────────

-- Dueño ve todos los gastos
CREATE POLICY "Dueno can read all gastos"
  ON gastos_generales FOR SELECT
  USING (get_my_rol() = 'Dueño');

-- Solo dueño puede registrar gastos generales
CREATE POLICY "Dueno can manage gastos"
  ON gastos_generales FOR ALL
  USING (get_my_rol() = 'Dueño');

-- ── 10. POLÍTICAS — CLIENTES ─────────────────────

-- Dueño ve todos los clientes
CREATE POLICY "Dueno can manage clientes"
  ON clientes FOR ALL
  USING (get_my_rol() = 'Dueño');

-- Vendedor puede ver y crear clientes
CREATE POLICY "Vendedor can read clientes"
  ON clientes FOR SELECT
  USING (get_my_rol() = 'Vendedor');

CREATE POLICY "Vendedor can insert clientes"
  ON clientes FOR INSERT
  WITH CHECK (get_my_rol() = 'Vendedor');

-- ── 11. POLÍTICAS — TRANSFERENCIAS ───────────────

CREATE POLICY "Cuanti users can manage transferencias"
  ON transferencias FOR ALL
  USING (is_cuanti_user());

-- ═══════════════════════════════════════════════════
--  SETUP INICIAL — Crear usuario dueño
--  (Ejecutar DESPUÉS de crear el usuario en
--  Authentication > Users en el panel de Supabase)
-- ═══════════════════════════════════════════════════

-- Reemplaza 'tu@email.com' con el email de Samu
-- INSERT INTO usuarios (nombre, email, rol, local_id, activo)
-- VALUES ('Samu', 'tu@email.com', 'Dueño', 1, true)
-- ON CONFLICT (email) DO NOTHING;
