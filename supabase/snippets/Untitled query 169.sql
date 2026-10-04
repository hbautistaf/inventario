
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

    SELECT bm.role
    INTO v_role
    FROM public.business_members AS bm
    WHERE bm.business_id = p_business_id
      AND bm.user_id = v_user_id;

    IF v_role IS NULL OR v_role NOT IN ('owner', 'admin', 'operator') THEN
        RAISE EXCEPTION 'No tienes permiso para registrar movimientos.';
    END IF;

    SELECT im.movement_type, im.status
    INTO v_movement_type, v_status
    FROM public.inventory_movements AS im
    WHERE im.id = p_movement_id
      AND im.business_id = p_business_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El movimiento no existe en esta empresa.';
    END IF;

    IF v_status <> 'draft' THEN
        RAISE EXCEPTION 'Solo puedes modificar movimientos en borrador.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.products AS p
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
            business_id,
            movement_id,
            product_id,
            quantity,
            unit_cost,
            adjustment_direction,
            physical_count
        )
        VALUES (
            p_business_id,
            p_movement_id,
            p_product_id,
            p_quantity,
            p_unit_cost,
            NULL,
            NULL
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
            business_id,
            movement_id,
            product_id,
            quantity,
            unit_cost,
            adjustment_direction,
            physical_count
        )
        VALUES (
            p_business_id,
            p_movement_id,
            p_product_id,
            1,
            NULL,
            NULL,
            p_physical_count
        )
        RETURNING id INTO v_line_id;
    END IF;

    RETURN v_line_id;
END;
$$;

REVOKE ALL ON FUNCTION public.add_inventory_movement_line(
    uuid, uuid, uuid, numeric, numeric, numeric
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.add_inventory_movement_line(
    uuid, uuid, uuid, numeric, numeric, numeric
) TO authenticated;
