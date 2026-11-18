// lib/models/video_model.dart
//
// Representa um vídeo publicado no UniTime.
// O custo é SEMPRE derivado da duração: nunca é digitado nem salvo à parte.

class VideoModel {
  // ---------- Regras de tempo e preço ----------
  /// 10 créditos por minuto COMPLETO.
  static const int creditsPerMinute = 10;

  /// Piso mínimo de cobrança: 1 minuto (= 10 créditos).
  static const int minBillableMinutes = 1;

  /// Limite de duração do envio (~15 minutos).
  static const int maxDurationSeconds = 15 * 60;

  // ---------- Dados do vídeo ----------
  final String id;
  final String authorRgm; // RGM do autor (liga ao UserModel)
  final String title;
  final String description;
  final String mainTopic; // tópico principal (obrigatório)
  final String? subTopic; // sub-tópico (opcional)
  final int durationSeconds; // fonte única da verdade para o preço
  final String? thumbnailPath;
  final String? videoPath;
  final int views;
  final int likes;
  final DateTime createdAt;

  /// Marcação de destaque (Top 20) feita direto no banco local,
  /// para controle de apresentação do protótipo.
  final bool isTop20;

  const VideoModel({
    required this.id,
    required this.authorRgm,
    required this.title,
    required this.description,
    required this.mainTopic,
    this.subTopic,
    required this.durationSeconds,
    this.thumbnailPath,
    this.videoPath,
    this.views = 0,
    this.likes = 0,
    required this.createdAt,
    this.isTop20 = false,
  }) : assert(durationSeconds >= 0, 'A duração não pode ser negativa.');

  // ---------- Economia ----------

  /// Minutos inteiros fechados, com piso de 1 minuto.
  /// Ex.: 0:45 -> 1 | 1:59 -> 1 | 2:00 -> 2 | 2:59 -> 2
  int get billableMinutes {
    final fullMinutes = durationSeconds ~/ 60; // divisão inteira: sem decimais
    return fullMinutes < minBillableMinutes ? minBillableMinutes : fullMinutes;
  }

  /// Custo de desbloqueio em créditos (1:00 a 1:59 = 10; 2:00 a 2:59 = 20...).
  int get creditCost => billableMinutes * creditsPerMinute;

  /// Verdadeiro se a duração respeita o limite de envio.
  bool get isWithinMaxDuration => durationSeconds <= maxDurationSeconds;

  /// O autor nunca compra o próprio vídeo: o acesso dele é liberado sem débito.
  bool isOwnedBy(String rgm) => authorRgm == rgm;

  // ---------- Exibição ----------

  /// Duração no formato m:ss (ex.: 2:05), para os cards e o player.
  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // ---------- Cópia e conversão ----------

  /// Cópia alterando campos. Duração e autor ficam de fora de propósito:
  /// a edição de metadados (título, descrição, tópico) NÃO muda o preço.
  /// Use clearSubTopic para remover o sub-tópico.
  VideoModel copyWith({
    String? title,
    String? description,
    String? mainTopic,
    String? subTopic,
    bool clearSubTopic = false,
    int? views,
    int? likes,
    bool? isTop20,
  }) {
    return VideoModel(
      id: id,
      authorRgm: authorRgm,
      title: title ?? this.title,
      description: description ?? this.description,
      mainTopic: mainTopic ?? this.mainTopic,
      subTopic: clearSubTopic ? null : (subTopic ?? this.subTopic),
      durationSeconds: durationSeconds,
      thumbnailPath: thumbnailPath,
      videoPath: videoPath,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      createdAt: createdAt,
      isTop20: isTop20 ?? this.isTop20,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'authorRgm': authorRgm,
      'title': title,
      'description': description,
      'mainTopic': mainTopic,
      'subTopic': subTopic,
      'durationSeconds': durationSeconds,
      'thumbnailPath': thumbnailPath,
      'videoPath': videoPath,
      'views': views,
      'likes': likes,
      'createdAt': createdAt.toIso8601String(),
      'isTop20': isTop20,
    };
  }

  factory VideoModel.fromMap(Map<String, dynamic> map) {
    return VideoModel(
      id: map['id'] as String,
      authorRgm: map['authorRgm'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      mainTopic: map['mainTopic'] as String,
      subTopic: map['subTopic'] as String?,
      durationSeconds: (map['durationSeconds'] as num).toInt(),
      thumbnailPath: map['thumbnailPath'] as String?,
      videoPath: map['videoPath'] as String?,
      views: (map['views'] as num?)?.toInt() ?? 0,
      likes: (map['likes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      isTop20: map['isTop20'] as bool? ?? false,
    );
  }

  // Dois vídeos são o mesmo quando têm o mesmo id.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is VideoModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VideoModel($id, $title, $creditCost créditos)';
}
