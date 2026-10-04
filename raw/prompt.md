Mi objetivo es construir un sistema de inventario multiempresa fiable, seguro y mantenible.
1. Entorno
Proyecto local: ~/Git/hbautistaf/inventario
Aplicación: Next.js con TypeScript, Tailwind CSS y App Router.
Base de datos: PostgreSQL mediante Supabase local.
API local: http://127.0.0.1:54321
Studio: http://127.0.0.1:54323
Migración inicial: supabase/migrations/20261003201204_initial_inventory_schema.sql
Existe un respaldo SQL de la migración inicial.
2. Modelo de datos
Se crearon estas tablas:
businesses
business_members
warehouses
products
inventory_balances
inventory_movements
inventory_movement_lines
El sistema separa el inventario por empresa, almacén y producto.
Los roles previstos son:
owner
admin
operator
viewer
Los movimientos tienen tipos receipt, issue y adjustment, y estados draft, posted y cancelled.
3. Funciones instaladas
Se verificaron estas funciones:
create_inventory_movement(...)
add_inventory_movement_line(...)
post_inventory_movement(uuid)
reverse_inventory_movement(uuid, text)
is_business_member(uuid)
Las cuatro funciones operativas son SECURITY DEFINER, propiedad de postgres, ejecutables por authenticated y no ejecutables por anon, según las consultas realizadas.
Las funciones de movimientos validan la pertenencia a la empresa, los roles, el estado del movimiento y los datos de sus líneas.
Lógica prevista
Las entradas incrementan las existencias y recalculan el costo promedio ponderado.
Las salidas disminuyen las existencias y deben impedir cantidades negativas.
Los ajustes físicos comparan el conteo con la existencia teórica.
Los borradores no deben afectar las existencias.
Los movimientos confirmados deben conservar trazabilidad.
Las reversiones crean movimientos inversos y no deben borrar el historial.
Se agregaron a inventory_movement_lines las columnas stock_before, stock_after y applied_unit_cost, todas de tipo numeric.
Se sustituyó post_inventory_movement para eliminar líneas de ajustes cuya diferencia sea cero. Si todo el ajuste carece de diferencias, la función genera una excepción.
4. Protecciones existentes
Se verificaron tres triggers habilitados:
inventory_movement_lines_guard
inventory_movements_changes_guard
inventory_movements_status_guard
También se revisaron las políticas RLS de lectura y las restricciones principales de las tablas.
Las tablas tienen permisos de lectura para usuarios autenticados y las operaciones de escritura del inventario están previstas para ejecutarse mediante funciones controladas.
5. Estado actual
La base de datos está vacía: cero empresas, miembros, almacenes, productos, movimientos, líneas y existencias.
No se han completado pruebas funcionales integrales.
Se detectó que no existe una función específica para inicializar una empresa y registrar de forma segura al usuario autenticado como propietario. La única función encontrada con nombres relacionados con empresas o miembros fue is_business_member(uuid).
Las últimas consultas solicitadas para revisar las columnas y los permisos de escritura de businesses y business_members todavía no tienen resultados disponibles.
6. Aspectos que debes auditar obligatoriamente
A. Seguridad
¿Hay vulnerabilidades derivadas de SECURITY DEFINER, permisos, search_path, RLS o validaciones incompletas?
¿Un usuario podría modificar o consultar datos de otra empresa?
¿Los roles están aplicados consistentemente en todas las operaciones?
¿Puede un usuario convertirse en propietario de una empresa ajena?
¿Los triggers y las funciones se complementan correctamente o tienen huecos?
B. Integridad transaccional
¿Las operaciones son atómicas?

¿Hay condiciones de carrera al confirmar movimientos, agregar líneas o revertir movimientos?
¿Los bloqueos de filas se realizan en un orden seguro?
¿Las restricciones de claves foráneas y claves compuestas evitan cruces entre empresas?
¿Existen casos donde una excepción pueda dejar datos inconsistentes?
C. Lógica de inventario
Verifica el cálculo del costo promedio ponderado.
Revisa el tratamiento de existencias cero y costos cero.
Comprueba ajustes físicos positivos, negativos, mixtos y sin diferencias.
Analiza las reversiones de entradas, salidas y ajustes.
Comprueba qué ocurre cuando existen movimientos posteriores al movimiento que se pretende revertir.
Evalúa si stock_before, stock_after y applied_unit_cost son suficientes para reconstruir y auditar las operaciones.
Busca errores relacionados con el borrado de líneas durante el procesamiento de un movimiento.
D. Arquitectura y mantenibilidad
Evalúa si el diseño de las siete tablas es adecuado.
Identifica funciones redundantes, validaciones duplicadas o complejidad innecesaria.
Determina qué debe corregirse antes de conectar la interfaz.
Identifica si falta una operación segura para crear una empresa y registrar a su propietario.
Comprueba si el esquema permite crecer a múltiples empresas y almacenes sin mezclar datos.
7. Forma de trabajo solicitada
No quiero otra ronda de consultas pequeñas y repetitivas.
Entrega primero:
Diagnóstico ejecutivo: qué está bien, qué está mal y qué falta.
Hallazgos priorizados: crítico, alto, medio y bajo, explicando el impacto y la evidencia disponible.
Correcciones necesarias: agrupa los cambios relacionados en bloques coherentes.
Plan de ejecución: orden exacto de los cambios, dependencias y criterios de aceptación.
Pruebas funcionales: escenarios concretos con resultados esperados.
Archivos que necesitas revisar: identifica los archivos SQL o de aplicación que faltan antes de afirmar que el sistema es seguro.
No inventes resultados de pruebas ni afirmes haber inspeccionado archivos que no recibiste.
Distingue entre:
hechos verificados;
riesgos detectados en el código;
hipótesis pendientes de comprobar.
Si necesitas el código SQL completo, solicítalo de forma agrupada y específica. No vuelvas a pedirme información que ya esté disponible.
Objetivo final: corregir los problemas reales y llevar el proyecto a una primera versión funcional, sin seguir repitiendo verificaciones que no producen avances.
