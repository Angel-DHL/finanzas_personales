import 'package:intl/intl.dart';


String formatMXNFromCents(int cents) {
final value = cents / 100.0;
final f = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
return f.format(value);
}


int parseCents(String input) {
final clean = input.replaceAll(RegExp(r'[^0-9\.]'), '');
if (clean.isEmpty) return 0;
final v = double.tryParse(clean) ?? 0;
return (v * 100).round();
}