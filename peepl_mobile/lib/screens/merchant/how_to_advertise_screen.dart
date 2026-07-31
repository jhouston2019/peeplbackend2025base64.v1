import 'package:flutter/material.dart';

import '../../widgets/merchant/merchant_screen_scaffold.dart';
import '../../widgets/merchant/peepl_merchant_tokens.dart';

class HowToAdvertiseScreen extends StatelessWidget {
  const HowToAdvertiseScreen({super.key});

  static const Color _blue = PeeplMerchantTokens.accentBlue;
  static const Color _blueDark = PeeplMerchantTokens.accentGradientEnd;

  static const _tiers = <_AdTier>[
    _AdTier(
      name: 'Standard',
      placement: 'Appears every 3rd post in the feed',
      price: '\$99/month',
      bullets: [
        'Reach active users',
        'Location-based targeting',
        'Real-time analytics',
      ],
      learnMore:
          'Standard ads rotate through the main feed, appearing every third post. '
          'They reach users who are actively browsing venues and crowd levels near them. '
          'You get location-based targeting within your chosen radius and a real-time '
          'analytics dashboard to track impressions and engagement.',
    ),
    _AdTier(
      name: 'Prime',
      placement: 'First post every user sees',
      price: '\$299/month',
      isPopular: true,
      bullets: [
        'Maximum visibility',
        'Prime placement guaranteed',
        'Priority support',
      ],
      learnMore:
          'Prime ads are pinned as the very first post every user sees when they open '
          'the feed. This guarantees maximum visibility at the top of the scroll — '
          'ideal for grand openings, special events, or high-traffic weekends. '
          'Prime advertisers also receive priority support from the Peepl team.',
    ),
    _AdTier(
      name: 'VIPeeps Exclusive',
      placement: 'Reach our premium subscribers',
      price: '\$199/month',
      bullets: [
        'High-value audience',
        'Ad-free users who pay for quality',
        'Premium brand association',
      ],
      learnMore:
          'VIPeeps Exclusive ads reach Peepl\'s premium subscribers — users who pay for '
          'an ad-free experience and actively engage with quality venues. '
          'This tier puts your brand in front of a high-value audience that values '
          'curated recommendations and premium experiences.',
    ),
  ];

  static const _steps = <_HowItWorksStep>[
    _HowItWorksStep(
      number: '1',
      title: 'Create your ad',
      description: 'Upload your creative, write your copy, and choose your venue.',
    ),
    _HowItWorksStep(
      number: '2',
      title: 'Set your budget',
      description: 'Pick a tier, set your monthly spend, and define your target area.',
    ),
    _HowItWorksStep(
      number: '3',
      title: 'Reach customers',
      description: 'Your ad goes live and connects with people deciding where to go.',
    ),
  ];

  static const _stats = <_StatItem>[
    _StatItem(value: '10,000+', label: 'monthly active users'),
    _StatItem(value: '500+', label: 'locations tracked'),
    _StatItem(value: 'Real-time', label: 'crowd data'),
  ];

  void _showTierDialog(BuildContext context, _AdTier tier) {
    // Inline detail — no dialogs per merchant UX guidelines.
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (ctx) => MerchantScreenScaffold(
          title: tier.name,
          onBack: () => Navigator.pop(ctx),
          body: ListView(
            children: [
              Text(
                tier.placement,
                style: const TextStyle(
                  color: PeeplMerchantTokens.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tier.price,
                style: const TextStyle(
                  color: PeeplMerchantTokens.accentBlue,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tier.learnMore,
                style: const TextStyle(
                  color: PeeplMerchantTokens.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeeplMerchantTokens.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  _buildHeroSection(),
                  const SizedBox(height: 28),
                  _buildSectionTitle('Choose Your Ad Tier'),
                  const SizedBox(height: 14),
                  ..._tiers.map((tier) => _buildTierCard(context, tier)),
                  const SizedBox(height: 28),
                  _buildSectionTitle('How It Works'),
                  const SizedBox(height: 14),
                  _buildHowItWorks(),
                  const SizedBox(height: 28),
                  _buildStatsBar(),
                  const SizedBox(height: 28),
                  MerchantPrimaryButton(
                    label: 'Start Advertising',
                    onPressed: () =>
                        Navigator.pushNamed(context, '/merchant_sign_in'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Advertise on Peepl',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_blue, _blueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📣', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 14),
          const Text(
            'Reach Customers Where They Are',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Advertise on Peepl and connect with people actively looking for places to go',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTierCard(BuildContext context, _AdTier tier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tier.isPopular ? _blue : Colors.grey.shade200,
          width: tier.isPopular ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tier.isPopular) const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tier.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tier.placement,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      tier.price,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...tier.bullets.map(
                  (bullet) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 18,
                          color: _blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            bullet,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _showTierDialog(context, tier),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Learn More',
                      style: TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (tier.isPopular)
            Positioned(
              top: -1,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: const Text(
                  'MOST POPULAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            _buildStepRow(_steps[i]),
            if (i < _steps.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 19),
                    Container(
                      width: 2,
                      height: 20,
                      color: _blue.withValues(alpha: 0.2),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepRow(_HowItWorksStep step) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step.number,
              style: const TextStyle(
                color: _blue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                step.description,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _blue.withValues(alpha: 0.08),
            _blueDark.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _blue.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: _stats
            .map(
              (stat) => Expanded(
                child: Column(
                  children: [
                    Text(
                      stat.value,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _blue,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stat.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AdTier {
  const _AdTier({
    required this.name,
    required this.placement,
    required this.price,
    required this.bullets,
    required this.learnMore,
    this.isPopular = false,
  });

  final String name;
  final String placement;
  final String price;
  final List<String> bullets;
  final String learnMore;
  final bool isPopular;
}

class _HowItWorksStep {
  const _HowItWorksStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;
}

class _StatItem {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;
}
