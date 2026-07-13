/// Stub usado fora da Web, onde `dart:html` não existe.
/// Esse arquivo serve como um "mecanismo de escape" para que o app não quebre 
/// ao ser compilado em plataformas mobile (Android/iOS), simulando a classe da Web.
class WebNotifier {

  /// Simula a requisição de permissão para notificações no navegador.
  /// Como este arquivo roda fora da Web, ele apenas retorna 'false' imediatamente de forma assíncrona.
  static Future<bool> requestPermission() async => false;


  /// Simula o disparo de uma notificação visual na tela do navegador.
  /// Recebe o [titulo] e o [corpo] da mensagem, mas não executa nenhuma ação em dispositivos móveis.
  static void mostrar(String titulo, String corpo) {}
}
