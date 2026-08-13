import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peepl_mobile/constants/national_brand_ads.dart';
import 'package:peepl_mobile/utils/crowd_display_mapper.dart';
import 'package:peepl_mobile/widgets/home/editorial_feed_layout.dart';
import 'package:peepl_mobile/widgets/home/happening_now_ticker.dart';
import 'package:peepl_mobile/widgets/home/organic_crowd_card.dart';
import 'package:peepl_mobile/widgets/home/peepl_bottom_navigation.dart';
import 'package:peepl_mobile/widgets/home/peepl_home_header.dart';
import 'package:peepl_mobile/widgets/home/peepl_home_background.dart';
import 'package:peepl_mobile/widgets/home/peepl_home_tokens.dart';
import 'package:peepl_mobile/widgets/home/quick_filter_row.dart';
import 'package:peepl_mobile/widgets/home/sponsored_native_card.dart';

class _PreviewHarness extends StatelessWidget {
  const _PreviewHarness({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final rows = EditorialFeedLayout.rowsFromItems(items);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PeeplHomeBackground(
        child: Column(
          children: [
            Padding(
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
                    onTap: _noop,
                  ),
                ],
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
                      height: EditorialFeedLayout.rowHeight(row),
                      child: _buildRow(row),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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

  static void _noop() {}

  Widget _buildRow(EditorialFeedRow row) {
    switch (row.kind) {
      case EditorialRowKind.featuredOrganic:
        return _organic(row.items.first, OrganicCardSize.featured);
      case EditorialRowKind.halfOrganicPair:
        return Row(
          children: [
            Expanded(child: _organic(row.items[0], OrganicCardSize.half, 0)),
            Container(
              width: PeeplHomeTokens.halfCardGap,
              color: PeeplHomeTokens.organicSeparator,
            ),
            Expanded(child: _organic(row.items[1], OrganicCardSize.half, 0)),
          ],
        );
      case EditorialRowKind.sponsored:
        final ad = row.items.first;
        return SponsoredNativeCard(
          name: ad['name']?.toString() ?? 'Sponsor',
          tagline: ad['tagline']?.toString() ?? '',
          offerLine: ad['offerLine']?.toString() ?? '',
          initial: ad['initial']?.toString() ?? 'P',
          accentColor: Color(ad['accentColor'] as int? ?? 0xFFE53935),
          imageUrl: ad['imageUrl']?.toString() ?? '',
          ctaLabel: ad['ctaLabel']?.toString() ?? 'View',
          onOpen: () {},
          onCta: () {},
        );
    }
  }

  Widget _organic(
    Map<String, dynamic> post,
    OrganicCardSize size, [
    double marginHorizontal = PeeplHomeTokens.cardHorizontalMargin,
  ]) {
    return OrganicCrowdCard(
      imageUrl: post['imageUrl']?.toString() ?? '',
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

void main() {
  testWidgets('home feed preview golden', (tester) async {
    const logicalSize = Size(390, 844);
    const padding = EdgeInsets.only(top: 47, bottom: 34);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = logicalSize;
    addTearDown(tester.view.reset);

    final items = _mockFeedItems(organicCount: 16);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: logicalSize,
          padding: padding,
          devicePixelRatio: 1,
        ),
        child: MaterialApp(
          home: _PreviewHarness(items: items),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_feed_preview_current.png'),
    );
  });
}
