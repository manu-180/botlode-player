# Script de Deploy con HTML Renderer para solucionar transparencia
# Uso: .\deploy_html_renderer.ps1

Write-Host "🔄 Limpiando build anterior..." -ForegroundColor Yellow
Remove-Item -Recurse -Force docs -ErrorAction SilentlyContinue

Write-Host "🎨 Compilando Flutter con HTML Renderer..." -ForegroundColor Cyan
flutter build web --release --web-renderer html

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error al compilar Flutter" -ForegroundColor Red
    exit 1
}

Write-Host "📦 Preparando archivos para Vercel..." -ForegroundColor Yellow
mkdir docs -ErrorAction SilentlyContinue
Copy-Item -Recurse -Force build/web/* docs/

Write-Host "🚀 Desplegando a Vercel..." -ForegroundColor Green
cd ..
git add .
git commit -m "v1.7 - HTML Renderer para transparencia"
git push

Write-Host "✅ Deploy completado!" -ForegroundColor Green
Write-Host "📍 URL: https://botlode-player.vercel.app/" -ForegroundColor Cyan
