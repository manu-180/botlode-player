{{flutter_js}}
{{flutter_build_config}}

const userConfig = {
  // Forzamos CanvasKit para máxima fidelidad visual
  renderer: "canvaskit", 
};

_flutter.loader.load({
  config: userConfig,
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      // ESTA ES LA CLAVE DEL ÉXITO:
      renderer: "canvaskit", 
    });
    await appRunner.runApp();
  }
});