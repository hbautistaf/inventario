
-- =========================================================
-- Inventario Universal 1.0
-- Migracion inicial: empresas, productos e inventario
-- =========================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------
-- 1. Empresas
-- ---------------------------------------------------------
CREATE TABLE public.businesses (
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

-- ---------------------------------------------------------
-- 2. Usuarios y pertenencia a empresas
-- ---------------------------------------------------------
CREATE TABLE public.business_members (
    business_id uuid NOT NULL
        REFERENCES public.businesses(id),
    user_id uuid NOT NULL
        REFERENCES auth.users(id),
    role text NOT NULL DEFAULT 'operator',
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (business_id, user_id),
    CONSTRAINT business_members_role_check
        CHECK (role IN ('owner', 'admin', 'operator', 'viewer'))
);

-- ---------------------------------------------------------
-- 3. Almacenes
-- ---------------------------------------------------------
CREATE TABLE public.warehouses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL
        REFERENCES public.businesses(id),
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

-- ---------------------------------------------------------
-- 4. Productos
-- ---------------------------------------------------------
CREATE TABLE public.products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL
        REFERENCES public.businesses(id),
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

-- ---------------------------------------------------------
-- 5. Saldos de inventario
-- El costo promedio se expresa por unidad de inventario.
-- ---------------------------------------------------------
CREATE TABLE public.inventory_balances (
    business_id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity numeric(18,4) NOT NULL DEFAULT 0,
    average_cost numeric(18,6) NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT now(),

    PRIMARY KEY (business_id, warehouse_id, product_id),

    FOREIGN KEY (business_id, warehouse_id)
        REFERENCES public.warehouses(business_id, id),

    FOREIGN KEY (business_id, product_id)
        REFERENCES public.products(business_id, id),

    CONSTRAINT inventory_quantity_nonnegative
        CHECK (quantity >= 0),

    CONSTRAINT inventory_average_cost_nonnegative
        CHECK (average_cost >= 0)
);

-- ---------------------------------------------------------
-- 6. Encabezados de movimientos
-- ---------------------------------------------------------
CREATE TABLE public.inventory_movements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL
        REFERENCES public.businesses(id),
    warehouse_id uuid NOT NULL,
    movement_type text NOT NULL,
    status text NOT NULL DEFAULT 'draft',
    reference text,
    reason text NOT NULL,
    notes text,
    created_by uuid REFERENCES auth.users(id),
    posted_by uuid REFERENCES auth.users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    posted_at timestamptz,

    UNIQUE (business_id, id),

    FOREIGN KEY (business_id, warehouse_id)
        REFERENCES public.warehouses(business_id, id),

    CONSTRAINT inventory_movement_type_check
        CHECK (movement_type IN ('receipt', 'issue', 'adjustment')),

    CONSTRAINT inventory_movement_status_check
        CHECK (status IN ('draft', 'posted', 'cancelled')),

    CONSTRAINT inventory_movement_reason_not_empty
        CHECK (length(trim(reason)) > 0)
);

-- ---------------------------------------------------------
-- 7. Detalle de movimientos
-- ---------------------------------------------------------
CREATE TABLE public.inventory_movement_lines (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL,
    movement_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity numeric(18,4) NOT NULL,
    unit_cost numeric(18,6),
    created_at timestamptz NOT NULL DEFAULT now(),

    FOREIGN KEY (business_id, movement_id)
        REFERENCES public.inventory_movements(business_id, id),

    FOREIGN KEY (business_id, product_id)
        REFERENCES public.products(business_id, id),

    CONSTRAINT inventory_line_quantity_positive
        CHECK (quantity > 0),

    CONSTRAINT inventory_line_cost_nonnegative
        CHECK (unit_cost IS NULL OR unit_cost >= 0)
);

-- ---------------------------------------------------------
-- 8. Índices para consultas frecuentes
-- ---------------------------------------------------------
CREATE INDEX idx_business_members_user
    ON public.business_members(user_id);

CREATE INDEX idx_products_business_active
    ON public.products(business_id, is_active);

CREATE INDEX idx_balances_product
    ON public.inventory_balances(business_id, product_id);

CREATE INDEX idx_movements_business_date
    ON public.inventory_movements(business_id, created_at DESC);

CREATE INDEX idx_movement_lines_movement
    ON public.inventory_movement_lines(business_id, movement_id);

-- ---------------------------------------------------------
-- 9. Aislamiento multiempresa mediante RLS
-- ---------------------------------------------------------
ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_movement_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY businesses_member_select
ON public.businesses
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.business_members m
        WHERE m.business_id = businesses.id
          AND m.user_id = (SELECT auth.uid())
    )
);

CREATE POLICY members_same_business_select
ON public.business_members
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.business_members mine
        WHERE mine.business_id = business_members.business_id
          AND mine.user_id = (SELECT auth.uid())
    )
);

CREATE POLICY warehouses_member_access
ON public.warehouses
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.business_members m
        WHERE m.business_id = warehouses.business_id
          AND m.user_id = (SELECT auth.uid())
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.business_members m
        WHERE m.business_id = warehouses.business_id
          AND m.user_id = (SELECT auth.uid())
    )
);

CREATE POLICY products_member_access
ON public.products
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.business_members m
        WHERE m.business_id = products.business_id
          AND m.user_id = (SELECT auth.uid())
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.business_members m
        WHERE m.business_id = products.business_id
          AND m.user_id = (SELECT auth.uid())
    )
);

CREATE POLICY balances_member_access
ON public.inventory_balances
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.business_members m
        WHERE m.business_id = inventory_balances.business_id
          AND m.user_id = (SELECT auth.uid())
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.business_members m
        WHERE m.business_id = inventory_balances.business_id
          AND m.user_id = (SELECT auth.uid())
    )
);

CREATE POLICY movements_member_access
ON public.inventory_movements
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.business_members m
        WHERE m.business_id = inventory_movements.business_id
          AND m.user_id = (SELECT auth.uid())
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.business_members m
        WHERE m.business_id = inventory_movements.business_id
          AND m.user_id = (SELECT auth.uid())
    )
);

CREATE POLICY movement_lines_member_access
ON public.inventory_movement_lines
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.business_members m
        WHERE m.business_id = inventory_movement_lines.business_id
          AND m.user_id = (SELECT auth.uid())
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.business_members m
        WHERE m.business_id = inventory_movement_lines.business_id
          AND m.user_id = (SELECT auth.uid())
    )
);