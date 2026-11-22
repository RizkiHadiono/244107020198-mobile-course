import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
import 'package:flutter/material.dart';

/// Gambar jaringan yang di-decode pada ukuran tampil (bukan ukuran asli).
///
/// Kenapa perlu pembungkus ini?
/// - `CachedNetworkImage` di web secara default memakai renderer `HtmlImage`:
///   browser yang melakukan decode, sehingga `memCacheWidth/Height` **tidak**
///   berpengaruh dan `ImageCache` tetap menyimpan gambar 1200x800
///   (±3,84 MB per gambar).
/// - Dengan `ImageRenderMethodForWeb.HttpGet`, byte gambar diunduh lalu
///   di-decode lewat engine Flutter, sehingga `ResizeImage` (dari
///   `memCacheWidth/Height`) benar-benar mengecilkan hasil decode.
/// - Di Android/iOS kedua jalur memakai engine yang sama, jadi perilakunya
///   konsisten.
class CachedThumbnail extends StatelessWidget {
  const CachedThumbnail({
    super.key,
    required this.url,
    required this.height,
    required this.memWidth,
    required this.memHeight,
    this.fit = BoxFit.cover,
    this.fadeInDuration = const Duration(milliseconds: 180),
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final double height;
  final int memWidth;
  final int memHeight;
  final BoxFit fit;
  final Duration fadeInDuration;
  final WidgetBuilder? placeholder;
  final WidgetBuilder? errorWidget;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: double.infinity,
      fit: fit,
      memCacheWidth: memWidth,
      memCacheHeight: memHeight,
      imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
      fadeInDuration: fadeInDuration,
      placeholder: placeholder == null
          ? null
          : (context, _) => placeholder!(context),
      errorWidget: errorWidget == null
          ? null
          : (context, _, _) => errorWidget!(context),
    );
  }
}
