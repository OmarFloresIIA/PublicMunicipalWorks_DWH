# Ejecuta los dos cambios del Ejercicio 8 en la base PostgreSQL local del compose.
# Guardar dentro de scripts/ y ejecutar desde cualquier carpeta:
#   powershell -ExecutionPolicy Bypass -File .\scripts\ejecutar-cambios-ejercicio8.ps1
# Requiere Docker Desktop iniciado y el repo actualizado a la rama TestDefinitivo.
# IMPORTANTE: actúa sobre la base local del compose, no sobre un servidor remoto.
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ComposeFile = Join-Path $RepoRoot 'docker\compose.yml'
$DbService = 'db'
$DbName = 'obras_publicas'
$DbUser = 'obras'

if (-not (Test-Path $ComposeFile)) {
    throw "No encontré docker/compose.yml en $RepoRoot. Coloca este archivo en la carpeta scripts/ del repositorio."
}

Write-Host ''
Write-Host 'Ejercicio 8: cambios de esquema para Issues #11 y #16' -ForegroundColor Cyan
Write-Host "Repositorio local: $RepoRoot"
Write-Host 'Base: obras_publicas (servicio PostgreSQL local de docker compose)'
Write-Host ''
Write-Host 'Este proceso modificará la base local y agregará datos sintéticos DEMO.' -ForegroundColor Yellow
Write-Host 'Haz un respaldo antes de continuar si tu base local contiene información que quieras conservar.' -ForegroundColor Yellow
$confirm = Read-Host 'Escribe APLICAR para continuar'
if ($confirm -cne 'APLICAR') {
    Write-Host 'Cancelado; no se aplicaron cambios.' -ForegroundColor Yellow
    exit 0
}

function Invoke-Compose {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    & docker compose -f $ComposeFile @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Falló docker compose $($Arguments -join ' ') (código $LASTEXITCODE). No ejecutes más pasos hasta revisar el error."
    }
}

function Invoke-SqlFile {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$ContainerFileName,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $localPath = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path $localPath)) {
        throw "No existe el archivo requerido: $localPath. Actualiza la rama TestDefinitivo y vuelve a intentarlo."
    }

    $containerPath = "/tmp/$ContainerFileName"
    Write-Host ''
    Write-Host "==> $Label" -ForegroundColor Cyan
    Invoke-Compose -Arguments @('cp', $localPath, "$($DbService):$containerPath")
    Invoke-Compose -Arguments @('exec', '-T', $DbService, 'psql', '-U', $DbUser, '-d', $DbName, '-v', 'ON_ERROR_STOP=1', '-f', $containerPath)
}

# Verificar Docker y arrancar solo el servicio de base de datos.
& docker --version
if ($LASTEXITCODE -ne 0) {
    throw 'Docker no está disponible. Abre/instala Docker Desktop y vuelve a ejecutar este script.'
}
Invoke-Compose -Arguments @('up', '-d', $DbService)

# Esperar a que PostgreSQL acepte conexiones.
$ready = $false
for ($i = 1; $i -le 30; $i++) {
    & docker compose -f $ComposeFile exec -T $DbService pg_isready -U $DbUser -d $DbName *> $null
    if ($LASTEXITCODE -eq 0) {
        $ready = $true
        break
    }
    Start-Sleep -Seconds 2
}
if (-not $ready) {
    throw 'PostgreSQL no estuvo listo en 60 segundos. Revisa: docker compose -f docker/compose.yml logs db'
}

# Crear respaldo local antes de cambiar el esquema.
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupName = "backup-antes-ejercicio8-$timestamp.sql"
$backupLocalPath = Join-Path $RepoRoot $backupName
$backupContainerPath = '/tmp/backup-antes-ejercicio8.sql'
Write-Host ''
Write-Host "==> Creando respaldo: $backupName" -ForegroundColor Cyan
Invoke-Compose -Arguments @('exec', '-T', $DbService, 'pg_dump', '-U', $DbUser, '-d', $DbName, '-f', $backupContainerPath)
Invoke-Compose -Arguments @('cp', "$($DbService):$backupContainerPath", $backupLocalPath)
Write-Host "Respaldo guardado en: $backupLocalPath" -ForegroundColor Green

# Issue #11: agrupar propuestas por tema y detectar propuestas similares.
Invoke-SqlFile 'db\cambio-usuario.sql' 'e8-issue11-schema.sql' 'Issue #11 - aplicar cambio de esquema'
Invoke-SqlFile 'db\diagramas\datos-demo-ejercicio8.sql' 'e8-issue11-demo.sql' 'Issue #11 - insertar datos de prueba marcados DEMO'
Invoke-SqlFile 'db\diagramas\consulta-ejercicio8.sql' 'e8-issue11-query.sql' 'Issue #11 - ejecutar consulta de resultados'

# Issue #16: guardar ubicación real y detectar evidencia fuera del rango.
Invoke-SqlFile 'db\diagramas\issue16\cambio-usuario.sql' 'e8-issue16-schema.sql' 'Issue #16 - aplicar cambio de esquema'
Invoke-SqlFile 'db\diagramas\issue16\datos-demo-ubicacion-ia.sql' 'e8-issue16-demo.sql' 'Issue #16 - insertar datos de prueba marcados DEMO'
Invoke-SqlFile 'db\diagramas\issue16\consulta-ubicacion-ia.sql' 'e8-issue16-query.sql' 'Issue #16 - ejecutar consulta de resultados'

Write-Host ''
Write-Host 'Terminó la secuencia sin errores reportados por psql.' -ForegroundColor Green
Write-Host 'Las filas DEMO son sintéticas: sirven para probar el esquema y no representan inferencias reales de modelos entrenados.'
Write-Host 'Toma capturas de las salidas de ambas consultas para adjuntarlas a los issues.'
Write-Host ''
