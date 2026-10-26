-- EV2 - PRUEBAS FUNCIONALES DE CONSULTA
-- No modifica tablas. Ejecutar como script para ver DBMS_OUTPUT.
-- No requiere desactivar el trigger antiguo: no inserta pedidos.
SET SERVEROUTPUT ON;

-- A. Registrar la version del motor, sin credenciales.
SELECT banner FROM v$version;

-- B. Datos utilizados para interpretar el periodo y el acumulado.
SELECT id_pedido, TO_CHAR(fecha_pedido, 'YYYY-MM-DD') AS fecha,
       estado, total
  FROM Pedido
 ORDER BY id_pedido;

-- C. Procedimiento parametrizado: comparar mes actual con SQL directo.
DECLARE
    v_obtenido NUMBER;
    v_esperado NUMBER;
BEGIN
    SELECT NVL(SUM(total), 0) INTO v_esperado
      FROM Pedido
     WHERE EXTRACT(MONTH FROM fecha_pedido) = EXTRACT(MONTH FROM SYSDATE)
       AND EXTRACT(YEAR FROM fecha_pedido) = EXTRACT(YEAR FROM SYSDATE)
       AND estado <> 'C';

    SP_LIQUIDAR_MES(EXTRACT(MONTH FROM SYSDATE),
                    EXTRACT(YEAR FROM SYSDATE), v_obtenido);

    IF v_obtenido IS NULL OR v_obtenido <> v_esperado THEN
        RAISE_APPLICATION_ERROR(-20990, 'FALLO: acumulado mensual distinto al SQL de control.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('C OK | Mes actual | Esperado: ' || v_esperado ||
                         ' | Obtenido: ' || v_obtenido);
END;
/

-- D. Consultar tambien el periodo del pedido inicial, sin cambiar su fecha.
DECLARE
    v_fecha DATE;
    v_obtenido NUMBER;
    v_esperado NUMBER;
BEGIN
    SELECT fecha_pedido INTO v_fecha FROM Pedido WHERE id_pedido = 1;
    SELECT NVL(SUM(total), 0) INTO v_esperado
      FROM Pedido
     WHERE EXTRACT(MONTH FROM fecha_pedido) = EXTRACT(MONTH FROM v_fecha)
       AND EXTRACT(YEAR FROM fecha_pedido) = EXTRACT(YEAR FROM v_fecha)
       AND estado <> 'C';
    SP_LIQUIDAR_MES(EXTRACT(MONTH FROM v_fecha),
                    EXTRACT(YEAR FROM v_fecha), v_obtenido);
    IF v_obtenido IS NULL OR v_obtenido <> v_esperado THEN
        RAISE_APPLICATION_ERROR(-20991, 'FALLO: acumulado del periodo historico.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('D OK | Periodo ' || TO_CHAR(v_fecha, 'YYYY-MM') ||
                         ' | Esperado: ' || v_esperado || ' | Obtenido: ' || v_obtenido);
END;
/

-- E. Procedimiento sin parametros y consulta de contraste.
BEGIN
    SP_REVISAR_STOCK_CRITICO;
END;
/
SELECT p.id_producto, p.nombre, i.cantidad, i.stock_minimo,
       CASE WHEN i.cantidad <= i.stock_minimo THEN 'CRITICO'
            ELSE 'NO CRITICO' END AS situacion
  FROM Producto p
  JOIN Inventario i ON i.id_inventario = p.id_inventario
 ORDER BY p.id_producto;

-- F. Funciones desde SQL.
SELECT FN_CALCULAR_DESCUENTO(50000, 2) AS descuento_vip,
       FN_CALCULAR_DESCUENTO(50000, 1) AS descuento_regular,
       FN_CALCULAR_DESCUENTO(NULL, 2) AS descuento_total_nulo,
       FN_TOTAL_VENTAS() AS total_historico
  FROM dual;

-- G. Funciones desde PL/SQL: comprobar el resultado, no solo imprimirlo.
DECLARE
    v_vip NUMBER;
    v_regular NUMBER;
    v_nulo NUMBER;
    v_historico NUMBER;
    v_esperado NUMBER;
BEGIN
    v_vip := FN_CALCULAR_DESCUENTO(50000, 2);
    v_regular := FN_CALCULAR_DESCUENTO(50000, 1);
    v_nulo := FN_CALCULAR_DESCUENTO(NULL, 2);
    v_historico := FN_TOTAL_VENTAS();
    SELECT NVL(SUM(total), 0) INTO v_esperado FROM Pedido WHERE estado <> 'C';
    IF v_vip IS NULL OR v_vip <> 5000 OR
       v_regular IS NULL OR v_regular <> 0 OR
       v_nulo IS NULL OR v_nulo <> 0 OR
       v_historico IS NULL OR v_historico <> v_esperado THEN
        RAISE_APPLICATION_ERROR(-20992, 'FALLO: resultados de funciones.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('G OK | VIP: ' || v_vip || ' | Regular: ' || v_regular ||
                         ' | NULL: ' || v_nulo || ' | Historico: ' || v_historico);
END;
/

-- H. Error especifico por total negativo. Si no ocurre o es otro, falla.
DECLARE
    v_resultado NUMBER;
    v_rechazo BOOLEAN := FALSE;
BEGIN
    BEGIN
        v_resultado := FN_CALCULAR_DESCUENTO(-100, 2);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20021 THEN
                v_rechazo := TRUE;
                DBMS_OUTPUT.PUT_LINE('H OK | Rechazo esperado: ' || SQLERRM);
            ELSE
                RAISE;
            END IF;
    END;
    IF NOT v_rechazo THEN
        RAISE_APPLICATION_ERROR(-20993, 'FALLO: no se rechazo el total negativo.');
    END IF;
END;
/
