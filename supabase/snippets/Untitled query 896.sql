
SELECT
    p.proname AS function_name,
    r.rolname AS function_owner,
    p.prosecdef AS security_definer,
    p.proconfig AS function_settings
FROM pg_proc AS p
JOIN pg_roles AS r
    ON r.oid = p.proowner
JOIN pg_namespace AS n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'create_inventory_movement';
