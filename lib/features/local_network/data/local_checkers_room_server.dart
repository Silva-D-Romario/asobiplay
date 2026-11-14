import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../checkers/domain/checkers_game.dart';
import '../domain/checkers_room.dart';
import 'local_room_discovery.dart';

class LocalCheckersRoomServer {
  LocalCheckersRoomServer._(this.room);

  final CheckersRoom room;
  final StreamController<CheckersRoomSnapshot> _states =
      StreamController<CheckersRoomSnapshot>.broadcast(sync: true);
  HttpServer? _server;
  WebSocket? _guestSocket;
  LocalRoomDiscoveryResponder? _discovery;
  String _localAddress = '127.0.0.1';

  Stream<CheckersRoomSnapshot> get states => _states.stream;
  CheckersRoomSnapshot get snapshot => room.snapshot;
  int get port => _server?.port ?? 0;
  String get localAddress => _localAddress;
  String get roomCode => room.roomCode;

  static Future<LocalCheckersRoomServer> start({
    required String hostName,
    required CheckersRules rules,
    required int boardColorIndex,
    required int hostPieceColorIndex,
    required int guestPieceColorIndex,
    String? roomCode,
    bool enableDiscovery = true,
  }) async {
    final instance = LocalCheckersRoomServer._(
      CheckersRoom(
        hostName: hostName.trim(),
        rules: rules,
        boardColorIndex: boardColorIndex,
        hostPieceColorIndex: hostPieceColorIndex,
        guestPieceColorIndex: guestPieceColorIndex,
        roomCode: roomCode,
      ),
    );
    await instance._start(enableDiscovery: enableDiscovery);
    return instance;
  }

  Future<void> _start({required bool enableDiscovery}) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0, shared: true);
    _localAddress = await _findLocalIPv4();
    _server!.listen(_handleRequest);
    if (enableDiscovery) {
      try {
        _discovery = await LocalRoomDiscoveryResponder.start(
          roomCode: room.roomCode,
          serverPort: port,
          game: 'checkers',
        );
      } on SocketException {
        _discovery = null;
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path != '/ws' ||
        !WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('AsobiPlay local checkers room');
      await request.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    socket.listen(
      (message) => _handleGuestMessage(socket, message),
      onDone: () => _handleGuestDisconnected(socket),
      onError: (_) => _handleGuestDisconnected(socket),
      cancelOnError: true,
    );
  }

  void _handleGuestMessage(WebSocket socket, dynamic rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage as String);
      if (decoded is! Map<String, dynamic>) return;
      switch (decoded['type']) {
        case 'join':
          final name = decoded['name'] as String? ?? '';
          if (_guestSocket != null &&
              _guestSocket != socket &&
              room.snapshot.guestConnected) {
            socket.close(4001, 'Sala ocupada');
            return;
          }
          if (!room.joinGuest(name)) {
            socket.close(4001, 'Sala ocupada');
            return;
          }
          _guestSocket = socket;
          _emit();
        case 'move':
          if (socket != _guestSocket) return;
          final from = (decoded['from'] as num?)?.toInt();
          final to = (decoded['to'] as num?)?.toInt();
          if (from != null &&
              to != null &&
              room.playAs(CheckersPlayer.two, from, to)) {
            _emit();
          }
        case 'next_round':
          if (socket == _guestSocket && room.nextRound()) _emit();
      }
    } on FormatException {
      socket.add(jsonEncode({'type': 'error', 'message': 'Mensagem inválida'}));
    } on RangeError {
      socket.add(jsonEncode({'type': 'error', 'message': 'Jogada inválida'}));
    } on TypeError {
      socket.add(jsonEncode({'type': 'error', 'message': 'Mensagem inválida'}));
    }
  }

  void _handleGuestDisconnected(WebSocket socket) {
    if (_guestSocket != socket) return;
    _guestSocket = null;
    room.setGuestConnected(false);
    _emit();
  }

  bool playHost(int from, int to) {
    final played = room.playAs(CheckersPlayer.one, from, to);
    if (played) _emit();
    return played;
  }

  bool nextRound() {
    final changed = room.nextRound();
    if (changed) _emit();
    return changed;
  }

  void _emit() {
    final state = room.snapshot;
    if (!_states.isClosed) _states.add(state);
    final socket = _guestSocket;
    if (socket != null && socket.readyState == WebSocket.open) {
      socket.add(jsonEncode(state.toJson()));
    }
  }

  Future<void> close() async {
    await _discovery?.close();
    await _guestSocket?.close();
    await _server?.close(force: true);
    await _states.close();
  }

  static Future<String> _findLocalIPv4() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) return address.address;
      }
    }
    return '127.0.0.1';
  }
}
