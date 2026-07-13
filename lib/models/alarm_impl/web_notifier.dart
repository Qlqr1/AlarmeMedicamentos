/// Realiza a exportação condicional dos arquivos de notificação web.
/// Por padrão, exporta o arquivo de stub (`web_notifier_stub.dart`) para evitar 
/// que o app quebre em plataformas mobile (Android/iOS) onde o pacote 'dart:html' não existe.
/// 
/// SE o app estiver rodando na Web (detectado pelo `if (dart.library.html)`), o Flutter 
/// substitui automaticamente a importação pelo arquivo real (`web_notifier_web.dart`).
export 'web_notifier_stub.dart' if (dart.library.html) 'web_notifier_web.dart';

