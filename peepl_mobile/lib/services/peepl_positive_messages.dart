import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'growth_analytics_service.dart';

/// A single positive message from the centralized Peepl library.
class PeeplPositiveMessageResult {
  const PeeplPositiveMessageResult({
    required this.id,
    required this.text,
  });

  /// Stable 1-based identifier for analytics (not the shuffle index).
  final int id;
  final String text;
}

/// Centralized positive message library and shuffle-bag rotation.
///
/// Edit [messages] here to add, remove, or reword copy. UI and notification
/// code should call [next] / [enrichPushBody] rather than reading the list.
class PeeplPositiveMessages {
  PeeplPositiveMessages._({Random? random}) : _random = random ?? Random();

  static final PeeplPositiveMessages instance = PeeplPositiveMessages._();

  @visibleForTesting
  factory PeeplPositiveMessages.test({Random? random}) =>
      PeeplPositiveMessages._(random: random);

  static const _orderKey = 'peepl_positive_msg_order';
  static const _positionKey = 'peepl_positive_msg_position';
  static const _lastIdKey = 'peepl_positive_msg_last_id';
  static const _pushFrequencyKey = 'peepl_positive_push_frequency';

  final Random _random;

  /// Approved message library. IDs are list index + 1.
  static const List<String> messages = [
    'You matter.',
    'The world is better with you in it.',
    'You make a difference.',
    'Your presence matters.',
    'You\u2019re important.',
    'You bring something no one else can.',
    'Someone is glad you\u2019re here.',
    'You\u2019re worth knowing.',
    'You have more impact than you realize.',
    'There\u2019s only one you.',
    'You make things better.',
    'Someone is rooting for you.',
    'You have something special.',
    'You\u2019re somebody worth knowing.',
    'You make more difference than you know.',
    'You have something the world needs.',
    'You\u2019re one of a kind.',
    'Someone appreciates you.',
    'You bring something good to the world.',
    'You\u2019re worth appreciating.',
    'Who you are matters.',
    'Your kindness matters.',
    'Your voice matters.',
    'Your ideas matter.',
    'Your perspective matters.',
    'Your story matters.',
    'You make life more interesting.',
    'You bring something uniquely yours.',
    'Someone smiles because of you.',
    'Someone is happy you\u2019re in their life.',
    'Someone thinks about you fondly.',
    'Someone is happy to see your name.',
    'Someone looks forward to seeing you.',
    'Someone enjoys having you around.',
    'Someone is glad they met you.',
    'Someone admires something about you.',
    'Someone appreciates what you bring.',
    'Someone has smiled because of you.',
    'Someone remembers something kind you did.',
    'Someone\u2019s day has been better because of you.',
    'You\u2019re capable of more than you know.',
    'You\u2019re doing better than you think.',
    'Give yourself some credit.',
    'Trust yourself.',
    'You\u2019ve come a long way.',
    'You know more than you realize.',
    'You can figure this out.',
    'You\u2019ve handled hard things before.',
    'You\u2019re stronger than you think.',
    'Don\u2019t underestimate yourself.',
    'You\u2019re worth betting on.',
    'Your potential is still unfolding.',
    'Your best days aren\u2019t all behind you.',
    'There\u2019s more ahead.',
    'Something good could happen today.',
    'The best part might still be ahead.',
    'Today still has possibilities.',
    'Your next chapter is still unwritten.',
    'Life can still surprise you.',
    'Leave room for something wonderful.',
    'Good things are possible.',
    'There are good things ahead.',
    'You have more to discover.',
    'You have memories you haven\u2019t made yet.',
    'You have laughs you haven\u2019t laughed yet.',
    'Your next favorite memory hasn\u2019t happened yet.',
    'You deserve a good day.',
    'You deserve some happiness.',
    'You deserve good people around you.',
    'You deserve moments that make you smile.',
    'You deserve something to look forward to.',
    'Be good to yourself.',
    'Give yourself a little kindness.',
    'Keep being you.',
    'Never forget that you matter.',
    'Tell someone they matter.',
    'Tell someone you\u2019re glad they\u2019re here.',
    'Tell someone you appreciate them.',
    'Tell someone they made you smile.',
    'Tell someone they did a good job.',
    'Tell someone you\u2019re proud of them.',
    'Tell someone you miss them.',
    'Tell someone you\u2019re thinking about them.',
    'Give someone a compliment today.',
    'Let someone know they\u2019re appreciated.',
    'Remind someone how much they mean to you.',
    'Thank someone who deserves to hear it.',
    'Make someone smile today.',
    'Say the nice thing.',
    'Reach out to someone you haven\u2019t talked to lately.',
    'Let someone know you believe in them.',
    'Make someone feel noticed.',
    'Make someone feel welcome.',
    'Make someone feel included.',
    'Give someone a reason to smile.',
    'Send the message you\u2019ve been meaning to send.',
    'Tell someone something you admire about them.',
    'Let someone know you\u2019re happy they\u2019re in your life.',
    'A little kindness can change someone\u2019s whole day.',
    'Make someone\u2019s world a little better today.',
  ];

  static const Set<String> eligiblePushTypes = {
    'walk_in_prompt',
    'crowdsource_request',
    'crowdsource_response',
    'post_liked',
    'new_post_nearby',
    'crowd_change_alert',
    'arrival_fulfilled',
  };

  static bool isEligiblePushType(String? notificationType) {
    if (notificationType == null || notificationType.isEmpty) return false;
    return eligiblePushTypes.contains(notificationType);
  }

  /// Returns the next message from the shuffle bag, persisting rotation state.
  Future<PeeplPositiveMessageResult> next({
    required String surface,
    String? context,
    bool logAnalytics = true,
  }) async {
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('[PeeplPositiveMessages] SharedPreferences error: $e');
      return PeeplPositiveMessageResult(id: 1, text: messages.first);
    }
    final lastId = prefs.getInt(_lastIdKey);

    var order = _readOrder(prefs);
    var position = prefs.getInt(_positionKey) ?? 0;

    if (order.isEmpty || position >= order.length) {
      order = _createShuffledOrder(lastId);
      position = 0;
    }

    final index = order[position];
    final result = PeeplPositiveMessageResult(
      id: index + 1,
      text: messages[index],
    );

    position += 1;
    await prefs.setString(_orderKey, order.join(','));
    await prefs.setInt(_positionKey, position);
    await prefs.setInt(_lastIdKey, result.id);

    if (logAnalytics) {
      unawaited(
        GrowthAnalyticsService.logEvent(
          'positive_message_impression',
          {
            'messageId': result.id,
            'surface': surface,
            'context': context ?? '',
          },
        ),
      );
    }

    return result;
  }

  /// Appends an optional positive sign-off to a functional push body.
  Future<String> enrichPushBody(
    String functionalBody, {
    required String? notificationType,
    bool logAnalytics = true,
  }) async {
    final trimmed = functionalBody.trim();
    if (trimmed.isEmpty) return functionalBody;
    if (!await _shouldIncludeInPush(notificationType)) {
      return functionalBody;
    }

    final message = await next(
      surface: 'push',
      context: notificationType,
      logAnalytics: logAnalytics,
    );

    return '$trimmed\n${message.text}';
  }

  Future<bool> _shouldIncludeInPush(String? notificationType) async {
    if (!isEligiblePushType(notificationType)) return false;

    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_pushFrequencyKey) ?? 0) + 1;
    await prefs.setInt(_pushFrequencyKey, count);
    return count.isEven;
  }

  List<int> _readOrder(SharedPreferences prefs) {
    final raw = prefs.getString(_orderKey);
    if (raw == null || raw.isEmpty) return [];
    return raw
        .split(',')
        .where((part) => part.isNotEmpty)
        .map(int.tryParse)
        .whereType<int>()
        .where((index) => index >= 0 && index < messages.length)
        .toList(growable: false);
  }

  List<int> _createShuffledOrder(int? lastMessageId) {
    final order = List<int>.generate(messages.length, (index) => index);
    order.shuffle(_random);

    if (lastMessageId != null &&
        order.isNotEmpty &&
        order.first + 1 == lastMessageId &&
        order.length > 1) {
      final swapIndex = 1 + _random.nextInt(order.length - 1);
      final temp = order[0];
      order[0] = order[swapIndex];
      order[swapIndex] = temp;
    }

    return order;
  }

  @visibleForTesting
  Future<void> resetRotationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_orderKey);
    await prefs.remove(_positionKey);
    await prefs.remove(_lastIdKey);
    await prefs.remove(_pushFrequencyKey);
  }
}
