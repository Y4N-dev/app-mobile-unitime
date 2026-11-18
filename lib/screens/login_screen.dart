// lib/screens/login_screen.dart
//
// Tela de LOGIN do UniTime.
// Regras do MVP:
//  - Existe SOMENTE login: nenhum botão ou rota de cadastro.
//  - Valida e-mail institucional + senha (padrão DUDA) no mock_database.
//  - Esta tela NÃO navega: ao logar, o MockDatabase avisa o app
//    (notifyListeners) e o main.dart troca para a navegação principal.
// Visual: estilos de campos e botões vêm do AppTheme.

import 'package:flutter/material.dart';

import '../data/mock_database.dart';
import '../theme/app_theme.dart';
import '../widgets/uni_star.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  String? _errorMessage; // erro de credenciais (exibido acima do botão)

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ---------- Ação de entrar ----------
  void _submit() {
    FocusScope.of(context).unfocus();

    // Validação dos campos (vazio, formato do e-mail).
    if (!_formKey.currentState!.validate()) return;

    // Consulta o banco simulado. O e-mail é normalizado dentro do banco;
    // a senha é comparada exatamente como foi digitada.
    final user = MockDatabase.instance.login(
      _emailController.text,
      _passwordController.text,
    );

    // Sucesso: não fazemos nada aqui. O banco já avisou o app, e o
    // main.dart troca de tela (esta tela será removida).
    if (user != null) return;

    setState(() {
      _errorMessage =
          'E-mail ou senha incorretos. Confira os dados do seu acesso DUDA.';
    });
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  // ---------- Interface ----------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Identidade do app: estrela amarela da UNIPÊ
                    const Center(child: UniStar(size: 84)),
                    const SizedBox(height: 12),
                    Text(
                      'UniTime',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    // Sublinhado estético em amarelo
                    const SizedBox(height: 6),
                    Center(
                      child: Container(
                        width: 56,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppTheme.yellow,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aprenda com os colegas da UNIPÊ e ensine o que você sabe.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppTheme.gray),
                    ),
                    const SizedBox(height: 32),

                    // E-mail institucional
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: (_) => _clearError(),
                      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      decoration: const InputDecoration(
                        labelText: 'E-mail institucional',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) {
                          return 'Informe seu e-mail institucional.';
                        }
                        if (!text.contains('@') || !text.contains('.')) {
                          return 'Informe um e-mail válido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Senha (padrão do DUDA)
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: (_) => _clearError(),
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Mostrar senha'
                              : 'Ocultar senha',
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) return 'Informe sua senha.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Aviso de erro: X vermelho (#CC0000) indicando falha
                    if (_errorMessage != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.close_rounded,
                              size: 22, color: AppTheme.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: AppTheme.red),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Botão Entrar (azul escuro, vindo do tema)
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: const Text(
                          'Entrar',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Aviso: não existe cadastro pelo app
                    Text(
                      'O acesso é feito com o seu e-mail institucional e a senha '
                      'do sistema acadêmico (DUDA).',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
