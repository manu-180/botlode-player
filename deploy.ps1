Write-Host "--- INICIANDO PROTOCOLO DE DESPLIEGUE AUTOMATICO ---" -ForegroundColor Cyan

# 1. LIMPIEZA
Write-Host "1. Limpiando motores..."
flutter clean
flutter pub get

# 2. BUILD
Write-Host "2. Compilando nucleo web..."
flutter build web --release

# 3. GITHUB AUTOMATICO (Sin preguntas)
$fecha = Get-Date -Format "yyyy-MM-dd HH:mm"
$commitMsg = "Auto Deploy Web: $fecha"

Write-Host "3. Guardando en GitHub ($commitMsg)..."
git add .
# El comando git commit puede fallar si no hay cambios, lo silenciamos con '2>$null' para que no pare el script
git commit -m "$commitMsg" 2>$null 
git push

# 4. DESPLIEGUE A VERCEL
Write-Host "4. Subiendo a la Nube (Vercel)..."
cd build\web

# --prod: Producción
# --yes: Sin preguntas
vercel --prod --yes 

cd ..\..

Write-Host "--- DESPLIEGUE COMPLETADO CON EXITO ---" -ForegroundColor Green