import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class AppTheme {
static ThemeData light() {
final base = ThemeData(
useMaterial3: true,
colorSchemeSeed: const Color(0xFF4F46E5),
brightness: Brightness.light,
);
return base.copyWith(
textTheme: GoogleFonts.interTextTheme(base.textTheme),
);
}

static ThemeData dark() {
final base = ThemeData(
useMaterial3: true,
colorSchemeSeed: const Color(0xFF4F46E5),
brightness: Brightness.dark,
);
return base.copyWith(
textTheme: GoogleFonts.interTextTheme(base.textTheme),
);
}
}