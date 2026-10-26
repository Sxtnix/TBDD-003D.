-- ============================================================
-- FAZBEAR PIZZA - SCRIPT DE BASE DE DATOS (CORREGIDO)
-- BDY1103 - Taller de Base de Datos
-- ============================================================
-- QUE SE CORRIGIO Y POR QUE:
--
-- 1) Las PK compuestas del script original se iban heredando de
--    tabla en tabla (Pais -> region -> Ciudad -> Direccion -> Local),
--    y lo mismo pasaba con Empleado -> Pedido. Eso hizo que la PK
--    de Pedido terminara con 6 columnas, y que detalle_pedido
--    tuviera que copiar esas 6 columnas solo para referenciar a
--    Pedido, dejando fuera al Producto.
--
-- 2) Aca se vuelve a PK simples: un solo NUMBER autoincremental
--    (SEQUENCE + TRIGGER, o IDENTITY) por tabla, y FK normales de
--    una sola columna. Es el mismo modelo del informe, pero ahora
--    el script de creacion coincide con el.
--
-- 3) Se agrega la FK que faltaba: detalle_pedido -> Producto.
-- ============================================================

-- ------------------------------------------------------------
-- 0. LIMPIEZA (por si el script anterior ya se ejecuto)
-- ------------------------------------------------------------
DROP TABLE detalle_pedido    CASCADE CONSTRAINTS PURGE;
DROP TABLE Pedido            CASCADE CONSTRAINTS PURGE;
DROP TABLE Producto          CASCADE CONSTRAINTS PURGE;
DROP TABLE Inventario        CASCADE CONSTRAINTS PURGE;
DROP TABLE Cliente           CASCADE CONSTRAINTS PURGE;
DROP TABLE Empleado          CASCADE CONSTRAINTS PURGE;
DROP TABLE activo            CASCADE CONSTRAINTS PURGE;
DROP TABLE Local             CASCADE CONSTRAINTS PURGE;
DROP TABLE Direccion         CASCADE CONSTRAINTS PURGE;
DROP TABLE Ciudad            CASCADE CONSTRAINTS PURGE;
DROP TABLE region            CASCADE CONSTRAINTS PURGE;
DROP TABLE Pais              CASCADE CONSTRAINTS PURGE;
DROP TABLE Tipo_Activo       CASCADE CONSTRAINTS PURGE;
DROP TABLE Tipo_empleado     CASCADE CONSTRAINTS PURGE;
DROP TABLE Tipo_cliente      CASCADE CONSTRAINTS PURGE;
DROP TABLE tipo_Producto     CASCADE CONSTRAINTS PURGE;

DROP SEQUENCE seq_pedido;
DROP SEQUENCE seq_detalle_pedido;

-- ------------------------------------------------------------
-- 1. TABLAS MAESTRAS (sin FK)
-- ------------------------------------------------------------
CREATE TABLE Pais (
    id_pais NUMBER NOT NULL,
    nombre  VARCHAR2(20) NOT NULL,
    CONSTRAINT Pais_PK PRIMARY KEY (id_pais)
);

CREATE TABLE Tipo_Activo (
    id_tipo_activo NUMBER NOT NULL,
    nombre         VARCHAR2(25) NOT NULL,
    descripcion    VARCHAR2(50),
    CONSTRAINT Tipo_Activo_PK PRIMARY KEY (id_tipo_activo)
);

CREATE TABLE Tipo_empleado (
    id_tipo_empleado NUMBER NOT NULL,
    nombre           VARCHAR2(25) NOT NULL,
    descripcion      VARCHAR2(50),
    CONSTRAINT Tipo_empleado_PK PRIMARY KEY (id_tipo_empleado)
);

CREATE TABLE Tipo_cliente (
    id_tipo_cliente NUMBER NOT NULL,
    nombre          VARCHAR2(30) NOT NULL,
    descripcion     VARCHAR2(50),
    CONSTRAINT Tipo_cliente_PK PRIMARY KEY (id_tipo_cliente)
);

CREATE TABLE tipo_Producto (
    id_tipo_producto NUMBER NOT NULL,
    nombre           VARCHAR2(25) NOT NULL,
    descripcion      VARCHAR2(50),
    CONSTRAINT tipo_Producto_PK PRIMARY KEY (id_tipo_producto)
);

-- ------------------------------------------------------------
-- 2. GEOGRAFIA (ahora con PK simple en cada nivel)
-- ------------------------------------------------------------
CREATE TABLE region (
    id_region NUMBER NOT NULL,
    nombre    VARCHAR2(25) NOT NULL,
    id_pais   NUMBER NOT NULL,
    CONSTRAINT region_PK PRIMARY KEY (id_region),
    CONSTRAINT region_Pais_FK FOREIGN KEY (id_pais) REFERENCES Pais (id_pais)
);

CREATE TABLE Ciudad (
    id_ciudad NUMBER NOT NULL,
    nombre    VARCHAR2(25) NOT NULL,
    id_region NUMBER NOT NULL,
    CONSTRAINT Ciudad_PK PRIMARY KEY (id_ciudad),
    CONSTRAINT Ciudad_region_FK FOREIGN KEY (id_region) REFERENCES region (id_region)
);

CREATE TABLE Direccion (
    id_direccion NUMBER NOT NULL,
    calle        VARCHAR2(30) NOT NULL,
    numero       NUMBER,
    referencia   VARCHAR2(50),
    id_ciudad    NUMBER NOT NULL,
    CONSTRAINT Direccion_PK PRIMARY KEY (id_direccion),
    CONSTRAINT Direccion_Ciudad_FK FOREIGN KEY (id_ciudad) REFERENCES Ciudad (id_ciudad)
);

-- ------------------------------------------------------------
-- 3. LOCAL
-- ------------------------------------------------------------
CREATE TABLE Local (
    id_local          NUMBER NOT NULL,
    nombre            VARCHAR2(40) NOT NULL,
    telefono          NUMBER,
    correo            VARCHAR2(25),
    horario_apertura  DATE,
    horario_cierre    DATE,
    id_direccion      NUMBER NOT NULL,
    CONSTRAINT Local_PK PRIMARY KEY (id_local),
    CONSTRAINT Local_Direccion_FK FOREIGN KEY (id_direccion) REFERENCES Direccion (id_direccion)
);

-- ------------------------------------------------------------
-- 4. ENTIDADES RELACIONADAS A LOCAL
-- ------------------------------------------------------------
CREATE TABLE activo (
    id_activo          NUMBER NOT NULL,
    nombre             VARCHAR2(25) NOT NULL,
    descripcion        VARCHAR2(50),
    fecha_adquisicion  DATE,
    valor              NUMBER,
    estado             CHAR(1) NOT NULL,   -- 'A' = disponible / 'N' = no disponible
    id_tipo_activo     NUMBER NOT NULL,
    id_local           NUMBER NOT NULL,
    CONSTRAINT activo_PK PRIMARY KEY (id_activo),
    CONSTRAINT activo_Tipo_Activo_FK FOREIGN KEY (id_tipo_activo) REFERENCES Tipo_Activo (id_tipo_activo),
    CONSTRAINT activo_Local_FK FOREIGN KEY (id_local) REFERENCES Local (id_local)
);

CREATE TABLE Empleado (
    rut               NUMBER NOT NULL,
    dv_rut            VARCHAR2(1),
    nombre            VARCHAR2(30) NOT NULL,
    ap_paterno        VARCHAR2(25),
    ap_materno        VARCHAR2(30),
    correo            VARCHAR2(50),
    telefono          NUMBER,
    salario           NUMBER,
    id_tipo_empleado  NUMBER NOT NULL,
    id_local          NUMBER NOT NULL,
    CONSTRAINT Empleado_PK PRIMARY KEY (rut),
    CONSTRAINT Empleado_Tipo_empleado_FK FOREIGN KEY (id_tipo_empleado) REFERENCES Tipo_empleado (id_tipo_empleado),
    CONSTRAINT Empleado_Local_FK FOREIGN KEY (id_local) REFERENCES Local (id_local)
);

CREATE TABLE Cliente (
    id_cliente       NUMBER NOT NULL,
    nombre           VARCHAR2(25) NOT NULL,
    ap_paterno       VARCHAR2(30),
    ap_materno       VARCHAR2(30),
    correo           VARCHAR2(50),
    telefono         NUMBER,
    fecha_registro   DATE DEFAULT SYSDATE,
    id_tipo_cliente  NUMBER NOT NULL,
    CONSTRAINT Cliente_PK PRIMARY KEY (id_cliente),
    CONSTRAINT Cliente_Tipo_cliente_FK FOREIGN KEY (id_tipo_cliente) REFERENCES Tipo_cliente (id_tipo_cliente)
);

CREATE TABLE Inventario (
    id_inventario         NUMBER NOT NULL,
    cantidad              NUMBER NOT NULL,
    stock_minimo          NUMBER NOT NULL,
    fecha_actualizacion   DATE DEFAULT SYSDATE,
    id_local              NUMBER NOT NULL,
    CONSTRAINT Inventario_PK PRIMARY KEY (id_inventario),
    CONSTRAINT Inventario_Local_FK FOREIGN KEY (id_local) REFERENCES Local (id_local)
);

CREATE TABLE Producto (
    id_producto        NUMBER NOT NULL,
    nombre             VARCHAR2(25) NOT NULL,
    descripcion        VARCHAR2(50),
    precio             NUMBER NOT NULL,
    estado             CHAR(1) NOT NULL,   -- 'A' = activo / 'I' = inactivo
    id_tipo_producto   NUMBER NOT NULL,
    id_inventario      NUMBER NOT NULL,
    CONSTRAINT Producto_PK PRIMARY KEY (id_producto),
    CONSTRAINT Producto_tipo_Producto_FK FOREIGN KEY (id_tipo_producto) REFERENCES tipo_Producto (id_tipo_producto),
    CONSTRAINT Producto_Inventario_FK FOREIGN KEY (id_inventario) REFERENCES Inventario (id_inventario)
);

-- ------------------------------------------------------------
-- 5. TABLAS TRANSACCIONALES (Pedidos)
-- ------------------------------------------------------------
CREATE TABLE Pedido (
    id_pedido      NUMBER NOT NULL,
    fecha_pedido   DATE DEFAULT SYSDATE,
    estado         CHAR(1) NOT NULL,   -- 'P' pendiente / 'X' en preparacion / 'E' entregado / 'C' cancelado
    total          NUMBER DEFAULT 0,
    id_cliente     NUMBER NOT NULL,
    id_local       NUMBER NOT NULL,
    empleado_rut   NUMBER NOT NULL,
    CONSTRAINT Pedido_PK PRIMARY KEY (id_pedido),
    CONSTRAINT Pedido_Cliente_FK FOREIGN KEY (id_cliente) REFERENCES Cliente (id_cliente),
    CONSTRAINT Pedido_Local_FK FOREIGN KEY (id_local) REFERENCES Local (id_local),
    CONSTRAINT Pedido_Empleado_FK FOREIGN KEY (empleado_rut) REFERENCES Empleado (rut)
);

-- *** ESTA ES LA TABLA QUE FALTABA ARREGLAR ***
-- Antes no tenia como referenciar a Producto. Ahora id_producto
-- es una FK normal de una sola columna, igual que id_pedido.
CREATE TABLE detalle_pedido (
    id_detalle_pedido  NUMBER NOT NULL,
    cantidad           NUMBER NOT NULL,
    precio_unitario    NUMBER NOT NULL,
    subtotal           NUMBER NOT NULL,
    id_pedido          NUMBER NOT NULL,
    id_producto        NUMBER NOT NULL,
    CONSTRAINT detalle_pedido_PK PRIMARY KEY (id_detalle_pedido),
    CONSTRAINT detalle_Pedido_FK FOREIGN KEY (id_pedido) REFERENCES Pedido (id_pedido),
    CONSTRAINT detalle_Producto_FK FOREIGN KEY (id_producto) REFERENCES Producto (id_producto)
);

-- ------------------------------------------------------------
-- 6. SECUENCIAS (para generar IDs de Pedido y Detalle automaticamente
--    desde el PL/SQL, en vez de escribirlos a mano)
-- ------------------------------------------------------------
CREATE SEQUENCE seq_pedido START WITH 100 INCREMENT BY 1;
CREATE SEQUENCE seq_detalle_pedido START WITH 100 INCREMENT BY 1;

COMMIT;
