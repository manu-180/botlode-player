#!/bin/bash
# Script de deployment para botlode-player

echo "🚀 Building botlode-player..."
flutter build web --release --tree-shake-icons -O 4 --no-source-maps

echo "📦 Copiando a docs..."
rm -rf docs
cp -r build/web docs

echo "✅ Commiting y pushing..."
git add .
git commit -m "deploy: botlode-player v6.0 - Fondo transparente"
git push origin main

echo "✅ Deploy completo! Vercel desplegará automáticamente."
