-- EV2 FAZBEAR PIZZA - PASO 1: DIAGNOSTICO
-- Solo consultas: no crea, modifica ni elimina objetos o datos.
-- Ejecutar cada SELECT por separado desde la conexion Oracle de VS Code.
-- No mostrar contrasenas, cadenas de conexion ni variables de entorno.

-- A. Identificar la sesion y el momento de la consulta.
SELECT USER AS usuario_bd,
       SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') AS esquema_actual,
       SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor_oracle,
       TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') AS fecha_consulta
  FROM dual;

-- B. Revisar las tablas del proyecto que pertenecen al usuario conectado.
-- Si no aparecen, no significa necesariamente que Docker este mal:
-- puede que se haya elegido otro usuario, servicio o esquema.
SELECT table_name
  FROM user_tables
 WHERE table_name IN (
    'PAIS', 'REGION', 'CIUDAD', 'DIRECCION', 'LOCAL',
    'TIPO_ACTIVO', 'TIPO_EMPLEADO', 'TIPO_CLIENTE', 'TIPO_PRODUCTO',
    'ACTIVO', 'EMPLEADO', 'CLIENTE', 'INVENTARIO', 'PRODUCTO',
    'PEDIDO', 'DETALLE_PEDIDO', 'AUDITORIA_PEDIDO'
 )
 ORDER BY table_name;

-- C. Revisar objetos PL/SQL del usuario conectado.
-- Si todos estan creados, se esperan 8 filas (7 nombres):
-- el package tiene una entrada PACKAGE y otra PACKAGE BODY.
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name IN (
    'SP_LIQUIDAR_MES', 'SP_REVISAR_STOCK_CRITICO',
    'FN_CALCULAR_DESCUENTO', 'FN_TOTAL_VENTAS',
    'PKG_GESTION_PEDIDOS', 'TGR_VALIDAR_ESTADO_PEDIDO',
    'TGR_AUDITAR_PEDIDOS'
 )
 ORDER BY object_type, object_name;

-- D. Consultar errores o advertencias registrados para esos objetos.
-- Conservar el resultado, incluso si devuelve cero filas.
-- Una consulta vacia no demuestra compilacion si los objetos no existen:
-- siempre interpretarla junto con la consulta C.
SELECT name, type, attribute, line, position, text
  FROM user_errors
 WHERE name IN (
    'SP_LIQUIDAR_MES', 'SP_REVISAR_STOCK_CRITICO',
    'FN_CALCULAR_DESCUENTO', 'FN_TOTAL_VENTAS',
    'PKG_GESTION_PEDIDOS', 'TGR_VALIDAR_ESTADO_PEDIDO',
    'TGR_AUDITAR_PEDIDOS'
 )
 ORDER BY name, type, sequence;
