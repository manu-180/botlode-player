# 1. LIMPIEZA Y PREPARACIÓN
# Esto borra build/web, por lo que Vercel "olvida" quién es el proyecto.
flutter clean
flutter pub get

# 2. CONSTRUCCIÓN DEL ARTEFACTO
# Generamos la web optimizada
flutter build web --release --web-renderer auto

# Copiamos la configuración de rutas (SPA)
Copy-Item "web/vercel.json" -Destination "build/web/" -Force

# 3. RESPALDO EN GITHUB
# Guardamos el código fuente antes de desplegar
git add .
# Si quieres cambiar el mensaje, edita lo que está entre comillas abajo:
git commit -m "Update: BotLode Player deployment" 
git push

# 4. DESPLIEGUE A PRODUCCIÓN AUTOMATIZADO
cd build\web

# --- LA MAGIA ESTÁ AQUÍ ---
# --prod: Despliega a producción directamente.
# --name botlode-player: Fuerza a Vercel a usar ESTE nombre y no "web".
# --yes: Responde "Sí" a todas las preguntas automáticamente.
vercel --prod --name botlode-player --yes

# 5. RETORNO A BASE
cd ..\..
Write-Host "✅ Misión Cumplida: BotLode Player actualizado." -ForegroundColor Green