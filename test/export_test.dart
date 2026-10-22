import 'package:efarm360/core/export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CSV pour Excel français : BOM, point-virgule, guillemets et retours à la ligne protégés', () {
    final csv = toCsv(['Produit', 'Quantité'], [
      ['Maïs; concassé', 12.5],
      ['Aliment "démarrage"', 3],
      [null, 'a\nb'],
    ]);
    expect(csv.startsWith('\u{FEFF}Produit;Quantité\r\n'), isTrue);
    expect(csv, contains('"Maïs; concassé";12.5\r\n'));
    expect(csv, contains('"Aliment ""démarrage""";3\r\n'));
    expect(csv, contains(';"a\nb"\r\n'));
  });
}
