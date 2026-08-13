import 'package:flutter/material.dart';

import 'peepl_home_tokens.dart';

/// Presentation-only editorial row types.
enum EditorialRowKind { featuredOrganic, halfOrganicPair, sponsored }

/// One feed row in the editorial layout.
class EditorialFeedRow {
  const EditorialFeedRow.featured(this.items)
      : kind = EditorialRowKind.featuredOrganic;

  const EditorialFeedRow.halfPair(this.items)
      : kind = EditorialRowKind.halfOrganicPair,
        assert(items.length == 2);

  const EditorialFeedRow.sponsored(this.items)
      : kind = EditorialRowKind.sponsored,
        assert(items.length == 1);

  final EditorialRowKind kind;
  final List<Map<String, dynamic>> items;
}

/// Converts the merged feed stream into editorial rows without altering item
/// order or sponsored insertion from [FeedScreen._mergeAdsIntoFeed].
///
/// Organic rhythm between ads: full → half pair → full → (ad in stream) → half pair.
class EditorialFeedLayout {
  EditorialFeedLayout._();

  static List<EditorialFeedRow> rowsFromItems(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const [];

    final rows = <EditorialFeedRow>[];
    Map<String, dynamic>? pendingHalf;
    var organicPhase = 0;

    void flushPendingHalf() {
      if (pendingHalf == null) return;
      rows.add(EditorialFeedRow.featured([pendingHalf!]));
      pendingHalf = null;
    }

    for (final item in items) {
      if (item['type'] == 'ad') {
        flushPendingHalf();
        rows.add(EditorialFeedRow.sponsored([item]));
        organicPhase = 4;
        continue;
      }

      switch (organicPhase % 6) {
        case 0:
        case 3:
          rows.add(EditorialFeedRow.featured([item]));
          organicPhase++;
        case 1:
        case 4:
          pendingHalf = item;
          organicPhase++;
        case 2:
        case 5:
          rows.add(EditorialFeedRow.halfPair([pendingHalf!, item]));
          pendingHalf = null;
          organicPhase++;
      }
    }

    flushPendingHalf();
    return rows;
  }

  static double rowHeight(EditorialFeedRow row, BuildContext context) {
    switch (row.kind) {
      case EditorialRowKind.featuredOrganic:
        return PeeplHomeTokens.featuredCardHeightFor(context);
      case EditorialRowKind.sponsored:
        return PeeplHomeTokens.sponsoredCardHeightFor(context);
      case EditorialRowKind.halfOrganicPair:
        return PeeplHomeTokens.halfCardHeightFor(context);
    }
  }
}
