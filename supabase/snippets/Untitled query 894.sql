
SELECT
    p.proname AS function_name,
    pg_get_userbyid(p.proowner) AS function_owner,
    p.prosecdef AS security_definer
FROM pg_proc AS p
JOIN pg_namespace AS n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
      'create_inventory_movement',
      'add_inventory_movement_line',
      'post_inventory_movement'
  )
ORDER BY p.proname;
