import 'package:flutter_test/flutter_test.dart';
import 'package:pinch_l10n/testing.dart';

/// Таблица l10n/strings.csv полная, ключи из кода в ней есть,
/// lib/l10n/strings.g.dart собран из неё (`dart run pinch_l10n gen`).
void main() => test('локализация', () => expect(l10nProblems(), isEmpty));
