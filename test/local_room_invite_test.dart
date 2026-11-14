import 'package:asobiplay/features/local_network/domain/local_room_invite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gera e interpreta convite de sala por QR Code', () {
    const invite = LocalRoomInvite(
      game: LocalGameType.checkers,
      address: '192.168.0.103',
      port: 43210,
      roomCode: '123456',
    );

    final restored = LocalRoomInvite.tryParse(invite.encode());

    expect(restored?.game, LocalGameType.checkers);
    expect(restored?.address, '192.168.0.103');
    expect(restored?.port, 43210);
    expect(restored?.roomCode, '123456');
  });

  test('rejeita QR Code externo ou incompleto', () {
    expect(LocalRoomInvite.tryParse('https://example.com'), isNull);
    expect(LocalRoomInvite.tryParse('asobiplay://room?game=checkers'), isNull);
  });
}
