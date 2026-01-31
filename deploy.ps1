# 1. LIMPIEZA Y PREPARACIÓN
#NO QUIERO QUE SE DESPLIEGUE A VERCEL SOLO QUIERO DESPLEGAR MANUALMENTE

# Metodo viejo
Remove-Item -Recurse -Force docs
flutter build web
mkdir docs    
cp -r build/web/* docs/
git add .
git commit -m "vercel" 
git push 