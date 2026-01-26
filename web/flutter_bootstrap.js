{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  hostElement: document.querySelector('#flutter-app-host'),
  onEntrypointLoaded: async function(engineInitializer) {
    console.log("ðŸŽ¨ Inicializando Flutter con soporte de transparencia...");
    console.log("ðŸ“¦ hostElement:", document.querySelector('#flutter-app-host'));
    
    const appRunner = await engineInitializer.initializeEngine({
      renderer: "html",  // â¬…ï¸ CAMBIO CRÃTICO: HTML renderer en lugar de CanvasKit
    });
    
    console.log("âœ… Motor Flutter inicializado correctamente (HTML RENDERER)");
    await appRunner.runApp();
  }
});
