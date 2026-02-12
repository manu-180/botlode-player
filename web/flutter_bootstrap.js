{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  hostElement: document.querySelector('#flutter-app-host'),
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      renderer: "html",  // HTML renderer
      // FIX: NO configurar transparencia, dejar que Scaffold maneje el fondo
    });
    await appRunner.runApp();
  }
});
