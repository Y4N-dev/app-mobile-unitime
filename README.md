# ⭐ UniTime

**Aprenda com os colegas. Ensine o que você sabe. O seu tempo vale créditos.**

UniTime é um aplicativo mobile acadêmico de aprendizado peer-to-peer (P2P), construído sobre um sistema de **Banco de Tempo** (*Timebanking*), voltado exclusivamente para estudantes da **UNIPÊ**, em João Pessoa (PB). A ideia central é simples: alunos assistem a videoaulas gravadas por outros colegas, usando créditos de tempo que eles próprios ganham ao publicar seus próprios conteúdos educacionais.

Este repositório contém o MVP (*Minimum Viable Product*) do projeto, desenvolvido em **Flutter/Dart**.

---

## 📑 Índice

- [Sobre o projeto](#-sobre-o-projeto)
- [Funcionalidades](#-funcionalidades)
- [Economia de créditos (Banco de Tempo)](#-economia-de-créditos-banco-de-tempo)
- [Identidade visual](#-identidade-visual)
- [Arquitetura e estrutura do projeto](#-arquitetura-e-estrutura-do-projeto)
- [Tecnologias e pacotes](#-tecnologias-e-pacotes)
- [Como executar](#-como-executar)
- [Contas de teste](#-contas-de-teste)
- [Vídeos de demonstração e créditos](#-vídeos-de-demonstração-e-créditos)
- [Licença](#-licença)
- [Observações futuras](#-observações-futuras)

---

## 📖 Sobre o projeto

O **UniTime** nasce de uma pergunta simples: e se o tempo que um aluno investe explicando algo que ele já domina pudesse ser trocado pelo tempo de outro aluno explicando algo diferente? É esse o coração do *Timebanking*: uma economia fechada, entre pares, sem dinheiro real envolvido — só o tempo de estudo de cada um.

Como é um MVP acadêmico, o aplicativo roda de forma **totalmente autossuficiente**, sem depender de nenhuma integração oficial com os sistemas da faculdade. Ele utiliza um **Mock Database** (banco de dados local simulado), pré-populado com alunos e vídeos de demonstração, o que garante estabilidade total durante testes e apresentações.

---

## 🚀 Funcionalidades

O aplicativo é estruturado em uma barra de navegação fixa com **4 abas principais**.

### 🔐 Autenticação
Login exclusivo com e-mail institucional e senha (no padrão do sistema acadêmico DUDA). Não existe nenhuma tela ou rota de cadastro pelo app — os dados acadêmicos (nome, RGM, curso, semestre) já vêm pré-populados no banco local. Todo novo aluno recebe um fundo inicial (*bootstrap*) de **100 créditos**, único e sem recargas automáticas.

### 🏠 Página Principal (Feed)
- Cabeçalho com busca rápida (ignora acentos e maiúsculas) e menu horizontal de **15 tópicos** de cursos variados do ensino superior, mais a categoria fixa "Principal".
- Grade de vídeos em blocos de cantos arredondados, com thumbnail, duração, título, autor (no formato `@NomeSobrenome`), curtidas, visualizações e a média de avaliações em estrelas.
- Os vídeos de maior impacto formam o **Top 20**, fixado automaticamente no topo de cada tópico.

### 🎬 Player de Vídeo
- Pop-up de confirmação antes de qualquer desbloqueio, mostrando custo e saldo atual.
- Player real, em área fixa de proporção **16:9** (com faixas pretas para vídeos gravados na vertical, sem cortar nem esticar a imagem).
- Curtir, comentar, avaliar (1 a 5 estrelas, com texto opcional) e denunciar — todas as interações disponíveis apenas para quem desbloqueou o vídeo (ou para o próprio autor).
- O autor nunca compra, avalia ou denuncia o próprio conteúdo.

### 💰 Métricas de Créditos
O painel financeiro do aluno no Banco de Tempo, em uma única rolagem:
- Saldo atual e equivalência em minutos de consumo.
- Estimativas de uso (vídeos ao alcance do saldo, mais barato e mais caro).
- Balanço de minutos **aprendidos** e **ensinados**.
- Resumo de ganhos e gastos por origem, com barras de proporção.
- Histórico de vídeos desbloqueados (atalho de consumo).
- Rendimento de cada vídeo publicado, com o aviso do impacto de uma eventual exclusão.
- Extrato completo de créditos, com filtros e paginação.

### 📤 Publicador de Vídeos
- **Enviar Vídeo:** formulário com leitura da duração real do arquivo (que define o preço automaticamente), capa opcional com prévia e alerta de dimensões, título, descrição, tópico principal e sub-tópico.
- **Gerenciar Vídeos:** métricas individuais de cada vídeo (curtidas, visualizações, média de avaliações), edição de metadados a custo fixo e exclusão com justificativa obrigatória.

### 🏅 Perfil e Missões Diárias
- Dados do aluno, foto de perfil editável e biografia opcional.
- Sistema de progressão simbólico: **nível e barra de XP**, **medalha** por faixa de nível (Chocolate, Bronze, Prata, Ouro, Diamante) e **sequência de dias** (corrente), com resumo da semana.
- **4 missões diárias**, com variação ao longo da semana, calculadas sobre dados que o próprio app já registra (sem contadores paralelos). O XP só pode ser ganho por missões e resgatado no mesmo dia.
- Toda a seção de progressão é estritamente privada, visível apenas para o dono da conta.

---

## 🏦 Economia de Créditos (Banco de Tempo)

A regra central do UniTime é simples e inviolável:

> **10 créditos por minuto inteiro de vídeo**, com piso mínimo de 1 minuto (nunca há frações ou decimais).

| Regra | Comportamento |
|---|---|
| **Desbloqueio** | O comprador paga o custo exato; o autor recebe **100%** do valor pago. |
| **Reabertura** | Um vídeo já desbloqueado pode ser assistido de novo, sem nova cobrança. |
| **Acesso do autor** | O autor nunca compra o próprio vídeo: acesso livre, sem débito, fora do histórico de desbloqueados. |
| **Edição de metadados** | Custo fixo de 10 créditos, cobrado **apenas quando** algum campo muda de fato. Esses créditos saem de circulação. |
| **Exclusão de vídeo** | Os compradores recebem **100%** dos créditos gastos de volta; o autor perde **100%** do que ganhou com aquele vídeo. |
| **Piso de segurança** | Nenhum saldo pode ficar negativo. Se a penalidade superar o saldo do autor, a perda é limitada ao que ele possui. |
| **Missões diárias** | Dão **apenas XP**, nunca créditos — os níveis são puramente simbólicos. |

Todas essas regras moram em um único serviço (`credit_service.dart`), e cada operação valida tudo antes de alterar qualquer saldo — nunca ficando pela metade.

---

## 🎨 Identidade Visual

O design é claro, simples e com predominância do branco, para que o azul e o amarelo não sobrecarreguem o campo de visão.

| Cor | Uso |
|---|---|
| 🔵 Azul escuro `#003366` | Cabeçalhos e botões |
| 🟡 Amarelo `#FFCC00` | Linhas, bordas e sublinhados estéticos |
| ⚪ Branco | Fundo principal e blocos de vídeo |
| ⚫ Preto | Textos de contraste e linhas finas |
| ⬜ Cinza | Subtítulos e mensagens secundárias |
| 🔴 Vermelho `#CC0000` | Curtidas e avisos importantes |
| 🟢 Verde `#2E7D32` | Ganhos de créditos |
| 🔵 Azul hover `#004080` | Hover/toque dos botões azuis |
| 🔵 Azul profundo `#002A52` | Ícones de fundo dos botões do Publicador |

A **estrela amarela da UNIPÊ** é desenhada inteiramente por código (sem nenhuma imagem), servindo como logo, espaço reservado de thumbnails e marca d'água. A medalha de nível e a corrente da sequência de dias seguem o mesmo princípio: desenhadas por código, leves e nítidas em qualquer tamanho. As animações são reduzidas ao mínimo necessário, mantendo o aplicativo leve.

---

## 🏗️ Arquitetura e Estrutura do Projeto

O código é organizado em camadas simples, cada uma com responsabilidade única — o que faz a regra de créditos ser ajustada em um só lugar, e uma futura troca de armazenamento afetar apenas a camada de dados.

```
lib/
├── main.dart                     # Ponto de entrada e tema do app
│
├── models/                       # Modelos de dados (puros, sem regra de negócio)
│   ├── user_model.dart
│   ├── video_model.dart
│   ├── credit_transaction_model.dart
│   ├── video_feedback_model.dart     # Comentários e avaliações
│   └── xp_entry_model.dart
│
├── data/
│   └── mock_database.dart        # Banco local simulado — fonte única de dados
│
├── services/                     # Regras de negócio, sem nenhuma tela
│   ├── credit_service.dart       # O motor financeiro do app
│   ├── metrics_service.dart
│   ├── progression_service.dart  # Curva de nível e faixas de medalha
│   └── mission_service.dart      # Missões diárias, resgate e sequência
│
├── theme/
│   └── app_theme.dart            # Paleta e estilos únicos do app
│
├── widgets/                      # Componentes visuais reutilizáveis
│   ├── uni_star.dart
│   ├── video_thumbnail.dart
│   ├── app_notice.dart           # Aviso rápido unificado
│   ├── app_dialog.dart           # Casca única dos pop-ups
│   ├── level_medal.dart
│   └── streak_chain.dart
│
├── utils/                        # Utilitários de plataforma
│   ├── media_picker.dart         # Seleção de vídeo e imagem
│   ├── author_handle.dart        # Identificador público (@Autor)
│   ├── blob_url_web.dart         # Arquivos no navegador
│   └── blob_url_stub.dart        # Arquivos no celular
│
└── screens/                      # Telas do aplicativo
    ├── login_screen.dart
    ├── main_shell.dart           # Navegação principal (4 abas)
    ├── home_screen.dart
    ├── watch_screen.dart
    ├── metrics_screen.dart
    ├── publisher_screen.dart
    ├── upload_video_screen.dart
    ├── manage_videos_screen.dart
    └── profile_screen.dart
```

---

## 🛠️ Tecnologias e Pacotes

- **[Flutter](https://flutter.dev) / Dart** — desenvolvido e testado no [FlutLab.io](https://flutlab.io)
- [`video_player`](https://pub.dev/packages/video_player) — reprodução real dos vídeos
- [`file_picker`](https://pub.dev/packages/file_picker) — seleção de arquivos de vídeo e imagem
- [`web`](https://pub.dev/packages/web) — suporte a arquivos temporários no navegador

---

## ▶️ Como Executar

```bash
# Clone o repositório
git clone https://github.com/<seu-usuario>/unitime.git
cd unitime

# Instale as dependências
flutter pub get

# Rode o aplicativo
flutter run
```

O aplicativo foi testado tanto no **navegador** (web) quanto em **APK** instalado em um dispositivo Android físico, funcionando normalmente nas duas plataformas.

---

## 👩‍🎓 Contas de Teste

O banco local vem pré-populado com 5 alunos, todos com o fundo inicial de 100 créditos:

| Aluno | Curso | E-mail | Senha |
|---|---|---|---|
| Lucas Henrique Barbosa | Análise e Desenvolvimento de Sistemas | `lucas.barbosa@cs.unipe.edu.br` | `@LHB123456` |
| Mariana Costa Albuquerque | Direito | `mariana.albuquerque@cs.unipe.edu.br` | `@MCA123456` |
| Rafael Torres Nogueira | Engenharia Civil | `rafael.nogueira@cs.unipe.edu.br` | `@RTN123456` |
| Beatriz Lima Cavalcanti | Enfermagem | `beatriz.cavalcanti@cs.unipe.edu.br` | `@BLC123456` |
| Gabriel Souza Pereira | Administração | `gabriel.pereira@cs.unipe.edu.br` | `@GSP123456` |

---

## 🎞️ Vídeos de Demonstração e Créditos

Os vídeos de demonstração do banco local são curtas-metragens de uso livre, produzidos pela **Blender Foundation** sob licença **Creative Commons BY (CC BY 3.0)**:

- *Big Buck Bunny* — © 2008 Blender Foundation — [bigbuckbunny.org](https://www.bigbuckbunny.org)
- *Sintel* — © Blender Foundation — [sintel.org](https://durian.blender.org)
- *Elephants Dream* — Blender Foundation
- *Tears of Steel* — © Blender Foundation — [tearsofsteel.org](https://mango.blender.org)

Esses vídeos servem apenas para testes do player e serão substituídos por conteúdo real dos alunos em uma versão futura.

---

## 📄 Licença

Este projeto é distribuído sob a licença **MIT**. Veja o arquivo `LICENSE` para mais detalhes.

---

## 🔭 Observações Futuras

Ideias e melhorias já discutidas e planejadas para versões futuras do UniTime, fora do escopo deste MVP:

- **Banco de dados persistente:** migração do armazenamento em memória (hoje reiniciado a cada sessão) para um banco local persistente (SQLite) ou para um banco de dados online, o que também habilitaria o uso P2P real entre aparelhos diferentes.
- **Telas de carregamento reais:** uma tela de abertura e uma pós-login, com a duração vinculada ao tempo real de carregamento dos dados — função que só faz sentido plenamente junto da migração de armazenamento acima.
- **Destino real para denúncias:** hoje o conteúdo da denúncia é apenas coletado na interface; futuramente será registrado e encaminhado a um fluxo de moderação.
- **Testes de carga e escalabilidade:** avaliação de quantos usuários simultâneos o sistema suportaria, caso a migração para um banco online seja adotada.
- **Conteúdo de demonstração real:** substituição gradual dos vídeos de uso livre por videoaulas produzidas pelos próprios alunos.
- **Reforço no risco do piso de crédito zerado:** mitigação adicional para o caso (hoje aceito como risco de MVP) de um autor esgotar o saldo antes de excluir um vídeo já pago.

---

<p align="center">Feito com 💛 e 💙 para os estudantes da UNIPÊ.</p>
