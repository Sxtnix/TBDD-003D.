-- REVISION ANTES DE INSTALAR EV2
-- Solo consultas; no modifica datos ni objetos.
-- Ejecutar los bloques A, B, C y D por separado.

-- A. Datos disponibles para las pruebas.
SELECT 'CLIENTE' AS tabla, COUNT(*) AS registros FROM Cliente
UNION ALL
SELECT 'LOCAL', COUNT(*) FROM Local
UNION ALL
SELECT 'EMPLEADO', COUNT(*) FROM Empleado
UNION ALL
SELECT 'PRODUCTO', COUNT(*) FROM Producto
UNION ALL
SELECT 'INVENTARIO', COUNT(*) FROM Inventario
UNION ALL
SELECT 'PEDIDO', COUNT(*) FROM Pedido
UNION ALL
SELECT 'DETALLE_PEDIDO', COUNT(*) FROM detalle_pedido;

-- B. Secuencias existentes. LAST_NUMBER no representa necesariamente
-- el siguiente valor que devolvera NEXTVAL si hay cache.
SELECT sequence_name, increment_by, last_number, cache_size
  FROM user_sequences
 WHERE sequence_name IN (
    'SEQ_PEDIDO', 'SEQ_DETALLE_PEDIDO', 'SEQ_AUDITORIA_PEDIDO'
 )
 ORDER BY sequence_name;

-- C. Columnas para contrastar el modelo antes de compilar.
SELECT table_name, column_name, data_type, data_length,
       data_precision, data_scale, nullable
  FROM user_tab_columns
 WHERE table_name IN (
    'LOCAL', 'CLIENTE', 'EMPLEADO', 'PRODUCTO',
    'INVENTARIO', 'PEDIDO', 'DETALLE_PEDIDO'
 )
 ORDER BY table_name, column_id;

-- D. Copia del package actual para revisar antes de reemplazarlo.
-- Exportar TODAS las filas con TYPE, LINE y TEXT a un archivo de texto
-- o CSV. No basta con una captura de las primeras lineas.
-- Esto es un registro de su fuente, no un script de restauracion listo
-- para ejecutar (no incorpora CREATE OR REPLACE ni separadores /).
SELECT type, line, text
  FROM user_source
 WHERE name = 'PKG_GESTION_PEDIDOS'
   AND type IN ('PACKAGE', 'PACKAGE BODY')
 ORDER BY CASE type WHEN 'PACKAGE' THEN 1 ELSE 2 END, line;
