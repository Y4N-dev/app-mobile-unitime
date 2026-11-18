// lib/services/credit_service.dart
//
// CORAÇÃO DA ECONOMIA do UniTime. TODAS as contas de créditos ficam aqui:
// as telas apenas chamam estes métodos e mostram a mensagem do resultado.
//
// Regras fixas:
//  - 10 créditos por minuto inteiro (custo vem de VideoModel.creditCost)
//  - Desbloqueio: comprador paga o valor exato; autor recebe 100%
//  - Autor NUNCA compra o próprio vídeo (acesso livre, sem histórico)
//  - Edição de metadados: 10 créditos fixos, que SAEM DE CIRCULAÇÃO
//  - Exclusão: compradores recebem 100% de volta; autor perde 100% dos
//    créditos ganhos com o vídeo
//  - PISO DE SEGURANÇA: nenhum saldo fica abaixo de 0

import '../data/mock_database.dart';
import '../models/credit_transaction_model.dart';
import '../models/video_model.dart';

/// Resultado possível de cada operação.
enum CreditStatus {
  success, // operação concluída
  ownerAccess, // autor abrindo o próprio vídeo (sem débito)
  alreadyUnlocked, // vídeo já comprado antes (sem nova cobrança)
  insufficientBalance, // saldo menor que o custo: compra bloqueada
  videoNotFound,
  userNotFound,
  notOwner, // só o autor pode editar ou excluir
  invalidInput, // campo vazio, justificativa ausente etc.
  invalidTopic, // tópico fora da lista oficial
  nothingChanged, // edição sem nenhuma alteração (não cobra)
}

/// Resposta padronizada: a tela só precisa ler [message] e [canWatch].
class CreditResult {
  final CreditStatus status;
  final String message; // texto pronto para exibir ao usuário
  final int amount; // valor principal movimentado (custo, taxa etc.)
  final int refundedTotal; // exclusão: total devolvido aos compradores
  final int refundedUsers; // exclusão: quantos compradores receberam
  final int penaltyDue; // exclusão: penalidade devida (100% do ganho)
  final int penaltyApplied; // exclusão: penalidade realmente aplicada (piso 0)

  const CreditResult({
    required this.status,
    required this.message,
    this.amount = 0,
    this.refundedTotal = 0,
    this.refundedUsers = 0,
    this.penaltyDue = 0,
    this.penaltyApplied = 0,
  });

  factory CreditResult.fail(CreditStatus status, String message) =>
      CreditResult(status: status, message: message);

  /// Operação concluída com sucesso.
  bool get isSuccess => status == CreditStatus.success;

  /// Para o desbloqueio: o player pode ser aberto?
  bool get canWatch =>
      status == CreditStatus.success ||
      status == CreditStatus.ownerAccess ||
      status == CreditStatus.alreadyUnlocked;
}

class CreditService {
  CreditService._();
  static final CreditService instance = CreditService._();

  MockDatabase get _db => MockDatabase.instance;

  // =====================================================================
  // CONSULTAS (para as telas decidirem o que mostrar)
  // =====================================================================

  /// Saldo atual do aluno (0 se não existir).
  int getBalance(String rgm) => _db.getUserByRgm(rgm)?.credits ?? 0;

  /// O aluno tem saldo suficiente para este vídeo?
  bool canAfford(String rgm, VideoModel video) =>
      getBalance(rgm) >= video.creditCost;

  // =====================================================================
  // 1) DESBLOQUEIO
  // =====================================================================

  /// Chamar SOMENTE depois que o usuário tocar em "Sim!" no pop-up.
  CreditResult unlockVideo({
    required String videoId,
    required String buyerRgm,
  }) {
    final video = _db.getVideoById(videoId);
    if (video == null) {
      return CreditResult.fail(
          CreditStatus.videoNotFound, 'Este vídeo não está mais disponível.');
    }
    final buyer = _db.getUserByRgm(buyerRgm);
    if (buyer == null) {
      return CreditResult.fail(
          CreditStatus.userNotFound, 'Usuário não encontrado.');
    }

    // Autor: acesso livre. Sem débito e SEM entrar no histórico.
    if (video.isOwnedBy(buyerRgm)) {
      return const CreditResult(
        status: CreditStatus.ownerAccess,
        message: 'Este vídeo é seu: acesso liberado sem custo.',
      );
    }

    // Já comprado: libera de novo, sem cobrar duas vezes.
    if (_db.hasUnlocked(buyerRgm, videoId)) {
      return const CreditResult(
        status: CreditStatus.alreadyUnlocked,
        message: 'Você já desbloqueou este vídeo.',
      );
    }

    // Saldo insuficiente: transação bloqueada (sem tolerância).
    final cost = video.creditCost;
    if (buyer.credits < cost) {
      return CreditResult.fail(
        CreditStatus.insufficientBalance,
        'Saldo insuficiente: o vídeo custa $cost créditos e você tem '
        '${buyer.credits}.',
      );
    }

    // O autor precisa existir ANTES de mexer em qualquer saldo.
    if (_db.getUserByRgm(video.authorRgm) == null) {
      return CreditResult.fail(
          CreditStatus.userNotFound, 'Autor do vídeo não encontrado.');
    }

    // Tudo validado: debita o comprador e credita 100% ao autor.
    _changeBalance(buyerRgm, -cost);
    _changeBalance(video.authorRgm, cost);
    _record(buyerRgm, CreditTransactionType.unlockSpend, cost, video);
    _record(video.authorRgm, CreditTransactionType.unlockEarning, cost, video);

    return CreditResult(
      status: CreditStatus.success,
      message: 'Vídeo desbloqueado! Foram debitados $cost créditos.',
      amount: cost,
    );
  }

  // =====================================================================
  // 2) EDIÇÃO DE METADADOS (título, descrição, tópico principal)
  // =====================================================================

  /// Custo FIXO de 10 créditos por edição, seja 1 campo ou todos juntos.
  /// Os créditos SAEM DE CIRCULAÇÃO (não vão para nenhum usuário).
  /// Envie apenas os campos que o autor quer alterar.
  CreditResult editVideoMetadata({
    required String videoId,
    required String authorRgm,
    String? title,
    String? description,
    String? mainTopic,
  }) {
    final video = _db.getVideoById(videoId);
    if (video == null) {
      return CreditResult.fail(
          CreditStatus.videoNotFound, 'Este vídeo não está mais disponível.');
    }
    final author = _db.getUserByRgm(authorRgm);
    if (author == null) {
      return CreditResult.fail(
          CreditStatus.userNotFound, 'Usuário não encontrado.');
    }
    if (!video.isOwnedBy(authorRgm)) {
      return CreditResult.fail(
          CreditStatus.notOwner, 'Só o autor pode editar este vídeo.');
    }

    // Normaliza os campos enviados (null = não alterar).
    final newTitle = title?.trim();
    final newDescription = description?.trim();
    final newTopic = mainTopic?.trim();

    if ((newTitle != null && newTitle.isEmpty) ||
        (newDescription != null && newDescription.isEmpty) ||
        (newTopic != null && newTopic.isEmpty)) {
      return CreditResult.fail(CreditStatus.invalidInput,
          'Título, descrição e tópico não podem ficar vazios.');
    }
    if (newTopic != null && !MockDatabase.topics.contains(newTopic)) {
      return CreditResult.fail(
          CreditStatus.invalidTopic, 'Escolha um tópico válido da lista.');
    }

    // Só cobra se algo realmente mudou.
    final changed = (newTitle != null && newTitle != video.title) ||
        (newDescription != null && newDescription != video.description) ||
        (newTopic != null && newTopic != video.mainTopic);
    if (!changed) {
      return CreditResult.fail(CreditStatus.nothingChanged,
          'Nenhuma alteração feita: nada foi cobrado.');
    }

    const fee = CreditTransactionModel.editFeeCredits;
    if (author.credits < fee) {
      return CreditResult.fail(
        CreditStatus.insufficientBalance,
        'Saldo insuficiente: cada edição custa $fee créditos e você tem '
        '${author.credits}.',
      );
    }

    // Cobra a taxa (créditos saem de circulação) e aplica a edição.
    _changeBalance(authorRgm, -fee);
    _record(authorRgm, CreditTransactionType.editFee, fee, video);
    _db.updateVideo(video.copyWith(
      title: newTitle,
      description: newDescription,
      mainTopic: newTopic,
    ));

    return CreditResult(
      status: CreditStatus.success,
      message: 'Vídeo atualizado! Foram cobrados $fee créditos pela edição.',
      amount: fee,
    );
  }

  // =====================================================================
  // 3) EXCLUSÃO COM ESTORNO E PENALIDADE
  // =====================================================================

  /// Regras:
  ///  - A justificativa é obrigatória.
  ///  - Cada comprador recebe de volta 100% do que gastou.
  ///  - O autor perde 100% dos créditos GANHOS com este vídeo.
  ///  - Se a penalidade passar do saldo do autor, o saldo trava em 0.
  CreditResult deleteVideo({
    required String videoId,
    required String authorRgm,
    required String justification,
  }) {
    final video = _db.getVideoById(videoId);
    if (video == null) {
      return CreditResult.fail(
          CreditStatus.videoNotFound, 'Este vídeo não está mais disponível.');
    }
    final author = _db.getUserByRgm(authorRgm);
    if (author == null) {
      return CreditResult.fail(
          CreditStatus.userNotFound, 'Usuário não encontrado.');
    }
    if (!video.isOwnedBy(authorRgm)) {
      return CreditResult.fail(
          CreditStatus.notOwner, 'Só o autor pode excluir este vídeo.');
    }
    if (justification.trim().isEmpty) {
      return CreditResult.fail(CreditStatus.invalidInput,
          'Informe a justificativa para excluir o vídeo.');
    }

    final movements = _db.getTransactionsByVideo(videoId);

    // --- Estorno de 100% a cada comprador ---
    var refundedTotal = 0;
    final refundedUsers = <String>{};
    for (final purchase in movements) {
      if (purchase.type != CreditTransactionType.unlockSpend) continue;
      if (_db.getUserByRgm(purchase.userRgm) == null) continue;
      _changeBalance(purchase.userRgm, purchase.amount);
      _record(purchase.userRgm, CreditTransactionType.deletionRefund,
          purchase.amount, video);
      refundedTotal += purchase.amount;
      refundedUsers.add(purchase.userRgm);
    }

    // --- Penalidade do autor: 100% do que ele ganhou com este vídeo ---
    var penaltyDue = 0;
    for (final earning in movements) {
      if (earning.type == CreditTransactionType.unlockEarning) {
        penaltyDue += earning.amount;
      }
    }
    final authorBalance = getBalance(authorRgm);
    // PISO DE 0: nunca desconta mais do que o autor possui.
    final penaltyApplied =
        penaltyDue > authorBalance ? authorBalance : penaltyDue;
    if (penaltyApplied > 0) {
      _changeBalance(authorRgm, -penaltyApplied);
      _record(authorRgm, CreditTransactionType.deletionPenalty, penaltyApplied,
          video);
    }

    // --- Remove o vídeo (o extrato antigo continua guardado) ---
    _db.deleteVideo(videoId);

    var message = 'Vídeo excluído.';
    if (refundedUsers.isNotEmpty) {
      message += ' ${refundedUsers.length} aluno(s) receberam '
          '$refundedTotal créditos de volta.';
    }
    if (penaltyApplied > 0) {
      message += ' Você perdeu $penaltyApplied créditos';
      message += penaltyApplied < penaltyDue
          ? ' (seu saldo foi zerado: o piso é 0 créditos).'
          : '.';
    }

    return CreditResult(
      status: CreditStatus.success,
      message: message,
      refundedTotal: refundedTotal,
      refundedUsers: refundedUsers.length,
      penaltyDue: penaltyDue,
      penaltyApplied: penaltyApplied,
    );
  }

  // =====================================================================
  // AUXILIARES PRIVADOS
  // =====================================================================

  /// Soma (ou subtrai) créditos respeitando o PISO DE 0.
  void _changeBalance(String rgm, int delta) {
    final user = _db.getUserByRgm(rgm);
    if (user == null) return;
    final newBalance = user.credits + delta;
    _db.updateUser(user.copyWith(credits: newBalance < 0 ? 0 : newBalance));
  }

  /// Grava a movimentação no extrato, com cópia do título do vídeo.
  void _record(
    String rgm,
    CreditTransactionType type,
    int amount,
    VideoModel video,
  ) {
    _db.addTransaction(CreditTransactionModel(
      id: _db.nextTransactionId(),
      userRgm: rgm,
      type: type,
      amount: amount,
      videoId: video.id,
      videoTitle: video.title,
      createdAt: DateTime.now(),
    ));
  }
}
