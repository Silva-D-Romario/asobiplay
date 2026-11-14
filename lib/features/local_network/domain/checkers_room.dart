import 'dart:math';

import '../../checkers/domain/checkers_game.dart';

class CheckersRoomSnapshot {
  const CheckersRoomSnapshot({
    required this.roomCode,
    required this.hostName,
    required this.guestName,
    required this.guestConnected,
    required this.board,
    required this.currentPlayer,
    required this.winner,
    required this.forcedPiece,
    required this.rules,
    required this.boardColorIndex,
    required this.hostPieceColorIndex,
    required this.guestPieceColorIndex,
    required this.scoreHost,
    required this.scoreGuest,
    required this.round,
  });

  final String roomCode;
  final String hostName;
  final String? guestName;
  final bool guestConnected;
  final List<CheckersPiece?> board;
  final CheckersPlayer currentPlayer;
  final CheckersPlayer? winner;
  final int? forcedPiece;
  final CheckersRules rules;
  final int boardColorIndex;
  final int hostPieceColorIndex;
  final int guestPieceColorIndex;
  final int scoreHost;
  final int scoreGuest;
  final int round;

  bool get isReady => guestName != null && guestConnected;
  bool get isFinished => winner != null;

  CheckersGame toGame() => CheckersGame.restored(
    board: board,
    currentPlayer: currentPlayer,
    rules: rules,
    winner: winner,
    forcedPiece: forcedPiece,
  );

  Map<String, Object?> toJson() => {
    'type': 'state',
    'game': 'checkers',
    'roomCode': roomCode,
    'hostName': hostName,
    'guestName': guestName,
    'guestConnected': guestConnected,
    'board': board.map(_pieceToJson).toList(),
    'currentPlayer': _playerName(currentPlayer),
    'winner': _playerName(winner),
    'forcedPiece': forcedPiece,
    'mandatoryCapture': rules.mandatoryCapture,
    'menCanCaptureBackward': rules.menCanCaptureBackward,
    'boardColorIndex': boardColorIndex,
    'hostPieceColorIndex': hostPieceColorIndex,
    'guestPieceColorIndex': guestPieceColorIndex,
    'scoreHost': scoreHost,
    'scoreGuest': scoreGuest,
    'round': round,
  };

  factory CheckersRoomSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['game'] != 'checkers') {
      throw const FormatException('A sala selecionada não é de Damas');
    }
    final rawBoard = json['board'];
    if (rawBoard is! List || rawBoard.length != 64) {
      throw const FormatException('Tabuleiro de Damas inválido');
    }
    final currentPlayer = _playerFromName(json['currentPlayer']);
    if (currentPlayer == null) {
      throw const FormatException('Jogador atual inválido');
    }
    return CheckersRoomSnapshot(
      roomCode: json['roomCode'] as String,
      hostName: json['hostName'] as String,
      guestName: json['guestName'] as String?,
      guestConnected: json['guestConnected'] as bool? ?? false,
      board: rawBoard.map(_pieceFromJson).toList(),
      currentPlayer: currentPlayer,
      winner: _playerFromName(json['winner']),
      forcedPiece: (json['forcedPiece'] as num?)?.toInt(),
      rules: CheckersRules(
        mandatoryCapture: json['mandatoryCapture'] as bool? ?? true,
        menCanCaptureBackward: json['menCanCaptureBackward'] as bool? ?? true,
      ),
      boardColorIndex: (json['boardColorIndex'] as num?)?.toInt() ?? 0,
      hostPieceColorIndex: (json['hostPieceColorIndex'] as num?)?.toInt() ?? 0,
      guestPieceColorIndex:
          (json['guestPieceColorIndex'] as num?)?.toInt() ?? 3,
      scoreHost: (json['scoreHost'] as num?)?.toInt() ?? 0,
      scoreGuest: (json['scoreGuest'] as num?)?.toInt() ?? 0,
      round: (json['round'] as num?)?.toInt() ?? 1,
    );
  }

  static Map<String, Object?>? _pieceToJson(CheckersPiece? piece) =>
      piece == null
      ? null
      : {'player': _playerName(piece.player), 'isKing': piece.isKing};

  static CheckersPiece? _pieceFromJson(dynamic value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Peça de Damas inválida');
    }
    final player = _playerFromName(value['player']);
    if (player == null) throw const FormatException('Peça de Damas inválida');
    return CheckersPiece(
      player: player,
      isKing: value['isKing'] as bool? ?? false,
    );
  }

  static String? _playerName(CheckersPlayer? player) => switch (player) {
    CheckersPlayer.one => 'one',
    CheckersPlayer.two => 'two',
    null => null,
  };

  static CheckersPlayer? _playerFromName(dynamic value) => switch (value) {
    'one' => CheckersPlayer.one,
    'two' => CheckersPlayer.two,
    _ => null,
  };
}

class CheckersRoom {
  CheckersRoom({
    required this.hostName,
    required this.rules,
    required this.boardColorIndex,
    required this.hostPieceColorIndex,
    required this.guestPieceColorIndex,
    String? roomCode,
  }) : roomCode = roomCode ?? generateRoomCode(),
       _game = CheckersGame(rules: rules);

  final String hostName;
  final String roomCode;
  final CheckersRules rules;
  final int boardColorIndex;
  final int hostPieceColorIndex;
  final int guestPieceColorIndex;
  String? _guestName;
  bool _guestConnected = false;
  CheckersGame _game;
  CheckersPlayer _starter = CheckersPlayer.one;
  int _scoreHost = 0;
  int _scoreGuest = 0;
  int _round = 1;
  bool _roundScored = false;

  CheckersRoomSnapshot get snapshot => CheckersRoomSnapshot(
    roomCode: roomCode,
    hostName: hostName,
    guestName: _guestName,
    guestConnected: _guestConnected,
    board: _game.board.toList(),
    currentPlayer: _game.currentPlayer,
    winner: _game.winner,
    forcedPiece: _game.forcedPiece,
    rules: rules,
    boardColorIndex: boardColorIndex,
    hostPieceColorIndex: hostPieceColorIndex,
    guestPieceColorIndex: guestPieceColorIndex,
    scoreHost: _scoreHost,
    scoreGuest: _scoreGuest,
    round: _round,
  );

  bool joinGuest(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty ||
        (_guestName != null && _guestName != normalized)) {
      return false;
    }
    _guestName = normalized;
    _guestConnected = true;
    return true;
  }

  void setGuestConnected(bool connected) {
    _guestConnected = connected && _guestName != null;
  }

  bool playAs(CheckersPlayer player, int from, int to) {
    if (!snapshot.isReady ||
        player != _game.currentPlayer ||
        from < 0 ||
        from >= 64 ||
        to < 0 ||
        to >= 64) {
      return false;
    }
    final piece = _game.board[from];
    if (piece?.player != player) return false;
    final played = _game.move(from, to);
    if (!played || !_game.isFinished || _roundScored) return played;
    if (_game.winner == CheckersPlayer.one) _scoreHost++;
    if (_game.winner == CheckersPlayer.two) _scoreGuest++;
    _roundScored = true;
    return true;
  }

  bool nextRound() {
    if (!snapshot.isReady || !_game.isFinished) return false;
    _starter = _starter == CheckersPlayer.one
        ? CheckersPlayer.two
        : CheckersPlayer.one;
    _game = CheckersGame(firstPlayer: _starter, rules: rules);
    _round++;
    _roundScored = false;
    return true;
  }

  static String generateRoomCode([Random? random]) {
    final generator = random ?? Random.secure();
    return (100000 + generator.nextInt(900000)).toString();
  }
}
