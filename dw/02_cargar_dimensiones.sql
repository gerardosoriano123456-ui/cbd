/* Carga T-SQL desde el modelo relacional hacia el modelo estrella.
   El origen y el destino deben estar en la misma instancia. */
USE analisis_opiniones_dw;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF DB_ID(N'analisis_opiniones') IS NULL OR DB_NAME() <> N'analisis_opiniones_dw'
    THROW 50011, 'Verifique las bases analisis_opiniones y analisis_opiniones_dw.', 1;

DECLARE @cambios TABLE (
    dimension SYSNAME PRIMARY KEY, insertadas INT NOT NULL, actualizadas INT NOT NULL
);
DECLARE @bloqueo INT, @insertadas INT, @actualizadas INT;
DECLARE @sistema NVARCHAR(80) = N'ANALISIS_OPINIONES';

BEGIN TRY
    BEGIN TRANSACTION;
    EXEC @bloqueo = sys.sp_getapplock
        @Resource = N'carga_dimensiones_opiniones', @LockMode = 'Exclusive',
        @LockOwner = 'Transaction', @LockTimeout = 10000;
    IF @bloqueo < 0
        THROW 50012, 'No se pudo obtener el bloqueo de carga de dimensiones.', 1;

    WITH fechas AS (
        SELECT CAST(fecha_opinion AS DATE) AS fecha FROM analisis_opiniones.dbo.opinion
        UNION
        SELECT CAST(fecha_respuesta AS DATE) FROM analisis_opiniones.dbo.respuesta_encuesta
    )
    INSERT dbo.dim_fecha (fecha_id, fecha)
    SELECT CONVERT(INT, CONVERT(CHAR(8), f.fecha, 112)), f.fecha
    FROM fechas f
    WHERE NOT EXISTS (SELECT 1 FROM dbo.dim_fecha d WHERE d.fecha = f.fecha);
    INSERT @cambios VALUES (N'dim_fecha', @@ROWCOUNT, 0);

    SELECT CONVERT(NVARCHAR(100), p.id_producto) COLLATE DATABASE_DEFAULT AS codigo,
           TRIM(p.nombre) COLLATE DATABASE_DEFAULT AS nombre,
           TRIM(c.nombre) COLLATE DATABASE_DEFAULT AS categoria
    INTO #dw_productos
    FROM analisis_opiniones.dbo.producto p
    INNER JOIN analisis_opiniones.dbo.categoria_producto c ON c.id_categoria = p.id_categoria;

    UPDATE d SET nombre = s.nombre, categoria = s.categoria
    FROM dbo.dim_producto d
    INNER JOIN #dw_productos s ON s.codigo = d.codigo_origen
    WHERE d.sistema_origen = @sistema
      AND EXISTS (SELECT s.nombre, s.categoria EXCEPT SELECT d.nombre, d.categoria);
    SET @actualizadas = @@ROWCOUNT;

    INSERT dbo.dim_producto (sistema_origen, codigo_origen, nombre, categoria)
    SELECT @sistema, s.codigo, s.nombre, s.categoria
    FROM #dw_productos s
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.dim_producto d
        WHERE d.sistema_origen = @sistema AND d.codigo_origen = s.codigo
    );
    SET @insertadas = @@ROWCOUNT;
    INSERT @cambios VALUES (N'dim_producto', @insertadas, @actualizadas);

    SELECT CONVERT(NVARCHAR(100), id_cliente) COLLATE DATABASE_DEFAULT AS codigo,
           NULLIF(CONCAT_WS(N' ', NULLIF(TRIM(nombre), N''), NULLIF(TRIM(apellido), N'')), N'')
               COLLATE DATABASE_DEFAULT AS nombre,
           NULLIF(TRIM(pais), N'') COLLATE DATABASE_DEFAULT AS pais,
           NULLIF(TRIM(ciudad), N'') COLLATE DATABASE_DEFAULT AS ciudad
    INTO #dw_clientes
    FROM analisis_opiniones.dbo.cliente;

    UPDATE d SET nombre = s.nombre, pais = s.pais, ciudad = s.ciudad
    FROM dbo.dim_cliente d
    INNER JOIN #dw_clientes s ON s.codigo = d.codigo_origen
    WHERE d.sistema_origen = @sistema
      AND EXISTS (SELECT s.nombre, s.pais, s.ciudad EXCEPT SELECT d.nombre, d.pais, d.ciudad);
    SET @actualizadas = @@ROWCOUNT;

    INSERT dbo.dim_cliente (sistema_origen, codigo_origen, nombre, pais, ciudad)
    SELECT @sistema, s.codigo, s.nombre, s.pais, s.ciudad
    FROM #dw_clientes s
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.dim_cliente d
        WHERE d.sistema_origen = @sistema AND d.codigo_origen = s.codigo
    );
    SET @insertadas = @@ROWCOUNT;
    INSERT @cambios VALUES (N'dim_cliente', @insertadas, @actualizadas);

    SELECT CONVERT(NVARCHAR(80), CONCAT(@sistema, N':', f.id_fuente)) AS codigo,
           TRIM(f.nombre) COLLATE DATABASE_DEFAULT AS nombre,
           m.canal, m.tipo_origen
    INTO #dw_fuentes
    FROM analisis_opiniones.dbo.fuente_datos f
    INNER JOIN (VALUES
        ('ENCUESTA', N'ENCUESTA', N'CSV'),
        ('RESENA_WEB', N'WEB', N'BASE_DATOS'),
        ('RED_SOCIAL', N'RED_SOCIAL', N'API_REST')
    ) m(tipo, canal, tipo_origen) ON f.tipo COLLATE DATABASE_DEFAULT = m.tipo;

    UPDATE d SET nombre = s.nombre, canal = s.canal, tipo_origen = s.tipo_origen
    FROM dbo.dim_fuente d
    INNER JOIN #dw_fuentes s ON s.codigo = d.codigo
    WHERE EXISTS (
        SELECT s.nombre, s.canal, s.tipo_origen EXCEPT SELECT d.nombre, d.canal, d.tipo_origen
    );
    SET @actualizadas = @@ROWCOUNT;

    INSERT dbo.dim_fuente (codigo, nombre, canal, tipo_origen)
    SELECT s.codigo, s.nombre, s.canal, s.tipo_origen
    FROM #dw_fuentes s
    WHERE NOT EXISTS (SELECT 1 FROM dbo.dim_fuente d WHERE d.codigo = s.codigo);
    SET @insertadas = @@ROWCOUNT;
    INSERT @cambios VALUES (N'dim_fuente', @insertadas, @actualizadas);

    IF NOT EXISTS (
        SELECT 1 FROM dbo.dim_cliente WHERE cliente_id = 0
          AND sistema_origen = N'TECNICO' AND codigo_origen = N'ANONIMO'
    ) OR NOT EXISTS (
        SELECT 1 FROM dbo.dim_evento WHERE evento_id = 0 AND codigo = N'SIN_EVENTO'
    ) OR (SELECT COUNT(*) FROM dbo.dim_sentimiento WHERE sentimiento_id BETWEEN 0 AND 3) <> 4
        THROW 50013, 'Faltan los miembros técnicos o el catálogo de sentimientos del modelo.', 1;

    INSERT @cambios VALUES (N'dim_sentimiento', 0, 0), (N'dim_evento', 0, 0);
    DROP TABLE #dw_productos, #dw_clientes, #dw_fuentes;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT dimension, insertadas, actualizadas FROM @cambios ORDER BY dimension;
