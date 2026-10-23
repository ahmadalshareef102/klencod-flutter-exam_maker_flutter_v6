import 'dart:ui' show Offset;

/// إحداثيات ورقة OMR بالنقاط (A4 = 595×842) - مشتركة بين الطباعة والتصحيح
class OmrLayout {
  static const markers = [Offset(42, 42), Offset(553, 42), Offset(42, 800), Offset(553, 800)]; // TL,TR,BL,BR
  static const rowsPerCol = 25;

  /// مركز دائرة الخيار idx (0=أ ... 3=د) للسؤال q. العمود الأول على اليمين، و(أ) أقصى اليمين.
  static Offset center(int q, int idx) {
    final col = q ~/ rowsPerCol, r = q % rowsPerCol;
    final base = col == 0 ? 350.0 : 110.0;
    return Offset(base + (3 - idx) * 30, 215 + r * 22.0);
  }

  static Offset numPos(int q) {
    final col = q ~/ rowsPerCol, r = q % rowsPerCol;
    return Offset(col == 0 ? 462.0 : 222.0, 215 + r * 22.0);
  }
}
