Write-Host "--- INICIANDO PROTOCOLO DE DESPLIEGUE AUTOMATICO ---" -ForegroundColor Cyan

# 1. LIMPIEZA
Write-Host "1. Limpiando motores..."
flutter clean
flutter pub get

# 2. BUILD (¡ESTA ES LA LÍNEA CLAVE!)
Write-Host "2. Compilando nucleo web (Canvaskit)..."
flutter build web --release --web-renderer canvaskit

# 3. GITHUB AUTOMATICO
$fecha = Get-Date -Format "yyyy-MM-dd HH:mm"
$commitMsg = "Auto Deploy Web: $fecha"

Write-Host "3. Guardando en GitHub ($commitMsg)..."
git add .
git commit -m "$commitMsg" *>$null 
git push

# 4. DESPLIEGUE A VERCEL
Write-Host "4. Subiendo a la Nube (Vercel)..."
cd build\web

# PRECAUCIÓN: Si crees que estás en el proyecto incorrecto, 
# Vercel usará la configuración guardada en la carpeta .vercel oculta aquí.
vercel --prod --yes 

cd ..

Write-Host "--- DESPLIEGUE COMPLETADO CON EXITO ---" -ForegroundColor Green