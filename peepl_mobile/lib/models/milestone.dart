/// Real accomplishment milestones — no XP, levels, or arbitrary badges.
class Milestone {
  Milestone._();

  static const String firstPeep = 'first_peep';
  static const String fivePlaces = 'five_places';
  static const String tenPeeps = 'ten_peeps';
  static const String pioneer = 'pioneer';
  static const String twentyFivePeeps = 'twenty_five_peeps';

  static const Map<String, String> displayText = {
    firstPeep: 'First Peep — You just put your first place on the map.',
    fivePlaces: '5 Places — You\'ve helped keep 5 places live.',
    tenPeeps: '10 Peeps — Your 10th contribution is live.',
    pioneer: 'Pioneer — You were the first person to Peep this place.',
    twentyFivePeeps:
        '25 Peeps — You\'re becoming one of the people who keeps Peepl current.',
  };

  static const List<String> allIds = [
    firstPeep,
    fivePlaces,
    tenPeeps,
    pioneer,
    twentyFivePeeps,
  ];

  static String? textFor(String id) => displayText[id];
}
