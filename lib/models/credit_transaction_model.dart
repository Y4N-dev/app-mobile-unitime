// lib/models/credit_transaction_model.dart
//
// Registro de UMA movimentação de créditos de UM usuário.
// Alimenta a aba Métricas (ganhos, gastos e histórico de desbloqueados)
// e permite ao credit_service localizar os compradores de um vídeo
// para devolver 100% dos créditos quando o autor o exclui.

/// Tipos de movimentação. A direção (entrada ou saída) vem do tipo.
enum CreditTransactionType {
  bootstrap, // entrada: fundo inicial de 100 créditos (único, sem recarga)
  unlockSpend, // saída: compra de um vídeo (desbloqueio)
  unlockEarning, // entrada: autor recebe 100% do valor pago
  deletionRefund, // entrada: comprador recebe 100% de volta (vídeo excluído)
  deletionPenalty, // saída: autor perde 100% dos créditos ganhos com o vídeo
  editFee, // saída: 10 créditos por edição (saem de circulação)
}

class CreditTransactionModel {
  /// Custo fixo de cada edição de metadados (título, descrição, tópico).
  static const int editFeeCredits = 10;

  final String id;
  final String userRgm; // dono da movimentação (UserModel.rgm)
  final CreditTransactionType type;

  /// Valor SEMPRE positivo (nunca negativo).
  /// Na penalidade, grava o valor REALMENTE descontado: se o piso de 0
  /// limitou o desconto, o registro reflete o que de fato saiu do saldo.
  final int amount;

  final String? videoId; // vídeo relacionado (nulo no bootstrap)

  /// Cópia do título no momento da transação: o extrato continua
  /// legível mesmo se o vídeo for excluído depois.
  final String? videoTitle;

  final DateTime createdAt;

  const CreditTransactionModel({
    required this.id,
    required this.userRgm,
    required this.type,
    required this.amount,
    this.videoId,
    this.videoTitle,
    required this.createdAt,
  }) : assert(amount >= 0, 'O valor da movimentação não pode ser negativo.');

  // ---------- Direção da movimentação ----------

  /// Entrada de créditos (aparece em "ganhos").
  bool get isIncome =>
      type == CreditTransactionType.bootstrap ||
      type == CreditTransactionType.unlockEarning ||
      type == CreditTransactionType.deletionRefund;

  /// Saída de créditos (aparece em "gastos").
  bool get isExpense => !isIncome;

  /// Valor com sinal, só para exibição (+30 ou -30).
  int get signedAmount => isIncome ? amount : -amount;

  /// Esta movimentação é um desbloqueio feito pelo próprio usuário?
  /// Usada para montar o histórico de vídeos desbloqueados.
  bool get isUnlockPurchase => type == CreditTransactionType.unlockSpend;

  // ---------- Exibição ----------

  /// Descrição curta para a lista de Métricas.
  String get description {
    final title = videoTitle ?? 'vídeo';
    switch (type) {
      case CreditTransactionType.bootstrap:
        return 'Fundo inicial de boas-vindas';
      case CreditTransactionType.unlockSpend:
        return 'Desbloqueio: $title';
      case CreditTransactionType.unlockEarning:
        return 'Ganho com o vídeo: $title';
      case CreditTransactionType.deletionRefund:
        return 'Estorno (vídeo excluído): $title';
      case CreditTransactionType.deletionPenalty:
        return 'Penalidade por exclusão: $title';
      case CreditTransactionType.editFee:
        return 'Edição de metadados: $title';
    }
  }

  // ---------- Conversão ----------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userRgm': userRgm,
      'type': type.name,
      'amount': amount,
      'videoId': videoId,
      'videoTitle': videoTitle,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CreditTransactionModel.fromMap(Map<String, dynamic> map) {
    return CreditTransactionModel(
      id: map['id'] as String,
      userRgm: map['userRgm'] as String,
      type:
          CreditTransactionType.values.firstWhere((t) => t.name == map['type']),
      amount: (map['amount'] as num).toInt(),
      videoId: map['videoId'] as String?,
      videoTitle: map['videoTitle'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CreditTransactionModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CreditTransaction($id, ${type.name}, $signedAmount, $userRgm)';
}
