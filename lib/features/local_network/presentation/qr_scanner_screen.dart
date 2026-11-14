import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/local_room_invite.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  var _handled = false;
  String? _error;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    final invite = LocalRoomInvite.tryParse(rawValue);
    if (invite == null) {
      setState(() => _error = 'Este QR Code não pertence ao AsobiPlay.');
      return;
    }
    _handled = true;
    Navigator.of(context).pop(invite);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ler QR da sala')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(key: const Key('room-qr-scanner'), onDetect: _onDetect),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.primary, width: 4),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                _error ?? 'Aponte a câmera para o QR exibido pelo anfitrião.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _error == null
                      ? AppColors.textPrimary
                      : AppColors.coral,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
