# Artillery Load Tests

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
