USE DBProyectoGestionComercial;
GO



INSERT INTO Categorias (Nombre)
VALUES
(N'Procesadores'),
(N'Placas Madre'),
(N'Memorias RAM');



-- Procesadores
INSERT INTO Productos (Nombre, Descripcion, PrecioUnitario, PrecioSinImpuesto, Stock, ID_Categoria)
VALUES
(N'Intel Core i7-12700K', N'Procesador Intel de 12va generación, 12 núcleos, socket LGA1700.', 350.00, 289.26, 10, 1),
(N'AMD Ryzen 7 5800X', N'Procesador AMD de 8 núcleos, socket AM4, rendimiento alto.', 320.00, 264.46, 8, 1);

-- Placas Madre
INSERT INTO Productos (Nombre, Descripcion, PrecioUnitario, PrecioSinImpuesto, Stock, ID_Categoria)
VALUES
(N'ASUS ROG STRIX B550-F', N'Placa madre para AMD Ryzen, soporte DDR4, PCIe 4.0.', 180.00, 148.76, 5, 2),
(N'MSI MAG Z690 TOMAHAWK', N'Placa madre Intel Z690, DDR5, soporte para 12va gen Intel.', 250.00, 206.61, 7, 2);

-- Memorias RAM
INSERT INTO Productos (Nombre, Descripcion, PrecioUnitario, PrecioSinImpuesto, Stock, ID_Categoria)
VALUES
(N'Corsair Vengeance LPX 16GB (2x8GB) DDR4-3200', N'Kit de memoria RAM de alto rendimiento.', 90.00, 74.38, 15, 3),
(N'Kingston Fury Beast 32GB DDR5-5600', N'Módulo de RAM DDR5 de última generación.', 160.00, 132.23, 12, 3);





INSERT INTO Tipo_de_Usuario (Nombre_TipoUsuario)
VALUES
    (N'Administrador'),
    (N'Empleado'),
    (N'Cliente');


INSERT INTO Usuario (
    ID_TipoUsuario, Nombre_Usuario, Apellido_Usuario, DNI_Usuario,
    Email, Contraseña, Telefono, Fecha_Ingreso, Fecha_Salida
) VALUES
-- Administradores
(1, N'Carlos', N'Fernández', N'30111222', N'carlos.admin@empresa.com', N'Admin1234', N'1155667788', '2024-01-10', NULL),
(1, N'Lucía', N'González', N'30222333', N'lucia.admin@empresa.com', N'LuciaPass1', N'1166778899', '2024-02-15', NULL),

-- Empleados
(2, N'Matías', N'Pérez', N'30333444', N'matias.emp@empresa.com', N'EmpMatias2024', N'1177889900', '2024-03-05', NULL),
(2, N'Sofía', N'Ramírez', N'30444555', N'sofia.emp@empresa.com', N'Sofi2024Emp', N'1188990011', '2024-04-01', NULL),

-- Clientes
(3, N'Juan', N'López', N'30555666', N'juan.cliente@mail.com', N'JuanCliente', N'1199001122', '2025-06-01', NULL),
(3, N'Mariana', N'Torres', N'30666777', N'mariana.cliente@mail.com', N'Mari1234', N'1100112233', '2025-06-01', NULL);




/*--------------------------Menu---------------------------------------*/

INSERT INTO Menu(Nombre)
VALUES (N'Ventas'),
       (N'Articulos'),
       (N'Empleados'),
       (N'Clientes'),
       (N'Informes');


/*-----------------------SubMenuVentas (ID 1 a 3)--------------------------------------*/

INSERT INTO SubMenu(ID_Menu,Nombre)
VALUES (1,N'Generar Nueva venta'),      -- 1
       (1,N'Listar Venta'),             -- 2
       (1,N'Buscar Venta');             -- 3


/*-----------------------SubMenuProductos (ID 4 a 11)--------------------------------------*/

INSERT INTO SubMenu(ID_Menu,Nombre)
VALUES (2,N'Agregar Productos'),                       -- 4
       (2,N'Listar Productos'),                        -- 5
       (2,N'Listar por Categoria con ID categoria'),   -- 6
       (2,N'Modificar Precio'),                        -- 7
       (2,N'Actualizar Stock'),                        -- 8
       (2,N'Agregar Categoria'),                       -- 9
       (2,N'Eliminar Producto'),                       -- 10
       (2,N'Restablecer Producto');                    -- 11



/*------------------------SubMenuEmpleados (ID 12 a 19)---------------------------------------*/
INSERT INTO SubMenu(ID_Menu,Nombre)
VALUES (3,N'Agregar Administrador'),                   -- 12
       (3,N'Agregar Empleado'),                        -- 13
       (3,N'Listar Empleado y administrador'),         -- 14
       (3,N'Buscar Empleado o administrador por ID'),  -- 15
       (3,N'Modificar Empleado o administrador'),      -- 16
       (3,N'Eliminar Empleado o administrador'),       -- 17
       (3,N'Restablecer Administrador'),               -- 18
       (3,N'Restablecer Empleado');                    -- 19




/*------------------------SubMenuClientes (ID 20 a 25)---------------------------------------*/
INSERT INTO SubMenu(ID_Menu,Nombre)
VALUES (4,N'Agregar Cliente'),                         -- 20
       (4,N'Listar Cliente'),                          -- 21
       (4,N'Buscar Cliente por ID'),                   -- 22
       (4,N'Modificar Cliente'),                       -- 23
       (4,N'Eliminar Cliente'),                        -- 24
       (4,N'Restablecer Cliente');                     -- 25



/*----------------------SubMenuInformes (ID 26 a 29)-----------------------------------------*/


INSERT INTO SubMenu(ID_Menu,Nombre)
VALUES (5,N'Recaudacion Anual'),                       -- 26
       (5,N'Recaudacion por Cliente'),                 -- 27
       (5,N'Recaudacion por Empleado'),                -- 28
       (5,N'Producto mas Vendido');                    -- 29


/*-----------------------Permisos Administrador---------------------------------------------*/


INSERT INTO Permiso (ID_TipoUsuario,ID_SubMenu,Estado)
VALUES (1,1,1),
       (1,2,1),
       (1,3,1),
       (1,4,1),
       (1,5,1),
       (1,6,1),
       (1,7,1),
       (1,8,1),
       (1,9,1),
       (1,10,1),
       (1,11,1),
       (1,12,1),
       (1,13,1),
       (1,14,1),
       (1,15,1),
       (1,16,1),
       (1,17,1),
       (1,18,1),
       (1,19,1),
       (1,20,1),
       (1,21,1),
       (1,22,1),
       (1,23,1),
       (1,24,1),
       (1,25,1),
       (1,26,1),
       (1,27,1),
       (1,28,1),
       (1,29,1);





/*-----------------------Permisos Empleados---------------------------------------------*/

INSERT INTO Permiso (ID_TipoUsuario,ID_SubMenu,Estado)
VALUES (2,1,1),
       (2,2,1),
       (2,3,1),
       (2,4,1),
       (2,5,1),
       (2,6,1),
       (2,7,1),
       (2,8,1),
       (2,9,1),
       (2,10,1),
       (2,11,1),
       (2,12,0),
       (2,13,0),
       (2,14,0),
       (2,15,0),
       (2,16,0),
       (2,17,0),
       (2,18,0),
       (2,19,0),
       (2,20,1),
       (2,21,1),
       (2,22,1),
       (2,23,1),
       (2,24,1),
       (2,25,1),
       (2,26,0),
       (2,27,0),
       (2,28,0),
       (2,29,0);
GO
