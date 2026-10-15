# Viveros Tajinaste S.A. — Modelo relacional

**Asignatura:** Administración y Diseño de Bases de Datos (ULL)
**Autor/es:** _(completar)_

## Contenido del repositorio

| Fichero | Descripción |
|---|---|
| `viveros(1).drawio` | Modelo entidad/relación (draw.io) |
| `viveros(1).drawio.png` | Imagen del modelo entidad/relación |
| `modelo_relacional.png` | Diseño relacional |
| `viveros.sql` | Script SQL para PostgreSQL |
| `IMG_SELECT/` | Capturas del `SELECT` de cada tabla |

## Modelo relacional

```
VIVERO       (cod_vivero, nombre, telefono, latitud, longitud)
ZONA         (cod_vivero → VIVERO, cod_zona, tipo, latitud?, longitud?)
PRODUCTO     (cod_producto, nombre, categoria, precio)
ALMACENA     ((cod_vivero, cod_zona) → ZONA, cod_producto → PRODUCTO, stock)
EMPLEADO     (dni, nombre, apellidos, email, fecha_contratacion)
PUESTO       (dni_empleado → EMPLEADO, fecha_inicio, fecha_fin?, (cod_vivero, cod_zona) → ZONA,
              tarea, objetivo_ventas?, productividad?)
CLIENTE      (id_cliente, nombre, apellidos, email?, telefono?)
CLIENTE_PLUS (id_cliente → CLIENTE, fecha_ingreso)
PEDIDO       (num_pedido, fecha, id_cliente → CLIENTE_PLUS, dni_empleado → EMPLEADO, /importe_total)
INCLUYE      (num_pedido → PEDIDO, cod_producto → PRODUCTO, cantidad, precio_unitario, /subtotal)
BONIFICACION (id_cliente → CLIENTE_PLUS, mes, /volumen_compras, /importe)
```

`→` clave ajena · `?` admite nulos · `/` atributo derivado

### Paso del modelo E/R al relacional

- **Entidades fuertes:** una tabla por entidad, con su identificador como clave primaria.
- **Entidades débiles** (`zona`, `puesto`, `bonificacion`): la clave primaria es la clave de la entidad fuerte más el discriminante.
- **Relaciones 1:N:** la clave del lado 1 pasa como clave ajena al lado N.
- **Relaciones N:M** (`almacena`, `incluye`): tabla propia con las dos claves ajenas y los atributos de la relación.
- **Jerarquía `cliente` → `cliente_plus`:** una tabla para cada una, con la misma clave.
- **Georreferenciación:** el atributo compuesto se divide en `latitud` y `longitud`.

## Decisiones del script

- **Restricciones:** `NOT NULL` en los campos obligatorios y `CHECK` para formatos (DNI, teléfono, email), listas de valores (`tipo`, `categoria`), rangos de coordenadas y cantidades no negativas.
- **`ON DELETE CASCADE`** cuando el hijo no tiene sentido sin el padre: las zonas de un vivero, el histórico de puestos de un empleado, las líneas de un pedido, y los pedidos y bonificaciones de un cliente Plus.
- **`ON DELETE RESTRICT`** cuando hay que conservar el histórico: no se puede borrar un producto vendido, un empleado con pedidos ni una zona con puestos.
- **`ON UPDATE CASCADE`** en todas las claves ajenas, para que un cambio de código se propague.
- **Atributos derivados:**
  - `subtotal` e `importe` son columnas generadas (`GENERATED ALWAYS AS … STORED`).
  - `importe_total` y `volumen_compras` se calculan con un `UPDATE` después de insertar los datos.

## Ejemplos de `DELETE`

| Operación | Efecto |
|---|---|
| Borrar el producto `DEC-00090` | Borrado simple, sin referencias. |
| Borrar el vivero `VIV-GR06` | `CASCADE`: se borran sus zonas y su stock. |
| Borrar al empleado `46789012T` | `CASCADE`: se borra su histórico de puestos. |
| Borrar el pedido `10237` | `CASCADE`: se borran sus líneas. |
| Borrar al cliente 6 de `cliente_plus` | Deja el programa Plus, pero sigue siendo cliente. |
| Borrar al cliente 5 | `CASCADE`: se borran su registro Plus, sus pedidos, sus líneas y sus bonificaciones. |
| 3 borrados comentados al final del script | Los impide `RESTRICT` y dan error de clave ajena si se ejecutan. |

## Ejecución

```bash
sudo -u postgres psql -f viveros.sql
```

El script borra y vuelve a crear la base de datos `viveros`, crea las tablas, inserta los datos, calcula los derivados, hace los `DELETE` y termina con un `SELECT` de cada tabla.

## Salida de las tablas

Estado final de la base de datos, después de los `DELETE`.

### `vivero`

Viveros de la empresa. `VIV-GR06` no aparece porque se borra en los ejemplos de `DELETE`.

```
viveros=# SELECT * FROM vivero;
 cod_vivero |      nombre       | telefono  |  latitud  |  longitud  
------------+-------------------+-----------+-----------+------------
 VIV-LL01   | Vivero La Laguna  | 922123456 | 28.487400 | -16.315900
 VIV-AD02   | Vivero Adeje      | 922712345 | 28.122700 | -16.726000
 VIV-SC03   | Vivero Santa Cruz | 922234567 | 28.463600 | -16.251800
 VIV-OR04   | Vivero La Orotava | 922334455 | 28.390800 | -16.523600
 VIV-IC05   | Vivero Icod       | 922815566 | 28.367300 | -16.719800
(5 rows)
```

### `zona`

Entidad débil de `vivero`: su clave es `(cod_vivero, cod_zona)`. La zona `VIV-SC03/2` no tiene coordenadas.

```
viveros=# SELECT * FROM zona;
 cod_vivero | cod_zona |    tipo     |  latitud  |  longitud  
------------+----------+-------------+-----------+------------
 VIV-LL01   |        1 | exterior    | 28.487300 | -16.315800
 VIV-LL01   |        2 | almacén     | 28.487600 | -16.316100
 VIV-LL01   |        3 | exposición  | 28.487500 | -16.315700
 VIV-AD02   |        1 | exterior    | 28.122600 | -16.725900
 VIV-AD02   |        2 | invernadero | 28.122900 | -16.726200
 VIV-SC03   |        1 | interior    | 28.463500 | -16.251700
 VIV-SC03   |        2 | exposición  |           |           
 VIV-OR04   |        1 | invernadero | 28.390900 | -16.523500
 VIV-IC05   |        1 | exterior    | 28.367200 | -16.719700
(9 rows)
```

### `producto`

Catálogo de productos. `JAR-00099` tiene precio 0 (producto promocional).

```
viveros=# SELECT * FROM producto;
 cod_producto |             nombre              | categoria  | precio 
--------------+---------------------------------+------------+--------
 PLT-00125    | Drago canario (maceta 20 cm)    | planta     |  24.95
 PLT-00210    | Tajinaste rojo (maceta 15 cm)   | planta     |  18.50
 PLT-00340    | Cardón canario (maceta 12 cm)   | planta     |  12.00
 JAR-00011    | Sustrato universal 50 L         | jardinería |   9.95
 JAR-00057    | Tijera de poda profesional      | jardinería |  15.90
 JAR-00099    | Muestra de semillas (promoción) | jardinería |   0.00
 DEC-00003    | Maceta de barro 30 cm           | decoración |   7.50
(7 rows)
```

### `almacena`

Relación N:M entre `zona` y `producto`, con el `stock`. Un mismo producto puede estar en varias zonas, y hay uno agotado (stock 0).

```
viveros=# SELECT * FROM almacena;
 cod_vivero | cod_zona | cod_producto | stock 
------------+----------+--------------+-------
 VIV-LL01   |        1 | PLT-00340    |    40
 VIV-LL01   |        2 | JAR-00011    |   120
 VIV-LL01   |        2 | DEC-00003    |    60
 VIV-LL01   |        3 | PLT-00125    |    35
 VIV-LL01   |        3 | PLT-00210    |     0
 VIV-AD02   |        2 | PLT-00125    |    18
 VIV-AD02   |        2 | PLT-00210    |    22
 VIV-SC03   |        1 | JAR-00057    |    15
 VIV-SC03   |        2 | PLT-00125    |     9
 VIV-OR04   |        1 | PLT-00340    |    55
(10 rows)
```

### `empleado`

Empleados de la empresa. Laura todavía no tiene puesto (recién contratada).

```
viveros=# SELECT * FROM empleado;
    dni    | nombre |    apellidos     |             email             | fecha_contratacion 
-----------+--------+------------------+-------------------------------+--------------------
 45123456K | Carmen | Hernández Pérez  | carmen.hernandez@tajinaste.es | 2023-03-01
 41234567L | Luis   | Rodríguez Afonso | luis.rodriguez@tajinaste.es   | 2022-01-15
 43456789B | Ana    | Martín Cabrera   | ana.martin@tajinaste.es       | 2024-02-01
 42345678M | Pedro  | García Delgado   | pedro.garcia@tajinaste.es     | 2021-09-01
 44567890X | Laura  | Suárez Mesa      | laura.suarez@tajinaste.es     | 2026-10-01
(5 rows)
```

### `puesto`

Histórico de puestos de cada empleado. Una `fecha_fin` vacía indica el puesto actual, y `objetivo_ventas` solo se usa en tareas de venta.

```
viveros=# SELECT * FROM puesto;
 dni_empleado | fecha_inicio | fecha_fin  | cod_vivero | cod_zona |        tarea        | objetivo_ventas | productividad 
--------------+--------------+------------+------------+----------+---------------------+-----------------+---------------
 45123456K    | 2026-01-10   | 2026-05-31 | VIV-AD02   |        1 | riego               |                 |          95.0
 45123456K    | 2026-06-01   | 2026-09-30 | VIV-LL01   |        3 | atención al cliente |         5000.00 |         112.0
 45123456K    | 2026-10-01   |            | VIV-LL01   |        2 | reposición          |                 |              
 41234567L    | 2025-01-01   | 2025-12-31 | VIV-LL01   |        3 | caja                |         8000.00 |          98.5
 41234567L    | 2026-01-01   |            | VIV-SC03   |        2 | atención al cliente |         6000.00 |              
 43456789B    | 2024-02-01   | 2025-06-30 | VIV-AD02   |        2 | poda                |                 |         101.0
 43456789B    | 2025-07-01   |            | VIV-OR04   |        1 | riego               |                 |              
 42345678M    | 2021-09-01   |            | VIV-SC03   |        1 | logística           |                 |              
(8 rows)
```

### `cliente`

Se identifica con `id_cliente` en lugar del DNI para no guardar datos personales. Algunos clientes no tienen email o teléfono.

![](IMG_SELECT/SELECT_cliente.png)

### `cliente_plus`

Clientes del programa Tajinaste Plus. Carlos y Sofía (8 y 9) no son Plus, y David (6) dejó el programa en los ejemplos de `DELETE`.

![](IMG_SELECT/SELECT_cliente_plus.png)

### `pedido`

`importe_total` es **derivado**: es la suma de los subtotales de las líneas del pedido.

![](IMG_SELECT/SELECT_pedido.png)

### `incluye`

Líneas de pedido (relación N:M entre `pedido` y `producto`). `subtotal` es una **columna generada** (`cantidad × precio_unitario`).

![](IMG_SELECT/SELECT_incluye.png)

### `bonificacion`

`volumen_compras` (suma de los pedidos del mes) e `importe` son **derivados**. Tramos: 0 % si < 50 €, 3 % si < 200 € y 5 % a partir de 200 €.

![](IMG_SELECT/SELECT_bonificacion.png)