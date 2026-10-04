
-- 1. Confirmar funciones instaladas
SELECT
    p.proname AS funcion,
    pg_get_userbyid(p.proowner) AS propietario,
    p.prosecdef AS security_definer,
    has_function_privilege(
        'authenticated', p.oid, 'EXECUTE'
    ) AS ejecutable_por_authenticated,
    has_function_privilege(
        'anon', p.oid, 'EXECUTE'
    ) AS ejecutable_por_anon
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
      'create_inventory_movement',
      'add_inventory_movement_line',
      'post_inventory_movement',
      'reverse_inventory_movement'
  )
ORDER BY p.proname;

-- 2. Revisar si existen datos de prueba
SELECT
    (SELECT count(*) FROM public.businesses) AS empresas,
    (SELECT count(*) FROM public.business_members) AS miembros,
    (SELECT count(*) FROM public.warehouses) AS almacenes,
    (SELECT count(*) FROM public.products) AS productos,
    (SELECT count(*) FROM public.inventory_movements) AS movimientos,
    (SELECT count(*) FROM public.inventory_movement_lines) AS lineas,
    (SELECT count(*) FROM public.inventory_balances) AS existencias;
