{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: {renderer: 'canvaskit', canvasKitVariant: 'full', canvasKitBaseUrl: 'canvaskit/'},
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  }
}).catch(function () {
  const status = document.querySelector('#loading-status');
  if (status) status.textContent = 'Kafe belum bisa dibuka. Periksa koneksi lalu muat ulang.';
  document.querySelector('#reload').hidden = false;
});
