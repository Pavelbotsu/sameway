import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';

/// Terms of Service / Privacy Policy version this build asks users to accept.
/// MUST match `handlers.CurrentTermsVersion` on the backend. Bumping both
/// re-prompts every user (signup screen + TermsGateScreen on next start).
const kTermsVersion = 2;

/// Served by the backend so a corrected document reaches every user without
/// an app release. The same URLs go in the Play Console / App Store Connect.
const kPrivacyPolicyUrl = '$kApiBase/legal/privacy';
const kTermsUrl = '$kApiBase/legal/terms';
const kAccountDeletionUrl = '$kApiBase/account/delete';

/// Languages the documents exist in on the backend (handlers/static).
const kLegalLanguages = {'en', 'pl', 'uk'};

/// [url] in [lang] when the document exists in it, otherwise English.
String legalUrlFor(String url, String lang) =>
    '$url?lang=${kLegalLanguages.contains(lang) ? lang : 'en'}';

/// Opens a legal page in the external browser, in the app's current
/// language. Returns false if nothing could handle it.
Future<bool> openLegalUrl(BuildContext context, String url) => launchUrl(
      Uri.parse(legalUrlFor(url, Localizations.localeOf(context).languageCode)),
      mode: LaunchMode.externalApplication,
    );
