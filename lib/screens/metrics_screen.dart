// lib/screens/metrics_screen.dart
//
// Aba "Métricas de Créditos": o painel do aluno no Banco de Tempo.
// Rolagem única, na ordem:
//   1. Saldo e estimativas de uso        4. Vídeos desbloqueados
//   2. Período + balanço de tempo        5. Rendimento dos meus vídeos
//   3. Resumo de ganhos e gastos         6. Extrato de créditos
//
// Esta tela só DESENHA: todos os cálculos vêm do MetricsService e nenhuma
// regra de créditos é executada aqui (isso é papel do credit_service.dart).
//
// Cores do extrato: ganhos = verde | gastos = amarelo (etiqueta com texto
// preto, para manter a leitura) | penalidade = vermelho.

import 'package:flutter/material.dart';

import '../data/mock_database.dart';
import '../models/credit_transaction_model.dart';
import '../models/video_model.dart';
import '../services/metrics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/uni_star.dart';
import '../widgets/video_thumbnail.dart';
import 'watch_screen.dart';

/// Tipo de valor, que define a cor (ganho, gasto ou penalidade).
enum _Tone { income, expense, penalty }

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({Key? key}) : super(key: key);

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  static const int _statementPage = 20; // itens do extrato por vez
  static const int _unlockedPreview = 5; // desbloqueados antes do "Ver todos"

  final MockDatabase _db = MockDatabase.instance;
  final MetricsService _metrics = MetricsService.instance;

  MetricsPeriod _period = MetricsPeriod.all;
  StatementFilter _filter = StatementFilter.all;
  int _statementLimit = _statementPage;
  bool _showAllUnlocked = false;

  // =====================================================================
  // INTERFACE
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Métricas de Créditos'),
      ),
      // Reconstrói sempre que o banco avisa uma mudança (compra, ganho...).
      body: AnimatedBuilder(
        animation: _db,
        builder: (context, _) {
          final user = _db.currentUser;
          if (user == null) return const SizedBox.shrink();
          final rgm = user.rgm;

          final estimates = _metrics.estimates(rgm);
          final summary = _metrics.summary(rgm, _period);
          final statement = _metrics.statement(rgm, _period, _filter);
          final unlocked = _metrics.unlockedHistory(rgm);
          final earnings = _metrics.videoEarnings(rgm);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // 1. Saldo e estimativas de uso
              _buildBalance(user.credits, estimates),
              const SizedBox(height: 28),

              // 2. Período + balanço de tempo
              _sectionTitle(
                'Período',
                subtitle: 'Vale para o balanço de tempo, o resumo e o extrato.',
              ),
              _ChoiceChips<MetricsPeriod>(
                options: MetricsPeriod.values,
                selected: _period,
                labelOf: (p) => p.label,
                onSelected: (p) => setState(() {
                  _period = p;
                  _statementLimit = _statementPage;
                }),
              ),
              const SizedBox(height: 16),
              _buildTimeBalance(summary),
              const SizedBox(height: 28),

              // 3. Resumo de ganhos e gastos
              _sectionTitle('Resumo de ganhos e gastos'),
              _buildSummary(summary),
              const SizedBox(height: 28),

              // 4. Vídeos desbloqueados
              _sectionTitle(
                'Vídeos desbloqueados',
                subtitle: 'Atalho para assistir de novo, sem nova cobrança.',
              ),
              _buildUnlocked(unlocked),
              const SizedBox(height: 28),

              // 5. Rendimento dos meus vídeos
              _sectionTitle(
                'Rendimento dos meus vídeos',
                subtitle: 'Quanto cada vídeo seu já rendeu em créditos.',
              ),
              _buildEarnings(earnings),
              const SizedBox(height: 28),

              // 6. Extrato de créditos
              _sectionTitle(
                'Extrato de créditos',
                subtitle: 'Período: ${_period.label}',
              ),
              _ChoiceChips<StatementFilter>(
                options: StatementFilter.values,
                selected: _filter,
                labelOf: (f) => f.label,
                onSelected: (f) => setState(() {
                  _filter = f;
                  _statementLimit = _statementPage;
                }),
              ),
              const SizedBox(height: 12),
              _buildStatement(statement),
            ],
          );
        },
      ),
    );
  }

  // ---------- Blocos reutilizáveis ----------
  /// Título de seção com sublinhado amarelo.
  Widget _sectionTitle(String text, {String? subtitle}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: AppTheme.yellow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  /// Bloco branco com linha fina preta.
  Widget _block({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(14),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border.fromBorderSide(AppTheme.thinBlack),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _emptyState(String message) {
    return _block(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          Opacity(opacity: 0.4, child: const UniStar(size: 40)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // ---------- Valores com cor ----------
  Color _toneColor(_Tone tone) {
    switch (tone) {
      case _Tone.income:
        return AppTheme.green;
      case _Tone.expense:
        return AppTheme.yellow;
      case _Tone.penalty:
        return AppTheme.red;
    }
  }

  /// Ganho: texto verde. Gasto: etiqueta amarela com texto preto.
  /// Penalidade: texto vermelho.
  Widget _amountText(int value, _Tone tone) {
    switch (tone) {
      case _Tone.income:
        return Text('+$value',
            style: const TextStyle(
                color: AppTheme.green, fontWeight: FontWeight.bold));
      case _Tone.expense:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.yellow,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('−$value',
              style: const TextStyle(
                  color: AppTheme.black, fontWeight: FontWeight.bold)),
        );
      case _Tone.penalty:
        return Text('−$value',
            style: const TextStyle(
                color: AppTheme.red, fontWeight: FontWeight.bold));
    }
  }

  _Tone _toneOf(CreditTransactionType type) {
    switch (type) {
      case CreditTransactionType.bootstrap:
      case CreditTransactionType.unlockEarning:
      case CreditTransactionType.deletionRefund:
        return _Tone.income;
      case CreditTransactionType.deletionPenalty:
        return _Tone.penalty;
      case CreditTransactionType.unlockSpend:
      case CreditTransactionType.editFee:
        return _Tone.expense;
    }
  }

  IconData _iconOf(CreditTransactionType type) {
    switch (type) {
      case CreditTransactionType.bootstrap:
        return Icons.card_giftcard;
      case CreditTransactionType.unlockSpend:
        return Icons.lock_open;
      case CreditTransactionType.unlockEarning:
        return Icons.trending_up;
      case CreditTransactionType.deletionRefund:
        return Icons.undo;
      case CreditTransactionType.deletionPenalty:
        return Icons.warning_amber_rounded;
      case CreditTransactionType.editFee:
        return Icons.edit_outlined;
    }
  }

  /// Barra de proporção (0 a 1) sobre um trilho cinza claro.
  Widget _bar(double fraction, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 8,
        color: AppTheme.grayLight,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction,
          child: Container(color: color),
        ),
      ),
    );
  }

  // ---------- 1. Saldo e estimativas ----------
  Widget _buildBalance(int credits, UsageEstimates est) {
    final missing = est.missingForMostExpensive;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.blue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Saldo atual',
                        style: TextStyle(color: AppTheme.white, fontSize: 14)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$credits',
                          style: const TextStyle(
                            color: AppTheme.white,
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('créditos',
                            style:
                                TextStyle(color: AppTheme.white, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '≈ ${est.minutesAffordable} min de vídeo',
                      style: const TextStyle(
                        color: AppTheme.yellow,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const UniStar(size: 56),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _block(
          child: Column(
            children: [
              _infoRow(
                Icons.ondemand_video_outlined,
                'Vídeos ao seu alcance',
                est.availableVideos == 0
                    ? 'nenhum novo'
                    : '${est.affordableVideos} de ${est.availableVideos}',
              ),
              const Divider(height: 20),
              _infoRow(
                Icons.south,
                'Vídeo mais barato',
                est.cheapestCost == null ? '—' : '${est.cheapestCost} créditos',
              ),
              const Divider(height: 20),
              _infoRow(
                Icons.north,
                'Vídeo mais caro',
                est.mostExpensiveCost == null
                    ? '—'
                    : '${est.mostExpensiveCost} créditos',
              ),
              if (missing != null && missing > 0) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Faltam $missing créditos para desbloquear o mais caro.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.black),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          value,
          style:
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ---------- 2. Balanço de tempo ----------
  Widget _buildTimeBalance(CreditSummary summary) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _timeTile(
              Icons.menu_book_outlined,
              'Aprendi',
              summary.learnedMinutes,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _timeTile(
              Icons.record_voice_over_outlined,
              'Ensinei',
              summary.taughtMinutes,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeTile(IconData icon, String label, int minutes) {
    final theme = Theme.of(context);
    return _block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.black),
              const SizedBox(width: 8),
              Text(label, style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$minutes',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Text('min', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- 3. Resumo de ganhos e gastos ----------
  Widget _buildSummary(CreditSummary s) {
    final theme = Theme.of(context);
    final net = s.net;

    return _block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _groupHeader('Ganhos', s.totalIncome, _Tone.income),
          _barRow('Fundo inicial', s.bootstrap, s.totalIncome, _Tone.income),
          _barRow(
              'Ganho com vídeos', s.videoEarnings, s.totalIncome, _Tone.income),
          _barRow('Estornos recebidos', s.refunds, s.totalIncome, _Tone.income),
          const Divider(height: 28),
          _groupHeader('Gastos', s.totalExpense, _Tone.expense),
          _barRow('Desbloqueios', s.unlockSpend, s.totalExpense, _Tone.expense),
          _barRow('Edições (saem de circulação)', s.editFees, s.totalExpense,
              _Tone.expense),
          _barRow('Penalidades por exclusão', s.penalties, s.totalExpense,
              _Tone.penalty),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Saldo líquido do período',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                net >= 0 ? '+$net' : '−${-net}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: net >= 0 ? AppTheme.green : AppTheme.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _groupHeader(String label, int total, _Tone tone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          total > 0
              ? _amountText(total, tone)
              : Text('0', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _barRow(String label, int value, int total, _Tone tone) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              value > 0
                  ? _amountText(value, tone)
                  : Text('0', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          _bar(CreditSummary.share(value, total), _toneColor(tone)),
        ],
      ),
    );
  }

  // ---------- 4. Vídeos desbloqueados ----------
  Widget _buildUnlocked(List<UnlockedEntry> unlocked) {
    if (unlocked.isEmpty) {
      return _emptyState(
          'Você ainda não desbloqueou nenhum vídeo. Explore a aba Principal.');
    }

    final theme = Theme.of(context);
    final shown =
        _showAllUnlocked ? unlocked : unlocked.take(_unlockedPreview).toList();

    return _block(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _videoRow(
              video: shown[i].video,
              onTap: () => WatchScreen.open(context, shown[i].video),
              lines: [
                Text(
                  'Por ${_authorName(shown[i].video)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Pago: ${shown[i].paid} créditos • '
                  '${_formatDay(shown[i].date)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
          if (unlocked.length > _unlockedPreview)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    setState(() => _showAllUnlocked = !_showAllUnlocked),
                child: Text(_showAllUnlocked
                    ? 'Mostrar menos'
                    : 'Ver todos (${unlocked.length})'),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- 5. Rendimento dos meus vídeos ----------
  Widget _buildEarnings(List<VideoEarning> earnings) {
    if (earnings.isEmpty) {
      return _emptyState(
          'Você ainda não publicou vídeos. Use a aba Publicador.');
    }

    final theme = Theme.of(context);
    final total = VideoEarning.total(earnings);

    return _block(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total rendido',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                total > 0
                    ? _amountText(total, _Tone.income)
                    : Text('0', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          for (final item in earnings) ...[
            const Divider(height: 1),
            _videoRow(
              video: item.video,
              onTap: () => WatchScreen.open(context, item.video),
              lines: [
                if (item.earned > 0)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        '${item.buyers} '
                        '${item.buyers == 1 ? 'comprador' : 'compradores'} '
                        '• rendeu',
                        style: theme.textTheme.bodySmall,
                      ),
                      _amountText(item.earned, _Tone.income),
                    ],
                  )
                else
                  Text('Nenhuma compra ainda.',
                      style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                // Aviso do que aconteceria se o autor excluísse o vídeo.
                if (item.earned > 0)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: AppTheme.red),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Se excluir: devolve ${item.refundOnDelete} aos '
                          'compradores e você perde ${item.penaltyOnDelete}'
                          '${item.penaltyOnDelete < item.earned ? ' (limitado ao seu saldo)' : ''}.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  )
                else
                  Text('Sem compras: pode excluir sem custo.',
                      style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------- 6. Extrato ----------
  Widget _buildStatement(List<CreditTransactionModel> statement) {
    if (statement.isEmpty) {
      return _emptyState('Nenhuma movimentação neste período.');
    }

    final theme = Theme.of(context);
    final shown = statement.take(_statementLimit).toList();
    final remaining = statement.length - shown.length;

    return _block(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _iconOf(shown[i].type),
                    size: 20,
                    color: _toneOf(shown[i].type) == _Tone.penalty
                        ? AppTheme.red
                        : AppTheme.black,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shown[i].description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateTime(shown[i].createdAt),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _amountText(shown[i].amount, _toneOf(shown[i].type)),
                ],
              ),
            ),
          ],
          if (remaining > 0)
            TextButton(
              onPressed: () =>
                  setState(() => _statementLimit += _statementPage),
              child: Text('Ver mais ($remaining restantes)'),
            ),
        ],
      ),
    );
  }

  // ---------- Linha de vídeo (desbloqueados e rendimento) ----------
  Widget _videoRow({
    required VideoModel video,
    required VoidCallback onTap,
    required List<Widget> lines,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      highlightColor: AppTheme.yellowSoft,
      splashColor: AppTheme.yellowSoft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 104,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: VideoThumbnail(
                    compact: true,
                    imageUrl: video.thumbnailPath,
                    durationText: video.formattedDuration,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  ...lines,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _authorName(VideoModel video) =>
      _db.getUserByRgm(video.authorRgm)?.fullName ?? 'autor desconhecido';
}

// =======================================================================
// FORMATAÇÃO DE DATAS
// =======================================================================

String _two(int n) => n.toString().padLeft(2, '0');

String _formatDay(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

String _formatDateTime(DateTime d) =>
    '${_formatDay(d)} ${_two(d.hour)}:${_two(d.minute)}';

// =======================================================================
// SELETOR DE OPÇÕES (período e filtro do extrato)
// =======================================================================

class _ChoiceChips<T> extends StatelessWidget {
  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  const _ChoiceChips({
    Key? key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          Material(
            color: option == selected ? AppTheme.blue : AppTheme.white,
            shape: StadiumBorder(
              side: option == selected
                  ? const BorderSide(color: AppTheme.blue)
                  : AppTheme.thinBlack,
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              highlightColor: AppTheme.yellowSoft,
              splashColor: AppTheme.yellowSoft,
              onTap: () => onSelected(option),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  labelOf(option),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: option == selected ? AppTheme.white : AppTheme.black,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
