-- ============================================================
-- FAZBEAR PIZZA
-- EVALUACION PARCIAL N°2 - BDY1103
--
-- Requiere ejecutar previamente:
--   1. FIX_BD_FAZBEAR.sql
--   2. Los datos de prueba de PLSQL_FAZBEAR_PIZZA.sql
--
-- Contiene:
--   - Procedimiento con parametros
--   - Procedimiento sin parametros
--   - Funcion con parametros
--   - Funcion sin parametros
--   - Package con elementos publicos y privados
--   - Trigger a nivel de fila
--   - Trigger a nivel de sentencia
--   - Pruebas de funcionamiento
-- ============================================================

SET SERVEROUTPUT ON;


-- ============================================================
-- 1. PROCEDIMIENTO CON PARAMETROS
-- ============================================================
-- Calcula el total vendido durante un mes y año determinados.
-- No considera pedidos cancelados.
--
-- PARAMETROS:
--   p_mes   -> mes que se desea consultar
--   p_anio  -> año que se desea consultar
--   p_total -> devuelve el total vendido
-- ============================================================

CREATE OR REPLACE PROCEDURE SP_LIQUIDAR_MES (
    p_mes    IN NUMBER,
    p_anio   IN NUMBER,
    p_total  OUT NUMBER
)
IS
BEGIN

    -- Validamos el mes recibido
    IF p_mes < 1 OR p_mes > 12 THEN
        RAISE_APPLICATION_ERROR(
            -20020,
            'El mes debe estar entre 1 y 12.'
        );
    END IF;

    SELECT NVL(SUM(total), 0)
      INTO p_total
      FROM Pedido
     WHERE EXTRACT(MONTH FROM fecha_pedido) = p_mes
       AND EXTRACT(YEAR FROM fecha_pedido) = p_anio
       AND estado <> 'C';

END;
/

SHOW ERRORS;


-- ============================================================
-- 2. PROCEDIMIENTO SIN PARAMETROS
-- ============================================================
-- Recorre todos los productos y muestra aquellos cuyo stock
-- actual es menor o igual al stock minimo.
--
-- Sirve como ejemplo de procesamiento de varias filas mediante
-- un cursor explicito.
-- ============================================================

CREATE OR REPLACE PROCEDURE SP_REVISAR_STOCK_CRITICO
IS

    CURSOR c_stock IS
        SELECT
            p.id_producto,
            p.nombre,
            i.cantidad,
            i.stock_minimo
        FROM Producto p
        JOIN Inventario i
          ON p.id_inventario = i.id_inventario
        WHERE i.cantidad <= i.stock_minimo
        ORDER BY p.id_producto;

    v_encontrados NUMBER := 0;

BEGIN

    DBMS_OUTPUT.PUT_LINE(
        '========================================'
    );

    DBMS_OUTPUT.PUT_LINE(
        'PRODUCTOS CON STOCK CRITICO'
    );

    DBMS_OUTPUT.PUT_LINE(
        '========================================'
    );

    FOR r_stock IN c_stock LOOP

        v_encontrados := v_encontrados + 1;

        DBMS_OUTPUT.PUT_LINE(
            'ID: ' || r_stock.id_producto ||
            ' | Producto: ' || r_stock.nombre ||
            ' | Stock actual: ' || r_stock.cantidad ||
            ' | Stock minimo: ' || r_stock.stock_minimo
        );

    END LOOP;

    IF v_encontrados = 0 THEN

        DBMS_OUTPUT.PUT_LINE(
            'No existen productos con stock critico.'
        );

    ELSE

        DBMS_OUTPUT.PUT_LINE(
            'Cantidad de productos criticos: '
            || v_encontrados
        );

    END IF;

END;
/

SHOW ERRORS;


-- ============================================================
-- 3. FUNCION CON PARAMETROS
-- ============================================================
-- Calcula el MONTO de descuento correspondiente a un cliente.
--
-- Regla utilizada para esta evaluacion:
--
-- Tipo cliente 1 = REGULAR -> 0%
-- Tipo cliente 2 = VIP     -> 10%
--
-- Retorna el dinero descontado, no el total final.
-- ============================================================

CREATE OR REPLACE FUNCTION FN_CALCULAR_DESCUENTO (
    p_total         IN NUMBER,
    p_tipo_cliente  IN NUMBER
)
RETURN NUMBER
IS

    v_descuento NUMBER := 0;

BEGIN

    IF p_total IS NULL THEN
        RETURN 0;
    END IF;

    IF p_total < 0 THEN

        RAISE_APPLICATION_ERROR(
            -20021,
            'El total no puede ser negativo.'
        );

    END IF;


    IF p_tipo_cliente = 2 THEN

        -- Cliente VIP: 10%
        v_descuento := p_total * 0.10;

    ELSE

        -- Cliente regular u otro tipo
        v_descuento := 0;

    END IF;


    RETURN v_descuento;

END;
/

SHOW ERRORS;


-- ============================================================
-- 4. FUNCION SIN PARAMETROS
-- ============================================================
-- Devuelve el total historico vendido.
-- Ignora pedidos cancelados.
-- ============================================================

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

END;
/

SHOW ERRORS;



-- ============================================================
-- 5. PACKAGE - ESPECIFICACION
-- ============================================================
--
-- ELEMENTOS PUBLICOS:
--
-- registrar_pedido
-- agregar_detalle
-- obtener_total_pedido
--
-- Los elementos declarados aca pueden ser utilizados desde
-- fuera del package.
-- ============================================================

CREATE OR REPLACE PACKAGE PKG_GESTION_PEDIDOS
IS

    -- --------------------------------------------------------
    -- Registra la cabecera de un pedido nuevo.
    -- Devuelve mediante OUT el ID generado.
    -- --------------------------------------------------------
    PROCEDURE REGISTRAR_PEDIDO (
        p_id_cliente    IN Cliente.id_cliente%TYPE,
        p_id_local      IN Local.id_local%TYPE,
        p_empleado_rut  IN Empleado.rut%TYPE,
        p_id_pedido     OUT Pedido.id_pedido%TYPE
    );


    -- --------------------------------------------------------
    -- Agrega un producto al detalle de un pedido.
    -- Valida el stock antes de insertar.
    -- --------------------------------------------------------
    PROCEDURE AGREGAR_DETALLE (
        p_id_pedido    IN Pedido.id_pedido%TYPE,
        p_id_producto  IN Producto.id_producto%TYPE,
        p_cantidad     IN NUMBER
    );


    -- --------------------------------------------------------
    -- Retorna el total actual de un pedido.
    -- --------------------------------------------------------
    FUNCTION OBTENER_TOTAL_PEDIDO (
        p_id_pedido IN Pedido.id_pedido%TYPE
    )
    RETURN NUMBER;

END PKG_GESTION_PEDIDOS;
/

SHOW ERRORS;



-- ============================================================
-- 6. PACKAGE - BODY
-- ============================================================
--
-- Contiene la implementacion.
--
-- ELEMENTOS PRIVADOS:
--
--   validar_stock
--   calcular_subtotal
--
-- Estos NO aparecen en la especificacion y por eso solamente
-- pueden ser utilizados dentro del package.
-- ============================================================

CREATE OR REPLACE PACKAGE BODY PKG_GESTION_PEDIDOS
IS


    -- ========================================================
    -- FUNCION PRIVADA
    -- CALCULAR_SUBTOTAL
    -- ========================================================

    FUNCTION CALCULAR_SUBTOTAL (
        p_cantidad IN NUMBER,
        p_precio   IN NUMBER
    )
    RETURN NUMBER
    IS
    BEGIN

        RETURN p_cantidad * p_precio;

    END CALCULAR_SUBTOTAL;



    -- ========================================================
    -- PROCEDIMIENTO PRIVADO
    -- VALIDAR_STOCK
    -- ========================================================

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
          JOIN Producto p
            ON p.id_inventario = i.id_inventario
         WHERE p.id_producto = p_id_producto;


        IF p_cantidad > v_stock THEN

            RAISE_APPLICATION_ERROR(
                -20001,
                'Stock insuficiente. Disponible: '
                || v_stock
                || ', solicitado: '
                || p_cantidad
            );

        END IF;


    EXCEPTION

        WHEN NO_DATA_FOUND THEN

            RAISE_APPLICATION_ERROR(
                -20002,
                'El producto no existe en el inventario.'
            );

    END VALIDAR_STOCK;



    -- ========================================================
    -- PROCEDIMIENTO PUBLICO
    -- REGISTRAR_PEDIDO
    -- ========================================================

    PROCEDURE REGISTRAR_PEDIDO (
        p_id_cliente    IN Cliente.id_cliente%TYPE,
        p_id_local      IN Local.id_local%TYPE,
        p_empleado_rut  IN Empleado.rut%TYPE,
        p_id_pedido     OUT Pedido.id_pedido%TYPE
    )
    IS

        v_existe NUMBER;

    BEGIN

        -- ----------------------------------------------------
        -- Comprobar cliente
        -- ----------------------------------------------------

        SELECT COUNT(*)
          INTO v_existe
          FROM Cliente
         WHERE id_cliente = p_id_cliente;

        IF v_existe = 0 THEN

            RAISE_APPLICATION_ERROR(
                -20003,
                'El cliente indicado no existe.'
            );

        END IF;


        -- ----------------------------------------------------
        -- Comprobar local
        -- ----------------------------------------------------

        SELECT COUNT(*)
          INTO v_existe
          FROM Local
         WHERE id_local = p_id_local;

        IF v_existe = 0 THEN

            RAISE_APPLICATION_ERROR(
                -20004,
                'El local indicado no existe.'
            );

        END IF;


        -- ----------------------------------------------------
        -- Comprobar empleado
        -- ----------------------------------------------------

        SELECT COUNT(*)
          INTO v_existe
          FROM Empleado
         WHERE rut = p_empleado_rut;

        IF v_existe = 0 THEN

            RAISE_APPLICATION_ERROR(
                -20005,
                'El empleado indicado no existe.'
            );

        END IF;


        -- ----------------------------------------------------
        -- Obtener nuevo ID
        -- ----------------------------------------------------

        p_id_pedido := seq_pedido.NEXTVAL;


        -- ----------------------------------------------------
        -- Crear pedido
        -- ----------------------------------------------------

        INSERT INTO Pedido (
            id_pedido,
            fecha_pedido,
            estado,
            total,
            id_cliente,
            id_local,
            empleado_rut
        )
        VALUES (
            p_id_pedido,
            SYSDATE,
            'P',
            0,
            p_id_cliente,
            p_id_local,
            p_empleado_rut
        );


        DBMS_OUTPUT.PUT_LINE(
            'Pedido #' || p_id_pedido ||
            ' registrado correctamente.'
        );


    END REGISTRAR_PEDIDO;



    -- ========================================================
    -- PROCEDIMIENTO PUBLICO
    -- AGREGAR_DETALLE
    -- ========================================================

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

        -- ----------------------------------------------------
        -- Validar cantidad
        -- ----------------------------------------------------

        IF p_cantidad IS NULL OR p_cantidad <= 0 THEN

            RAISE_APPLICATION_ERROR(
                -20006,
                'La cantidad debe ser mayor que cero.'
            );

        END IF;


        -- ----------------------------------------------------
        -- Validar pedido
        -- ----------------------------------------------------

        BEGIN

            SELECT estado
              INTO v_estado_pedido
              FROM Pedido
             WHERE id_pedido = p_id_pedido;

        EXCEPTION

            WHEN NO_DATA_FOUND THEN

                RAISE_APPLICATION_ERROR(
                    -20007,
                    'El pedido indicado no existe.'
                );

        END;


        IF v_estado_pedido = 'C' THEN

            RAISE_APPLICATION_ERROR(
                -20008,
                'No se pueden agregar productos a un pedido cancelado.'
            );

        END IF;


        -- ----------------------------------------------------
        -- Obtener producto
        -- ----------------------------------------------------

        BEGIN

            SELECT precio,
                   id_inventario
              INTO v_precio,
                   v_id_inventario
              FROM Producto
             WHERE id_producto = p_id_producto
               AND estado = 'A';

        EXCEPTION

            WHEN NO_DATA_FOUND THEN

                RAISE_APPLICATION_ERROR(
                    -20009,
                    'El producto no existe o se encuentra inactivo.'
                );

        END;


        -- ----------------------------------------------------
        -- Llamar al procedimiento PRIVADO del package
        -- ----------------------------------------------------

        VALIDAR_STOCK(
            p_id_producto,
            p_cantidad
        );


        -- ----------------------------------------------------
        -- Llamar a funcion PRIVADA del package
        -- ----------------------------------------------------

        v_subtotal := CALCULAR_SUBTOTAL(
            p_cantidad,
            v_precio
        );


        -- ----------------------------------------------------
        -- Insertar detalle
        -- ----------------------------------------------------

        INSERT INTO detalle_pedido (
            id_detalle_pedido,
            cantidad,
            precio_unitario,
            subtotal,
            id_pedido,
            id_producto
        )
        VALUES (
            seq_detalle_pedido.NEXTVAL,
            p_cantidad,
            v_precio,
            v_subtotal,
            p_id_pedido,
            p_id_producto
        );


        -- ----------------------------------------------------
        -- Descontar inventario
        -- ----------------------------------------------------

        UPDATE Inventario
           SET cantidad = cantidad - p_cantidad,
               fecha_actualizacion = SYSDATE
         WHERE id_inventario = v_id_inventario;


        -- ----------------------------------------------------
        -- Actualizar total del pedido
        -- ----------------------------------------------------

        UPDATE Pedido
           SET total = NVL(total, 0) + v_subtotal
         WHERE id_pedido = p_id_pedido;


        DBMS_OUTPUT.PUT_LINE(
            'Producto agregado correctamente.'
        );

        DBMS_OUTPUT.PUT_LINE(
            'Subtotal agregado: $' || v_subtotal
        );


    END AGREGAR_DETALLE;



    -- ========================================================
    -- FUNCION PUBLICA
    -- OBTENER_TOTAL_PEDIDO
    -- ========================================================

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

            RAISE_APPLICATION_ERROR(
                -20010,
                'El pedido indicado no existe.'
            );

    END OBTENER_TOTAL_PEDIDO;


END PKG_GESTION_PEDIDOS;
/

SHOW ERRORS;



-- ============================================================
-- 7. TABLA DE AUDITORIA
-- ============================================================
-- Esta tabla permitira demostrar el trigger a nivel de
-- sentencia.
-- ============================================================

CREATE TABLE Auditoria_Pedido (

    id_auditoria NUMBER NOT NULL,

    fecha_evento DATE DEFAULT SYSDATE NOT NULL,

    operacion VARCHAR2(10) NOT NULL,

    usuario_bd VARCHAR2(128) NOT NULL,

    descripcion VARCHAR2(200),

    CONSTRAINT Auditoria_Pedido_PK
        PRIMARY KEY (id_auditoria)

);


CREATE SEQUENCE seq_auditoria_pedido
START WITH 1
INCREMENT BY 1;



-- ============================================================
-- 8. TRIGGER A NIVEL DE FILA
-- ============================================================
--
-- FOR EACH ROW indica que se ejecuta una vez por cada fila
-- afectada.
--
-- Utiliza:
--   :OLD -> valor anterior
--   :NEW -> valor nuevo
--
-- Reglas:
--
-- 1. Un pedido cancelado no puede volver a estar activo.
-- 2. Solamente se permiten los estados:
--      P = pendiente
--      X = en preparacion
--      E = entregado
--      C = cancelado
-- ============================================================

CREATE OR REPLACE TRIGGER TGR_VALIDAR_ESTADO_PEDIDO

BEFORE UPDATE OF estado
ON Pedido

FOR EACH ROW

BEGIN

    -- --------------------------------------------------------
    -- Validar valores permitidos
    -- --------------------------------------------------------

    IF :NEW.estado NOT IN ('P', 'X', 'E', 'C') THEN

        RAISE_APPLICATION_ERROR(
            -20011,
            'Estado de pedido invalido.'
        );

    END IF;


    -- --------------------------------------------------------
    -- Impedir reactivar un pedido cancelado
    -- --------------------------------------------------------

    IF :OLD.estado = 'C'
       AND :NEW.estado <> 'C'
    THEN

        RAISE_APPLICATION_ERROR(
            -20012,
            'Un pedido cancelado no puede volver a activarse.'
        );

    END IF;

END;
/

SHOW ERRORS;



-- ============================================================
-- 9. TRIGGER A NIVEL DE SENTENCIA
-- ============================================================
--
-- IMPORTANTE:
--
-- Este trigger NO posee FOR EACH ROW.
--
-- Por eso se ejecuta una sola vez por sentencia SQL,
-- independientemente de que la sentencia afecte una fila
-- o cien filas.
-- ============================================================

CREATE OR REPLACE TRIGGER TGR_AUDITAR_PEDIDOS

AFTER INSERT OR UPDATE OR DELETE
ON Pedido

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


    INSERT INTO Auditoria_Pedido (
        id_auditoria,
        fecha_evento,
        operacion,
        usuario_bd,
        descripcion
    )
    VALUES (
        seq_auditoria_pedido.NEXTVAL,
        SYSDATE,
        v_operacion,
        USER,
        'Operacion realizada sobre la tabla Pedido'
    );

END;
/

SHOW ERRORS;



-- ============================================================
-- ============================================================
--                  PRUEBAS DE LOS OBJETOS
-- ============================================================
-- ============================================================



-- ============================================================
-- PRUEBA 1
-- PROCEDIMIENTO CON PARAMETROS
-- ============================================================

DECLARE

    v_total NUMBER;

BEGIN

    SP_LIQUIDAR_MES(
        EXTRACT(MONTH FROM SYSDATE),
        EXTRACT(YEAR FROM SYSDATE),
        v_total
    );

    DBMS_OUTPUT.PUT_LINE(
        '------------------------------------'
    );

    DBMS_OUTPUT.PUT_LINE(
        'PRUEBA SP_LIQUIDAR_MES'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Total vendido este mes: $'
        || v_total
    );

END;
/



-- ============================================================
-- PRUEBA 2
-- PROCEDIMIENTO SIN PARAMETROS
-- ============================================================

BEGIN

    SP_REVISAR_STOCK_CRITICO;

END;
/



-- ============================================================
-- PRUEBA 3
-- FUNCION CON PARAMETROS DESDE SQL
-- ============================================================

SELECT
    FN_CALCULAR_DESCUENTO(
        50000,
        2
    ) AS descuento_vip
FROM dual;



-- ============================================================
-- PRUEBA 4
-- FUNCION CON PARAMETROS DESDE PL/SQL
-- ============================================================

DECLARE

    v_descuento NUMBER;

BEGIN

    v_descuento :=
        FN_CALCULAR_DESCUENTO(
            50000,
            2
        );

    DBMS_OUTPUT.PUT_LINE(
        'Descuento VIP sobre $50000: $'
        || v_descuento
    );

END;
/



-- ============================================================
-- PRUEBA 5
-- FUNCION SIN PARAMETROS DESDE SQL
-- ============================================================

SELECT
    FN_TOTAL_VENTAS() AS total_historico
FROM dual;



-- ============================================================
-- PRUEBA 6
-- FUNCION SIN PARAMETROS DESDE PL/SQL
-- ============================================================

DECLARE

    v_total NUMBER;

BEGIN

    v_total := FN_TOTAL_VENTAS();

    DBMS_OUTPUT.PUT_LINE(
        'Total historico vendido: $'
        || v_total
    );

END;
/



-- ============================================================
-- PRUEBA 7
-- PACKAGE COMPLETO
-- ============================================================
--
-- Esta prueba:
--
-- 1. Crea un pedido.
-- 2. Agrega 2 pizzas.
-- 3. Descuenta el inventario.
-- 4. Actualiza el total.
-- 5. Consulta el total usando la funcion del package.
-- ============================================================

DECLARE

    v_id_pedido Pedido.id_pedido%TYPE;

    v_total Pedido.total%TYPE;

BEGIN

    DBMS_OUTPUT.PUT_LINE(
        '======================================'
    );

    DBMS_OUTPUT.PUT_LINE(
        'PRUEBA PACKAGE'
    );

    DBMS_OUTPUT.PUT_LINE(
        '======================================'
    );


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


    v_total :=
        PKG_GESTION_PEDIDOS.OBTENER_TOTAL_PEDIDO(
            v_id_pedido
        );


    DBMS_OUTPUT.PUT_LINE(
        'ID DEL PEDIDO: '
        || v_id_pedido
    );


    DBMS_OUTPUT.PUT_LINE(
        'TOTAL FINAL: $'
        || v_total
    );


    COMMIT;

END;
/



-- ============================================================
-- VERIFICAR PEDIDOS
-- ============================================================

SELECT
    id_pedido,
    fecha_pedido,
    estado,
    total,
    id_cliente,
    id_local,
    empleado_rut
FROM Pedido
ORDER BY id_pedido;



-- ============================================================
-- VERIFICAR DETALLES
-- ============================================================

SELECT
    id_detalle_pedido,
    cantidad,
    precio_unitario,
    subtotal,
    id_pedido,
    id_producto
FROM detalle_pedido
ORDER BY id_detalle_pedido;



-- ============================================================
-- VERIFICAR INVENTARIO
-- ============================================================

SELECT
    i.id_inventario,
    p.nombre,
    i.cantidad,
    i.stock_minimo,
    i.fecha_actualizacion
FROM Inventario i
JOIN Producto p
  ON p.id_inventario = i.id_inventario
ORDER BY i.id_inventario;



-- ============================================================
-- PRUEBA 8
-- ERROR DE STOCK
-- ============================================================
--
-- Intentamos agregar 999 unidades.
-- Debe provocar ORA-20001.
--
-- La excepcion se captura para poder continuar con las demas
-- pruebas.
-- ============================================================

DECLARE

    v_pedido NUMBER;

BEGIN

    SELECT MAX(id_pedido)
      INTO v_pedido
      FROM Pedido;


    BEGIN

        PKG_GESTION_PEDIDOS.AGREGAR_DETALLE(

            p_id_pedido   => v_pedido,

            p_id_producto => 1,

            p_cantidad    => 999

        );

    EXCEPTION

        WHEN OTHERS THEN

            DBMS_OUTPUT.PUT_LINE(
                '-----------------------------------'
            );

            DBMS_OUTPUT.PUT_LINE(
                'ERROR DE STOCK DETECTADO'
            );

            DBMS_OUTPUT.PUT_LINE(
                SQLERRM
            );

    END;

END;
/



-- ============================================================
-- PRUEBA 9
-- TRIGGER A NIVEL DE FILA
-- ============================================================
--
-- Se utiliza el pedido original ID 1.
--
-- 1. Lo cambiamos a cancelado.
-- 2. Intentamos volverlo a pendiente.
-- 3. El trigger debe impedirlo.
-- 4. Finalmente hacemos ROLLBACK para no alterar los datos.
-- ============================================================

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

        DBMS_OUTPUT.PUT_LINE(
            '==================================='
        );

        DBMS_OUTPUT.PUT_LINE(
            'TRIGGER DE FILA FUNCIONANDO'
        );

        DBMS_OUTPUT.PUT_LINE(
            SQLERRM
        );

END;
/


ROLLBACK TO antes_trigger_fila;



-- ============================================================
-- PRUEBA 10
-- TRIGGER A NIVEL DE SENTENCIA
-- ============================================================
--
-- Esta sentencia puede modificar varias filas.
--
-- El trigger de sentencia se ejecutara SOLO UNA VEZ.
-- ============================================================

DECLARE

    v_antes   NUMBER;

    v_despues NUMBER;

BEGIN

    SELECT COUNT(*)
      INTO v_antes
      FROM Auditoria_Pedido;


    -- Una sentencia UPDATE.
    --
    -- Puede afectar varios pedidos, pero el trigger
    -- de sentencia solamente se ejecuta una vez.

    UPDATE Pedido
       SET total = total
     WHERE estado <> 'C';


    SELECT COUNT(*)
      INTO v_despues
      FROM Auditoria_Pedido;


    DBMS_OUTPUT.PUT_LINE(
        '==================================='
    );

    DBMS_OUTPUT.PUT_LINE(
        'PRUEBA TRIGGER DE SENTENCIA'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Registros antes: '
        || v_antes
    );

    DBMS_OUTPUT.PUT_LINE(
        'Registros despues: '
        || v_despues
    );

    DBMS_OUTPUT.PUT_LINE(
        'Triggers ejecutados por la sentencia: '
        || (v_despues - v_antes)
    );


    COMMIT;

END;
/



-- ============================================================
-- VERIFICAR AUDITORIA
-- ============================================================

SELECT
    id_auditoria,
    fecha_evento,
    operacion,
    usuario_bd,
    descripcion
FROM Auditoria_Pedido
ORDER BY id_auditoria;



-- ============================================================
-- CONSULTAR ESTADO DE LOS OBJETOS
-- ============================================================
--
-- Todos deberian aparecer como VALID.
-- ============================================================

SELECT
    object_name,
    object_type,
    status
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
ORDER BY object_type,
         object_name;


-- ============================================================
-- FIN DEL SCRIPT
-- ============================================================