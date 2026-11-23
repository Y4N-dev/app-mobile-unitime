// lib/utils/author_handle.dart
//
// Identificador público do autor: "@" + 1º e 2º nome (ex.: Lucas Henrique
// Barbosa -> @LucasHenrique), sem acentos e sem espaços. Usado no bloco de
// vídeo, no player e nas Métricas.
//
// Nomes repetidos: se dois autores gerarem o mesmo identificador, os 2
// últimos dígitos do RGM são acrescentados aos DOIS (ex.: @LucasHenrique17).

import '../data/mock_database.dart';
import '../models/user_model.dart';

class AuthorHandle {
  AuthorHandle._();

  /// Conectores que não contam como "2º nome".
  static const Set<String> _connectors = {
    'de',
    'da',
    'do',
    'das',
    'dos',
    'e',
    'di',
    'du',
    'del',
    'la',
    'le',
  };

  /// Atalho: identificador do aluno com este RGM.
  static String forRgm(String rgm) {
    final db = MockDatabase.instance;
    final user = db.getUserByRgm(rgm);
    if (user == null) return '@desconhecido';
    return forUser(user, db.allUsers);
  }

  /// Identificador do aluno, considerando todos os alunos (para repetidos).
  static String forUser(UserModel user, List<UserModel> everyone) {
    final base = _base(user.fullName);

    var clashes = 0;
    for (final other in everyone) {
      if (other.rgm != user.rgm && _base(other.fullName) == base) clashes++;
    }
    if (clashes == 0) return base;

    final rgm = user.rgm;
    final suffix = rgm.length >= 2 ? rgm.substring(rgm.length - 2) : rgm;
    return '$base$suffix';
  }

  static String _base(String fullName) {
    final words = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '@';

    String? second;
    for (final word in words.skip(1)) {
      if (!_connectors.contains(word.toLowerCase())) {
        second = word;
        break;
      }
    }
    return '@${_capitalize(words.first)}'
        '${second == null ? '' : _capitalize(second)}';
  }

  /// "lUCAS" -> "Lucas" (sem acentos e sem símbolos).
  static String _capitalize(String word) {
    final clean = _stripAccents(word).replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (clean.isEmpty) return '';
    return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
  }

  static String _stripAccents(String text) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
    const to = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
    var result = text;
    for (var i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    return result;
  }
}
