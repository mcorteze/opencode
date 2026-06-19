$DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PERFILES_FILE = "$DIR\perfiles.json"
$ENV_FILE      = "$DIR\.env"
$AUTH_FILE     = "$env:USERPROFILE\.local\share\opencode\auth.json"
$CONFIG_FILE   = "$env:USERPROFILE\.config\opencode\config.json"

# --- Agregar PATH de npm global (necesario en Windows si no esta en PATH del sistema) ---
$npmGlobal = "$env:APPDATA\npm"
if ($env:PATH -notlike "*$npmGlobal*") {
    $env:PATH = "$npmGlobal;$env:PATH"
}

# --- Leer .env y devolver valor de una variable ---
function Leer-Env {
    param($clave)
    if (-not (Test-Path $ENV_FILE)) { return "" }
    $linea = Get-Content $ENV_FILE | Where-Object { $_ -match "^\s*$clave\s*=" } | Select-Object -First 1
    if ($linea) {
        return ($linea -split "=", 2)[1].Trim()
    }
    return ""
}

# --- Verificar e instalar opencode si falta ---
function Verificar-Opencode {
    $ok = $null
    try { $ok = & opencode --version 2>$null } catch {}
    if (-not $ok) {
        Write-Host ""
        Write-Host "OpenCode no esta instalado. Instalando..." -ForegroundColor Yellow
        npm install -g opencode-ai
        # Reintentar
        try { $ok = & opencode --version 2>$null } catch {}
        if (-not $ok) {
            Write-Host ""
            Write-Host "ERROR: no se pudo instalar opencode-ai." -ForegroundColor Red
            Write-Host "Verifica que Node.js este instalado: https://nodejs.org" -ForegroundColor Red
            Write-Host "Si Node ya esta instalado, cierra y vuelve a abrir la terminal e intenta de nuevo." -ForegroundColor Yellow
            pause
            exit
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

# --- Cargar perfiles (y enriquecer con .env si los campos estan vacios) ---
function Leer-Perfiles {
    if (-not (Test-Path $PERFILES_FILE)) {
        Write-Host "No se encontro perfiles.json en $DIR" -ForegroundColor Red
        pause
        exit
    }
    $datos = (Get-Content $PERFILES_FILE -Raw | ConvertFrom-Json).perfiles

    # Si solo hay un perfil y todos sus campos estan vacios, intentar poblar desde .env
    $groqEnv       = Leer-Env "GROQ_API_KEY"
    $openrouterEnv = Leer-Env "OPENROUTER_API_KEY"
    $anthropicEnv  = Leer-Env "ANTHROPIC_API_KEY"
    $openaiEnv     = Leer-Env "OPENAI_API_KEY"

    foreach ($p in $datos) {
        if (-not $p.groq       -and $groqEnv)       { $p.groq       = $groqEnv }
        if (-not $p.openrouter -and $openrouterEnv) { $p.openrouter = $openrouterEnv }
        if (-not $p.anthropic  -and $anthropicEnv)  { $p.anthropic  = $anthropicEnv }
        if (-not $p.openai     -and $openaiEnv)     { $p.openai     = $openaiEnv }
    }

    return $datos
}

function Mostrar-Menu {
    param($perfiles, $activo)
    Clear-Host
    Write-Host "============================================"
    Write-Host "   OpenCode - Menu principal"
    Write-Host "============================================"
    Write-Host ""
    Write-Host "  PERFIL ACTIVO: " -NoNewline
    if ($activo) {
        Write-Host $activo -ForegroundColor Green
    } else {
        Write-Host "ninguno" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  1. Abrir OpenCode con perfil activo"
    Write-Host "  2. Cambiar perfil"
    Write-Host "  3. Elegir modelo segun tarea"
    Write-Host "  4. Ver modelos disponibles"
    Write-Host "  5. Ver perfil activo"
    Write-Host "  6. Salir"
    Write-Host ""
}

function Activar-Perfil {
    param($perfil)
    Crear-Dirs

    # --- auth.json: keys por proveedor ---
    $auth = @{}
    if ($perfil.groq       -and $perfil.groq -ne "")       { $auth["groq"]       = @{ api_key = $perfil.groq } }
    if ($perfil.openrouter -and $perfil.openrouter -ne "") { $auth["openrouter"] = @{ api_key = $perfil.openrouter } }
    if ($perfil.anthropic  -and $perfil.anthropic -ne "")  { $auth["anthropic"]  = @{ api_key = $perfil.anthropic } }
    if ($perfil.openai     -and $perfil.openai -ne "")     { $auth["openai"]     = @{ api_key = $perfil.openai } }
    $auth | ConvertTo-Json -Depth 3 | Set-Content $AUTH_FILE -Encoding UTF8

    # --- config.json: elegir proveedor y modelo por defecto segun lo disponible ---
    $proveedor = ""
    $modelo    = ""
    if ($perfil.groq -and $perfil.groq -ne "") {
        $proveedor = "groq"
        $modelo    = "groq/llama-3.3-70b-versatile"
    } elseif ($perfil.openrouter -and $perfil.openrouter -ne "") {
        $proveedor = "openrouter"
        $modelo    = "openrouter/meta-llama/llama-3.3-70b-instruct:free"
    } elseif ($perfil.anthropic -and $perfil.anthropic -ne "") {
        $proveedor = "anthropic"
        $modelo    = "anthropic/claude-sonnet-4-6"
    } elseif ($perfil.openai -and $perfil.openai -ne "") {
        $proveedor = "openai"
        $modelo    = "openai/gpt-4o-mini"
    }

    $config = @{
        model = $modelo
    }
    $config | ConvertTo-Json -Depth 3 | Set-Content $CONFIG_FILE -Encoding UTF8

    Write-Host ""
    Write-Host "Perfil '$($perfil.nombre)' activado. Proveedor: $proveedor / Modelo: $modelo" -ForegroundColor Green
    Start-Sleep -Milliseconds 900
}

function Menu-Perfiles {
    param($perfiles)
    Clear-Host
    Write-Host "============================================"
    Write-Host "   Seleccionar perfil"
    Write-Host "============================================"
    Write-Host ""
    for ($i = 0; $i -lt $perfiles.Count; $i++) {
        $p    = $perfiles[$i]
        $g    = if ($p.groq       -and $p.groq -ne "")       { "[Groq OK]"       } else { "[Groq -]" }
        $or   = if ($p.openrouter -and $p.openrouter -ne "") { "[OpenRouter OK]" } else { "[OpenRouter -]" }
        $ant  = if ($p.anthropic  -and $p.anthropic -ne "")  { "[Claude OK]"     } else { "[Claude -]" }
        $oai  = if ($p.openai     -and $p.openai -ne "")     { "[OpenAI OK]"     } else { "[OpenAI -]" }
        Write-Host "  $($i + 1). $($p.nombre)  $g $or $ant $oai"
    }
    Write-Host ""
    $sel = Read-Host "Elige perfil (1-$($perfiles.Count))"
    $idx = [int]$sel - 1
    if ($idx -ge 0 -and $idx -lt $perfiles.Count) {
        Activar-Perfil $perfiles[$idx]
        return $perfiles[$idx].nombre
    } else {
        Write-Host "Opcion invalida." -ForegroundColor Red
        Start-Sleep -Milliseconds 800
        return $null
    }
}

function Ver-Modelos {
    Clear-Host
    Write-Host "============================================"
    Write-Host "   Modelos disponibles"
    Write-Host "============================================"
    Write-Host ""
    Write-Host "  GROQ (gratis, 14,400 req/dia — sin tarjeta)" -ForegroundColor Cyan
    Write-Host "  groq/llama-3.3-70b-versatile     recomendado"
    Write-Host "  groq/llama-3.1-8b-instant        mas rapido"
    Write-Host "  groq/mixtral-8x7b-32768          contexto largo"
    Write-Host ""
    Write-Host "  OPENROUTER (modelos gratis con cuenta Google/GitHub)" -ForegroundColor Cyan
    Write-Host "  openrouter/meta-llama/llama-3.3-70b-instruct:free"
    Write-Host "  openrouter/mistralai/mistral-small-3.2-24b:free  codigo, equilibrado"
    Write-Host "  openrouter/mistralai/mistral-7b-instruct:free"
    Write-Host "  openrouter/deepseek/deepseek-chat-v3-0324:free   chino, muy capaz"
    Write-Host "  openrouter/tngtech/deepseek-r1t-chimera:free      razonamiento + rapidez"
    Write-Host "  openrouter/qwen/qwen3-235b-a22b:free             chino, bueno para codigo"
    Write-Host "  openrouter/google/gemini-2.0-flash-exp:free      velocidad + multimodal"
    Write-Host "  openrouter/google/gemma-3-27b-it:free            instrucciones precisas"
    Write-Host "  openrouter/microsoft/phi-4-reasoning:free        razonamiento paso a paso"
    Write-Host ""
    Write-Host "  ANTHROPIC / CLAUDE (pago)" -ForegroundColor Cyan
    Write-Host "  anthropic/claude-sonnet-4-6      recomendado"
    Write-Host "  anthropic/claude-haiku-4-5-20251001  economico"
    Write-Host ""
    Write-Host "  OPENAI / CHATGPT (pago)" -ForegroundColor Cyan
    Write-Host "  openai/gpt-4o-mini               economico"
    Write-Host "  openai/gpt-4o                    potente"
    Write-Host ""
    Write-Host "  Para cambiar modelo edita: $CONFIG_FILE"
    Write-Host ""
    Read-Host "Presiona Enter para volver"
}

function Elegir-Por-Tarea {
    $tareas = @(
        @{ desc = "Skill con flujo claro (mecanico)";      modelo = "groq/llama-3.3-70b-versatile" },
        @{ desc = "Expandir estilos a otras pages";        modelo = "groq/llama-3.3-70b-versatile" },
        @{ desc = "Refactor simple / renombrar / mover";   modelo = "groq/llama-3.1-8b-instant" },
        @{ desc = "Respuesta rapida / consulta puntual";   modelo = "groq/llama-3.1-8b-instant" },
        @{ desc = "Redisenar page con criterio propio";    modelo = "openrouter/deepseek/deepseek-chat-v3-0324:free" },
        @{ desc = "Arquitectura / decidir estructura";     modelo = "openrouter/deepseek/deepseek-chat-v3-0324:free" },
        @{ desc = "Debuggear algo raro / logica compleja"; modelo = "openrouter/qwen/qwen3-235b-a22b:free" },
        @{ desc = "Razonamiento paso a paso";              modelo = "openrouter/microsoft/phi-4-reasoning:free" },
        @{ desc = "Tarea rapida multimodal (imagen+texto)";modelo = "openrouter/google/gemini-2.0-flash-exp:free" }
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
        $config = @{ model = $modelo }
        $config | ConvertTo-Json -Depth 3 | Set-Content $CONFIG_FILE -Encoding UTF8

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
            if ($post -eq "1") {
                # continua el while con misma tarea y modelo
            } elseif ($post -eq "2") {
                Elegir-Por-Tarea
                return
            } else {
                return
            }
        }
    } else {
        Write-Host "Opcion invalida." -ForegroundColor Red
        Start-Sleep -Milliseconds 800
    }
}

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
            @{ nombre = "OpenAI";     prop = "openai" }
        )
        foreach ($c in $campos) {
            $val = $auth.($c.prop)
            if ($val -and $val.api_key) {
                $k = $val.api_key
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

# ===== INICIO =====
Verificar-Opencode

$perfiles    = Leer-Perfiles
$perfilActivo = $null

if (Test-Path $AUTH_FILE) {
    $authActual = Get-Content $AUTH_FILE -Raw | ConvertFrom-Json
    foreach ($p in $perfiles) {
        if ($p.groq -and $authActual.groq -and $p.groq -eq $authActual.groq.api_key) {
            $perfilActivo = $p.nombre
            break
        }
        if ($p.openrouter -and $authActual.openrouter -and $p.openrouter -eq $authActual.openrouter.api_key) {
            $perfilActivo = $p.nombre
            break
        }
    }
}

while ($true) {
    Mostrar-Menu $perfiles $perfilActivo
    $op = Read-Host "Elige una opcion (1-6)"

    switch ($op) {
        "1" {
            if (-not $perfilActivo) {
                Write-Host ""
                Write-Host "Primero selecciona un perfil (opcion 2)." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            } else {
                while ($true) {
                    Clear-Host
                    Write-Host "Abriendo OpenCode con perfil '$perfilActivo'..."
                    Write-Host "(Para salir escribe /exit)"
                    Write-Host ""
                    & opencode
                    Clear-Host
                    Write-Host "============================================"
                    Write-Host "   Sesion terminada"
                    Write-Host "============================================"
                    Write-Host ""
                    if (Test-Path $CONFIG_FILE) {
                        $cfg = Get-Content $CONFIG_FILE -Raw | ConvertFrom-Json
                        Write-Host "  Modelo actual: $($cfg.model)" -ForegroundColor Yellow
                    }
                    Write-Host ""
                    Write-Host "  1. Continuar con el mismo modelo"
                    Write-Host "  2. Cambiar tipo de tarea (y modelo)"
                    Write-Host "  3. Volver al menu principal"
                    Write-Host ""
                    $post = Read-Host "Que deseas hacer?"
                    if ($post -eq "1") {
                        # vuelve al inicio del while, reabre opencode con mismo modelo
                    } elseif ($post -eq "2") {
                        Elegir-Por-Tarea
                    } else {
                        break
                    }
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
        "6" { exit }
        default {
            Write-Host "Opcion invalida." -ForegroundColor Red
            Start-Sleep -Milliseconds 500
        }
    }
}
