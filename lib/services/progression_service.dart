// lib/services/progression_service.dart
//
// Regras de NÍVEL e MEDALHA do UniTime. Só matemática: não mexe em banco,
// em créditos nem em tela. Os níveis são SIMBÓLICOS e não afetam nada nos
// usuários (créditos, preços e acessos continuam iguais).
//
// Curva: linear suave com teto por nível.
//   XP para subir ao nível n = min(30 + 10 × (n − 1), 150)
//   (nível 1 = 30 XP, nível 2 = 40 XP ... a partir do nível 13 = 150 XP)
//   Nível máximo: 30 (3.720 XP no total).
//
// Valores de referência (XP total -> nível):
//   0 -> 0 | 30 -> 1 | 250 -> 5 | 750 -> 10 | 2220 -> 20 | 3720 -> 30

/// Faixas de medalha (valor apenas simbólico, de decoração no perfil).
enum MedalTier {
  chocolate('Chocolate', 0),
  bronze('Bronze', 5),
  silver('Prata', 12),
  gold('Ouro', 20),
  diamond('Diamante', 27);

  final String label;
  final int minLevel; // primeiro nível da faixa
  const MedalTier(this.label, this.minLevel);
}

/// Situação de progresso de um usuário, pronta para a tela desenhar.
class LevelInfo {
  final int level; // de 0 a ProgressionService.maxLevel
  final int totalXp;
  final int xpIntoLevel; // XP já feito dentro do nível atual
  final int xpForNext; // XP que o próximo nível exige (0 no nível máximo)

  const LevelInfo({
    required this.level,
    required this.totalXp,
    required this.xpIntoLevel,
    required this.xpForNext,
  });

  bool get isMax => level >= ProgressionService.maxLevel;

  /// Progresso dentro do nível atual, de 0.0 a 1.0 (para a barra).
  double get progress {
    if (isMax || xpForNext <= 0) return 1.0;
    return (xpIntoLevel / xpForNext).clamp(0.0, 1.0).toDouble();
  }

  /// XP que falta para o próximo nível.
  int get xpMissing => isMax ? 0 : xpForNext - xpIntoLevel;

  MedalTier get tier => ProgressionService.tierFor(level);
}

class ProgressionService {
  ProgressionService._();

  static const int maxLevel = 30;
  static const int firstLevelCost = 30; // XP para o nível 1
  static const int costStep = 10; // cada nível custa 10 XP a mais...
  static const int costCap = 150; // ...até este teto

  /// XP necessário para subir do nível (level − 1) ao nível [level].
  static int costToReach(int level) {
    if (level < 1) return 0;
    final cost = firstLevelCost + costStep * (level - 1);
    return cost > costCap ? costCap : cost;
  }

  /// XP TOTAL acumulado necessário para alcançar o nível [level].
  static int totalXpForLevel(int level) {
    final target = level > maxLevel ? maxLevel : level;
    var total = 0;
    for (var n = 1; n <= target; n++) {
      total += costToReach(n);
    }
    return total;
  }

  /// Calcula nível e progresso a partir do XP total do usuário.
  static LevelInfo infoFor(int totalXp) {
    final xp = totalXp < 0 ? 0 : totalXp;
    var level = 0;
    var spent = 0; // XP gasto até o início do nível atual

    while (level < maxLevel) {
      final cost = costToReach(level + 1);
      if (xp < spent + cost) break;
      spent += cost;
      level++;
    }

    if (level >= maxLevel) {
      // Nível máximo: o XP extra continua somando, mas o nível não sobe.
      return LevelInfo(
        level: maxLevel,
        totalXp: xp,
        xpIntoLevel: 0,
        xpForNext: 0,
      );
    }

    return LevelInfo(
      level: level,
      totalXp: xp,
      xpIntoLevel: xp - spent,
      xpForNext: costToReach(level + 1),
    );
  }

  /// Faixa de medalha de um nível.
  static MedalTier tierFor(int level) {
    var result = MedalTier.chocolate;
    for (final tier in MedalTier.values) {
      if (level >= tier.minLevel) result = tier;
    }
    return result;
  }
}
