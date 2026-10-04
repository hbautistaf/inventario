-- ============================================================================
-- INVENTARIO UNIVERSAL 1.0 - MIGRACIÓN CONSOLIDADA CANÓNICA
-- Fecha: Octubre 2026
-- Contenido:
--  1. Extensiones
--  2. Tablas del Núcleo (businesses, business_members, warehouses, products)
--  3. Tablas de Inventario y Trazabilidad (balances, movements, movement_lines)
--  4. Índices para Alto Rendimiento
--  5. Triggers de Seguridad e Inmutabilidad
--  6. Aislamiento Multiempresa Estricto (RLS: Solo SELECT para usuarios autenticados)
--  7. Funciones del Sistema (create_business, create_inventory_movement,
--     add_inventory_movement_line, post_inventory_movement, reverse_inventory_movement)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
-- 1. TABLAS DEL NÚCLEO
-- ----------------------------------------------------------------------------

-- Empresas / Tenants
CREATE TABLE IF NOT EXISTS public.businesses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    legal_name text,
    tax_id text,
    currency_code char(3) NOT NULL DEFAULT 'MXN',
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT businesses_name_not_empty
        CHECK (length(trim(name)) > 0)
);

-- Miembros y Roles por Empresa
CREATE TABLE IF NOT EXISTS public.business_members (
    business_id uuid NOT NULL
        REFERENCES public.businesses(id) ON DELETE CASCADE,
    user_id uuid NOT NULL
        REFERENCES auth.users(id) ON DELETE CASCADE,
    role text NOT NULL DEFAULT 'operator',
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (business_id, user_id),
    CONSTRAINT business_members_role_check
        CHECK (role IN ('owner', 'admin', 'operator', 'viewer'))
);

-- Almacenes por Empresa
CREATE TABLE IF NOT EXISTS public.warehouses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL
        REFERENCES public.businesses(id) ON DELETE CASCADE,
    code text NOT NULL,
    name text NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (business_id, id),
    UNIQUE (business_id, code),
    CONSTRAINT warehouses_code_not_empty
        CHECK (length(trim(code)) > 0),
    CONSTRAINT warehouses_name_not_empty
        CHECK (length(trim(name)) > 0)
);

-- Catálogo de Productos
CREATE TABLE IF NOT EXISTS public.products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL
        REFERENCES public.businesses(id) ON DELETE CASCADE,
    sku text NOT NULL,
    name text NOT NULL,
    description text,
    unit text NOT NULL DEFAULT 'pieza',
    min_stock numeric(18,4) NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (business_id, id),
    UNIQUE (business_id, sku),
    CONSTRAINT products_min_stock_nonnegative
        CHECK (min_stock >= 0),
    CONSTRAINT products_sku_not_empty
        CHECK (length(trim(sku)) > 0),
    CONSTRAINT products_name_not_empty
        CHECK (length(trim(name)) > 0)
);

-- ----------------------------------------------------------------------------
-- 2. TABLAS DE INVENTARIO Y TRAZABILIDAD
-- ----------------------------------------------------------------------------

-- Saldos de Inventario (Existencias y Costo Promedio Ponderado)
CREATE TABLE IF NOT EXISTS public.inventory_balances (
    business_id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity numeric(18,4) NOT NULL DEFAULT 0,
    average_cost numeric(18,6) NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT now(),

    PRIMARY KEY (business_id, warehouse_id, product_id),

    FOREIGN KEY (business_id, warehouse_id)
        REFERENCES public.warehouses(business_id, id) ON DELETE RESTRICT,

    FOREIGN KEY (business_id, product_id)
        REFERENCES public.products(business_id, id) ON DELETE RESTRICT,

    CONSTRAINT inventory_quantity_nonnegative
        CHECK (quantity >= 0),

    CONSTRAINT inventory_average_cost_nonnegative
        CHECK (average_cost >= 0)
);

-- Encabezados de Movimientos
CREATE TABLE IF NOT EXISTS public.inventory_movements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL
        REFERENCES public.businesses(id) ON DELETE RESTRICT,
    warehouse_id uuid NOT NULL,
    movement_type text NOT NULL,
    status text NOT NULL DEFAULT 'draft',
    reference text,
    reason text NOT NULL,
    notes text,
    created_by uuid REFERENCES auth.users(id),
    posted_by uuid REFERENCES auth.users(id),
    reversal_of uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    posted_at timestamptz,

    UNIQUE (business_id, id),
    UNIQUE (business_id, reversal_of),

    FOREIGN KEY (business_id, warehouse_id)
        REFERENCES public.warehouses(business_id, id) ON DELETE RESTRICT,

    FOREIGN KEY (business_id, reversal_of)
        REFERENCES public.inventory_movements(business_id, id) ON DELETE RESTRICT,

    CONSTRAINT inventory_movement_type_check
        CHECK (movement_type IN ('receipt', 'issue', 'adjustment')),

    CONSTRAINT inventory_movement_status_check
        CHECK (status IN ('draft', 'posted', 'cancelled')),

    CONSTRAINT inventory_movement_reason_not_empty
        CHECK (length(trim(reason)) > 0)
);

-- Detalle de Líneas de Movimiento
CREATE TABLE IF NOT EXISTS public.inventory_movement_lines (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL,
    movement_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity numeric(18,4) NOT NULL DEFAULT 1,
    unit_cost numeric(18,6),
    physical_count numeric(18,4),
    adjustment_direction text,
    stock_before numeric(18,4),
    stock_after numeric(18,4),
    applied_unit_cost numeric(18,6),
    created_at timestamptz NOT NULL DEFAULT now(),

    UNIQUE (business_id, movement_id, product_id),

    FOREIGN KEY (business_id, movement_id)
        REFERENCES public.inventory_movements(business_id, id) ON DELETE CASCADE,

    FOREIGN KEY (business_id, product_id)
        REFERENCES public.products(business_id, id) ON DELETE RESTRICT,

    CONSTRAINT inventory_line_quantity_nonnegative
        CHECK (quantity >= 0),

    CONSTRAINT inventory_line_cost_nonnegative
        CHECK (unit_cost IS NULL OR unit_cost >= 0),

    CONSTRAINT inventory_line_physical_count_nonnegative
        CHECK (physical_count IS NULL OR physical_count >= 0),

    CONSTRAINT inventory_line_adjustment_direction_check
        CHECK (adjustment_direction IS NULL OR adjustment_direction IN ('increase', 'decrease', 'none')),

    CONSTRAINT inventory_line_stock_before_nonnegative
        CHECK (stock_before IS NULL OR stock_before >= 0),

    CONSTRAINT inventory_line_stock_after_nonnegative
        CHECK (stock_after IS NULL OR stock_after >= 0),

    CONSTRAINT inventory_line_applied_cost_nonnegative
        CHECK (applied_unit_cost IS NULL OR applied_unit_cost >= 0)
);

-- ----------------------------------------------------------------------------
-- 3. ÍNDICES DE RENDIMIENTO
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_business_members_user
    ON public.business_members(user_id);

CREATE INDEX IF NOT EXISTS idx_products_business_active
    ON public.products(business_id, is_active);

CREATE INDEX IF NOT EXISTS idx_balances_product
    ON public.inventory_balances(business_id, product_id);

CREATE INDEX IF NOT EXISTS idx_movements_business_date
    ON public.inventory_movements(business_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_movement_lines_movement
    ON public.inventory_movement_lines(business_id, movement_id);

-- ----------------------------------------------------------------------------
-- 4. TRIGGERS DE SEGURIDAD E INMUTABILIDAD
-- ----------------------------------------------------------------------------

-- A. Control de cambios en encabezado
CREATE OR REPLACE FUNCTION public.guard_inventory_movement_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Los movimientos no pueden eliminarse físicamente. Conserva el historial.';
    END IF;

    IF OLD.status <> 'draft' THEN
        RAISE EXCEPTION 'Solo pueden modificarse movimientos en borrador.';
    END IF;

    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.business_id IS DISTINCT FROM OLD.business_id
       OR NEW.created_by IS DISTINCT FROM OLD.created_by
       OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'No se pueden cambiar los identificadores ni los datos de creación.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS inventory_movements_changes_guard ON public.inventory_movements;
CREATE TRIGGER inventory_movements_changes_guard
BEFORE UPDATE OR DELETE ON public.inventory_movements
FOR EACH ROW EXECUTE FUNCTION public.guard_inventory_movement_changes();

-- B. Control de transición de estado
CREATE OR REPLACE FUNCTION public.guard_inventory_movement_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        IF OLD.status <> 'draft' OR NEW.status NOT IN ('posted', 'cancelled') THEN
            RAISE EXCEPTION 'Transición de estado no permitida.';
        END IF;

        IF NEW.status = 'posted' AND (NEW.posted_by IS NULL OR NEW.posted_at IS NULL) THEN
            RAISE EXCEPTION 'La confirmación requiere usuario y fecha.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS inventory_movements_status_guard ON public.inventory_movements;
CREATE TRIGGER inventory_movements_status_guard
BEFORE UPDATE OF status ON public.inventory_movements
FOR EACH ROW EXECUTE FUNCTION public.guard_inventory_movement_status();

-- C. Salvaguarda de líneas (solo mutables en draft)
CREATE OR REPLACE FUNCTION public.guard_inventory_movement_line()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_business_id uuid;
    v_status text;
BEGIN
    IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
        SELECT m.business_id, m.status
        INTO v_business_id, v_status
        FROM public.inventory_movements AS m
        WHERE m.id = OLD.movement_id
        FOR UPDATE;

        IF NOT FOUND OR v_business_id <> OLD.business_id OR v_status <> 'draft' THEN
            RAISE EXCEPTION 'Solo pueden modificarse líneas de movimientos en borrador.';
        END IF;
    END IF;

    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        SELECT m.business_id, m.status
        INTO v_business_id, v_status
        FROM public.inventory_movements AS m
        WHERE m.id = NEW.movement_id
        FOR UPDATE;

        IF NOT FOUND OR v_business_id <> NEW.business_id OR v_status <> 'draft' THEN
            RAISE EXCEPTION 'La línea debe pertenecer a un movimiento en borrador de la misma empresa.';
        END IF;

        RETURN NEW;
    END IF;

    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS inventory_movement_lines_guard ON public.inventory_movement_lines;
CREATE TRIGGER inventory_movement_lines_guard
BEFORE INSERT OR UPDATE OR DELETE ON public.inventory_movement_lines
FOR EACH ROW EXECUTE FUNCTION public.guard_inventory_movement_line();

-- ----------------------------------------------------------------------------
-- 5. SEGURIDAD Y AISLAMIENTO MULTIEMPRESA (RLS)
-- ----------------------------------------------------------------------------
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_movement_lines ENABLE ROW LEVEL SECURITY;

-- Función de ayuda sin recursión
CREATE OR REPLACE FUNCTION public.is_business_member(p_business_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.business_members AS m
        WHERE m.business_id = p_business_id
          AND m.user_id = (SELECT auth.uid())
    );
$$;

REVOKE ALL ON FUNCTION public.is_business_member(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_business_member(uuid) TO authenticated;

-- Políticas de lectura estricta
DROP POLICY IF EXISTS businesses_member_select ON public.businesses;
CREATE POLICY businesses_member_select ON public.businesses
FOR SELECT TO authenticated
USING (public.is_business_member(id));

DROP POLICY IF EXISTS members_same_business_select ON public.business_members;
CREATE POLICY members_same_business_select ON public.business_members
FOR SELECT TO authenticated
USING (public.is_business_member(business_id));

DROP POLICY IF EXISTS warehouses_member_select ON public.warehouses;
DROP POLICY IF EXISTS warehouses_member_access ON public.warehouses;
CREATE POLICY warehouses_member_select ON public.warehouses
FOR SELECT TO authenticated
USING (public.is_business_member(business_id));

DROP POLICY IF EXISTS products_member_select ON public.products;
DROP POLICY IF EXISTS products_member_access ON public.products;
DROP POLICY IF EXISTS products_admin_insert ON public.products;
DROP POLICY IF EXISTS products_admin_update ON public.products;

CREATE POLICY products_member_select ON public.products
FOR SELECT TO authenticated
USING (public.is_business_member(business_id));

CREATE POLICY products_admin_insert ON public.products
FOR INSERT TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.business_members AS m
        WHERE m.business_id = products.business_id
          AND m.user_id = (SELECT auth.uid())
          AND m.role IN ('owner', 'admin')
    )
);

CREATE POLICY products_admin_update ON public.products
FOR UPDATE TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.business_members AS m
        WHERE m.business_id = products.business_id
          AND m.user_id = (SELECT auth.uid())
          AND m.role IN ('owner', 'admin')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.business_members AS m
        WHERE m.business_id = products.business_id
          AND m.user_id = (SELECT auth.uid())
          AND m.role IN ('owner', 'admin')
    )
);

DROP POLICY IF EXISTS balances_member_select ON public.inventory_balances;
DROP POLICY IF EXISTS balances_member_access ON public.inventory_balances;
CREATE POLICY balances_member_select ON public.inventory_balances
FOR SELECT TO authenticated
USING (public.is_business_member(business_id));

DROP POLICY IF EXISTS movements_member_select ON public.inventory_movements;
DROP POLICY IF EXISTS movements_member_access ON public.inventory_movements;
CREATE POLICY movements_member_select ON public.inventory_movements
FOR SELECT TO authenticated
USING (public.is_business_member(business_id));

DROP POLICY IF EXISTS movement_lines_member_select ON public.inventory_movement_lines;
DROP POLICY IF EXISTS movement_lines_member_access ON public.inventory_movement_lines;
CREATE POLICY movement_lines_member_select ON public.inventory_movement_lines
FOR SELECT TO authenticated
USING (public.is_business_member(business_id));

-- ----------------------------------------------------------------------------
-- 6. FUNCIONES DE SISTEMA Y OPERACIONES DE INVENTARIO
-- ----------------------------------------------------------------------------

-- A. ONBOARDING: Crear Empresa y Asignar Propietario
CREATE OR REPLACE FUNCTION public.create_business(
    p_name text,
    p_legal_name text DEFAULT NULL,
    p_tax_id text DEFAULT NULL,
    p_currency_code char(3) DEFAULT 'MXN'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_business_id uuid;
BEGIN
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Debes iniciar sesión para crear una empresa.';
    END IF;

    IF p_name IS NULL OR pg_catalog.btrim(p_name) = '' THEN
        RAISE EXCEPTION 'El nombre de la empresa es obligatorio.';
    END IF;

    INSERT INTO public.businesses (name, legal_name, tax_id, currency_code)
    VALUES (
        pg_catalog.btrim(p_name),
        NULLIF(pg_catalog.btrim(p_legal_name), ''),
        NULLIF(pg_catalog.btrim(p_tax_id), ''),
        COALESCE(p_currency_code, 'MXN')
    )
    RETURNING id INTO v_business_id;

    INSERT INTO public.business_members (business_id, user_id, role)
    VALUES (v_business_id, v_user_id, 'owner');

    INSERT INTO public.warehouses (business_id, code, name)
    VALUES (v_business_id, 'PRI', 'Almacén Principal');

    RETURN v_business_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_business(text, text, text, char(3)) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_business(text, text, text, char(3)) TO authenticated;

-- B. Crear Movimiento en Borrador
CREATE OR REPLACE FUNCTION public.create_inventory_movement(
    p_business_id uuid,
    p_warehouse_id uuid,
    p_movement_type text,
    p_reason text,
    p_reference text DEFAULT NULL,
    p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_movement_id uuid;
BEGIN
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Debes iniciar sesión.';
    END IF;

    IF p_movement_type NOT IN ('receipt', 'issue', 'adjustment') THEN
        RAISE EXCEPTION 'Tipo de movimiento no válido.';
    END IF;

    IF p_reason IS NULL OR pg_catalog.btrim(p_reason) = '' THEN
        RAISE EXCEPTION 'El motivo es obligatorio.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.businesses AS b
        WHERE b.id = p_business_id AND b.is_active = true
    ) THEN
        RAISE EXCEPTION 'La empresa no existe o está inactiva.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.business_members AS bm
        WHERE bm.business_id = p_business_id
          AND bm.user_id = v_user_id
          AND bm.role IN ('owner', 'admin', 'operator')
    ) THEN
        RAISE EXCEPTION 'No tienes permiso para registrar movimientos.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.warehouses AS w
        WHERE w.id = p_warehouse_id
          AND w.business_id = p_business_id
          AND w.is_active = true
    ) THEN
        RAISE EXCEPTION 'El almacén no existe, está inactivo o no pertenece a la empresa.';
    END IF;

    INSERT INTO public.inventory_movements (
        business_id, warehouse_id, movement_type, status,
        reference, reason, notes, created_by
    )
    VALUES (
        p_business_id,
        p_warehouse_id,
        p_movement_type,
        'draft',
        NULLIF(pg_catalog.btrim(p_reference), ''),
        pg_catalog.btrim(p_reason),
        NULLIF(pg_catalog.btrim(p_notes), ''),
        v_user_id
    )
    RETURNING id INTO v_movement_id;

    RETURN v_movement_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_inventory_movement(uuid, uuid, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_inventory_movement(uuid, uuid, text, text, text, text) TO authenticated;

-- C. Agregar Línea a Movimiento en Borrador
CREATE OR REPLACE FUNCTION public.add_inventory_movement_line(
    p_business_id uuid,
    p_movement_id uuid,
    p_product_id uuid,
    p_quantity numeric DEFAULT NULL,
    p_unit_cost numeric DEFAULT NULL,
    p_physical_count numeric DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_role text;
    v_movement_type text;
    v_status text;
    v_line_id uuid;
BEGIN
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Debes iniciar sesión.';
    END IF;

    SELECT bm.role INTO v_role
    FROM public.business_members AS bm
    WHERE bm.business_id = p_business_id AND bm.user_id = v_user_id;

    IF v_role IS NULL OR v_role NOT IN ('owner', 'admin', 'operator') THEN
        RAISE EXCEPTION 'No tienes permiso para registrar movimientos.';
    END IF;

    SELECT im.movement_type, im.status
    INTO v_movement_type, v_status
    FROM public.inventory_movements AS im
    WHERE im.id = p_movement_id AND im.business_id = p_business_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El movimiento no existe en esta empresa.';
    END IF;

    IF v_status <> 'draft' THEN
        RAISE EXCEPTION 'Solo puedes modificar movimientos en borrador.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.products AS p
        WHERE p.id = p_product_id
          AND p.business_id = p_business_id
          AND p.is_active = true
    ) THEN
        RAISE EXCEPTION 'El producto no existe, está inactivo o no pertenece a la empresa.';
    END IF;

    IF v_movement_type IN ('receipt', 'issue') THEN
        IF p_quantity IS NULL OR p_quantity <= 0 THEN
            RAISE EXCEPTION 'La cantidad debe ser mayor que cero.';
        END IF;

        IF p_physical_count IS NOT NULL THEN
            RAISE EXCEPTION 'La existencia física solo se utiliza en ajustes.';
        END IF;

        IF v_movement_type = 'receipt' THEN
            IF p_unit_cost IS NULL OR p_unit_cost < 0 THEN
                RAISE EXCEPTION 'La entrada requiere un costo unitario igual o mayor que cero.';
            END IF;
        ELSE
            IF p_unit_cost IS NOT NULL THEN
                RAISE EXCEPTION 'El costo de una salida se tomará del costo promedio vigente.';
            END IF;
        END IF;

        INSERT INTO public.inventory_movement_lines (
            business_id, movement_id, product_id,
            quantity, unit_cost, adjustment_direction, physical_count
        )
        VALUES (
            p_business_id, p_movement_id, p_product_id,
            p_quantity, p_unit_cost, NULL, NULL
        )
        RETURNING id INTO v_line_id;

    ELSIF v_movement_type = 'adjustment' THEN
        IF p_physical_count IS NULL OR p_physical_count < 0 THEN
            RAISE EXCEPTION 'Indica una existencia física igual o mayor que cero.';
        END IF;

        IF p_quantity IS NOT NULL OR p_unit_cost IS NOT NULL THEN
            RAISE EXCEPTION 'En ajustes solo debes indicar la existencia física contada.';
        END IF;

        INSERT INTO public.inventory_movement_lines (
            business_id, movement_id, product_id,
            quantity, unit_cost, adjustment_direction, physical_count
        )
        VALUES (
            p_business_id, p_movement_id, p_product_id,
            1, NULL, NULL, p_physical_count
        )
        RETURNING id INTO v_line_id;
    END IF;

    RETURN v_line_id;
END;
$$;

REVOKE ALL ON FUNCTION public.add_inventory_movement_line(uuid, uuid, uuid, numeric, numeric, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_inventory_movement_line(uuid, uuid, uuid, numeric, numeric, numeric) TO authenticated;

-- D. Confirmar Movimiento (post_inventory_movement con Bloqueo Determinista y Auditoría)
CREATE OR REPLACE FUNCTION public.post_inventory_movement(
    p_movement_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_business_id uuid;
    v_warehouse_id uuid;
    v_movement_type text;
    v_status text;
    v_role text;
    v_line record;
    v_stock numeric;
    v_average_cost numeric;
    v_new_stock numeric;
    v_new_average_cost numeric;
    v_difference numeric;
    v_effective_lines integer := 0;
BEGIN
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Debes iniciar sesión.';
    END IF;

    SELECT m.business_id, m.warehouse_id, m.movement_type, m.status
    INTO v_business_id, v_warehouse_id, v_movement_type, v_status
    FROM public.inventory_movements AS m
    WHERE m.id = p_movement_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El movimiento no existe.';
    END IF;

    SELECT bm.role INTO v_role
    FROM public.business_members AS bm
    WHERE bm.business_id = v_business_id AND bm.user_id = v_user_id;

    IF v_role IS NULL OR v_role NOT IN ('owner', 'admin', 'operator') THEN
        RAISE EXCEPTION 'No tienes permiso para confirmar movimientos.';
    END IF;

    IF v_status <> 'draft' THEN
        RAISE EXCEPTION 'Solo pueden confirmarse movimientos en borrador.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.businesses AS b
        WHERE b.id = v_business_id AND b.is_active
    ) THEN
        RAISE EXCEPTION 'La empresa está inactiva.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.warehouses AS w
        WHERE w.id = v_warehouse_id AND w.business_id = v_business_id AND w.is_active
    ) THEN
        RAISE EXCEPTION 'El almacén no existe o está inactivo.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.inventory_movement_lines AS l
        WHERE l.business_id = v_business_id AND l.movement_id = p_movement_id
    ) THEN
        RAISE EXCEPTION 'El movimiento no contiene productos.';
    END IF;

    -- PRE-BLOQUEO DETERMINISTA: Asegurar balances y bloquear ordenados por product_id para evitar deadlocks
    INSERT INTO public.inventory_balances (business_id, warehouse_id, product_id, quantity, average_cost)
    SELECT DISTINCT v_business_id, v_warehouse_id, l.product_id, 0, 0
    FROM public.inventory_movement_lines AS l
    WHERE l.business_id = v_business_id AND l.movement_id = p_movement_id
    ON CONFLICT (business_id, warehouse_id, product_id) DO NOTHING;

    -- Procesar cada línea en orden estricto de product_id
    FOR v_line IN
        SELECT l.id AS line_id, l.product_id, l.quantity, l.unit_cost, l.physical_count
        FROM public.inventory_movement_lines AS l
        WHERE l.business_id = v_business_id AND l.movement_id = p_movement_id
        ORDER BY l.product_id
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM public.products AS p
            WHERE p.id = v_line.product_id AND p.business_id = v_business_id AND p.is_active
        ) THEN
            RAISE EXCEPTION 'Un producto no existe, está inactivo o pertenece a otra empresa.';
        END IF;

        -- Bloquear la fila de balance específica
        SELECT b.quantity, b.average_cost
        INTO v_stock, v_average_cost
        FROM public.inventory_balances AS b
        WHERE b.business_id = v_business_id
          AND b.warehouse_id = v_warehouse_id
          AND b.product_id = v_line.product_id
        FOR UPDATE;

        v_new_stock := v_stock;
        v_new_average_cost := v_average_cost;

        IF v_movement_type = 'receipt' THEN
            IF v_line.quantity IS NULL OR v_line.quantity <= 0 OR v_line.unit_cost IS NULL OR v_line.unit_cost < 0 THEN
                RAISE EXCEPTION 'Línea de entrada inválida.';
            END IF;

            v_new_stock := v_stock + v_line.quantity;
            IF v_new_stock > 0 THEN
                v_new_average_cost := ((v_stock * v_average_cost) + (v_line.quantity * v_line.unit_cost)) / v_new_stock;
            END IF;
            v_effective_lines := v_effective_lines + 1;

        ELSIF v_movement_type = 'issue' THEN
            IF v_line.quantity IS NULL OR v_line.quantity <= 0 THEN
                RAISE EXCEPTION 'Línea de salida inválida.';
            END IF;

            IF v_stock < v_line.quantity THEN
                RAISE EXCEPTION 'Existencias insuficientes para el producto %. Disponible: %, Solicitado: %.',
                    v_line.product_id, v_stock, v_line.quantity;
            END IF;

            v_new_stock := v_stock - v_line.quantity;
            v_effective_lines := v_effective_lines + 1;

        ELSIF v_movement_type = 'adjustment' THEN
            IF v_line.physical_count IS NULL OR v_line.physical_count < 0 THEN
                RAISE EXCEPTION 'Línea de ajuste inválida.';
            END IF;

            v_difference := v_line.physical_count - v_stock;
            v_new_stock := v_line.physical_count;

            IF v_difference > 0 THEN
                UPDATE public.inventory_movement_lines
                SET quantity = v_difference,
                    adjustment_direction = 'increase'
                WHERE id = v_line.line_id;
                v_effective_lines := v_effective_lines + 1;

            ELSIF v_difference < 0 THEN
                UPDATE public.inventory_movement_lines
                SET quantity = pg_catalog.abs(v_difference),
                    adjustment_direction = 'decrease'
                WHERE id = v_line.line_id;
                v_effective_lines := v_effective_lines + 1;

            ELSE
                -- CONTEO EXACTO: Conservar registro de auditoría con cantidad 0 y dirección 'none'
                UPDATE public.inventory_movement_lines
                SET quantity = 0,
                    adjustment_direction = 'none'
                WHERE id = v_line.line_id;
            END IF;
        ELSE
            RAISE EXCEPTION 'Tipo de movimiento no válido.';
        END IF;

        -- Actualizar trazabilidad de línea
        UPDATE public.inventory_movement_lines
        SET stock_before = v_stock,
            stock_after = v_new_stock,
            applied_unit_cost = CASE WHEN v_movement_type = 'receipt' THEN v_line.unit_cost ELSE v_average_cost END
        WHERE id = v_line.line_id;

        -- Actualizar saldo de inventario
        UPDATE public.inventory_balances
        SET quantity = v_new_stock,
            average_cost = v_new_average_cost,
            updated_at = pg_catalog.now()
        WHERE business_id = v_business_id
          AND warehouse_id = v_warehouse_id
          AND product_id = v_line.product_id;
    END LOOP;

    -- Si fue ajuste y ninguna línea tuvo discrepancia física
    IF v_movement_type = 'adjustment' AND v_effective_lines = 0 THEN
        -- Se permite la confirmación documental del conteo físico sin error destructivo,
        -- asegurando que la auditoría física queda grabada con fecha y responsable.
        NULL;
    END IF;

    UPDATE public.inventory_movements
    SET status = 'posted',
        posted_by = v_user_id,
        posted_at = pg_catalog.now()
    WHERE id = p_movement_id
      AND business_id = v_business_id
      AND status = 'draft';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No fue posible confirmar el movimiento.';
    END IF;

    RETURN p_movement_id;
END;
$$;

REVOKE ALL ON FUNCTION public.post_inventory_movement(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.post_inventory_movement(uuid) TO authenticated;

-- E. Revertir Movimiento Confirmado
CREATE OR REPLACE FUNCTION public.reverse_inventory_movement(
    p_movement_id uuid,
    p_reason text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_business_id uuid;
    v_warehouse_id uuid;
    v_type text;
    v_status text;
    v_role text;
    v_reversal_type text;
    v_reversal_id uuid;
    v_line record;
    v_stock numeric;
BEGIN
    v_user_id := (SELECT auth.uid());
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Debes iniciar sesión.';
    END IF;

    IF p_reason IS NULL OR pg_catalog.btrim(p_reason) = '' THEN
        RAISE EXCEPTION 'Indica el motivo de la reversión.';
    END IF;

    SELECT m.business_id, m.warehouse_id, m.movement_type, m.status
    INTO v_business_id, v_warehouse_id, v_type, v_status
    FROM public.inventory_movements AS m
    WHERE m.id = p_movement_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El movimiento no existe.';
    END IF;

    SELECT bm.role INTO v_role
    FROM public.business_members AS bm
    WHERE bm.business_id = v_business_id AND bm.user_id = v_user_id;

    IF v_role IS NULL OR v_role NOT IN ('owner', 'admin', 'operator') THEN
        RAISE EXCEPTION 'No tienes permiso para revertir movimientos.';
    END IF;

    IF v_status <> 'posted' THEN
        RAISE EXCEPTION 'Solo pueden revertirse movimientos confirmados.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.inventory_movements AS m
        WHERE m.business_id = v_business_id AND m.reversal_of = p_movement_id
    ) THEN
        RAISE EXCEPTION 'Este movimiento ya tiene una reversión.';
    END IF;

    IF v_type = 'receipt' THEN
        v_reversal_type := 'issue';
    ELSIF v_type = 'issue' THEN
        v_reversal_type := 'receipt';
    ELSE
        v_reversal_type := 'adjustment';
    END IF;

    -- Validaciones para reversión de ajuste
    IF v_type = 'adjustment' THEN
        FOR v_line IN
            SELECT l.product_id, l.stock_before, l.stock_after
            FROM public.inventory_movement_lines AS l
            WHERE l.business_id = v_business_id
              AND l.movement_id = p_movement_id
              AND l.adjustment_direction IN ('increase', 'decrease')
            ORDER BY l.product_id
        LOOP
            IF v_line.stock_before IS NULL OR v_line.stock_after IS NULL THEN
                RAISE EXCEPTION 'No hay trazabilidad suficiente para revertir este ajuste histórico.';
            END IF;

            SELECT b.quantity INTO v_stock
            FROM public.inventory_balances AS b
            WHERE b.business_id = v_business_id
              AND b.warehouse_id = v_warehouse_id
              AND b.product_id = v_line.product_id
            FOR UPDATE;

            IF NOT FOUND OR v_stock <> v_line.stock_after THEN
                RAISE EXCEPTION 'El inventario del producto % cambió desde el ajuste. No se puede revertir automáticamente.',
                    v_line.product_id;
            END IF;
        END LOOP;
    END IF;

    -- Salida solo reversible si se guardó el costo aplicado
    IF v_type = 'issue' AND EXISTS (
        SELECT 1 FROM public.inventory_movement_lines AS l
        WHERE l.business_id = v_business_id
          AND l.movement_id = p_movement_id
          AND l.applied_unit_cost IS NULL
    ) THEN
        RAISE EXCEPTION 'Este movimiento histórico no tiene costos suficientes para una reversión segura.';
    END IF;

    -- Crear cabecera inversa
    INSERT INTO public.inventory_movements (
        business_id, warehouse_id, movement_type, status,
        reference, reason, notes, created_by, reversal_of
    )
    SELECT
        m.business_id, m.warehouse_id, v_reversal_type, 'draft',
        m.reference, pg_catalog.btrim(p_reason),
        'Reversión del movimiento ' || m.id::text,
        v_user_id, m.id
    FROM public.inventory_movements AS m
    WHERE m.id = p_movement_id AND m.business_id = v_business_id
    RETURNING id INTO v_reversal_id;

    -- Copiar líneas invertidas
    IF v_type IN ('receipt', 'issue') THEN
        INSERT INTO public.inventory_movement_lines (
            business_id, movement_id, product_id,
            quantity, unit_cost, physical_count
        )
        SELECT
            l.business_id, v_reversal_id, l.product_id, l.quantity,
            CASE WHEN v_type = 'issue' THEN l.applied_unit_cost ELSE NULL END,
            NULL
        FROM public.inventory_movement_lines AS l
        WHERE l.business_id = v_business_id AND l.movement_id = p_movement_id;
    ELSE
        INSERT INTO public.inventory_movement_lines (
            business_id, movement_id, product_id,
            quantity, unit_cost, physical_count
        )
        SELECT
            l.business_id, v_reversal_id, l.product_id, 1, NULL, l.stock_before
        FROM public.inventory_movement_lines AS l
        WHERE l.business_id = v_business_id
          AND l.movement_id = p_movement_id
          AND l.adjustment_direction IN ('increase', 'decrease')
          AND l.stock_before IS NOT NULL;
    END IF;

    -- Confirmar automáticamente el movimiento inverso
    PERFORM public.post_inventory_movement(v_reversal_id);

    RETURN v_reversal_id;
END;
$$;

REVOKE ALL ON FUNCTION public.reverse_inventory_movement(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reverse_inventory_movement(uuid, text) TO authenticated;