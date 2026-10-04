
SELECT pg_get_functiondef(
    'public.create_inventory_movement(uuid, uuid, text, text, text, text)'::regprocedure
);
