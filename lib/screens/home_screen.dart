// lib/screens/home_screen.dart
//
// Aba "Página Principal": cabeçalho com busca, menu horizontal de tópicos
// e grade de vídeos (2 colunas x até 10 linhas = 20 blocos).
// O feed vem pronto do MockDatabase.getFeed (destaques no topo, depois os
// mais recentes). Esta tela só EXIBE: nenhuma regra de créditos aqui.

import '../utils/author_handle.dart';
import 'package:flutter/material.dart';
import 'watch_screen.dart';
import '../data/mock_database.dart';
import '../models/video_model.dart';
import '../theme/app_theme.dart';
import '../widgets/uni_star.dart';
import '../widgets/video_thumbnail.dart';
import '../widgets/app_notice.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MockDatabase _db = MockDatabase.instance;
  final TextEditingController _searchController = TextEditingController();
  // Rolagem própria do menu de tópicos (só ele rola, nunca a aba inteira).
  final ScrollController _topicScroll = ScrollController();
  final GlobalKey _topicViewKey = GlobalKey();

  // Chaves para rolar o menu até o tópico escolhido pela busca.
  final Map<String, GlobalKey> _topicKeys = {
    for (final topic in MockDatabase.topics) topic: GlobalKey(),
  };

  String _selectedTopic = MockDatabase.principalTopic;
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _topicScroll.dispose();
    super.dispose();
  }

  // ---------- Busca ----------
  void _openSearch() => setState(() => _searching = true);

  void _closeSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() => _searching = false);
  }

  /// Ao pressionar Enter: leva ao tópico correspondente.
  void _submitSearch(String query) {
    final topic = _db.findTopicByQuery(query);
    if (topic == null) {
      showAppNotice(
          context, 'Nenhum tópico encontrado para "${query.trim()}".');
      return;
    }
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = false;
      _selectedTopic = topic;
    });
    _scrollTopicIntoView(topic);
  }

  void _selectTopic(String topic) {
    if (topic == _selectedTopic) return;
    setState(() => _selectedTopic = topic);
    _scrollTopicIntoView(topic);
  }

  /// Rola SÓ o menu de tópicos até o item escolhido. (O comando anterior,
  /// Scrollable.ensureVisible, rolava também a aba inteira do app, o que
  /// causava a "puxada" para a esquerda.)
  void _scrollTopicIntoView(String topic) {
    final itemContext = _topicKeys[topic]?.currentContext;
    final viewContext = _topicViewKey.currentContext;
    if (itemContext == null || viewContext == null)
      return; // "Principal" é fixo
    if (!_topicScroll.hasClients) return;

    final itemBox = itemContext.findRenderObject() as RenderBox?;
    final viewBox = viewContext.findRenderObject() as RenderBox?;
    if (itemBox == null || viewBox == null) return;

    // Posição do item dentro da área visível do menu (já inclui a rolagem).
    final itemLeft = itemBox.localToGlobal(Offset.zero, ancestor: viewBox).dx;
    final target = _topicScroll.offset +
        itemLeft -
        (viewBox.size.width - itemBox.size.width) / 2; // centraliza o item

    final max = _topicScroll.position.maxScrollExtent;
    _topicScroll.animateTo(
      target.clamp(0.0, max).toDouble(),
      duration: AppTheme.tabTransition,
      curve: Curves.easeOutCubic,
    );
  }

  // ---------- Toque no bloco ----------
  void _openVideo(VideoModel video) {
    // Decide sozinho: pop-up de compra, ou abre direto (autor/já comprado).
    WatchScreen.open(context, video);
  }

  // ---------- Interface ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        // Abertura rápida da barra de pesquisa (troca suave do título).
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _searching ? _buildSearchField() : _buildBrand(),
        ),
        actions: [
          IconButton(
            tooltip: _searching ? 'Fechar pesquisa' : 'Pesquisar',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _searching ? _closeSearch : _openSearch,
          ),
        ],
      ),
      // Reconstrói sempre que o banco avisa uma mudança (vídeo novo,
      // vídeo excluído, etc.).
      body: AnimatedBuilder(
        animation: _db,
        builder: (context, _) {
          final videos = _db.getFeed(_selectedTopic);
          return Column(
            children: [
              _buildTopicBar(),
              Expanded(child: _buildFeed(videos)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBrand() {
    return Row(
      key: const ValueKey('brand'),
      mainAxisSize: MainAxisSize.min,
      children: const [
        UniStar(size: 30),
        SizedBox(width: 8),
        Text('UniTime'),
      ],
    );
  }

  Widget _buildSearchField() {
    OutlineInputBorder border(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return TextField(
      key: const ValueKey('search'),
      controller: _searchController,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onSubmitted: _submitSearch,
      cursorColor: AppTheme.blue,
      style: const TextStyle(color: AppTheme.black, fontSize: 15),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppTheme.white,
        hintText: 'Pesquisar tópico (ex.: Direito)',
        hintStyle: const TextStyle(color: AppTheme.gray, fontSize: 15),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: border(AppTheme.white),
        enabledBorder: border(AppTheme.white),
        focusedBorder: border(AppTheme.yellow, width: 2),
      ),
    );
  }

  /// "Principal" fixo à esquerda + 5 tópicos rolando na horizontal.
  Widget _buildTopicBar() {
    return SizedBox(
      height: 46,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _topicItem(MockDatabase.principalTopic),
          Expanded(
            child: SingleChildScrollView(
              key: _topicViewKey,
              controller: _topicScroll,
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final topic in MockDatabase.topics)
                    _topicItem(topic, key: _topicKeys[topic]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Item do menu: sublinhado amarelo (mais grosso quando selecionado).
  Widget _topicItem(String topic, {Key? key}) {
    final selected = topic == _selectedTopic;
    return InkWell(
      key: key,
      onTap: () => _selectTopic(topic),
      highlightColor: AppTheme.yellowSoft,
      splashColor: AppTheme.yellowSoft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.yellow,
              width: selected ? 3 : 1,
            ),
          ),
        ),
        child: Text(
          topic,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? AppTheme.black : AppTheme.gray,
          ),
        ),
      ),
    );
  }

  Widget _buildFeed(List<VideoModel> videos) {
    if (videos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(opacity: 0.4, child: const UniStar(size: 56)),
              const SizedBox(height: 12),
              Text(
                'Nenhum vídeo neste tópico ainda.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.gray),
              ),
            ],
          ),
        ),
      );
    }

    // Grade de 2 colunas (até 10 linhas = 20 blocos, limite do banco).
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: videos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 204,
      ),
      itemBuilder: (context, index) {
        final video = videos[index];
        return _VideoCard(video: video, onTap: () => _openVideo(video));
      },
    );
  }
}

/// Bloco de vídeo: fundo branco, linha fina preta e cantos bem arredondados.
class _VideoCard extends StatelessWidget {
  static const double _blockRadius = 16;

  final VideoModel video;
  final VoidCallback onTap;

  const _VideoCard({Key? key, required this.video, required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final average = MockDatabase.instance.averageRating(video.id);
    final handle = AuthorHandle.forRgm(video.authorRgm);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border.fromBorderSide(AppTheme.thinBlack),
        borderRadius: BorderRadius.circular(_blockRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          highlightColor: AppTheme.yellowSoft,
          splashColor: AppTheme.yellowSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thumbnail (imagem real ou o espaço reservado azul com a estrela).
              AspectRatio(
                aspectRatio: 16 / 9,
                child: VideoThumbnail(
                  durationText: video.formattedDuration,
                  imageUrl: video.thumbnailPath,
                ),
              ),
              // Linha amarela separando a thumbnail das informações.
              Container(height: 2, color: AppTheme.yellow),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Autor: @ + 1º e 2º nome.
                      Text(
                        handle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      const Spacer(),
                      // Curtidas (vermelho), visualizações (cinza) e média de
                      // estrelas (amarela; cinza com "—" se ainda não há nota).
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            const Icon(Icons.favorite_border,
                                size: 16, color: AppTheme.red),
                            const SizedBox(width: 4),
                            Text(_compact(video.likes),
                                style: theme.textTheme.bodySmall),
                            const SizedBox(width: 12),
                            const Icon(Icons.visibility_outlined,
                                size: 16, color: AppTheme.gray),
                            const SizedBox(width: 4),
                            Text(_compact(video.views),
                                style: theme.textTheme.bodySmall),
                            const SizedBox(width: 12),
                            Icon(
                              average == null ? Icons.star_border : Icons.star,
                              size: 16,
                              color: average == null
                                  ? AppTheme.gray
                                  : AppTheme.yellow,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              average == null
                                  ? '—'
                                  : average
                                      .toStringAsFixed(1)
                                      .replaceAll('.', ','),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 950 -> "950" | 1200 -> "1,2 mil"
  static String _compact(int n) {
    if (n < 1000) return '$n';
    return '${(n / 1000).toStringAsFixed(1).replaceAll('.', ',')} mil';
  }
}
