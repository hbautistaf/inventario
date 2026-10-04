SELECT
    table_name,
    grantee,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN (
      'businesses',
      'business_members',
      'warehouses',
      'products',
      'inventory_balances',
      'inventory_movements',
      'inventory_movement_lines'
  )
  AND grantee IN ('anon', 'authenticated')
ORDER BY grantee, table_name, privilege_type;