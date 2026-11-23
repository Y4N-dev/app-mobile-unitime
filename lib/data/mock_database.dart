// lib/data/mock_database.dart
//
// Banco de dados LOCAL SIMULADO (mock) do UniTime.
// Guarda tudo em memória: alunos, vídeos, movimentações de créditos e
// curtidas. Este arquivo só GUARDA e BUSCA dados. As contas (custo,
// estorno, penalidade, piso de 0) ficam no credit_service.dart.
//
// FUTURO: o plano é criar um banco de dados online e transferir para lá
// vídeos, comentários e logins, deixando o app independente de
// armazenamento local. Como TODO acesso a dados passa por esta classe,
// só ela precisará ser trocada por dentro; as telas e o credit_service
// continuarão chamando os mesmos métodos.
//
// Comentar, avaliar e denunciar ainda são SIMULADOS nas telas (apenas
// confirmam a ação); quando o banco online existir, passarão a ser
// gravados aqui.
//
// Uso nas telas: MockDatabase.instance
//
import '../models/xp_entry_model.dart';
import 'package:flutter/foundation.dart';
import '../models/video_feedback_model.dart';
import '../models/credit_transaction_model.dart';
import '../models/user_model.dart';
import '../models/video_model.dart';

class MockDatabase extends ChangeNotifier {
  // ---------- Singleton: uma única instância para o app inteiro ----------
  MockDatabase._internal() {
    _loadSeed();
  }
  static final MockDatabase instance = MockDatabase._internal();

  // ---------- Tópicos do feed ----------
  /// Categoria fixa que acompanha o menu horizontal.
  static const String principalTopic = 'Principal';

  /// Os 15 subtemas acadêmicos (cursos variados, alternados entre áreas).
  static const List<String> topics = [
    'Programação',
    'Design',
    'Direito',
    'Pedagogia',
    'Engenharia',
    'Psicologia',
    'Saúde',
    'Ciências Contábeis',
    'Administração',
    'Publicidade e Propaganda',
    'Gastronomia',
    'Medicina Veterinária',
    'Serviço Social',
    'Agronomia',
    'Comércio Exterior',
  ];

  /// Grade do feed: 2 de largura x 10 de altura = 20 itens por visualização.
  static const int feedPageSize = 20;

  // ---------- Dados em memória ----------
  List<UserModel> _users = [];
  List<VideoModel> _videos = [];
  List<CreditTransactionModel> _transactions = [];

  /// Curtidas: chave "rgm|videoId" -> quando foi curtido (um aluno curte
  /// um vídeo uma vez).
  final Map<String, DateTime> _likes = <String, DateTime>{};

  /// XP resgatado (missões diárias). Níveis são simbólicos.
  final List<XpEntryModel> _xpEntries = [];
  int _xpSeq = 0;

  /// Comentários e avaliações (em memória; futuramente, no banco online).
  final List<CommentModel> _comments = [];
  final List<RatingModel> _ratings = [];
  int _feedbackSeq = 0;

  int _videoSeq = 0;
  int _transactionSeq = 0;

  /// RGM do aluno logado (nulo = ninguém logado).
  String? _currentRgm;

  // =====================================================================
  // SESSÃO E LOGIN (apenas login: não existe cadastro pelo app)
  // =====================================================================

  /// Valida e-mail institucional + senha. Retorna o aluno ou null.
  UserModel? login(String email, String password) {
    final typedEmail = email.trim().toLowerCase();
    for (final user in _users) {
      if (user.institutionalEmail.toLowerCase() == typedEmail &&
          user.password == password) {
        _currentRgm = user.rgm;
        notifyListeners();
        return user;
      }
    }
    return null;
  }

  void logout() {
    _currentRgm = null;
    notifyListeners();
  }

  bool get isLoggedIn => _currentRgm != null;

  /// Aluno logado, sempre na versão mais atual (saldo atualizado etc.).
  UserModel? get currentUser =>
      _currentRgm == null ? null : getUserByRgm(_currentRgm!);

  // =====================================================================
  // ALUNOS
  // =====================================================================

  UserModel? getUserByRgm(String rgm) {
    for (final user in _users) {
      if (user.rgm == rgm) return user;
    }
    return null;
  }

  /// Substitui o aluno (identificado pelo RGM) pela versão atualizada.
  void updateUser(UserModel updated) {
    final index = _users.indexWhere((u) => u.rgm == updated.rgm);
    if (index == -1) return;
    _users[index] = updated;
    notifyListeners();
  }

  /// Todos os alunos (usado para identificar nomes repetidos).
  List<UserModel> get allUsers => List<UserModel>.unmodifiable(_users);

  // =====================================================================
  // VÍDEOS
  // =====================================================================

  String nextVideoId() {
    _videoSeq++;
    return 'v${_videoSeq.toString().padLeft(3, '0')}';
  }

  VideoModel? getVideoById(String id) {
    for (final video in _videos) {
      if (video.id == id) return video;
    }
    return null;
  }

  /// Todos os vídeos do app (para estimativas e métricas).
  List<VideoModel> get allVideos => List<VideoModel>.unmodifiable(_videos);

  /// Vídeos de um autor (para "Gerenciar Vídeos"), mais recentes primeiro.
  List<VideoModel> getVideosByAuthor(String rgm) {
    final list = _videos.where((v) => v.authorRgm == rgm).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Feed de um tópico: no máximo 20 itens.
  /// Ordem: destaques (Top 20) fixados no topo, depois os mais recentes.
  /// Na categoria "Principal" entram vídeos de todos os tópicos.
  List<VideoModel> getFeed(String topic) {
    final List<VideoModel> list;
    if (topic == principalTopic) {
      list = List<VideoModel>.of(_videos);
    } else {
      list = _videos
          .where((v) => v.mainTopic == topic || v.subTopic == topic)
          .toList();
    }
    list.sort((a, b) {
      if (a.isTop20 != b.isTop20) return a.isTop20 ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list.take(feedPageSize).toList();
  }

  /// Barra de pesquisa: devolve o tópico correspondente ao texto digitado
  /// (ignora maiúsculas e acentos) ou null se nada corresponder.
  String? findTopicByQuery(String query) {
    final q = _normalize(query);
    if (q.isEmpty) return null;
    final all = [principalTopic, ...topics];
    for (final topic in all) {
      if (_normalize(topic) == q) return topic;
    }
    for (final topic in all) {
      if (_normalize(topic).contains(q)) return topic;
    }
    return null;
  }

  void addVideo(VideoModel video) {
    _videos.add(video);
    notifyListeners();
  }

  /// Substitui o vídeo (identificado pelo id) pela versão atualizada.
  void updateVideo(VideoModel updated) {
    final index = _videos.indexWhere((v) => v.id == updated.id);
    if (index == -1) return;
    _videos[index] = updated;
    notifyListeners();
  }

  /// Remove o vídeo do banco. ATENÇÃO: aqui NÃO há regra econômica.
  /// O estorno de 100% e a penalidade do autor são feitos pelo
  /// credit_service.dart. As movimentações antigas continuam no extrato.
  void deleteVideo(String id) {
    _videos.removeWhere((v) => v.id == id);
    _likes.removeWhere((key, _) => key.endsWith('|$id')); // limpa as curtidas
    _comments.removeWhere((c) => c.videoId == id); // limpa os comentários
    _ratings.removeWhere((r) => r.videoId == id); // limpa as avaliações
    notifyListeners();
  }

  /// Marcação manual do Top 20 (curadoria do protótipo).
  void setTop20(String videoId, bool value) {
    final video = getVideoById(videoId);
    if (video == null) return;
    updateVideo(video.copyWith(isTop20: value));
  }

  // =====================================================================
  // CURTIDAS E VISUALIZAÇÕES
  // =====================================================================

  static String _likeKey(String rgm, String videoId) => '$rgm|$videoId';

  /// O aluno já curtiu este vídeo?
  bool hasLiked(String rgm, String videoId) =>
      _likes.containsKey(_likeKey(rgm, videoId));

  /// Alterna a curtida (curte / descurte) e atualiza o contador do vídeo.
  /// Retorna true se, depois da ação, o vídeo está curtido.
  bool toggleLike(String rgm, String videoId) {
    final video = getVideoById(videoId);
    if (video == null) return false;

    final key = _likeKey(rgm, videoId);
    final nowLiked = !_likes.containsKey(key);
    if (nowLiked) {
      _likes[key] = DateTime.now(); // guarda QUANDO curtiu (missões diárias)
    } else {
      _likes.remove(key);
    }

    final newCount = video.likes + (nowLiked ? 1 : -1);
    updateVideo(video.copyWith(likes: newCount < 0 ? 0 : newCount));
    return nowLiked;
  }

  /// Soma 1 visualização. Quem chama (watch_screen) decide quando contar.
  void registerView(String videoId) {
    final video = getVideoById(videoId);
    if (video == null) return;
    updateVideo(video.copyWith(views: video.views + 1));
  }

  /// Ids dos vídeos que o aluno curtiu NO DIA [day] e que continuam curtidos.
  /// (Base da missão "curtir vídeos diferentes".)
  List<String> likedVideoIdsOn(String rgm, DateTime day) {
    final prefix = '$rgm|';
    final result = <String>[];
    _likes.forEach((key, when) {
      if (key.startsWith(prefix) && _sameDay(when, day)) {
        result.add(key.substring(prefix.length));
      }
    });
    return result;
  }

  // =====================================================================
  // COMENTÁRIOS E AVALIAÇÕES
  // =====================================================================

  String nextFeedbackId() {
    _feedbackSeq++;
    return 'f${_feedbackSeq.toString().padLeft(4, '0')}';
  }

  /// Comentários de um vídeo, mais recentes primeiro.
  List<CommentModel> getComments(String videoId) {
    final list = _comments.where((c) => c.videoId == videoId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  void addComment(CommentModel comment) {
    _comments.add(comment);
    notifyListeners();
  }

  /// Avaliações de um vídeo, mais recentes primeiro.
  List<RatingModel> getRatings(String videoId) {
    final list = _ratings.where((r) => r.videoId == videoId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Avaliação que este aluno já fez para o vídeo (ou null).
  RatingModel? getRatingBy(String rgm, String videoId) {
    for (final rating in _ratings) {
      if (rating.authorRgm == rgm && rating.videoId == videoId) return rating;
    }
    return null;
  }

  /// Salva a avaliação. REGRA: uma por aluno em cada vídeo; se já existir,
  /// a nova substitui a antiga.
  void saveRating(RatingModel rating) {
    _ratings.removeWhere(
        (r) => r.authorRgm == rating.authorRgm && r.videoId == rating.videoId);
    _ratings.add(rating);
    notifyListeners();
  }

  /// Média das estrelas do vídeo (null se ainda não há avaliações).
  double? averageRating(String videoId) {
    final list = _ratings.where((r) => r.videoId == videoId).toList();
    if (list.isEmpty) return null;
    final total = list.fold<int>(0, (sum, r) => sum + r.stars);
    return total / list.length;
  }

  // =====================================================================
  // MOVIMENTAÇÕES DE CRÉDITOS
  // =====================================================================

  String nextTransactionId() {
    _transactionSeq++;
    return 't${_transactionSeq.toString().padLeft(4, '0')}';
  }

  void addTransaction(CreditTransactionModel transaction) {
    _transactions.add(transaction);
    notifyListeners();
  }

  /// Extrato completo de um aluno, mais recentes primeiro.
  List<CreditTransactionModel> getTransactionsByUser(String rgm) {
    final list = _transactions.where((t) => t.userRgm == rgm).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Todas as movimentações ligadas a um vídeo (de todos os alunos).
  /// O credit_service usa isto na exclusão: acha os compradores
  /// (unlockSpend) e o total ganho pelo autor (unlockEarning).
  List<CreditTransactionModel> getTransactionsByVideo(String videoId) {
    return _transactions.where((t) => t.videoId == videoId).toList();
  }

  /// O aluno já desbloqueou este vídeo?
  bool hasUnlocked(String rgm, String videoId) {
    return _transactions.any(
        (t) => t.userRgm == rgm && t.isUnlockPurchase && t.videoId == videoId);
  }

  /// Histórico de vídeos desbloqueados (atalho de consumo), do mais
  /// recente para o mais antigo. Só inclui vídeos que ainda existem.
  List<VideoModel> getUnlockedVideos(String rgm) {
    final purchases =
        getTransactionsByUser(rgm).where((t) => t.isUnlockPurchase).toList();
    final seen = <String>{};
    final result = <VideoModel>[];
    for (final purchase in purchases) {
      final id = purchase.videoId;
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      final video = getVideoById(id);
      if (video != null) result.add(video);
    }
    return result;
  }

  // =====================================================================
  // XP (MISSÕES DIÁRIAS)
  // =====================================================================

  String nextXpId() {
    _xpSeq++;
    return 'x${_xpSeq.toString().padLeft(4, '0')}';
  }

  /// Registra um XP resgatado. REGRA: cada missão só pode ser resgatada UMA
  /// vez por dia. Devolve false (sem gravar) se já havia sido resgatada.
  bool addXpEntry(XpEntryModel entry) {
    if (hasClaimed(entry.userRgm, entry.missionId, entry.dayKey)) return false;
    _xpEntries.add(entry);
    notifyListeners();
    return true;
  }

  /// A missão já foi resgatada neste dia?
  bool hasClaimed(String rgm, String missionId, String dayKey) {
    return _xpEntries.any((e) =>
        e.userRgm == rgm && e.missionId == missionId && e.dayKey == dayKey);
  }

  /// Registros de XP do aluno, mais recentes primeiro.
  List<XpEntryModel> getXpEntries(String rgm) {
    final list = _xpEntries.where((e) => e.userRgm == rgm).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// XP total do aluno (o nível é calculado a partir daqui).
  int totalXp(String rgm) {
    var total = 0;
    for (final entry in _xpEntries) {
      if (entry.userRgm == rgm) total += entry.xp;
    }
    return total;
  }

  /// Dias ("2026-11-15") em que o aluno resgatou alguma missão
  /// (base da sequência de dias).
  Set<String> claimedDayKeys(String rgm) {
    return _xpEntries
        .where((e) => e.userRgm == rgm)
        .map((e) => e.dayKey)
        .toSet();
  }

  // =====================================================================
  // UTILITÁRIOS
  // =====================================================================

  /// Restaura o banco ao estado inicial (útil entre demonstrações).
  void resetDemo() {
    _currentRgm = null;
    _loadSeed();
    notifyListeners();
  }

  void _loadSeed() {
    _users = List<UserModel>.of(_seedUsers());
    _videos = _seedVideos();
    _transactions = _seedTransactions(_users);
    _likes.clear();
    _xpEntries.clear();
    _xpSeq = 0;
    _comments.clear();
    _ratings.clear();
    _feedbackSeq = 0;
    _videoSeq = _videos.length;
    _transactionSeq = _transactions.length;
  }

  /// Minúsculas, sem espaços nas pontas e sem acentos.
  static String _normalize(String text) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    var result = text.trim().toLowerCase();
    for (var i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    return result;
  }

  /// As duas datas caem no mesmo dia?
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // =====================================================================
  // DADOS INICIAIS (SEED)
  // =====================================================================

  // Senha padrão de teste: "@" + iniciais de cada nome (maiúsculas) + "123456".
  // Todos já nascem com o fundo inicial de 100 créditos (valor padrão do
  // UserModel). principalCount é só ilustrativo para a demonstração.
  static List<UserModel> _seedUsers() => const [
        UserModel(
          rgm: '24100317',
          fullName: 'Lucas Henrique Barbosa',
          course: 'Análise e Desenvolvimento de Sistemas',
          semester: 4,
          institutionalEmail: 'lucas.barbosa@cs.unipe.edu.br',
          password: '@LHB123456',
          principalCount: 1,
        ),
        UserModel(
          rgm: '24100842',
          fullName: 'Mariana Costa Albuquerque',
          course: 'Direito',
          semester: 6,
          institutionalEmail: 'mariana.albuquerque@cs.unipe.edu.br',
          password: '@MCA123456',
          principalCount: 1,
        ),
        UserModel(
          rgm: '23200655',
          fullName: 'Rafael Torres Nogueira',
          course: 'Engenharia Civil',
          semester: 3,
          institutionalEmail: 'rafael.nogueira@cs.unipe.edu.br',
          password: '@RTN123456',
        ),
        UserModel(
          rgm: '25300129',
          fullName: 'Beatriz Lima Cavalcanti',
          course: 'Enfermagem',
          semester: 5,
          institutionalEmail: 'beatriz.cavalcanti@cs.unipe.edu.br',
          password: '@BLC123456',
          principalCount: 1,
        ),
        UserModel(
          rgm: '24400976',
          fullName: 'Gabriel Souza Pereira',
          course: 'Administração',
          semester: 2,
          institutionalEmail: 'gabriel.pereira@cs.unipe.edu.br',
          password: '@GSP123456',
          principalCount: 1,
        ),
      ];

  // Vídeos de TESTE: filmes abertos da Blender Foundation (Creative
  // Commons BY), usados no mundo todo para testar players de vídeo.
  // REAIS: videoPath (link direto do MP4), thumbnailPath, durationSeconds.
  // DE DEMONSTRAÇÃO: tópico, autor, views e likes (troque pelos dados
  // reais quando os alunos publicarem vídeos).
  // Preço = minutos inteiros x 10 (calculado pelo VideoModel):
  //   596 s -> 90 | 888 s -> 140 | 653 s -> 100 | 734 s -> 120 | 10 s -> 10
  static const String _gtvBase =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/';

  static List<VideoModel> _seedVideos() => [
        VideoModel(
          id: 'v001',
          authorRgm: '24100317',
          title: 'Big Buck Bunny (vídeo de teste)',
          description: 'Curta de animação aberto, usado para testar vídeos. '
              '© 2008 Blender Foundation | bigbuckbunny.org (CC BY 3.0).',
          mainTopic: 'Programação',
          durationSeconds: 596, // 9:56
          videoPath: '${_gtvBase}BigBuckBunny.mp4',
          thumbnailPath:
              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Big_buck_bunny_poster_big.jpg/400px-Big_buck_bunny_poster_big.jpg',
          views: 120,
          likes: 34,
          createdAt: DateTime(2026, 10, 2),
          isTop20: true,
        ),
        VideoModel(
          id: 'v002',
          authorRgm: '24100842',
          title: 'Sintel (vídeo de teste)',
          description: 'Curta de animação aberto, usado para testar vídeos. '
              '© Blender Foundation | sintel.org (CC BY 3.0).',
          mainTopic: 'Direito',
          durationSeconds: 888, // 14:48
          videoPath: '${_gtvBase}Sintel.mp4',
          thumbnailPath: 'https://media.w3.org/2010/05/sintel/poster.png',
          views: 150,
          likes: 52,
          createdAt: DateTime(2026, 10, 3),
          isTop20: true,
        ),
        VideoModel(
          id: 'v003',
          authorRgm: '23200655',
          title: 'Elephants Dream (vídeo de teste)',
          description:
              'Primeiro filme aberto da Blender Foundation, usado para '
              'testar vídeos (Creative Commons BY).',
          mainTopic: 'Engenharia',
          durationSeconds: 653, // 10:53
          videoPath: '${_gtvBase}ElephantsDream.mp4',
          thumbnailPath:
              'https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/Elephants_Dream_s1_proog.jpg/800px-Elephants_Dream_s1_proog.jpg',
          views: 58,
          likes: 15,
          createdAt: DateTime(2026, 10, 5),
        ),
        VideoModel(
          id: 'v004',
          authorRgm: '25300129',
          title: 'Tears of Steel (vídeo de teste)',
          description:
              'Curta aberto que mistura cenas reais e animação, usado para '
              'testar vídeos. (CC) Blender Foundation | tearsofsteel.org.',
          mainTopic: 'Saúde',
          durationSeconds: 734, // 12:14
          videoPath: '${_gtvBase}TearsOfSteel.mp4',
          thumbnailPath:
              'https://cdn2.hubspot.net/hubfs/2163521/Demo_zone/tears_of_steel_poster.jpg',
          views: 143,
          likes: 47,
          createdAt: DateTime(2026, 10, 6),
          isTop20: true,
        ),
        VideoModel(
          id: 'v005',
          authorRgm: '24400976',
          title: 'Big Buck Bunny, trecho de 10 s (vídeo de teste)',
          description:
              'Trecho curto de 10 segundos, ideal para testar uma compra '
              'barata (10 créditos). © Blender Foundation | bigbuckbunny.org '
              '(CC BY 3.0).',
          mainTopic: 'Administração',
          durationSeconds: 10,
          videoPath: 'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/'
              'Big_Buck_Bunny_360_10s_1MB.mp4',
          // sem thumbnail: a tela usa o espaço reservado (estrela amarela)
          views: 69,
          likes: 19,
          createdAt: DateTime(2026, 10, 20),
        ),
      ];

  /// Cada aluno começa com UMA movimentação: o fundo inicial de 100 créditos.
  static List<CreditTransactionModel> _seedTransactions(List<UserModel> users) {
    final list = <CreditTransactionModel>[];
    for (var i = 0; i < users.length; i++) {
      list.add(CreditTransactionModel(
        id: 't${(i + 1).toString().padLeft(4, '0')}',
        userRgm: users[i].rgm,
        type: CreditTransactionType.bootstrap,
        amount: UserModel.bootstrapCredits,
        createdAt: DateTime(2026, 9, 1),
      ));
    }
    return list;
  }
}
