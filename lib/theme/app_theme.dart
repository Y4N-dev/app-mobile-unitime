// lib/theme/app_theme.dart
//
// Identidade visual do UniTime, definida UMA vez para o app inteiro.
// Visual claro e simples: predominância do branco, com azul e amarelo
// apenas como destaques.
//
//  - Azul escuro  #003366 -> cabeçalhos e botões
//  - Amarelo      #FFCC00 -> linhas, bordas, sublinhados estéticos e hovers
//  - Branco puro          -> fundo e blocos de vídeo
//  - Preto puro           -> textos de contraste, ícones menores, linhas finas
//  - Cinza                -> subtítulos e mensagens menores
//  - Vermelho     #CC0000 -> curtidas e avisos importantes (X, !, ATENÇÃO)

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ---------- Paleta ----------
  static const Color blue = Color(0xFF003366);
  static const Color yellow = Color(0xFFFFCC00);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color gray = Color(0xFF757575);
  static const Color red = Color(0xFFCC0000);

  // Cores complementares (uso pontual)
  static const Color green = Color(0xFF2E7D32); // ganhos de créditos
  static const Color grayLight =
      Color(0xFFE0E0E0); // trilhos de barras e divisórias suaves

  // Medalhas de nível (decoração simbólica do Perfil): cor da medalha, anel
  // (tom mais escuro) e estrela central (cor de destaque que contrasta).
  static const Color medalChocolate = Color(0xFF7B4B2A);
  static const Color medalChocolateRing = Color(0xFF4F2D17);
  static const Color medalChocolateStar = Color(0xFFFFE2B0);

  static const Color medalBronze = Color(0xFFCD7F32);
  static const Color medalBronzeRing = Color(0xFF8A5522);
  static const Color medalBronzeStar = Color(0xFF4F2B0E);

  static const Color medalSilver = Color(0xFFC4CBD6);
  static const Color medalSilverRing = Color(0xFF8B94A3);
  static const Color medalSilverStar = Color(0xFF003366);

  static const Color medalGold = Color(0xFFE8A900);
  static const Color medalGoldRing = Color(0xFFA67300);
  static const Color medalGoldStar = Color(0xFF003366);

  static const Color medalDiamond = Color(0xFF8EDCF2);
  static const Color medalDiamondRing = Color(0xFF3FA3C4);
  static const Color medalDiamondStar = Color(0xFF003366);

  /// Amarelo translúcido (25%): usado nos efeitos de hover e toque.
  static const Color yellowSoft = Color(0x40FFCC00);

  /// Azul um pouco mais claro: hover e toque dos botões azul escuro.
  static const Color blueHover = Color(0xff0055ab);

  /// Azul um pouco mais escuro que o base: ícones de fundo dos botões grandes.
  static const Color blueDark = Color(0xFF002A52);

  /// Espessura da linha amarela na base dos cabeçalhos.
  static const double headerLineWidth = 4;

  // ---------- Constantes de interface ----------
  /// Duração do aviso rápido (ex.: "Compra não realizada").
  static const Duration noticeDuration = Duration(milliseconds: 1200);

  /// Duração da transição horizontal entre abas (rápida e leve).
  static const Duration tabTransition = Duration(milliseconds: 250);

  static const double radius = 8;

  /// Linha fina preta: contorno de blocos e botões.
  static const BorderSide thinBlack = BorderSide(color: black, width: 1);

  /// Bloco de vídeo: fundo branco com linha fina preta delimitando o tamanho.
  /// Use em um Container: Container(decoration: AppTheme.videoBlockDecoration)
  static const BoxDecoration videoBlockDecoration = BoxDecoration(
    color: white,
    border: Border.fromBorderSide(thinBlack),
    borderRadius: BorderRadius.all(Radius.circular(radius)),
  );

  // ---------- Tema principal ----------
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: blue,
      onPrimary: white,
      secondary: yellow,
      onSecondary: black,
      error: red,
      onError: white,
      surface: white,
      onSurface: black,
      outline: black,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    // Textos: pretos por padrão; subtítulos e mensagens menores em cinza.
    final textTheme =
        base.textTheme.apply(bodyColor: black, displayColor: black).copyWith(
              bodySmall: base.textTheme.bodySmall?.copyWith(color: gray),
              labelSmall: base.textTheme.labelSmall?.copyWith(color: gray),
            );

    // Hover e toque em amarelo suave.
    final yellowOverlay = MaterialStateProperty.resolveWith<Color?>((states) {
      if (states.contains(MaterialState.hovered) ||
          states.contains(MaterialState.pressed) ||
          states.contains(MaterialState.focused)) {
        return yellowSoft;
      }
      return null;
    });

    // Hover e toque dos botões azul escuro: um azul um pouco mais claro.
    final blueOverlay = MaterialStateProperty.resolveWith<Color?>((states) {
      if (states.contains(MaterialState.hovered) ||
          states.contains(MaterialState.pressed) ||
          states.contains(MaterialState.focused)) {
        return blueHover;
      }
      return null;
    });

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    return base.copyWith(
      scaffoldBackgroundColor: white,
      canvasColor: white,
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: black),

      // Cabeçalhos: azul escuro, com linha amarela na base.
      appBarTheme: const AppBarTheme(
        backgroundColor: blue,
        foregroundColor: white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: white),
        titleTextStyle: TextStyle(
          color: white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        shape:
            Border(bottom: BorderSide(color: yellow, width: headerLineWidth)),
      ),

      // Botões principais: azul escuro com texto branco.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: white,
          elevation: 0,
          shape: buttonShape,
        ).copyWith(overlayColor: blueOverlay),
      ),

      // Botões secundários: contorno fino preto.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: black,
          side: thinBlack,
          shape: buttonShape,
        ).copyWith(overlayColor: yellowOverlay),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: blue)
            .copyWith(overlayColor: yellowOverlay),
      ),

      // Campos de texto: borda fina preta; borda amarela ao focar.
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(color: gray),
        floatingLabelStyle: TextStyle(color: blue),
        hintStyle: TextStyle(color: gray),
        prefixIconColor: black,
        suffixIconColor: black,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          borderSide: thinBlack,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          borderSide: thinBlack,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          borderSide: BorderSide(color: yellow, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          borderSide: BorderSide(color: red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          borderSide: BorderSide(color: red, width: 2),
        ),
        errorStyle: TextStyle(color: red),
      ),

      // Barra inferior das 4 abas.
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: white,
        selectedItemColor: blue,
        unselectedItemColor: gray,
        elevation: 0,
        showUnselectedLabels: true,
      ),

      // Linhas divisórias em amarelo.
      dividerTheme: const DividerThemeData(
        color: yellow,
        thickness: 1,
        space: 1,
      ),

      // Cursor e seleção de texto em azul.
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: blue,
        selectionHandleColor: blue,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(color: blue),
    );
  }
}
