param(
    [string]$ImageName      = "toru-app",
    [string]$Tag            = "latest",
    [string]$ContainerName  = "toru-app",
    [int]   $HostPort       = 8000,   # Port on your Windows host
    [int]   $ContainerPort  = 8000,   # Port exposed by the app inside the container
    [string]$OllamaHost     = "http://host.docker.internal:11434"  # Where Ollama server is reachable from container
)

$ErrorActionPreference = "Stop"

Write-Host "=== Building image ${ImageName}:${Tag} ==="
docker build -t "${ImageName}:${Tag}" . 

Write-Host "=== Stopping old container (if exists): ${ContainerName} ==="
$existing = docker ps -a --filter "name=${ContainerName}" --format "{{.ID}}"

if ($existing) {
    docker stop  ${ContainerName} 2>$null | Out-Null
    docker rm    ${ContainerName} 2>$null | Out-Null
}

Write-Host "=== Running new container ${ContainerName} on port ${HostPort} -> ${ContainerPort} ==="
docker run -d `
    --name ${ContainerName} `
    -e "OLLAMA_HOST=${OllamaHost}" `
    -p "${HostPort}:${ContainerPort}" `
    "${ImageName}:${Tag}"

Write-Host "=== Done. Container status: ==="
docker ps --filter "name=${ContainerName}"