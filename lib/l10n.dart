import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart' show rootBundle;

/// Languages with a file in `assets/l10n/<code>.xml`. The first is the fallback.
const supportedLanguages = ['en', 'ru'];

var _strings = <String, String>{};
var _fallback = <String, String>{};

/// The language the device is set to, if we have it; English otherwise.
String deviceLanguage() {
  final code = PlatformDispatcher.instance.locale.languageCode;
  return supportedLanguages.contains(code) ? code : supportedLanguages.first;
}

/// Loads the strings for [language] (the device's by default), keeping English
/// behind them for any key a translation misses.
Future<void> loadLocalization([String? language]) async {
  language ??= deviceLanguage();
  _fallback = await _load(supportedLanguages.first);
  _strings = language == supportedLanguages.first ? _fallback : await _load(language);
}

Future<Map<String, String>> _load(String language) async =>
    parseStrings(await rootBundle.loadString('assets/l10n/$language.xml'));

final _entry = RegExp(r'<string\s+name="([^"]+)"\s*>(.*?)</string>', dotAll: true);
final _entity = RegExp(r'&(lt|gt|amp|quot|apos);');
const _entities = {'lt': '<', 'gt': '>', 'amp': '&', 'quot': '"', 'apos': "'"};

/// Reads `<string name="key">text</string>` entries, in the manner of Android
/// string resources: XML entities and `\n` are understood, comments skipped.
Map<String, String> parseStrings(String xml) {
  xml = xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  return {
    for (final m in _entry.allMatches(xml))
      m[1]!: m[2]!.trim().replaceAll(r'\n', '\n').replaceAllMapped(_entity, (e) => _entities[e[1]!]!),
  };
}

/// The string for [key], with each `{name}` in it filled from [args].
String tr(String key, [Map<String, Object> args = const {}]) {
  var s = _strings[key] ?? _fallback[key] ?? key;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}
