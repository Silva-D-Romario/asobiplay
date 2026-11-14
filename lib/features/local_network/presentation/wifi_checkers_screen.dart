import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../checkers/domain/checkers_game.dart';
import '../../checkers/presentation/checkers_colors.dart';
import '../data/local_checkers_room_client.dart';
import '../data/local_checkers_room_server.dart';
import '../domain/checkers_room.dart';
import '../domain/local_room_invite.dart';
import 'room_qr_card.dart';

class WifiCheckersScreen extends StatefulWidget {
  const WifiCheckersScreen.host({
    required LocalCheckersRoomServer server,
    super.key,
  }) : _server = server,
       _client = null;

  const WifiCheckersScreen.guest({
    required LocalCheckersRoomClient client,
    super.key,
  }) : _server = null,
       _client = client;

  final LocalCheckersRoomServer? _server;
  final LocalCheckersRoomClient? _client;

  bool get isHost => _server != null;

  @override
  State<WifiCheckersScreen> createState() => _WifiCheckersScreenState();
}

class _WifiCheckersScreenState extends State<WifiCheckersScreen> {
  StreamSubscription<CheckersRoomSnapshot>? _subscription;
  late CheckersRoomSnapshot _snapshot;
  int? _selected;
  String? _connectionError;

  CheckersPlayer get _localPlayer =>
      widget.isHost ? CheckersPlayer.one : CheckersPlayer.two;

  CheckersGame get _game => _snapshot.toGame();

  @override
  void initState() {
    super.initState();
    _snapshot = widget._server?.snapshot ?? widget._client!.snapshot!;
    final stream = widget._server?.states ?? widget._client!.states;
    _subscription = stream.listen(
      (state) {
        if (!mounted) return;
        setState(() {
          _snapshot = state;
          _connectionError = null;
          _selected = state.currentPlayer == _localPlayer
              ? state.forcedPiece
              : null;
        });
      },
      onError: (_) {
        if (mounted) {
          setState(
            () => _connectionError = 'A conexão com a sala foi perdida.',
          );
        }
      },
      onDone: () {
        if (mounted && !widget.isHost) {
          setState(() => _connectionError = 'O anfitrião encerrou a sala.');
        }
      },
    );
  }

  @override
  void dispose() {
    final subscription = _subscription;
    if (subscription != null) unawaited(subscription.cancel());
    final server = widget._server;
    if (server != null) unawaited(server.close());
    final client = widget._client;
    if (client != null) unawaited(client.close());
    super.dispose();
  }

  void _tapCell(int index) {
    if (!_snapshot.isReady ||
        _snapshot.isFinished ||
        _snapshot.currentPlayer != _localPlayer) {
      return;
    }
    final game = _game;
    if (_selected != null &&
        game.legalMovesFor(_selected!).any((move) => move.to == index)) {
      final from = _selected!;
      setState(() => _selected = null);
      if (widget.isHost) {
        widget._server!.playHost(from, index);
      } else {
        widget._client!.play(from, index);
      }
      return;
    }
    final piece = game.board[index];
    if (piece?.player == _localPlayer && game.legalMovesFor(index).isNotEmpty) {
      setState(() => _selected = index);
    } else if (game.forcedPiece == null) {
      setState(() => _selected = null);
    }
  }

  void _nextRound() {
    if (widget.isHost) {
      widget._server!.nextRound();
    } else {
      widget._client!.nextRound();
    }
  }

  String _nameFor(CheckersPlayer player) => player == CheckersPlayer.one
      ? _snapshot.hostName
      : (_snapshot.guestName ?? 'Convidado');

  String get _status {
    if (!_snapshot.isReady) return 'Aguardando o segundo jogador';
    if (_snapshot.winner case final winner?) {
      return '${_nameFor(winner)} venceu!';
    }
    if (_snapshot.forcedPiece != null) {
      return '${_nameFor(_snapshot.currentPlayer)} deve continuar capturando';
    }
    return 'Vez de ${_nameFor(_snapshot.currentPlayer)}';
  }

  @override
  Widget build(BuildContext context) {
    final boardColors =
        checkersBoardOptions[_snapshot.boardColorIndex.clamp(
          0,
          checkersBoardOptions.length - 1,
        )];
    final hostColor =
        checkersPieceColorOptions[_snapshot.hostPieceColorIndex.clamp(
              0,
              checkersPieceColorOptions.length - 1,
            )]
            .color;
    final guestColor =
        checkersPieceColorOptions[_snapshot.guestPieceColorIndex.clamp(
              0,
              checkersPieceColorOptions.length - 1,
            )]
            .color;
    final pieceColors = CheckersPieceColors(
      playerOne: hostColor,
      playerTwo: guestColor,
    );
    final localTurn =
        _snapshot.isReady &&
        !_snapshot.isFinished &&
        _snapshot.currentPlayer == _localPlayer;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.8, -0.8),
            radius: 1.25,
            colors: [Color(0xFF20214A), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                sliver: SliverList.list(
                  children: [
                    const _TopBar(),
                    const SizedBox(height: 16),
                    if (widget.isHost)
                      RoomQrCard(
                        invite: LocalRoomInvite(
                          game: LocalGameType.checkers,
                          address: widget._server!.localAddress,
                          port: widget._server!.port,
                          roomCode: widget._server!.roomCode,
                        ),
                      ),
                    if (widget.isHost) const SizedBox(height: 14),
                    if (_connectionError != null)
                      _MessageCard(
                        message: _connectionError!,
                        color: AppColors.coral,
                      ),
                    if (_connectionError != null) const SizedBox(height: 14),
                    _Scoreboard(
                      snapshot: _snapshot,
                      hostColor: hostColor,
                      guestColor: guestColor,
                    ),
                    const SizedBox(height: 14),
                    _TurnBanner(status: _status, localTurn: localTurn),
                    const SizedBox(height: 18),
                    if (!_snapshot.isReady)
                      const _WaitingCard()
                    else ...[
                      _NetworkCheckersBoard(
                        game: _game,
                        selected: _selected,
                        boardColors: boardColors,
                        pieceColors: pieceColors,
                        onTap: _tapCell,
                      ),
                      const SizedBox(height: 18),
                      if (_snapshot.isFinished)
                        _ResultCard(text: _status, onNextRound: _nextRound)
                      else
                        Text(
                          localTurn
                              ? 'Sua vez: selecione uma peça e uma casa destacada.'
                              : 'Aguarde a jogada de ${_nameFor(_snapshot.currentPlayer)}.',
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Sair da sala',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Damas',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text('Sala Wi-Fi · anfitrião valida as jogadas'),
            ],
          ),
        ),
        Icon(Icons.wifi_rounded, color: AppColors.primary),
      ],
    );
  }
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({
    required this.snapshot,
    required this.hostColor,
    required this.guestColor,
  });

  final CheckersRoomSnapshot snapshot;
  final Color hostColor;
  final Color guestColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PlayerCard(
            name: snapshot.hostName,
            score: snapshot.scoreHost,
            color: hostColor,
            active:
                snapshot.isReady &&
                !snapshot.isFinished &&
                snapshot.currentPlayer == CheckersPlayer.one,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PlayerCard(
            name: snapshot.guestName ?? 'Aguardando...',
            score: snapshot.scoreGuest,
            color: guestColor,
            active:
                snapshot.isReady &&
                !snapshot.isFinished &&
                snapshot.currentPlayer == CheckersPlayer.two,
          ),
        ),
      ],
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.name,
    required this.score,
    required this.color,
    required this.active,
  });

  final String name;
  final int score;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.13) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.surfaceLight,
          width: active ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white70),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text('$score vitória${score == 1 ? '' : 's'}'),
                if (active)
                  const Text(
                    'JOGANDO',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnBanner extends StatelessWidget {
  const _TurnBanner({required this.status, required this.localTurn});

  final String status;
  final bool localTurn;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('wifi-checkers-turn-status'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: localTurn ? AppColors.primary : AppColors.surfaceLight,
          width: localTurn ? 2 : 1,
        ),
      ),
      child: Text(
        localTurn ? '$status · SUA VEZ' : status,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: localTurn ? AppColors.primary : AppColors.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _NetworkCheckersBoard extends StatelessWidget {
  const _NetworkCheckersBoard({
    required this.game,
    required this.selected,
    required this.boardColors,
    required this.pieceColors,
    required this.onTap,
  });

  final CheckersGame game;
  final int? selected;
  final CheckersBoardColors boardColors;
  final CheckersPieceColors pieceColors;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final destinations = selected == null
        ? const <int>[]
        : game.legalMovesFor(selected!).map((move) => move.to).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, 560.0);
        return Center(
          child: Container(
            key: const Key('wifi-checkers-board'),
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceLight, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 28),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
              ),
              itemCount: 64,
              itemBuilder: (context, index) {
                final row = index ~/ 8;
                final column = index % 8;
                final piece = game.board[index];
                final isSelected = selected == index;
                final isDestination = destinations.contains(index);
                final squareColor = (row + column).isEven
                    ? boardColors.light
                    : boardColors.dark;
                final pieceColor = piece?.player == CheckersPlayer.one
                    ? pieceColors.playerOne
                    : pieceColors.playerTwo;
                return GestureDetector(
                  key: Key('wifi-checkers-cell-$index'),
                  onTap: () => onTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    color: isSelected
                        ? Color.alphaBlend(
                            AppColors.primary.withValues(alpha: 0.42),
                            squareColor,
                          )
                        : squareColor,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isDestination)
                          Container(
                            width: size / 28,
                            height: size / 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.72),
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (piece != null)
                          Container(
                            width: size / 11,
                            height: size / 11,
                            decoration: BoxDecoration(
                              color: pieceColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.65),
                                width: isSelected ? 3 : 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: piece.isKing
                                ? Icon(
                                    Icons.workspace_premium_rounded,
                                    size: size / 20,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard();

  @override
  Widget build(BuildContext context) {
    return const _MessageCard(
      key: Key('wifi-checkers-waiting-player'),
      message:
          'Aguardando o convidado entrar...\nCompartilhe o QR ou o código da sala.',
      color: AppColors.primary,
      loading: true,
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.color,
    this.loading = false,
    super.key,
  });

  final String message;
  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          if (loading) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.text, required this.onNextRound});

  final String text;
  final VoidCallback onNextRound;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Text(text, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('wifi-checkers-next-round'),
            onPressed: onNextRound,
            child: const Text('Jogar novamente'),
          ),
        ],
      ),
    );
  }
}
