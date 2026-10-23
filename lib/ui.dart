import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'math.dart';
import 'math_keyboard.dart';
import 'models.dart';
import 'omr_grader.dart';
import 'pdf_builder.dart';
import 'word_export.dart';

const kBlue = Color(0xFF1B3A8A);

Widget tf(String label, String value, ValueChanged<String> onChanged,
        {int lines = 1, TextInputType? type}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: value, onChanged: onChanged, minLines: lines, maxLines: lines == 1 ? 1 : lines + 3,
        keyboardType: type,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  List<Exam> exams = [];
  @override
  void initState() {
    super.initState();
    Store.load().then((v) => setState(() => exams = v));
  }

  Future<void> _open(Exam e) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ExamEditor(exam: e, onSave: () => Store.save(exams))));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('صانع الاختبارات الذكي'), backgroundColor: kBlue, foregroundColor: Colors.white),
        body: exams.isEmpty
            ? const Center(child: Text('لا توجد اختبارات بعد.\nاضغط + لإنشاء اختبار جديد', textAlign: TextAlign.center))
            : ListView(
                children: exams
                    .map((e) => Card(
                          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: ListTile(
                            title: Text(e.subject.isEmpty ? 'اختبار بدون مادة' : e.subject),
                            subtitle: Text('${e.title}\nالصف: ${e.grade} • الدرجة: ${e.total.toStringAsFixed(0)} • الطلاب: ${e.students.length}'),
                            isThreeLine: true,
                            onTap: () => _open(e),
                            trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  setState(() => exams.remove(e));
                                  await Store.save(exams);
                                }),
                          ),
                        ))
                    .toList()),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: kBlue, foregroundColor: Colors.white,
          icon: const Icon(Icons.add), label: const Text('اختبار جديد'),
          onPressed: () {
            final e = Exam();
            exams.add(e);
            _open(e);
          },
        ),
      );
}

class ExamEditor extends StatefulWidget {
  final Exam exam;
  final Future<void> Function() onSave;
  const ExamEditor({super.key, required this.exam, required this.onSave});
  @override
  State<ExamEditor> createState() => _EditorState();
}

class _EditorState extends State<ExamEditor> {
  Exam get e => widget.exam;
  void _ch() {
    widget.onSave();
    setState(() {});
  }

  Future<void> _editQ(Question? q) async {
    final r = await showModalBottomSheet<Question>(
        context: context, isScrollControlled: true,
        builder: (_) => QuestionSheet(q: q ?? Question()));
    if (r == null) return;
    if (q == null) {
      e.qs.add(r);
    } else {
      e.qs[e.qs.indexOf(q)] = r;
    }
    _ch();
  }

  Future<void> _roster() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
    if (r == null || r.files.single.bytes == null) return;
    final book = xl.Excel.decodeBytes(r.files.single.bytes!);
    final sheet = book.tables.values.first;
    final list = <Student>[];
    for (final row in sheet.rows) {
      String c(int i) => i < row.length ? (row[i]?.value?.toString() ?? '').trim() : '';
      if (c(0).isEmpty || c(0).contains('اسم')) continue;
      list.add(Student(c(0), c(1), c(2).isEmpty ? (1000 + list.length * 7919 % 9000).toString() : c(2)));
    }
    e.students = list;
    _ch();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم استيراد ${list.length} طالب')));
  }

  Future<void> _word(bool key) async {
    final bytes = Uint8List.fromList(WordExport.build(e, key: key));
    await FilePicker.platform.saveFile(
        fileName: key ? 'نموذج_الإجابة.docx' : 'ورقة_الاختبار.docx', bytes: bytes, type: FileType.custom, allowedExtensions: ['docx']);
  }

  static const _letters = ['أ', 'ب', 'ج', 'د'];

  Future<void> _scan() async {
    void msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
    final key = e.omrKey.split(RegExp(r'[,،\s]+')).where((x) => x.isNotEmpty).map((x) => x == 'ا' ? 'أ' : x).toList();
    if (key.isEmpty) return msg('أدخل مفتاح التصحيح أولاً من إعدادات OMR');
    final n = key.length > 50 ? 50 : key.length;
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 95);
    if (x == null) return;
    msg('جارٍ التصحيح...');
    List<int> ans;
    try {
      ans = await OmrGrader.grade(await x.readAsBytes(), n);
    } catch (err) {
      return msg('$err');
    }
    var score = 0;
    final wrong = <String>[];
    for (var i = 0; i < n; i++) {
      final ok = ans[i] >= 0 && _letters[ans[i]] == key[i];
      if (ok) {
        score++;
      } else {
        wrong.add('${i + 1}${ans[i] == -1 ? ' (فارغ)' : ans[i] == -2 ? ' (مزدوج)' : ''}');
      }
    }
    Student? who;
    if (!mounted) return;
    await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
              builder: (c, set) => AlertDialog(
                title: Text('الدرجة: $score / $n'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(wrong.isEmpty ? 'جميع الإجابات صحيحة 🎉' : 'الأسئلة الخاطئة: ${wrong.join('، ')}'),
                  if (e.students.isNotEmpty)
                    DropdownButton<Student>(
                        isExpanded: true, hint: const Text('اختر الطالب'), value: who,
                        items: e.students.map((s) => DropdownMenuItem(value: s, child: Text('${s.name} - ${s.seat}'))).toList(),
                        onChanged: (v) => set(() => who = v)),
                ])),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text('إغلاق')),
                  FilledButton(
                      onPressed: () {
                        e.results.add({'name': who?.name ?? 'غير محدد', 'seat': who?.seat ?? '', 'score': score, 'of': n});
                        _ch();
                        Navigator.pop(c);
                      },
                      child: const Text('حفظ النتيجة')),
                ],
              ),
            ));
  }

  Future<void> _export(Kind k, String name) async {
    final bytes = await PdfBuilder.build(e, k);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('الدرجة الكلية: ${e.total.toStringAsFixed(0)}'), backgroundColor: kBlue, foregroundColor: Colors.white, actions: [
          IconButton(icon: const Icon(Icons.document_scanner), tooltip: 'تصحيح OMR بالكاميرا', onPressed: _scan),
          PopupMenuButton<int>(
            icon: const Icon(Icons.picture_as_pdf),
            onSelected: (v) {
              if (v == 0) _export(Kind.student, 'ورقة الاختبار');
              if (v == 1) _export(Kind.key, 'نموذج الإجابة');
              if (v == 2) _export(Kind.omr, 'ورقة OMR');
              if (v == 3) _word(false);
              if (v == 4) _word(true);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 0, child: Text('ورقة الاختبار (للطلاب)')),
              PopupMenuItem(value: 1, child: Text('نموذج الإجابة (محلول)')),
              PopupMenuItem(value: 2, child: Text('ورقة التظليل OMR')),
              PopupMenuItem(value: 3, child: Text('Word: ورقة الاختبار')),
              PopupMenuItem(value: 4, child: Text('Word: نموذج الإجابة')),
            ],
          ),
        ]),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          ExpansionTile(title: const Text('بيانات الترويسة'), children: [
            tf('عنوان الاختبار', e.title, (v) { e.title = v; widget.onSave(); }),
            tf('المادة', e.subject, (v) { e.subject = v; widget.onSave(); }),
            tf('الصف', e.grade, (v) { e.grade = v; widget.onSave(); }),
            tf('التاريخ', e.date, (v) { e.date = v; widget.onSave(); }),
            tf('الزمن', e.duration, (v) { e.duration = v; widget.onSave(); }),
            tf('الفترة', e.period, (v) { e.period = v; widget.onSave(); }),
            tf('أسطر الترويسة اليمنى (سطر لكل جهة)', e.rightLines, (v) { e.rightLines = v; widget.onSave(); }, lines: 5),
            tf('عبارة الختام', e.closing, (v) { e.closing = v; widget.onSave(); }),
            tf('توقيع المعلم', e.teacher, (v) { e.teacher = v; widget.onSave(); }),
          ]),
          ExpansionTile(title: Text('كشف الطلاب (${e.students.length})'), children: [
            const Padding(
                padding: EdgeInsets.all(8),
                child: Text('ملف Excel: العمود A الاسم، B رقم الجلوس، C الرقم السري (اختياري). تُطبع ورقة مستقلة لكل طالب مع QR.')),
            FilledButton.icon(onPressed: _roster, icon: const Icon(Icons.table_chart), label: const Text('استيراد من Excel')),
            if (e.students.isNotEmpty)
              TextButton(onPressed: () { e.students = []; _ch(); }, child: const Text('مسح الكشف')),
          ]),
          ExpansionTile(title: const Text('إعدادات OMR'), children: [
            tf('عدد الأسئلة', e.omrCount.toString(), (v) { e.omrCount = int.tryParse(v) ?? 20; widget.onSave(); }, type: TextInputType.number),
            tf('مفتاح التصحيح (مثال: أ,ب,ج,د)', e.omrKey, (v) { e.omrKey = v; widget.onSave(); }),
          ]),
          ExpansionTile(title: Text('نتائج OMR (${e.results.length})'), children: [
            for (var i = 0; i < e.results.length; i++)
              ListTile(
                dense: true,
                title: Text('${e.results[i]['name']}  ${e.results[i]['seat']}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${e.results[i]['score']} / ${e.results[i]['of']}'),
                  IconButton(icon: const Icon(Icons.close), onPressed: () { e.results.removeAt(i); _ch(); }),
                ]),
              ),
          ]),
          const Divider(),
          for (var i = 0; i < e.qs.length; i++)
            Card(
              child: ListTile(
                title: Text('السؤال ${i + 1}: ${e.qs[i].prompt}', maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${e.qs[i].marks.toStringAsFixed(0)} د${e.qs[i].twoCols ? ' • عمودان' : ''}'),
                onTap: () => _editQ(e.qs[i]),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () { e.qs.removeAt(i); _ch(); }),
              ),
            ),
          const SizedBox(height: 80),
        ]),
        floatingActionButton: FloatingActionButton.extended(
            backgroundColor: kBlue, foregroundColor: Colors.white,
            onPressed: () => _editQ(null), icon: const Icon(Icons.add), label: const Text('إضافة سؤال')),
      );
}

const _templates = {
  'اختيار من متعدد': ['اختر الإجابة الصحيحة من بين الأقواس لما يأتي:', '١- ........ [ أ.. ، ب.. ]\n٢- ........ [ أ.. ، ب.. ]\n٣- ........ [ أ.. ، ب.. ]\n٤- ........ [ أ.. ، ب.. ]', 'true'],
  'صح وخطأ': ['ضع علامة (✓) أمام العبارة الصحيحة وعلامة (✗) أمام العبارة الخطأ فيما يأتي:', '١- ........ ( ).\n٢- ........ ( ).\n٣- ........ ( ).\n٤- ........ ( ).', ''],
  'علل / اذكر السبب': ['علل لما يأتي:', '١- ........\n.......................................\n٢- ........\n.......................................', ''],
  'أكمل الفراغات': ['أكمل الفراغات الآتية:', '١- ........\n٢- ........\n٣- ........', ''],
  'سؤال حر': ['', '', ''],
};

class QuestionSheet extends StatefulWidget {
  final Question q;
  const QuestionSheet({super.key, required this.q});
  @override
  State<QuestionSheet> createState() => _QSheetState();
}

class _QSheetState extends State<QuestionSheet> {
  late final prompt = TextEditingController(text: widget.q.prompt);
  late final body = TextEditingController(text: widget.q.body);
  late final answer = TextEditingController(text: widget.q.answer);
  late double marks = widget.q.marks;
  late bool two = widget.q.twoCols;
  bool kb = false;

  void _ins(String s) {
    final t = body.text, sel = body.selection;
    final i = sel.isValid ? sel.start : t.length;
    body.value = TextEditingValue(text: t.replaceRange(i, i, s), selection: TextSelection.collapsed(offset: i + s.length));
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('قوالب جاهزة', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 6, children: _templates.entries.map((t) => ActionChip(
                  label: Text(t.key),
                  onPressed: () => setState(() {
                    prompt.text = t.value[0];
                    body.text = t.value[1];
                    two = t.value[2] == 'true';
                  }),
                )).toList()),
            const SizedBox(height: 10),
            TextField(controller: prompt, decoration: const InputDecoration(labelText: 'نص التوجيه', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: FilledButton.tonalIcon(onPressed: () => setState(() => kb = !kb), icon: const Icon(Icons.calculate), label: Text(kb ? 'إخفاء كيبورد الرياضيات' : 'كيبورد الرياضيات'))),
            if (kb) MathKeyboard(onInsert: (t) => setState(() => _ins(t))),
            const SizedBox(height: 4),
            TextField(controller: body, onChanged: (_) => setState(() {}), minLines: 5, maxLines: 10, decoration: const InputDecoration(labelText: 'محتوى السؤال (سطر لكل فقرة)', border: OutlineInputBorder())),
            if (body.text.contains('⟦'))
              Container(
                margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(8), width: double.infinity,
                decoration: BoxDecoration(border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final l in body.text.split('\n')) MathLine(l)]),
              ),
            const SizedBox(height: 8),
            TextField(controller: answer, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'الإجابة النموذجية', border: OutlineInputBorder())),
            Row(children: [
              const Text('الدرجة:'),
              Expanded(child: Slider(value: marks, min: 1, max: 20, divisions: 38, label: marks.toString(), onChanged: (v) => setState(() => marks = v))),
              Text(marks.toStringAsFixed(1)),
            ]),
            SwitchListTile(title: const Text('عمودان (توفير ورق)'), value: two, onChanged: (v) => setState(() => two = v)),
            FilledButton(
                onPressed: () => Navigator.pop(context, Question(prompt: prompt.text, body: body.text, answer: answer.text, marks: marks, twoCols: two)),
                child: const Text('تأكيد السؤال')),
          ]),
        ),
      );
}
