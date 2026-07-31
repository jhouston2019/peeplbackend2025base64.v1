import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peepl_mobile/constants/national_brand_ads.dart';
import 'package:peepl_mobile/utils/crowd_display_mapper.dart';
import 'package:peepl_mobile/widgets/home/editorial_feed_layout.dart';
import 'package:peepl_mobile/widgets/home/happening_now_ticker.dart';
import 'package:peepl_mobile/widgets/home/organic_crowd_card.dart';
import 'package:peepl_mobile/widgets/home/peepl_bottom_navigation.dart';
import 'package:peepl_mobile/widgets/home/peepl_home_header.dart';
import 'package:peepl_mobile/widgets/home/peepl_home_tokens.dart';
import 'package:peepl_mobile/widgets/home/quick_filter_row.dart';
import 'package:peepl_mobile/widgets/home/sponsored_native_card.dart';

/// Mirrors production home shell + editorial feed for viewport density checks.
class _HomeFeedViewportHarness extends StatelessWidget {
  const _HomeFeedViewportHarness({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final rows = EditorialFeedLayout.rowsFromItems(items);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: PeeplHomeTokens.feedBackground,
      body: Column(
        children: [
          ColoredBox(
            color: PeeplHomeTokens.shellNavy,
            child: Padding(
              padding: EdgeInsets.only(top: topInset + 4, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PeeplHomeHeader(
                    areaLabel: 'Perimeter Mall Area',
                    onLocationTap: () {},
                    onProfileTap: () {},
                    onMenuTap: () {},
                    onPostTap: () {},
                    onRequestPeepTap: () {},
                  ),
                  QuickFilterRow(
                    onMapTap: () {},
                    onMoreTap: () {},
                  ),
                  HappeningNowTicker(
                    text: '20% off @ Local Brewery  •  Happy hour now',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < rows.length - 1
                        ? PeeplHomeTokens.rowVerticalGap
                        : 0,
                  ),
                  child: SizedBox(
                    key: ValueKey('feed_row_$index'),
                    height: EditorialFeedLayout.rowHeight(row),
                    child: _buildEditorialRow(context, row),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: PeeplBottomNavigation(
        onExploreTap: () {},
        onSearchTap: () {},
        onDealsTap: () {},
        onAlertsTap: () {},
        onProfileTap: () {},
      ),
    );
  }

  Widget _buildEditorialRow(BuildContext context, EditorialFeedRow row) {
    switch (row.kind) {
      case EditorialRowKind.featuredOrganic:
        return _organic(row.items.first, OrganicCardSize.featured);
      case EditorialRowKind.halfOrganicPair:
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PeeplHomeTokens.cardHorizontalMargin,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _organic(row.items[0], OrganicCardSize.half, 0)),
              const SizedBox(width: PeeplHomeTokens.halfCardGap),
              Expanded(child: _organic(row.items[1], OrganicCardSize.half, 0)),
            ],
          ),
        );
      case EditorialRowKind.sponsored:
        final ad = row.items.first;
        return SponsoredNativeCard(
          name: (ad['advertiser'] ?? 'Sponsor').toString(),
          tagline: (ad['tagline'] ?? '').toString(),
          offerLine: (ad['tagline'] ?? '').toString(),
          initial: (ad['initial'] ?? 'A').toString(),
          accentColor: Color((ad['accentColor'] as int?) ?? 0xFF2E6CFF),
          imageUrl: NationalBrandAds.imageSource(ad),
          ctaLabel: (ad['cta'] ?? 'Learn More').toString(),
          onOpen: () {},
          onCta: () {},
        );
    }
  }

  Widget _organic(
    Map<String, dynamic> post,
    OrganicCardSize size, [
    double? marginHorizontal,
  ]) {
    return OrganicCrowdCard(
      imageUrl: 'assets/ads/cocacola.png',
      name: post['locationName']?.toString() ?? 'Venue',
      crowdData: CrowdDisplayMapper.fromPost(post),
      distanceLabel: post['distance']?.toString(),
      waitLabel: post['waitTime'] != null ? 'Wait ${post['waitTime']}' : null,
      size: size,
      marginHorizontal: marginHorizontal,
      onTap: () {},
    );
  }
}

List<Map<String, dynamic>> _mockFeedItems({required int organicCount}) {
  final items = <Map<String, dynamic>>[];
  var organic = 0;
  var patternIndex = 0;
  var sinceAd = 0;
  const pattern = [3, 2, 3];
  var nextThreshold = pattern[0];
  var adIndex = 0;

  while (organic < organicCount) {
    if (sinceAd >= nextThreshold) {
      final ad = Map<String, dynamic>.from(
        NationalBrandAds.all[adIndex % NationalBrandAds.all.length],
      );
      ad['type'] = 'ad';
      items.add(ad);
      sinceAd = 0;
      patternIndex = (patternIndex + 1) % pattern.length;
      nextThreshold = pattern[patternIndex];
      adIndex++;
    }

    items.add({
      'type': 'post',
      'id': 'post_$organic',
      'locationName': 'Venue ${organic + 1}',
      'imageUrl': 'assets/ads/cocacola.png',
      'crowdingLevel': organic % 11,
      'distance': '${(organic % 9) + 1}.${organic % 10} mi',
      'waitTime': '${5 + (organic % 20)} min',
    });
    organic++;
    sinceAd++;
  }
  return items;
}

int _countCompleteVisibleRows(WidgetTester tester) {
  final listBox = tester.renderObject<RenderBox>(find.byType(ListView));
  final feedTop = listBox.localToGlobal(Offset.zero).dy;
  final feedBottom = feedTop + listBox.size.height;

  var completeRows = 0;
  for (var i = 0; i < 32; i++) {
    final rowFinder = find.byKey(ValueKey('feed_row_$i'));
    if (rowFinder.evaluate().isEmpty) break;

    final rowBox = tester.renderObject<RenderBox>(rowFinder);
    final top = rowBox.localToGlobal(Offset.zero).dy;
    final bottom = top + rowBox.size.height;

    if (bottom <= feedTop + 0.5) continue;
    if (top >= feedBottom - 0.5) break;

    if (top >= feedTop - 0.5 && bottom <= feedBottom + 0.5) {
      completeRows++;
    } else {
      break;
    }
  }

  return completeRows;
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  required Size logicalSize,
  required EdgeInsets padding,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(
    logicalSize.width * 3,
    logicalSize.height * 3,
  );
  addTearDown(tester.view.reset);

  final items = _mockFeedItems(organicCount: 20);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: logicalSize,
        padding: padding,
        devicePixelRatio: 3,
      ),
      child: MaterialApp(
        home: _HomeFeedViewportHarness(items: items),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const viewports = <String, Size>{
    '390x844': Size(390, 844),
    '393x852': Size(393, 852),
    '412x915': Size(412, 915),
  };

  const iosSafeArea = EdgeInsets.only(top: 47, bottom: 34);

  for (final entry in viewports.entries) {
    testWidgets('reports complete row count at ${entry.key}', (tester) async {
      await _pumpHarness(
        tester,
        logicalSize: entry.value,
        padding: iosSafeArea,
      );
      final rows = _countCompleteVisibleRows(tester);
      // ignore: avoid_print
      print('VIEWPORT ${entry.key}: $rows complete feed rows visible');
      expect(rows, greaterThanOrEqualTo(8));
    });
  }

  for (final entry in viewports.entries) {
    testWidgets(
      'complete feed rows visible at ${entry.key} (iOS safe area)',
      (tester) async {
        await _pumpHarness(
          tester,
          logicalSize: entry.value,
          padding: iosSafeArea,
        );

        final rows = _countCompleteVisibleRows(tester);
        expect(
          rows,
          greaterThanOrEqualTo(8),
          reason:
              'Expected ≥8 complete feed rows above bottom nav at ${entry.key}; '
              'cardHeight=${PeeplHomeTokens.featuredCardHeight}, '
              'rowGap=${PeeplHomeTokens.rowVerticalGap}',
        );
      },
    );
  }

  testWidgets('initial editorial sequence starts featured → half pair', (
    WidgetTester tester,
  ) async {
    await _pumpHarness(
      tester,
      logicalSize: const Size(390, 844),
      padding: iosSafeArea,
    );

    final organicOnly = List.generate(8, (i) {
      return {
        'type': 'post',
        'id': 'post_$i',
        'locationName': 'Venue ${i + 1}',
        'imageUrl': 'assets/ads/cocacola.png',
        'crowdingLevel': i % 11,
      };
    });
    final rows = EditorialFeedLayout.rowsFromItems(organicOnly);
    expect(rows.length, greaterThanOrEqualTo(5));
    expect(rows[0].kind, EditorialRowKind.featuredOrganic);
    expect(rows[1].kind, EditorialRowKind.halfOrganicPair);
    expect(rows[2].kind, EditorialRowKind.featuredOrganic);

    final withAds = _mockFeedItems(organicCount: 12);
    final adRows = EditorialFeedLayout.rowsFromItems(withAds);
    final firstSponsored = adRows.indexWhere(
      (row) => row.kind == EditorialRowKind.sponsored,
    );
    expect(firstSponsored, greaterThan(0));
    for (final row in adRows.where((r) => r.kind == EditorialRowKind.sponsored)) {
      expect(row.items.length, 1);
    }
  });

  testWidgets('half-width cards are equal width', (WidgetTester tester) async {
    await _pumpHarness(
      tester,
      logicalSize: const Size(390, 844),
      padding: iosSafeArea,
    );

    final items = _mockFeedItems(organicCount: 20);
    final rows = EditorialFeedLayout.rowsFromItems(items);
    final halfIndex = rows.indexWhere(
      (row) => row.kind == EditorialRowKind.halfOrganicPair,
    );
    expect(halfIndex, greaterThan(0));

    final halfPairFinder = find.byKey(ValueKey('feed_row_$halfIndex'));
    expect(halfPairFinder, findsOneWidget);

    final cards = find.descendant(
      of: halfPairFinder,
      matching: find.byType(OrganicCrowdCard),
    );
    expect(cards, findsNWidgets(2));

    final left = tester.getSize(cards.first);
    final right = tester.getSize(cards.at(1));
    expect(left.width, closeTo(right.width, 1));

    final rowWidth =
        390 - (PeeplHomeTokens.cardHorizontalMargin * 2);
    expect(
      left.width * 2 + PeeplHomeTokens.halfCardGap,
      closeTo(rowWidth, 2),
    );
  });

  testWidgets('scroll offset preserved when returning from detail navigation', (
    WidgetTester tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    final items = _mockFeedItems(organicCount: 20);
    final rows = EditorialFeedLayout.rowsFromItems(items);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: 47, bottom: 34),
          ),
          child: Scaffold(
            body: ListView.builder(
              controller: controller,
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                return SizedBox(
                  key: ValueKey('scroll_row_$index'),
                  height: EditorialFeedLayout.rowHeight(row),
                  child: const ColoredBox(color: Colors.blue),
                );
              },
            ),
          ),
        ),
        routes: {
          '/detail': (_) => const Scaffold(body: Text('Detail')),
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    final offsetBefore = controller.offset;
    expect(offsetBefore, greaterThan(0));

    final nav = tester.element(find.byType(ListView));
    Navigator.of(nav).pushNamed('/detail');
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);

    Navigator.of(nav).pop();
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(offsetBefore, 1));
  });
}
