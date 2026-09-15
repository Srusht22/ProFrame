// Flutter's own bootstrap, with one change.
//
// By default the web build fetches its renderer from Google's CDN at startup,
// so the app would not open in a workshop with no internet — even though the
// renderer is built into this bundle. `canvasKitBaseUrl` points Flutter at
// that copy instead.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
