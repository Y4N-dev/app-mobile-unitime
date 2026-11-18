// lib/models/user_model.dart
//
// Representa um aluno da UNIPÊ dentro do UniTime.
// Dados institucionais são FIXOS (vêm do mock_database.dart).
// Apenas saldo, contador "Principal", foto e biografia podem mudar.

class UserModel {
  /// Fundo inicial (bootstrap): 100 créditos = 10 minutos de consumo.
  /// Valor único e estático: o sistema NUNCA recarrega automaticamente.
  static const int bootstrapCredits = 100;

  // ---------- Dados institucionais (inalteráveis) ----------
  final String rgm; // ID acadêmico: serve como identificador único do aluno
  final String fullName;
  final String course;
  final int semester;
  final String institutionalEmail; // e-mail no padrão DUDA
  final String password; // somente para o login simulado (mock)

  // ---------- Dados que podem mudar ----------
  final int credits; // saldo atual (nunca negativo)
  final int principalCount; // vezes que figurou no Top 20 (ícone de chama)
  final String? photoPath; // foto de perfil (editável)
  final String? bio; // biografia opcional

  const UserModel({
    required this.rgm,
    required this.fullName,
    required this.course,
    required this.semester,
    required this.institutionalEmail,
    required this.password,
    this.credits = bootstrapCredits,
    this.principalCount = 0,
    this.photoPath,
    this.bio,
  }) : assert(credits >= 0, 'O saldo de créditos nunca pode ser negativo.');

  /// Cria uma cópia alterando apenas os campos mutáveis.
  /// Os dados institucionais não possuem parâmetro aqui de propósito.
  /// Use clearPhoto / clearBio para remover foto ou biografia.
  UserModel copyWith({
    int? credits,
    int? principalCount,
    String? photoPath,
    String? bio,
    bool clearPhoto = false,
    bool clearBio = false,
  }) {
    return UserModel(
      rgm: rgm,
      fullName: fullName,
      course: course,
      semester: semester,
      institutionalEmail: institutionalEmail,
      password: password,
      credits: credits ?? this.credits,
      principalCount: principalCount ?? this.principalCount,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      bio: clearBio ? null : (bio ?? this.bio),
    );
  }

  /// Converte para Map (útil para o mock_database ou persistência futura).
  Map<String, dynamic> toMap() {
    return {
      'rgm': rgm,
      'fullName': fullName,
      'course': course,
      'semester': semester,
      'institutionalEmail': institutionalEmail,
      'password': password,
      'credits': credits,
      'principalCount': principalCount,
      'photoPath': photoPath,
      'bio': bio,
    };
  }

  /// Cria o usuário a partir de um Map.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      rgm: map['rgm'] as String,
      fullName: map['fullName'] as String,
      course: map['course'] as String,
      semester: (map['semester'] as num).toInt(),
      institutionalEmail: map['institutionalEmail'] as String,
      password: map['password'] as String,
      credits: (map['credits'] as num?)?.toInt() ?? bootstrapCredits,
      principalCount: (map['principalCount'] as num?)?.toInt() ?? 0,
      photoPath: map['photoPath'] as String?,
      bio: map['bio'] as String?,
    );
  }

  // Dois usuários são o mesmo aluno quando têm o mesmo RGM.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is UserModel && other.rgm == rgm);

  @override
  int get hashCode => rgm.hashCode;

  @override
  String toString() => 'UserModel($rgm, $fullName, $credits créditos)';
}
