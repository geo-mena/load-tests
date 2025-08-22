# Load Testing para Passive Liveness API

Este directorio contiene herramientas para realizar pruebas de carga y estrés del endpoint `passive-liveness/evaluate/token` del SDK SelphId.

## 📋 Tabla de Contenido

- [Estructura de Directorios](#estructura-de-directorios)
- [Apache JMeter - Herramienta Principal](#apache-jmeter---herramienta-principal)
- [Monitoreo de Recursos](#monitoreo-de-recursos)
- [Preparación de Datos de Prueba](#preparación-de-datos-de-prueba)
- [Ejecución de Pruebas Completas](#ejecución-de-pruebas-completas)
- [Análisis de Resultados](#análisis-de-resultados)
- [Troubleshooting](#troubleshooting)
- [Próximos Pasos](#próximos-pasos)

## Estructura de Directorios

```
load-tests/
├── jmeter/              # Planes de prueba JMeter (.jmx)
├── scripts/             # Scripts alternativos (bash, curl, wrk)
├── results/             # Resultados de las pruebas
├── test-data/           # Imágenes de prueba y datos necesarios
└── README.md            # Esta documentación
```

## Apache JMeter - Herramienta Principal

#### Archivos disponibles:
- `jmeter/passive-liveness-4tps.jmx` - Prueba de carga a 4 TPS
- `jmeter/passive-liveness-5tps.jmx` - Prueba de carga a 5 TPS
- `jmeter/passive-liveness-6tps.jmx` - Prueba de carga a 6 TPS

#### Configuración de las pruebas JMeter:
- **Threads**: 4, 5 o 6 hilos concurrentes (según el archivo)
- **Ramp-up**: 4-6 segundos (gradual)
- **Duración**: 300 segundos (5 minutos) por defecto
- **Timer**: 1 segundo entre requests por hilo

#### Variables configurables:
- `SERVER_HOST`: Host del servidor (default: localhost)
- `SERVER_PORT`: Puerto del servidor (default: 8080)
- `TEST_DURATION`: Duración de la prueba en segundos (default: 300)
- `PAYLOAD_FILE`: Archivo JSON con el payload (default: ../data/payload.json)

#### Cómo ejecutar con JMeter:

##### Modo GUI (para desarrollo y depuración):
```bash
# Abrir JMeter con interfaz gráfica
jmeter

# O abrir directamente un plan de prueba
jmeter -t jmeter/passive-liveness-4tps.jmx  # 4 TPS
jmeter -t jmeter/passive-liveness-5tps.jmx  # 5 TPS
jmeter -t jmeter/passive-liveness-6tps.jmx  # 6 TPS
```

##### Modo Non-GUI (para pruebas de rendimiento):
```bash
# Prueba de 4 TPS
jmeter -n -t jmeter/passive-liveness-4tps.jmx \
       -JSERVER_HOST=localhost \
       -JSERVER_PORT=8080 \
       -JTEST_DURATION=300 \
       -l results/jmeter-4tps-results.jtl \
       -e -o results/jmeter-4tps-report/

# Prueba de 5 TPS
jmeter -n -t jmeter/passive-liveness-5tps.jmx \
       -JSERVER_HOST=localhost \
       -JSERVER_PORT=8080 \
       -JTEST_DURATION=300 \
       -l results/jmeter-5tps-results.jtl \
       -e -o results/jmeter-5tps-report/

# Prueba de 6 TPS
jmeter -n -t jmeter/passive-liveness-6tps.jmx \
       -JSERVER_HOST=localhost \
       -JSERVER_PORT=8080 \
       -JTEST_DURATION=300 \
       -l results/jmeter-6tps-results.jtl \
       -e -o results/jmeter-6tps-report/
```

## Monitoreo de Recursos

### Script de Monitoreo: `scripts/monitor-resources.sh`

Este script monitorea el rendimiento del sistema durante las pruebas de carga.

#### Métricas monitoreadas:
- **CPU**: Uso por proceso, carga del sistema
- **Memoria**: RAM total, usada, disponible, swap
- **Disco**: I/O reads/writes, utilización
- **Red**: Tráfico de entrada/salida
- **Procesos Java**: CPU y memoria específica de Java

#### Uso:
```bash
cd scripts
./monitor-resources.sh [DURATION] [INTERVAL] [OUTPUT_PREFIX]

# Ejemplo: Monitorear por 300s cada 5s
./monitor-resources.sh 300 5 "passive-liveness-test"
```

#### Archivos generados:
- `*-cpu.log`: Estadísticas de CPU
- `*-memory.log`: Uso de memoria
- `*-disk.log`: I/O de disco
- `*-network.log`: Tráfico de red
- `*-processes.log`: Procesos Java específicos
- `*-summary.txt`: Resumen estadístico

## Preparación de Datos de Prueba

### 1. Configurar Payload JSON
Edita el archivo `data/payload.json` con tu `tokenImage` real:

```json
{
  "tokenImage": "TU_IMAGEN_BASE64_AQUI",
  "extraData": "load-test-request"
}
```

**Pasos para configurar:**
1. Codifica tu imagen de rostro en Base64
2. Reemplaza `"BASE64_ENCODED_IMAGE_HERE"` en `data/payload.json`
3. Opcionalmente modifica `extraData` según tus necesidades

### 2. Configuración del Servidor
Asegúrate de que el servidor SelphId esté ejecutándose:

```bash
# Verificar que el servicio esté corriendo
curl -X GET http://localhost:8080/api/v1/selphid/health
```

## Ejecución de Pruebas Completas

### Escenario Recomendado

1. **Preparar el entorno:**
```bash
# Iniciar servidor SelphId
# Colocar imagen de prueba en test-data/

# Verificar conectividad
curl -X GET http://localhost:8080/api/v1/selphid/health
```

2. **Ejecutar monitoreo en background:**
```bash
cd scripts
./monitor-resources.sh 600 5 "test-5tps" &
MONITOR_PID=$!
```

3. **Ejecutar prueba de carga (elegir una opción):**

**Ejecutar prueba con JMeter:**
```bash
# Modo GUI (desarrollo)
jmeter -t jmeter/passive-liveness-5tps.jmx

# Modo Non-GUI (producción)
jmeter -n -t jmeter/passive-liveness-5tps.jmx \
       -l results/test-5tps-jmeter.jtl \
       -e -o results/test-5tps-jmeter-report/
```

4. **Detener monitoreo:**
```bash
kill $MONITOR_PID
```

### Ventajas de JMeter para estas pruebas:

- **Interfaz gráfica** para desarrollo y configuración
- **Reportes HTML automáticos** con gráficos detallados
- **Métricas completas**: TPS, tiempos de respuesta, percentiles
- **Fácil configuración** de variables y parámetros
- **Listeners integrados** para monitoreo en tiempo real
- **Assertions** para validar respuestas automáticamente

## Análisis de Resultados

### Métricas Clave a Analizar

#### 1. Rendimiento de API:
- **TPS real**: Transacciones por segundo logradas
- **Tiempo de respuesta promedio**: < 2000ms recomendado
- **Percentil 95**: < 3000ms recomendado
- **Tasa de errores**: < 1% recomendado

#### 2. Recursos del Sistema:
- **Uso de RAM**: Monitorear crecimiento durante la prueba
- **CPU**: No debería superar 80% sostenido
- **I/O de Disco**: Verificar no sea un cuello de botella
- **Memoria Java**: Verificar garbage collection

### Umbrales Recomendados

| Métrica | 4 TPS | 5 TPS | 6 TPS | Acción si se excede |
|---------|-------|-------|-------|-------------------|
| Tiempo respuesta avg | < 1200ms | < 1500ms | < 1800ms | Optimizar algoritmo |
| Uso RAM | < 1.5GB | < 2GB | < 2.5GB | Aumentar heap size |
| CPU promedio | < 50% | < 60% | < 70% | Verificar procesamiento |
| Tasa de errores | < 0.1% | < 0.5% | < 1% | Revisar logs de errores |

## Troubleshooting

### Problemas Comunes

1. **Error "Connection refused"**
   - Verificar que el servidor esté ejecutándose
   - Confirmar host y puerto correctos

2. **Timeouts en respuestas**
   - Aumentar timeout en los scripts
   - Verificar recursos del servidor

3. **Memoria insuficiente**
   - Aumentar heap size de Java: `-Xmx4g`
   - Monitorear garbage collection

4. **Imagen de prueba inválida**
   - Verificar que la imagen sea un rostro válido
   - Confirmar formato y tamaño adecuados

### Logs de Depuración

```bash
# Verificar logs del servidor
tail -f /var/log/selphid/application.log

# Verificar conectividad de red
netstat -tlnp | grep 8080

# Monitorear procesos Java
jps -v
```

## Próximos Pasos

1. **Ejecutar pruebas progresivas**: Empezar con 4 TPS, luego 5 TPS, finalmente 6 TPS
2. **Analizar resultados** y identificar cuellos de botella
3. **Ajustar configuración** del servidor según necesidad
4. **Incrementar gradualmente** la carga hasta encontrar límites
5. **Documentar configuración óptima** para producción

### Estrategia de Pruebas Recomendada:

```bash
# 1. Prueba baseline (4 TPS) - Establecer línea base
jmeter -t jmeter/passive-liveness-4tps.jmx

# 2. Prueba objetivo (5 TPS) - Carga esperada
jmeter -t jmeter/passive-liveness-5tps.jmx  

# 3. Prueba estrés (6 TPS) - Verificar límites
jmeter -t jmeter/passive-liveness-6tps.jmx
```