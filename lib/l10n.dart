/// Локализация — общий модуль pinch_l10n.
///
/// Тексты — в таблице `l10n/strings.csv`: первый столбец — ключ
/// (`tr('play')`), дальше по столбцу на язык, английский — запасной.
/// После правки таблицы: `dart run pinch_l10n gen`.
library;

import 'package:pinch_l10n/pinch_l10n.dart';

import 'l10n/strings.g.dart';

export 'package:pinch_l10n/pinch_l10n.dart' show L10n, tr, trn;

/// Таблица переводов и язык устройства — один раз при старте.
Future<void> loadLocalization([String? language]) async =>
    L10n.init(l10nTable, language: language);
