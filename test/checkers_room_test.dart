import 'package:asobiplay/features/checkers/domain/checkers_game.dart';
import 'package:asobiplay/features/local_network/domain/checkers_room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CheckersRoom', () {
    test('mantém a partida bloqueada até o convidado entrar', () {
      final room = CheckersRoom(
        hostName: 'Romario',
        roomCode: '123456',
        rules: const CheckersRules(),
        boardColorIndex: 1,
        hostPieceColorIndex: 0,
        guestPieceColorIndex: 3,
      );

      expect(room.playAs(CheckersPlayer.one, 40, 33), isFalse);
      expect(room.joinGuest('Bia'), isTrue);
      expect(room.playAs(CheckersPlayer.one, 40, 33), isTrue);
      expect(room.snapshot.currentPlayer, CheckersPlayer.two);
    });

    test('serializa tabuleiro, regras e aparência escolhida', () {
      final room = CheckersRoom(
        hostName: 'Romario',
        roomCode: '654321',
        rules: const CheckersRules(
          mandatoryCapture: false,
          menCanCaptureBackward: false,
        ),
        boardColorIndex: 2,
        hostPieceColorIndex: 4,
        guestPieceColorIndex: 2,
      )..joinGuest('Bia');

      expect(room.playAs(CheckersPlayer.one, 40, 33), isTrue);
      final restored = CheckersRoomSnapshot.fromJson(room.snapshot.toJson());

      expect(restored.board[33]?.player, CheckersPlayer.one);
      expect(restored.rules.mandatoryCapture, isFalse);
      expect(restored.rules.menCanCaptureBackward, isFalse);
      expect(restored.boardColorIndex, 2);
      expect(restored.hostPieceColorIndex, 4);
      expect(restored.guestPieceColorIndex, 2);
      expect(restored.toGame().currentPlayer, CheckersPlayer.two);
    });

    test('rejeita jogada feita pelo jogador fora da vez', () {
      final room = CheckersRoom(
        hostName: 'Romario',
        roomCode: '123456',
        rules: const CheckersRules(),
        boardColorIndex: 0,
        hostPieceColorIndex: 0,
        guestPieceColorIndex: 3,
      )..joinGuest('Bia');

      expect(room.playAs(CheckersPlayer.two, 17, 24), isFalse);
      expect(room.snapshot.currentPlayer, CheckersPlayer.one);
    });
  });
}
