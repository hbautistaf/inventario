
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
    v_processed_lines integer := 0;
BEGIN
    v_user_id := (SELECT auth.uid());

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Debes iniciar sesión.';
    END IF;

    SELECT
        m.business_id,
        m.warehouse_id,
        m.movement_type,
        m.status
    INTO
        v_business_id,
        v_warehouse_id,
        v_movement_type,
        v_status
    FROM public.inventory_movements AS m
    WHERE m.id = p_movement_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El movimiento no existe.';
    END IF;

    SELECT bm.role
    INTO v_role
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
        SELECT 1
        FROM public.businesses AS b
        WHERE b.id = v_business_id
          AND b.is_active = true
    ) THEN
        RAISE EXCEPTION 'La empresa está inactiva.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.warehouses AS w
        WHERE w.id = v_warehouse_id
          AND w.business_id = v_business_id
          AND w.is_active = true
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
        SELECT
            l.id AS line_id,
            l.product_id,
            l.quantity,
            l.unit_cost,
            l.physical_count
        FROM public.inventory_movement_lines AS l
        WHERE l.business_id = v_business_id
          AND l.movement_id = p_movement_id
        ORDER BY l.product_id
    LOOP
        v_processed_lines := v_processed_lines + 1;

        IF NOT EXISTS (
            SELECT 1
            FROM public.products AS p
            WHERE p.id = v_line.product_id
              AND p.business_id = v_business_id
              AND p.is_active = true
        ) THEN
            RAISE EXCEPTION
                'Un producto no existe, está inactivo o pertenece a otra empresa.';
        END IF;

        IF v_movement_type = 'receipt' THEN
            IF v_line.quantity IS NULL
               OR v_line.quantity <= 0
               OR v_line.unit_cost IS NULL
               OR v_line.unit_cost < 0
               OR v_line.physical_count IS NOT NULL THEN
                RAISE EXCEPTION 'Una línea de entrada tiene datos inválidos.';
            END IF;

        ELSIF v_movement_type = 'issue' THEN
            IF v_line.quantity IS NULL
               OR v_line.quantity <= 0
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
            business_id,
            warehouse_id,
            product_id,
            quantity,
            average_cost
        )
        VALUES (
            v_business_id,
            v_warehouse_id,
            v_line.product_id,
            0,
            0
        )
        ON CONFLICT (business_id, warehouse_id, product_id)
        DO NOTHING;

        SELECT
            b.quantity,
            b.average_cost
        INTO
            v_stock,
            v_average_cost
        FROM public.inventory_balances AS b
        WHERE b.business_id = v_business_id
          AND b.warehouse_id = v_warehouse_id
          AND b.product_id = v_line.product_id
        FOR UPDATE;

        IF v_movement_type = 'receipt' THEN
            v_new_stock := v_stock + v_line.quantity;

            IF v_new_stock > 0 THEN
                v_new_average_cost :=
                    (
                        v_stock * v_average_cost
                        + v_line.quantity * v_line.unit_cost
                    ) / v_new_stock;
            ELSE
                v_new_average_cost := 0;
            END IF;

        ELSIF v_movement_type = 'issue' THEN
            IF v_stock < v_line.quantity THEN
                RAISE EXCEPTION
                    'Existencias insuficientes para el producto %. Disponible: %, solicitado: %.',
                    v_line.product_id, v_stock, v_line.quantity;
            END IF;

            v_new_stock := v_stock - v_line.quantity;
            v_new_average_cost := v_average_cost;

        ELSE
            v_difference := v_line.physical_count - v_stock;

            IF v_difference > 0 THEN
                v_new_stock := v_line.physical_count;
                v_new_average_cost := v_average_cost;

                UPDATE public.inventory_movement_lines
                SET quantity = v_difference,
                    adjustment_direction = 'increase'
                WHERE id = v_line.line_id;

            ELSIF v_difference < 0 THEN
                v_new_stock := v_line.physical_count;
                v_new_average_cost := v_average_cost;

                UPDATE public.inventory_movement_lines
                SET quantity = abs(v_difference),
                    adjustment_direction = 'decrease'
                WHERE id = v_line.line_id;

            ELSE
                -- Conteo sin diferencia: no altera las existencias.
                v_new_stock := v_stock;
                v_new_average_cost := v_average_cost;

                UPDATE public.inventory_movement_lines
                SET adjustment_direction = NULL
                WHERE id = v_line.line_id;
            END IF;
        END IF;

        UPDATE public.inventory_balances
        SET quantity = v_new_stock,
            average_cost = v_new_average_cost,
            updated_at = pg_catalog.now()
        WHERE business_id = v_business_id
          AND warehouse_id = v_warehouse_id
          AND product_id = v_line.product_id;
    END LOOP;

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
