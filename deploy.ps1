Write-Host "--- INICIANDO PROTOCOLO DE DESPLIEGUE AUTOMATICO ---" -ForegroundColor Cyan

# 0. VERIFICACION Y CONFIGURACION DE GIT (Auto-Fix)
if (-not (Test-Path .git)) {
    Write-Host "0. Inicializando repositorio Git..."
    git init
    git branch -m main
    # Configuramos usuario genérico si no existe para evitar error
    git config user.email "deploy@botlode.com"
    git config user.name "Auto Deploy"
    Write-Host "✅ Git inicializado correctamente."
}

# 1. LIMPIEZA
Write-Host "1. Limpiando motores..."
flutter clean
flutter pub get

# 2. BUILD (CORREGIDO: Sin flag --web-renderer porque ya es default)
Write-Host "2. Compilando nucleo web (Canvaskit Default)..."
# En Flutter moderno, esto usa Canvaskit por defecto automáticamente.
flutter build web --release

# Verificamos si la build funcionó antes de seguir
if (-not (Test-Path "build\web\index.html")) {
    Write-Host "❌ ERROR CRITICO: La compilación falló. Revisa los errores arriba." -ForegroundColor Red
    Exit
}

# 3. GITHUB AUTOMATICO
$fecha = Get-Date -Format "yyyy-MM-dd HH:mm"
$commitMsg = "Auto Deploy Web: $fecha"

Write-Host "3. Guardando cambios ($commitMsg)..."
git add .
git commit -m "$commitMsg" *>$null 
# Nota: Si no tienes repositorio remoto conectado, 'git push' fallará pero no detendrá el script.
# Si solo usas Vercel, no necesitas 'git push' obligatorio.

# 4. DESPLIEGUE A VERCEL
Write-Host "4. Subiendo a la Nube (Vercel)..."
cd build\web

# --prod: Producción
# --yes: Sin preguntas
vercel --prod --yes 

cd .

Write-Host "--- DESPLIEGUE COMPLETADO CON EXITO ---" -ForegroundColor Green