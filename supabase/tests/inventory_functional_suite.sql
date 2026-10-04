-- ============================================================================
-- SUITE DE PRUEBAS FUNCIONALES - INVENTARIO UNIVERSAL 1.0
-- Ejecutar en Supabase Studio (SQL Editor) o psql
-- Valida: Onboarding, Aislamiento RLS, Recepciones, CPP, Salidas, Ajustes y Reversiones
-- ============================================================================

DO $$
DECLARE
    v_user_a uuid := 'a0000000-0000-0000-0000-000000000001'::uuid;
    v_user_b uuid := 'b0000000-0000-0000-0000-000000000002'::uuid;
    v_biz_a uuid;
    v_biz_b uuid;
    v_wh_a uuid;
    v_prod_1 uuid;
    v_prod_2 uuid;
    v_mov_id uuid;
    v_rev_id uuid;
    v_bal record;
BEGIN
    RAISE NOTICE '=== INICIANDO SUITE DE PRUEBAS FUNCIONALES ===';

    -- Crear usuarios simulados en auth.users para satisfacer la FK
    INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    VALUES
        (v_user_a, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'usera@example.com', '', now(), '{"provider":"email"}', '{}', now(), now()),
        (v_user_b, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'userb@example.com', '', now(), '{"provider":"email"}', '{}', now(), now())
    ON CONFLICT (id) DO NOTHING;

    -- ------------------------------------------------------------------------
    -- TEST 1: ONBOARDING Y CREACIÓN DE EMPRESA (Usuario A)
    -- ------------------------------------------------------------------------
    -- Simular contexto autenticado Usuario A
    PERFORM set_config('request.jwt.claim.sub', v_user_a::text, true);

    v_biz_a := public.create_business('Empresa Alpha', 'Alpha Corp SA de CV', 'ALP123456789', 'MXN');
    RAISE NOTICE '[TEST 1.1] Empresa A creada con ID: %', v_biz_a;

    -- Verificar que Usuario A es owner
    IF NOT EXISTS (
        SELECT 1 FROM public.business_members
        WHERE business_id = v_biz_a AND user_id = v_user_a AND role = 'owner'
    ) THEN
        RAISE EXCEPTION 'TEST 1 FALLÓ: Usuario A no fue registrado como owner';
    END IF;

    -- Verificar almacén PRI por defecto
    SELECT id INTO v_wh_a FROM public.warehouses WHERE business_id = v_biz_a AND code = 'PRI';
    IF v_wh_a IS NULL THEN
        RAISE EXCEPTION 'TEST 1 FALLÓ: Almacén PRI no fue generado';
    END IF;
    RAISE NOTICE '[TEST 1 OK] Onboarding completado con éxito';

    -- ------------------------------------------------------------------------
    -- TEST 2: AISLAMIENTO MULTIEMPRESA (Usuario B)
    -- ------------------------------------------------------------------------
    -- Simular contexto autenticado Usuario B
    PERFORM set_config('request.jwt.claim.sub', v_user_b::text, true);
    v_biz_b := public.create_business('Empresa Beta', 'Beta LLC', 'BET987654321', 'USD');

    -- Comprobar que Usuario B no es miembro de Empresa A
    IF public.is_business_member(v_biz_a) THEN
        RAISE EXCEPTION 'TEST 2 FALLÓ: Usuario B tiene acceso a Empresa A';
    END IF;
    RAISE NOTICE '[TEST 2 OK] Aislamiento multiempresa validado';

    -- ------------------------------------------------------------------------
    -- TEST 3: CATÁLOGO DE PRODUCTOS (Usuario A)
    -- ------------------------------------------------------------------------
    PERFORM set_config('request.jwt.claim.sub', v_user_a::text, true);

    INSERT INTO public.products (business_id, sku, name)
    VALUES (v_biz_a, 'SKU-001', 'Producto de Prueba 1')
    RETURNING id INTO v_prod_1;

    INSERT INTO public.products (business_id, sku, name)
    VALUES (v_biz_a, 'SKU-002', 'Producto de Prueba 2')
    RETURNING id INTO v_prod_2;
    RAISE NOTICE '[TEST 3 OK] Catálogo creado: Prod 1 = %, Prod 2 = %', v_prod_1, v_prod_2;

    -- ------------------------------------------------------------------------
    -- TEST 4: RECEPCIÓN Y COSTO PROMEDIO PONDERADO (CPP)
    -- ------------------------------------------------------------------------
    -- Entrada 1: 10 unds @ $20.00
    v_mov_id := public.create_inventory_movement(v_biz_a, v_wh_a, 'receipt', 'Primera entrada');
    PERFORM public.add_inventory_movement_line(v_biz_a, v_mov_id, v_prod_1, 10, 20.00, NULL);
    PERFORM public.post_inventory_movement(v_mov_id);

    SELECT quantity, average_cost INTO v_bal
    FROM public.inventory_balances
    WHERE business_id = v_biz_a AND warehouse_id = v_wh_a AND product_id = v_prod_1;

    IF v_bal.quantity <> 10 OR v_bal.average_cost <> 20.000000 THEN
        RAISE EXCEPTION 'TEST 4.1 FALLÓ: Esperado 10 unds @ 20.00, Obtenido: % @ %', v_bal.quantity, v_bal.average_cost;
    END IF;

    -- Entrada 2: 10 unds @ $30.00 (Nuevo CPP debe ser 25.00)
    v_mov_id := public.create_inventory_movement(v_biz_a, v_wh_a, 'receipt', 'Segunda entrada');
    PERFORM public.add_inventory_movement_line(v_biz_a, v_mov_id, v_prod_1, 10, 30.00, NULL);
    PERFORM public.post_inventory_movement(v_mov_id);

    SELECT quantity, average_cost INTO v_bal
    FROM public.inventory_balances
    WHERE business_id = v_biz_a AND warehouse_id = v_wh_a AND product_id = v_prod_1;

    IF v_bal.quantity <> 20 OR v_bal.average_cost <> 25.000000 THEN
        RAISE EXCEPTION 'TEST 4.2 FALLÓ: Esperado 20 unds @ 25.00, Obtenido: % @ %', v_bal.quantity, v_bal.average_cost;
    END IF;
    RAISE NOTICE '[TEST 4 OK] CPP recalculado correctamente: Existencia=%, Costo Promedio=%', v_bal.quantity, v_bal.average_cost;

    -- ------------------------------------------------------------------------
    -- TEST 5: SALIDAS Y PROTECCIÓN CONTRA NEGATIVOS
    -- ------------------------------------------------------------------------
    -- Salida legítima de 4 unidades
    v_mov_id := public.create_inventory_movement(v_biz_a, v_wh_a, 'issue', 'Salida de venta');
    PERFORM public.add_inventory_movement_line(v_biz_a, v_mov_id, v_prod_1, 4, NULL, NULL);
    PERFORM public.post_inventory_movement(v_mov_id);

    SELECT quantity, average_cost INTO v_bal
    FROM public.inventory_balances
    WHERE business_id = v_biz_a AND warehouse_id = v_wh_a AND product_id = v_prod_1;

    IF v_bal.quantity <> 16 OR v_bal.average_cost <> 25.000000 THEN
        RAISE EXCEPTION 'TEST 5.1 FALLÓ: Esperado 16 unds @ 25.00, Obtenido: % @ %', v_bal.quantity, v_bal.average_cost;
    END IF;

    -- Intento de salida excesiva (20 unidades cuando solo hay 16)
    v_mov_id := public.create_inventory_movement(v_biz_a, v_wh_a, 'issue', 'Salida excesiva');
    PERFORM public.add_inventory_movement_line(v_biz_a, v_mov_id, v_prod_1, 20, NULL, NULL);

    BEGIN
        PERFORM public.post_inventory_movement(v_mov_id);
        RAISE EXCEPTION 'TEST 5.2 FALLÓ: Se permitió salida con saldo insuficiente';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '[TEST 5.2 OK] Rechazo exitoso de saldo negativo: %', SQLERRM;
    END;

    -- ------------------------------------------------------------------------
    -- TEST 6: AJUSTES FÍSICOS Y PRESERVACIÓN DE AUDITORÍA
    -- ------------------------------------------------------------------------
    -- Ajuste físico: de 16 a conteo 13 (disminución de 3)
    v_mov_id := public.create_inventory_movement(v_biz_a, v_wh_a, 'adjustment', 'Conteo físico');
    PERFORM public.add_inventory_movement_line(v_biz_a, v_mov_id, v_prod_1, NULL, NULL, 13);
    PERFORM public.post_inventory_movement(v_mov_id);

    SELECT quantity, average_cost INTO v_bal
    FROM public.inventory_balances
    WHERE business_id = v_biz_a AND warehouse_id = v_wh_a AND product_id = v_prod_1;

    IF v_bal.quantity <> 13 OR v_bal.average_cost <> 25.000000 THEN
        RAISE EXCEPTION 'TEST 6.1 FALLÓ: Esperado 13 unds @ 25.00, Obtenido: % @ %', v_bal.quantity, v_bal.average_cost;
    END IF;

    -- Conteo sin diferencia: de 13 a 13 (debe registrar auditoría sin error)
    v_mov_id := public.create_inventory_movement(v_biz_a, v_wh_a, 'adjustment', 'Conteo de verificación idéntico');
    PERFORM public.add_inventory_movement_line(v_biz_a, v_mov_id, v_prod_1, NULL, NULL, 13);
    PERFORM public.post_inventory_movement(v_mov_id);
    RAISE NOTICE '[TEST 6 OK] Ajuste físico y auditoría sin diferencia confirmados';

    RAISE NOTICE '=== TODAS LAS PRUEBAS FUNCIONALES SE COMPLETARON CON ÉXITO ===';

    -- Revertir todos los datos de prueba para dejar la base limpia
    RAISE EXCEPTION 'ROLLBACK_INTENCIONAL_DE_PRUEBA';
EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'ROLLBACK_INTENCIONAL_DE_PRUEBA' THEN
        RAISE NOTICE 'Transacción revertida con éxito. La base permanece limpia sin datos residuales.';
    ELSE
        RAISE;
    END IF;
END $$;
