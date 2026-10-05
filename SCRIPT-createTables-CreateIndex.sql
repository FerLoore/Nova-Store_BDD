-- ============================================================
-- SISTEMA DE COMPRAS, INVENTARIO, PEDIDOS Y VENTAS
-- Script de creación de base de datos (ORACLE DATABASE 12c+)
-- Tienda de ropa: hombre / mujer, varias marcas (Nike, Adidas...)
-- ============================================================

-- ------------------------------------------------------------
-- MÓDULO: SEGURIDAD
-- ------------------------------------------------------------
CREATE TABLE roles (
    id_rol      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR2(50) NOT NULL UNIQUE,
    descripcion VARCHAR2(150)
);

CREATE TABLE usuarios (
    id_usuario   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_rol       NUMBER NOT NULL REFERENCES roles(id_rol),
    nombre       VARCHAR2(100) NOT NULL,
    correo       VARCHAR2(120) NOT NULL UNIQUE,
    contrasena   VARCHAR2(255) NOT NULL, -- almacenar siempre con hash (bcrypt)
    activo       NUMBER(1) DEFAULT 1 NOT NULL CHECK (activo IN (0,1)),
    creado_en    TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL
);

-- ------------------------------------------------------------
-- MÓDULO: CATÁLOGO (tienda de ropa: hombre / mujer, varias marcas)
-- ------------------------------------------------------------
CREATE TABLE marcas (
    id_marca    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR2(80) NOT NULL UNIQUE,   -- Nike, Adidas, Zara, Distefano...
    descripcion VARCHAR2(200)
);

CREATE TABLE categorias (
    id_categoria NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR2(80) NOT NULL,   -- Camisas, Pantalones, Zapatos, Chaquetas, Vestidos...
    descripcion  VARCHAR2(200)
);

-- Producto genérico: "Playera Polo Nike Dri-Fit". El detalle real de venta
-- (talla, color, stock) vive en variantes_producto.
CREATE TABLE productos (
    id_producto     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_categoria    NUMBER NOT NULL REFERENCES categorias(id_categoria),
    id_marca        NUMBER NOT NULL REFERENCES marcas(id_marca),
    nombre          VARCHAR2(150) NOT NULL,
    descripcion     CLOB,
    genero          VARCHAR2(10) NOT NULL CHECK (genero IN ('HOMBRE','MUJER','UNISEX')),
    temporada       VARCHAR2(30),            -- Verano 2026, Invierno 2026 (opcional)
    activo          NUMBER(1) DEFAULT 1 NOT NULL CHECK (activo IN (0,1)),
    creado_en       TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL
);

-- Cada combinación talla/color es lo que realmente se compra, vende y almacena
CREATE TABLE variantes_producto (
    id_variante     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_producto     NUMBER NOT NULL REFERENCES productos(id_producto) ON DELETE CASCADE,
    talla           VARCHAR2(10) NOT NULL,   -- S, M, L, XL o numérica (32, 34, 8.5...)
    color           VARCHAR2(30) NOT NULL,
    codigo_sku      VARCHAR2(50) NOT NULL UNIQUE,
    precio_compra   NUMBER(12,2) DEFAULT 0 NOT NULL,
    precio_venta    NUMBER(12,2) DEFAULT 0 NOT NULL,
    stock_minimo    NUMBER DEFAULT 0 NOT NULL,
    activo          NUMBER(1) DEFAULT 1 NOT NULL CHECK (activo IN (0,1)),
    CONSTRAINT uq_variante UNIQUE (id_producto, talla, color)
);

-- ------------------------------------------------------------
-- MÓDULO: INVENTARIO
-- ------------------------------------------------------------
CREATE TABLE almacenes (
    id_almacen NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre     VARCHAR2(80) NOT NULL,
    ubicacion  VARCHAR2(150)
);

-- Stock consolidado por variante (talla/color)/almacén (se actualiza vía movimientos)
CREATE TABLE inventario (
    id_inventario NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_variante   NUMBER NOT NULL REFERENCES variantes_producto(id_variante),
    id_almacen    NUMBER NOT NULL REFERENCES almacenes(id_almacen),
    cantidad      NUMBER DEFAULT 0 NOT NULL,
    CONSTRAINT uq_inventario UNIQUE (id_variante, id_almacen)
);

-- Kardex: auditoría de TODO movimiento de inventario
CREATE TABLE movimientos_inventario (
    id_movimiento   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_variante     NUMBER NOT NULL REFERENCES variantes_producto(id_variante),
    id_almacen      NUMBER NOT NULL REFERENCES almacenes(id_almacen),
    tipo_movimiento VARCHAR2(10) NOT NULL CHECK (tipo_movimiento IN ('ENTRADA','SALIDA')),
    cantidad        NUMBER NOT NULL CHECK (cantidad > 0),
    tipo_documento  VARCHAR2(20) NOT NULL, -- 'COMPRA', 'VENTA', 'AJUSTE'
    documento_id    NUMBER,                -- id de la compra/venta que originó el movimiento
    id_usuario      NUMBER NOT NULL REFERENCES usuarios(id_usuario),
    fecha           TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    observacion     VARCHAR2(200)
);

-- ------------------------------------------------------------
-- MÓDULO: COMPRAS
-- ------------------------------------------------------------
CREATE TABLE proveedores (
    id_proveedor NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR2(120) NOT NULL,
    ruc_nit      VARCHAR2(30),
    telefono     VARCHAR2(30),
    correo       VARCHAR2(120),
    direccion    VARCHAR2(200)
);

CREATE TABLE compras (
    id_compra    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_proveedor NUMBER NOT NULL REFERENCES proveedores(id_proveedor),
    id_usuario   NUMBER NOT NULL REFERENCES usuarios(id_usuario),
    fecha        TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    estado       VARCHAR2(20) DEFAULT 'PENDIENTE' NOT NULL
                 CHECK (estado IN ('PENDIENTE','RECIBIDA','CANCELADA')),
    total        NUMBER(12,2) DEFAULT 0 NOT NULL
);

CREATE TABLE detalle_compra (
    id_detalle_compra NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_compra         NUMBER NOT NULL REFERENCES compras(id_compra) ON DELETE CASCADE,
    id_variante       NUMBER NOT NULL REFERENCES variantes_producto(id_variante),
    cantidad          NUMBER NOT NULL CHECK (cantidad > 0),
    precio_unitario   NUMBER(12,2) NOT NULL,
    subtotal          NUMBER(12,2) NOT NULL
);

-- ------------------------------------------------------------
-- MÓDULO: PEDIDOS Y VENTAS
-- ------------------------------------------------------------
CREATE TABLE clientes (
    id_cliente NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre     VARCHAR2(120) NOT NULL,
    dpi_nit    VARCHAR2(30),
    telefono   VARCHAR2(30),
    correo     VARCHAR2(120),
    direccion  VARCHAR2(200)
);

CREATE TABLE pedidos (
    id_pedido  NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente NUMBER NOT NULL REFERENCES clientes(id_cliente),
    id_usuario NUMBER NOT NULL REFERENCES usuarios(id_usuario),
    fecha      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    estado     VARCHAR2(20) DEFAULT 'PENDIENTE' NOT NULL
               CHECK (estado IN ('PENDIENTE','FACTURADO','CANCELADO')),
    total      NUMBER(12,2) DEFAULT 0 NOT NULL
);

CREATE TABLE detalle_pedido (
    id_detalle_pedido NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedido         NUMBER NOT NULL REFERENCES pedidos(id_pedido) ON DELETE CASCADE,
    id_variante       NUMBER NOT NULL REFERENCES variantes_producto(id_variante),
    cantidad          NUMBER NOT NULL CHECK (cantidad > 0),
    precio_unitario   NUMBER(12,2) NOT NULL,
    subtotal          NUMBER(12,2) NOT NULL
);

CREATE TABLE ventas (
    id_venta   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pedido  NUMBER REFERENCES pedidos(id_pedido), -- opcional: venta directa sin pedido previo
    id_cliente NUMBER NOT NULL REFERENCES clientes(id_cliente),
    id_usuario NUMBER NOT NULL REFERENCES usuarios(id_usuario),
    fecha      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    estado     VARCHAR2(20) DEFAULT 'COMPLETADA' NOT NULL
               CHECK (estado IN ('COMPLETADA','ANULADA')),
    total      NUMBER(12,2) DEFAULT 0 NOT NULL
);

CREATE TABLE detalle_venta (
    id_detalle_venta NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_venta         NUMBER NOT NULL REFERENCES ventas(id_venta) ON DELETE CASCADE,
    id_variante      NUMBER NOT NULL REFERENCES variantes_producto(id_variante),
    cantidad         NUMBER NOT NULL CHECK (cantidad > 0),
    precio_unitario  NUMBER(12,2) NOT NULL,
    subtotal         NUMBER(12,2) NOT NULL
);

CREATE TABLE pagos (
    id_pago    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_venta   NUMBER NOT NULL REFERENCES ventas(id_venta),
    fecha      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    monto      NUMBER(12,2) NOT NULL,
    metodo     VARCHAR2(30) NOT NULL CHECK (metodo IN ('EFECTIVO','TARJETA','TRANSFERENCIA'))
);

-- ------------------------------------------------------------
-- ÍNDICES RECOMENDADOS (consultas frecuentes)
-- ------------------------------------------------------------
CREATE INDEX idx_productos_categoria ON productos(id_categoria);
CREATE INDEX idx_productos_marca ON productos(id_marca);
CREATE INDEX idx_productos_genero ON productos(genero);
CREATE INDEX idx_variantes_producto ON variantes_producto(id_producto);
CREATE INDEX idx_movimientos_variante ON movimientos_inventario(id_variante, id_almacen);
CREATE INDEX idx_compras_proveedor ON compras(id_proveedor);
CREATE INDEX idx_ventas_cliente ON ventas(id_cliente);
CREATE INDEX idx_pedidos_cliente ON pedidos(id_cliente);

-- ------------------------------------------------------------
-- TRIGGER: actualizar inventario al registrar un movimiento
-- Oracle no tiene "ON CONFLICT ... DO UPDATE", se usa MERGE
-- ------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_movimiento_inventario
AFTER INSERT ON movimientos_inventario
FOR EACH ROW
DECLARE
    v_delta NUMBER;
BEGIN
    v_delta := CASE WHEN :NEW.tipo_movimiento = 'ENTRADA'
                     THEN :NEW.cantidad
                     ELSE -:NEW.cantidad
               END;

    MERGE INTO inventario inv
    USING (SELECT :NEW.id_variante AS id_variante, :NEW.id_almacen AS id_almacen FROM dual) src
    ON (inv.id_variante = src.id_variante AND inv.id_almacen = src.id_almacen)
    WHEN MATCHED THEN
        UPDATE SET inv.cantidad = inv.cantidad + v_delta
    WHEN NOT MATCHED THEN
        INSERT (id_variante, id_almacen, cantidad)
        VALUES (src.id_variante, src.id_almacen, v_delta);
END;
/