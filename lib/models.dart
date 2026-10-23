import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Student {
  String name, seat, secret;
  Student(this.name, this.seat, this.secret);
  Map<String, dynamic> toJson() => {'n': name, 's': seat, 'c': secret};
  factory Student.fromJson(Map j) => Student(j['n'] ?? '', j['s'] ?? '', j['c'] ?? '');
}

class Question {
  String prompt, body, answer;
  double marks;
  bool twoCols;
  Question({this.prompt = '', this.body = '', this.answer = '', this.marks = 5, this.twoCols = false});
  Map<String, dynamic> toJson() =>
      {'p': prompt, 'b': body, 'a': answer, 'm': marks, 't': twoCols};
  factory Question.fromJson(Map j) => Question(
      prompt: j['p'] ?? '', body: j['b'] ?? '', answer: j['a'] ?? '',
      marks: (j['m'] ?? 5).toDouble(), twoCols: j['t'] ?? false);
}

class Exam {
  String id, title, subject, grade, date, duration, period, closing, teacher, rightLines, omrKey;
  int omrCount;
  List<Question> qs;
  List<Student> students;
  List<Map<String, dynamic>> results;
  Exam({
    String? id,
    this.title = 'اختبار نهاية الفصل الدراسي الأول',
    this.subject = '', this.grade = '', this.date = '', this.duration = 'ساعتان',
    this.period = 'واحدة',
    this.closing = 'انتهت الأسئلة مع تمنياتنا لكم بالتوفيق والنجاح',
    this.teacher = 'معلم المادة: ......................',
    this.rightLines =
        'الجمهورية اليمنية\nوزارة التربية والتعليم والبحث العلمي\nمكتب التربية والتعليم بالمحافظة: ....\nمكتب التربية والتعليم بالمديرية: ....\nالمدرسة: ....',
    this.omrKey = '', this.omrCount = 20,
    List<Question>? qs, List<Student>? students, List<Map<String, dynamic>>? results,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        qs = qs ?? [],
        students = students ?? [],
        results = results ?? [];
  double get total => qs.fold(0.0, (a, q) => a + q.marks);
  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'subject': subject, 'grade': grade, 'date': date,
        'duration': duration, 'period': period, 'closing': closing, 'teacher': teacher,
        'rightLines': rightLines, 'omrKey': omrKey, 'omrCount': omrCount,
        'qs': qs.map((e) => e.toJson()).toList(),
        'students': students.map((e) => e.toJson()).toList(),
        'results': results,
      };
  factory Exam.fromJson(Map j) => Exam(
        id: j['id'], title: j['title'] ?? '', subject: j['subject'] ?? '',
        grade: j['grade'] ?? '', date: j['date'] ?? '', duration: j['duration'] ?? '',
        period: j['period'] ?? '', closing: j['closing'] ?? '', teacher: j['teacher'] ?? '',
        rightLines: j['rightLines'] ?? '', omrKey: j['omrKey'] ?? '',
        omrCount: j['omrCount'] ?? 20,
        qs: ((j['qs'] ?? []) as List).map((e) => Question.fromJson(e)).toList(),
        students: ((j['students'] ?? []) as List).map((e) => Student.fromJson(e)).toList(),
        results: ((j['results'] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList(),
      );
}

class Store {
  static Future<File> _f() async {
    final d = await getApplicationDocumentsDirectory();
    return File('${d.path}/exams.json');
  }

  static Future<List<Exam>> load() async {
    final f = await _f();
    if (!await f.exists()) return [];
    return (jsonDecode(await f.readAsString()) as List).map((e) => Exam.fromJson(e)).toList();
  }

  static Future<void> save(List<Exam> l) async =>
      (await _f()).writeAsString(jsonEncode(l.map((e) => e.toJson()).toList()));
}
