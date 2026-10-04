
SELECT
    p.proname AS funcion,
    pg_get_function_identity_arguments(p.oid) AS argumentos,
    pg_get_userbyid(p.proowner) AS propietario,
    p.prosecdef AS security_definer
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
      p.proname ILIKE '%business%'
      OR p.proname ILIKE '%member%'
      OR p.proname ILIKE '%company%'
  )
ORDER BY p.proname;
