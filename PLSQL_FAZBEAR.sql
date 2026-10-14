-- ============================================================
-- FAZBEAR PIZZA - PL/SQL
-- Evaluacion Parcial N°2 - BDY1103
--
-- Prerrequisitos:
--   1. FIX_BD_FAZBEAR.sql
--   2. Datos de prueba (PLSQL_FAZBEAR_PIZZA.sql)
--
-- Componentes:
--   - Procedimientos (con y sin parametros)
--   - Funciones (con y sin parametros)
--   - Package con miembros publicos y privados
--   - Triggers (nivel de fila y de sentencia)
--   - Bloques anonimos de prueba
-- ============================================================

SET SERVEROUTPUT ON;

-- ============================================================
-- 1. PROCEDIMIENTO CON PARAMETROS: SP_LIQUIDAR_MES
-- ============================================================
-- Calcula el total acumulado de ventas en un mes/anio especifico
-- excluyendo los pedidos cancelados ('C').
CREATE OR REPLACE PROCEDURE SP_LIQUIDAR_MES (
    p_mes    IN NUMBER,
    p_anio   IN NUMBER,
    p_total  OUT NUMBER
)
IS
BEGIN
    IF p_mes < 1 OR p_mes > 12 THEN
        RAISE_APPLICATION_ERROR(-20020, 'El mes debe estar entre 1 y 12.');
    END IF;

    SELECT NVL(SUM(total), 0)
      INTO p_total
      FROM Pedido
     WHERE EXTRACT(MONTH FROM fecha_pedido) = p_mes
       AND EXTRACT(YEAR FROM fecha_pedido) = p_anio
       AND estado <> 'C';
END SP_LIQUIDAR_MES;
/
SHOW ERRORS;

-- ============================================================
-- 2. PROCEDIMIENTO SIN PARAMETROS: SP_REVISAR_STOCK_CRITICO
-- ============================================================
-- Informa productos con stock actual menor o igual al stock minimo.
CREATE OR REPLACE PROCEDURE SP_REVISAR_STOCK_CRITICO
IS
    CURSOR c_stock IS
        SELECT p.id_producto,
               p.nombre,
               i.cantidad,
               i.stock_minimo
          FROM Producto p
          JOIN Inventario i ON p.id_inventario = i.id_inventario
         WHERE i.cantidad <= i.stock_minimo
         ORDER BY p.id_producto;

    v_encontrados NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    DBMS_OUTPUT.PUT_LINE('PRODUCTOS CON STOCK CRITICO');
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');

    FOR r IN c_stock LOOP
        v_encontrados := v_encontrados + 1;
        DBMS_OUTPUT.PUT_LINE('ID: ' || r.id_producto ||
                             ' | Producto: ' || r.nombre ||
                             ' | Stock: ' || r.cantidad ||
                             ' | Minimo: ' || r.stock_minimo);
    END LOOP;

    IF v_encontrados = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No se registran productos con stock critico.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Total productos en estado critico: ' || v_encontrados);
    END IF;
END SP_REVISAR_STOCK_CRITICO;
/
SHOW ERRORS;

-- ============================================================
-- 3. FUNCION CON PARAMETROS: FN_CALCULAR_DESCUENTO
-- ============================================================
-- Retorna el monto de descuento segun tipo de cliente:
-- Tipo 1 (Regular) -> 0% | Tipo 2 (VIP) -> 10%
CREATE OR REPLACE FUNCTION FN_CALCULAR_DESCUENTO (
    p_total         IN NUMBER,
    p_tipo_cliente  IN NUMBER
)
RETURN NUMBER
IS
BEGIN
    IF p_total IS NULL THEN
        RETURN 0;
    END IF;

    IF p_total < 0 THEN
        RAISE_APPLICATION_ERROR(-20021, 'El total no puede ser negativo.');
    END IF;

    IF p_tipo_cliente = 2 THEN
        RETURN p_total * 0.10;
    END IF;

    RETURN 0;
END FN_CALCULAR_DESCUENTO;
/
SHOW ERRORS;

-- ============================================================
-- 4. FUNCION SIN PARAMETROS: FN_TOTAL_VENTAS
-- ============================================================
-- Devuelve el total acumulado historico de pedidos no cancelados.
CREATE OR REPLACE FUNCTION FN_TOTAL_VENTAS
RETURN NUMBER
IS
    v_total NUMBER;
BEGIN
    SELECT NVL(SUM(total), 0)
      INTO v_total
      FROM Pedido
     WHERE estado <> 'C';

    RETURN v_total;
END FN_TOTAL_VENTAS;
/
SHOW ERRORS;

-- ============================================================
-- 5. PACKAGE GESTION PEDIDOS - ESPECIFICACION
-- ============================================================
CREATE OR REPLACE PACKAGE PKG_GESTION_PEDIDOS
IS
    PROCEDURE REGISTRAR_PEDIDO (
        p_id_cliente    IN Cliente.id_cliente%TYPE,
        p_id_local      IN Local.id_local%TYPE,
        p_empleado_rut  IN Empleado.rut%TYPE,
        p_id_pedido     OUT Pedido.id_pedido%TYPE
    );

    PROCEDURE AGREGAR_DETALLE (
        p_id_pedido    IN Pedido.id_pedido%TYPE,
        p_id_producto  IN Producto.id_producto%TYPE,
        p_cantidad     IN NUMBER
    );

    FUNCTION OBTENER_TOTAL_PEDIDO (
        p_id_pedido IN Pedido.id_pedido%TYPE
    )
    RETURN NUMBER;
END PKG_GESTION_PEDIDOS;
/
SHOW ERRORS;

-- ============================================================
-- 6. PACKAGE GESTION PEDIDOS - BODY
-- ============================================================
CREATE OR REPLACE PACKAGE BODY PKG_GESTION_PEDIDOS
IS
    -- Subprogramas privados
    FUNCTION CALCULAR_SUBTOTAL (
        p_cantidad IN NUMBER,
        p_precio   IN NUMBER
    )
    RETURN NUMBER
    IS
    BEGIN
        RETURN p_cantidad * p_precio;
    END CALCULAR_SUBTOTAL;

    PROCEDURE VALIDAR_STOCK (
        p_id_producto IN Producto.id_producto%TYPE,
        p_cantidad    IN NUMBER
    )
    IS
        v_stock Inventario.cantidad%TYPE;
    BEGIN
        SELECT i.cantidad
          INTO v_stock
          FROM Inventario i
          JOIN Producto p ON p.id_inventario = i.id_inventario
         WHERE p.id_producto = p_id_producto;

        IF p_cantidad > v_stock THEN
            RAISE_APPLICATION_ERROR(-20001, 'Stock insuficiente. Disponible: ' || v_stock || ', solicitado: ' || p_cantidad);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'El producto no existe en el inventario.');
    END VALIDAR_STOCK;

    -- Subprogramas publicos
    PROCEDURE REGISTRAR_PEDIDO (
        p_id_cliente    IN Cliente.id_cliente%TYPE,
        p_id_local      IN Local.id_local%TYPE,
        p_empleado_rut  IN Empleado.rut%TYPE,
        p_id_pedido     OUT Pedido.id_pedido%TYPE
    )
    IS
        v_existe NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_existe FROM Cliente WHERE id_cliente = p_id_cliente;
        IF v_existe = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'El cliente indicado no existe.');
        END IF;

        SELECT COUNT(*) INTO v_existe FROM Local WHERE id_local = p_id_local;
        IF v_existe = 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'El local indicado no existe.');
        END IF;

        SELECT COUNT(*) INTO v_existe FROM Empleado WHERE rut = p_empleado_rut;
        IF v_existe = 0 THEN
            RAISE_APPLICATION_ERROR(-20005, 'El empleado indicado no existe.');
        END IF;

        p_id_pedido := seq_pedido.NEXTVAL;

        INSERT INTO Pedido (id_pedido, fecha_pedido, estado, total, id_cliente, id_local, empleado_rut)
        VALUES (p_id_pedido, SYSDATE, 'P', 0, p_id_cliente, p_id_local, p_empleado_rut);

        DBMS_OUTPUT.PUT_LINE('Pedido #' || p_id_pedido || ' registrado con exito.');
    END REGISTRAR_PEDIDO;

    PROCEDURE AGREGAR_DETALLE (
        p_id_pedido    IN Pedido.id_pedido%TYPE,
        p_id_producto  IN Producto.id_producto%TYPE,
        p_cantidad     IN NUMBER
    )
    IS
        v_precio          Producto.precio%TYPE;
        v_id_inventario   Producto.id_inventario%TYPE;
        v_subtotal        detalle_pedido.subtotal%TYPE;
        v_estado_pedido   Pedido.estado%TYPE;
    BEGIN
        IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
            RAISE_APPLICATION_ERROR(-20006, 'La cantidad debe ser mayor que cero.');
        END IF;

        BEGIN
            SELECT estado
              INTO v_estado_pedido
              FROM Pedido
             WHERE id_pedido = p_id_pedido;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20007, 'El pedido indicado no existe.');
        END;

        IF v_estado_pedido = 'C' THEN
            RAISE_APPLICATION_ERROR(-20008, 'No se pueden agregar productos a un pedido cancelado.');
        END IF;

        BEGIN
            SELECT precio, id_inventario
              INTO v_precio, v_id_inventario
              FROM Producto
             WHERE id_producto = p_id_producto
               AND estado = 'A';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20009, 'El producto no existe o se encuentra inactivo.');
        END;

        -- Validar disponibilidad e importe
        VALIDAR_STOCK(p_id_producto, p_cantidad);
        v_subtotal := CALCULAR_SUBTOTAL(p_cantidad, v_precio);

        -- Registrar detalle
        INSERT INTO detalle_pedido (id_detalle_pedido, cantidad, precio_unitario, subtotal, id_pedido, id_producto)
        VALUES (seq_detalle_pedido.NEXTVAL, p_cantidad, v_precio, v_subtotal, p_id_pedido, p_id_producto);

        -- Actualizar existencias
        UPDATE Inventario
           SET cantidad = cantidad - p_cantidad,
               fecha_actualizacion = SYSDATE
         WHERE id_inventario = v_id_inventario;

        -- Acumular total del pedido
        UPDATE Pedido
           SET total = NVL(total, 0) + v_subtotal
         WHERE id_pedido = p_id_pedido;

        DBMS_OUTPUT.PUT_LINE('Item agregado. Subtotal: $' || v_subtotal);
    END AGREGAR_DETALLE;

    FUNCTION OBTENER_TOTAL_PEDIDO (
        p_id_pedido IN Pedido.id_pedido%TYPE
    )
    RETURN NUMBER
    IS
        v_total Pedido.total%TYPE;
    BEGIN
        SELECT total
          INTO v_total
          FROM Pedido
         WHERE id_pedido = p_id_pedido;

        RETURN NVL(v_total, 0);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20010, 'El pedido indicado no existe.');
    END OBTENER_TOTAL_PEDIDO;

END PKG_GESTION_PEDIDOS;
/
SHOW ERRORS;

-- ============================================================
-- 7. TABLA Y SECUENCIA DE AUDITORIA
-- ============================================================
CREATE TABLE Auditoria_Pedido (
    id_auditoria NUMBER NOT NULL,
    fecha_evento DATE DEFAULT SYSDATE NOT NULL,
    operacion    VARCHAR2(10) NOT NULL,
    usuario_bd   VARCHAR2(128) NOT NULL,
    descripcion  VARCHAR2(200),
    CONSTRAINT Auditoria_Pedido_PK PRIMARY KEY (id_auditoria)
);

CREATE SEQUENCE seq_auditoria_pedido
START WITH 1
INCREMENT BY 1;

-- ============================================================
-- 8. TRIGGER A NIVEL DE FILA: TGR_VALIDAR_ESTADO_PEDIDO
-- ============================================================
CREATE OR REPLACE TRIGGER TGR_VALIDAR_ESTADO_PEDIDO
BEFORE UPDATE OF estado ON Pedido
FOR EACH ROW
BEGIN
    IF :NEW.estado NOT IN ('P', 'X', 'E', 'C') THEN
        RAISE_APPLICATION_ERROR(-20011, 'Estado de pedido invalido.');
    END IF;

    IF :OLD.estado = 'C' AND :NEW.estado <> 'C' THEN
        RAISE_APPLICATION_ERROR(-20012, 'Un pedido cancelado no puede volver a activarse.');
    END IF;
END TGR_VALIDAR_ESTADO_PEDIDO;
/
SHOW ERRORS;

-- ============================================================
-- 9. TRIGGER A NIVEL DE SENTENCIA: TGR_AUDITAR_PEDIDOS
-- ============================================================
CREATE OR REPLACE TRIGGER TGR_AUDITAR_PEDIDOS
AFTER INSERT OR UPDATE OR DELETE ON Pedido
DECLARE
    v_operacion VARCHAR2(10);
BEGIN
    IF INSERTING THEN
        v_operacion := 'INSERT';
    ELSIF UPDATING THEN
        v_operacion := 'UPDATE';
    ELSIF DELETING THEN
        v_operacion := 'DELETE';
    END IF;

    INSERT INTO Auditoria_Pedido (id_auditoria, fecha_evento, operacion, usuario_bd, descripcion)
    VALUES (seq_auditoria_pedido.NEXTVAL, SYSDATE, v_operacion, USER, 'Operacion realizada sobre la tabla Pedido');
END TGR_AUDITAR_PEDIDOS;
/
SHOW ERRORS;

-- ============================================================
-- PRUEBAS DE FUNCIONAMIENTO
-- ============================================================

-- PRUEBA 1: Procedimiento con parametros (SP_LIQUIDAR_MES)
DECLARE
    v_total NUMBER;
BEGIN
    SP_LIQUIDAR_MES(EXTRACT(MONTH FROM SYSDATE), EXTRACT(YEAR FROM SYSDATE), v_total);
    DBMS_OUTPUT.PUT_LINE('Prueba 1 | Total vendido mes actual: $' || v_total);
END;
/

-- PRUEBA 2: Procedimiento sin parametros (SP_REVISAR_STOCK_CRITICO)
BEGIN
    SP_REVISAR_STOCK_CRITICO;
END;
/

-- PRUEBA 3: Funcion con parametros invocada desde SQL
SELECT FN_CALCULAR_DESCUENTO(50000, 2) AS descuento_vip FROM dual;

-- PRUEBA 4: Funcion con parametros invocada desde PL/SQL
DECLARE
    v_descuento NUMBER;
BEGIN
    v_descuento := FN_CALCULAR_DESCUENTO(50000, 2);
    DBMS_OUTPUT.PUT_LINE('Prueba 4 | Descuento VIP sobre $50.000: $' || v_descuento);
END;
/

-- PRUEBA 5: Funcion sin parametros invocada desde SQL
SELECT FN_TOTAL_VENTAS() AS total_historico FROM dual;

-- PRUEBA 6: Funcion sin parametros invocada desde PL/SQL
DECLARE
    v_total NUMBER;
BEGIN
    v_total := FN_TOTAL_VENTAS();
    DBMS_OUTPUT.PUT_LINE('Prueba 6 | Total historico ventas: $' || v_total);
END;
/

-- PRUEBA 7: Flujo completo mediante PKG_GESTION_PEDIDOS
DECLARE
    v_id_pedido Pedido.id_pedido%TYPE;
    v_total     Pedido.total%TYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- Prueba 7: Registro y detalle con Package ---');
    PKG_GESTION_PEDIDOS.REGISTRAR_PEDIDO(
        p_id_cliente   => 1,
        p_id_local     => 1,
        p_empleado_rut => 11111111,
        p_id_pedido    => v_id_pedido
    );

    PKG_GESTION_PEDIDOS.AGREGAR_DETALLE(
        p_id_pedido   => v_id_pedido,
        p_id_producto => 1,
        p_cantidad    => 2
    );

    v_total := PKG_GESTION_PEDIDOS.OBTENER_TOTAL_PEDIDO(v_id_pedido);
    DBMS_OUTPUT.PUT_LINE('Pedido finalizado #' || v_id_pedido || ' | Total: $' || v_total);
    COMMIT;
END;
/

-- Consultas de verificacion posteriores a la prueba 7
SELECT id_pedido, fecha_pedido, estado, total, id_cliente, id_local, empleado_rut
  FROM Pedido
 ORDER BY id_pedido;

SELECT id_detalle_pedido, cantidad, precio_unitario, subtotal, id_pedido, id_producto
  FROM detalle_pedido
 ORDER BY id_detalle_pedido;

SELECT i.id_inventario, p.nombre, i.cantidad, i.stock_minimo, i.fecha_actualizacion
  FROM Inventario i
  JOIN Producto p ON p.id_inventario = i.id_inventario
 ORDER BY i.id_inventario;

-- PRUEBA 8: Control de excepcion por falta de stock (espera ORA-20001)
DECLARE
    v_pedido NUMBER;
BEGIN
    SELECT MAX(id_pedido) INTO v_pedido FROM Pedido;

    BEGIN
        PKG_GESTION_PEDIDOS.AGREGAR_DETALLE(
            p_id_pedido   => v_pedido,
            p_id_producto => 1,
            p_cantidad    => 999
        );
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Prueba 8 | Error de stock capturado correctamente: ' || SQLERRM);
    END;
END;
/

-- PRUEBA 9: Trigger a nivel de fila (impedir reactivar pedido cancelado)
SAVEPOINT antes_trigger_fila;

UPDATE Pedido
   SET estado = 'C'
 WHERE id_pedido = 1;

BEGIN
    UPDATE Pedido
       SET estado = 'P'
     WHERE id_pedido = 1;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Prueba 9 | Trigger de fila activo: ' || SQLERRM);
END;
/

ROLLBACK TO antes_trigger_fila;

-- PRUEBA 10: Trigger a nivel de sentencia (un solo registro para sentencia masiva)
DECLARE
    v_antes   NUMBER;
    v_despues NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_antes FROM Auditoria_Pedido;

    UPDATE Pedido
       SET total = total
     WHERE estado <> 'C';

    SELECT COUNT(*) INTO v_despues FROM Auditoria_Pedido;

    DBMS_OUTPUT.PUT_LINE('Prueba 10 | Registros antes: ' || v_antes ||
                         ' | Registros despues: ' || v_despues ||
                         ' | Disparos del trigger: ' || (v_despues - v_antes));
    COMMIT;
END;
/

-- Consultas de verificacion finales
SELECT id_auditoria, fecha_evento, operacion, usuario_bd, descripcion
  FROM Auditoria_Pedido
 ORDER BY id_auditoria;

SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name IN (
    'SP_LIQUIDAR_MES',
    'SP_REVISAR_STOCK_CRITICO',
    'FN_CALCULAR_DESCUENTO',
    'FN_TOTAL_VENTAS',
    'PKG_GESTION_PEDIDOS',
    'TGR_VALIDAR_ESTADO_PEDIDO',
    'TGR_AUDITAR_PEDIDOS'
 )
 ORDER BY object_type, object_name;