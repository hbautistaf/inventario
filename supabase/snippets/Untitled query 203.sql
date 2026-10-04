
CREATE OR REPLACE FUNCTION public.guard_inventory_movement_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'Los movimientos no pueden eliminarse físicamente. Conserva el historial.';
    END IF;

    IF OLD.status <> 'draft' THEN
        RAISE EXCEPTION
            'Solo pueden modificarse movimientos en borrador.';
    END IF;

    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.business_id IS DISTINCT FROM OLD.business_id
       OR NEW.created_by IS DISTINCT FROM OLD.created_by
       OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION
            'No se pueden cambiar los identificadores ni los datos de creación.';
    END IF;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.guard_inventory_movement_changes()
FROM PUBLIC, anon, authenticated;

CREATE TRIGGER inventory_movements_changes_guard
BEFORE UPDATE OR DELETE
ON public.inventory_movements
FOR EACH ROW
EXECUTE FUNCTION public.guard_inventory_movement_changes();
