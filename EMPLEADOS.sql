USE DBProyectoGestionComercial;
GO

/*  NOTA: dentro de un bloque BEGIN TRY, un RAISERROR de severidad 16 salta
    directamente al BEGIN CATCH, que deshace la transacción y relanza el error.  */


/*-----------------------------------------------Trigger: validar empleado/administrador---------------------------------*/

-- Se aplica a administradores y empleados (ID_TipoUsuario 1 y 2) al insertarlos o modificarlos.
-- Los clientes se validan con trg_ValidarClienteUnico (CLIENTES.sql).
CREATE OR ALTER TRIGGER trg_ValidarUsuarioUnico
ON Usuario
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar campos obligatorios
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE ID_TipoUsuario IN (1, 2)
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

    -- Validar duplicados: DNI, Email, Teléfono
    IF EXISTS (
        SELECT 1
        FROM Usuario u
        JOIN inserted i ON
            (u.DNI_Usuario = i.DNI_Usuario
             OR u.Email = i.Email
             OR u.Telefono = i.Telefono)
        WHERE u.ID_Usuario <> i.ID_Usuario
          AND i.ID_TipoUsuario IN (1, 2)
    )
    BEGIN
        RAISERROR('Ya existe un usuario con el mismo DNI, Email o Teléfono.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO



/*-----------------------------------------------Agregar Empleado / Administrador---------------------------------*/

CREATE OR ALTER PROCEDURE AgregarEmpleado_Administrador (
    @ID_UsuarioEjecutor INT,
    @ID_TipoUsuario INT,             -- Solo se permite 1 (Administrador) o 2 (Empleado)
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
        -----------------------------------------------
        -- Validar campos obligatorios
        -----------------------------------------------
        IF @ID_UsuarioEjecutor IS NULL
            RAISERROR('El ID del usuario ejecutor es obligatorio.', 16, 1);

        IF @ID_TipoUsuario IS NULL
            RAISERROR('El tipo de usuario es obligatorio.', 16, 1);

        IF @Nombre IS NULL OR LTRIM(RTRIM(@Nombre)) = ''
            RAISERROR('El nombre es obligatorio.', 16, 1);

        IF @Apellido IS NULL OR LTRIM(RTRIM(@Apellido)) = ''
            RAISERROR('El apellido es obligatorio.', 16, 1);

        IF @DNI IS NULL OR LTRIM(RTRIM(@DNI)) = ''
            RAISERROR('El DNI es obligatorio.', 16, 1);

        IF @Email IS NULL OR LTRIM(RTRIM(@Email)) = ''
            RAISERROR('El Email es obligatorio.', 16, 1);

        IF @Contrasena IS NULL OR LTRIM(RTRIM(@Contrasena)) = ''
            RAISERROR('La contraseña es obligatoria.', 16, 1);

        IF @Telefono IS NULL OR LTRIM(RTRIM(@Telefono)) = ''
            RAISERROR('El teléfono es obligatorio.', 16, 1);

        -----------------------------------------------
        -- Validar formatos
        -----------------------------------------------
        IF LEN(@DNI) NOT BETWEEN 7 AND 10 OR @DNI LIKE '%[^0-9]%'
            RAISERROR('El DNI debe tener entre 7 y 10 dígitos numéricos.', 16, 1);

        IF @Email NOT LIKE '%_@_%._%'
            RAISERROR('El email no tiene un formato válido.', 16, 1);

        -----------------------------------------------
        -- Validar existencia y estado del ejecutor
        -----------------------------------------------
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);

        -----------------------------------------------
        -- Validar tipo de usuario
        -----------------------------------------------
        IF @ID_TipoUsuario NOT IN (1, 2)
            RAISERROR('Solo se permite tipo de usuario Administrador (1) o Empleado (2).', 16, 1);

        -----------------------------------------------
        -- Validar permisos del ejecutor en el submenú
        -----------------------------------------------
        DECLARE @ID_SubMenu INT = CASE
                                      WHEN @ID_TipoUsuario = 1 THEN 12  -- Agregar Administrador
                                      WHEN @ID_TipoUsuario = 2 THEN 13  -- Agregar Empleado
                                  END;

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = @ID_SubMenu
              AND p.Estado = 1
        )
            RAISERROR('El usuario ejecutor no tiene permiso para realizar esta acción.', 16, 1);

        -----------------------------------------------
        -- Validar duplicados de DNI, Email o Teléfono
        -----------------------------------------------
        IF EXISTS (
            SELECT 1
            FROM Usuario
            WHERE DNI_Usuario = @DNI
               OR Email = @Email
               OR Telefono = @Telefono
        )
            RAISERROR('Ya existe un usuario con el mismo DNI, Email o Teléfono.', 16, 1);

        -----------------------------------------------
        -- Insertar nuevo usuario
        -----------------------------------------------
        BEGIN TRANSACTION;

        INSERT INTO Usuario (ID_TipoUsuario, Nombre_Usuario, Apellido_Usuario, DNI_Usuario, Email, Contraseña, Telefono, Fecha_Ingreso, Estado)
        VALUES (@ID_TipoUsuario, LTRIM(RTRIM(@Nombre)), LTRIM(RTRIM(@Apellido)), LTRIM(RTRIM(@DNI)),
                LTRIM(RTRIM(@Email)), @Contrasena, LTRIM(RTRIM(@Telefono)), GETDATE(), 1);

        COMMIT TRANSACTION;
        PRINT 'Usuario agregado correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO



/*  Ejemplo de ejecución
EXEC AgregarEmpleado_Administrador
    @ID_UsuarioEjecutor = 1,
    @ID_TipoUsuario = 2,
    @Nombre = 'Fernando',
    @Apellido = 'Gutierrez',
    @DNI = '44444050',
    @Email = 'ferv.gutierrez@empresa.com',
    @Contrasena = 'Callefalsa123',
    @Telefono = '000000845';
*/



/*-----------------------------------------------ListarEmpleados---------------------------------*/

CREATE OR ALTER PROCEDURE ListarEmpleados(
    @ID_UsuarioEjecutor INT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar que el ID del usuario ejecutor no sea NULL
        IF @ID_UsuarioEjecutor IS NULL
            RAISERROR('El ID del usuario ejecutor es obligatorio.', 16, 1);

        -- Validar que el usuario ejecutor exista y esté activo
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);

        -- Validar que el tipo de usuario del ejecutor sea Administrador o Empleado
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND ID_TipoUsuario IN (1, 2)
        )
            RAISERROR('Solo administradores o empleados pueden listar usuarios.', 16, 1);

        -- Validar que el usuario ejecutor tenga permiso para listar empleados (ID_SubMenu = 14)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 14
              AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permiso para listar empleados.', 16, 1);

        -- Listar empleados y administradores con información adicional
        SELECT
            u.ID_Usuario,
            u.Nombre_Usuario,
            u.Apellido_Usuario,
            u.DNI_Usuario,
            u.Email,
            u.Contraseña,  -- Incluido a pedido
            u.Telefono,
            u.Fecha_Ingreso,
            u.Fecha_Salida,
            tu.Nombre_TipoUsuario AS Tipo_Usuario,
            CASE
                WHEN u.Estado = 1 THEN 'Activo'
                ELSE 'Inactivo'
            END AS Estado
        FROM Usuario u
        JOIN Tipo_de_Usuario tu ON u.ID_TipoUsuario = tu.ID_TipoUsuario
        WHERE u.ID_TipoUsuario IN (1, 2)  -- Empleado o Administrador
        ORDER BY u.ID_TipoUsuario, u.Apellido_Usuario, u.Nombre_Usuario;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


--  EXEC ListarEmpleados @ID_UsuarioEjecutor = 1;


/*----------------------------------------------Buscar empleado-----------------------------------------*/

CREATE OR ALTER PROCEDURE BuscarEmpleadoPorID(
    @ID_UsuarioEjecutor INT,
    @ID_EmpleadoBuscar INT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar que el ID del usuario ejecutor no sea NULL y mayor que cero
        IF @ID_UsuarioEjecutor IS NULL OR @ID_UsuarioEjecutor <= 0
            RAISERROR('El ID del usuario ejecutor es obligatorio y debe ser mayor que cero.', 16, 1);

        -- Validar que el ID del empleado a buscar no sea NULL y mayor que cero
        IF @ID_EmpleadoBuscar IS NULL OR @ID_EmpleadoBuscar <= 0
            RAISERROR('El ID del empleado a buscar es obligatorio y debe ser mayor que cero.', 16, 1);

        -- Validar existencia y estado activo del usuario ejecutor
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);

        -- Validar permisos sobre el SubMenú "Buscar Empleado por ID" (ID_SubMenu = 15)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 15
              AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permiso para buscar empleados por ID.', 16, 1);

        -- Validar existencia del empleado buscado (solo Administrador o Empleado)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_EmpleadoBuscar
              AND ID_TipoUsuario IN (1, 2)
        )
            RAISERROR('El empleado buscado no existe o no es administrador/empleado.', 16, 1);

        -- Mostrar datos del empleado
        SELECT
            u.ID_Usuario AS ID_Empleado,
            u.Nombre_Usuario,
            u.Apellido_Usuario,
            u.DNI_Usuario,
            u.Email,
            u.Telefono,
            u.Fecha_Ingreso,
            u.Fecha_Salida,
            tu.Nombre_TipoUsuario AS Tipo_Usuario,
            CASE
                WHEN u.Estado = 1 THEN 'Activo'
                ELSE 'Inactivo'
            END AS Estado
        FROM Usuario u
        JOIN Tipo_de_Usuario tu ON u.ID_TipoUsuario = tu.ID_TipoUsuario
        WHERE u.ID_Usuario = @ID_EmpleadoBuscar;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

/*  Ejemplo de ejecución
EXEC BuscarEmpleadoPorID
    @ID_UsuarioEjecutor = 1,
    @ID_EmpleadoBuscar = 4;
*/



/*-------------------------------------------Eliminar Empleado---------------------------------------------------------*/

-- Trigger que registra la fecha de salida cuando un administrador/empleado
-- es dado de baja (Estado 1 -> 0) y la limpia cuando se lo restablece (0 -> 1).
CREATE OR ALTER TRIGGER trg_ActualizarEmpleadoInactivo
ON Usuario
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(Estado) RETURN;

    UPDATE u
    SET u.Fecha_Salida = CASE WHEN i.Estado = 0 THEN CAST(GETDATE() AS DATE) ELSE NULL END
    FROM Usuario u
    INNER JOIN inserted i ON u.ID_Usuario = i.ID_Usuario
    INNER JOIN deleted d ON d.ID_Usuario = i.ID_Usuario
    WHERE d.ID_TipoUsuario IN (1, 2)
      AND d.Estado <> i.Estado; -- Solo si realmente cambió el Estado
END;
GO


CREATE OR ALTER PROCEDURE EliminarEmpleado(
    @ID_UsuarioEjecutor INT,
    @ID_Empleado INT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @ID_UsuarioEjecutor IS NULL
            RAISERROR('El ID del usuario ejecutor es obligatorio.', 16, 1);

        IF @ID_Empleado IS NULL
            RAISERROR('El ID del empleado a eliminar es obligatorio.', 16, 1);

        IF @ID_UsuarioEjecutor = @ID_Empleado
            RAISERROR('No puede eliminarse a sí mismo.', 16, 1);

        IF NOT EXISTS (
            SELECT 1 FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o no está activo.', 16, 1);

        -- Permiso para eliminar empleados (ID_SubMenu = 17)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 17
              AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permiso para eliminar empleados.', 16, 1);

        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_Empleado
              AND ID_TipoUsuario IN (1, 2)
              AND Estado = 1
        )
            RAISERROR('El usuario no es un empleado/administrador válido o ya está inactivo.', 16, 1);

        BEGIN TRANSACTION;

        -- Baja lógica (el trigger trg_ActualizarEmpleadoInactivo registra la Fecha_Salida)
        UPDATE Usuario
        SET Estado = 0
        WHERE ID_Usuario = @ID_Empleado;

        COMMIT TRANSACTION;
        PRINT 'Usuario dado de baja correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/*  Ejemplo de ejecución
EXEC EliminarEmpleado
    @ID_UsuarioEjecutor = 1,
    @ID_Empleado = 4;
*/



/*-------------------------------------------Modificar Empleado---------------------------------------------------------*/

CREATE OR ALTER PROCEDURE ModificarEmpleado
(
    @ID_UsuarioEjecutor INT,
    @ID_Empleado INT,
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
        -- Validar que el usuario ejecutor no sea NULL
        IF @ID_UsuarioEjecutor IS NULL
            RAISERROR('El ID del usuario ejecutor no puede ser NULL.', 16, 1);

        -- Validar que el ID del empleado no sea NULL
        IF @ID_Empleado IS NULL
            RAISERROR('El ID del empleado a modificar no puede ser NULL.', 16, 1);

        -- Validar que el usuario ejecutor exista y esté activo
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o está inactivo.', 16, 1);

        -- Validar que tenga permiso para modificar empleados (ID_SubMenu = 16)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 16
              AND p.Estado = 1
        )
            RAISERROR('El usuario no tiene permiso para modificar empleados.', 16, 1);

        -- Validar que el empleado exista, sea tipo 1 o 2, y esté activo
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_Empleado
              AND ID_TipoUsuario IN (1, 2)
              AND Estado = 1
        )
            RAISERROR('El empleado no existe, no es válido o está dado de baja.', 16, 1);

        -- Validar que al menos un dato venga a modificar
        IF @Nombre IS NULL AND @Apellido IS NULL AND @DNI IS NULL AND
           @Email IS NULL AND @Contrasena IS NULL AND @Telefono IS NULL
            RAISERROR('Debe proporcionar al menos un dato para modificar.', 16, 1);

        -- Validar campos vacíos
        IF @Nombre IS NOT NULL AND LTRIM(RTRIM(@Nombre)) = ''
            RAISERROR('El nombre no puede estar vacío.', 16, 1);

        IF @Apellido IS NOT NULL AND LTRIM(RTRIM(@Apellido)) = ''
            RAISERROR('El apellido no puede estar vacío.', 16, 1);

        IF @DNI IS NOT NULL AND LTRIM(RTRIM(@DNI)) = ''
            RAISERROR('El DNI no puede estar vacío.', 16, 1);

        IF @Email IS NOT NULL AND LTRIM(RTRIM(@Email)) = ''
            RAISERROR('El email no puede estar vacío.', 16, 1);

        IF @Contrasena IS NOT NULL AND LTRIM(RTRIM(@Contrasena)) = ''
            RAISERROR('La contraseña no puede estar vacía.', 16, 1);

        IF @Telefono IS NOT NULL AND LTRIM(RTRIM(@Telefono)) = ''
            RAISERROR('El teléfono no puede estar vacío.', 16, 1);

        -- Validar formatos
        IF @DNI IS NOT NULL AND (LEN(@DNI) NOT BETWEEN 7 AND 10 OR @DNI LIKE '%[^0-9]%')
            RAISERROR('El DNI debe tener entre 7 y 10 dígitos numéricos.', 16, 1);

        IF @Email IS NOT NULL AND @Email NOT LIKE '%_@_%._%'
            RAISERROR('El email no tiene un formato válido.', 16, 1);

        -- Validar duplicados
        IF EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario <> @ID_Empleado
              AND (
                   (@DNI IS NOT NULL AND DNI_Usuario = @DNI)
                OR (@Email IS NOT NULL AND Email = @Email)
                OR (@Telefono IS NOT NULL AND Telefono = @Telefono)
              )
        )
            RAISERROR('DNI, Email o Teléfono ya están registrados por otro usuario.', 16, 1);

        BEGIN TRANSACTION;

        -- Realizar modificación (solo los campos enviados)
        UPDATE Usuario
        SET
            Nombre_Usuario   = COALESCE(LTRIM(RTRIM(@Nombre)), Nombre_Usuario),
            Apellido_Usuario = COALESCE(LTRIM(RTRIM(@Apellido)), Apellido_Usuario),
            DNI_Usuario      = COALESCE(LTRIM(RTRIM(@DNI)), DNI_Usuario),
            Email            = COALESCE(LTRIM(RTRIM(@Email)), Email),
            Contraseña       = COALESCE(@Contrasena, Contraseña),
            Telefono         = COALESCE(LTRIM(RTRIM(@Telefono)), Telefono)
        WHERE ID_Usuario = @ID_Empleado;

        COMMIT TRANSACTION;
        PRINT 'Usuario modificado correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/*  Ejemplo de ejecución
EXEC ModificarEmpleado
    @ID_UsuarioEjecutor = 1,
    @ID_Empleado = 4,
    @Nombre = 'Lucas',
    @Apellido = 'Fernandez',
    @Email = 'lucas.fernandez@email.com',
    @Telefono = '1122334455';
*/



/*-------------------------------------------Restablecer Empleado--------------------------------------------------------------------*/

CREATE OR ALTER PROCEDURE RestablecerEmpleado
(
    @ID_UsuarioEjecutor INT,
    @Email NVARCHAR(100),
    @NuevaContrasena NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validaciones básicas
        IF @ID_UsuarioEjecutor IS NULL
            RAISERROR('Debe ingresar un ID de usuario ejecutor.', 16, 1);

        IF @Email IS NULL OR LTRIM(RTRIM(@Email)) = ''
            RAISERROR('Debe ingresar un email válido.', 16, 1);

        IF @NuevaContrasena IS NULL OR LTRIM(RTRIM(@NuevaContrasena)) = ''
            RAISERROR('Debe ingresar una contraseña válida.', 16, 1);

        -- Validar existencia y estado activo del usuario ejecutor
        IF NOT EXISTS (
            SELECT 1 FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o está inactivo.', 16, 1);

        -- Validar permiso para restablecer empleados (ID_SubMenu = 19)
        IF NOT EXISTS (
            SELECT 1 FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 19
              AND p.Estado = 1
        )
            RAISERROR('El usuario ejecutor no tiene permiso para restablecer empleados.', 16, 1);

        -- Buscar empleado por email y tipo 2 (Empleado)
        DECLARE @ID_Empleado INT;
        SELECT @ID_Empleado = ID_Usuario
        FROM Usuario
        WHERE Email = @Email
          AND ID_TipoUsuario = 2;

        IF @ID_Empleado IS NULL
            RAISERROR('No se encontró un empleado con ese correo.', 16, 1);

        -- Validar que el empleado esté inactivo
        IF EXISTS (
            SELECT 1 FROM Usuario
            WHERE ID_Usuario = @ID_Empleado AND Estado = 1
        )
            RAISERROR('El empleado ya está activo. No es necesario restablecer.', 16, 1);

        BEGIN TRANSACTION;

        -- Actualizar contraseña y reactivar (el trigger limpia la Fecha_Salida)
        UPDATE Usuario
        SET Estado = 1,
            Contraseña = @NuevaContrasena
        WHERE ID_Usuario = @ID_Empleado;

        COMMIT TRANSACTION;
        PRINT 'Empleado restablecido correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/*  Ejemplo de ejecución
EXEC RestablecerEmpleado
    @ID_UsuarioEjecutor = 1,                   -- ID del usuario que ejecuta la acción (quien tiene permisos)
    @Email = 'sofia.emp@empresa.com',          -- Email del empleado que querés restablecer
    @NuevaContrasena = 'NuevaClaveSegura123';  -- Nueva contraseña para el empleado
*/



/*------------------------------------------Restablecer Administrador--------------------------------------------------------------*/

CREATE OR ALTER PROCEDURE RestablecerAdministrador
(
    @ID_UsuarioEjecutor INT,
    @Email NVARCHAR(100),
    @NuevaContrasena NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar que el ID del usuario ejecutor no sea NULL
        IF @ID_UsuarioEjecutor IS NULL
            RAISERROR('Debe ingresar un ID de usuario ejecutor válido.', 16, 1);

        -- Validar que el email y la nueva contraseña no estén vacíos o solo espacios
        IF @Email IS NULL OR LTRIM(RTRIM(@Email)) = ''
           OR @NuevaContrasena IS NULL OR LTRIM(RTRIM(@NuevaContrasena)) = ''
            RAISERROR('El email y la nueva contraseña no pueden estar vacíos.', 16, 1);

        -- Validar que el usuario ejecutor exista y esté activo
        IF NOT EXISTS (
            SELECT 1 FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioEjecutor AND Estado = 1
        )
            RAISERROR('El usuario ejecutor no existe o está inactivo.', 16, 1);

        -- Validar que el usuario ejecutor tenga permiso para restablecer administradores (ID_SubMenu = 18)
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario u
            JOIN Permiso p ON u.ID_TipoUsuario = p.ID_TipoUsuario
            WHERE u.ID_Usuario = @ID_UsuarioEjecutor
              AND p.ID_SubMenu = 18
              AND p.Estado = 1
        )
            RAISERROR('El usuario ejecutor no tiene permiso para restablecer administradores.', 16, 1);

        -- Buscar el administrador por correo
        DECLARE @ID_UsuarioRestablecer INT;
        SELECT @ID_UsuarioRestablecer = ID_Usuario
        FROM Usuario
        WHERE Email = @Email
          AND ID_TipoUsuario = 1;

        IF @ID_UsuarioRestablecer IS NULL
            RAISERROR('No se encontró un administrador con ese correo.', 16, 1);

        -- Validar que el administrador esté inactivo
        IF EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_UsuarioRestablecer AND Estado = 1
        )
            RAISERROR('El administrador ya está activo. No es necesario restablecer.', 16, 1);

        BEGIN TRANSACTION;

        -- Restablecer el estado y actualizar la contraseña (el trigger limpia la Fecha_Salida)
        UPDATE Usuario
        SET Estado = 1,
            Contraseña = @NuevaContrasena
        WHERE ID_Usuario = @ID_UsuarioRestablecer;

        COMMIT TRANSACTION;
        PRINT 'Administrador restablecido correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/*  Ejemplo de ejecución
EXEC RestablecerAdministrador
    @ID_UsuarioEjecutor = 1,                          -- ID de usuario con permisos
    @Email = 'lucia.admin@empresa.com',               -- Email del admin a restablecer
    @NuevaContrasena = 'NuevaClaveSegura456';         -- Nueva contraseña
*/
