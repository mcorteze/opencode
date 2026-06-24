$DIR             = Split-Path -Parent $MyInvocation.MyCommand.Path
$PERFILES_FILE   = "$DIR\perfiles.json"
$ENV_FILE        = "$DIR\.env"
$AUTH_FILE       = "$env:USERPROFILE\.local\share\opencode\auth.json"
$CONFIG_FILE     = "$env:USERPROFILE\.config\opencode\config.json"
$CLAUDE_SETTINGS = "$env:USERPROFILE\.claude\settings.json"

# --- Agregar PATH de npm global ---
$npmGlobal = "$env:APPDATA\npm"
if ($env:PATH -notlike "*$npmGlobal*") { $env:PATH = "$npmGlobal;$env:PATH" }

# --- Leer una variable del .env ---
function Leer-Env {
    param($clave)
    if (-not (Test-Path $ENV_FILE)) { return "" }
    $linea = Get-Content $ENV_FILE | Where-Object { $_ -match "^\s*$clave\s*=" } | Select-Object -First 1
    if ($linea) { return ($linea -split "=", 2)[1].Trim() }
    return ""
}

# --- Convertir nombre de perfil a sufijo de variable .env ---
# "Gmail 1" -> "GMAIL1", "Mi Trabajo" -> "MITRABAJO"
function Nombre-A-Sufijo {
    param($nombre)
    return ($nombre.ToUpper() -replace '\s+', '')
}

# --- Leer todas las keys de un perfil desde .env ---
function Leer-Keys-Perfil {
    param($nombrePerfil)
    $s = Nombre-A-Sufijo $nombrePerfil
    return @{
        groq       = Leer-Env "GROQ_KEY_$s"
        openrouter = Leer-Env "OPENROUTER_KEY_$s"
        anthropic  = Leer-Env "ANTHROPIC_KEY_$s"
        openai     = Leer-Env "OPENAI_KEY_$s"
        gemini     = Leer-Env "GEMINI_KEY_$s"
    }
}

# --- Verificar e instalar opencode si falta ---
function Verificar-Opencode {
    $ok = $null
    try { $ok = & opencode --version 2>$null } catch {}
    if (-not $ok) {
        Write-Host ""
        Write-Host "OpenCode no esta instalado. Instalando..." -ForegroundColor Yellow
        npm install -g opencode-ai
        try { $ok = & opencode --version 2>$null } catch {}
        if (-not $ok) {
            Write-Host "ERROR: no se pudo instalar opencode-ai." -ForegroundColor Red
            Write-Host "Verifica que Node.js este instalado: https://nodejs.org" -ForegroundColor Red
            pause; exit
        }
        Write-Host "OpenCode instalado correctamente." -ForegroundColor Green
    }
}

# --- Crear directorios de config si no existen ---
function Crear-Dirs {
    $authDir   = Split-Path $AUTH_FILE
    $configDir = Split-Path $CONFIG_FILE
    if (-not (Test-Path $authDir))   { New-Item -ItemType Directory -Force $authDir   | Out-Null }
    if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Force $configDir | Out-Null }
}

# --- Cargar lista de perfiles desde perfiles.json ---
function Leer-Perfiles {
    if (-not (Test-Path $PERFILES_FILE)) {
        Write-Host "No se encontro perfiles.json en $DIR" -ForegroundColor Red
        pause; exit
    }
    return (Get-Content $PERFILES_FILE -Raw | ConvertFrom-Json).perfiles
}

# --- Leer modo de permisos activo desde settings.json de Claude Code ---
function Leer-ModoPermisos {
    if (-not (Test-Path $CLAUDE_SETTINGS)) { return "default" }
    $cfg  = Get-Content $CLAUDE_SETTINGS -Raw | ConvertFrom-Json
    $modo = $cfg.permissions.defaultMode
    if ($modo -eq "bypassPermissions") { return "bypassPermissions" }
    $allow = $cfg.permissions.allow
    if ($allow -and $allow.Count -gt 0) { return "acceptEdits" }
    return "default"
}

# --- Menu principal ---
function Mostrar-Menu {
    param($perfiles, $activo)
    Clear-Host
    Write-Host "============================================"
    Write-Host "   OpenCode - Menu principal"
    Write-Host "============================================"
    Write-Host ""
    Write-Host "  PERFIL ACTIVO: " -NoNewline
    if ($activo) { Write-Host $activo -ForegroundColor Green } else { Write-Host "ninguno" -ForegroundColor Yellow }

    if (Test-Path $CONFIG_FILE) {
        $cfg = Get-Content $CONFIG_FILE -Raw | ConvertFrom-Json
        Write-Host "  MODELO ACTIVO:  " -NoNewline
        Write-Host $cfg.model -ForegroundColor Cyan
    }

    $modoActual = Leer-ModoPermisos
    Write-Host "  PERMISOS:       " -NoNewline
    switch ($modoActual) {
        "default"           { Write-Host "default (pide confirmacion para todo)" -ForegroundColor Yellow }
        "acceptEdits"       { Write-Host "acceptEdits (archivos libres, bash protegido)" -ForegroundColor Cyan }
        "bypassPermissions" { Write-Host "bypassPermissions (sin confirmaciones)" -ForegroundColor Red }
    }

    Write-Host ""
    Write-Host "  1. Abrir OpenCode con perfil activo"
    Write-Host "  2. Cambiar perfil"
    Write-Host "  3. Elegir modelo segun tarea"
    Write-Host "  4. Ver modelos disponibles"
    Write-Host "  5. Ver perfil activo"
    Write-Host "  6. Cambiar modo de permisos"
    Write-Host "  7. Salir"
    Write-Host ""
}

# --- Activar un perfil: escribe auth.json y config.json ---
function Activar-Perfil {
    param($nombrePerfil)
    Crear-Dirs

    $keys = Leer-Keys-Perfil $nombrePerfil

    # Verificar que el perfil tiene al menos una key
    $tieneKey = $keys.Values | Where-Object { $_ -ne "" }
    if (-not $tieneKey) {
        Write-Host ""
        Write-Host "  El perfil '$nombrePerfil' no tiene keys en el .env." -ForegroundColor Red
        $sufijo = Nombre-A-Sufijo $nombrePerfil
        Write-Host "  Agrega al menos una de estas variables en el archivo .env:" -ForegroundColor Yellow
        Write-Host "    GROQ_KEY_$sufijo"
        Write-Host "    OPENROUTER_KEY_$sufijo"
        Write-Host "    ANTHROPIC_KEY_$sufijo"
        Write-Host "    OPENAI_KEY_$sufijo"
        Write-Host "    GEMINI_KEY_$sufijo"
        Start-Sleep -Seconds 3
        return $false
    }

    # auth.json
    $auth = @{}
    if ($keys.groq)       { $auth["groq"]       = @{ api_key = $keys.groq } }
    if ($keys.openrouter) { $auth["openrouter"] = @{ api_key = $keys.openrouter } }
    if ($keys.anthropic)  { $auth["anthropic"]  = @{ api_key = $keys.anthropic } }
    if ($keys.openai)     { $auth["openai"]     = @{ api_key = $keys.openai } }
    if ($keys.gemini)     { $auth["google"]     = @{ api_key = $keys.gemini } }
    $auth | ConvertTo-Json -Depth 3 | Set-Content $AUTH_FILE -Encoding UTF8

    # config.json: elegir modelo por prioridad segun keys disponibles
    $modelo = ""
    if     ($keys.groq)       { $modelo = "groq/llama-3.3-70b-versatile" }
    elseif ($keys.openrouter) { $modelo = "openrouter/meta-llama/llama-3.3-70b-instruct:free" }
    elseif ($keys.anthropic)  { $modelo = "anthropic/claude-sonnet-4-6" }
    elseif ($keys.openai)     { $modelo = "openai/gpt-4o-mini" }
    elseif ($keys.gemini)     { $modelo = "google/gemini-2.0-flash" }

    @{ model = $modelo } | ConvertTo-Json -Depth 3 | Set-Content $CONFIG_FILE -Encoding UTF8

    Write-Host ""
    Write-Host "  Perfil '$nombrePerfil' activado. Modelo: $modelo" -ForegroundColor Green
    Start-Sleep -Milliseconds 900
    return $true
}

# --- Seleccionar perfil ---
function Menu-Perfiles {
    param($perfiles)
    Clear-Host
    Write-Host "============================================"
    Write-Host "   Seleccionar perfil"
    Write-Host "============================================"
    Write-Host ""

    for ($i = 0; $i -lt $perfiles.Count; $i++) {
        $nombre = $perfiles[$i].nombre
        $keys   = Leer-Keys-Perfil $nombre
        $g   = if ($keys.groq)       { "[Groq OK]"       } else { "[Groq -]" }
        $or  = if ($keys.openrouter) { "[OpenRouter OK]" } else { "[OpenRouter -]" }
        $ant = if ($keys.anthropic)  { "[Claude OK]"     } else { "[Claude -]" }
        $oai = if ($keys.openai)     { "[OpenAI OK]"     } else { "[OpenAI -]" }
        $gem = if ($keys.gemini)     { "[Gemini OK]"     } else { "[Gemini -]" }
        Write-Host "  $($i + 1). $nombre  $g $or $ant $oai $gem"
    }

    Write-Host ""
    $sel = Read-Host "Elige perfil (1-$($perfiles.Count))"
    $idx = [int]$sel - 1
    if ($idx -ge 0 -and $idx -lt $perfiles.Count) {
        $ok = Activar-Perfil $perfiles[$idx].nombre
        if ($ok) { return $perfiles[$idx].nombre }
        return $null
    } else {
        Write-Host "Opcion invalida." -ForegroundColor Red
        Start-Sleep -Milliseconds 800
        return $null
    }
}

# --- Ver modelos disponibles ---
function Ver-Modelos {
    Clear-Host
    Write-Host "============================================"
    Write-Host "   Modelos disponibles"
    Write-Host "============================================"
    Write-Host ""
    Write-Host "  GROQ (gratis, 14,400 req/dia)" -ForegroundColor Cyan
    Write-Host "  groq/llama-3.3-70b-versatile       recomendado"
    Write-Host "  groq/llama-3.1-8b-instant          mas rapido"
    Write-Host "  groq/mixtral-8x7b-32768            contexto largo"
    Write-Host ""
    Write-Host "  OPENROUTER (modelos gratis)" -ForegroundColor Cyan
    Write-Host "  openrouter/meta-llama/llama-3.3-70b-instruct:free"
    Write-Host "  openrouter/mistralai/mistral-small-3.2-24b:free"
    Write-Host "  openrouter/deepseek/deepseek-chat-v3-0324:free"
    Write-Host "  openrouter/tngtech/deepseek-r1t-chimera:free"
    Write-Host "  openrouter/qwen/qwen3-235b-a22b:free"
    Write-Host "  openrouter/google/gemini-2.0-flash-exp:free"
    Write-Host "  openrouter/google/gemma-3-27b-it:free"
    Write-Host "  openrouter/microsoft/phi-4-reasoning:free"
    Write-Host ""
    Write-Host "  GOOGLE GEMINI (nivel gratuito disponible)" -ForegroundColor Cyan
    Write-Host "  google/gemini-2.0-flash"
    Write-Host "  google/gemini-1.5-pro"
    Write-Host ""
    Write-Host "  ANTHROPIC / CLAUDE (pago)" -ForegroundColor Cyan
    Write-Host "  anthropic/claude-sonnet-4-6"
    Write-Host "  anthropic/claude-haiku-4-5-20251001"
    Write-Host ""
    Write-Host "  OPENAI (pago)" -ForegroundColor Cyan
    Write-Host "  openai/gpt-4o-mini"
    Write-Host "  openai/gpt-4o"
    Write-Host ""
    Write-Host "  Para cambiar modelo edita: $CONFIG_FILE"
    Write-Host ""
    Read-Host "Presiona Enter para volver"
}

# --- Elegir modelo segun tipo de tarea ---
function Elegir-Por-Tarea {
    $tareas = @(
        @{ desc = "Skill con flujo claro (mecanico)";       modelo = "groq/llama-3.3-70b-versatile" },
        @{ desc = "Expandir estilos a otras pages";         modelo = "groq/llama-3.3-70b-versatile" },
        @{ desc = "Refactor simple / renombrar / mover";    modelo = "groq/llama-3.1-8b-instant" },
        @{ desc = "Respuesta rapida / consulta puntual";    modelo = "groq/llama-3.1-8b-instant" },
        @{ desc = "Redisenar page con criterio propio";     modelo = "openrouter/deepseek/deepseek-chat-v3-0324:free" },
        @{ desc = "Arquitectura / decidir estructura";      modelo = "openrouter/deepseek/deepseek-chat-v3-0324:free" },
        @{ desc = "Debuggear algo raro / logica compleja";  modelo = "openrouter/qwen/qwen3-235b-a22b:free" },
        @{ desc = "Razonamiento paso a paso";               modelo = "openrouter/microsoft/phi-4-reasoning:free" },
        @{ desc = "Tarea multimodal (imagen + texto)";      modelo = "openrouter/google/gemini-2.0-flash-exp:free" }
    )

    Clear-Host
    Write-Host "============================================"
    Write-Host "   Elegir modelo segun tarea"
    Write-Host "============================================"
    Write-Host ""
    for ($i = 0; $i -lt $tareas.Count; $i++) {
        Write-Host "  $($i + 1). $($tareas[$i].desc)"
    }
    Write-Host ""
    $sel = Read-Host "Que quieres hacer? (1-$($tareas.Count))"
    $idx = [int]$sel - 1
    if ($idx -ge 0 -and $idx -lt $tareas.Count) {
        $tareaActual = $tareas[$idx]
        $modelo      = $tareaActual.modelo
        Crear-Dirs
        @{ model = $modelo } | ConvertTo-Json -Depth 3 | Set-Content $CONFIG_FILE -Encoding UTF8

        while ($true) {
            Write-Host ""
            Write-Host "  Tarea:  $($tareaActual.desc)" -ForegroundColor Cyan
            Write-Host "  Modelo: $modelo" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Abriendo OpenCode..." -ForegroundColor Yellow
            Start-Sleep -Milliseconds 800
            Clear-Host
            & opencode
            Clear-Host
            Write-Host "============================================"
            Write-Host "   Sesion terminada"
            Write-Host "============================================"
            Write-Host ""
            Write-Host "  Ultima tarea:  $($tareaActual.desc)" -ForegroundColor Cyan
            Write-Host "  Modelo usado:  $modelo" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  1. Continuar con el mismo modelo"
            Write-Host "  2. Cambiar tipo de tarea (y modelo)"
            Write-Host "  3. Volver al menu principal"
            Write-Host ""
            $post = Read-Host "Que deseas hacer?"
            if ($post -eq "2") { Elegir-Por-Tarea; return }
            elseif ($post -ne "1") { return }
        }
    } else {
        Write-Host "Opcion invalida." -ForegroundColor Red
        Start-Sleep -Milliseconds 800
    }
}

# --- Ver perfil activo ---
function Ver-PerfilActivo {
    Clear-Host
    Write-Host "============================================"
    Write-Host "   Perfil activo"
    Write-Host "============================================"
    Write-Host ""
    if (Test-Path $AUTH_FILE) {
        $auth = Get-Content $AUTH_FILE -Raw | ConvertFrom-Json
        $campos = @(
            @{ nombre = "Groq";       prop = "groq" },
            @{ nombre = "OpenRouter"; prop = "openrouter" },
            @{ nombre = "Claude";     prop = "anthropic" },
            @{ nombre = "OpenAI";     prop = "openai" },
            @{ nombre = "Gemini";     prop = "google" }
        )
        foreach ($c in $campos) {
            $val = $auth.($c.prop)
            if ($val -and $val.api_key) {
                $k       = $val.api_key
                $preview = if ($k.Length -gt 8) { $k.Substring(0, 8) + "..." } else { $k }
                Write-Host "  $($c.nombre):".PadRight(14) -NoNewline
                Write-Host $preview -ForegroundColor Green
            } else {
                Write-Host "  $($c.nombre):".PadRight(14) -NoNewline
                Write-Host "no configurado" -ForegroundColor DarkGray
            }
        }
        if (Test-Path $CONFIG_FILE) {
            $cfg = Get-Content $CONFIG_FILE -Raw | ConvertFrom-Json
            Write-Host ""
            Write-Host "  Modelo activo: $($cfg.model)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  No hay perfil activo aun." -ForegroundColor Yellow
    }
    Write-Host ""
    Read-Host "Presiona Enter para volver"
}

# --- Cambiar modo de permisos de Claude Code ---
function Cambiar-ModoPermisos {
    Clear-Host
    Write-Host "============================================"
    Write-Host "   Modo de permisos de Claude Code"
    Write-Host "============================================"
    Write-Host ""
    $modoActual = Leer-ModoPermisos
    Write-Host "  Modo actual: " -NoNewline
    switch ($modoActual) {
        "default"           { Write-Host "default" -ForegroundColor Yellow }
        "acceptEdits"       { Write-Host "acceptEdits" -ForegroundColor Cyan }
        "bypassPermissions" { Write-Host "bypassPermissions" -ForegroundColor Red }
    }
    Write-Host ""
    Write-Host "  1. default          - Pide confirmacion antes de cada accion."
    Write-Host "                        Maximo control, mas interrupciones."
    Write-Host ""
    Write-Host "  2. acceptEdits      - Leer y escribir archivos sin pedir confirmacion."
    Write-Host "                        Comandos de terminal peligrosos siguen pidiendo OK."
    Write-Host ""
    Write-Host "  3. bypassPermissions - Nunca aparece ninguna ventana de confirmacion."
    Write-Host "                         Claude Code ejecuta todo directamente."
    Write-Host ""
    Write-Host "  4. Volver sin cambiar"
    Write-Host ""
    $sel = Read-Host "Elige modo (1-4)"

    $nuevoJson = $null
    $msg       = ""
    $color     = "White"
    switch ($sel) {
        "1" {
            $nuevoJson = '{ "permissions": {} }'
            $msg   = "Modo cambiado a: default"
            $color = "Yellow"
        }
        "2" {
            $nuevoJson = '{
  "permissions": {
    "allow": [
      "Read", "Write", "Edit", "Glob", "Grep",
      "Bash(git status)", "Bash(git diff *)", "Bash(git log *)",
      "Bash(git add *)", "Bash(git commit *)",
      "Bash(node *)", "Bash(npm *)", "Bash(npx *)",
      "Bash(ls *)", "Bash(dir *)", "Bash(cat *)",
      "Bash(Get-Content *)", "Bash(Get-ChildItem *)",
      "Bash(Test-Path *)", "Bash(New-Item *)"
    ]
  }
}'
            $msg   = "Modo cambiado a: acceptEdits"
            $color = "Cyan"
        }
        "3" {
            $nuevoJson = '{
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}'
            $msg   = "Modo cambiado a: bypassPermissions (sin confirmaciones)"
            $color = "Red"
        }
        "4" { return }
        default {
            Write-Host "Opcion invalida." -ForegroundColor Red
            Start-Sleep -Milliseconds 800
            return
        }
    }

    if ($nuevoJson) {
        $settingsDir = Split-Path $CLAUDE_SETTINGS
        if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Force $settingsDir | Out-Null }
        $nuevoJson | Set-Content $CLAUDE_SETTINGS -Encoding UTF8
        Write-Host ""
        Write-Host "  $msg" -ForegroundColor $color
        Start-Sleep -Seconds 1
    }
}

# ===== INICIO =====
Verificar-Opencode
$perfiles     = Leer-Perfiles
$perfilActivo = $null

# Detectar perfil activo comparando keys del .env con auth.json
if (Test-Path $AUTH_FILE) {
    $authActual = Get-Content $AUTH_FILE -Raw | ConvertFrom-Json
    foreach ($p in $perfiles) {
        $keys = Leer-Keys-Perfil $p.nombre
        if ($keys.groq       -and $authActual.groq       -and $keys.groq       -eq $authActual.groq.api_key)       { $perfilActivo = $p.nombre; break }
        if ($keys.openrouter -and $authActual.openrouter -and $keys.openrouter -eq $authActual.openrouter.api_key) { $perfilActivo = $p.nombre; break }
        if ($keys.anthropic  -and $authActual.anthropic  -and $keys.anthropic  -eq $authActual.anthropic.api_key)  { $perfilActivo = $p.nombre; break }
        if ($keys.openai     -and $authActual.openai     -and $keys.openai     -eq $authActual.openai.api_key)     { $perfilActivo = $p.nombre; break }
        if ($keys.gemini     -and $authActual.google     -and $keys.gemini     -eq $authActual.google.api_key)     { $perfilActivo = $p.nombre; break }
    }
}

while ($true) {
    Mostrar-Menu $perfiles $perfilActivo
    $op = Read-Host "Elige una opcion (1-7)"

    switch ($op) {
        "1" {
            if (-not $perfilActivo) {
                Write-Host ""
                Write-Host "  Primero selecciona un perfil (opcion 2)." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            } else {
                while ($true) {
                    Clear-Host
                    Write-Host "  Abriendo OpenCode con perfil '$perfilActivo'..."
                    Write-Host ""
                    & opencode
                    Clear-Host
                    Write-Host "============================================"
                    Write-Host "   Sesion terminada"
                    Write-Host "============================================"
                    Write-Host ""
                    if (Test-Path $CONFIG_FILE) {
                        $cfg = Get-Content $CONFIG_FILE -Raw | ConvertFrom-Json
                        Write-Host "  Modelo usado: $($cfg.model)" -ForegroundColor Yellow
                    }
                    Write-Host ""
                    Write-Host "  1. Continuar con el mismo modelo"
                    Write-Host "  2. Cambiar tipo de tarea (y modelo)"
                    Write-Host "  3. Volver al menu principal"
                    Write-Host ""
                    $post = Read-Host "Que deseas hacer?"
                    if ($post -eq "2") { Elegir-Por-Tarea }
                    elseif ($post -ne "1") { break }
                }
            }
        }
        "2" {
            $nuevo = Menu-Perfiles $perfiles
            if ($nuevo) { $perfilActivo = $nuevo }
        }
        "3" { Elegir-Por-Tarea }
        "4" { Ver-Modelos }
        "5" { Ver-PerfilActivo }
        "6" { Cambiar-ModoPermisos }
        "7" { exit }
        default {
            Write-Host "Opcion invalida." -ForegroundColor Red
            Start-Sleep -Milliseconds 500
        }
    }
}
