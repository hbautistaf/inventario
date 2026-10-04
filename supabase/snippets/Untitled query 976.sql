
-- 1. Estado de las funciones y permisos
SELECT
    p.proname AS funcion,
    pg_get_userbyid(p.proowner) AS propietario,
    p.prosecdef AS security_definer,
    has_function_privilege(
        'authenticated',
        p.oid,
        'EXECUTE'
    ) AS authenticated_puede_ejecutar,
    has_function_privilege(
        'anon',
        p.oid,
        'EXECUTE'
    ) AS anon_puede_ejecutar
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
      'create_inventory_movement',
      'add_inventory_movement_line',
      'post_inventory_movement',
      'reverse_inventory_movement'
  )
ORDER BY p.proname;

-- 2. Triggers habilitados
SELECT
    c.relname AS tabla,
    t.tgname AS trigger,
    t.tgenabled AS habilitado
FROM pg_trigger AS t
JOIN pg_class AS c ON c.oid = t.tgrelid
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
      'inventory_movements',
      'inventory_movement_lines'
  )
  AND NOT t.tgisinternal
ORDER BY c.relname, t.tgname;

-- 3. Campos de trazabilidad
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'inventory_movement_lines'
  AND column_name IN (
      'stock_before',
      'stock_after',
      'applied_unit_cost'
  )
ORDER BY column_name;
