import 'package:url_launcher/url_launcher.dart';

/// Política de privacidad publicada en Firebase Hosting (`hosting/privacidad.html`).
/// Es la misma URL que va en la ficha de Play Store.
const String kPrivacyPolicyUrl = 'https://trainapp-prod.web.app/privacidad';

/// Abre la política de privacidad en el navegador. Devuelve false si no se pudo.
Future<bool> openPrivacyPolicy() async {
  try {
    return await launchUrl(
      Uri.parse(kPrivacyPolicyUrl),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
