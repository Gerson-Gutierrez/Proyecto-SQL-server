USE DBProyectoGestionComercial;
GO

/*  NOTA: dentro de un bloque BEGIN TRY, un RAISERROR de severidad 16 salta
    directamente al BEGIN CATCH, que deshace la transacción y relanza el error.  */


/*--------------------------------Trigger: validar cliente---------------------------------------------------------*/

-- Se aplica a los clientes (ID_TipoUsuario = 3) al insertarlos o modificarlos.
-- Los administradores/empleados se validan con trg_ValidarUsuarioUnico (EMPLEADOS.sql).
CREATE OR ALTER TRIGGER trg_ValidarClienteUnico
ON Usuario
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar campos obligatorios
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE ID_TipoUsuario = 3
          AND (   LTRIM(RTRIM(ISNULL(Nombre_Usuario, ''))) = ''
               OR LTRIM(RTRIM(ISNULL(Apellido_Usuario, ''))) = ''
               OR LTRIM(RTRIM(ISNULL(DNI_Usuario, ''))) = ''
               OR LTRIM(RTRIM(ISNULL(Email, ''))) = ''
               OR LTRIM(RTRIM(ISNULL(Telefono, ''))) = '')
    )
    BEGIN
        RAISERROR('No se permiten campos obligatorios vacíos o nulos (Nombre, Apellido, DNI, Email o Teléfono).', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Validar duplicados en DNI, Email o Teléfono contra cualquier otro usuario
    IF EXISTS (
        SELECT 1
        FROM Usuario u
        JOIN inserted i ON
            (u.DNI_Usuario = i.DNI_Usuario
             OR u.Email = i.Email
             OR u.Telefono = i.Telefono)
        WHERE u.ID_Usuario <> i.ID_Usuario
          AND i.ID_TipoUsuario = 3
    )
    BEGIN
        RAISERROR('Ya existe un usuario con el mismo DNI, Email o Teléfono.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO



/*--------------------------------Agregar Cliente---------------------------------------------------------*/

CREATE OR ALTER PROCEDURE AgregarCliente (
    @ID_UsuarioEjecutor INT,
    @Nombre NVARCHAR(50),
    @Apellido NVARCHAR(50),
    @DNI NVARCHAR(20),
    @Email NVARCHAR(100),
    @Contrasena NVARCHAR(50),
    @Telefono NVARCHAR(20)
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @ID_UsuarioEjecutor IS NULL
            RAISERROR('Debe ingresar un ID de usuario ejecutor válido.', 16, 1);

        -- Validar existencia y estado del ejecutor
        IF NOT EXISTS (
            SELECT 1 FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);

        -- Validar permiso (ID_SubMenu = 20)
        IF NOT EXISTS (
            SELECT 1 FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 20 AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permiso para agregar clientes.', 16, 1);

        -- Validar campos nulos o vacíos
        IF LTRIM(RTRIM(ISNULL(@Nombre, ''))) = ''
            OR LTRIM(RTRIM(ISNULL(@Apellido, ''))) = ''
            OR LTRIM(RTRIM(ISNULL(@DNI, ''))) = ''
            OR LTRIM(RTRIM(ISNULL(@Email, ''))) = ''
            OR LTRIM(RTRIM(ISNULL(@Contrasena, ''))) = ''
            OR LTRIM(RTRIM(ISNULL(@Telefono, ''))) = ''
            RAISERROR('Ningún campo puede estar vacío.', 16, 1);

        -- Validar formatos
        IF LEN(@DNI) NOT BETWEEN 7 AND 10 OR @DNI LIKE '%[^0-9]%'
            RAISERROR('El DNI debe tener entre 7 y 10 dígitos numéricos.', 16, 1);

        IF @Email NOT LIKE '%_@_%._%'
            RAISERROR('El email no tiene un formato válido.', 16, 1);

        -- Validar duplicados
        IF EXISTS (
            SELECT 1 FROM Usuario
            WHERE DNI_Usuario = @DNI OR Email = @Email OR Telefono = @Telefono
        )
            RAISERROR('Ya existe un usuario con el mismo DNI, Email o Teléfono.', 16, 1);

        BEGIN TRANSACTION;

        -- Insertar cliente (TipoUsuario = 3)
        INSERT INTO Usuario (
            ID_TipoUsuario, Nombre_Usuario, Apellido_Usuario,
            DNI_Usuario, Email, Contraseña, Telefono, Fecha_Ingreso, Estado
        )
        VALUES (
            3, LTRIM(RTRIM(@Nombre)), LTRIM(RTRIM(@Apellido)), LTRIM(RTRIM(@DNI)),
            LTRIM(RTRIM(@Email)), @Contrasena, LTRIM(RTRIM(@Telefono)), GETDATE(), 1
        );

        COMMIT TRANSACTION;
        PRINT 'Cliente agregado correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/*  Ejemplo de ejecución
EXEC AgregarCliente
    @ID_UsuarioEjecutor = 1,
    @Nombre = 'Julian',
    @Apellido = 'Alvarez',
    @DNI = '38345678',
    @Email = 'julian.alvarez@email.com',
    @Contrasena = '129945',
    @Telefono = '1123459000';
*/




/*--------------------------------Listar Cliente---------------------------------------------------------*/

CREATE OR ALTER PROCEDURE ListarClientes (
    @ID_UsuarioEjecutor INT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @ID_UsuarioEjecutor IS NULL
            RAISERROR('Debe ingresar un ID de usuario ejecutor válido.', 16, 1);

        -- Validar que el usuario ejecutor exista y esté activo
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);

        -- Validar permiso para listar clientes (ID_SubMenu = 21)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 21
              AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permiso para listar clientes.', 16, 1);

        -- Listar los clientes
        SELECT
            ID_Usuario,
            Nombre_Usuario,
            Apellido_Usuario,
            DNI_Usuario,
            Email,
            Telefono,
            Fecha_Ingreso,
            Fecha_Salida,
            CASE
                WHEN Estado = 1 THEN 'Activo'
                ELSE 'Inactivo'
            END AS Estado_Descripcion
        FROM Usuario
        WHERE ID_TipoUsuario = 3
        ORDER BY Apellido_Usuario, Nombre_Usuario;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


--  EXEC ListarClientes @ID_UsuarioEjecutor = 3;



/*--------------------------------Buscar cliente por ID------------------------------------------------------------*/

CREATE OR ALTER PROCEDURE BuscarClientePorID(
    @ID_UsuarioEjecutor INT = NULL,
    @ID_ClienteBuscar INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar parámetros nulos
        IF @ID_UsuarioEjecutor IS NULL
            RAISERROR('Debe ingresar un ID de usuario ejecutor válido.', 16, 1);

        IF @ID_ClienteBuscar IS NULL
            RAISERROR('Debe ingresar un ID de cliente válido para buscar.', 16, 1);

        -- Validar existencia y estado del usuario ejecutor
        IF NOT EXISTS (
            SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);

        -- Validar permiso sobre el SubMenú (22 = Buscar Cliente por ID)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 22 AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permiso para buscar clientes por ID.', 16, 1);

        -- Validar que el ID buscado sea un cliente
        IF NOT EXISTS (
            SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_ClienteBuscar AND ID_TipoUsuario = 3
        )
            RAISERROR('El cliente buscado no existe o no es cliente.', 16, 1);

        -- Devolver datos del cliente
        SELECT
            ID_Usuario AS ID_Cliente,
            Nombre_Usuario,
            Apellido_Usuario,
            DNI_Usuario,
            Email,
            Telefono,
            Fecha_Ingreso,
            Fecha_Salida,
            CASE
                WHEN Estado = 1 THEN 'Activo'
                ELSE 'Inactivo'
            END AS Estado
        FROM Usuario
        WHERE ID_Usuario = @ID_ClienteBuscar;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


/*  Ejemplo de ejecución
EXEC BuscarClientePorID
    @ID_UsuarioEjecutor = 1,
    @ID_ClienteBuscar = 5;
*/




/*----------------------------ELIMINAR CLIENTES-----------------------------------------------------------------*/

CREATE OR ALTER PROCEDURE EliminarCliente
(
    @ID_UsuarioEjecutor INT,
    @ID_Cliente INT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @ID_UsuarioEjecutor IS NULL OR @ID_Cliente IS NULL
            RAISERROR('Los parámetros ID_UsuarioEjecutor e ID_Cliente son obligatorios.', 16, 1);

        -- Validar que el usuario ejecutor exista y esté activo
        IF NOT EXISTS (
            SELECT 1 FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);

        -- Validar que el usuario ejecutor tenga permiso para eliminar clientes (ID_SubMenu = 24)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 24
              AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permiso para eliminar clientes.', 16, 1);

        -- Validar que el cliente exista, sea tipo cliente y esté activo
        IF NOT EXISTS (
            SELECT 1 FROM Usuario
            WHERE ID_Usuario = @ID_Cliente
              AND ID_TipoUsuario = 3
              AND Estado = 1
        )
            RAISERROR('El cliente no existe, no es cliente o ya está inactivo.', 16, 1);

        BEGIN TRANSACTION;

        -- Baja lógica: actualizar estado y fecha de salida
        UPDATE Usuario
        SET Estado = 0,
            Fecha_Salida = GETDATE()
        WHERE ID_Usuario = @ID_Cliente;

        COMMIT TRANSACTION;
        PRINT 'Cliente dado de baja correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/*  Ejemplo de ejecución
EXEC EliminarCliente @ID_UsuarioEjecutor = 1, @ID_Cliente = 5;
SELECT * FROM VW_TodosLosUsuarios;
*/




/*---------------------------------Modificar Cliente----------------------------------------------*/

CREATE OR ALTER PROCEDURE ModificarCliente
(
    @ID_UsuarioEjecutor INT = NULL,
    @ID_Cliente INT = NULL,
    @Nombre NVARCHAR(50) = NULL,
    @Apellido NVARCHAR(50) = NULL,
    @DNI NVARCHAR(20) = NULL,
    @Email NVARCHAR(100) = NULL,
    @Contrasena NVARCHAR(50) = NULL,
    @Telefono NVARCHAR(20) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar parámetros obligatorios
        IF @ID_UsuarioEjecutor IS NULL
            RAISERROR('Debe ingresar un ID de usuario ejecutor válido.', 16, 1);

        IF @ID_Cliente IS NULL
            RAISERROR('Debe ingresar el ID del cliente a modificar.', 16, 1);

        -- Validar que al menos un campo para modificar no sea NULL
        IF @Nombre IS NULL AND @Apellido IS NULL AND @DNI IS NULL AND @Email IS NULL AND @Contrasena IS NULL AND @Telefono IS NULL
            RAISERROR('Debe especificar al menos un campo para modificar.', 16, 1);

        -- Validar que los campos enviados no estén vacíos
        IF (@Nombre IS NOT NULL AND LTRIM(RTRIM(@Nombre)) = '')
           OR (@Apellido IS NOT NULL AND LTRIM(RTRIM(@Apellido)) = '')
           OR (@DNI IS NOT NULL AND LTRIM(RTRIM(@DNI)) = '')
           OR (@Email IS NOT NULL AND LTRIM(RTRIM(@Email)) = '')
           OR (@Contrasena IS NOT NULL AND LTRIM(RTRIM(@Contrasena)) = '')
           OR (@Telefono IS NOT NULL AND LTRIM(RTRIM(@Telefono)) = '')
            RAISERROR('Los campos a modificar no pueden estar vacíos.', 16, 1);

        -- Validar formatos
        IF @DNI IS NOT NULL AND (LEN(@DNI) NOT BETWEEN 7 AND 10 OR @DNI LIKE '%[^0-9]%')
            RAISERROR('El DNI debe tener entre 7 y 10 dígitos numéricos.', 16, 1);

        IF @Email IS NOT NULL AND @Email NOT LIKE '%_@_%._%'
            RAISERROR('El email no tiene un formato válido.', 16, 1);

        -- Validar que el usuario ejecutor exista y esté activo
        IF NOT EXISTS (
            SELECT 1 FROM Usuario WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o está inactivo.', 16, 1);

        -- Validar permiso para modificar cliente (ID_SubMenu = 23)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 23
              AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permiso para modificar clientes.', 16, 1);

        -- Validar que el cliente exista y esté activo
        IF NOT EXISTS (
            SELECT 1 FROM Usuario
            WHERE ID_Usuario = @ID_Cliente
              AND ID_TipoUsuario = 3
              AND Estado = 1
        )
            RAISERROR('El cliente no existe o está dado de baja.', 16, 1);

        -- Validar que no haya duplicados si se modifican DNI, Email o Telefono
        IF EXISTS (
            SELECT 1 FROM Usuario
            WHERE ID_Usuario <> @ID_Cliente
              AND (
                   (@DNI IS NOT NULL AND DNI_Usuario = @DNI)
                OR (@Email IS NOT NULL AND Email = @Email)
                OR (@Telefono IS NOT NULL AND Telefono = @Telefono)
              )
        )
            RAISERROR('DNI, Email o Teléfono ya están registrados por otro usuario.', 16, 1);

        BEGIN TRANSACTION;

        -- Realizar la modificación (solo los campos enviados)
        UPDATE Usuario
        SET
            Nombre_Usuario   = COALESCE(LTRIM(RTRIM(@Nombre)), Nombre_Usuario),
            Apellido_Usuario = COALESCE(LTRIM(RTRIM(@Apellido)), Apellido_Usuario),
            DNI_Usuario      = COALESCE(LTRIM(RTRIM(@DNI)), DNI_Usuario),
            Email            = COALESCE(LTRIM(RTRIM(@Email)), Email),
            Contraseña       = COALESCE(@Contrasena, Contraseña),
            Telefono         = COALESCE(LTRIM(RTRIM(@Telefono)), Telefono)
        WHERE ID_Usuario = @ID_Cliente;

        COMMIT TRANSACTION;
        PRINT 'Cliente modificado correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/*  Ejemplo de ejecución
EXEC ModificarCliente
    @ID_UsuarioEjecutor = 1,
    @ID_Cliente = 5,
    @Nombre = 'NuevoNombre',
    @Telefono = '123456789';
*/



/*--------------------------------Restablecer Cliente-----------------------------------------------------------*/

CREATE OR ALTER PROCEDURE RestablecerCliente
(
    @ID_UsuarioEjecutor INT = NULL,
    @Email NVARCHAR(100) = NULL,
    @Contrasena NVARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar parámetros no nulos
        IF @ID_UsuarioEjecutor IS NULL
            RAISERROR('Debe ingresar un ID de usuario ejecutor válido.', 16, 1);

        IF @Email IS NULL OR LTRIM(RTRIM(@Email)) = ''
            RAISERROR('Debe ingresar un email válido.', 16, 1);

        IF @Contrasena IS NULL OR LTRIM(RTRIM(@Contrasena)) = ''
            RAISERROR('Debe ingresar una contraseña válida.', 16, 1);

        -- Validar permisos del usuario ejecutor (ID_SubMenu = 25)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND u.Estado = 1
              AND p.ID_SubMenu = 25
              AND p.Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe, está inactivo o no tiene permiso para restablecer clientes.', 16, 1);

        -- Buscar el cliente por email y contraseña
        DECLARE @ID_Cliente INT;
        SELECT @ID_Cliente = ID_Usuario
        FROM Usuario
        WHERE Email = @Email
          AND Contraseña = @Contrasena
          AND ID_TipoUsuario = 3;

        IF @ID_Cliente IS NULL
            RAISERROR('No se encontró un cliente con ese correo y contraseña.', 16, 1);

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_Cliente AND Estado = 0
        )
            RAISERROR('El cliente ya está activo. No es necesario restablecer.', 16, 1);

        BEGIN TRANSACTION;

        -- Restablecer cliente y limpiar fecha de salida
        UPDATE Usuario
        SET Estado = 1,
            Fecha_Salida = NULL
        WHERE ID_Usuario = @ID_Cliente;

        COMMIT TRANSACTION;
        PRINT 'Cliente restablecido correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


/*  Ejemplo de ejecución
EXEC RestablecerCliente
    @ID_UsuarioEjecutor = 1,
    @Email = 'juan.cliente@mail.com',
    @Contrasena = 'JuanCliente';
*/
