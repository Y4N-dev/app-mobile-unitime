// lib/models/video_feedback_model.dart
//
// Retorno dos alunos sobre um vídeo: COMENTÁRIOS e AVALIAÇÕES.
// Guardados em memória pelo MockDatabase (futuramente, no banco online).
// O nome do autor é uma cópia da hora do envio: a lista continua legível
// mesmo se os dados do aluno mudarem.

/// Comentário livre sob o vídeo.
class CommentModel {
  /// Limite de caracteres do texto.
  static const int maxLength = 300;

  final String id;
  final String videoId;
  final String authorRgm;
  final String authorName;
  final String text;
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.videoId,
    required this.authorRgm,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'videoId': videoId,
      'authorRgm': authorRgm,
      'authorName': authorName,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    return CommentModel(
      id: map['id'] as String,
      videoId: map['videoId'] as String,
      authorRgm: map['authorRgm'] as String,
      authorName: map['authorName'] as String,
      text: map['text'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CommentModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Comment($id, $authorRgm, video $videoId)';
}

/// Avaliação de 1 a 5 estrelas, com texto OPCIONAL.
/// Regra: uma avaliação por aluno em cada vídeo (a nova substitui a antiga).
class RatingModel {
  static const int minStars = 1;
  static const int maxStars = 5;

  /// Limite de caracteres do texto opcional.
  static const int maxTextLength = 300;

  final String id;
  final String videoId;
  final String authorRgm;
  final String authorName;
  final int stars; // de 1 a 5
  final String? text; // opcional: nulo quando o aluno só dá as estrelas
  final DateTime createdAt;

  const RatingModel({
    required this.id,
    required this.videoId,
    required this.authorRgm,
    required this.authorName,
    required this.stars,
    this.text,
    required this.createdAt,
  }) : assert(stars >= minStars && stars <= maxStars,
            'A nota deve ficar entre 1 e 5 estrelas.');

  /// Tem texto para exibir abaixo das estrelas?
  bool get hasText => text != null && text!.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'videoId': videoId,
      'authorRgm': authorRgm,
      'authorName': authorName,
      'stars': stars,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RatingModel.fromMap(Map<String, dynamic> map) {
    return RatingModel(
      id: map['id'] as String,
      videoId: map['videoId'] as String,
      authorRgm: map['authorRgm'] as String,
      authorName: map['authorName'] as String,
      stars: (map['stars'] as num).toInt(),
      text: map['text'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is RatingModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Rating($id, $authorRgm, $stars estrelas)';
}
