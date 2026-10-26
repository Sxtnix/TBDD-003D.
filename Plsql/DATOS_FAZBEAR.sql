-- ============================================================
-- FAZBEAR PIZZA - COMPONENTES PL/SQL
-- BDY1103 - Taller de Base de Datos - Evaluacion Parcial N1
-- Requiere haber ejecutado antes: FIX_BD_FAZBEAR.sql
-- ============================================================
SET SERVEROUTPUT ON;

-- ============================================================
-- 0. DATOS DE PRUEBA
-- ============================================================
INSERT INTO Tipo_cliente VALUES (1, 'REGULAR', 'Cliente regular');
INSERT INTO Tipo_cliente VALUES (2, 'VIP', 'Cliente frecuente con beneficios');

INSERT INTO tipo_Producto VALUES (1, 'PIZZA', 'Pizzas del menu');
INSERT INTO tipo_Producto VALUES (2, 'BEBIDA', 'Bebestibles');

INSERT INTO Tipo_empleado VALUES (1, 'VENDEDOR', 'Atencion y toma de pedidos');
INSERT INTO Tipo_empleado VALUES (2, 'COCINERO', 'Preparacion de alimentos');

INSERT INTO Tipo_Activo VALUES (1, 'ANIMATRONICO', 'Personajes animatronicos');
INSERT INTO Tipo_Activo VALUES (2, 'ARCADE', 'Maquinas recreativas');

INSERT INTO Pais VALUES (1, 'Chile');
INSERT INTO region VALUES (1, 'Los Lagos', 1);
INSERT INTO Ciudad VALUES (1, 'Puerto Montt', 1);
INSERT INTO Direccion VALUES (1, 'Av. Diego Portales', 1000, 'Frente al mall', 1);

INSERT INTO Local (id_local, nombre, telefono, correo, horario_apertura, horario_cierre, id_direccion)
VALUES (1, 'Fazbear Pizza Puerto Montt', 652123456, 'contacto@fazbear.cl',
        TO_DATE('10:00', 'HH24:MI'), TO_DATE('22:00', 'HH24:MI'), 1);

INSERT INTO Empleado (rut, dv_rut, nombre, ap_paterno, ap_materno, correo, telefono, salario, id_tipo_empleado, id_local)
VALUES (11111111, '1', 'Vicente', 'Placencia', 'Perez', 'vicente@fazbear.cl', 912345678, 550000, 1, 1);

INSERT INTO Cliente (id_cliente, nombre, ap_paterno, ap_materno, correo, telefono, fecha_registro, id_tipo_cliente)
VALUES (1, 'Ana', 'Soto', 'Reyes', 'ana@correo.cl', 987654321, SYSDATE, 2);

INSERT INTO Cliente (id_cliente, nombre, ap_paterno, ap_materno, correo, telefono, fecha_registro, id_tipo_cliente)
VALUES (2, 'Bastian', 'Rojas', 'Lopez', 'bastian@correo.cl', 987000111, SYSDATE, 1);

INSERT INTO Inventario (id_inventario, cantidad, stock_minimo, fecha_actualizacion, id_local)
VALUES (1, 50, 10, SYSDATE, 1);

INSERT INTO Producto (id_producto, nombre, descripcion, precio, estado, id_tipo_producto, id_inventario)
VALUES (1, 'Pizza Familiar', 'Pizza de muzzarella grande', 12000, 'A', 1, 1);

INSERT INTO activo (id_activo, nombre, descripcion, fecha_adquisicion, valor, estado, id_tipo_activo, id_local)
VALUES (1, 'Freddy Animatronic', 'Personaje principal para shows', DATE '2023-01-10', 500000, 'A', 1, 1);

-- Un par de pedidos para probar cursores y reportes
INSERT INTO Pedido (id_pedido, fecha_pedido, estado, total, id_cliente, id_local, empleado_rut)
VALUES (1, SYSDATE - 3, 'E', 12000, 1, 1, 11111111);

INSERT INTO detalle_pedido (id_detalle_pedido, cantidad, precio_unitario, subtotal, id_pedido, id_producto)
VALUES (1, 1, 12000, 12000, 1, 1);

COMMIT;
