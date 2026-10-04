
BEGIN;

-- Eliminar las políticas generales que permiten ALL.
DROP POLICY IF EXISTS warehouses_member_access
    ON public.warehouses;

DROP POLICY IF EXISTS products_member_access
    ON public.products;

DROP POLICY IF EXISTS balances_member_access
    ON public.inventory_balances;

DROP POLICY IF EXISTS movements_member_access
    ON public.inventory_movements;

DROP POLICY IF EXISTS movement_lines_member_access
    ON public.inventory_movement_lines;

-- Crear políticas explícitas de lectura para miembros.
CREATE POLICY warehouses_member_select
ON public.warehouses
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.business_members m
        WHERE m.business_id = warehouses.business_id
          AND m.user_id = (SELECT auth.uid())
    )
);

CREATE POLICY products_member_select
ON public.products
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.business_members m
        WHERE m.business_id = products.business_id
          AND m.user_id = (SELECT auth.uid())
    )
);

CREATE POLICY balances_member_select
ON public.inventory_balances
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.business_members m
        WHERE m.business_id = inventory_balances.business_id
          AND m.user_id = (SELECT auth.uid())
    )
);

CREATE POLICY movements_member_select
ON public.inventory_movements
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.business_members m
        WHERE m.business_id = inventory_movements.business_id
          AND m.user_id = (SELECT auth.uid())
    )
);

CREATE POLICY movement_lines_member_select
ON public.inventory_movement_lines
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.business_members m
        WHERE m.business_id = inventory_movement_lines.business_id
          AND m.user_id = (SELECT auth.uid())
    )
);

COMMIT;
