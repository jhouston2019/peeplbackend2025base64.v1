import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peepl_mobile/services/peepl_positive_messages.dart';
import 'package:peepl_mobile/widgets/peepl_positive_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PeeplPositiveMessages.test(random: Random(42)).resetRotationState();
  });

  group('PeeplPositiveMessages', () {
    test('serves each message once per shuffle cycle', () async {
      final service = PeeplPositiveMessages.test(random: Random(7));
      final seenIds = <int>{};

      for (var i = 0; i < PeeplPositiveMessages.messages.length; i++) {
        final result = await service.next(
          surface: 'popup',
          logAnalytics: false,
        );
        expect(seenIds.contains(result.id), isFalse);
        seenIds.add(result.id);
      }

      expect(seenIds.length, PeeplPositiveMessages.messages.length);
    });

    test('reshuffle avoids repeating the last message of the prior cycle', () async {
      final service = PeeplPositiveMessages.test(random: Random(11));

      PeeplPositiveMessageResult? lastOfFirstCycle;
      for (var i = 0; i < PeeplPositiveMessages.messages.length; i++) {
        lastOfFirstCycle = await service.next(
          surface: 'popup',
          logAnalytics: false,
        );
      }

      final firstOfSecondCycle = await service.next(
        surface: 'popup',
        logAnalytics: false,
      );

      expect(firstOfSecondCycle.id, isNot(lastOfFirstCycle!.id));
    });

    test('persists rotation state across service instances', () async {
      final first = PeeplPositiveMessages.test(random: Random(3));
      final initial = await first.next(surface: 'popup', logAnalytics: false);

      final second = PeeplPositiveMessages.test(random: Random(99));
      final resumed = await second.next(surface: 'popup', logAnalytics: false);

      expect(resumed.id, isNot(initial.id));
      expect(resumed.text, isNot(initial.text));
    });

    test('eligible push types gate enrichment', () async {
      expect(
        PeeplPositiveMessages.isEligiblePushType('walk_in_prompt'),
        isTrue,
      );
      expect(
        PeeplPositiveMessages.isEligiblePushType('reengagement'),
        isFalse,
      );
    });

    test('enrichPushBody keeps functional content first', () async {
      final service = PeeplPositiveMessages.test(random: Random(5));
      final functional = 'How is it right now? Peep it.';

      final enriched = await service.enrichPushBody(
        functional,
        notificationType: 'walk_in_prompt',
        logAnalytics: false,
      );

      expect(enriched.startsWith(functional), isTrue);
      if (enriched.contains('\n')) {
        final signOff = enriched.substring(functional.length + 1);
        expect(PeeplPositiveMessages.messages, contains(signOff));
      }
    });
  });

  group('PeeplPositiveMessage widget', () {
    testWidgets('keeps the same message across rebuilds', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    const PeeplPositiveMessage(contextKey: 'test_popup'),
                    TextButton(
                      onPressed: () => setState(() {}),
                      child: const Text('rebuild'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final messageFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            PeeplPositiveMessages.messages.contains(widget.data),
      );
      expect(messageFinder, findsOneWidget);
      final firstText = tester.widget<Text>(messageFinder.first).data;

      await tester.tap(find.text('rebuild'));
      await tester.pump();

      expect(find.text(firstText!), findsOneWidget);
    });

    testWidgets('long messages stay within two lines', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: PeeplPositiveMessage(
                contextKey: 'overflow_check',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final messageFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            PeeplPositiveMessages.messages.contains(widget.data),
      );
      final textWidget = tester.widget<Text>(messageFinder.first);
      expect(textWidget.maxLines, 2);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });
  });
}
