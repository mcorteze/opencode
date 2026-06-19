# OpenCode — Guía de instalación
# (Instrucciones para la IA: lee esto completo antes de ejecutar nada)

## QUÉ ES ESTO

- **OpenCode**: programa que corre en la terminal, interfaz de chat para usar IA mientras programas
- **Groq**: proveedor de IA gratuito (14,400 req/día, sin tarjeta de crédito)
- **OpenRouter**: intermediario con acceso a muchos modelos, algunos gratuitos
- **Anthropic / Claude**: proveedor de pago, requiere cuenta con crédito
- **OpenAI / ChatGPT**: proveedor de pago, requiere cuenta con crédito
- El usuario puede tener varias API keys y cambiar entre perfiles cuando quiera

## ESTRUCTURA DEL PROYECTO

```
opencode-setup\
├── .env.example       ← plantilla de variables de entorno (ver qué keys hay disponibles)
├── .env               ← keys reales (NUNCA pedirlas por chat, NUNCA escribir este archivo)
├── .gitignore         ← el .env está ignorado por git, no se sube
├── perfiles.json      ← perfiles de usuario con sus keys (rellenar desde .env)
├── menu.ps1           ← menú principal en PowerShell
├── opencode.bat       ← lanzador con doble click (llama a menu.ps1)
└── OPENCODE_SETUP.md  ← este archivo
```

---

## INSTRUCCIONES PARA LA IA — EJECUTAR EN ORDEN

### PASO 1 — Verificar Node.js y npm

```powershell
node --version
npm --version
```

Si Node.js no está instalado: detener y decirle al usuario que lo descargue de https://nodejs.org (versión LTS). No continuar hasta que Node esté disponible.

---

### PASO 2 — Agregar npm global al PATH (Windows)

En Windows, el directorio global de npm frecuentemente no está en el PATH del sistema.
Ejecutar esto para agregarlo en la sesión actual y verificar:

```powershell
$npmGlobal = "$env:APPDATA\npm"
$env:PATH = "$npmGlobal;$env:PATH"
```

Verificar que la ruta existe:
```powershell
Test-Path "$env:APPDATA\npm"
```

Si no existe aún (porque opencode no está instalado todavía), se creará al instalar en el paso 3.

---

### PASO 3 — Instalar OpenCode

```powershell
npm install -g opencode-ai
```

Verificar instalación (puede requerir cerrar y reabrir terminal si el PATH no tomó efecto):
```powershell
opencode --version
```

Si el comando `opencode` no se reconoce luego de instalarlo:
1. Asegurarse de que `$env:APPDATA\npm` está en el PATH (ver paso 2)
2. O cerrar y reabrir la terminal

Si npm install falla, intentar:
```powershell
npm install -g opencode-ai --force
```

Si sigue fallando, revisar el repositorio oficial: https://github.com/sst/opencode (el nombre del paquete pudo haber cambiado).

---

### PASO 4 — Verificar que el usuario tiene su .env listo

Revisar si existe el archivo `.env` en la carpeta del proyecto:
```powershell
Test-Path ".\\.env"
```

Si no existe, decirle al usuario:
> Crea el archivo `.env` en esta carpeta, copia el contenido de `.env.example` y rellena tus API keys reales.
> Nunca compartas ese archivo por chat.

**Nunca pedirle las keys por chat. Nunca escribir el .env por la IA.**

Revisar `.env.example` para saber qué campos existen:
- `GROQ_API_KEY` — empieza con `gsk_` (gratuito)
- `OPENROUTER_API_KEY` — empieza con `sk-or-v1-` (gratuito)
- `ANTHROPIC_API_KEY` — empieza con `sk-ant-` (pago)
- `OPENAI_API_KEY` — empieza con `sk-proj-` (pago)

---

### PASO 5 — Crear directorios de configuración de OpenCode

OpenCode guarda su configuración en dos rutas del sistema. Crearlas si no existen:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.local\share\opencode"
New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\opencode"
```

---

### PASO 6 — Escribir auth.json con las keys disponibles

Leer el `.env` del proyecto y escribir:
`%USERPROFILE%\.local\share\opencode\auth.json`

Incluir solo los proveedores cuya key existe y no está vacía.
Ejemplo con Groq y OpenRouter:

```json
{
  "groq": { "api_key": "gsk_VALOR_LEIDO_DEL_ENV" },
  "openrouter": { "api_key": "sk-or-v1_VALOR_LEIDO_DEL_ENV" }
}
```

Si el usuario también tiene Anthropic o OpenAI, agregarlos:
```json
{
  "groq": { "api_key": "gsk_..." },
  "openrouter": { "api_key": "sk-or-v1-..." },
  "anthropic": { "api_key": "sk-ant-..." },
  "openai": { "api_key": "sk-proj-..." }
}
```

---

### PASO 7 — Escribir config.json con el modelo por defecto

Escribir en: `%USERPROFILE%\.config\opencode\config.json`

La estructura correcta que requiere OpenCode es:

```json
{
  "model": "groq/llama-3.3-70b-versatile"
}
```

Elegir el modelo según los proveedores disponibles:
- Si tiene Groq → `"groq/llama-3.3-70b-versatile"` (recomendado, gratis)
- Si solo tiene OpenRouter → `"openrouter/meta-llama/llama-3.3-70b-instruct:free"`
- Si tiene Anthropic → `"anthropic/claude-sonnet-4-6"`
- Si tiene OpenAI → `"openai/gpt-4o-mini"`

**Nota importante:** la versión instalada de OpenCode define qué estructura acepta en `config.json`.
Si OpenCode muestra error al arrancar, revisar su versión con `opencode --version` y ajustar el config.

---

### PASO 8 — Actualizar perfiles.json

Abrir `perfiles.json` y rellenar las keys en el perfil del usuario (usando los valores del `.env`).
Ejemplo:

```json
{
  "perfiles": [
    {
      "nombre": "Gmail del usuario",
      "groq": "gsk_...",
      "openrouter": "sk-or-v1-...",
      "anthropic": "",
      "openai": ""
    }
  ]
}
```

El `menu.ps1` también intenta leer el `.env` y poblar los campos vacíos automáticamente,
pero es mejor tenerlos en `perfiles.json` para que el menú de perfiles funcione correctamente.

---

### PASO 9 — Probar

```powershell
opencode --version
```

Indicar al usuario que puede arrancar OpenCode con doble click en `opencode.bat`.
El menú permite cambiar perfiles, ver modelos y abrir OpenCode directamente.

---

## SOLUCIÓN DE PROBLEMAS

**`opencode: command not found` o `opencode no se reconoce`**
→ El directorio global de npm no está en el PATH.
→ Solución 1: cerrar y reabrir la terminal después de instalar.
→ Solución 2: agregar `$env:APPDATA\npm` al PATH manualmente en la sesión.
→ El `menu.ps1` hace esto automáticamente cada vez que se ejecuta.

**Error de API key inválida**
→ Verificar que la key en auth.json no tenga espacios extra y empiece con el prefijo correcto (`gsk_`, `sk-or-v1-`, `sk-ant-`, `sk-proj-`).

**npm install falla con error de permisos**
→ Abrir la terminal como Administrador e intentar de nuevo.
→ O probar: `npm install -g opencode-ai --force`

**El .bat no abre**
→ Click derecho → Ejecutar como administrador.
→ O abrir PowerShell manualmente y ejecutar: `powershell -NoProfile -ExecutionPolicy Bypass -File "ruta\al\menu.ps1"`

**OpenCode arranca pero da error de modelo o configuración**
→ Revisar que `config.json` tenga la estructura `{ "model": "proveedor/nombre-modelo" }`.
→ Revisar que `auth.json` tenga la api_key del proveedor que se está usando.

---

## MODELOS DISPONIBLES

### Groq (gratuito, 14,400 req/día, sin tarjeta)
- `groq/llama-3.3-70b-versatile` — recomendado
- `groq/llama-3.1-8b-instant` — más rápido, menor calidad
- `groq/mixtral-8x7b-32768` — contexto largo

### OpenRouter (modelos gratis con cuenta Google/GitHub)
- `openrouter/meta-llama/llama-3.3-70b-instruct:free`
- `openrouter/mistralai/mistral-7b-instruct:free`

### Anthropic / Claude (pago)
- `anthropic/claude-sonnet-4-6` — recomendado (buena calidad/precio)
- `anthropic/claude-haiku-4-5-20251001` — económico y rápido

### OpenAI / ChatGPT (pago)
- `openai/gpt-4o-mini` — económico
- `openai/gpt-4o` — potente

Para cambiar el modelo editar: `%USERPROFILE%\.config\opencode\config.json`
