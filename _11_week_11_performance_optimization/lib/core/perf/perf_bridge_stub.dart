/// Stub untuk platform non-web: jembatan JS tidak tersedia sehingga harness
/// hanya dapat dijalankan di Flutter web.
void exposePerfBridge({
  required void Function() onStart,
  required String Function() onSummary,
  required String Function() onState,
  required void Function(String path) onNavigate,
  required void Function(String query) onSearch,
}) {}

/// Mengirim hasil akhir skenario ke `window.__perfResult`.
void publishPerfResult(String json) {}
