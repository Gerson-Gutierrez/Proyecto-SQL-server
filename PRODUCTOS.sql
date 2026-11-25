USE DBProyectoGestionComercial;
GO

/*  NOTA: dentro de un bloque BEGIN TRY, un RAISERROR de severidad 16 salta
    directamente al BEGIN CATCH. Por eso las validaciones solo hacen RAISERROR
    y el CATCH se encarga de deshacer la transacción (si hay una abierta)
    y de relanzar el error con THROW.  */


/*-----------------------------------Trigger: validar producto------------------------------------------------------*/

CREATE OR ALTER TRIGGER TR_ValidarProductoUnico
ON Productos
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar que ningún campo obligatorio esté vacío o nulo
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE
            -- Campos string no nulos ni vacíos (ni espacios en blanco)
            LTRIM(RTRIM(ISNULL(Nombre, ''))) = ''
            OR LTRIM(RTRIM(ISNULL(Descripcion, ''))) = ''
            -- Campos numéricos no nulos y válidos
            OR PrecioUnitario IS NULL OR PrecioUnitario <= 0
            OR PrecioSinImpuesto IS NULL OR PrecioSinImpuesto <= 0
            OR PrecioSinImpuesto > PrecioUnitario
            OR Stock IS NULL OR Stock < 0
            OR ID_Categoria IS NULL
    )
    BEGIN
        RAISERROR('Todos los campos obligatorios deben estar completos y válidos (no vacíos, no nulos, precios positivos y stock no negativo).', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Validar que no exista otro producto con el mismo nombre
    -- (la intercalación de la base es CI_AI: no distingue mayúsculas ni acentos)
    IF EXISTS (
        SELECT 1
        FROM Productos p
        JOIN inserted i ON LTRIM(RTRIM(p.Nombre)) = LTRIM(RTRIM(i.Nombre))
    )
    OR EXISTS (
        SELECT 1
        FROM inserted
        GROUP BY LTRIM(RTRIM(Nombre))
        HAVING COUNT(*) > 1
    )
    BEGIN
        RAISERROR('Ya existe un producto con el mismo nombre.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Insertar los datos válidos
    INSERT INTO Productos (Nombre, Descripcion, PrecioUnitario, PrecioSinImpuesto, Stock, ID_Categoria, Estado)
    SELECT LTRIM(RTRIM(Nombre)), LTRIM(RTRIM(Descripcion)), PrecioUnitario, PrecioSinImpuesto, Stock, ID_Categoria, ISNULL(Estado, 1)
    FROM inserted;
END;
GO



/*-----------------------------------Agregar Producto------------------------------------------------------*/

CREATE OR ALTER PROCEDURE AgregarProducto(
    @ID_UsuarioEjecutor INT,
    @Nombre NVARCHAR(50),
    @Descripcion NVARCHAR(100),
    @PrecioUnitario DECIMAL(10,2),
    @PrecioSinImpuesto DECIMAL(10,2),
    @Stock INT,
    @ID_Categoria INT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar usuario ejecutor no NULL
        IF @ID_UsuarioEjecutor IS NULL
            RAISERROR('Debe ingresar un ID de usuario ejecutor válido.', 16, 1);

        -- Validar parámetros obligatorios NO NULL / NO VACÍOS
        IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
            RAISERROR('El nombre del producto no puede estar vacío.', 16, 1);

        IF @Descripcion IS NULL OR LTRIM(RTRIM(@Descripcion)) = ''
            RAISERROR('La descripción del producto no puede estar vacía.', 16, 1);

        IF @PrecioUnitario IS NULL
            RAISERROR('El precio unitario no puede ser NULL.', 16, 1);

        IF @PrecioUnitario < 1 OR @PrecioUnitario > 99999999.99
            RAISERROR('El precio unitario está fuera del rango permitido (1 a 99.999.999,99).', 16, 1);

        IF @PrecioSinImpuesto IS NULL
            RAISERROR('El precio sin impuesto no puede ser NULL.', 16, 1);

        IF @PrecioSinImpuesto < 1 OR @PrecioSinImpuesto > 99999999.99
            RAISERROR('El precio sin impuesto está fuera del rango permitido (1 a 99.999.999,99).', 16, 1);

        IF @PrecioSinImpuesto > @PrecioUnitario
            RAISERROR('El precio sin impuesto no puede ser mayor que el precio unitario.', 16, 1);

        IF @Stock IS NULL
            RAISERROR('El stock no puede ser NULL.', 16, 1);

        IF @Stock <= 0
            RAISERROR('El stock debe ser mayor que cero.', 16, 1);

        IF @ID_Categoria IS NULL
            RAISERROR('La categoría no puede ser NULL.', 16, 1);

        -- Validar usuario ejecutor existe y está activo
        IF NOT EXISTS (
            SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);

        -- Validar permisos para agregar productos (ID_SubMenu = 4)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 4
              AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permiso para agregar productos.', 16, 1);

        -- Validar que la categoría exista
        IF NOT EXISTS (SELECT 1 FROM Categorias WHERE ID_Categoria = @ID_Categoria)
            RAISERROR('La categoría no existe.', 16, 1);

        BEGIN TRANSACTION;

        -- Inserción (el trigger TR_ValidarProductoUnico valida unicidad y otras validaciones)
        INSERT INTO Productos (Nombre, Descripcion, PrecioUnitario, PrecioSinImpuesto, Stock, ID_Categoria)
        VALUES (@Nombre, @Descripcion, @PrecioUnitario, @PrecioSinImpuesto, @Stock, @ID_Categoria);

        COMMIT TRANSACTION;
        PRINT 'Producto agregado correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/*  Ejemplo de ejecución
EXEC AgregarProducto
    @ID_UsuarioEjecutor = 1,
    @Nombre = 'Nuevo Procesador T900',
    @Descripcion = 'Procesador avanzado con 16 núcleos y alto rendimiento.',
    @PrecioUnitario = 450.00,
    @PrecioSinImpuesto = 380.00,
    @Stock = 22,
    @ID_Categoria = 1;
*/



/*-----------------------------------Listar Productos------------------------------------------------------*/

CREATE OR ALTER PROCEDURE ListarProductos
    (@ID_UsuarioEjecutor INT)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar que el parámetro usuario ejecutor no sea NULL
        IF @ID_UsuarioEjecutor IS NULL
            RAISERROR('El ID del usuario ejecutor no puede ser NULL.', 16, 1);

        -- Validar que el usuario exista y esté activo
        IF NOT EXISTS (
            SELECT 1 FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor
              AND Estado = 1
        )
            RAISERROR('El usuario no existe o no está activo.', 16, 1);

        -- Validar que el usuario tenga permiso para listar productos (ID_SubMenu = 5)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 5
              AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permiso para listar productos.', 16, 1);

        -- Listar todos los productos con estado como texto
        SELECT
            p.ID_Producto,
            p.Nombre,
            p.Descripcion,
            p.PrecioUnitario,
            p.PrecioSinImpuesto,
            p.Stock,
            p.ID_Categoria,
            c.Nombre AS Categoria,
            CASE
                WHEN p.Estado = 1 THEN 'Activo'
                ELSE 'Inactivo'
            END AS Estado
        FROM Productos p
        JOIN Categorias c ON c.ID_Categoria = p.ID_Categoria
        ORDER BY p.ID_Producto;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


--  EXEC ListarProductos @ID_UsuarioEjecutor = 1;



/*--------------------------------------Listar Productos por ID Categoria----------------------------------------------*/

CREATE OR ALTER PROCEDURE ListarProductosPorCategoria(
    @ID_UsuarioEjecutor INT,
    @ID_Categoria INT)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @ID_UsuarioEjecutor IS NULL OR @ID_Categoria IS NULL
            RAISERROR('Los parámetros ID_UsuarioEjecutor e ID_Categoria son obligatorios.', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1)
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);

        -- Permiso para listar por categoría (ID_SubMenu = 6)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 6
              AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permiso para listar productos por categoría.', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM Categorias WHERE ID_Categoria = @ID_Categoria)
            RAISERROR('La categoría no existe.', 16, 1);

        SELECT
            p.ID_Producto,
            p.Nombre,
            p.Descripcion,
            p.PrecioUnitario,
            p.PrecioSinImpuesto,
            p.Stock,
            c.Nombre AS Categoria,
            CASE
                WHEN p.Estado = 1 THEN 'Activo'
                ELSE 'Inactivo'
            END AS Estado
        FROM Productos p
        JOIN Categorias c ON p.ID_Categoria = c.ID_Categoria
        WHERE p.ID_Categoria = @ID_Categoria
        ORDER BY p.Nombre;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


--  EXEC ListarProductosPorCategoria @ID_UsuarioEjecutor = 1, @ID_Categoria = 2;



/*--------------------------------Eliminar Productos-------------------------------------------*/

-- Trigger para evitar dar de baja un producto que ya está dado de baja.
-- Solo actúa cuando se modifica la columna Estado (así no bloquea cambios de
-- precio o stock, ni la actualización de stock que hace trg_ActualizarStock).
CREATE OR ALTER TRIGGER TR_ValidarBajaProducto
ON Productos
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(Estado) AND EXISTS (
        SELECT 1
        FROM inserted i
        JOIN deleted d ON i.ID_Producto = d.ID_Producto
        WHERE d.Estado = 0 AND i.Estado = 0
    )
    BEGIN
        RAISERROR('El producto ya está dado de baja.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- Procedimiento para baja lógica
CREATE OR ALTER PROCEDURE BajaLogicaProducto
   ( @ID_UsuarioEjecutor INT,
     @ID_Producto INT)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @ID_UsuarioEjecutor IS NULL OR @ID_Producto IS NULL
            RAISERROR('Los parámetros ID_UsuarioEjecutor e ID_Producto son obligatorios.', 16, 1);

        IF NOT EXISTS (
            SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);

        -- Permiso para eliminar productos (ID_SubMenu = 10)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 10
              AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permiso para dar de baja productos.', 16, 1);

        IF NOT EXISTS (
            SELECT 1 FROM Productos WHERE ID_Producto = @ID_Producto AND Estado = 1
        )
            RAISERROR('El producto no existe o ya está dado de baja.', 16, 1);

        BEGIN TRANSACTION;

        UPDATE Productos
        SET Estado = 0
        WHERE ID_Producto = @ID_Producto;

        COMMIT TRANSACTION;
        PRINT 'Producto dado de baja correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


--  EXEC BajaLogicaProducto @ID_UsuarioEjecutor = 1, @ID_Producto = 4;



/*--------------------------------Modificar precio--------------------------------------------------------*/

CREATE OR ALTER PROCEDURE ModificarPrecioProducto(
    @ID_UsuarioEjecutor INT,
    @ID_Producto INT,
    @NuevoPrecioUnitario DECIMAL(10,2),
    @NuevoPrecioSinImpuesto DECIMAL(10,2))
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @ID_UsuarioEjecutor IS NULL OR @ID_Producto IS NULL
            RAISERROR('Los parámetros ID_UsuarioEjecutor e ID_Producto son obligatorios.', 16, 1);

        -- Validar que el usuario exista y esté activo
        IF NOT EXISTS (
            SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);

        -- Validar que el usuario tenga permiso para modificar precios (ID_SubMenu = 7)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor AND p.ID_SubMenu = 7 AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permiso para modificar precios.', 16, 1);

        -- Validar que el producto exista y esté activo
        IF NOT EXISTS (
            SELECT 1 FROM Productos WHERE ID_Producto = @ID_Producto AND Estado = 1
        )
            RAISERROR('El producto no existe o no está activo.', 16, 1);

        -- Validar precios nuevos (rango permitido por DECIMAL(10,2))
        IF @NuevoPrecioUnitario IS NULL OR @NuevoPrecioUnitario < 1 OR @NuevoPrecioUnitario > 99999999.99
           OR @NuevoPrecioSinImpuesto IS NULL OR @NuevoPrecioSinImpuesto < 1 OR @NuevoPrecioSinImpuesto > 99999999.99
            RAISERROR('Los precios deben estar entre 1 y 99.999.999,99.', 16, 1);

        -- Validar que PrecioSinImpuesto no sea mayor que PrecioUnitario
        IF @NuevoPrecioSinImpuesto > @NuevoPrecioUnitario
            RAISERROR('El precio sin impuesto no puede ser mayor que el precio unitario.', 16, 1);

        BEGIN TRANSACTION;

        -- Actualizar precios
        UPDATE Productos
        SET PrecioUnitario = @NuevoPrecioUnitario,
            PrecioSinImpuesto = @NuevoPrecioSinImpuesto
        WHERE ID_Producto = @ID_Producto;

        COMMIT TRANSACTION;
        PRINT 'Precio modificado correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/*  Ejemplo de ejecución
EXEC ModificarPrecioProducto
    @ID_UsuarioEjecutor = 1,
    @ID_Producto = 4,
    @NuevoPrecioUnitario = 1500.00,
    @NuevoPrecioSinImpuesto = 1200.00;
*/



/*----------------------------------------Actualizar stock----------------------------------------------------*/

CREATE OR ALTER PROCEDURE ActualizarStockProducto(
    @ID_UsuarioEjecutor INT,
    @ID_Producto INT,
    @NuevoStock INT)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @ID_UsuarioEjecutor IS NULL OR @ID_Producto IS NULL
            RAISERROR('Los parámetros ID_UsuarioEjecutor e ID_Producto son obligatorios.', 16, 1);

        -- Validar que el usuario exista y esté activo
        IF NOT EXISTS (
            SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);

        -- Validar que el usuario tenga permiso para modificar stock (SubMenu 8)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor AND p.ID_SubMenu = 8 AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permiso para actualizar stock.', 16, 1);

        -- Validar que el producto exista y esté activo
        IF NOT EXISTS (
            SELECT 1 FROM Productos WHERE ID_Producto = @ID_Producto AND Estado = 1
        )
            RAISERROR('El producto no existe o no está activo.', 16, 1);

        -- Validar nuevo stock (debe ser mayor o igual a cero)
        IF @NuevoStock IS NULL OR @NuevoStock < 0
            RAISERROR('El stock debe ser un número mayor o igual a cero.', 16, 1);

        -- Validar que el stock no sea demasiado alto
        IF @NuevoStock > 1000000
            RAISERROR('El stock es demasiado alto (máximo 1.000.000).', 16, 1);

        BEGIN TRANSACTION;

        -- Actualizar el stock
        UPDATE Productos
        SET Stock = @NuevoStock
        WHERE ID_Producto = @ID_Producto;

        COMMIT TRANSACTION;
        PRINT 'Stock actualizado correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/*  Ejemplo de ejecución
EXEC ActualizarStockProducto
    @ID_UsuarioEjecutor = 1,
    @ID_Producto = 2,
    @NuevoStock = 10;
*/



/*---------------------------------------------Agregar categoria-----------------------------------------*/

CREATE OR ALTER PROCEDURE AgregarCategoria(
    @ID_UsuarioEjecutor INT,
    @NombreCategoria NVARCHAR(50))
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar que el parámetro usuario ejecutor no sea NULL
        IF @ID_UsuarioEjecutor IS NULL
            RAISERROR('El ID del usuario ejecutor no puede ser NULL.', 16, 1);

        -- Validar que el parámetro nombre de categoría no sea NULL ni vacío
        IF @NombreCategoria IS NULL OR LTRIM(RTRIM(@NombreCategoria)) = ''
            RAISERROR('El nombre de la categoría no puede ser NULL ni estar vacío.', 16, 1);

        -- Validar usuario ejecutor existe y está activo
        IF NOT EXISTS (
            SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);

        -- Validar permiso del usuario (SubMenu 9 es para categorías)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 9
              AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permiso para agregar categorías.', 16, 1);

        -- Validar que no exista ya la categoría con ese nombre
        -- (la intercalación CI_AI ya ignora mayúsculas/minúsculas y acentos)
        IF EXISTS (
            SELECT 1 FROM Categorias WHERE LTRIM(RTRIM(Nombre)) = LTRIM(RTRIM(@NombreCategoria))
        )
            RAISERROR('La categoría ya existe.', 16, 1);

        BEGIN TRANSACTION;

        -- Insertar la nueva categoría
        INSERT INTO Categorias (Nombre)
        VALUES (LTRIM(RTRIM(@NombreCategoria)));

        COMMIT TRANSACTION;

        -- Mensaje de éxito
        PRINT 'Categoría agregada correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


--  EXEC AgregarCategoria @ID_UsuarioEjecutor = 3, @NombreCategoria = 'Electrónica';



/*---------------------------------Restablecer producto---------------------------------------------------------------*/

CREATE OR ALTER PROCEDURE RestablecerProducto(
   @ID_UsuarioEjecutor INT,
   @ID_Producto INT)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar que los parámetros no sean NULL
        IF @ID_UsuarioEjecutor IS NULL OR @ID_Producto IS NULL
            RAISERROR('Los parámetros ID_UsuarioEjecutor e ID_Producto son obligatorios.', 16, 1);

        -- Validar que el usuario ejecutor exista y esté activo
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor
              AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);

        -- Validar que el usuario ejecutor tenga permiso para restablecer productos (ID_SubMenu = 11)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 11
              AND p.Estado = 1
        )
            RAISERROR('El usuario ejecutor no tiene permiso para restablecer productos.', 16, 1);

        -- Validar que el producto exista y esté inactivo
        IF NOT EXISTS (
            SELECT 1
            FROM Productos
            WHERE ID_Producto = @ID_Producto AND Estado = 0
        )
            RAISERROR('El producto no existe o ya está activo.', 16, 1);

        BEGIN TRANSACTION;

        -- Restablecer producto (poner Estado en 1)
        UPDATE Productos
        SET Estado = 1
        WHERE ID_Producto = @ID_Producto;

        COMMIT TRANSACTION;
        PRINT 'Producto restablecido correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/*  Ejemplo de ejecución
EXEC RestablecerProducto
    @ID_UsuarioEjecutor = 1,
    @ID_Producto = 4;
*/
