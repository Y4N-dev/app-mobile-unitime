// lib/models/xp_entry_model.dart
//
// Registro de um XP RESGATADO (um por missão e por dia).
// O XP total do aluno e o nível NÃO ficam guardados no aluno: são sempre
// calculados somando estes registros (uma só fonte da verdade). A sequência
// de dias também sai daqui (os dias em que houve algum resgate).
//
// Os níveis são SIMBÓLICOS: nada disto altera créditos, preços ou acessos.

class XpEntryModel {
  final String id;
  final String userRgm;

  /// Qual missão foi resgatada (ex.: "like", "comment"). Os códigos são
  /// definidos no mission_service.dart.
  final String missionId;

  /// Dia da missão no formato "2026-11-15". O resgate só vale no MESMO dia.
  final String dayKey;

  final int xp;
  final DateTime createdAt;

  const XpEntryModel({
    required this.id,
    required this.userRgm,
    required this.missionId,
    required this.dayKey,
    required this.xp,
    required this.createdAt,
  });

  // ---------- Datas (dia local, virando à meia-noite) ----------

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// DateTime -> "2026-11-15"
  static String dayKeyOf(DateTime date) =>
      '${date.year}-${_two(date.month)}-${_two(date.day)}';

  /// "2026-11-15" -> DateTime (meia-noite desse dia). Nulo se inválido.
  static DateTime? dayFromKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  // ---------- Conversão ----------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userRgm': userRgm,
      'missionId': missionId,
      'dayKey': dayKey,
      'xp': xp,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory XpEntryModel.fromMap(Map<String, dynamic> map) {
    return XpEntryModel(
      id: map['id'] as String,
      userRgm: map['userRgm'] as String,
      missionId: map['missionId'] as String,
      dayKey: map['dayKey'] as String,
      xp: (map['xp'] as num).toInt(),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is XpEntryModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'XpEntry($id, $userRgm, $missionId, $dayKey, +$xp)';
}
