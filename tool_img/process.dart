import 'dart:collection';
import 'dart:io';
import 'package:image/image.dart' as img;

const assets = '../assets/images';

void main() {
  // ---------- 1) LOGO: remove outer black background ----------
  final logo = img.decodeImage(File('$assets/logo.jpeg').readAsBytesSync())!
      .convert(numChannels: 4);
  final w = logo.width, h = logo.height;

  bool isBlack(img.Pixel p, [int tol = 60]) =>
      p.r < tol && p.g < tol && p.b < tol;

  final visited = List.generate(h, (_) => List.filled(w, false));
  final q = Queue<List<int>>();
  for (final s in [
    [0, 0],
    [w - 1, 0],
    [0, h - 1],
    [w - 1, h - 1]
  ]) {
    q.add(s);
    visited[s[1]][s[0]] = true;
  }
  while (q.isNotEmpty) {
    final c = q.removeFirst();
    final x = c[0], y = c[1];
    final p = logo.getPixel(x, y);
    if (!isBlack(p)) continue;
    logo.setPixelRgba(x, y, 0, 0, 0, 0);
    for (final n in [
      [x + 1, y],
      [x - 1, y],
      [x, y + 1],
      [x, y - 1]
    ]) {
      final nx = n[0], ny = n[1];
      if (nx >= 0 && nx < w && ny >= 0 && ny < h && !visited[ny][nx]) {
        visited[ny][nx] = true;
        q.add(n);
      }
    }
  }
  File('$assets/logo.png').writeAsBytesSync(img.encodePng(logo));
  print('logo.png saved ${logo.width}x${logo.height}');

  // ---------- 2 & 3) BANNER ----------
  var src = img.decodeImage(File('$assets/appBar.jpeg').readAsBytesSync())!
      .convert(numChannels: 4);

  // Crop tight to non-white content plus a small pad.
  int minX = src.width, minY = src.height, maxX = 0, maxY = 0;
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      final lum = (p.r + p.g + p.b) / 3;
      if (lum < 245) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  const pad = 18;
  minX = (minX - pad).clamp(0, src.width - 1);
  minY = (minY - pad).clamp(0, src.height - 1);
  maxX = (maxX + pad).clamp(0, src.width - 1);
  maxY = (maxY + pad).clamp(0, src.height - 1);
  src = img.copyCrop(src,
      x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);

  img.Image makeTransparent(img.Image input) {
    final out = img.Image.from(input);
    for (int y = 0; y < out.height; y++) {
      for (int x = 0; x < out.width; x++) {
        final p = out.getPixel(x, y);
        final lum = (p.r + p.g + p.b) / 3;
        if (lum > 240) {
          out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 0);
        } else if (lum > 200) {
          final alpha = (255 * (240 - lum) / 40).round().clamp(0, 255);
          out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), alpha);
        }
      }
    }
    return out;
  }

  final light = makeTransparent(src);
  File('$assets/appbar_light.png').writeAsBytesSync(img.encodePng(light));
  print('appbar_light.png saved ${light.width}x${light.height}');

  // Dark variant: recolor dark navy text to white for dark surfaces.
  final dark = img.Image.from(light);
  for (int y = 0; y < dark.height; y++) {
    for (int x = 0; x < dark.width; x++) {
      final p = dark.getPixel(x, y);
      if (p.a > 0) {
        final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        if (lum < 110 && p.b >= p.r) {
          final f = ((110 - lum) / 110 + 0.35).clamp(0.0, 1.0);
          final nr = (p.r + (255 - p.r) * f).round();
          final ng = (p.g + (255 - p.g) * f).round();
          final nb = (p.b + (255 - p.b) * f).round();
          dark.setPixelRgba(x, y, nr, ng, nb, p.a.toInt());
        }
      }
    }
  }
  File('$assets/appbar_dark.png').writeAsBytesSync(img.encodePng(dark));
  print('appbar_dark.png saved ${dark.width}x${dark.height}');
}
