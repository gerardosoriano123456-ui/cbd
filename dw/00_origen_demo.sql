/* Origen ficticio para una instancia local de prueba. Ejecutar una sola vez.
   Usa el contrato de columnas del modelo transaccional y fechas e IDs
   representativos de los archivos CSV del proyecto. */
USE master;
IF DB_ID(N'analisis_opiniones') IS NOT NULL
    THROW 50010, 'El origen ya existe. Use el origen existente o una instancia de prueba.', 1;

EXEC(N'CREATE DATABASE analisis_opiniones;');
EXEC sys.sp_executesql N'
USE analisis_opiniones;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

CREATE TABLE dbo.categoria_producto (
    id_categoria INT PRIMARY KEY, nombre NVARCHAR(80) NOT NULL
);
CREATE TABLE dbo.producto (
    id_producto INT PRIMARY KEY,
    id_categoria INT NOT NULL REFERENCES dbo.categoria_producto(id_categoria),
    nombre NVARCHAR(120) NOT NULL
);
CREATE TABLE dbo.cliente (
    id_cliente INT PRIMARY KEY, nombre NVARCHAR(80) NOT NULL,
    apellido NVARCHAR(80) NOT NULL, pais NVARCHAR(60), ciudad NVARCHAR(60)
);
CREATE TABLE dbo.fuente_datos (
    id_fuente INT PRIMARY KEY, nombre NVARCHAR(100) NOT NULL, tipo VARCHAR(20) NOT NULL
);
CREATE TABLE dbo.opinion (
    id_opinion BIGINT PRIMARY KEY, fecha_opinion DATETIME2(0) NOT NULL
);
CREATE TABLE dbo.respuesta_encuesta (
    id_respuesta BIGINT PRIMARY KEY, fecha_respuesta DATETIME2(0) NOT NULL
);

INSERT dbo.categoria_producto VALUES (1,N''Audio''),(2,N''Accesorios''),(3,N''Energía'');
INSERT dbo.producto VALUES
    (501,1,N''Audífonos inalámbricos''),(502,2,N''Ratón inalámbrico''),
    (503,3,N''Batería portátil''),(504,3,N''Cargador USB-C'');
INSERT dbo.cliente VALUES
    (1001,N''Ana'',N''Pérez'',N''República Dominicana'',N''Santo Domingo''),
    (1002,N''Luis'',N''Gómez'',N''República Dominicana'',N''Boca Chica''),
    (1003,N''Marta'',N''Díaz'',N''República Dominicana'',N''Santiago''),
    (1004,N''José'',N''Reyes'',N''República Dominicana'',N''Santo Domingo''),
    (1005,N''Elena'',N''Santos'',N''República Dominicana'',N''La Romana''),
    (1006,N''Jorge'',N''Peña'',N''República Dominicana'',N''Boca Chica''),
    (1007,N''Sara'',N''Mora'',N''República Dominicana'',N''Santiago''),
    (1008,N''Mario'',N''Cruz'',N''República Dominicana'',N''La Romana'');
INSERT dbo.fuente_datos VALUES
    (101,N''Encuestas de satisfacción'',''ENCUESTA''),
    (205,N''Facebook'',''RED_SOCIAL''),(307,N''Instagram'',''RED_SOCIAL''),
    (409,N''Reseñas de la tienda web'',''RESENA_WEB'');
INSERT dbo.opinion VALUES
    (9001,''2026-10-15T12:00:00''),(9002,''2026-10-15T12:01:00''),
    (9003,''2026-10-15T12:02:00''),(9004,''2026-10-15T12:03:00''),
    (9005,''2026-10-16T12:04:00''),(9006,''2026-10-16T12:05:00''),
    (9007,''2026-10-16T12:06:00''),(9008,''2026-10-16T12:07:00''),
    (9009,''2026-10-17T12:08:00''),(9010,''2026-10-17T12:09:00''),
    (9011,''2026-10-17T12:10:00''),(9012,''2026-10-17T12:11:00'');
INSERT dbo.respuesta_encuesta VALUES
    (630,''2026-10-15T12:04:00''),(640,''2026-10-15T12:05:00'');
COMMIT TRANSACTION;
';
