import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peepl_mobile/notifiers/active_filter_notifier.dart';
import 'package:peepl_mobile/widgets/home/peepl_bottom_navigation.dart';
import 'package:peepl_mobile/widgets/home/quick_filter_row.dart';

void main() {
  testWidgets('Deals footer item opens /deals route', (tester) async {
    var dealsOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: PeeplBottomNavigation(
            onExploreTap: () {},
            onSearchTap: () {},
            onDealsTap: () => Navigator.of(
              tester.element(find.byType(PeeplBottomNavigation)),
            ).pushNamed('/deals'),
            onAlertsTap: () {},
            onProfileTap: () {},
          ),
        ),
        routes: {
          '/deals': (_) {
            dealsOpened = true;
            return const Scaffold(body: Text('Deals Screen'));
          },
        },
      ),
    );

    await tester.tap(find.text('Deals'));
    await tester.pumpAndSettle();

    expect(dealsOpened, isTrue);
    expect(find.text('Deals Screen'), findsOneWidget);
  });

  testWidgets('Map chip opens /map route', (tester) async {
    var mapOpened = false;
    activeFilterNotifier.value = 'Newest';

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (_) => Scaffold(
                body: QuickFilterRow(
                  onMapTap: () {
                    activeFilterNotifier.value = 'Map';
                    Navigator.of(tester.element(find.byType(QuickFilterRow)))
                        .pushNamed('/map');
                  },
                  onMoreTap: () {},
                ),
              ),
          '/map': (_) {
            mapOpened = true;
            return const Scaffold(body: Text('Map Screen'));
          },
        },
      ),
    );

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();

    expect(mapOpened, isTrue);
    expect(activeFilterNotifier.value, 'Map');
    expect(find.text('Map Screen'), findsOneWidget);
  });
}
