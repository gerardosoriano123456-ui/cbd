# Carga de dimensiones del Data Warehouse

**Estudiante:** Gerardo Soriano  
**Matrícula:** 20252481

Los scripts implementan la carga T-SQL del modelo estrella del Sistema de Análisis de
Opiniones de Clientes. La base de origen `analisis_opiniones` y el destino
`analisis_opiniones_dw` deben estar en la misma instancia de SQL Server 2017 o superior.
La carga lee los catálogos relacionales y las fechas de actividad. El Worker de extracción
conserva sus lotes NDJSON para las etapas posteriores del flujo de opiniones.

## Ejecutar en SQL Server Management Studio

1. En una instancia de prueba vacía, abre `00_origen_demo.sql` y ejecútalo con F5. Si ya
   tienes el origen relacional con sus tablas pobladas, empieza en el paso 2.
2. Si el destino todavía no existe, ejecuta `01_crear_modelo.sql`. Este paso requiere
   permiso para crear la base y sus objetos.
3. Ejecuta `02_cargar_dimensiones.sql`. El usuario requiere SELECT en las seis tablas
   de origen referenciadas y SELECT, INSERT y UPDATE en las dimensiones de destino.
   El resultado indica las filas insertadas y actualizadas por dimensión.
4. Ejecuta `03_verificar_dimensiones.sql` para consultar los conteos y las muestras.
   Si ejecutas el paso 3 de nuevo con el mismo origen, los cambios de cada dimensión
   deben sumar cero.

| Dimensión | Regla de carga |
| --- | --- |
| `dim_fecha` | Fechas distintas de `opinion` y `respuesta_encuesta`. Clave AAAAMMDD. |
| `dim_producto` | `producto` unido a `categoria_producto`. Identidad por sistema y código original. La marca queda NULL cuando no se informa. |
| `dim_cliente` | Nombre completo y ubicación desde `cliente`. Identidad por sistema y código. El miembro 0 representa cliente anónimo. |
| `dim_fuente` | `fuente_datos` aporta código y nombre. Los tipos admitidos por el modelo se proyectan a encuesta/CSV, web/base de datos y red social/API REST. |
| `dim_sentimiento` | Catálogo fijo del modelo. El identificador 0 representa una opinión sin clasificar. |
| `dim_evento` | El miembro 0 representa la ausencia de un evento asociado. El origen anterior carece de un catálogo de eventos. |

En productos, clientes y fuentes se aplica SCD tipo 1. Se reemplazan los atributos
en caso de cambio y se conserva la clave sustituta. Las filas ausentes en el origen
se conservan para preservar referencias analíticas. Un bloqueo de aplicación y una
transacción coordinan ejecuciones concurrentes de este módulo. La actividad cubre
las dimensiones. El modelo incluye `fact_opinion` para la futura carga de hechos.

[Salida de ejecución y consultas en SQL Server](../docs/evidencias/dimensiones/carga.txt)
