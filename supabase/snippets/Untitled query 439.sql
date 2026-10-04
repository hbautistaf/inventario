
SELECT
    grantee,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN ('anon', 'authenticated')
  AND table_name IN (
      'inventory_movements',
      'inventory_movement_lines',
      'inventory_balances'
  )
ORDER BY table_name, grantee, privilege_type;
