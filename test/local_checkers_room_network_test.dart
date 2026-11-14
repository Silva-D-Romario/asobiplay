import 'package:asobiplay/features/checkers/domain/checkers_game.dart';
import 'package:asobiplay/features/local_network/data/local_checkers_room_client.dart';
import 'package:asobiplay/features/local_network/data/local_checkers_room_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sincroniza partida de Damas por WebSocket', () async {
    final server = await LocalCheckersRoomServer.start(
      hostName: 'Romario',
      roomCode: '123456',
      rules: const CheckersRules(),
      boardColorIndex: 1,
      hostPieceColorIndex: 0,
      guestPieceColorIndex: 3,
      enableDiscovery: false,
    );
    addTearDown(server.close);
    final client = await LocalCheckersRoomClient.connect(
      address: '127.0.0.1',
      port: server.port,
      guestName: 'Bia',
    );
    addTearDown(client.close);

    expect(client.snapshot?.isReady, isTrue);
    expect(server.playHost(40, 33), isTrue);
    final guestTurn = await client.states.firstWhere(
      (state) => state.board[33]?.player == CheckersPlayer.one,
    );
    expect(guestTurn.currentPlayer, CheckersPlayer.two);

    client.play(17, 24);
    final hostTurn = await server.states.firstWhere(
      (state) => state.board[24]?.player == CheckersPlayer.two,
    );
    expect(hostTurn.currentPlayer, CheckersPlayer.one);
  });
}
