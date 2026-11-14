import 'package:asobiplay/core/theme/app_theme.dart';
import 'package:asobiplay/features/local_network/presentation/wifi_lobby_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('apresenta criação e entrada em sala Wi-Fi', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const WifiLobbyScreen()),
    );

    expect(find.text('Criar sala'), findsOneWidget);
    expect(find.text('Entrar na sala'), findsOneWidget);
    expect(find.byKey(const Key('wifi-host-name')), findsOneWidget);
    expect(find.byKey(const Key('wifi-room-code')), findsOneWidget);
    expect(find.byKey(const Key('wifi-game-picker')), findsOneWidget);
    expect(find.byKey(const Key('scan-room-qr')), findsOneWidget);
    expect(find.textContaining('mesma rede Wi-Fi'), findsOneWidget);

    await tester.tap(find.text('Damas').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wifi-checkers-options')), findsOneWidget);
    expect(find.text('Criar sala de Damas'), findsOneWidget);
  });
}
