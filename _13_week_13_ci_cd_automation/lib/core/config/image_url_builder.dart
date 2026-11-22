/// Konfigurasi URL gambar agar harness profiling dapat memakai server lokal
/// (deterministik, tanpa ketergantungan jaringan internet).
///
/// - Build normal  : `https://picsum.photos/seed/<id>/<w>/<h>`
/// - Build harness : `--dart-define=PERF_IMAGE_BASE=http://127.0.0.1:8777/img`
///   sehingga menjadi `http://127.0.0.1:8777/img/<w>x<h>/<id>.png`
class ImageUrlBuilder {
  const ImageUrlBuilder(this.base);

  final String base;

  static const String defaultBase = 'https://picsum.photos';

  bool get isLocal => !base.contains('picsum');

  String full(int id) =>
      isLocal ? '$base/1200x800/$id.png' : '$base/seed/$id/1200/800';

  String thumb(int id) =>
      isLocal ? '$base/150x100/$id.png' : '$base/seed/$id/150/100';
}
