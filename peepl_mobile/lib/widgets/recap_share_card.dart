import 'package:flutter/material.dart';

/// Fixed-size share card for monthly Peepl recaps (Phase 8).
class RecapShareCard extends StatelessWidget {
  const RecapShareCard({
    super.key,
    required this.periodLabel,
    required this.peepCount,
    required this.placeCount,
    required this.peopleHelped,
    required this.milestoneCount,
    this.pioneerVenueName,
  });

  final String periodLabel;
  final int peepCount;
  final int placeCount;
  final int peopleHelped;
  final int milestoneCount;
  final String? pioneerVenueName;

  static const Color _blue = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 375,
      height: 667,
      child: ColoredBox(
        color: _blue,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Peepl',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                periodLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 36),
              _statLine('$peepCount Peeps'),
              const SizedBox(height: 14),
              _statLine('$placeCount places updated'),
              const SizedBox(height: 14),
              _statLine('$peopleHelped people helped'),
              const SizedBox(height: 14),
              _statLine('$milestoneCount milestones'),
              if (pioneerVenueName != null &&
                  pioneerVenueName!.trim().isNotEmpty) ...[
                const SizedBox(height: 28),
                Text(
                  'Pioneer at ${pioneerVenueName!.trim()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statLine(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
    );
  }
}

/// Full-year variant for annual sharing (Phase 8).
class RecapShareCardAnnual extends StatelessWidget {
  const RecapShareCardAnnual({
    super.key,
    required this.year,
    required this.peepCount,
    required this.placeCount,
    required this.peopleHelped,
    required this.milestoneCount,
    this.pioneerVenueName,
  });

  final int year;
  final int peepCount;
  final int placeCount;
  final int peopleHelped;
  final int milestoneCount;
  final String? pioneerVenueName;

  @override
  Widget build(BuildContext context) {
    return RecapShareCard(
      periodLabel: 'My $year on Peepl',
      peepCount: peepCount,
      placeCount: placeCount,
      peopleHelped: peopleHelped,
      milestoneCount: milestoneCount,
      pioneerVenueName: pioneerVenueName,
    );
  }
}
