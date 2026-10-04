
CREATE OR REPLACE FUNCTION public.guard_inventory_movement_status()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        IF OLD.status <> 'draft'
           OR NEW.status NOT IN ('posted', 'cancelled') THEN
            RAISE EXCEPTION
                'Transición de estado no permitida.';
        END IF;

        IF NEW.status = 'posted'
           AND (
               NEW.posted_by IS NULL
               OR NEW.posted_at IS NULL
           ) THEN
            RAISE EXCEPTION
                'La confirmación requiere usuario y fecha.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.guard_inventory_movement_status()
FROM PUBLIC, anon, authenticated;

CREATE TRIGGER inventory_movements_status_guard
BEFORE UPDATE OF status
ON public.inventory_movements
FOR EACH ROW
EXECUTE FUNCTION public.guard_inventory_movement_status();
