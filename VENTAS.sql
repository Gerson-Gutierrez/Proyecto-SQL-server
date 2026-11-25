USE DBProyectoGestionComercial;
GO

/*  NOTA: dentro de un bloque BEGIN TRY, un RAISERROR de severidad 16 salta
    directamente al BEGIN CATCH, que deshace la transacción y relanza el error.  */


/*-----------------------------------Trigger: descontar stock----------------------------*/

CREATE OR ALTER TRIGGER trg_ActualizarStock
ON Detalle_Venta
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Cantidades agrupadas por producto (por si un producto aparece en más de una línea)
    DECLARE @Movimientos TABLE (ID_Producto INT PRIMARY KEY, Cantidad INT);

    INSERT INTO @Movimientos (ID_Producto, Cantidad)
    SELECT ID_Producto, SUM(Cantidad)
    FROM inserted
    WHERE ID_Producto IS NOT NULL
    GROUP BY ID_Producto;

    -- Validar stock suficiente antes de descontar
    IF EXISTS (
        SELECT 1
        FROM Productos p
        JOIN @Movimientos m ON p.ID_Producto = m.ID_Producto
        WHERE p.Stock < m.Cantidad
    )
    BEGIN
        RAISERROR('Stock insuficiente para uno o más productos.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Descuenta el stock por cada producto insertado en Detalle_Venta
    UPDATE p
    SET p.Stock = p.Stock - m.Cantidad
    FROM Productos p
    JOIN @Movimientos m ON p.ID_Producto = m.ID_Producto;
END;
GO



/*-----------------------------------Tipo tabla para el detalle de la venta----------------------------*/

IF TYPE_ID('dbo.TVP_DetalleVenta') IS NULL
    CREATE TYPE dbo.TVP_DetalleVenta AS TABLE (
        ID_Producto INT,
        Cantidad INT
    );
GO



/*-----------------------------------Agregar Venta----------------------------*/

CREATE OR ALTER PROCEDURE AgregarVenta
(
    @ID_Usuario INT,
    @ID_Cliente INT,
    @ProductosVenta dbo.TVP_DetalleVenta READONLY
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validaciones parámetros obligatorios
        IF @ID_Usuario IS NULL
            RAISERROR('El parámetro ID_Usuario es obligatorio.', 16, 1);

        IF @ID_Cliente IS NULL
            RAISERROR('El parámetro ID_Cliente es obligatorio.', 16, 1);

        -- Validación: vendedor y cliente no pueden ser la misma persona
        IF @ID_Usuario = @ID_Cliente
            RAISERROR('El vendedor y el cliente no pueden ser la misma persona.', 16, 1);

        -- Validar permisos del usuario (vendedor) - ID_SubMenu = 1
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_Usuario
              AND u.Estado = 1
              AND p.ID_SubMenu = 1
              AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permisos para realizar una venta o no está activo.', 16, 1);

        -- Validar cliente activo y rol correcto (tipo usuario = 3)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_Cliente
              AND ID_TipoUsuario = 3
              AND Estado = 1
        )
            RAISERROR('El cliente no existe, no está activo o no tiene el rol correcto.', 16, 1);

        -- Validar que se ingresó al menos un producto para la venta
        IF NOT EXISTS (SELECT 1 FROM @ProductosVenta)
            RAISERROR('Debe ingresar al menos un producto para realizar la venta.', 16, 1);

        -- Validar que no haya productos NULL
        IF EXISTS (SELECT 1 FROM @ProductosVenta WHERE ID_Producto IS NULL)
            RAISERROR('Todos los productos deben tener un ID válido.', 16, 1);

        -- Validar que no haya productos repetidos
        IF EXISTS (
            SELECT ID_Producto
            FROM @ProductosVenta
            GROUP BY ID_Producto
            HAVING COUNT(*) > 1
        )
            RAISERROR('Un mismo producto no puede repetirse. Sume la cantidad en una sola línea.', 16, 1);

        -- Validar cantidades > 0
        IF EXISTS (SELECT 1 FROM @ProductosVenta WHERE Cantidad IS NULL OR Cantidad <= 0)
            RAISERROR('La cantidad de cada producto debe ser mayor que cero.', 16, 1);

        -- Validar existencia de productos
        IF EXISTS (
            SELECT 1
            FROM @ProductosVenta pv
            LEFT JOIN Productos pr ON pv.ID_Producto = pr.ID_Producto
            WHERE pr.ID_Producto IS NULL
        )
            RAISERROR('Uno o más productos ingresados no existen.', 16, 1);

        -- Validar estado de productos activos
        IF EXISTS (
            SELECT 1
            FROM @ProductosVenta pv
            JOIN Productos pr ON pv.ID_Producto = pr.ID_Producto
            WHERE pr.Estado = 0
        )
            RAISERROR('Uno o más productos están inactivos.', 16, 1);

        BEGIN TRANSACTION;

        -- Validar stock suficiente (UPDLOCK bloquea las filas hasta el COMMIT
        -- para que dos ventas simultáneas no vendan el mismo stock)
        IF EXISTS (
            SELECT 1
            FROM @ProductosVenta pv
            JOIN Productos pr WITH (UPDLOCK, HOLDLOCK) ON pv.ID_Producto = pr.ID_Producto
            WHERE pv.Cantidad > pr.Stock
        )
            RAISERROR('Uno o más productos no tienen stock suficiente.', 16, 1);

        -- Calcular total de la venta
        DECLARE @Total DECIMAL(12, 2);
        SELECT @Total = SUM(pv.Cantidad * pr.PrecioUnitario)
        FROM @ProductosVenta pv
        JOIN Productos pr ON pv.ID_Producto = pr.ID_Producto;

        -- Insertar venta
        DECLARE @ID_Venta INT;
        INSERT INTO Ventas (ID_Usuario, ID_Cliente, Importe_Total, FechaDeVenta)
        VALUES (@ID_Usuario, @ID_Cliente, @Total, GETDATE());

        SET @ID_Venta = SCOPE_IDENTITY();

        -- Insertar detalle de venta (el trigger trg_ActualizarStock descuenta el stock)
        INSERT INTO Detalle_Venta (ID_Venta, ID_Producto, Cantidad, Precio_Unitario)
        SELECT @ID_Venta, pv.ID_Producto, pv.Cantidad, pr.PrecioUnitario
        FROM @ProductosVenta pv
        JOIN Productos pr ON pv.ID_Producto = pr.ID_Producto;

        COMMIT TRANSACTION;

        SELECT @ID_Venta AS ID_Venta, @Total AS Importe_Total, 'Venta registrada correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO



/*  Ejemplo de ejecución (ejecutar todo el bloque junto)
DECLARE @DetalleVenta dbo.TVP_DetalleVenta;

INSERT INTO @DetalleVenta (ID_Producto, Cantidad)
VALUES (1, 5),
       (2, 5);

EXEC AgregarVenta
    @ID_Usuario = 3,
    @ID_Cliente = 6,
    @ProductosVenta = @DetalleVenta;

SELECT * FROM VW_ProductosStock;
*/



/*-----------------------------------LISTA DE VENTAS----------------------------*/

CREATE OR ALTER PROCEDURE SP_ListadoDeVentas(
    @ID_Usuario INT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar que se haya ingresado un ID de usuario válido
        IF @ID_Usuario IS NULL OR @ID_Usuario <= 0
            RAISERROR('Debe ingresar un ID de usuario válido.', 16, 1);

        -- Validar que el usuario exista y esté activo
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_Usuario
              AND Estado = 1
        )
            RAISERROR('El usuario no existe o está inactivo.', 16, 1);

        -- Validar permiso para acceder al listado de ventas (SubMenú ID = 2)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_Usuario
              AND p.ID_SubMenu = 2
              AND p.Estado = 1
        )
            RAISERROR('Permiso denegado. El usuario no tiene acceso al listado de ventas.', 16, 1);

        -- Listado de ventas. Se usan LEFT JOIN para no perder ventas históricas
        -- cuando un cliente/vendedor fue dado de baja o un producto fue eliminado.
        SELECT
            V.ID_Venta,
            V.FechaDeVenta,
            CONCAT(C.Nombre_Usuario, ' ', C.Apellido_Usuario) AS Nombre_Cliente,
            CONCAT(U.Nombre_Usuario, ' ', U.Apellido_Usuario) AS Nombre_Vendedor,
            STRING_AGG(CONCAT(ISNULL(P.Nombre, '(producto eliminado)'), ' (', DV.Cantidad, ')'), ', ') AS ProductosComprados,
            SUM(DV.Cantidad) AS CantidadTotalProductos,
            V.Importe_Total
        FROM Ventas V
        INNER JOIN Detalle_Venta DV ON V.ID_Venta = DV.ID_Venta
        LEFT JOIN Productos P ON DV.ID_Producto = P.ID_Producto
        LEFT JOIN Usuario C ON V.ID_Cliente = C.ID_Usuario
        LEFT JOIN Usuario U ON V.ID_Usuario = U.ID_Usuario
        GROUP BY
            V.ID_Venta,
            V.FechaDeVenta,
            C.Nombre_Usuario, C.Apellido_Usuario,
            U.Nombre_Usuario, U.Apellido_Usuario,
            V.Importe_Total
        ORDER BY V.ID_Venta;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO



--  EXEC SP_ListadoDeVentas @ID_Usuario = 1;



/*---------------------------------Listado de Ventas por id------------------------------------*/

CREATE OR ALTER PROCEDURE SP_ListadoDeVentasPorID (
    @ID_Usuario INT,
    @ID_Venta INT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validaciones de entrada
        IF @ID_Usuario IS NULL OR @ID_Usuario <= 0
            RAISERROR('Debe ingresar un ID de usuario válido.', 16, 1);

        IF @ID_Venta IS NULL OR @ID_Venta <= 0
            RAISERROR('Debe ingresar un ID de venta válido.', 16, 1);

        -- Verificar que el usuario esté activo
        IF NOT EXISTS (
            SELECT 1 FROM Usuario
            WHERE ID_Usuario = @ID_Usuario AND Estado = 1
        )
            RAISERROR('El usuario no existe o está inactivo.', 16, 1);

        -- Validar permiso para buscar venta (ID_SubMenu = 3)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_Usuario
              AND p.ID_SubMenu = 3
              AND p.Estado = 1
        )
            RAISERROR('Permiso denegado. El usuario no tiene acceso para buscar ventas.', 16, 1);

        -- Validar que la venta exista (antes de devolver un resultado vacío)
        IF NOT EXISTS (SELECT 1 FROM Ventas WHERE ID_Venta = @ID_Venta)
            RAISERROR('No se encontró la venta con el ID especificado.', 16, 1);

        -- Buscar venta específica
        SELECT
            V.ID_Venta,
            V.FechaDeVenta,
            CONCAT(C.Nombre_Usuario, ' ', C.Apellido_Usuario) AS Nombre_Cliente,
            CONCAT(U.Nombre_Usuario, ' ', U.Apellido_Usuario) AS Nombre_Vendedor,
            STRING_AGG(CONCAT(ISNULL(P.Nombre, '(producto eliminado)'), ' (', DV.Cantidad, ')'), ', ') AS ProductosComprados,
            SUM(DV.Cantidad) AS CantidadTotalProductos,
            V.Importe_Total
        FROM Ventas V
        INNER JOIN Detalle_Venta DV ON V.ID_Venta = DV.ID_Venta
        LEFT JOIN Productos P ON DV.ID_Producto = P.ID_Producto
        LEFT JOIN Usuario C ON V.ID_Cliente = C.ID_Usuario
        LEFT JOIN Usuario U ON V.ID_Usuario = U.ID_Usuario
        WHERE V.ID_Venta = @ID_Venta
        GROUP BY
            V.ID_Venta,
            V.FechaDeVenta,
            C.Nombre_Usuario, C.Apellido_Usuario,
            U.Nombre_Usuario, U.Apellido_Usuario,
            V.Importe_Total;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


/*  Ejemplo de ejecución
EXEC SP_ListadoDeVentasPorID
    @ID_Usuario = 1,
    @ID_Venta = 1;
*/
