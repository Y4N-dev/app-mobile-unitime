// lib/main.dart
//
// Ponto de entrada do UniTime.
// Decide qual tela mostrar:
//   - ninguém logado  -> LoginScreen
//   - aluno logado    -> área principal (por enquanto, a tela provisória)
//
// O MockDatabase avisa (notifyListeners) quando o aluno entra ou sai,
// e este arquivo reage trocando de tela automaticamente.
// O visual do app inteiro vem do AppTheme (lib/theme/app_theme.dart).

import 'package:flutter/material.dart';
import 'screens/main_shell.dart';
import 'data/mock_database.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/uni_star.dart';

void main() {
  runApp(const UniTimeApp());
}

class UniTimeApp extends StatelessWidget {
  const UniTimeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniTime',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light, // identidade visual definida em um só lugar
      home: const _AuthGate(),
    );
  }
}

/// Porteiro do app: escuta o banco e escolhe entre login e área logada.
class _AuthGate extends StatelessWidget {
  const _AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final db = MockDatabase.instance;

    // AnimatedBuilder reconstrói esta parte sempre que o banco avisa
    // uma mudança (login, logout, saldo, etc.).
    return AnimatedBuilder(
      animation: db,
      builder: (context, _) {
        if (!db.isLoggedIn) return const LoginScreen();

        return const MainShell();
      },
    );
  }
}

/// TELA PROVISÓRIA: serve só para testar login e logout.
/// Será APAGADA quando o main_shell.dart (4 abas) estiver pronto.
class _ProvisionalHome extends StatelessWidget {
  const _ProvisionalHome({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final db = MockDatabase.instance;
    final user = db.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('UniTime')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const UniStar(size: 72),
              const SizedBox(height: 16),
              Text(
                user == null ? 'Sessão encerrada' : 'Olá, ${user.fullName}!',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              if (user != null) ...[
                const SizedBox(height: 8),
                Text(
                  'RGM ${user.rgm}  •  ${user.course}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Saldo: ${user.credits} créditos',
                  style: theme.textTheme.titleMedium,
                ),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: db.logout,
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
