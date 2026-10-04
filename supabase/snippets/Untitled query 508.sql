
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
        SELECT 1
        FROM public.businesses AS b
        WHERE b.id = p_business_id
          AND b.is_active = true
    ) THEN
        RAISE EXCEPTION 'La empresa no existe o está inactiva.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.business_members AS bm
        WHERE bm.business_id = p_business_id
          AND bm.user_id = v_user_id
          AND bm.role IN ('owner', 'admin', 'operator')
    ) THEN
        RAISE EXCEPTION 'No tienes permiso para registrar movimientos.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.warehouses AS w
        WHERE w.id = p_warehouse_id
          AND w.business_id = p_business_id
          AND w.is_active = true
    ) THEN
        RAISE EXCEPTION 'El almacén no existe, está inactivo o no pertenece a la empresa.';
    END IF;

    INSERT INTO public.inventory_movements (
        business_id,
        warehouse_id,
        movement_type,
        status,
        reference,
        reason,
        notes,
        created_by
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

REVOKE ALL ON FUNCTION public.create_inventory_movement(
    uuid, uuid, text, text, text, text
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.create_inventory_movement(
    uuid, uuid, text, text, text, text
) TO authenticated;
