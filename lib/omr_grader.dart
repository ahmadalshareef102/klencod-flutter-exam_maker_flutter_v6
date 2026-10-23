import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'package:image/image.dart' as img;
import 'omr_layout.dart';

/// يرجع قائمة: رقم الخيار (0..3) أو -1 فارغ أو -2 تظليل مزدوج
class OmrGrader {
  static Future<List<int>> grade(Uint8List bytes, int n) async {
    var im = img.decodeImage(bytes);
    if (im == null) throw 'تعذر قراءة الصورة';
    im = img.bakeOrientation(im);
    im = img.copyResize(im, width: 1200);
    final w = im.width, h = im.height;
    final g = Uint8List(w * h);
    double sum = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = im.getPixel(x, y);
        final v = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        g[y * w + x] = v.round().clamp(0, 255).toInt();
        sum += v;
      }
    }
    final thr = (sum / (w * h)) * 0.6;
    final pts = _markers(g, w, h, thr);
    final mk = OmrLayout.markers;
    final tl = pts[0], tr = pts[1], bl = pts[2], br = pts[3];
    Offset map(Offset p) {
      final u = (p.dx - mk[0].dx) / (mk[1].dx - mk[0].dx);
      final v = (p.dy - mk[0].dy) / (mk[2].dy - mk[0].dy);
      return tl + (tr - tl) * u + (bl - tl) * v + (br - bl - tr + tl) * (u * v);
    }

    final scale = (tr - tl).distance / (mk[1].dx - mk[0].dx);
    final rad = 8 * scale * 0.55;
    double frac(Offset c) {
      var tot = 0, d = 0;
      for (var y = -rad.round(); y <= rad.round(); y++) {
        for (var x = -rad.round(); x <= rad.round(); x++) {
          if (x * x + y * y > rad * rad) continue;
          final px = (c.dx + x).round(), py = (c.dy + y).round();
          if (px < 0 || py < 0 || px >= w || py >= h) continue;
          tot++;
          if (g[py * w + px] < thr) d++;
        }
      }
      return tot == 0 ? 0 : d / tot;
    }

    final out = <int>[];
    for (var q = 0; q < n; q++) {
      final filled = <int>[];
      for (var i = 0; i < 4; i++) {
        if (frac(map(OmrLayout.center(q, i))) > 0.45) filled.add(i);
      }
      out.add(filled.isEmpty ? -1 : filled.length > 1 ? -2 : filled.first);
    }
    return out;
  }

  static List<Offset> _markers(Uint8List g, int w, int h, double thr) {
    final vis = Uint8List(w * h);
    final regions = [
      [0.0, 0.35, 0.0, 0.35, 0.0, 0.0],
      [0.65, 1.0, 0.0, 0.35, 1.0, 0.0],
      [0.0, 0.35, 0.65, 1.0, 0.0, 1.0],
      [0.65, 1.0, 0.65, 1.0, 1.0, 1.0],
    ];
    final res = <Offset>[];
    for (final r in regions) {
      final x0 = (r[0] * w).toInt(), x1 = (r[1] * w).toInt() - 1;
      final y0 = (r[2] * h).toInt(), y1 = (r[3] * h).toInt() - 1;
      final cx = r[4] * w, cy = r[5] * h;
      Offset? best;
      var bestD = double.infinity;
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          final i = y * w + x;
          if (vis[i] == 1 || g[i] >= thr) continue;
          var minx = x, maxx = x, miny = y, maxy = y, area = 0;
          double sx = 0, sy = 0;
          final st = <int>[i];
          vis[i] = 1;
          while (st.isNotEmpty) {
            final k = st.removeLast();
            final px = k % w, py = k ~/ w;
            area++;
            sx += px;
            sy += py;
            if (px < minx) minx = px;
            if (px > maxx) maxx = px;
            if (py < miny) miny = py;
            if (py > maxy) maxy = py;
            for (final d in const [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
              final nx = px + d[0], ny = py + d[1];
              if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
              final ni = ny * w + nx;
              if (vis[ni] == 0 && g[ni] < thr) {
                vis[ni] = 1;
                st.add(ni);
              }
            }
          }
          final bw = maxx - minx + 1, bh = maxy - miny + 1;
          if (bw < 0.015 * w || bw > 0.12 * w || bh < 0.015 * w || bh > 0.12 * w) continue;
          final asp = bw / bh;
          if (asp < 0.7 || asp > 1.4 || area / (bw * bh) < 0.75) continue;
          final c = Offset(sx / area, sy / area);
          final dist = (c - Offset(cx, cy)).distance;
          if (dist < bestD) {
            bestD = dist;
            best = c;
          }
        }
      }
      if (best == null) throw 'لم أستطع تحديد زوايا الورقة. صوّر الورقة كاملة بإضاءة جيدة وبدون ظلال.';
      res.add(best);
    }
    return res;
  }
}
