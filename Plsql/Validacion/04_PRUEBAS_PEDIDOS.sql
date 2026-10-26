-- EV2 - PRUEBA INTEGRADA CON REVERSIÓN DE DATOS
-- Ejecutar TODO el archivo como script, en la conexión FNAF.
-- Antes de comenzar, terminar cualquier transacción de trabajo ajena.
-- No modifica ni desactiva triggers. No contiene DDL ni COMMIT.
-- Revierte pedidos, detalles, inventario y auditoría creados por esta prueba.
-- Las secuencias NO revierten sus valores: pueden quedar saltos de IDs.
-- Si hay errores, no se deben ignorar ni considerar la prueba aprobada.
SET SERVEROUTPUT ON;

DECLARE
    v_id Pedido.id_pedido%TYPE;
    v_precio Producto.precio%TYPE;
    v_inv Producto.id_inventario%TYPE;
    v_stock_inicial NUMBER;
    v_stock_final NUMBER;
    v_total NUMBER;
    v_lineas NUMBER;
    v_pedidos_inicial NUMBER;
    v_detalles_inicial NUMBER;
    v_audit_inicial NUMBER;
    v_pedidos_final NUMBER;
    v_detalles_final NUMBER;
    v_audit_final NUMBER;
    v_audit_antes NUMBER;
    v_audit_despues NUMBER;
    v_filas NUMBER;
    v_estado Pedido.estado%TYPE;
    v_error_esperado BOOLEAN;
    v_solicitud NUMBER;
    v_error VARCHAR2(4000);
    v_traza VARCHAR2(4000);

    PROCEDURE comprobar(p_condicion BOOLEAN, p_mensaje VARCHAR2) IS
    BEGIN
        IF p_condicion IS NULL OR NOT p_condicion THEN
            RAISE_APPLICATION_ERROR(-20980, 'FALLO: ' || p_mensaje);
        END IF;
    END;
BEGIN
    SAVEPOINT ev2_inicio_prueba;
    SELECT COUNT(*) INTO v_pedidos_inicial FROM Pedido;
    SELECT COUNT(*) INTO v_detalles_inicial FROM detalle_pedido;
    SELECT COUNT(*) INTO v_audit_inicial FROM Auditoria_Pedido;
    SELECT precio, id_inventario INTO v_precio, v_inv
      FROM Producto WHERE id_producto = 1 AND estado = 'A';
    SELECT cantidad INTO v_stock_inicial
      FROM Inventario WHERE id_inventario = v_inv;
    comprobar(v_stock_inicial >= 2, 'Se necesitan al menos dos unidades del producto 1.');
    SELECT estado INTO v_estado FROM Pedido WHERE id_pedido = 1;
    comprobar(v_estado <> 'C', 'El pedido inicial debe estar no cancelado para este escenario.');

    DBMS_OUTPUT.PUT_LINE('INICIO | Pedidos: ' || v_pedidos_inicial ||
                         ' | Detalles: ' || v_detalles_inicial ||
                         ' | Stock: ' || v_stock_inicial ||
                         ' | Auditoria: ' || v_audit_inicial);

    -- A. Registrar un pedido y comprobar sus dos unidades.
    -- Esta llamada conserva activo el trigger antiguo de duplicados.
    PKG_GESTION_PEDIDOS.REGISTRAR_PEDIDO(1, 1, 11111111, v_id);
    PKG_GESTION_PEDIDOS.AGREGAR_DETALLE(v_id, 1, 2);
    v_total := PKG_GESTION_PEDIDOS.OBTENER_TOTAL_PEDIDO(v_id);
    SELECT cantidad INTO v_stock_final
      FROM Inventario WHERE id_inventario = v_inv;
    SELECT COUNT(*) INTO v_lineas FROM detalle_pedido
     WHERE id_pedido = v_id AND id_producto = 1 AND cantidad = 2
       AND precio_unitario = v_precio AND subtotal = 2 * v_precio;
    comprobar(v_total = 2 * v_precio, 'Total del nuevo pedido incorrecto.');
    comprobar(v_stock_final = v_stock_inicial - 2, 'Descuento de stock incorrecto.');
    comprobar(v_lineas = 1, 'Detalle del pedido incorrecto.');
    DBMS_OUTPUT.PUT_LINE('A OK | Pedido: ' || v_id || ' | Total: ' || v_total ||
                         ' | Stock antes: ' || v_stock_inicial ||
                         ' | Stock despues: ' || v_stock_final);

    -- B. Solicitar más que el saldo disponible: debe fallar con -20001.
    v_solicitud := v_stock_final + 1;
    v_error_esperado := FALSE;
    BEGIN
        PKG_GESTION_PEDIDOS.AGREGAR_DETALLE(v_id, 1, v_solicitud);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20001 THEN
                v_error_esperado := TRUE;
                DBMS_OUTPUT.PUT_LINE('B OK | Stock insuficiente: ' || SQLERRM);
            ELSE RAISE;
            END IF;
    END;
    comprobar(v_error_esperado, 'No se rechazo la solicitud que supera el stock.');

    -- C. Cantidad cero: debe fallar con -20006.
    v_error_esperado := FALSE;
    BEGIN
        PKG_GESTION_PEDIDOS.AGREGAR_DETALLE(v_id, 1, 0);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20006 THEN
                v_error_esperado := TRUE;
                DBMS_OUTPUT.PUT_LINE('C OK | Cantidad cero: ' || SQLERRM);
            ELSE RAISE;
            END IF;
    END;
    comprobar(v_error_esperado, 'No se rechazo la cantidad cero.');
    SELECT cantidad INTO v_stock_final
      FROM Inventario WHERE id_inventario = v_inv;
    v_total := PKG_GESTION_PEDIDOS.OBTENER_TOTAL_PEDIDO(v_id);
    SELECT COUNT(*) INTO v_lineas FROM detalle_pedido WHERE id_pedido = v_id;
    comprobar(v_stock_final = v_stock_inicial - 2 AND
              v_total = 2 * v_precio AND v_lineas = 1,
              'Las operaciones rechazadas alteraron datos del pedido.');
    DBMS_OUTPUT.PUT_LINE('BC OK | Sin cambios indebidos | Detalles: ' || v_lineas ||
                         ' | Total: ' || v_total || ' | Stock: ' || v_stock_final);

    -- D. Trigger de fila: cancelar y rechazar la reactivación.
    SAVEPOINT ev2_antes_cancelar;
    UPDATE Pedido SET estado = 'C' WHERE id_pedido = v_id;
    v_error_esperado := FALSE;
    BEGIN
        UPDATE Pedido SET estado = 'P' WHERE id_pedido = v_id;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20012 THEN
                v_error_esperado := TRUE;
                DBMS_OUTPUT.PUT_LINE('D OK | Reactivacion rechazada: ' || SQLERRM);
            ELSE RAISE;
            END IF;
    END;
    comprobar(v_error_esperado, 'Se permitio reactivar el pedido cancelado.');
    SELECT estado INTO v_estado FROM Pedido WHERE id_pedido = v_id;
    comprobar(v_estado = 'C', 'El pedido no conservo el estado cancelado.');
    ROLLBACK TO ev2_antes_cancelar;

    -- E. Trigger de sentencia: dos filas, una entrada en auditoría.
    SELECT COUNT(*) INTO v_audit_antes FROM Auditoria_Pedido;
    UPDATE Pedido SET total = total WHERE id_pedido IN (1, v_id);
    v_filas := SQL%ROWCOUNT;
    SELECT COUNT(*) INTO v_audit_despues FROM Auditoria_Pedido;
    comprobar(v_filas = 2, 'La prueba masiva debe afectar exactamente dos pedidos.');
    comprobar(v_audit_despues - v_audit_antes = 1,
              'La sentencia no genero exactamente una entrada de auditoria.');
    DBMS_OUTPUT.PUT_LINE('E OK | Filas actualizadas: ' || v_filas ||
                         ' | Auditoria antes: ' || v_audit_antes ||
                         ' | Auditoria despues: ' || v_audit_despues ||
                         ' | Incremento: ' || (v_audit_despues - v_audit_antes));

    -- F. Revertir y comprobar los saldos y conteos iniciales.
    ROLLBACK TO ev2_inicio_prueba;
    SELECT COUNT(*) INTO v_pedidos_final FROM Pedido;
    SELECT COUNT(*) INTO v_detalles_final FROM detalle_pedido;
    SELECT COUNT(*) INTO v_audit_final FROM Auditoria_Pedido;
    SELECT cantidad INTO v_stock_final FROM Inventario WHERE id_inventario = v_inv;
    comprobar(v_pedidos_final = v_pedidos_inicial AND
              v_detalles_final = v_detalles_inicial AND
              v_audit_final = v_audit_inicial AND
              v_stock_final = v_stock_inicial,
              'Los conteos o el stock no coinciden tras la reversion.');
    DBMS_OUTPUT.PUT_LINE('F OK | Reversion comprobada | Pedidos: ' || v_pedidos_final ||
                         ' | Detalles: ' || v_detalles_final ||
                         ' | Stock: ' || v_stock_final || ' | Auditoria: ' || v_audit_final);
    DBMS_OUTPUT.PUT_LINE('PRUEBA INTEGRADA COMPLETADA. Datos de prueba revertidos; secuencias consumidas.');
EXCEPTION
    WHEN OTHERS THEN
        v_error := SQLERRM;
        v_traza := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        ROLLBACK TO ev2_inicio_prueba;
        DBMS_OUTPUT.PUT_LINE('PRUEBA NO APROBADA | Cambios de esta prueba revertidos.');
        DBMS_OUTPUT.PUT_LINE(v_error);
        DBMS_OUTPUT.PUT_LINE(v_traza);
        RAISE;
END;
/
