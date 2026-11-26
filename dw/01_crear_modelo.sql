/* Actividad 3.1 - Sistema de Analisis de Opiniones de Clientes
   Gerardo Soriano | 20252481 | Electiva 1 - ITLA
   MODELO ANALITICO. Ejecutar en SSMS con permiso CREATE DATABASE.
   No modifica analisis_opiniones. No contiene datos de negocio ni un ETL.
   Las dimensiones usan claves sustitutas; grano: una opinion por fuente e ID.
   Este script se ejecuta una sola vez. Una segunda ejecucion aborta sin borrar.
*/
USE master;
-- Un solo lote: THROW impide alcanzar cualquier sentencia posterior.
IF DB_ID(N'analisis_opiniones_dw') IS NOT NULL
BEGIN
    ;THROW 50001, 'La base analisis_opiniones_dw ya existe. No se modifica. Revise su contenido antes de continuar.', 1;
END;
EXEC(N'CREATE DATABASE analisis_opiniones_dw;');
-- SQL dinamico permite cambiar de base sin separar la guardia con GO.
-- Si el DDL falla, XACT_ABORT revierte los objetos; la base vacia puede permanecer.
EXEC sys.sp_executesql N'USE analisis_opiniones_dw;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

CREATE TABLE dbo.dim_fecha (
    fecha_id INT NOT NULL,
    fecha DATE NOT NULL,
    anio AS YEAR(fecha) PERSISTED,
    trimestre AS DATEPART(QUARTER, fecha) PERSISTED,
    mes AS MONTH(fecha) PERSISTED,
    dia AS DAY(fecha) PERSISTED,
    CONSTRAINT PK_dim_fecha PRIMARY KEY (fecha_id),
    CONSTRAINT UQ_dim_fecha UNIQUE (fecha),
    CONSTRAINT CK_dim_fecha_clave CHECK
      (fecha_id = YEAR(fecha) * 10000 + MONTH(fecha) * 100 + DAY(fecha))
);

CREATE TABLE dbo.dim_producto (
    producto_id INT IDENTITY(1,1) NOT NULL,
    sistema_origen NVARCHAR(80) NOT NULL,
    codigo_origen NVARCHAR(100) NOT NULL,
    nombre NVARCHAR(200) NOT NULL,
    categoria NVARCHAR(150) NOT NULL,
    marca NVARCHAR(100) NULL,
    CONSTRAINT PK_dim_producto PRIMARY KEY (producto_id),
    CONSTRAINT UQ_dim_producto_origen UNIQUE (sistema_origen, codigo_origen)
);

CREATE TABLE dbo.dim_cliente (
    cliente_id INT IDENTITY(1,1) NOT NULL,
    sistema_origen NVARCHAR(80) NOT NULL,
    codigo_origen NVARCHAR(100) NOT NULL,
    nombre NVARCHAR(200) NULL,
    pais NVARCHAR(100) NULL,
    region NVARCHAR(100) NULL,
    ciudad NVARCHAR(100) NULL,
    tipo_cliente NVARCHAR(80) NULL,
    CONSTRAINT PK_dim_cliente PRIMARY KEY (cliente_id),
    CONSTRAINT UQ_dim_cliente_origen UNIQUE (sistema_origen, codigo_origen)
);

CREATE TABLE dbo.dim_fuente (
    fuente_id INT IDENTITY(1,1) NOT NULL,
    codigo NVARCHAR(80) NOT NULL,
    nombre NVARCHAR(150) NOT NULL,
    canal NVARCHAR(20) NOT NULL,
    tipo_origen NVARCHAR(20) NOT NULL,
    CONSTRAINT PK_dim_fuente PRIMARY KEY (fuente_id),
    CONSTRAINT UQ_dim_fuente_codigo UNIQUE (codigo),
    CONSTRAINT CK_dim_fuente_canal CHECK
      (canal IN (N''ENCUESTA'', N''WEB'', N''RED_SOCIAL'')),
    CONSTRAINT CK_dim_fuente_tipo CHECK
      (tipo_origen IN (N''CSV'', N''BASE_DATOS'', N''API_REST''))
);

CREATE TABLE dbo.dim_sentimiento (
    sentimiento_id TINYINT NOT NULL,
    nombre NVARCHAR(30) NOT NULL,
    CONSTRAINT PK_dim_sentimiento PRIMARY KEY (sentimiento_id),
    CONSTRAINT UQ_dim_sentimiento_nombre UNIQUE (nombre),
    CONSTRAINT CK_dim_sentimiento_valor CHECK
      ((sentimiento_id = 0 AND nombre = N''SIN_CLASIFICAR'') OR
       (sentimiento_id = 1 AND nombre = N''POSITIVO'') OR
       (sentimiento_id = 2 AND nombre = N''NEGATIVO'') OR
       (sentimiento_id = 3 AND nombre = N''NEUTRO''))
);

CREATE TABLE dbo.dim_evento (
    evento_id INT IDENTITY(1,1) NOT NULL,
    codigo NVARCHAR(80) NOT NULL,
    nombre NVARCHAR(200) NOT NULL,
    tipo NVARCHAR(80) NOT NULL,
    fecha_inicio DATE NULL,
    fecha_fin DATE NULL,
    CONSTRAINT PK_dim_evento PRIMARY KEY (evento_id),
    CONSTRAINT UQ_dim_evento_codigo UNIQUE (codigo),
    CONSTRAINT CK_dim_evento_fechas CHECK
      ((fecha_inicio IS NULL AND fecha_fin IS NULL) OR
       (fecha_inicio IS NOT NULL AND fecha_fin IS NOT NULL AND fecha_fin >= fecha_inicio))
);

CREATE TABLE dbo.fact_opinion (
    opinion_id BIGINT IDENTITY(1,1) NOT NULL,
    id_opinion_origen NVARCHAR(200) NOT NULL,
    fecha_id INT NOT NULL,
    producto_id INT NOT NULL,
    cliente_id INT NOT NULL CONSTRAINT DF_fact_cliente DEFAULT (0),
    fuente_id INT NOT NULL,
    sentimiento_id TINYINT NOT NULL CONSTRAINT DF_fact_sentimiento DEFAULT (0),
    evento_id INT NOT NULL CONSTRAINT DF_fact_evento DEFAULT (0),
    fecha_opinion DATETIME2(0) NOT NULL,
    edad_al_opinar TINYINT NULL,
    texto NVARCHAR(MAX) NULL,
    calificacion_5 DECIMAL(4,2) NULL,
    valoracion_original DECIMAL(10,4) NULL,
    escala_minima DECIMAL(10,4) NULL,
    escala_maxima DECIMAL(10,4) NULL,
    metodo_sentimiento NVARCHAR(100) NULL,
    fecha_carga_utc DATETIME2(0) NOT NULL
      CONSTRAINT DF_fact_carga DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_fact_opinion PRIMARY KEY (opinion_id),
    CONSTRAINT UQ_fact_opinion_origen UNIQUE (fuente_id, id_opinion_origen),
    CONSTRAINT FK_fact_fecha FOREIGN KEY (fecha_id) REFERENCES dbo.dim_fecha(fecha_id),
    CONSTRAINT FK_fact_producto FOREIGN KEY (producto_id) REFERENCES dbo.dim_producto(producto_id),
    CONSTRAINT FK_fact_cliente FOREIGN KEY (cliente_id) REFERENCES dbo.dim_cliente(cliente_id),
    CONSTRAINT FK_fact_fuente FOREIGN KEY (fuente_id) REFERENCES dbo.dim_fuente(fuente_id),
    CONSTRAINT FK_fact_sentimiento FOREIGN KEY (sentimiento_id) REFERENCES dbo.dim_sentimiento(sentimiento_id),
    CONSTRAINT FK_fact_evento FOREIGN KEY (evento_id) REFERENCES dbo.dim_evento(evento_id),
    CONSTRAINT CK_fact_fecha CHECK
      (fecha_id = YEAR(fecha_opinion) * 10000 + MONTH(fecha_opinion) * 100 + DAY(fecha_opinion)),
    CONSTRAINT CK_fact_id_origen CHECK (LEN(LTRIM(RTRIM(id_opinion_origen))) > 0),
    CONSTRAINT CK_fact_edad CHECK (edad_al_opinar IS NULL OR edad_al_opinar <= 120),
    CONSTRAINT CK_fact_calificacion CHECK (calificacion_5 IS NULL OR calificacion_5 BETWEEN 1 AND 5),
    CONSTRAINT CK_fact_escala CHECK
      ((valoracion_original IS NULL AND escala_minima IS NULL AND escala_maxima IS NULL AND calificacion_5 IS NULL) OR
       (valoracion_original IS NOT NULL AND escala_minima IS NOT NULL AND escala_maxima IS NOT NULL
        AND calificacion_5 IS NOT NULL AND escala_maxima > escala_minima
        AND valoracion_original BETWEEN escala_minima AND escala_maxima
        AND ABS(calificacion_5 - (1.0 + 4.0 *
          ((valoracion_original - escala_minima) / NULLIF(escala_maxima - escala_minima, 0)))) <= 0.0051))
);

CREATE INDEX IX_fact_fecha_producto ON dbo.fact_opinion(fecha_id, producto_id)
    INCLUDE (calificacion_5, sentimiento_id, fuente_id);
CREATE INDEX IX_fact_producto_fecha ON dbo.fact_opinion(producto_id, fecha_id)
    INCLUDE (calificacion_5, sentimiento_id);
CREATE INDEX IX_fact_cliente ON dbo.fact_opinion(cliente_id);
CREATE INDEX IX_fact_fuente_sentimiento ON dbo.fact_opinion(fuente_id, sentimiento_id);
CREATE INDEX IX_fact_evento ON dbo.fact_opinion(evento_id);

/* Miembros tecnicos. No son datos de clientes ni opiniones de demostracion. */
SET IDENTITY_INSERT dbo.dim_cliente ON;
INSERT INTO dbo.dim_cliente (cliente_id, sistema_origen, codigo_origen, nombre)
VALUES (0, N''TECNICO'', N''ANONIMO'', N''Cliente no identificado'');
SET IDENTITY_INSERT dbo.dim_cliente OFF;

SET IDENTITY_INSERT dbo.dim_evento ON;
INSERT INTO dbo.dim_evento (evento_id, codigo, nombre, tipo)
VALUES (0, N''SIN_EVENTO'', N''Sin evento identificado'', N''NO_APLICA'');
SET IDENTITY_INSERT dbo.dim_evento OFF;

INSERT INTO dbo.dim_sentimiento (sentimiento_id, nombre)
VALUES (0,N''SIN_CLASIFICAR''),(1,N''POSITIVO''),(2,N''NEGATIVO''),(3,N''NEUTRO'');

COMMIT TRANSACTION;
PRINT N''Modelo creado: 6 dimensiones y 1 tabla de hechos. No hay opiniones cargadas.'';
';
