USE DBProyectoGestionComercial;
GO

/*  NOTA: dentro de un bloque BEGIN TRY, un RAISERROR de severidad 16 salta
    directamente al BEGIN CATCH, que relanza el error con THROW.
    Los informes solo leen datos, por eso no abren transacción.  */


/*--------------------------Recaudacion Anual por Empleados------------------------------*/

CREATE OR ALTER PROCEDURE RecaudacionEmpleados
    (@ID_UsuarioEjecutor INT)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar que el usuario ejecutor no sea NULL ni menor o igual a cero
        IF @ID_UsuarioEjecutor IS NULL OR @ID_UsuarioEjecutor <= 0
            RAISERROR('El ID del usuario ejecutor no puede ser NULL ni menor o igual a cero.', 16, 1);

        -- Verificar si el usuario ejecutor existe y está activo
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o está inactivo.', 16, 1);

        -- Validar que tenga permiso para ver la recaudación por empleado (ID_SubMenu = 28)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 28
              AND p.Estado = 1
        )
            RAISERROR('Permiso denegado: no puede acceder a la recaudación por empleado.', 16, 1);

        -- Recaudación anual por usuario vendedor (admins o empleados activos).
        -- Se suma el detalle (Cantidad * Precio_Unitario) y no V.Importe_Total,
        -- porque al unir con Detalle_Venta el importe de la venta se repetiría
        -- una vez por cada línea de detalle.
        SELECT
            U.ID_Usuario,
            U.Nombre_Usuario + ' ' + U.Apellido_Usuario AS Nombre_Usuario,
            TU.Nombre_TipoUsuario AS Tipo_Usuario,
            YEAR(V.FechaDeVenta) AS Año,
            COUNT(DISTINCT V.ID_Venta) AS Cantidad_Ventas,
            SUM(DV.Cantidad) AS Total_Productos_Vendidos,
            SUM(DV.Cantidad * DV.Precio_Unitario) AS Total_Recaudado
        FROM Usuario U
        INNER JOIN Tipo_de_Usuario TU ON U.ID_TipoUsuario = TU.ID_TipoUsuario
        INNER JOIN Ventas V ON V.ID_Usuario = U.ID_Usuario
        INNER JOIN Detalle_Venta DV ON DV.ID_Venta = V.ID_Venta
        WHERE U.Estado = 1
          AND U.ID_TipoUsuario IN (1, 2)
        GROUP BY U.ID_Usuario, U.Nombre_Usuario, U.Apellido_Usuario, TU.Nombre_TipoUsuario, YEAR(V.FechaDeVenta)
        ORDER BY Año, Total_Recaudado DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


--  EXEC RecaudacionEmpleados @ID_UsuarioEjecutor = 1;



/*--------------------------Recaudacion anual por cliente----------------------------*/

CREATE OR ALTER PROCEDURE recaudacionDeClientes
   ( @ID_UsuarioEjecutor INT)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar que el parámetro no sea NULL ni menor o igual a cero
        IF @ID_UsuarioEjecutor IS NULL OR @ID_UsuarioEjecutor <= 0
            RAISERROR('El ID del usuario ejecutor no puede ser NULL ni menor o igual a cero.', 16, 1);

        -- Verificar si el usuario existe y está activo
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);

        -- Validar permiso sobre "Recaudación por Cliente" (ID_SubMenu = 27)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 27
              AND p.Estado = 1
        )
            RAISERROR('No tiene permisos para ver la recaudación por cliente.', 16, 1);

        -- Mostrar la recaudación por cliente y año
        SELECT
            u.ID_Usuario AS ID_Cliente,
            u.Nombre_Usuario + ' ' + u.Apellido_Usuario AS Nombre_Cliente,
            tu.Nombre_TipoUsuario AS Tipo_Usuario,
            YEAR(v.FechaDeVenta) AS Año,
            COUNT(DISTINCT v.ID_Venta) AS Cantidad_Compras,
            SUM(dv.Cantidad) AS Total_Productos_Comprados,
            SUM(dv.Cantidad * dv.Precio_Unitario) AS Total_Recaudado
        FROM Ventas v
        INNER JOIN Usuario u ON v.ID_Cliente = u.ID_Usuario
        INNER JOIN Tipo_de_Usuario tu ON u.ID_TipoUsuario = tu.ID_TipoUsuario
        INNER JOIN Detalle_Venta dv ON v.ID_Venta = dv.ID_Venta
        WHERE u.ID_TipoUsuario = 3
        GROUP BY
            u.ID_Usuario, u.Nombre_Usuario, u.Apellido_Usuario, tu.Nombre_TipoUsuario, YEAR(v.FechaDeVenta)
        ORDER BY
            Año, Total_Recaudado DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


--  EXEC recaudacionDeClientes @ID_UsuarioEjecutor = 1;



/*---------------------------Recaudacion Anual---------------------------------*/

CREATE OR ALTER PROCEDURE Mostrar_Recaudacion_Anual
    @ID_Usuario INT,
    @Año INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar que el ID_Usuario no sea NULL ni menor o igual a cero
        IF @ID_Usuario IS NULL OR @ID_Usuario <= 0
            RAISERROR('El ID del usuario ejecutor no puede ser NULL ni menor o igual a cero.', 16, 1);

        -- Validar el año
        IF @Año IS NULL OR @Año < 1900 OR @Año > 9999
            RAISERROR('Debe ingresar un año válido.', 16, 1);

        -- Validar que el usuario exista y esté activo
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_Usuario AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o está inactivo.', 16, 1);

        -- Validar permiso (ID_SubMenu = 26)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_Usuario
              AND p.ID_SubMenu = 26
              AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permisos para ver la recaudación anual.', 16, 1);

        -- Mostrar recaudación por mes para el año especificado
        -- (nombres de mes fijos en español, sin depender del idioma del servidor)
        SELECT
            m.Mes,
            m.NumeroMes,
            COUNT(v.ID_Venta) AS Cantidad_Ventas,
            ISNULL(SUM(v.Importe_Total), 0) AS Total_Mensual
        FROM (
            VALUES (1,'Enero'),(2,'Febrero'),(3,'Marzo'),(4,'Abril'),(5,'Mayo'),(6,'Junio'),
                   (7,'Julio'),(8,'Agosto'),(9,'Septiembre'),(10,'Octubre'),(11,'Noviembre'),(12,'Diciembre')
        ) AS m(NumeroMes, Mes)
        LEFT JOIN Ventas v
            ON MONTH(v.FechaDeVenta) = m.NumeroMes
           AND YEAR(v.FechaDeVenta) = @Año
        GROUP BY m.NumeroMes, m.Mes
        ORDER BY m.NumeroMes;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


--  EXEC Mostrar_Recaudacion_Anual @ID_Usuario = 1, @Año = 2025;



/*---------------------------------------Producto mas vendido-----------------------------------------------------------*/

CREATE OR ALTER PROCEDURE ProductoMasVendido
    @ID_UsuarioEjecutor INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar que el ID del usuario no sea NULL ni menor o igual a cero
        IF @ID_UsuarioEjecutor IS NULL OR @ID_UsuarioEjecutor <= 0
            RAISERROR('El ID del usuario ejecutor no puede ser NULL ni menor o igual a cero.', 16, 1);

        -- Validar que el usuario existe y está activo
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);

        -- Validar permiso sobre el SubMenú "Producto mas Vendido" (ID_SubMenu = 29)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 29
              AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permiso para ver el producto más vendido.', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM Detalle_Venta WHERE ID_Producto IS NOT NULL)
            RAISERROR('Todavía no hay ventas registradas.', 16, 1);

        -- Obtener el producto más vendido (WITH TIES muestra empates)
        SELECT TOP 1 WITH TIES
            p.ID_Producto,
            p.Nombre AS Producto,
            SUM(dv.Cantidad) AS Total_Unidades_Vendidas,
            COUNT(DISTINCT dv.ID_Venta) AS Veces_Vendido,
            SUM(dv.Cantidad * dv.Precio_Unitario) AS Total_Recaudado
        FROM Detalle_Venta dv
        INNER JOIN Productos p ON dv.ID_Producto = p.ID_Producto
        GROUP BY p.ID_Producto, p.Nombre
        ORDER BY SUM(dv.Cantidad) DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


--  EXEC ProductoMasVendido @ID_UsuarioEjecutor = 1;
