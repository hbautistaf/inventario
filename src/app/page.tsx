import { createClient } from '@/utils/supabase/server';
import { loginQuickAction, signOutAction } from '@/app/actions/auth';
import { createBusinessAction } from '@/app/actions/business';
import { createProductAction, registerMovementAction } from '@/app/actions/inventory';
import { KardexModal, type KardexEntry } from '@/app/components/KardexModal';

export default async function HomePage() {
  const supabase = await createClient();

  // 1. Obtener usuario actual
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Si no hay usuario autenticado, mostrar pantalla de inicio de sesión de prueba
  if (!user) {
    return (
      <main className="min-h-screen bg-slate-950 text-slate-100 flex items-center justify-center p-6">
        <div className="w-full max-w-md bg-slate-900 border border-slate-800 rounded-2xl p-8 shadow-2xl">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-10 h-10 rounded-xl bg-blue-600 flex items-center justify-center font-bold text-white shadow-lg shadow-blue-500/30">
              IU
            </div>
            <div>
              <h1 className="text-xl font-bold tracking-tight">Inventario Universal</h1>
              <p className="text-xs text-slate-400">Entorno Local Supabase</p>
            </div>
          </div>

          <p className="text-sm text-slate-300 mb-6">
            Inicia sesión o crea una cuenta para acceder a tu panel de inventario multiempresa.
          </p>

          <form action={loginQuickAction} className="space-y-4">
            <div>
              <label className="block text-xs font-semibold text-slate-400 mb-1">
                Correo Electrónico
              </label>
              <input
                type="email"
                name="email"
                defaultValue="admin@inventario.local"
                required
                className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-blue-500"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-400 mb-1">
                Contraseña
              </label>
              <input
                type="password"
                name="password"
                defaultValue="Admin123456!"
                required
                className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-blue-500"
              />
            </div>

            <button
              type="submit"
              className="w-full bg-blue-600 hover:bg-blue-500 text-white font-medium py-2.5 rounded-lg text-sm transition-colors shadow-lg shadow-blue-600/20"
            >
              Iniciar Sesión / Registrarse
            </button>
          </form>
        </div>
      </main>
    );
  }

  // 2. Consultar empresas a las que pertenece el usuario
  const { data: businesses } = await supabase
    .from('businesses')
    .select('*, warehouses(*)')
    .order('created_at', { ascending: false });

  // Si no tiene empresa registrada, mostrar pantalla de onboarding
  if (!businesses || businesses.length === 0) {
    return (
      <main className="min-h-screen bg-slate-950 text-slate-100 flex items-center justify-center p-6">
        <div className="w-full max-w-lg bg-slate-900 border border-slate-800 rounded-2xl p-8 shadow-2xl">
          <div className="flex items-center justify-between mb-6">
            <span className="px-3 py-1 bg-amber-500/10 text-amber-400 border border-amber-500/20 rounded-full text-xs font-medium">
              Onboarding Necesario
            </span>
            <form action={signOutAction}>
              <button className="text-xs text-slate-400 hover:text-slate-200">Cerrar sesión</button>
            </form>
          </div>

          <h2 className="text-2xl font-bold mb-2">Crea tu Primera Empresa</h2>
          <p className="text-sm text-slate-400 mb-6">
            Bienvenido, <span className="text-slate-200 font-medium">{user.email}</span>. Para
            comenzar a gestionar productos y existencias, registra los datos de tu empresa. Te
            asignaremos automáticamente como propietario (<code className="text-blue-400">owner</code>).
          </p>

          <form action={createBusinessAction} className="space-y-4">
            <div>
              <label className="block text-xs font-semibold text-slate-400 mb-1">
                Nombre de la Empresa *
              </label>
              <input
                type="text"
                name="name"
                placeholder="Ej. Distribuidora El Sol"
                required
                className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-blue-500"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-400 mb-1">
                Razón Social (Opcional)
              </label>
              <input
                type="text"
                name="legal_name"
                placeholder="Ej. Distribuidora El Sol S.A. de C.V."
                className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-blue-500"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-semibold text-slate-400 mb-1">RFC / Tax ID</label>
                <input
                  type="text"
                  name="tax_id"
                  placeholder="XAXX010101000"
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-blue-500"
                />
              </div>
              <div>
                <label className="block text-xs font-semibold text-slate-400 mb-1">Moneda</label>
                <select
                  name="currency_code"
                  defaultValue="MXN"
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-blue-500"
                >
                  <option value="MXN">MXN (Pesos)</option>
                  <option value="USD">USD (Dólares)</option>
                  <option value="EUR">EUR (Euros)</option>
                </select>
              </div>
            </div>

            <button
              type="submit"
              className="w-full mt-2 bg-blue-600 hover:bg-blue-500 text-white font-medium py-2.5 rounded-lg text-sm transition-colors shadow-lg shadow-blue-600/20"
            >
              Inicializar Empresa y Almacén
            </button>
          </form>
        </div>
      </main>
    );
  }

  // 3. Empresa activa y datos
  const currentBusiness = businesses[0];
  const currentWarehouse = currentBusiness.warehouses?.[0];

  // Consultar productos de la empresa
  const { data: products } = await supabase
    .from('products')
    .select('*')
    .eq('business_id', currentBusiness.id)
    .order('created_at', { ascending: false });

  // Consultar existencias actuales
  const { data: balances } = await supabase
    .from('inventory_balances')
    .select('*, product:products(name, sku, unit)')
    .eq('business_id', currentBusiness.id);

  // Consultar historial de movimientos para el Kárdex
  const { data: rawKardex } = await supabase
    .from('inventory_movement_lines')
    .select(`
      id,
      movement_id,
      product_id,
      quantity,
      unit_cost,
      applied_unit_cost,
      stock_before,
      stock_after,
      physical_count,
      adjustment_direction,
      created_at,
      movement:inventory_movements(
        movement_type,
        status,
        reference,
        reason,
        posted_at
      ),
      product:products(
        sku,
        name,
        unit
      )
    `)
    .eq('business_id', currentBusiness.id)
    .order('created_at', { ascending: false });

  type RawItem = NonNullable<typeof rawKardex>[number];

  const kardexEntries: KardexEntry[] = (rawKardex || []).map((item: RawItem) => {
    const mov = Array.isArray(item.movement) ? item.movement[0] : item.movement;
    const prod = Array.isArray(item.product) ? item.product[0] : item.product;

    return {
      line_id: item.id,
      movement_id: item.movement_id,
      product_id: item.product_id,
      product_sku: prod?.sku || '',
      product_name: prod?.name || '',
      product_unit: prod?.unit || 'pieza',
      movement_type: (mov?.movement_type || 'receipt') as 'receipt' | 'issue' | 'adjustment',
      status: mov?.status || 'posted',
      reference: mov?.reference || null,
      reason: mov?.reason || '',
      posted_at: mov?.posted_at || null,
      quantity: Number(item.quantity),
      unit_cost: item.unit_cost !== null ? Number(item.unit_cost) : null,
      applied_unit_cost: item.applied_unit_cost !== null ? Number(item.applied_unit_cost) : null,
      stock_before: Number(item.stock_before || 0),
      stock_after: Number(item.stock_after || 0),
      adjustment_direction: item.adjustment_direction || null,
    };
  });

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100">
      {/* Barra de Navegación Superior */}
      <header className="border-b border-slate-800 bg-slate-900/60 backdrop-blur px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="w-9 h-9 rounded-xl bg-blue-600 flex items-center justify-center font-bold text-white shadow-md shadow-blue-500/20">
            IU
          </div>
          <div>
            <h1 className="font-semibold text-sm leading-tight">{currentBusiness.name}</h1>
            <p className="text-xs text-slate-400">
              Almacén: <span className="text-slate-200">{currentWarehouse?.name || 'PRI'}</span>
            </p>
          </div>
        </div>

        <div className="flex items-center gap-4">
          <span className="text-xs text-slate-400">{user.email}</span>
          <form action={signOutAction}>
            <button className="text-xs text-slate-400 hover:text-red-400 transition-colors">
              Cerrar Sesión
            </button>
          </form>
        </div>
      </header>

      {/* Contenido Principal */}
      <main className="max-w-7xl mx-auto p-6 space-y-8">
        {/* Sección de Existencias */}
        <section className="bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-xl">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
            <div>
              <h2 className="text-lg font-bold">Existencias y Costos Promedio Ponderados</h2>
              <p className="text-xs text-slate-400">
                Saldos valorados en tiempo real por almacén
              </p>
            </div>

            <KardexModal
              entries={kardexEntries}
              products={(products || []).map((p) => ({
                id: p.id,
                sku: p.sku,
                name: p.name,
              }))}
            />
          </div>

          {!balances || balances.length === 0 ? (
            <div className="text-center py-10 border border-dashed border-slate-800 rounded-xl">
              <p className="text-sm text-slate-400">No hay movimientos registrados aún.</p>
              <p className="text-xs text-slate-500 mt-1">
                Registra un producto y su primera entrada de inventario a continuación.
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="text-xs uppercase bg-slate-950/50 text-slate-400 border-b border-slate-800">
                  <tr>
                    <th className="py-3 px-4">SKU</th>
                    <th className="py-3 px-4">Producto</th>
                    <th className="py-3 px-4 text-right">Existencia</th>
                    <th className="py-3 px-4 text-right">Costo Promedio (CPP)</th>
                    <th className="py-3 px-4 text-right">Valor Total</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800">
                  {balances.map((b) => (
                    <tr key={b.product_id} className="hover:bg-slate-800/30 transition-colors">
                      <td className="py-3 px-4 font-mono text-xs text-slate-400">
                        {b.product?.sku}
                      </td>
                      <td className="py-3 px-4 font-medium">{b.product?.name}</td>
                      <td className="py-3 px-4 text-right font-mono font-semibold text-emerald-400">
                        {Number(b.quantity).toFixed(2)} {b.product?.unit}
                      </td>
                      <td className="py-3 px-4 text-right font-mono text-slate-300">
                        ${Number(b.average_cost).toFixed(4)}
                      </td>
                      <td className="py-3 px-4 text-right font-mono font-semibold text-slate-100">
                        ${(Number(b.quantity) * Number(b.average_cost)).toFixed(2)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>

        {/* Formularios Operativos */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Formulario 1: Alta de Producto */}
          <section className="bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-xl">
            <h3 className="font-bold text-base mb-1">Registrar Producto en Catálogo</h3>
            <p className="text-xs text-slate-400 mb-4">
              Agrega artículos para controlar entradas y salidas
            </p>

            <form action={createProductAction} className="space-y-3">
              <input type="hidden" name="business_id" value={currentBusiness.id} />

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1">SKU *</label>
                  <input
                    type="text"
                    name="sku"
                    placeholder="PROD-001"
                    required
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1">Unidad</label>
                  <input
                    type="text"
                    name="unit"
                    defaultValue="pieza"
                    required
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-blue-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-400 mb-1">Nombre *</label>
                <input
                  type="text"
                  name="name"
                  placeholder="Nombre comercial del producto"
                  required
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-blue-500"
                />
              </div>

              <button
                type="submit"
                className="w-full bg-slate-800 hover:bg-slate-700 text-slate-100 font-medium py-2 rounded-lg text-sm transition-colors mt-2"
              >
                Guardar Producto
              </button>
            </form>
          </section>

          {/* Formulario 2: Movimiento de Inventario */}
          <section className="bg-slate-900 border border-slate-800 rounded-2xl p-6 shadow-xl">
            <h3 className="font-bold text-base mb-1">Operación de Inventario</h3>
            <p className="text-xs text-slate-400 mb-4">
              Registra una Entrada (recalcula CPP) o Salida (valida stock)
            </p>

            {(!products || products.length === 0) ? (
              <div className="text-sm text-slate-500 py-6 text-center">
                Primero registra al menos un producto a la izquierda.
              </div>
            ) : (
              <form action={registerMovementAction} className="space-y-3">
                <input type="hidden" name="business_id" value={currentBusiness.id} />
                <input type="hidden" name="warehouse_id" value={currentWarehouse?.id} />

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-semibold text-slate-400 mb-1">Tipo *</label>
                    <select
                      name="movement_type"
                      defaultValue="receipt"
                      className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-blue-500"
                    >
                      <option value="receipt">Entrada (Receipt)</option>
                      <option value="issue">Salida (Issue)</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-400 mb-1">
                      Producto *
                    </label>
                    <select
                      name="product_id"
                      required
                      className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-blue-500"
                    >
                      {products.map((p) => (
                        <option key={p.id} value={p.id}>
                          {p.sku} - {p.name}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-semibold text-slate-400 mb-1">
                      Cantidad *
                    </label>
                    <input
                      type="number"
                      name="quantity"
                      step="0.01"
                      min="0.01"
                      placeholder="10"
                      required
                      className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-blue-500"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-400 mb-1">
                      Costo Unitario ($)
                    </label>
                    <input
                      type="number"
                      name="unit_cost"
                      step="0.0001"
                      min="0"
                      placeholder="Solo para entradas"
                      className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-blue-500"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1">Motivo</label>
                  <input
                    type="text"
                    name="reason"
                    placeholder="Ej. Compra a proveedor / Venta al público"
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-blue-500"
                  />
                </div>

                <button
                  type="submit"
                  className="w-full bg-emerald-600 hover:bg-emerald-500 text-white font-medium py-2 rounded-lg text-sm transition-colors shadow-lg shadow-emerald-600/20 mt-2"
                >
                  Confirmar y Procesar Movimiento
                </button>
              </form>
            )}
          </section>
        </div>
      </main>
    </div>
  );
}
