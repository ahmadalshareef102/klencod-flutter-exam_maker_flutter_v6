import 'dart:convert';
import 'package:archive/archive.dart';
import 'math.dart';
import 'models.dart';

class WordExport {
  static String _e(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  static String _n(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static String _run(String t, {bool bold = false, String? color, int size = 24}) =>
      '<w:r><w:rPr><w:rFonts w:ascii="Cairo" w:hAnsi="Cairo" w:cs="Cairo"/>${bold ? '<w:b/><w:bCs/>' : ''}'
      '${color != null ? '<w:color w:val="$color"/>' : ''}<w:sz w:val="$size"/><w:szCs w:val="$size"/><w:rtl/></w:rPr>'
      '<w:t xml:space="preserve">${_e(t)}</w:t></w:r>';

  static String _mr(String t) => '<m:r><m:t>${_e(t)}</m:t></m:r>';

  static String _p(String inner, {bool center = false, String? fill, int after = 40}) =>
      '<w:p><w:pPr><w:bidi/>${fill != null ? '<w:shd w:val="clear" w:color="auto" w:fill="$fill"/>' : ''}'
      '<w:spacing w:after="$after"/>${center ? '<w:jc w:val="center"/>' : ''}</w:pPr>$inner</w:p>';

  /// سطر يدعم الكسور والجذور (معادلات Word) والعمليات العمودية (نص خطي)
  static String _line(String t, {bool bold = false}) {
    final b = StringBuffer();
    for (final s in parseMath(t)) {
      switch (s.t) {
        case 'f':
          b.write('<m:oMath><m:f><m:num>${_mr(s.a[0])}</m:num><m:den>${_mr(s.a.length > 1 ? s.a[1] : '')}</m:den></m:f></m:oMath>');
          break;
        case 'r':
          b.write('<m:oMath><m:rad><m:radPr><m:degHide m:val="1"/></m:radPr><m:deg/><m:e>${_mr(s.a[0])}</m:e></m:rad></m:oMath>');
          break;
        case 'v':
          b.write(_run(' ${s.a.length > 1 ? s.a[1] : ''} ${s.a[0]} ${s.a.length > 2 ? s.a[2] : ''} = ........ ', bold: bold));
          break;
        default:
          b.write(_run(s.a[0], bold: bold));
      }
    }
    return _p(b.toString());
  }

  static String _cell(int w, String inner, {String? fill}) =>
      '<w:tc><w:tcPr><w:tcW w:w="$w" w:type="dxa"/>${fill != null ? '<w:shd w:val="clear" w:color="auto" w:fill="$fill"/>' : ''}</w:tcPr>'
      '${inner.isEmpty ? '<w:p/>' : inner}</w:tc>';

  static const _borders =
      '<w:tblBorders><w:top w:val="single" w:sz="8"/><w:left w:val="single" w:sz="8"/><w:bottom w:val="single" w:sz="8"/>'
      '<w:right w:val="single" w:sz="8"/><w:insideH w:val="single" w:sz="6"/><w:insideV w:val="single" w:sz="6"/></w:tblBorders>';

  static String _tbl(List<int> cols, String rows) =>
      '<w:tbl><w:tblPr><w:bidiVisual/><w:tblW w:w="${cols.reduce((a, b) => a + b)}" w:type="dxa"/>$_borders</w:tblPr>'
      '<w:tblGrid>${cols.map((c) => '<w:gridCol w:w="$c"/>').join()}</w:tblGrid>$rows</w:tbl>';

  static List<int> build(Exam e, {bool key = false}) {
    final body = StringBuffer();
    body.write(_p(_run('اسم الطالب: ${'.' * 45}') + _run('        رقم الجلوس: [ ${'.' * 10} ]')));
    final right = e.rightLines.split('\n').map((l) => _p(_run(l, size: 18), center: true, after: 0)).join();
    final left = [
      'الصف: ${e.grade}', 'المادة: ${e.subject}', 'التاريخ: ${e.date}', 'الزمن: ${e.duration}', 'الفترة: ${e.period}'
    ].map((l) => _p(_run(l, size: 18), after: 0)).join();
    body.write(_tbl([4200, 2200, 3400],
        '<w:tr>${_cell(4200, right)}${_cell(2200, _p(_run('بسم الله الرحمن الرحيم', bold: true, size: 20), center: true))}${_cell(3400, left)}</w:tr>'));
    body.write(_p(_run(key ? '${e.title} (نموذج الإجابة وتوزيع الدرجات)' : e.title, bold: true), center: true, fill: 'E6E6E6', after: 120));

    final rows = StringBuffer();
    rows.write('<w:tr>${_cell(1100, _p(_run('السؤال', bold: true), center: true), fill: 'E6E6E6')}'
        '${_cell(7700, _p(_run('أجب عن جميع الأسئلة الآتية', bold: true, color: 'C62828'), center: true), fill: 'E6E6E6')}'
        '${_cell(1000, _p(_run('الدرجة', bold: true), center: true), fill: 'E6E6E6')}</w:tr>');
    for (var i = 0; i < e.qs.length; i++) {
      final q = e.qs[i];
      final c = StringBuffer();
      if (q.prompt.isNotEmpty) c.write(_p(_run(q.prompt, bold: true)));
      for (final l in q.body.split('\n').where((l) => l.trim().isNotEmpty)) {
        c.write(_line(l));
      }
      if (key && q.answer.trim().isNotEmpty) {
        c.write(_p(_run('الإجابة النموذجية:', bold: true, color: '0D47A1'), fill: 'E3F2FD'));
        for (final l in q.answer.split('\n')) {
          c.write(_line(l));
        }
      }
      rows.write('<w:tr>${_cell(1100, _p(_run('السؤال ${i + 1}'), center: true))}${_cell(7700, c.toString())}'
          '${_cell(1000, _p(_run('${_n(q.marks)} د'), center: true))}</w:tr>');
    }
    body.write(_tbl([1100, 7700, 1000], rows.toString()));
    body.write(_p(_run(key ? 'المجموع: ${_n(e.total)} د' : e.closing, bold: true), center: true, after: 80));
    body.write(_p(_run(key ? 'المصحح / المراجع: ......................' : e.teacher)));

    final doc = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"><w:body>$body'
        '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720" w:header="400" w:footer="400" w:gutter="0"/><w:bidi/></w:sectPr>'
        '</w:body></w:document>';
    const types = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>';
    const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>';
    final a = Archive();
    void add(String n, String c) {
      final b = utf8.encode(c);
      a.addFile(ArchiveFile(n, b.length, b));
    }

    add('[Content_Types].xml', types);
    add('_rels/.rels', rels);
    add('word/document.xml', doc);
    return ZipEncoder().encode(a)!;
  }
}
