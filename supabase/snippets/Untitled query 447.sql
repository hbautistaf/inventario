
BEGIN;

-- =========================================================
-- 1. Campos de trazabilidad por línea
-- =========================================================

ALTER TABLE public.inventory_movement_lines
    ADD COLUMN IF NOT EXISTS stock_before numeric,
    ADD COLUMN IF NOT EXISTS stock_after numeric,
    ADD COLUMN IF NOT EXISTS applied_unit_cost numeric;

ALTER TABLE public.inventory_movement_lines
    DROP CONSTRAINT IF EXISTS inventory_line_stock_before_nonnegative;

ALTER TABLE public.inventory_movement_lines
    ADD CONSTRAINT inventory_line_stock_before_nonnegative
    CHECK (stock_before IS NULL OR stock_before >= 0);

ALTER TABLE public.inventory_movement_lines
    DROP CONSTRAINT IF EXISTS inventory_line_stock_after_nonnegative;

ALTER TABLE public.inventory_movement_lines
    ADD CONSTRAINT inventory_line_stock_after_nonnegative
    CHECK (stock_after IS NULL OR stock_after >= 0);

ALTER TABLE public.inventory_movement_lines
    DROP CONSTRAINT IF EXISTS inventory_line_applied_cost_nonnegative;

ALTER TABLE public.inventory_movement_lines
    ADD CONSTRAINT inventory_line_applied_cost_nonnegative
    CHECK (applied_unit_cost IS NULL OR applied_unit_cost >= 0);


-- =========================================================
-- 2. Confirmación con trazabilidad de existencias y costos
-- =========================================================

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

    SELECT m.business_id, m.warehouse_id,
           m.movement_type, m.status
    INTO v_business_id, v_warehouse_id,
         v_movement_type, v_status
    FROM public.inventory_movements AS m
    WHERE m.id = p_movement_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El movimiento no existe.';
    END IF;

    SELECT bm.role INTO v_role
    FROM public.business_members AS bm
    WHERE bm.business_id = v_business_id
      AND bm.user_id = v_user_id;

    IF v_role IS NULL
       OR v_role NOT IN ('owner', 'admin', 'operator') THEN
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
        WHERE w.id = v_warehouse_id
          AND w.business_id = v_business_id
          AND w.is_active
    ) THEN
        RAISE EXCEPTION 'El almacén no existe o está inactivo.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.inventory_movement_lines AS l
        WHERE l.business_id = v_business_id
          AND l.movement_id = p_movement_id
    ) THEN
        RAISE EXCEPTION 'El movimiento no contiene productos.';
    END IF;

    FOR v_line IN
        SELECT l.id AS line_id, l.product_id, l.quantity,
               l.unit_cost, l.physical_count
        FROM public.inventory_movement_lines AS l
        WHERE l.business_id = v_business_id
          AND l.movement_id = p_movement_id
        ORDER BY l.product_id
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM public.products AS p
            WHERE p.id = v_line.product_id
              AND p.business_id = v_business_id
              AND p.is_active
        ) THEN
            RAISE EXCEPTION
                'Un producto no existe, está inactivo o pertenece a otra empresa.';
        END IF;

        IF v_movement_type = 'receipt' THEN
            IF v_line.quantity IS NULL OR v_line.quantity <= 0
               OR v_line.unit_cost IS NULL OR v_line.unit_cost < 0
               OR v_line.physical_count IS NOT NULL THEN
                RAISE EXCEPTION 'Una línea de entrada tiene datos inválidos.';
            END IF;
        ELSIF v_movement_type = 'issue' THEN
            IF v_line.quantity IS NULL OR v_line.quantity <= 0
               OR v_line.unit_cost IS NOT NULL
               OR v_line.physical_count IS NOT NULL THEN
                RAISE EXCEPTION 'Una línea de salida tiene datos inválidos.';
            END IF;
        ELSIF v_movement_type = 'adjustment' THEN
            IF v_line.physical_count IS NULL
               OR v_line.physical_count < 0
               OR v_line.unit_cost IS NOT NULL THEN
                RAISE EXCEPTION 'Una línea de ajuste tiene datos inválidos.';
            END IF;
        ELSE
            RAISE EXCEPTION 'Tipo de movimiento no válido.';
        END IF;

        INSERT INTO public.inventory_balances (
            business_id, warehouse_id, product_id,
            quantity, average_cost
        )
        VALUES (
            v_business_id, v_warehouse_id, v_line.product_id, 0, 0
        )
        ON CONFLICT (business_id, warehouse_id, product_id)
        DO NOTHING;

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
            v_new_stock := v_stock + v_line.quantity;

            v_new_average_cost :=
                (v_stock * v_average_cost
                 + v_line.quantity * v_line.unit_cost)
                / v_new_stock;

            v_effective_lines := v_effective_lines + 1;

        ELSIF v_movement_type = 'issue' THEN
            IF v_stock < v_line.quantity THEN
                RAISE EXCEPTION
                    'Existencias insuficientes para el producto %. Disponible: %, solicitado: %.',
                    v_line.product_id, v_stock, v_line.quantity;
            END IF;

            v_new_stock := v_stock - v_line.quantity;
            v_effective_lines := v_effective_lines + 1;

        ELSE
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
                SET quantity = abs(v_difference),
                    adjustment_direction = 'decrease'
                WHERE id = v_line.line_id;

                v_effective_lines := v_effective_lines + 1;
            END IF;
        END IF;

        UPDATE public.inventory_movement_lines
        SET stock_before = v_stock,
            stock_after = v_new_stock,
            applied_unit_cost =
                CASE
                    WHEN v_movement_type = 'receipt'
                        THEN v_line.unit_cost
                    ELSE v_average_cost
                END
        WHERE id = v_line.line_id;

        UPDATE public.inventory_balances
        SET quantity = v_new_stock,
            average_cost = v_new_average_cost,
            updated_at = pg_catalog.now()
        WHERE business_id = v_business_id
          AND warehouse_id = v_warehouse_id
          AND product_id = v_line.product_id;
    END LOOP;

    IF v_movement_type = 'adjustment'
       AND v_effective_lines = 0 THEN
        RAISE EXCEPTION
            'El conteo no presenta diferencias; no se generó el ajuste.';
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

REVOKE ALL ON FUNCTION public.post_inventory_movement(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.post_inventory_movement(uuid)
TO authenticated;


-- =========================================================
-- 3. Reversión de movimientos confirmados
-- =========================================================

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

    SELECT m.business_id, m.warehouse_id,
           m.movement_type, m.status
    INTO v_business_id, v_warehouse_id, v_type, v_status
    FROM public.inventory_movements AS m
    WHERE m.id = p_movement_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El movimiento no existe.';
    END IF;

    SELECT bm.role INTO v_role
    FROM public.business_members AS bm
    WHERE bm.business_id = v_business_id
      AND bm.user_id = v_user_id;

    IF v_role IS NULL
       OR v_role NOT IN ('owner', 'admin', 'operator') THEN
        RAISE EXCEPTION 'No tienes permiso para revertir movimientos.';
    END IF;

    IF v_status <> 'posted' THEN
        RAISE EXCEPTION 'Solo pueden revertirse movimientos confirmados.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.inventory_movements AS m
        WHERE m.business_id = v_business_id
          AND m.reversal_of = p_movement_id
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

    -- Para revertir ajustes necesitamos conocer los saldos originales
    -- y confirmar que no hayan cambiado desde entonces.
    IF v_type = 'adjustment' THEN
        FOR v_line IN
            SELECT l.product_id, l.stock_before, l.stock_after
            FROM public.inventory_movement_lines AS l
            WHERE l.business_id = v_business_id
              AND l.movement_id = p_movement_id
              AND l.adjustment_direction IS NOT NULL
            ORDER BY l.product_id
        LOOP
            IF v_line.stock_before IS NULL
               OR v_line.stock_after IS NULL THEN
                RAISE EXCEPTION
                    'No hay trazabilidad suficiente para revertir este ajuste histórico.';
            END IF;

            SELECT b.quantity INTO v_stock
            FROM public.inventory_balances AS b
            WHERE b.business_id = v_business_id
              AND b.warehouse_id = v_warehouse_id
              AND b.product_id = v_line.product_id
            FOR UPDATE;

            IF NOT FOUND OR v_stock <> v_line.stock_after THEN
                RAISE EXCEPTION
                    'El inventario del producto % cambió desde el ajuste. No se puede revertir automáticamente.',
                    v_line.product_id;
            END IF;
        END LOOP;
    END IF;

    -- Las salidas originales solo pueden revertirse si se guardó
    -- su costo aplicado al confirmar.
    IF v_type = 'issue' AND EXISTS (
        SELECT 1
        FROM public.inventory_movement_lines AS l
        WHERE l.business_id = v_business_id
          AND l.movement_id = p_movement_id
          AND l.applied_unit_cost IS NULL
    ) THEN
        RAISE EXCEPTION
            'Este movimiento histórico no tiene costos suficientes para una reversión segura.';
    END IF;

    INSERT INTO public.inventory_movements (
        business_id, warehouse_id, movement_type, status,
        reference, reason, notes, created_by, reversal_of
    )
    SELECT
        m.business_id,
        m.warehouse_id,
        v_reversal_type,
        'draft',
        m.reference,
        pg_catalog.btrim(p_reason),
        'Reversión del movimiento ' || m.id::text,
        v_user_id,
        m.id
    FROM public.inventory_movements AS m
    WHERE m.id = p_movement_id
      AND m.business_id = v_business_id
    RETURNING id INTO v_reversal_id;

    IF v_type IN ('receipt', 'issue') THEN
        INSERT INTO public.inventory_movement_lines (
            business_id, movement_id, product_id,
            quantity, unit_cost, physical_count
        )
        SELECT
            l.business_id,
            v_reversal_id,
            l.product_id,
            l.quantity,
            CASE
                WHEN v_type = 'issue' THEN l.applied_unit_cost
                ELSE NULL
            END,
            NULL
        FROM public.inventory_movement_lines AS l
        WHERE l.business_id = v_business_id
          AND l.movement_id = p_movement_id;

    ELSE
        INSERT INTO public.inventory_movement_lines (
            business_id, movement_id, product_id,
            quantity, unit_cost, physical_count
        )
        SELECT
            l.business_id,
            v_reversal_id,
            l.product_id,
            1,
            NULL,
            l.stock_before
        FROM public.inventory_movement_lines AS l
        WHERE l.business_id = v_business_id
          AND l.movement_id = p_movement_id
          AND l.adjustment_direction IS NOT NULL
          AND l.stock_before IS NOT NULL;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'No existen líneas de ajuste con trazabilidad suficiente para revertir.';
        END IF;
    END IF;

    PERFORM public.post_inventory_movement(v_reversal_id);

    RETURN v_reversal_id;
END;
$$;

REVOKE ALL ON FUNCTION public.reverse_inventory_movement(uuid, text)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.reverse_inventory_movement(uuid, text)
TO authenticated;

COMMIT;
