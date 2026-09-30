import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colour tokens — tokens/colors.css.
abstract final class C {
  // Night sky (brand base)
  static const night900 = Color(0xFF101A3F);
  static const night800 = Color(0xFF1B2A5B);
  static const night700 = Color(0xFF243873);
  static const night600 = Color(0xFF2F4A94);
  static const night500 = Color(0xFF3E61B8);
  // Ice (secondary)
  static const ice600 = Color(0xFF2E8FD0);
  static const ice500 = Color(0xFF4FB3F5);
  static const ice400 = Color(0xFF7CD3FF);
  static const ice200 = Color(0xFFC4ECFF);
  static const ice100 = Color(0xFFE6F7FF);
  // Berry (primary action)
  static const berry800 = Color(0xFFA3243D);
  static const berry700 = Color(0xFFC42F4B);
  static const berry600 = Color(0xFFE0405E);
  static const berry500 = Color(0xFFFF5D73);
  static const berry300 = Color(0xFFFF9EAB);
  static const berry100 = Color(0xFFFFE3E7);
  // Sun (rewards, stars)
  static const sun700 = Color(0xFFD99500);
  static const sun500 = Color(0xFFFFC93C);
  static const sun300 = Color(0xFFFFE08A);
  static const sun100 = Color(0xFFFFF4D1);
  // Mint (success)
  static const mint700 = Color(0xFF1F9E72);
  static const mint500 = Color(0xFF4DD6A3);
  static const mint100 = Color(0xFFDDF8EE);
  // Paper & snow neutrals
  static const paper = Color(0xFFFFFFFF);
  static const snow50 = Color(0xFFF6FAFF);
  static const snow100 = Color(0xFFEAF2FF);
  static const snow200 = Color(0xFFD6E4FA);
  static const snow300 = Color(0xFFB4C7E8);
  static const snow500 = Color(0xFF7D90B8);
  static const snow700 = Color(0xFF4A5B85);

  static const surfaceTable = snow100;
  static const surfaceGlass = Color(0x24FFFFFF); // white 14%
  static const textStrong = night800;
  static const textBody = snow700;
  static const ringFocus = Color(0xB37CD3FF);
}

/// Radii — tokens/effects.css.
abstract final class R {
  static const s = 12.0, m = 18.0, l = 24.0, xl = 32.0;
}

/// Motion — tokens/effects.css.
abstract final class Motion {
  static const bounce = Cubic(.34, 1.56, .64, 1);
  static const out = Cubic(.22, 1, .36, 1);
  static const press = Duration(milliseconds: 120);
  static const pop = Duration(milliseconds: 320);
  static const unfold = Duration(milliseconds: 1400);
}

const screenPad = 20.0;

/// Rubik — headlines, buttons, numbers.
TextStyle display(double size, {FontWeight weight = FontWeight.w800, Color color = Colors.white, double? height, List<Shadow>? shadows}) =>
    GoogleFonts.rubik(fontSize: size, fontWeight: weight, color: color, height: height, shadows: shadows);

/// Nunito — hints, body.
TextStyle body(double size, {FontWeight weight = FontWeight.w700, Color color = C.textBody, double? height}) =>
    GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color, height: height);

/// Solid “drop” shadow for headlines on dark backgrounds.
List<Shadow> drop(double dy) => [Shadow(color: C.night900, offset: Offset(0, dy))];
