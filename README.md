# Load Testing para Passive Liveness API

Este directorio contiene herramientas para realizar pruebas de carga y estrés del endpoint `passive-liveness/evaluate/token` del SDK SelphId usando **K6** con monitoreo en tiempo real via **Netdata**.

## 📋 Tabla de Contenido

- [Estructura de Directorios](#estructura-de-directorios)
- [K6 + Netdata - Stack Principal](#k6--netdata---stack-principal)
- [Instalación y Configuración](#instalación-y-configuración)
- [Ejecución de Pruebas](#ejecución-de-pruebas)
- [Monitoreo en Tiempo Real](#monitoreo-en-tiempo-real)
- [Análisis de Resultados](#análisis-de-resultados)
- [Troubleshooting](#troubleshooting)
- [Migración desde JMeter](#migración-desde-jmeter)

## Estructura de Directorios

```
load-tests/
├── k6/                  # Scripts de prueba K6 (.js)
├── scripts/             # Scripts de automatización y configuración
├── monitoring/          # Configuración Netdata y dashboards
├── results/             # Resultados de las pruebas
├── data/                # Datos de prueba (payload.json)
└── README.md            # Esta documentación
```

## K6 + Netdata - Stack Principal

### 🚀 K6 Load Testing

**K6** es una herramienta moderna de load testing que ofrece:
- Scripts en JavaScript más legibles y mantenibles
- Mejor rendimiento y menor consumo de recursos
- Métricas detalladas y umbrales configurables
- Integración nativa con sistemas de monitoreo
- Resultados en múltiples formatos (JSON, HTML, CSV)

### 📊 Netdata Monitoring

**Netdata** proporciona monitoreo en tiempo real con:
- Dashboards interactivos con métricas del sistema
- Visualización en tiempo real durante las pruebas
- Detección automática de servicios y aplicaciones
- Configuración optimizada para load testing
- Alertas y notificaciones automáticas

### 🔄 Ventajas del Stack K6 + Netdata

- **Rendimiento**: K6 consume menos recursos que JMeter
- **Observabilidad**: Monitoreo completo del sistema durante pruebas
- **Automatización**: Scripts completamente automatizados
- **Reportes**: Generación automática de reportes HTML y JSON
- **Escalabilidad**: Mejor manejo de alta concurrencia
- **DevOps Ready**: Integración fácil en pipelines CI/CD

## Instalación y Configuración

### 🛠️ Instalación Automática

```bash
cd scripts
./setup-netdata.sh
```

Este script automáticamente:
- Instala K6 y Netdata
- Configura Netdata para load testing
- Crea dashboards personalizados
- Inicia los servicios necesarios

### 📦 Instalación Manual

#### K6 Installation:
```bash
# macOS
brew install k6

# Ubuntu/Debian
sudo apt-get install k6

# Windows
choco install k6
```

#### Netdata Installation:
```bash
# Instalación automática (Linux/macOS)
bash <(curl -Ss https://my-netdata.io/kickstart.sh)

# macOS con Homebrew
brew install netdata
```

### ⚙️ Configuración

La configuración de Netdata está optimizada en `monitoring/netdata.conf` para:
- Intervalo de actualización de 1 segundo
- Retención de datos extendida para pruebas
- Monitoreo detallado de procesos Java
- Métricas de red y I/O optimizadas

## Ejecución de Pruebas

### 🎯 Ejecución Integrada (Recomendado)

```bash
cd scripts
./integrated-load-test.sh [TPS] [DURATION] [HOST] [PORT]

# Ejemplos:
./integrated-load-test.sh 4 5m              # 4 TPS por 5 minutos
./integrated-load-test.sh 6 10m localhost 8080  # 6 TPS por 10 minutos
```

Este script ejecuta automáticamente:
1. ✅ Verificación de prerrequisitos
2. 🚀 Inicio de monitoreo Netdata
3. 📊 Ejecución de prueba K6
4. 📈 Generación de reportes
5. 🌐 Apertura de resultados en navegador

### ⚡ Ejecución Individual K6

```bash
cd scripts
./run-k6-tests.sh [TPS] [DURATION] [HOST] [PORT]

# Ejemplos:
./run-k6-tests.sh 4 5m          # 4 TPS por 5 minutos
./run-k6-tests.sh 8 2m localhost 8080  # 8 TPS por 2 minutos
```

### 🔧 Configuración Avanzada

Puedes personalizar las pruebas usando variables de entorno:

```bash
# Configuración personalizada
export SERVER_HOST="production-server.com"
export SERVER_PORT="443"
export TPS="10"
export DURATION="15m"
export TOKEN_IMAGE="$(cat image.b64)"

k6 run k6/passive-liveness-load-test.js
```

### 📄 Preparación de Datos

1. **Configurar Payload JSON:**
   ```bash
   # Editar data/payload.json
   {
     "tokenImage": "TU_IMAGEN_BASE64_AQUI",
     "extraData": "load-test-request"
   }
   ```

2. **Verificar Servidor:**
   ```bash
   curl -X GET http://localhost:8080/api/v1/selphid/health
   ```

## Monitoreo en Tiempo Real

### 📊 Dashboards Disponibles

1. **Dashboard Principal Netdata:**
   ```
   http://localhost:19999
   ```

2. **Dashboard Load Testing Personalizado:**
   ```
   monitoring/dashboards/load-test-overview.html
   ```

### 📈 Métricas Clave a Monitorear

#### Durante la Ejecución:
- **CPU Usage**: Debe mantenerse bajo 80%
- **Memory Usage**: Monitorear crecimiento
- **Network Traffic**: Validar patrones de tráfico
- **TCP Connections**: Verificar conexiones activas
- **Disk I/O**: Identificar posibles cuellos de botella

#### Métricas K6 en Tiempo Real:
- **TPS Real**: Transacciones por segundo logradas
- **Response Time**: Percentiles 90, 95, 99
- **Error Rate**: Tasa de errores en tiempo real
- **Active VUs**: Usuarios virtuales activos

### 🚨 Alertas Automáticas

Netdata está configurado para alertar cuando:
- CPU > 85% por más de 2 minutos
- Memoria > 90% del total disponible
- Error rate > 5% en K6
- Response time P95 > 5 segundos

### 📊 Visualización de Resultados

Los scripts generan automáticamente:
- **HTML Reports**: Reportes visuales interactivos
- **JSON Data**: Datos raw para análisis posterior
- **CSV Exports**: Para análisis en hojas de cálculo
- **Sistema Metrics**: Logs de monitoreo del sistema

## Análisis de Resultados

### 📊 Tipos de Reportes Generados

#### 1. K6 HTML Reports
- Gráficos interactivos de rendimiento
- Análisis de percentiles y distribuciones
- Timeline de métricas durante la prueba
- Comparación con umbrales definidos

#### 2. Netdata Historical Data
- Métricas del sistema durante toda la prueba
- Correlación entre carga y uso de recursos
- Identificación de patrones y anomalías
- Análisis de tendencias a largo plazo

#### 3. Reportes Integrados
- Sesión completa con ID único
- Correlación entre métricas K6 y sistema
- Resumen ejecutivo automático
- Links a todos los recursos generados

### 🎯 Umbrales y KPIs

| Métrica | Target | Warning | Critical | Acción |
|---------|---------|---------|----------|--------|
| **Response Time P95** | < 2000ms | < 3000ms | > 5000ms | Optimizar backend |
| **Error Rate** | < 0.1% | < 1% | > 5% | Revisar logs |
| **CPU Usage** | < 60% | < 80% | > 90% | Escalar recursos |
| **Memory Usage** | < 70% | < 85% | > 95% | Aumentar RAM |
| **TPS Achievement** | > 95% | > 85% | < 75% | Revisar limitaciones |

### 📈 Análisis de Tendencias

```bash
# Comparar múltiples ejecuciones
ls results/ | grep "test_.*_report.html"

# Extraer métricas clave de JSON
jq '.metrics.http_req_duration.values.avg' results/k6-*-summary.json

# Análisis de correlación sistema vs rendimiento
python3 scripts/analyze-correlation.py results/
```

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

## Migración desde JMeter

### 🔄 Equivalencias de Configuración

| JMeter | K6 | Descripción |
|--------|----|-----------|
| Thread Group | `options.stages` | Configuración de usuarios concurrentes |
| Ramp-up Period | `duration` en stages | Tiempo de incremento gradual |
| Loop Count | Loop en `default()` | Repeticiones por usuario |
| Timer | `sleep()` | Pausa entre requests |
| Assertions | `check()` | Validaciones de respuesta |
| Listeners | `handleSummary()` | Reportes y métricas |

### 📋 Mapeo de Funcionalidades

#### Configuración JMeter → K6:
```javascript
// JMeter: 5 threads, 5s ramp-up, 300s duration
// K6 equivalent:
export let options = {
  stages: [
    { duration: '5s', target: 5 },   // ramp-up
    { duration: '300s', target: 5 }, // sustain
    { duration: '5s', target: 0 }    // ramp-down
  ]
};
```

### 🚀 Estrategia de Migración

1. **Prueba de Validación:**
   ```bash
   ./integrated-load-test.sh 1 1m  # Validar funcionalidad básica
   ```

2. **Migración Gradual:**
   ```bash
   # Baseline (equivalente a 4 TPS JMeter)
   ./integrated-load-test.sh 4 5m
   
   # Target load (equivalente a 5 TPS JMeter) 
   ./integrated-load-test.sh 5 5m
   
   # Stress test (equivalente a 6 TPS JMeter)
   ./integrated-load-test.sh 6 5m
   ```

3. **Comparación de Resultados:**
   - Tiempo de respuesta promedio
   - Percentiles 95 y 99
   - Tasa de errores
   - Uso de recursos del sistema

### ✅ Ventajas de la Migración

- **50% menos consumo de CPU** en K6 vs JMeter
- **Monitoreo en tiempo real** con Netdata
- **Scripts más legibles** en JavaScript
- **Mejor integración CI/CD** con K6
- **Reportes más ricos** y interactivos
- **Automatización completa** del flujo de testing