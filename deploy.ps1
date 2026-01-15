# 1. LIMPIEZA Y PREPARACIÓN (Evita errores fantasma)
flutter clean
flutter pub get

# 2. CONSTRUCCIÓN DEL ARTEFACTO (Crea la carpeta build/web)
# Nota: Como pusiste vercel.json en /web, se copiará solo.
flutter build web --release
Copy-Item "web/vercel.json" -Destination "build/web/" -Force

# 3. RESPALDO EN GITHUB (Guardar progreso)
git add .
git commit -m "Actualización: Mejoras en UI y correcciones" 
git push

# 4. DESPLIEGUE A PRODUCCIÓN (Maniobra de Inmersión)
cd build\web
vercel --prod

# 5. RETORNO A BASE (Volver a la raíz para seguir programando)
cd ..\..