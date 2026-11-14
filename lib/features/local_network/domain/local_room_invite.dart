enum LocalGameType {
  ticTacToe('tic_tac_toe', 'Jogo da Velha'),
  checkers('checkers', 'Damas');

  const LocalGameType(this.id, this.label);

  final String id;
  final String label;

  static LocalGameType? fromId(String? id) {
    for (final type in values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

class LocalRoomInvite {
  const LocalRoomInvite({
    required this.game,
    required this.address,
    required this.port,
    required this.roomCode,
  });

  final LocalGameType game;
  final String address;
  final int port;
  final String roomCode;

  String encode() => Uri(
    scheme: 'asobiplay',
    host: 'room',
    queryParameters: {
      'game': game.id,
      'address': address,
      'port': '$port',
      'code': roomCode,
    },
  ).toString();

  static LocalRoomInvite? tryParse(String? value) {
    if (value == null) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'asobiplay' || uri.host != 'room') {
      return null;
    }
    final game = LocalGameType.fromId(uri.queryParameters['game']);
    final address = uri.queryParameters['address']?.trim();
    final port = int.tryParse(uri.queryParameters['port'] ?? '');
    final code = uri.queryParameters['code']?.trim();
    if (game == null ||
        address == null ||
        address.isEmpty ||
        port == null ||
        port < 1 ||
        port > 65535 ||
        code == null ||
        !RegExp(r'^\d{6}$').hasMatch(code)) {
      return null;
    }
    return LocalRoomInvite(
      game: game,
      address: address,
      port: port,
      roomCode: code,
    );
  }
}
