import 'package:flutter/material.dart';

/// صيغة التخزين: ⟦f:بسط|مقام⟧  ⟦r:داخل الجذر⟧  ⟦v:+|عدد1|عدد2⟧ (عملية عمودية)
class Seg {
  final String t;
  final List<String> a;
  Seg(this.t, this.a);
}

final _re = RegExp(r'⟦(\w):([^⟧]*)⟧');

List<Seg> parseMath(String s) {
  final out = <Seg>[];
  var i = 0;
  for (final m in _re.allMatches(s)) {
    if (m.start > i) out.add(Seg('t', [s.substring(i, m.start)]));
    out.add(Seg(m.group(1)!, m.group(2)!.split('|')));
    i = m.end;
  }
  if (i < s.length) out.add(Seg('t', [s.substring(i)]));
  return out;
}

String tok(String t, List<String> a) => '⟦$t:${a.join('|')}⟧';

/// عرض السطر داخل التطبيق (معاينة)
class MathLine extends StatelessWidget {
  final String text;
  const MathLine(this.text, {super.key});
  Widget _bar(double w) => Container(width: w, height: 1.2, color: Colors.black, margin: const EdgeInsets.symmetric(vertical: 1));
  @override
  Widget build(BuildContext context) {
    final ws = <Widget>[];
    for (final s in parseMath(text)) {
      switch (s.t) {
        case 'f':
          final w = s.a.map((x) => x.length).reduce((a, b) => a > b ? a : b) * 10.0 + 8;
          ws.add(Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(mainAxisSize: MainAxisSize.min, children: [Text(s.a[0], style: const TextStyle(fontSize: 13)), _bar(w), Text(s.a.length > 1 ? s.a[1] : '', style: const TextStyle(fontSize: 13))])));
          break;
        case 'r':
          ws.add(Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('√'),
            Container(decoration: const BoxDecoration(border: Border(top: BorderSide(width: 1.2))), child: Text(s.a[0]))
          ]));
          break;
        case 'v':
          final a = s.a.length > 1 ? s.a[1] : '', b = s.a.length > 2 ? s.a[2] : '';
          final w = (a.length > b.length ? a.length : b.length) * 10.0 + 18;
          ws.add(Directionality(
              textDirection: TextDirection.ltr,
              child: Container(
                  width: w, margin: const EdgeInsets.all(6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(a),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(s.a[0]), Text(b)]),
                    _bar(w), const SizedBox(height: 14),
                  ]))));
          break;
        default:
          ws.add(Text(s.a[0]));
      }
    }
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: ws);
  }
}
