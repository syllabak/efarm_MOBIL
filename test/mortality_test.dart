import 'package:efarm360/features/farm/mortality_chart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mortalité par jour : cumul des rapports du même jour, jours sans rapport à 0, ordre chronologique', () {
    final r = mortaliteParJour([
      {'date_rapport': '2026-10-20', 'mortalite_jour': 3},
      {'date_rapport': '2026-10-20 08:00:00', 'mortalite_jour': '2'},
      {'date_rapport': '2026-10-18', 'mortalite_jour': 1},
      {'date_rapport': '2026-01-01', 'mortalite_jour': 99},
    ], jours: 5, fin: DateTime(2026, 10, 21));
    expect(r.length, 5);
    expect(r.first.jour, DateTime(2026, 10, 17));
    expect(r.last.jour, DateTime(2026, 10, 21));
    expect(r.map((e) => e.morts).toList(), [0, 1, 0, 5, 0]);
  });
}
