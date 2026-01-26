{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  hostElement: document.querySelector('#flutter-app-host'),
  onEntrypointLoaded: async function(engineInitializer) {
    console.log("Inicializando Flutter...");
    console.log("hostElement:", document.querySelector('#flutter-app-host'));
    
    const appRunner = await engineInitializer.initializeEngine({
      renderer: "html",  // HTML renderer
      // FIX: NO configurar transparencia, dejar que Scaffold maneje el fondo
    });
    
    console.log("Motor Flutter inicializado correctamente (HTML RENDERER)");
    await appRunner.runApp();
  }
});
