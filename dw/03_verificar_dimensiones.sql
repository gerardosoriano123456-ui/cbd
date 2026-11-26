USE analisis_opiniones_dw;
GO
SET NOCOUNT ON;
SELECT DB_NAME() AS base_destino, SERVERPROPERTY('ProductVersion') AS version_motor;

SELECT N'dim_cliente' AS tabla, COUNT(*) AS filas FROM dbo.dim_cliente
UNION ALL SELECT N'dim_evento', COUNT(*) FROM dbo.dim_evento
UNION ALL SELECT N'dim_fecha', COUNT(*) FROM dbo.dim_fecha
UNION ALL SELECT N'dim_fuente', COUNT(*) FROM dbo.dim_fuente
UNION ALL SELECT N'dim_producto', COUNT(*) FROM dbo.dim_producto
UNION ALL SELECT N'dim_sentimiento', COUNT(*) FROM dbo.dim_sentimiento
UNION ALL SELECT N'fact_opinion', COUNT(*) FROM dbo.fact_opinion
ORDER BY tabla;

SELECT fecha_id, fecha, anio, trimestre, mes, dia FROM dbo.dim_fecha ORDER BY fecha_id;
SELECT TOP (10) producto_id, codigo_origen, nombre, categoria
FROM dbo.dim_producto ORDER BY codigo_origen, producto_id;
SELECT TOP (10) cliente_id, codigo_origen, ciudad
FROM dbo.dim_cliente ORDER BY cliente_id;
SELECT TOP (10) fuente_id, codigo, canal, tipo_origen FROM dbo.dim_fuente ORDER BY codigo;
SELECT sentimiento_id, nombre FROM dbo.dim_sentimiento ORDER BY sentimiento_id;
SELECT TOP (10) evento_id, codigo, nombre FROM dbo.dim_evento ORDER BY evento_id;
