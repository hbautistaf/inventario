
SELECT
    t.tgname AS trigger_name,
    t.tgenabled AS enabled_status,
    p.proname AS trigger_function,
    pg_get_userbyid(p.proowner) AS function_owner
FROM pg_trigger AS t
JOIN pg_class AS c
    ON c.oid = t.tgrelid
JOIN pg_namespace AS n
    ON n.oid = c.relnamespace
JOIN pg_proc AS p
    ON p.oid = t.tgfoid
WHERE n.nspname = 'public'
  AND c.relname = 'inventory_movement_lines'
  AND NOT t.tgisinternal;
