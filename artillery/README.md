# Artillery Load Tests

Este directorio contiene pruebas de carga para el SDK Facephi SelphID utilizando Artillery. Los tests están diseñados para evaluar el rendimiento del endpoint de Passive Liveness bajo diferentes cargas de trabajo, permitiendo identificar límites de capacidad y comportamiento del sistema en condiciones de estrés.

## Tabla de Contenido

- [Instalación](#instalación)
- [Uso](#uso)
- [Configuración](#configuración)
- [Requisitos](#requisitos)
- [Monitoreo](#monitoreo)
  - [NetData con Docker Compose](#netdata-con-docker-compose)
  - [Exportar Datos de NetData](#exportar-datos-de-netdata)

## Instalación

```bash
npm install -g artillery
```

## Uso

### Test por defecto (5 TPS)
```bash
artillery run load-tests/artillery/load-test.yml
```

### Test local (4 TPS)
```bash
artillery run -e local load-tests/artillery/load-test.yml
```

### Test de estrés (6 TPS)
```bash
artillery run -e stress load-tests/artillery/load-test.yml
```

## Configuración

### Fases del test:
- **30s**: Ramp up (inicio gradual)
- **30s**: Incremento al TPS objetivo
- **5min**: Mantenimiento del TPS
- **30s**: Ramp down (finalización gradual)

### Variables de entorno:
- `local`: 4 TPS por 4 minutos
- `stress`: 6 TPS por 5 minutos
- Por defecto: 5 TPS por 5 minutos

## Requisitos

1. Servidor corriendo en `localhost:8080`
2. Reemplazar `"BASE64_ENCODED_IMAGE_HERE"` con imagen real en base64
3. Endpoint disponible: `/api/v1/selphid/passive-liveness/evaluate/token`

## Monitoreo

### NetData con Docker Compose

NetData es un sistema de monitoreo en tiempo real de código abierto. Se incluye un `docker-compose.yml` en este directorio para facilitar su instalación.

#### Instalación y Uso

1. **Iniciar NetData:**
   ```bash
   docker-compose up -d
   ```

2. **Acceder al dashboard:**
   - URL: `http://localhost:19999`

3. **Detener NetData:**
   ```bash
   docker-compose down
   ```

#### Flujo de trabajo recomendado

1. Iniciar NetData: `docker-compose up -d`
2. Ejecutar load tests: `artillery run load-test.yml`
3. Monitorear métricas en tiempo real: `http://localhost:19999`
4. Detener NetData: `docker-compose down`

#### Métricas clave a monitorear

Durante los load tests, observar:
- **CPU**: Uso del procesador
- **Memoria**: RAM y swap
- **Red**: I/O de red, conexiones
- **Disco**: I/O de disco
- **Procesos**: Aplicaciones en ejecución

### Exportar Datos de NetData

NetData permite exportar y descargar datos históricos de varias formas:

#### 1. Exportar datos via API

```bash
# Exportar datos de los últimos 5 minutos
curl "http://localhost:19999/api/v1/data?chart=system.cpu&after=-300" > cpu_data.json

# Exportar métricas de memoria
curl "http://localhost:19999/api/v1/data?chart=system.ram&after=-300" > memory_data.json
```

#### 2. Exportar en formato CSV

```bash
curl "http://localhost:19999/api/v1/data?chart=system.cpu&format=csv&after=-300" > cpu_data.csv
```

#### 3. Desde la interfaz web

- Ve a `http://localhost:19999`
- Selecciona el gráfico que quieres
- Click derecho → "Save image" o usa el botón de export
- Puedes ajustar el rango temporal (últimos 5 min, 10 min, etc.)

#### 4. Configurar retención de datos

En el docker-compose, los datos se guardan en volúmenes persistentes:
- `netdatalib:/var/lib/netdata` - Datos históricos
- `netdatacache:/var/cache/netdata` - Cache

#### Parámetros útiles para la API

- `after=-300` = últimos 5 minutos
- `after=-600` = últimos 10 minutos  
- `format=csv` o `format=json`
