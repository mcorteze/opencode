# Dónde obtener las API keys

## GRATUITOS

### Groq
- Sitio: https://console.groq.com
- Registro: con cuenta Google o GitHub
- Key: empieza con `gsk_`
- Límite gratis: 14,400 requests/día, sin tarjeta de crédito
- Modelos destacados: llama-3.3-70b-versatile, llama-3.1-8b-instant, mixtral-8x7b

### OpenRouter
- Sitio: https://openrouter.ai
- Registro: con cuenta Google o GitHub
- Key: empieza con `sk-or-v1-`
- Límite gratis: varios modelos con sufijo `:free`, sin tarjeta
- Modelos gratuitos destacados:
  - meta-llama/llama-3.3-70b-instruct:free
  - mistralai/mistral-small-3.2-24b:free
  - mistralai/mistral-7b-instruct:free
  - deepseek/deepseek-chat-v3-0324:free
  - tngtech/deepseek-r1t-chimera:free
  - qwen/qwen3-235b-a22b:free
  - google/gemini-2.0-flash-exp:free
  - google/gemma-3-27b-it:free
  - microsoft/phi-4-reasoning:free

---

## DE PAGO

### Anthropic (Claude)
- Sitio: https://console.anthropic.com
- Registro: cuenta de correo + tarjeta de crédito
- Key: empieza con `sk-ant-`
- Crédito inicial: sin free tier, se paga por uso
- Modelos destacados: claude-sonnet-4-6, claude-haiku-4-5-20251001

### OpenAI (ChatGPT)
- Sitio: https://platform.openai.com/api-keys
- Registro: cuenta de correo + tarjeta de crédito
- Key: empieza con `sk-proj-`
- Crédito inicial: sin free tier permanente, se paga por uso
- Modelos destacados: gpt-4o, gpt-4o-mini

---

## CÓMO AGREGAR UNA KEY AL PROYECTO

1. Abre el archivo `.env` en la carpeta del proyecto
2. Copia la key en la variable correspondiente:
   ```
   GROQ_API_KEY=gsk_tukeyrealaqui
   OPENROUTER_API_KEY=sk-or-v1-tukeyrealaqui
   ANTHROPIC_API_KEY=sk-ant-tukeyrealaqui
   OPENAI_API_KEY=sk-proj-tukeyrealaqui
   ```
3. Abre el menú (`opencode.bat`) y selecciona opción 2 para activar el perfil
4. El menú lee el `.env` automáticamente y configura todo

> El archivo `.env` está en `.gitignore` — nunca se sube al repositorio.
