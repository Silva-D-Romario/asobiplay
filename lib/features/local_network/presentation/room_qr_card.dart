import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/local_room_invite.dart';

class RoomQrCard extends StatelessWidget {
  const RoomQrCard({required this.invite, super.key});

  final LocalRoomInvite invite;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('wifi-room-access'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${invite.game.label} · Código da sala'),
              Text(
                invite.roomCode,
                key: const Key('wifi-room-code-display'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              Text('Conexão manual: ${invite.address}:${invite.port}'),
              const SizedBox(height: 6),
              const Text('Escaneie o QR no segundo celular.'),
            ],
          );
          final qr = Semantics(
            label: 'QR Code para entrar na sala',
            child: Container(
              width: 148,
              height: 148,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: QrImageView(
                key: const Key('wifi-room-qr'),
                data: invite.encode(),
                padding: EdgeInsets.zero,
              ),
            ),
          );
          if (constraints.maxWidth < 430) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 14),
                Center(child: qr),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 16),
              qr,
            ],
          );
        },
      ),
    );
  }
}
