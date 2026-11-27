/// Локализация — общий модуль pinch_l10n.
///
/// Тексты — в таблице `l10n/strings.csv`: первый столбец — ключ
/// (`tr('play')`), дальше по столбцу на язык, английский — запасной.
/// После правки таблицы: `dart run pinch_l10n gen`.
library;

import 'package:pinch_l10n/pinch_l10n.dart';

import 'l10n/strings.g.dart';

export 'package:pinch_l10n/pinch_l10n.dart' show L10n, tr, trn;

/// Таблица переводов — один раз при старте. [language] — выбор игрока из
/// настроек; null — язык устройства.
Future<void> loadLocalization([String? language]) async =>
    L10n.init(l10nTable, language: language);

/// Языки игры в порядке списка в настройках, каждый — на своём языке.
const languageNames = <String, String>{
  'en': 'English',
  'ru': 'Русский',
  'de': 'Deutsch',
  'fr': 'Français',
  'it': 'Italiano',
  'es': 'Español',
  'pt': 'Português',
  'ja': '日本語',
  'ko': '한국어',
  'zh': '简体中文',
  'zht': '繁體中文',
};
