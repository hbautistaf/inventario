'use client';

import { useState } from 'react';

export interface KardexEntry {
  line_id: string;
  movement_id: string;
  product_id: string;
  product_sku: string;
  product_name: string;
  product_unit: string;
  movement_type: 'receipt' | 'issue' | 'adjustment';
  status: string;
  reference: string | null;
  reason: string;
  posted_at: string | null;
  quantity: number;
  unit_cost: number | null;
  applied_unit_cost: number | null;
  stock_before: number;
  stock_after: number;
  adjustment_direction: string | null;
}

interface KardexModalProps {
  entries: KardexEntry[];
  products: { id: string; sku: string; name: string }[];
}

export function KardexModal({ entries, products }: KardexModalProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [selectedProductId, setSelectedProductId] = useState<string>('all');
  const [typeFilter, setTypeFilter] = useState<string>('all');

  const filteredEntries = entries.filter((item) => {
    if (selectedProductId !== 'all' && item.product_id !== selectedProductId) {
      return false;
    }
    if (typeFilter !== 'all' && item.movement_type !== typeFilter) {
      return false;
    }
    return true;
  });

  return (
    <>
      <button
        onClick={() => setIsOpen(true)}
        className="px-3.5 py-1.5 bg-blue-600/10 hover:bg-blue-600/20 text-blue-400 border border-blue-500/30 rounded-lg text-xs font-semibold flex items-center gap-2 transition-colors shadow-sm"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1-2.5-2.5Z" />
          <path d="M6 6h10" />
          <path d="M6 10h10" />
          <path d="M6 14h10" />
        </svg>
        Ver Kárdex / Historial de Movimientos
      </button>

      {isOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm animate-in fade-in duration-200">
          <div className="bg-slate-900 border border-slate-800 w-full max-w-6xl max-h-[90vh] rounded-2xl shadow-2xl flex flex-col overflow-hidden">
            {/* Header */}
            <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-900/80">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-lg bg-blue-600/20 text-blue-400 flex items-center justify-center border border-blue-500/30 font-bold text-xs">
                  KD
                </div>
                <div>
                  <h3 className="font-bold text-base text-slate-100">
                    Kárdex Valorado de Inventario
                  </h3>
                  <p className="text-xs text-slate-400">
                    Trazabilidad inmutable de entradas, salidas y saldos resultantes
                  </p>
                </div>
              </div>

              <button
                onClick={() => setIsOpen(false)}
                className="text-slate-400 hover:text-slate-100 p-1.5 rounded-lg hover:bg-slate-800 transition-colors"
                aria-label="Cerrar modal"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="18"
                  height="18"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <line x1="18" y1="6" x2="6" y2="18"></line>
                  <line x1="6" y1="6" x2="18" y2="18"></line>
                </svg>
              </button>
            </div>

            {/* Filtros */}
            <div className="p-4 bg-slate-950/40 border-b border-slate-800/80 flex flex-wrap items-center gap-4 text-xs">
              <div className="flex items-center gap-2">
                <span className="text-slate-400 font-medium">Filtrar Producto:</span>
                <select
                  value={selectedProductId}
                  onChange={(e) => setSelectedProductId(e.target.value)}
                  className="bg-slate-950 border border-slate-800 text-slate-200 rounded-lg px-2.5 py-1.5 focus:outline-none focus:border-blue-500"
                >
                  <option value="all">Todos los productos</option>
                  {products.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.sku} - {p.name}
                    </option>
                  ))}
                </select>
              </div>

              <div className="flex items-center gap-2">
                <span className="text-slate-400 font-medium">Tipo:</span>
                <select
                  value={typeFilter}
                  onChange={(e) => setTypeFilter(e.target.value)}
                  className="bg-slate-950 border border-slate-800 text-slate-200 rounded-lg px-2.5 py-1.5 focus:outline-none focus:border-blue-500"
                >
                  <option value="all">Todos los tipos</option>
                  <option value="receipt">Solo Entradas (Receipt)</option>
                  <option value="issue">Solo Salidas (Issue)</option>
                  <option value="adjustment">Solo Ajustes Físicos</option>
                </select>
              </div>

              <div className="ml-auto text-slate-400">
                Mostrando <span className="font-semibold text-slate-200">{filteredEntries.length}</span> transacciones
              </div>
            </div>

            {/* Tabla Kárdex */}
            <div className="overflow-auto flex-1 p-4">
              {filteredEntries.length === 0 ? (
                <div className="text-center py-12 text-slate-500 text-sm">
                  No se encontraron movimientos con los filtros seleccionados.
                </div>
              ) : (
                <table className="w-full text-left text-xs">
                  <thead className="bg-slate-950/70 uppercase text-slate-400 border-b border-slate-800 sticky top-0 backdrop-blur">
                    <tr>
                      <th className="py-2.5 px-3">Fecha / Hora</th>
                      <th className="py-2.5 px-3">Tipo</th>
                      <th className="py-2.5 px-3">Ref / Motivo</th>
                      <th className="py-2.5 px-3">Producto</th>
                      <th className="py-2.5 px-3 text-right">Cant. Movimiento</th>
                      <th className="py-2.5 px-3 text-right">Costo Aplicado</th>
                      <th className="py-2.5 px-3 text-right">Stock Anterior</th>
                      <th className="py-2.5 px-3 text-right text-emerald-400 font-bold">
                        Stock Resultante
                      </th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800/60 font-mono">
                    {filteredEntries.map((row) => {
                      const isReceipt = row.movement_type === 'receipt';
                      const isIssue = row.movement_type === 'issue';

                      return (
                        <tr
                          key={row.line_id}
                          className="hover:bg-slate-800/40 transition-colors"
                        >
                          <td className="py-3 px-3 text-slate-400 font-sans whitespace-nowrap">
                            {row.posted_at
                              ? new Date(row.posted_at).toLocaleString('es-MX', {
                                  dateStyle: 'short',
                                  timeStyle: 'medium',
                                })
                              : '—'}
                          </td>

                          <td className="py-3 px-3 font-sans">
                            {isReceipt && (
                              <span className="px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 text-[11px] font-semibold">
                                Entrada
                              </span>
                            )}
                            {isIssue && (
                              <span className="px-2 py-0.5 rounded bg-rose-500/10 text-rose-400 border border-rose-500/20 text-[11px] font-semibold">
                                Salida
                              </span>
                            )}
                            {row.movement_type === 'adjustment' && (
                              <span className="px-2 py-0.5 rounded bg-amber-500/10 text-amber-400 border border-amber-500/20 text-[11px] font-semibold">
                                Ajuste {row.adjustment_direction ? `(${row.adjustment_direction})` : ''}
                              </span>
                            )}
                          </td>

                          <td className="py-3 px-3 font-sans">
                            <div className="font-semibold text-slate-200">
                              {row.reference || '—'}
                            </div>
                            <div className="text-[11px] text-slate-400 truncate max-w-xs">
                              {row.reason}
                            </div>
                          </td>

                          <td className="py-3 px-3 font-sans">
                            <span className="font-mono text-slate-400 text-[11px]">
                              {row.product_sku}
                            </span>
                            <div className="text-slate-200 font-medium truncate max-w-[140px]">
                              {row.product_name}
                            </div>
                          </td>

                          <td
                            className={`py-3 px-3 text-right font-semibold ${
                              isReceipt
                                ? 'text-emerald-400'
                                : isIssue
                                ? 'text-rose-400'
                                : 'text-slate-300'
                            }`}
                          >
                            {isReceipt ? '+' : isIssue ? '-' : ''}
                            {Number(row.quantity).toFixed(2)} {row.product_unit}
                          </td>

                          <td className="py-3 px-3 text-right text-slate-300">
                            {row.applied_unit_cost !== null
                              ? `$${Number(row.applied_unit_cost).toFixed(4)}`
                              : '—'}
                          </td>

                          <td className="py-3 px-3 text-right text-slate-400">
                            {Number(row.stock_before).toFixed(2)}
                          </td>

                          <td className="py-3 px-3 text-right font-bold text-slate-100 bg-slate-950/30">
                            {Number(row.stock_after).toFixed(2)} {row.product_unit}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              )}
            </div>

            {/* Footer */}
            <div className="px-6 py-3 border-t border-slate-800 bg-slate-950/60 flex items-center justify-between text-xs text-slate-400">
              <span>Registros auditados según norma contable de Costo Promedio Ponderado.</span>
              <button
                onClick={() => setIsOpen(false)}
                className="px-4 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-200 rounded-lg transition-colors font-medium"
              >
                Cerrar
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
