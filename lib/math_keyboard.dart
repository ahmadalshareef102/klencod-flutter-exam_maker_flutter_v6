import 'package:flutter/material.dart';
import 'math.dart';

class MathKeyboard extends StatelessWidget {
  final void Function(String) onInsert;
  const MathKeyboard({super.key, required this.onInsert});

  Future<List<String>?> _ask(BuildContext c, String title, List<String> labels) {
    final ctrls = labels.map((_) => TextEditingController()).toList();
    return showDialog<List<String>>(
        context: c,
        builder: (_) => AlertDialog(
              title: Text(title),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < labels.length; i++)
                  TextField(controller: ctrls[i], autofocus: i == 0, decoration: InputDecoration(labelText: labels[i])),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(c, ctrls.map((e) => e.text.trim()).toList()), child: const Text('إدراج')),
              ],
            ));
  }

  Widget _k(String label, VoidCallback f, {Color? color, bool wide = false}) => Padding(
        padding: const EdgeInsets.all(2),
        child: SizedBox(
          width: wide ? 96 : 42, height: 40,
          child: FilledButton.tonal(
              style: FilledButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: color),
              onPressed: f, child: Text(label, style: const TextStyle(fontSize: 15))),
        ),
      );

  @override
  Widget build(BuildContext context) {
    Future<void> frac() async {
      final r = await _ask(context, 'كسر', ['البسط', 'المقام']);
      if (r != null) onInsert(tok('f', r));
    }

    Future<void> root() async {
      final r = await _ask(context, 'جذر', ['ما داخل الجذر']);
      if (r != null) onInsert(tok('r', r));
    }

    Future<void> vert(String op, String name) async {
      final r = await _ask(context, name, ['العدد الأول', 'العدد الثاني']);
      if (r != null) onInsert(tok('v', [op, ...r]));
    }

    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const ops = ['+', '−', '×', '÷', '=', '≠', '<', '>', '≤', '≥', '(', ')', '²', '³', '±', 'π', '°', '%', '٫', '✓', '✗', '........'];
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Wrap(alignment: WrapAlignment.center, children: [
          _k('بسط/مقام', frac, color: const Color(0xFFD1C4E9), wide: true),
          _k('√ جذر', root, color: const Color(0xFFB3E5FC), wide: true),
          _k('جمع عمودي', () => vert('+', 'جمع عمودي'), color: const Color(0xFFFFCDD2), wide: true),
          _k('طرح عمودي', () => vert('−', 'طرح عمودي'), color: const Color(0xFFFFCDD2), wide: true),
          _k('ضرب عمودي', () => vert('×', 'ضرب عمودي'), color: const Color(0xFFFFCDD2), wide: true),
        ]),
        const Divider(height: 10),
        Wrap(alignment: WrapAlignment.center, children: [for (final d in digits) _k(d, () => onInsert(d))]),
        Wrap(alignment: WrapAlignment.center, children: [for (final o in ops) _k(o, () => onInsert(o))]),
      ]),
    );
  }
}
