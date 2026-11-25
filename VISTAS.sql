USE DBProyectoGestionComercial;
GO



/*------------------------------------Vistas de menu con subMenu------------------------------------------------------*/

CREATE OR ALTER VIEW VW_Menu_SubMenu AS
SELECT
    M.ID_Menu,
    M.Nombre AS Nombre_Menu,
    SM.ID_SubMenu,
    SM.Nombre AS Nombre_SubMenu
FROM
    Menu M
INNER JOIN
    SubMenu SM ON M.ID_Menu = SM.ID_Menu;
GO




/*--------------------------Vistas para todos los empleados--------------------------------*/

CREATE OR ALTER VIEW VW_UsuariosEmpleados AS
SELECT
    u.ID_Usuario,
    u.Nombre_Usuario,
    u.Apellido_Usuario,
    u.Email,
    u.Contraseña,
    tu.Nombre_TipoUsuario AS Tipo_Usuario,
    Estado = CASE u.Estado
                WHEN 1 THEN 'Activo'
                WHEN 0 THEN 'Inactivo'
             END
FROM Usuario u
JOIN Tipo_de_Usuario tu ON u.ID_TipoUsuario = tu.ID_TipoUsuario
WHERE u.ID_TipoUsuario IN (1, 2);
GO


/*--------------------------Vista para todos los usuarios----------------------------------------------------------------*/

CREATE OR ALTER VIEW VW_TodosLosUsuarios AS
SELECT
    u.ID_Usuario,
    u.Nombre_Usuario AS Nombre,
    u.Apellido_Usuario AS Apellido,
    u.DNI_Usuario AS DNI,
    u.Email,
    u.Contraseña,
    u.Telefono,
    tu.Nombre_TipoUsuario AS Tipo_Usuario,
    Estado = CASE u.Estado
                WHEN 1 THEN 'Activo'
                WHEN 0 THEN 'Inactivo'
             END
FROM Usuario u
JOIN Tipo_de_Usuario tu ON u.ID_TipoUsuario = tu.ID_TipoUsuario;
GO



/*-------------------------------------Productos Stock-------------------------------------------------------------------- */

CREATE OR ALTER VIEW VW_ProductosStock
AS
SELECT
    ID_Producto,
    Nombre,
    Stock,
    CASE
        WHEN Estado = 1 THEN 'Activo'
        ELSE 'Inactivo'
    END AS EstadoProducto
FROM Productos;
GO


/*
SELECT * FROM VW_Menu_SubMenu;
SELECT * FROM VW_UsuariosEmpleados;
SELECT * FROM VW_TodosLosUsuarios;
SELECT * FROM VW_ProductosStock;
*/
