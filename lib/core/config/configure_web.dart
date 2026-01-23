// Archivo: lib/core/config/configure_web.dart
import 'package:flutter_web_plugins/url_strategy.dart';

void configureUrlStrategy() {
  usePathUrlStrategy(); // Esto elimina el hash (#) de la URL
}