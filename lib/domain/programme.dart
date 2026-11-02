/// Une émission du guide TV (EPG).
class Programme {
  const Programme({required this.start, required this.stop, required this.title, this.description = ''});
  final DateTime start;
  final DateTime stop;
  final String title;
  final String description;

  bool isOnAt(DateTime t) => !t.isBefore(start) && t.isBefore(stop);
}
