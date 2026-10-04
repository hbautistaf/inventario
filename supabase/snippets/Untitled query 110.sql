
SELECT
    has_table_privilege(
        'postgres',
        'public.inventory_movements',
        'INSERT'
    ) AS postgres_can_insert_movements,
    has_table_privilege(
        'authenticated',
        'public.inventory_movements',
        'INSERT'
    ) AS authenticated_can_insert_movements;
