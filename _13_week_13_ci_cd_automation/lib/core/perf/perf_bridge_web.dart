import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Menjembatani aplikasi Flutter web dengan harness Chrome DevTools Protocol.
///
/// Harness memanggil `window.__perfStart()` lalu membaca hasilnya dari
/// `window.__perfResult` setelah `window.__perfState()` bernilai `done`.
/// `window.__perfGo(path)` dan `window.__perfSearch(query)` dipakai untuk
/// menyiapkan kondisi screenshot.
void exposePerfBridge({
  required void Function() onStart,
  required String Function() onSummary,
  required String Function() onState,
  required void Function(String path) onNavigate,
  required void Function(String query) onSearch,
}) {
  globalContext['__perfStart'] = (() {
    onStart();
  }).toJS;

  globalContext['__perfSummary'] = (() {
    return onSummary().toJS;
  }).toJS;

  globalContext['__perfState'] = (() {
    return onState().toJS;
  }).toJS;

  globalContext['__perfGo'] = ((JSString path) {
    onNavigate(path.toDart);
  }).toJS;

  globalContext['__perfSearch'] = ((JSString query) {
    onSearch(query.toDart);
  }).toJS;

  globalContext['__perfResult'] = ''.toJS;
}

void publishPerfResult(String json) {
  globalContext['__perfResult'] = json.toJS;
}
