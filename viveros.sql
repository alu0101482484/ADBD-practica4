-- =============================================================
--  Viveros Tajinaste S.A. - Modelo relacional (PostgreSQL)
--  Ejecutar con:  psql -U postgres -f viveros.sql
-- =============================================================

DROP DATABASE IF EXISTS viveros WITH (FORCE);   -- cierra otras conexiones abiertas
CREATE DATABASE viveros;
\c viveros


-- =============================================================
--  1. TABLAS
-- =============================================================

CREATE TABLE vivero (
    cod_vivero  VARCHAR(10)  PRIMARY KEY,
    nombre      VARCHAR(60)  NOT NULL,
    telefono    CHAR(9)      NOT NULL CHECK (telefono ~ '^[0-9]{9}$'),
    latitud     NUMERIC(8,6) NOT NULL CHECK (latitud  BETWEEN  -90 AND  90),
    longitud    NUMERIC(9,6) NOT NULL CHECK (longitud BETWEEN -180 AND 180)
);

-- Entidad débil de VIVERO: si se borra el vivero, se borran sus zonas
CREATE TABLE zona (
    cod_vivero  VARCHAR(10)  REFERENCES vivero ON DELETE CASCADE ON UPDATE CASCADE,
    cod_zona    INTEGER      CHECK (cod_zona > 0),
    tipo        VARCHAR(12)  NOT NULL
                CHECK (tipo IN ('exterior', 'interior', 'almacén', 'invernadero', 'exposición')),
    latitud     NUMERIC(8,6) CHECK (latitud  BETWEEN  -90 AND  90),
    longitud    NUMERIC(9,6) CHECK (longitud BETWEEN -180 AND 180),
    PRIMARY KEY (cod_vivero, cod_zona)
);

CREATE TABLE producto (
    cod_producto VARCHAR(15)   PRIMARY KEY,
    nombre       VARCHAR(80)   NOT NULL,
    categoria    VARCHAR(12)   NOT NULL CHECK (categoria IN ('planta', 'jardinería', 'decoración')),
    precio       NUMERIC(10,2) NOT NULL CHECK (precio >= 0)
);

-- Relación N:M ZONA - PRODUCTO
CREATE TABLE almacena (
    cod_vivero   VARCHAR(10),
    cod_zona     INTEGER,
    cod_producto VARCHAR(15) REFERENCES producto ON DELETE CASCADE ON UPDATE CASCADE,
    stock        INTEGER     NOT NULL DEFAULT 0 CHECK (stock >= 0),
    PRIMARY KEY (cod_vivero, cod_zona, cod_producto),
    FOREIGN KEY (cod_vivero, cod_zona) REFERENCES zona ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE empleado (
    dni                CHAR(9)      PRIMARY KEY CHECK (dni ~ '^[0-9]{8}[A-Z]$'),
    nombre             VARCHAR(40)  NOT NULL,
    apellidos          VARCHAR(80)  NOT NULL,
    email              VARCHAR(100) NOT NULL UNIQUE CHECK (email LIKE '%@%.%'),
    fecha_contratacion DATE         NOT NULL
);

-- Entidad débil de EMPLEADO (histórico de puestos)
--   - si se borra el empleado, se borra su histórico (CASCADE)
--   - no se puede borrar una zona con histórico de puestos (RESTRICT)
CREATE TABLE puesto (
    dni_empleado    CHAR(9)       REFERENCES empleado ON DELETE CASCADE ON UPDATE CASCADE,
    fecha_inicio    DATE,
    fecha_fin       DATE,                       -- NULL = puesto actual
    cod_vivero      VARCHAR(10)   NOT NULL,
    cod_zona        INTEGER       NOT NULL,
    tarea           VARCHAR(25)   NOT NULL,
    objetivo_ventas NUMERIC(10,2) CHECK (objetivo_ventas >= 0),
    productividad   NUMERIC(5,1)  CHECK (productividad >= 0),
    PRIMARY KEY (dni_empleado, fecha_inicio),
    FOREIGN KEY (cod_vivero, cod_zona) REFERENCES zona ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);

-- Se usa un identificador numérico en lugar del DNI para no guardar datos personales
CREATE TABLE cliente (
    id_cliente INTEGER      PRIMARY KEY CHECK (id_cliente > 0),
    nombre     VARCHAR(40)  NOT NULL,
    apellidos  VARCHAR(80)  NOT NULL,
    email      VARCHAR(100) UNIQUE CHECK (email LIKE '%@%.%'),
    telefono   CHAR(9)      CHECK (telefono ~ '^[0-9]{9}$')
);

-- Subtipo de CLIENTE (jerarquía parcial): misma clave que CLIENTE
CREATE TABLE cliente_plus (
    id_cliente    INTEGER PRIMARY KEY REFERENCES cliente ON DELETE CASCADE ON UPDATE CASCADE,
    fecha_ingreso DATE    NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE pedido (
    num_pedido    INTEGER       PRIMARY KEY,
    fecha         DATE          NOT NULL DEFAULT CURRENT_DATE,
    id_cliente    INTEGER       NOT NULL REFERENCES cliente_plus ON DELETE CASCADE  ON UPDATE CASCADE,
    dni_empleado  CHAR(9)       NOT NULL REFERENCES empleado     ON DELETE RESTRICT ON UPDATE CASCADE,
    importe_total NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (importe_total >= 0)   -- DERIVADO
);

-- Relación N:M PRODUCTO - PEDIDO (líneas de pedido)
CREATE TABLE incluye (
    num_pedido      INTEGER       REFERENCES pedido   ON DELETE CASCADE  ON UPDATE CASCADE,
    cod_producto    VARCHAR(15)   REFERENCES producto ON DELETE RESTRICT ON UPDATE CASCADE,
    cantidad        INTEGER       NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario >= 0),
    -- DERIVADO: se calcula automáticamente
    subtotal        NUMERIC(12,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
    PRIMARY KEY (num_pedido, cod_producto)
);

-- Entidad débil de CLIENTE_PLUS. El mes se guarda como el día 1 de ese mes.
CREATE TABLE bonificacion (
    id_cliente      INTEGER       REFERENCES cliente_plus ON DELETE CASCADE ON UPDATE CASCADE,
    mes             DATE          CHECK (EXTRACT(DAY FROM mes) = 1),
    volumen_compras NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (volumen_compras >= 0),  -- DERIVADO
    -- DERIVADO: 0 % si < 50 €, 3 % si < 200 €, 5 % a partir de 200 €
    importe         NUMERIC(10,2) GENERATED ALWAYS AS (
                        ROUND(volumen_compras * CASE WHEN volumen_compras >= 200 THEN 0.05
                                                     WHEN volumen_compras >=  50 THEN 0.03
                                                     ELSE 0 END, 2)) STORED,
    PRIMARY KEY (id_cliente, mes)
);


-- =============================================================
--  2. DATOS
-- =============================================================

INSERT INTO vivero VALUES
    ('VIV-LL01', 'Vivero La Laguna',  '922123456', 28.487400, -16.315900),
    ('VIV-AD02', 'Vivero Adeje',      '922712345', 28.122700, -16.726000),
    ('VIV-SC03', 'Vivero Santa Cruz', '922234567', 28.463600, -16.251800),
    ('VIV-OR04', 'Vivero La Orotava', '922334455', 28.390800, -16.523600),
    ('VIV-IC05', 'Vivero Icod',       '922815566', 28.367300, -16.719800),
    ('VIV-GR06', 'Vivero Granadilla', '922776688', 28.118500, -16.576000);

INSERT INTO zona VALUES
    ('VIV-LL01', 1, 'exterior',    28.487300, -16.315800),
    ('VIV-LL01', 2, 'almacén',     28.487600, -16.316100),
    ('VIV-LL01', 3, 'exposición',  28.487500, -16.315700),
    ('VIV-AD02', 1, 'exterior',    28.122600, -16.725900),
    ('VIV-AD02', 2, 'invernadero', 28.122900, -16.726200),
    ('VIV-SC03', 1, 'interior',    28.463500, -16.251700),
    ('VIV-SC03', 2, 'exposición',  NULL,      NULL),        -- sin coordenadas
    ('VIV-OR04', 1, 'invernadero', 28.390900, -16.523500),
    ('VIV-IC05', 1, 'exterior',    28.367200, -16.719700),  -- zona sin productos
    ('VIV-GR06', 1, 'exterior',    28.118400, -16.575900),
    ('VIV-GR06', 2, 'almacén',     28.118600, -16.576100);

INSERT INTO producto VALUES
    ('PLT-00125', 'Drago canario (maceta 20 cm)',    'planta',     24.95),
    ('PLT-00210', 'Tajinaste rojo (maceta 15 cm)',   'planta',     18.50),
    ('PLT-00340', 'Cardón canario (maceta 12 cm)',   'planta',     12.00),
    ('JAR-00011', 'Sustrato universal 50 L',         'jardinería',  9.95),
    ('JAR-00057', 'Tijera de poda profesional',      'jardinería', 15.90),
    ('JAR-00099', 'Muestra de semillas (promoción)', 'jardinería',  0.00),
    ('DEC-00003', 'Maceta de barro 30 cm',           'decoración',  7.50),
    ('DEC-00090', 'Farol solar de jardín',           'decoración', 22.00);  -- sin stock ni ventas

INSERT INTO almacena VALUES
    ('VIV-LL01', 1, 'PLT-00340',  40),
    ('VIV-LL01', 2, 'JAR-00011', 120),
    ('VIV-LL01', 2, 'DEC-00003',  60),
    ('VIV-LL01', 3, 'PLT-00125',  35),
    ('VIV-LL01', 3, 'PLT-00210',   0),   -- agotado
    ('VIV-AD02', 2, 'PLT-00125',  18),   -- mismo producto en otro vivero
    ('VIV-AD02', 2, 'PLT-00210',  22),
    ('VIV-SC03', 1, 'JAR-00057',  15),
    ('VIV-SC03', 2, 'PLT-00125',   9),
    ('VIV-OR04', 1, 'PLT-00340',  55),
    ('VIV-GR06', 1, 'PLT-00340',  30),
    ('VIV-GR06', 2, 'JAR-00011',  80);

INSERT INTO empleado VALUES
    ('45123456K', 'Carmen', 'Hernández Pérez',  'carmen.hernandez@tajinaste.es', '2023-03-01'),
    ('41234567L', 'Luis',   'Rodríguez Afonso', 'luis.rodriguez@tajinaste.es',   '2022-01-15'),
    ('43456789B', 'Ana',    'Martín Cabrera',   'ana.martin@tajinaste.es',       '2024-02-01'),
    ('42345678M', 'Pedro',  'García Delgado',   'pedro.garcia@tajinaste.es',     '2021-09-01'),
    ('46789012T', 'Sergio', 'Ramos Expósito',   'sergio.ramos@tajinaste.es',     '2025-05-01'),
    ('44567890X', 'Laura',  'Suárez Mesa',      'laura.suarez@tajinaste.es',     '2026-10-01');  -- sin puesto

INSERT INTO puesto VALUES
    ('45123456K', '2026-01-10', '2026-05-31', 'VIV-AD02', 1, 'riego',               NULL,     95.0),
    ('45123456K', '2026-06-01', '2026-09-30', 'VIV-LL01', 3, 'atención al cliente', 5000.00, 112.0),
    ('45123456K', '2026-10-01', NULL,         'VIV-LL01', 2, 'reposición',          NULL,    NULL),
    ('41234567L', '2025-01-01', '2025-12-31', 'VIV-LL01', 3, 'caja',                8000.00,  98.5),
    ('41234567L', '2026-01-01', NULL,         'VIV-SC03', 2, 'atención al cliente', 6000.00, NULL),
    ('43456789B', '2024-02-01', '2025-06-30', 'VIV-AD02', 2, 'poda',                NULL,    101.0),
    ('43456789B', '2025-07-01', NULL,         'VIV-OR04', 1, 'riego',               NULL,    NULL),
    ('42345678M', '2021-09-01', NULL,         'VIV-SC03', 1, 'logística',           NULL,    NULL),
    ('46789012T', '2025-05-01', '2025-10-31', 'VIV-IC05', 1, 'riego',               NULL,     88.0),
    ('46789012T', '2026-03-01', NULL,         'VIV-LL01', 1, 'poda',                NULL,    NULL);

INSERT INTO cliente VALUES
    (1, 'Javier',    'González Díaz',    'javi.gd@gmail.com',        '678123456'),
    (2, 'María',     'Pérez Hernández',  'maria.ph@hotmail.com',     '622334455'),
    (3, 'Elena',     'Torres Rivero',    'elena.torres@gmail.com',   NULL),
    (4, 'Alejandro', 'Febles Correa',    'afebles@yahoo.es',         '655443322'),
    (5, 'Nayra',     'Bethencourt León', 'nayra.bl@gmail.com',       '644556677'),
    (6, 'David',     'Alonso Santana',   'david.alonso@outlook.com', '611223344'),
    (7, 'Raquel',    'Quintero Vera',    NULL,                       '699887766'),
    (8, 'Carlos',    'Díaz Morales',     'carlosdm@gmail.com',       NULL),         -- no es Plus
    (9, 'Sofía',     'Fumero Castro',    NULL,                       '633221100');  -- no es Plus

INSERT INTO cliente_plus VALUES
    (1, '2024-06-15'),
    (2, '2025-01-10'),
    (3, '2026-03-01'),
    (4, '2025-05-05'),
    (5, '2023-11-20'),
    (6, '2026-09-01'),
    (7, '2026-02-14');   -- sin pedidos

-- importe_total se deja a 0: se calcula después
INSERT INTO pedido (num_pedido, fecha, id_cliente, dni_empleado) VALUES
    (10230, '2025-11-03', 1, '41234567L'),
    (10231, '2026-07-12', 1, '45123456K'),
    (10232, '2026-08-05', 1, '45123456K'),
    (10233, '2026-08-21', 2, '45123456K'),
    (10234, '2026-09-20', 1, '45123456K'),
    (10235, '2026-09-25', 3, '41234567L'),
    (10236, '2026-08-14', 5, '41234567L'),
    (10237, '2026-10-02', 2, '41234567L'),
    (10238, '2026-09-10', 4, '45123456K');

-- subtotal no se indica: es una columna generada
INSERT INTO incluye (num_pedido, cod_producto, cantidad, precio_unitario) VALUES
    (10230, 'PLT-00210',  2, 17.90),   -- precio antiguo (hoy 18.50)
    (10230, 'JAR-00011',  1,  9.95),
    (10231, 'PLT-00125',  1, 24.95),
    (10231, 'DEC-00003',  2,  7.50),
    (10232, 'PLT-00340',  3, 12.00),
    (10232, 'JAR-00057',  1, 15.90),
    (10232, 'JAR-00011',  2,  9.95),
    (10233, 'PLT-00125',  4, 24.95),
    (10233, 'DEC-00003',  6,  7.50),
    (10234, 'PLT-00125',  3, 24.95),
    (10234, 'JAR-00099',  1,  0.00),   -- regalo
    (10235, 'PLT-00210', 10, 18.50),
    (10235, 'JAR-00011',  5,  9.95),
    (10236, 'JAR-00057',  2, 15.90),
    (10237, 'DEC-00003',  1,  7.50),
    (10237, 'PLT-00340',  2, 12.00),
    (10238, 'PLT-00125', 10, 22.50),
    (10238, 'JAR-00011', 10,  9.95);

-- volumen_compras se deja a 0: se calcula después; importe es generado
INSERT INTO bonificacion (id_cliente, mes) VALUES
    (1, '2025-11-01'),
    (1, '2026-07-01'),
    (1, '2026-08-01'),
    (1, '2026-09-01'),
    (2, '2026-08-01'),
    (2, '2026-10-01'),
    (3, '2026-09-01'),
    (4, '2026-09-01'),
    (5, '2026-08-01'),
    (7, '2026-03-01');   -- mes sin compras


-- =============================================================
--  3. CÁLCULO DE ATRIBUTOS DERIVADOS
-- =============================================================

-- importe_total = suma de los subtotales de sus líneas
UPDATE pedido p
   SET importe_total = (SELECT COALESCE(SUM(i.subtotal), 0)
                          FROM incluye i
                         WHERE i.num_pedido = p.num_pedido);

-- volumen_compras = suma de los pedidos del cliente en ese mes
-- (importe se recalcula solo al ser columna generada)
UPDATE bonificacion b
   SET volumen_compras = (SELECT COALESCE(SUM(p.importe_total), 0)
                            FROM pedido p
                           WHERE p.id_cliente = b.id_cliente
                             AND date_trunc('month', p.fecha) = b.mes);


-- =============================================================
--  4. EJEMPLOS DE DELETE
-- =============================================================

-- Borrado simple: producto sin stock ni ventas
DELETE FROM producto WHERE cod_producto = 'DEC-00090';

-- CASCADE: al borrar el vivero se borran sus zonas y el stock de esas zonas
DELETE FROM vivero WHERE cod_vivero = 'VIV-GR06';

-- CASCADE: al borrar el empleado se borra su histórico de puestos
DELETE FROM empleado WHERE dni = '46789012T';

-- CASCADE: al borrar un pedido se borran sus líneas
DELETE FROM pedido WHERE num_pedido = 10237;

-- Un cliente deja el programa Plus pero sigue siendo cliente
DELETE FROM cliente_plus WHERE id_cliente = 6;

-- CASCADE: cliente -> cliente_plus -> pedidos -> líneas, y bonificaciones
DELETE FROM cliente WHERE id_cliente = 5;

-- Tras borrar el pedido 10237, se vuelve a calcular la bonificación afectada
UPDATE bonificacion b
   SET volumen_compras = (SELECT COALESCE(SUM(p.importe_total), 0)
                            FROM pedido p
                           WHERE p.id_cliente = b.id_cliente
                             AND date_trunc('month', p.fecha) = b.mes);

-- Borrados que PostgreSQL NO permite (ON DELETE RESTRICT). Si se quitan los
-- comentarios, dan error de clave ajena:
-- DELETE FROM producto WHERE cod_producto = 'PLT-00125';  -- aparece en pedidos
-- DELETE FROM empleado WHERE dni = '45123456K';           -- gestiona pedidos
-- DELETE FROM vivero   WHERE cod_vivero = 'VIV-LL01';     -- sus zonas tienen puestos


-- =============================================================
--  5. CONSULTA DE TODAS LAS TABLAS
-- =============================================================
SELECT * FROM vivero;
SELECT * FROM zona;
SELECT * FROM producto;
SELECT * FROM almacena;
SELECT * FROM empleado;
SELECT * FROM puesto;
SELECT * FROM cliente;
SELECT * FROM cliente_plus;
SELECT * FROM pedido;
SELECT * FROM incluye;
SELECT * FROM bonificacion;