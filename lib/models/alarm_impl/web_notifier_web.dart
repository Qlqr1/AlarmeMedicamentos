// Importa a biblioteca nativa do Dart para interagir diretamente com a árvore DOM e APIs do navegador.
import 'dart:html' as html;

/// Notificações do navegador para a build Web (`dart:html`).
/// Esta classe gerencia o ciclo de vida e a exibição de alertas visuais no ecossistema web.
class WebNotifier {
  
  /// Solicita ao usuário a autorização necessária para disparar notificações no navegador.
  /// Retorna um [Future<bool>] indicando o sucesso ou a rejeição do consentimento.
  static Future<bool> requestPermission() async {
    try {
      // Verifica se o navegador atual possui suporte técnico para a API de Notificações Web.
      if (html.Notification.supported != true) return false;
      
      // Se a permissão já foi concedida anteriormente pelo usuário, retorna verdadeiro imediatamente.
      if (html.Notification.permission == 'granted') return true;
      
      // Dispara a janela nativa do navegador pedindo permissão de envio.
      // Inclui um limitador de tempo de 5 segundos para evitar que a execução trave indefinidamente.
      final resultado = await html.Notification.requestPermission().timeout(
        const Duration(seconds: 5),
        onTimeout: () => 'default', // Caso expire o tempo, define o estado como padrão/indefinido.
      );
      
      // Retorna verdadeiro apenas se a resposta final do usuário for explicitamente "granted" (concedido).
      return resultado == 'granted';
    } catch (_) {
      // Captura qualquer erro inesperado ou bloqueio de segurança do navegador e retorna falso.
      return false;
    }
  }

  /// Exibe a notificação visual na tela do sistema operacional através do navegador.
  /// Requer o preenchimento de um [titulo] e o [corpo] textual da mensagem de alerta.
  static void mostrar(String titulo, String corpo) {
    try {
      // Valida se o recurso é suportado e se o usuário deu autorização prévia de exibição.
      if (html.Notification.supported == true &&
          html.Notification.permission == 'granted') {
        
        // Instancia a notificação nativa injetando o título, o corpo do texto e a imagem de ícone do projeto.
        html.Notification(titulo, body: corpo, icon: 'icons/Icon-192.png');
      }
    } catch (_) {
      // Silencia falhas na renderização do componente visual caso o navegador bloqueie a operação.
    }
  }
}
