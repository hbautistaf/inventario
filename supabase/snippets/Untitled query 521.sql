
-- 1. Funciones del motor de inventario
SELECT
    p.proname AS funcion,
    pg_get_function_identity_arguments(p.oid) AS argumentos,
    pg_get_userbyid(p.proowner) AS propietario,
    p.prosecdef AS security_definer,
    p.proconfig AS configuracion,
    pg_get_functiondef(p.oid) AS definicion
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
      'is_business_member',
      'create_inventory_movement',
      'add_inventory_movement_line',
      'post_inventory_movement',
      'guard_inventory_movement_line',
      'guard_inventory_movement_status',
      'guard_inventory_movement_changes'
  )
ORDER BY p.proname;

-- 2. Permisos efectivos declarados para las tablas
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
ORDER BY table_name, grantee, privilege_type;

-- 3. Políticas RLS
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
      'businesses',
      'business_members',
      'warehouses',
      'products',
      'inventory_balances',
      'inventory_movements',
      'inventory_movement_lines'
  )
ORDER BY tablename, policyname;

-- 4. Restricciones de integridad
SELECT
    c.relname AS tabla,
    con.conname AS restriccion,
    con.contype AS tipo,
    pg_get_constraintdef(con.oid) AS definicion
FROM pg_constraint AS con
JOIN pg_class AS c ON c.oid = con.conrelid
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
      'businesses',
      'business_members',
      'warehouses',
      'products',
      'inventory_balances',
      'inventory_movements',
      'inventory_movement_lines'
  )
ORDER BY c.relname, con.conname;
