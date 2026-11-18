// lib/screens/main_shell.dart
//
// Estrutura principal do app depois do login: barra inferior com as
// 4 abas essenciais (Principal, Métricas, Publicador e Perfil).
// Cada aba terá o PRÓPRIO Scaffold e cabeçalho azul; este arquivo cuida
// só da barra de rodapé e da transição horizontal rápida entre abas.
//
// Por enquanto as abas são espaços reservados (_PlaceholderTab).
// Conforme cada tela real ficar pronta, ela substitui o seu espaço
// (procure os comentários TODO).
//

import 'profile_screen.dart';
import 'publisher_screen.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'metrics_screen.dart';
import '../data/mock_database.dart';
import '../theme/app_theme.dart';
import '../widgets/uni_star.dart';

class MainShell extends StatefulWidget {
  const MainShell({Key? key}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // As 4 abas, na ordem do rodapé. Cada uma mantém o estado ao trocar.
  late final List<Widget> _pages = [
    const _KeepAliveTab(child: HomeScreen()),
    const _KeepAliveTab(child: MetricsScreen()),
    const _KeepAliveTab(child: PublisherScreen()),
    const _KeepAliveTab(child: ProfileScreen()),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Troca de aba com transição horizontal rápida.
  void _onTabSelected(int index) {
    if (index == _currentIndex) return;

    final previous = _currentIndex;
    setState(() => _currentIndex = index);

    // Abas distantes: pula para a vizinha da destino e anima só o último
    // passo, para não desenhar as telas do meio (mantém o app leve).
    if ((index - previous).abs() > 1) {
      _pageController.jumpToPage(index > previous ? index - 1 : index + 1);
    }

    _pageController.animateToPage(
      index,
      duration: AppTheme.tabTransition,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // physics bloqueado: a troca é só pelo toque na barra, sem deslizar
      // (evita conflito com o menu horizontal de tópicos da Home).
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _pages,
      ),

      // Barra inferior com linha amarela no topo.
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.white,
          border: Border(top: BorderSide(color: AppTheme.yellow, width: 2.8)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Principal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Métricas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.video_call_outlined),
              activeIcon: Icon(Icons.video_call),
              label: 'Publicador',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

/// Mantém a aba "viva" ao trocar (preserva rolagem e estado).
class _KeepAliveTab extends StatefulWidget {
  final Widget child;
  const _KeepAliveTab({Key? key, required this.child}) : super(key: key);

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // exigido pelo AutomaticKeepAliveClientMixin
    return widget.child;
  }
}

/// ESPAÇO RESERVADO de uma aba (será substituído pela tela real).
class _PlaceholderTab extends StatelessWidget {
  final String title;
  final String description;
  final bool showLogout;

  const _PlaceholderTab({
    Key? key,
    required this.title,
    required this.description,
    this.showLogout = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = MockDatabase.instance;
    final user = db.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: UniStarWatermark(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppTheme.gray),
                ),
                if (showLogout) ...[
                  const SizedBox(height: 16),
                  if (user != null) ...[
                    Text(
                      user.fullName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('Saldo: ${user.credits} créditos'),
                    const SizedBox(height: 16),
                  ],
                  OutlinedButton.icon(
                    onPressed: db.logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sair'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
