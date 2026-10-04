
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

        IF NOT FOUND
           OR v_business_id <> OLD.business_id
           OR v_status <> 'draft' THEN
            RAISE EXCEPTION
                'Solo pueden modificarse líneas de movimientos en borrador.';
        END IF;
    END IF;

    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        SELECT m.business_id, m.status
        INTO v_business_id, v_status
        FROM public.inventory_movements AS m
        WHERE m.id = NEW.movement_id
        FOR UPDATE;

        IF NOT FOUND
           OR v_business_id <> NEW.business_id
           OR v_status <> 'draft' THEN
            RAISE EXCEPTION
                'La línea debe pertenecer a un movimiento en borrador de la misma empresa.';
        END IF;

        RETURN NEW;
    END IF;

    RETURN OLD;
END;
$$;

REVOKE ALL ON FUNCTION public.guard_inventory_movement_line()
FROM PUBLIC, anon, authenticated;

CREATE TRIGGER inventory_movement_lines_guard
BEFORE INSERT OR UPDATE OR DELETE
ON public.inventory_movement_lines
FOR EACH ROW
EXECUTE FUNCTION public.guard_inventory_movement_line();
