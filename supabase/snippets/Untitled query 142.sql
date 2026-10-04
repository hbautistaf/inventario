
BEGIN;

-- 1. Retirar todos los privilegios directos del rol anon.
REVOKE ALL PRIVILEGES ON TABLE
    public.businesses,
    public.business_members,
    public.warehouses,
    public.products,
    public.inventory_balances,
    public.inventory_movements,
    public.inventory_movement_lines
FROM anon;

-- 2. Retirar los privilegios directos de authenticated.
REVOKE ALL PRIVILEGES ON TABLE
    public.businesses,
    public.business_members,
    public.warehouses,
    public.products,
    public.inventory_balances,
    public.inventory_movements,
    public.inventory_movement_lines
FROM authenticated;

-- 3. Permitir consultas a usuarios autenticados.
-- Las políticas RLS seguirán filtrando los registros accesibles.
GRANT SELECT ON TABLE
    public.businesses,
    public.business_members,
    public.warehouses,
    public.products,
    public.inventory_balances,
    public.inventory_movements,
    public.inventory_movement_lines
TO authenticated;

COMMIT;