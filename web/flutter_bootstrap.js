{{flutter_js}}
{{flutter_build_config}}

// Flutter's default version of this file also registers
// flutter_service_worker.js, a deprecated worker that only removes itself.
// It would take the place of ours (web/sw.js, registered by
// lib/core/data/web_app_browser.dart), so the app is loaded without it.
_flutter.loader.load();
