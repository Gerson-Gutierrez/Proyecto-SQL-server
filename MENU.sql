USE DBProyectoGestionComercial;
GO

/*  La vista VW_Menu_SubMenu se crea en VISTAS.sql (antes estaba duplicada aquí
    y la segunda creación fallaba).  */


/*------------------------------Ver SubMenus por Usuario con Permisos ----------------------------------------------------*/

CREATE OR ALTER PROCEDURE PermisosSubMenusPorUsuario
    @ID_Usuario INT,
    @Contrasena NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validar parámetros
        IF @ID_Usuario IS NULL OR @ID_Usuario <= 0
            RAISERROR('Debe ingresar un ID de usuario válido.', 16, 1);

        IF @Contrasena IS NULL OR LTRIM(RTRIM(@Contrasena)) = ''
            RAISERROR('Debe ingresar la contraseña.', 16, 1);

        -- Validar si el usuario existe, tiene esa contraseña y está activo
        IF NOT EXISTS (
            SELECT 1
            FROM Usuario
            WHERE ID_Usuario = @ID_Usuario
              AND Contraseña = @Contrasena
              AND Estado = 1
        )
            RAISERROR('Usuario no válido, contraseña incorrecta o usuario inactivo.', 16, 1);

        -- Variables de información
        DECLARE @ID_TipoUsuario INT;
        DECLARE @NombreCompleto NVARCHAR(101);
        DECLARE @Rol NVARCHAR(30);

        -- Obtener datos del usuario
        SELECT
            @ID_TipoUsuario = u.ID_TipoUsuario,
            @NombreCompleto = u.Nombre_Usuario + ' ' + u.Apellido_Usuario,
            @Rol            = tu.Nombre_TipoUsuario
        FROM Usuario u
        JOIN Tipo_de_Usuario tu ON tu.ID_TipoUsuario = u.ID_TipoUsuario
        WHERE u.ID_Usuario = @ID_Usuario;

        -- Validar que sea Administrador o Empleado
        IF @ID_TipoUsuario NOT IN (1, 2)
            RAISERROR('Acceso denegado: solo administradores o empleados pueden ejecutar este procedimiento.', 16, 1);

        -- Mostrar todos los submenús y si tiene o no permiso activo
        SELECT
            @NombreCompleto AS Nombre_Usuario,
            @Rol AS Tipo_Usuario,
            M.Nombre AS Nombre_Menu,
            SM.ID_SubMenu,
            SM.Nombre AS Nombre_SubMenu,
            CASE
                WHEN P.Estado = 1 THEN 'Activo'
                WHEN P.Estado = 0 THEN 'Inactivo'
                ELSE 'Sin Permiso Registrado'
            END AS Estado_Permiso
        FROM SubMenu SM
        INNER JOIN Menu M ON M.ID_Menu = SM.ID_Menu
        LEFT JOIN Permiso P ON P.ID_SubMenu = SM.ID_SubMenu AND P.ID_TipoUsuario = @ID_TipoUsuario
        ORDER BY M.ID_Menu, SM.ID_SubMenu;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


/*  Ejemplo de ejecución
EXEC PermisosSubMenusPorUsuario
    @ID_Usuario = 3,
    @Contrasena = 'EmpMatias2024';
*/
