import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const delegate = _AppLocalizationsDelegate();

  /// Languages the app has translations for. Single source for the
  /// delegate, MaterialApp.supportedLocales and the device-locale default.
  static const supportedLanguageCodes = ['en', 'uk', 'es', 'de', 'fr', 'it'];

  // Helper: pick by language code, falling back to English. English fallback
  // means new locales can be added one string at a time without breaking the
  // app — `fr:` / `it:` are optional named args on every getter.
  String _t({
    required String en,
    String? uk,
    String? es,
    String? de,
    String? fr,
    String? it,
  }) =>
      switch (locale.languageCode) {
        'uk' => uk ?? en,
        'es' => es ?? en,
        'de' => de ?? en,
        'fr' => fr ?? en,
        'it' => it ?? en,
        _ => en,
      };

  // ─── Role selection ──────────────────────────────────────────────────────
  String get iAm => _t(
        en: 'I am a…',
        uk: 'Я є…',
        es: 'Soy…',
        de: 'Ich bin…',
        fr: 'Je suis…',
        it: 'Sono…',
      );
  String get chooseRole => _t(
        en: 'Choose your role to get started',
        uk: 'Виберіть свою роль для початку',
        es: 'Elige tu rol para empezar',
        de: 'Wähle deine Rolle, um zu starten',
        fr: 'Choisis ton rôle pour commencer',
        it: 'Scegli il tuo ruolo per iniziare',
      );
  String get driver => _t(
        en: 'Driver',
        uk: 'Водій',
        es: 'Conductor',
        de: 'Fahrer',
        fr: 'Conducteur',
        it: 'Conducente',
      );
  String get driverSubtitle => _t(
        en: 'I have seats to share along my route',
        uk: 'У мене є місця по моєму маршруту',
        es: 'Tengo asientos para compartir en mi ruta',
        de: 'Ich habe Plätze entlang meiner Route frei',
        fr: 'J\'ai des places à partager sur mon trajet',
        it: 'Ho posti da condividere lungo il mio tragitto',
      );
  String get passenger => _t(
        en: 'Passenger',
        uk: 'Пасажир',
        es: 'Pasajero',
        de: 'Fahrgast',
        fr: 'Passager',
        it: 'Passeggero',
      );
  String get passengerSubtitle => _t(
        en: 'I need a ride to my destination',
        uk: 'Мені потрібна поїздка до місця призначення',
        es: 'Necesito un viaje a mi destino',
        de: 'Ich brauche eine Mitfahrt zu meinem Ziel',
        fr: 'J\'ai besoin d\'un trajet vers ma destination',
        it: 'Ho bisogno di un passaggio fino a destinazione',
      );
  String get continueAsGuest => _t(
        en: 'Continue as Guest',
        uk: 'Продовжити як гість',
        es: 'Continuar como invitado',
        de: 'Als Gast fortfahren',
        fr: 'Continuer en tant qu\'invité',
        it: 'Continua come ospite',
      );
  String get canSwitchRoles => _t(
        en: 'You can switch roles anytime from settings.',
        uk: 'Ви можете змінити роль у будь-який час у налаштуваннях.',
        es: 'Puedes cambiar de rol en cualquier momento desde los ajustes.',
        de: 'Du kannst die Rolle jederzeit in den Einstellungen wechseln.',
        fr: 'Tu peux changer de rôle à tout moment dans les paramètres.',
        it: 'Puoi cambiare ruolo in qualsiasi momento dalle impostazioni.',
      );
  String get exploreAsGuest => _t(
        en: 'Explore as Guest',
        uk: 'Досліджувати як гість',
        es: 'Explorar como invitado',
        de: 'Als Gast erkunden',
        fr: 'Explorer en tant qu\'invité',
        it: 'Esplora come ospite',
      );
  String get guestSubtitle => _t(
        en: 'Browse the map without an account.\nSign in later to unlock full features.',
        uk: 'Переглядайте карту без акаунта.\nВвійдіть пізніше, щоб розблокувати всі функції.',
        es: 'Explora el mapa sin cuenta.\nInicia sesión después para desbloquear todo.',
        de: 'Karte ohne Konto erkunden.\nMelde dich später an, um alle Funktionen freizuschalten.',
        fr: 'Parcours la carte sans compte.\nConnecte-toi plus tard pour débloquer toutes les fonctionnalités.',
        it: 'Esplora la mappa senza un account.\nAccedi più tardi per sbloccare tutte le funzioni.',
      );
  String get guestDriver => _t(
        en: 'Guest Driver',
        uk: 'Гість-водій',
        es: 'Conductor invitado',
        de: 'Gast-Fahrer',
        fr: 'Conducteur invité',
        it: 'Conducente ospite',
      );
  String get guestPassenger => _t(
        en: 'Guest Passenger',
        uk: 'Гість-пасажир',
        es: 'Pasajero invitado',
        de: 'Gast-Fahrgast',
        fr: 'Passager invité',
        it: 'Passeggero ospite',
      );

  // ─── Auth screen ─────────────────────────────────────────────────────────
  String get welcomeBack => _t(
        en: 'Welcome back',
        uk: 'З поверненням',
        es: 'Bienvenido de nuevo',
        de: 'Willkommen zurück',
        fr: 'Bon retour',
        it: 'Bentornato',
      );
  String get createAccount => _t(
        en: 'Create account',
        uk: 'Створити акаунт',
        es: 'Crear cuenta',
        de: 'Konto erstellen',
        fr: 'Créer un compte',
        it: 'Crea account',
      );
  String get signInContinue => _t(
        en: 'Sign in to continue your journey',
        uk: 'Увійдіть, щоб продовжити подорож',
        es: 'Inicia sesión para continuar tu viaje',
        de: 'Melde dich an, um deine Reise fortzusetzen',
        fr: 'Connecte-toi pour continuer ton trajet',
        it: 'Accedi per continuare il tuo viaggio',
      );
  String get joinSameway => _t(
        en: 'Join sameway today',
        uk: 'Приєднайтесь до sameway сьогодні',
        es: 'Únete a sameway hoy',
        de: 'Werde noch heute Teil von sameway',
        fr: 'Rejoins sameway aujourd\'hui',
        it: 'Unisciti a sameway oggi',
      );
  String get signIn => _t(
        en: 'Sign In',
        uk: 'Увійти',
        es: 'Iniciar sesión',
        de: 'Anmelden',
        fr: 'Se connecter',
        it: 'Accedi',
      );
  String get signUp => _t(
        en: 'Sign Up',
        uk: 'Зареєструватися',
        es: 'Registrarse',
        de: 'Registrieren',
        fr: 'S\'inscrire',
        it: 'Registrati',
      );
  String get continueWithGoogle => _t(
        en: 'Continue with Google',
        uk: 'Продовжити з Google',
        es: 'Continuar con Google',
        de: 'Mit Google fortfahren',
        fr: 'Continuer avec Google',
        it: 'Continua con Google',
      );
  String get or => _t(
        en: 'or',
        uk: 'або',
        es: 'o',
        de: 'oder',
        fr: 'ou',
        it: 'o',
      );

  // ─── Home top bar & account sheet ────────────────────────────────────────
  String get account => _t(
        en: 'Account',
        uk: 'Акаунт',
        es: 'Cuenta',
        de: 'Konto',
        fr: 'Compte',
        it: 'Account',
      );
  String get switchRole => _t(
        en: 'Switch Role',
        uk: 'Змінити роль',
        es: 'Cambiar de rol',
        de: 'Rolle wechseln',
        fr: 'Changer de rôle',
        it: 'Cambia ruolo',
      );
  String get language => _t(
        en: 'Language',
        uk: 'Мова',
        es: 'Idioma',
        de: 'Sprache',
        fr: 'Langue',
        it: 'Lingua',
      );
  String get signOut => _t(
        en: 'Sign Out',
        uk: 'Вийти',
        es: 'Cerrar sesión',
        de: 'Abmelden',
        fr: 'Se déconnecter',
        it: 'Esci',
      );
  String get guest => _t(
        en: 'GUEST',
        uk: 'ГІСТЬ',
        es: 'INVITADO',
        de: 'GAST',
        fr: 'INVITÉ',
        it: 'OSPITE',
      );

  // ─── Forms / validators ──────────────────────────────────────────────────
  String get fieldRequired => _t(
        en: 'Required',
        uk: 'Обов\'язкове поле',
        es: 'Obligatorio',
        de: 'Pflichtfeld',
        fr: 'Obligatoire',
        it: 'Obbligatorio',
      );

  // ─── Quick role-switch sheet ─────────────────────────────────────────────
  String get switchRoleTo => _t(
        en: 'Switch role',
        uk: 'Змінити роль',
        es: 'Cambiar de rol',
        de: 'Rolle wechseln',
        fr: 'Changer de rôle',
        it: 'Cambia ruolo',
      );
  String get switchToDriver => _t(
        en: 'Switch to Driver',
        uk: 'Перейти у водія',
        es: 'Cambiar a conductor',
        de: 'Zum Fahrer wechseln',
        fr: 'Passer en conducteur',
        it: 'Passa a conducente',
      );
  String get switchToPassenger => _t(
        en: 'Switch to Passenger',
        uk: 'Перейти у пасажира',
        es: 'Cambiar a pasajero',
        de: 'Zum Fahrgast wechseln',
        fr: 'Passer en passager',
        it: 'Passa a passeggero',
      );
  String get currentRole => _t(
        en: 'Current role',
        uk: 'Поточна роль',
        es: 'Rol actual',
        de: 'Aktuelle Rolle',
        fr: 'Rôle actuel',
        it: 'Ruolo attuale',
      );

  // ─── Account & Security ──────────────────────────────────────────────────
  String get accountSecurity => _t(
        en: 'Account & Security',
        uk: 'Акаунт і безпека',
        es: 'Cuenta y seguridad',
        de: 'Konto & Sicherheit',
        fr: 'Compte et sécurité',
        it: 'Account e sicurezza',
      );

  // ─── Driver home ─────────────────────────────────────────────────────────
  String get readyToShare => _t(
        en: 'Ready to share your route?',
        uk: 'Готові поділитися маршрутом?',
        es: '¿Listo para compartir tu ruta?',
        de: 'Bereit, deine Route zu teilen?',
        fr: 'Prêt à partager ton trajet ?',
        it: 'Pronto a condividere il tuo tragitto?',
      );
  String get setRouteDesc => _t(
        en: 'Set your destination and find passengers heading your way.',
        uk: 'Вкажіть пункт призначення та знайдіть попутників.',
        es: 'Define tu destino y encuentra pasajeros que vayan por tu camino.',
        de: 'Lege dein Ziel fest und finde Fahrgäste auf deiner Strecke.',
        fr: 'Définis ta destination et trouve des passagers sur ta route.',
        it: 'Imposta la destinazione e trova passeggeri sul tuo percorso.',
      );
  String get setRoute => _t(
        en: 'Set Route',
        uk: 'Встановити маршрут',
        es: 'Definir ruta',
        de: 'Route festlegen',
        fr: 'Définir le trajet',
        it: 'Imposta tragitto',
      );
  String get settingRoute => _t(
        en: 'Setting route…',
        uk: 'Встановлення маршруту…',
        es: 'Definiendo ruta…',
        de: 'Route wird festgelegt…',
        fr: 'Définition du trajet…',
        it: 'Impostazione del tragitto…',
      );
  String get findPassengers => _t(
        en: 'Find Passengers',
        uk: 'Знайти пасажирів',
        es: 'Buscar pasajeros',
        de: 'Fahrgäste finden',
        fr: 'Trouver des passagers',
        it: 'Trova passeggeri',
      );
  String get setYourRoute => _t(
        en: 'Set your route',
        uk: 'Встановіть свій маршрут',
        es: 'Define tu ruta',
        de: 'Lege deine Route fest',
        fr: 'Définis ton trajet',
        it: 'Imposta il tuo tragitto',
      );
  String get destination => _t(
        en: 'Destination address',
        uk: 'Адреса призначення',
        es: 'Dirección de destino',
        de: 'Zieladresse',
        fr: 'Adresse de destination',
        it: 'Indirizzo di destinazione',
      );
  String get yourDestination => _t(
        en: 'Your destination',
        uk: 'Ваше призначення',
        es: 'Tu destino',
        de: 'Dein Ziel',
        fr: 'Votre destination',
        it: 'La tua destinazione',
      );
  String get yourRequests => _t(
        en: 'YOUR REQUESTS',
        uk: 'ВАШІ ЗАПИТИ',
        es: 'TUS SOLICITUDES',
        de: 'DEINE ANFRAGEN',
        fr: 'VOS DEMANDES',
        it: 'LE TUE RICHIESTE',
      );
  String get yourRequestsHint => _t(
        en: 'Rides you\'ve asked for — waiting for the driver.',
        uk: 'Поїздки, які ви запросили — очікують водія.',
        es: 'Viajes que has pedido: esperando al conductor.',
        de: 'Von dir angefragte Fahrten — warten auf den Fahrer.',
        fr: 'Trajets demandés — en attente du conducteur.',
        it: 'Corse richieste — in attesa del conducente.',
      );
  String driversHeadingYourWay(int n) => _t(
        en: '$n heading your way',
        uk: '$n їдуть у ваш бік',
        es: '$n van hacia ti',
        de: '$n unterwegs zu dir',
        fr: '$n vont dans ta direction',
        it: '$n in arrivo verso di te',
      );

  String get likelyMatchChip => _t(
        en: 'Heading your way',
        uk: 'Їде у ваш бік',
        es: 'Va hacia ti',
        de: 'In deine Richtung',
        fr: 'Dans ta direction',
        it: 'Nella tua direzione',
      );

  // ─── Persistent chat (Round 2 §3) ───────────────────────────────────────
  String get chatConversation => _t(
        en: 'Conversation',
        uk: 'Розмова',
        es: 'Conversación',
        de: 'Unterhaltung',
        fr: 'Conversation',
        it: 'Conversazione',
      );
  String get chatUnavailable => _t(
        en: 'You can only message your current match candidates',
        uk: 'Писати можна лише поточним кандидатам на поїздку',
        es: 'Solo puedes escribir a tus candidatos de viaje actuales',
        de: 'Du kannst nur aktuellen Mitfahr-Kandidaten schreiben',
        fr: 'Tu ne peux écrire qu’à tes candidats de trajet actuels',
        it: 'Puoi scrivere solo ai tuoi attuali candidati di viaggio',
      );
  String get chatSlowDown => _t(
        en: 'Sending too fast — wait a moment',
        uk: 'Занадто швидко — зачекайте хвилинку',
        es: 'Demasiado rápido — espera un momento',
        de: 'Zu schnell — warte einen Moment',
        fr: 'Trop rapide — attends un instant',
        it: 'Troppo veloce — aspetta un attimo',
      );
  String get messagesTitle => _t(
        en: 'Messages',
        uk: 'Повідомлення',
        es: 'Mensajes',
        de: 'Nachrichten',
        fr: 'Messages',
        it: 'Messaggi',
      );
  String get noConversations => _t(
        en: 'No conversations yet',
        uk: 'Ще немає розмов',
        es: 'Aún no hay conversaciones',
        de: 'Noch keine Unterhaltungen',
        fr: 'Pas encore de conversations',
        it: 'Ancora nessuna conversazione',
      );
  String get noConversationsDesc => _t(
        en: 'Chats with your drivers and passengers appear here',
        uk: 'Тут з’являться чати з вашими водіями та пасажирами',
        es: 'Aquí aparecerán los chats con tus conductores y pasajeros',
        de: 'Chats mit deinen Fahrern und Fahrgästen erscheinen hier',
        fr: 'Les discussions avec tes conducteurs et passagers apparaissent ici',
        it: 'Le chat con i tuoi conducenti e passeggeri appaiono qui',
      );
  String blockUserQ(String name) => _t(
        en: 'Block $name?',
        uk: 'Заблокувати $name?',
        es: '¿Bloquear a $name?',
        de: '$name blockieren?',
        fr: 'Bloquer $name ?',
        it: 'Bloccare $name?',
      );
  String get blockUserBody => _t(
        en: 'Neither of you will be able to message the other. You can undo this later.',
        uk: 'Ви обоє не зможете писати одне одному. Це можна скасувати пізніше.',
        es: 'Ninguno de los dos podrá escribir al otro. Puedes deshacerlo más tarde.',
        de: 'Ihr könnt euch gegenseitig nicht mehr schreiben. Das lässt sich später rückgängig machen.',
        fr: 'Aucun de vous deux ne pourra écrire à l’autre. Tu pourras annuler plus tard.',
        it: 'Nessuno dei due potrà scrivere all’altro. Puoi annullare più tardi.',
      );
  String get blockAction => _t(
        en: 'Block',
        uk: 'Заблокувати',
        es: 'Bloquear',
        de: 'Blockieren',
        fr: 'Bloquer',
        it: 'Blocca',
      );
  String get userBlocked => _t(
        en: 'User blocked',
        uk: 'Користувача заблоковано',
        es: 'Usuario bloqueado',
        de: 'Nutzer blockiert',
        fr: 'Utilisateur bloqué',
        it: 'Utente bloccato',
      );
  String reportUserQ(String name) => _t(
        en: 'Report $name?',
        uk: 'Поскаржитися на $name?',
        es: '¿Denunciar a $name?',
        de: '$name melden?',
        fr: 'Signaler $name ?',
        it: 'Segnalare $name?',
      );
  String get reportReasonHint => _t(
        en: 'What happened? (optional)',
        uk: 'Що сталося? (необов’язково)',
        es: '¿Qué pasó? (opcional)',
        de: 'Was ist passiert? (optional)',
        fr: 'Que s’est-il passé ? (facultatif)',
        it: 'Cosa è successo? (facoltativo)',
      );
  String get reportAction => _t(
        en: 'Report',
        uk: 'Поскаржитися',
        es: 'Denunciar',
        de: 'Melden',
        fr: 'Signaler',
        it: 'Segnala',
      );
  String get userReported => _t(
        en: 'Report sent — thank you',
        uk: 'Скаргу надіслано — дякуємо',
        es: 'Denuncia enviada — gracias',
        de: 'Meldung gesendet — danke',
        fr: 'Signalement envoyé — merci',
        it: 'Segnalazione inviata — grazie',
      );

  // ─── Partial relay + micro-detour (Round 2 §1–2) ────────────────────────
  String get partialRideTitle => _t(
        en: 'Partial ride — you continue after drop-off',
        uk: 'Часткова поїздка — далі ви їдете самі',
        es: 'Viaje parcial: continúas después de bajarte',
        de: 'Teilfahrt — nach dem Aussteigen geht es weiter',
        fr: 'Trajet partiel — tu continues après la dépose',
        it: 'Corsa parziale — prosegui dopo la discesa',
      );
  String relayStopInfo(String stop, int meters) => _t(
        en: 'Drops you ~$meters m from stop "$stop"',
        uk: 'Висадить вас за ~$meters м від зупинки «$stop»',
        es: 'Te deja a ~$meters m de la parada "$stop"',
        de: 'Setzt dich ~$meters m von der Haltestelle „$stop“ ab',
        fr: 'Te dépose à ~$meters m de l’arrêt « $stop »',
        it: 'Ti lascia a ~$meters m dalla fermata "$stop"',
      );
  String get relayFallbackInfo => _t(
        en: "After drop-off we'll immediately search for your next ride from there",
        uk: 'Після висадки ми одразу шукатимемо вашу наступну поїздку звідти',
        es: 'Después de bajarte, buscaremos de inmediato tu siguiente viaje desde allí',
        de: 'Nach dem Aussteigen suchen wir sofort deine nächste Mitfahrt von dort',
        fr: 'Après la dépose, on cherche aussitôt ton prochain trajet depuis là',
        it: 'Dopo la discesa cercheremo subito il tuo prossimo passaggio da lì',
      );
  String get acceptPartialRide => _t(
        en: 'Accept partial ride',
        uk: 'Прийняти часткову поїздку',
        es: 'Aceptar viaje parcial',
        de: 'Teilfahrt annehmen',
        fr: 'Accepter le trajet partiel',
        it: 'Accetta corsa parziale',
      );
  String get relayLeg2Searching => _t(
        en: 'Leg 1 done — looking for your next ride…',
        uk: 'Перший етап завершено — шукаємо наступну поїздку…',
        es: 'Primera etapa lista — buscando tu siguiente viaje…',
        de: 'Etappe 1 geschafft — suche deine nächste Mitfahrt…',
        fr: 'Étape 1 terminée — recherche de ton prochain trajet…',
        it: 'Prima tappa fatta — cerchiamo il tuo prossimo passaggio…',
      );
  String get microDetourPassengerNote => _t(
        en: 'Driver picks you up at your location',
        uk: 'Водій забере вас з вашого місця',
        es: 'El conductor te recoge en tu ubicación',
        de: 'Der Fahrer holt dich an deinem Standort ab',
        fr: 'Le conducteur vient te chercher où tu es',
        it: 'Il conducente ti viene a prendere dove sei',
      );
  String detourAddsLabel(int meters, int seconds) => _t(
        en: 'adds ~$meters m / $seconds s to your route',
        uk: 'додає ~$meters м / $seconds с до вашого маршруту',
        es: 'añade ~$meters m / $seconds s a tu ruta',
        de: 'verlängert deine Route um ~$meters m / $seconds s',
        fr: 'ajoute ~$meters m / $seconds s à ton itinéraire',
        it: 'aggiunge ~$meters m / $seconds s al tuo percorso',
      );
  String get allowMicroDetourTitle => _t(
        en: 'Allow small detours',
        uk: 'Дозволити невеликі об’їзди',
        es: 'Permitir pequeños desvíos',
        de: 'Kleine Umwege erlauben',
        fr: 'Autoriser les petits détours',
        it: 'Consenti piccole deviazioni',
      );
  String get allowMicroDetourSubtitle => _t(
        en: 'Pick up passengers up to ~300 m / 90 s off your route — always shown before you confirm',
        uk: 'Забирати пасажирів до ~300 м / 90 с від маршруту — завжди показуємо перед підтвердженням',
        es: 'Recoger pasajeros hasta ~300 m / 90 s fuera de tu ruta — siempre se muestra antes de confirmar',
        de: 'Fahrgäste bis ~300 m / 90 s abseits der Route abholen — wird vor der Bestätigung immer angezeigt',
        fr: 'Prendre des passagers jusqu’à ~300 m / 90 s hors itinéraire — toujours affiché avant confirmation',
        it: 'Raccogli passeggeri fino a ~300 m / 90 s fuori rotta — sempre mostrato prima della conferma',
      );

  // ─── Match-state banner (Round 2 §6) ────────────────────────────────────
  String get matchStateSearching => _t(
        en: 'Searching for drivers heading your way…',
        uk: 'Шукаємо водіїв у вашому напрямку…',
        es: 'Buscando conductores que van hacia ti…',
        de: 'Suche Fahrer in deine Richtung…',
        fr: 'Recherche de conducteurs dans ta direction…',
        it: 'Cerchiamo conducenti nella tua direzione…',
      );
  String get matchStateSearchingDesc => _t(
        en: "We'll notify you the moment one appears",
        uk: 'Повідомимо, щойно хтось з’явиться',
        es: 'Te avisaremos en cuanto aparezca uno',
        de: 'Wir melden uns, sobald einer auftaucht',
        fr: 'On te prévient dès qu’un apparaît',
        it: 'Ti avvisiamo appena ne compare uno',
      );
  String get matchStateCandidatesDesc => _t(
        en: 'Tap to see them on the map',
        uk: 'Торкніться, щоб побачити на мапі',
        es: 'Toca para verlos en el mapa',
        de: 'Tippen, um sie auf der Karte zu sehen',
        fr: 'Touche pour les voir sur la carte',
        it: 'Tocca per vederli sulla mappa',
      );
  String get matchStateOffer => _t(
        en: 'Ride offer received',
        uk: 'Отримано пропозицію поїздки',
        es: 'Oferta de viaje recibida',
        de: 'Mitfahr-Angebot erhalten',
        fr: 'Offre de trajet reçue',
        it: 'Offerta di passaggio ricevuta',
      );
  String get matchStateOfferDesc => _t(
        en: 'Tap to review and accept',
        uk: 'Торкніться, щоб переглянути та прийняти',
        es: 'Toca para revisarla y aceptar',
        de: 'Tippen zum Prüfen und Annehmen',
        fr: 'Touche pour vérifier et accepter',
        it: 'Tocca per esaminare e accettare',
      );
  String get matchStateRequested => _t(
        en: 'Request sent',
        uk: 'Запит надіслано',
        es: 'Solicitud enviada',
        de: 'Anfrage gesendet',
        fr: 'Demande envoyée',
        it: 'Richiesta inviata',
      );
  String get matchStateRequestedDesc => _t(
        en: 'Waiting for the driver to confirm',
        uk: 'Чекаємо підтвердження водія',
        es: 'Esperando la confirmación del conductor',
        de: 'Warte auf Bestätigung des Fahrers',
        fr: 'En attente de la confirmation du conducteur',
        it: 'In attesa della conferma del conducente',
      );
  String get matchStateMatched => _t(
        en: 'Ride confirmed',
        uk: 'Поїздку підтверджено',
        es: 'Viaje confirmado',
        de: 'Fahrt bestätigt',
        fr: 'Trajet confirmé',
        it: 'Passaggio confermato',
      );
  String matchStateMatchedWith(String name) => _t(
        en: 'Matched with $name',
        uk: 'Ваш водій — $name',
        es: 'Emparejado con $name',
        de: 'Fahrt mit $name bestätigt',
        fr: 'Trajet confirmé avec $name',
        it: 'Abbinato a $name',
      );
  String get matchStateMatchedDesc => _t(
        en: 'Tap for pickup details',
        uk: 'Торкніться для деталей посадки',
        es: 'Toca para ver los detalles de recogida',
        de: 'Tippen für Abhol-Details',
        fr: 'Touche pour les détails de prise en charge',
        it: 'Tocca per i dettagli del ritiro',
      );
  String get matchStateInProgress => _t(
        en: 'Ride in progress',
        uk: 'Поїздка триває',
        es: 'Viaje en curso',
        de: 'Fahrt läuft',
        fr: 'Trajet en cours',
        it: 'Viaggio in corso',
      );
  String get matchStateInProgressDesc => _t(
        en: 'Enjoy the trip',
        uk: 'Гарної поїздки',
        es: 'Disfruta el viaje',
        de: 'Gute Fahrt',
        fr: 'Bon trajet',
        it: 'Buon viaggio',
      );
  String get pickOnMap => _t(
        en: 'Pick on map',
        uk: 'Вибрати на карті',
        es: 'Elegir en el mapa',
        de: 'Auf Karte wählen',
        fr: 'Choisir sur la carte',
        it: 'Scegli sulla mappa',
      );
  String get moveMapToDestination => _t(
        en: 'Move the map to your destination',
        uk: 'Перемістіть карту до місця призначення',
        es: 'Mueve el mapa hasta tu destino',
        de: 'Bewege die Karte zu deinem Ziel',
        fr: 'Déplace la carte vers ta destination',
        it: 'Sposta la mappa sulla destinazione',
      );
  String get setDestinationHere => _t(
        en: 'Set destination here',
        uk: 'Призначити сюди',
        es: 'Fijar destino aquí',
        de: 'Ziel hier festlegen',
        fr: 'Définir la destination ici',
        it: 'Imposta destinazione qui',
      );
  String get adviceTitle => _t(
        en: 'Tips to get matched',
        uk: 'Поради, щоб знайти поїздку',
        es: 'Consejos para encontrar viaje',
        de: 'Tipps für ein Match',
        fr: 'Conseils pour être jumelé',
        it: 'Consigli per trovare un passaggio',
      );
  String adviceTripTooShort(String km) => _t(
        en: 'Short trip (~$km km) — walking may be faster, or arrange directly.',
        uk: 'Коротка поїздка (~$km км) — пішки може бути швидше, або домовтесь напряму.',
        es: 'Viaje corto (~$km km): caminar puede ser más rápido, o coordina directamente.',
        de: 'Kurze Strecke (~$km km) — zu Fuß ist evtl. schneller, oder direkt absprechen.',
        fr: 'Trajet court (~$km km) — la marche peut être plus rapide, ou arrange-toi directement.',
        it: 'Tragitto breve (~$km km): a piedi può essere più veloce, o accordati direttamente.',
      );
  String adviceWalkCloser(int meters) => _t(
        en: 'A driver passes ~$meters m away — walking toward the road could get you a match (if it\'s safe).',
        uk: 'Водій проїжджає за ~$meters м — підійдіть ближче до дороги, щоб знайти поїздку (якщо це безпечно).',
        es: 'Un conductor pasa a ~$meters m: acercarte a la vía podría darte un viaje (si es seguro).',
        de: 'Ein Fahrer fährt ~$meters m entfernt vorbei — näher zur Straße zu gehen kann ein Match bringen (wenn sicher).',
        fr: 'Un conducteur passe à ~$meters m — te rapprocher de la route pourrait te jumeler (si c\'est sûr).',
        it: 'Un conducente passa a ~$meters m: avvicinarti alla strada potrebbe farti trovare un passaggio (se è sicuro).',
      );
  String get adviceEnableLongWalk => _t(
        en: 'Allow a longer walk to reach more drivers heading your way.',
        uk: 'Дозвольте довшу прогулянку, щоб охопити більше водіїв.',
        es: 'Permite caminar más para llegar a más conductores.',
        de: 'Längeren Fußweg erlauben, um mehr Fahrer zu erreichen.',
        fr: 'Autorise une marche plus longue pour atteindre plus de conducteurs.',
        it: 'Consenti una camminata più lunga per raggiungere più conducenti.',
      );
  String get adviceNoSameWayDrivers => _t(
        en: 'No drivers heading your exact way yet — try again shortly.',
        uk: 'Поки немає водіїв саме у вашому напрямку — спробуйте трохи згодом.',
        es: 'Aún no hay conductores en tu dirección exacta: inténtalo en breve.',
        de: 'Noch keine Fahrer genau in deine Richtung — versuch es gleich nochmal.',
        fr: 'Pas encore de conducteurs dans ta direction exacte — réessaie bientôt.',
        it: 'Ancora nessun conducente nella tua direzione esatta: riprova a breve.',
      );
  String get adviceNoDrivers => _t(
        en: 'No drivers nearby right now — try later or check planned trips.',
        uk: 'Поблизу зараз немає водіїв — спробуйте пізніше або перегляньте заплановані поїздки.',
        es: 'No hay conductores cerca ahora: prueba más tarde o mira viajes planificados.',
        de: 'Gerade keine Fahrer in der Nähe — später versuchen oder geplante Fahrten ansehen.',
        fr: 'Aucun conducteur à proximité — réessaie plus tard ou vois les trajets planifiés.',
        it: 'Nessun conducente nelle vicinanze: riprova più tardi o guarda i viaggi pianificati.',
      );
  String get adviceSetDestination => _t(
        en: 'Set a destination to find drivers going your way.',
        uk: 'Вкажіть призначення, щоб знайти водіїв у вашому напрямку.',
        es: 'Indica un destino para encontrar conductores en tu dirección.',
        de: 'Lege ein Ziel fest, um Fahrer in deine Richtung zu finden.',
        fr: 'Définis une destination pour trouver des conducteurs dans ta direction.',
        it: 'Imposta una destinazione per trovare conducenti nella tua direzione.',
      );
  String get corridorRadius => _t(
        en: 'Corridor radius',
        uk: 'Радіус коридору',
        es: 'Radio del corredor',
        de: 'Korridorradius',
        fr: 'Rayon du couloir',
        it: 'Raggio del corridoio',
      );
  String get availableSeats => _t(
        en: 'Available seats',
        uk: 'Доступні місця',
        es: 'Asientos disponibles',
        de: 'Verfügbare Plätze',
        fr: 'Places disponibles',
        it: 'Posti disponibili',
      );
  String get routeActive => _t(
        en: 'Route active',
        uk: 'Маршрут активний',
        es: 'Ruta activa',
        de: 'Route aktiv',
        fr: 'Trajet actif',
        it: 'Tragitto attivo',
      );
  String get exploringAsGuest => _t(
        en: 'Exploring as Guest',
        uk: 'Досліджуєте як гість',
        es: 'Explorando como invitado',
        de: 'Als Gast unterwegs',
        fr: 'Exploration en invité',
        it: 'Esplorazione come ospite',
      );
  String get signInToShareRoute => _t(
        en: 'Sign In to Share Route',
        uk: 'Увійдіть, щоб поділитися маршрутом',
        es: 'Inicia sesión para compartir tu ruta',
        de: 'Anmelden, um Route zu teilen',
        fr: 'Connecte-toi pour partager ton trajet',
        it: 'Accedi per condividere il tragitto',
      );
  String get signInShareDesc => _t(
        en: 'Sign in to share your route and get matched with passengers.',
        uk: 'Увійдіть, щоб поділитися маршрутом та знайти пасажирів.',
        es: 'Inicia sesión para compartir tu ruta y encontrar pasajeros.',
        de: 'Melde dich an, um deine Route zu teilen und Fahrgäste zu finden.',
        fr: 'Connecte-toi pour partager ton trajet et trouver des passagers.',
        it: 'Accedi per condividere il tragitto e trovare passeggeri.',
      );

  // ─── Passenger home ──────────────────────────────────────────────────────
  String get lookingForRides => _t(
        en: 'Looking for rides',
        uk: 'Шукаємо поїздки',
        es: 'Buscando viajes',
        de: 'Suche nach Fahrten',
        fr: 'Recherche de trajets',
        it: 'Cerco passaggi',
      );
  String get lookingDesc => _t(
        en: "We'll notify you when a driver with a matching route is nearby.",
        uk: 'Ми повідомимо вас, коли поруч буде водій з відповідним маршрутом.',
        es: 'Te avisaremos cuando haya un conductor con una ruta compatible cerca.',
        de: 'Wir benachrichtigen dich, wenn ein passender Fahrer in der Nähe ist.',
        fr: 'Nous t\'informerons quand un conducteur avec un trajet compatible sera à proximité.',
        it: 'Ti avviseremo quando un conducente con un tragitto compatibile sarà vicino.',
      );
  String get signInToFindRides => _t(
        en: 'Sign In to Find Rides',
        uk: 'Увійдіть, щоб знайти поїздки',
        es: 'Inicia sesión para buscar viajes',
        de: 'Anmelden, um Fahrten zu finden',
        fr: 'Connecte-toi pour trouver des trajets',
        it: 'Accedi per trovare passaggi',
      );
  String get signInFindDesc => _t(
        en: 'Sign in to get matched with drivers heading your way.',
        uk: 'Увійдіть, щоб отримати підбір водіїв, які їдуть у вашому напрямку.',
        es: 'Inicia sesión para encontrar conductores que vayan por tu camino.',
        de: 'Melde dich an, um Fahrer auf deinem Weg zu finden.',
        fr: 'Connecte-toi pour être mis en relation avec des conducteurs sur ta route.',
        it: 'Accedi per essere abbinato a conducenti diretti dalle tue parti.',
      );

  // ─── Sign-in prompt sheet ────────────────────────────────────────────────
  String get signInToContinue => _t(
        en: 'Sign in to continue',
        uk: 'Увійдіть, щоб продовжити',
        es: 'Inicia sesión para continuar',
        de: 'Zum Fortfahren anmelden',
        fr: 'Connecte-toi pour continuer',
        it: 'Accedi per continuare',
      );
  String get signInRegister => _t(
        en: 'Sign In / Register',
        uk: 'Увійти / Зареєструватися',
        es: 'Iniciar sesión / Registrarse',
        de: 'Anmelden / Registrieren',
        fr: 'Se connecter / S\'inscrire',
        it: 'Accedi / Registrati',
      );

  // ─── Auth — fields and toggles ───────────────────────────────────────────
  String get fullName => _t(
        en: 'Full name',
        uk: 'Повне ім\'я',
        es: 'Nombre completo',
        de: 'Vollständiger Name',
        fr: 'Nom complet',
        it: 'Nome completo',
      );
  String get emailAddress => _t(
        en: 'Email address',
        uk: 'Електронна пошта',
        es: 'Correo electrónico',
        de: 'E-Mail-Adresse',
        fr: 'Adresse e-mail',
        it: 'Indirizzo e-mail',
      );
  String get password => _t(
        en: 'Password',
        uk: 'Пароль',
        es: 'Contraseña',
        de: 'Passwort',
        fr: 'Mot de passe',
        it: 'Password',
      );
  String get invalidEmail => _t(
        en: 'Invalid email',
        uk: 'Невірна електронна пошта',
        es: 'Correo no válido',
        de: 'Ungültige E-Mail',
        fr: 'E-mail invalide',
        it: 'E-mail non valida',
      );
  String get minSixChars => _t(
        en: 'Min 6 characters',
        uk: 'Мінімум 6 символів',
        es: 'Mín. 6 caracteres',
        de: 'Mind. 6 Zeichen',
        fr: 'Min. 6 caractères',
        it: 'Min. 6 caratteri',
      );
  String get noAccountYet => _t(
        en: "Don't have an account? ",
        uk: 'Немає акаунта? ',
        es: '¿No tienes cuenta? ',
        de: 'Noch kein Konto? ',
        fr: 'Pas de compte ? ',
        it: 'Non hai un account? ',
      );
  String get alreadyHaveAccount => _t(
        en: 'Already have an account? ',
        uk: 'Вже маєте акаунт? ',
        es: '¿Ya tienes cuenta? ',
        de: 'Bereits ein Konto? ',
        fr: 'Déjà un compte ? ',
        it: 'Hai già un account? ',
      );

  // ─── Onboarding pages ────────────────────────────────────────────────────
  String get onboardTitle1 => _t(
        en: 'Smarter routes, together.',
        uk: 'Розумніші маршрути разом.',
        es: 'Rutas más inteligentes, juntos.',
        de: 'Klügere Routen, gemeinsam.',
        fr: 'Des trajets plus intelligents, ensemble.',
        it: 'Tragitti più intelligenti, insieme.',
      );
  String get onboardSubtitle1 => _t(
        en: 'Share rides with people heading your way.',
        uk: 'Поділіться поїздкою з тими, хто їде у тому ж напрямку.',
        es: 'Comparte viajes con personas que van por tu camino.',
        de: 'Teile Fahrten mit Menschen auf deinem Weg.',
        fr: 'Partage des trajets avec ceux qui vont dans ta direction.',
        it: 'Condividi i passaggi con chi va nella tua stessa direzione.',
      );
  String get onboardTitle2 => _t(
        en: 'Real-time matching.',
        uk: 'Підбір у реальному часі.',
        es: 'Emparejamiento en tiempo real.',
        de: 'Matching in Echtzeit.',
        fr: 'Mise en relation en temps réel.',
        it: 'Abbinamento in tempo reale.',
      );
  String get onboardSubtitle2 => _t(
        en: 'Drivers and passengers find each other instantly.',
        uk: 'Водії та пасажири миттєво знаходять одне одного.',
        es: 'Conductores y pasajeros se encuentran al instante.',
        de: 'Fahrer und Fahrgäste finden sich sofort.',
        fr: 'Conducteurs et passagers se trouvent instantanément.',
        it: 'Conducenti e passeggeri si trovano all\'istante.',
      );
  String get onboardTitle3 => _t(
        en: 'Save CO₂ together.',
        uk: 'Економте CO₂ разом.',
        es: 'Ahorra CO₂ juntos.',
        de: 'Gemeinsam CO₂ sparen.',
        fr: 'Économisons du CO₂ ensemble.',
        it: 'Risparmiamo CO₂ insieme.',
      );
  String get onboardSubtitle3 => _t(
        en: 'Every shared trip reduces emissions.',
        uk: 'Кожна спільна поїздка зменшує викиди.',
        es: 'Cada viaje compartido reduce las emisiones.',
        de: 'Jede geteilte Fahrt senkt die Emissionen.',
        fr: 'Chaque trajet partagé réduit les émissions.',
        it: 'Ogni viaggio condiviso riduce le emissioni.',
      );
  String get skip => _t(
        en: 'Skip',
        uk: 'Пропустити',
        es: 'Saltar',
        de: 'Überspringen',
        fr: 'Passer',
        it: 'Salta',
      );
  String get getStarted => _t(
        en: 'Get Started',
        uk: 'Почати',
        es: 'Comenzar',
        de: 'Loslegen',
        fr: 'Commencer',
        it: 'Inizia',
      );
  String get continueLabel => _t(
        en: 'Continue',
        uk: 'Продовжити',
        es: 'Continuar',
        de: 'Weiter',
        fr: 'Continuer',
        it: 'Continua',
      );

  // ─── First-run safety disclaimers (onboarding carousel) ──────────────────
  String get safetyPassengerTitle => _t(
        en: 'Ride smart, stay safe',
        uk: 'Їдьте розумно й безпечно',
        es: 'Viaja con cabeza, viaja seguro',
        de: 'Clever mitfahren, sicher bleiben',
        fr: 'Voyagez malin, restez en sécurité',
        it: 'Viaggia furbo, viaggia sicuro',
      );
  String get safetyPassengerBody => _t(
        en: "Sameway connects you with drivers already heading your way — it's not a taxi. Wait somewhere safe and easy to reach, near a spot a passing driver can pull over for. Only get in when you feel comfortable.",
        uk: "Sameway з'єднує вас із водіями, які й так їдуть у вашому напрямку, — це не таксі. Чекайте в безпечному й легкодоступному місці, де водій, що проїжджає повз, зможе зупинитися. Сідайте лише тоді, коли почуваєтеся комфортно.",
        es: 'Sameway te conecta con conductores que ya van en tu dirección; no es un taxi. Espera en un lugar seguro y de fácil acceso, donde un conductor de paso pueda detenerse. Súbete solo cuando te sientas cómodo.',
        de: 'Sameway verbindet dich mit Fahrern, die ohnehin in deine Richtung fahren – es ist kein Taxi. Warte an einem sicheren, gut erreichbaren Ort, an dem ein vorbeifahrender Fahrer anhalten kann. Steig nur ein, wenn du dich wohlfühlst.',
        fr: "Sameway vous met en relation avec des conducteurs qui vont déjà dans votre direction — ce n'est pas un taxi. Attendez dans un endroit sûr et facile d'accès, où un conducteur de passage peut s'arrêter. Ne montez que si vous vous sentez à l'aise.",
        it: 'Sameway ti mette in contatto con automobilisti che stanno già andando nella tua direzione — non è un taxi. Aspetta in un luogo sicuro e facile da raggiungere, dove un conducente di passaggio possa fermarsi. Sali solo quando ti senti a tuo agio.',
      );
  String get safetyDriverTitle => _t(
        en: 'Drive your own way',
        uk: 'Їдьте своїм маршрутом',
        es: 'Conduce a tu manera',
        de: 'Fahr deinen eigenen Weg',
        fr: 'Roulez à votre façon',
        it: 'Guida a modo tuo',
      );
  String get safetyDriverBody => _t(
        en: "You're sharing the road you're already on. Only stop for a passenger when it's safe and they're in a good, reachable spot. If they're not, it's okay to keep going — take a small detour only if you're comfortable. It's your call, not an obligation.",
        uk: "Ви ділитеся дорогою, якою вже їдете. Зупиняйтеся заради пасажира лише тоді, коли це безпечно, а він у зручному й доступному місці. Якщо ні — можете спокійно їхати далі. Робіть невеликий об'їзд, лише якщо вам це зручно. Це ваш вибір, а не обов'язок.",
        es: 'Compartes la carretera por la que ya vas. Detente por un pasajero solo cuando sea seguro y esté en un lugar accesible. Si no lo está, puedes seguir tu camino sin problema. Haz un pequeño desvío solo si te resulta cómodo. Es tu decisión, no una obligación.',
        de: 'Du teilst die Strecke, auf der du ohnehin unterwegs bist. Halte nur für einen Fahrgast, wenn es sicher ist und er an einer gut erreichbaren Stelle steht. Wenn nicht, kannst du ruhig weiterfahren. Mach nur einen kleinen Umweg, wenn es für dich passt. Es ist deine Entscheidung, keine Pflicht.',
        fr: "Vous partagez la route que vous empruntez déjà. Ne vous arrêtez pour un passager que si c'est sûr et qu'il se trouve à un endroit accessible. Sinon, vous pouvez continuer votre chemin sans souci. Ne faites un petit détour que si cela vous convient. C'est votre choix, pas une obligation.",
        it: 'Condividi la strada che stai già percorrendo. Fermati per un passeggero solo quando è sicuro e si trova in un punto facilmente raggiungibile. In caso contrario, puoi tranquillamente proseguire. Fai una piccola deviazione solo se ti è comodo. È una tua scelta, non un obbligo.',
      );

  // ─── Common buttons / dialogs ────────────────────────────────────────────
  String get save => _t(
        en: 'Save',
        uk: 'Зберегти',
        es: 'Guardar',
        de: 'Speichern',
        fr: 'Enregistrer',
        it: 'Salva',
      );
  String get cancel => _t(
        en: 'Cancel',
        uk: 'Скасувати',
        es: 'Cancelar',
        de: 'Abbrechen',
        fr: 'Annuler',
        it: 'Annulla',
      );
  String get later => _t(
        en: 'Later',
        uk: 'Пізніше',
        es: 'Más tarde',
        de: 'Später',
        fr: 'Plus tard',
        it: 'Più tardi',
      );
  String get openSettings => _t(
        en: 'Open Settings',
        uk: 'Відкрити налаштування',
        es: 'Abrir ajustes',
        de: 'Einstellungen öffnen',
        fr: 'Ouvrir les paramètres',
        it: 'Apri impostazioni',
      );
  String get gpsOff => _t(
        en: 'GPS is off',
        uk: 'GPS вимкнено',
        es: 'GPS desactivado',
        de: 'GPS ist aus',
        fr: 'GPS désactivé',
        it: 'GPS disattivato',
      );
  String get gpsOffMessage => _t(
        en: 'Location services are required to find rides.',
        uk: 'Потрібно увімкнути геолокацію, щоб знаходити поїздки.',
        es: 'Se requiere ubicación para encontrar viajes.',
        de: 'Standortdienste sind nötig, um Fahrten zu finden.',
        fr: 'La localisation est nécessaire pour trouver des trajets.',
        it: 'I servizi di localizzazione sono necessari per trovare passaggi.',
      );
  String get keepRide => _t(
        en: 'Keep ride',
        uk: 'Залишити поїздку',
        es: 'Mantener viaje',
        de: 'Fahrt behalten',
        fr: 'Garder le trajet',
        it: 'Mantieni il passaggio',
      );
  String get cancelRideQ => _t(
        en: 'Cancel ride?',
        uk: 'Скасувати поїздку?',
        es: '¿Cancelar viaje?',
        de: 'Fahrt abbrechen?',
        fr: 'Annuler le trajet ?',
        it: 'Annullare il passaggio?',
      );
  String get cancelRideMessageDriver => _t(
        en: 'The passenger will be notified.',
        uk: 'Пасажир буде сповіщений.',
        es: 'Se avisará al pasajero.',
        de: 'Der Fahrgast wird benachrichtigt.',
        fr: 'Le passager sera averti.',
        it: 'Il passeggero verrà avvisato.',
      );
  String get cancelRideMessagePassenger => _t(
        en: 'Your driver will be notified.',
        uk: 'Водій буде сповіщений.',
        es: 'Se avisará a tu conductor.',
        de: 'Dein Fahrer wird benachrichtigt.',
        fr: 'Ton conducteur sera averti.',
        it: 'Il tuo conducente verrà avvisato.',
      );

  // ─── Offer / Accepted / Looking cards ────────────────────────────────────
  String get rideOffer => _t(
        en: 'Ride offer!',
        uk: 'Пропозиція поїздки!',
        es: '¡Oferta de viaje!',
        de: 'Fahrtangebot!',
        fr: 'Offre de trajet !',
        it: 'Offerta di passaggio!',
      );
  String get accept => _t(
        en: 'Accept',
        uk: 'Прийняти',
        es: 'Aceptar',
        de: 'Annehmen',
        fr: 'Accepter',
        it: 'Accetta',
      );
  String get decline => _t(
        en: 'Decline',
        uk: 'Відхилити',
        es: 'Rechazar',
        de: 'Ablehnen',
        fr: 'Refuser',
        it: 'Rifiuta',
      );
  String get rideAccepted => _t(
        en: 'Ride accepted!',
        uk: 'Поїздку прийнято!',
        es: '¡Viaje aceptado!',
        de: 'Fahrt angenommen!',
        fr: 'Trajet accepté !',
        it: 'Passaggio accettato!',
      );
  String get youAreInTheRide => _t(
        en: "You're in the ride",
        uk: 'Ви в поїздці',
        es: 'Estás en el viaje',
        de: 'Du bist in der Fahrt',
        fr: 'Vous êtes dans le trajet',
        it: 'Sei in viaggio',
      );
  String get driverNotified => _t(
        en: 'Your driver has been notified. Stay at your location.',
        uk: 'Водія сповіщено. Залишайтеся на місці.',
        es: 'Tu conductor ha sido avisado. Quédate en tu ubicación.',
        de: 'Dein Fahrer wurde benachrichtigt. Bleib an deinem Standort.',
        fr: 'Ton conducteur a été averti. Reste à ton emplacement.',
        it: 'Il tuo conducente è stato avvisato. Resta sul posto.',
      );
  String get messageDriver => _t(
        en: 'Message Driver',
        uk: 'Написати водієві',
        es: 'Mensaje al conductor',
        de: 'Fahrer schreiben',
        fr: 'Écrire au conducteur',
        it: 'Scrivi al conducente',
      );
  String get driverLabel => _t(
        en: 'Driver',
        uk: 'Водій',
        es: 'Conductor',
        de: 'Fahrer',
        fr: 'Conducteur',
        it: 'Conducente',
      );
  String get corridorLabel => _t(
        en: 'km corridor',
        uk: 'км коридор',
        es: 'km de corredor',
        de: 'km Korridor',
        fr: 'km de couloir',
        it: 'km di corridoio',
      );
  String get seatLabel => _t(
        en: 'seat',
        uk: 'місце',
        es: 'asiento',
        de: 'Platz',
        fr: 'place',
        it: 'posto',
      );
  String get seatsLabel => _t(
        en: 'seats',
        uk: 'місць',
        es: 'asientos',
        de: 'Plätze',
        fr: 'places',
        it: 'posti',
      );

  // ─── Driver home — requests list ─────────────────────────────────────────
  String get noRideRequests => _t(
        en: 'No ride requests yet',
        uk: 'Поки немає запитів',
        es: 'Aún no hay solicitudes',
        de: 'Noch keine Fahrtanfragen',
        fr: 'Aucune demande pour l\'instant',
        it: 'Ancora nessuna richiesta',
      );
  String get noRideRequestsDesc => _t(
        en: 'Passengers near your route will appear here.',
        uk: 'Пасажири біля вашого маршруту з\'являться тут.',
        es: 'Los pasajeros cerca de tu ruta aparecerán aquí.',
        de: 'Fahrgäste in der Nähe deiner Route erscheinen hier.',
        fr: 'Les passagers proches de ton trajet apparaîtront ici.',
        it: 'I passeggeri vicini al tuo tragitto appariranno qui.',
      );
  String get rideRequests => _t(
        en: 'Ride requests',
        uk: 'Запити на поїздку',
        es: 'Solicitudes de viaje',
        de: 'Fahrtanfragen',
        fr: 'Demandes de trajet',
        it: 'Richieste di passaggio',
      );

  // ─── Account & Security ──────────────────────────────────────────────────
  String get displayName => _t(
        en: 'Display name',
        uk: 'Ім\'я',
        es: 'Nombre visible',
        de: 'Anzeigename',
        fr: 'Nom affiché',
        it: 'Nome visualizzato',
      );
  String get changePassword => _t(
        en: 'Change password',
        uk: 'Змінити пароль',
        es: 'Cambiar contraseña',
        de: 'Passwort ändern',
        fr: 'Changer le mot de passe',
        it: 'Cambia password',
      );
  String get currentPassword => _t(
        en: 'Current password',
        uk: 'Поточний пароль',
        es: 'Contraseña actual',
        de: 'Aktuelles Passwort',
        fr: 'Mot de passe actuel',
        it: 'Password attuale',
      );
  String get newPassword => _t(
        en: 'New password',
        uk: 'Новий пароль',
        es: 'Nueva contraseña',
        de: 'Neues Passwort',
        fr: 'Nouveau mot de passe',
        it: 'Nuova password',
      );
  String get confirmNewPassword => _t(
        en: 'Confirm new password',
        uk: 'Підтвердити новий пароль',
        es: 'Confirmar nueva contraseña',
        de: 'Neues Passwort bestätigen',
        fr: 'Confirmer le nouveau mot de passe',
        it: 'Conferma la nuova password',
      );
  String get updatePassword => _t(
        en: 'Update Password',
        uk: 'Оновити пароль',
        es: 'Actualizar contraseña',
        de: 'Passwort aktualisieren',
        fr: 'Mettre à jour le mot de passe',
        it: 'Aggiorna password',
      );
  String get passwordSameAsCurrent => _t(
        en: 'New password must differ from current password',
        uk: 'Новий пароль має відрізнятися від поточного',
        es: 'La nueva contraseña debe diferir de la actual',
        de: 'Neues Passwort muss vom aktuellen abweichen',
        fr: 'Le nouveau mot de passe doit différer de l\'actuel',
        it: 'La nuova password deve essere diversa da quella attuale',
      );
  String get passwordsNotMatch => _t(
        en: 'New passwords do not match',
        uk: 'Нові паролі не співпадають',
        es: 'Las contraseñas no coinciden',
        de: 'Neue Passwörter stimmen nicht überein',
        fr: 'Les nouveaux mots de passe ne correspondent pas',
        it: 'Le nuove password non coincidono',
      );
  String get passwordTooShort => _t(
        en: 'Password must be at least 6 characters',
        uk: 'Пароль має містити мінімум 6 символів',
        es: 'La contraseña debe tener al menos 6 caracteres',
        de: 'Passwort muss mindestens 6 Zeichen haben',
        fr: 'Le mot de passe doit comporter au moins 6 caractères',
        it: 'La password deve contenere almeno 6 caratteri',
      );
  String get passwordUpdated => _t(
        en: 'Password updated',
        uk: 'Пароль оновлено',
        es: 'Contraseña actualizada',
        de: 'Passwort aktualisiert',
        fr: 'Mot de passe mis à jour',
        it: 'Password aggiornata',
      );
  String get networkError => _t(
        en: 'Network error',
        uk: 'Помилка мережі',
        es: 'Error de red',
        de: 'Netzwerkfehler',
        fr: 'Erreur réseau',
        it: 'Errore di rete',
      );
  String get nameUpdated => _t(
        en: 'Name updated',
        uk: 'Ім\'я оновлено',
        es: 'Nombre actualizado',
        de: 'Name aktualisiert',
        fr: 'Nom mis à jour',
        it: 'Nome aggiornato',
      );
  String get emailCopied => _t(
        en: 'Email copied',
        uk: 'Email скопійовано',
        es: 'Correo copiado',
        de: 'E-Mail kopiert',
        fr: 'E-mail copié',
        it: 'E-mail copiata',
      );

  // ─── Chat ────────────────────────────────────────────────────────────────
  String get activeTrip => _t(
        en: 'Active trip',
        uk: 'Активна поїздка',
        es: 'Viaje activo',
        de: 'Aktive Fahrt',
        fr: 'Trajet en cours',
        it: 'Viaggio attivo',
      );
  String get noMessages => _t(
        en: 'No messages yet.\nSay hello!',
        uk: 'Поки немає повідомлень.\nПривітайтеся!',
        es: 'Aún no hay mensajes.\n¡Saluda!',
        de: 'Noch keine Nachrichten.\nSag Hallo!',
        fr: 'Pas encore de messages.\nDis bonjour !',
        it: 'Nessun messaggio ancora.\nSaluta!',
      );
  String get messageHint => _t(
        en: 'Message…',
        uk: 'Повідомлення…',
        es: 'Mensaje…',
        de: 'Nachricht…',
        fr: 'Message…',
        it: 'Messaggio…',
      );
  // "<name> is typing…" — drives the pill above the chat input.
  String typing(String name) => _t(
        en: '$name is typing…',
        uk: '$name пише…',
        es: '$name está escribiendo…',
        de: '$name schreibt…',
        fr: '$name écrit…',
        it: '$name sta scrivendo…',
      );

  // ─── Trip history ────────────────────────────────────────────────────────
  String get tripHistory => _t(
        en: 'Trip History',
        uk: 'Історія поїздок',
        es: 'Historial de viajes',
        de: 'Fahrtenverlauf',
        fr: 'Historique des trajets',
        it: 'Cronologia viaggi',
      );
  String get noTripsYet => _t(
        en: 'No trips yet',
        uk: 'Поки немає поїздок',
        es: 'Aún no hay viajes',
        de: 'Noch keine Fahrten',
        fr: 'Aucun trajet pour l\'instant',
        it: 'Ancora nessun viaggio',
      );
  String get firstRidePrompt => _t(
        en: 'Complete your first ride to see it here.',
        uk: 'Завершіть першу поїздку, щоб побачити її тут.',
        es: 'Completa tu primer viaje para verlo aquí.',
        de: 'Schließe deine erste Fahrt ab, um sie hier zu sehen.',
        fr: 'Termine ton premier trajet pour le voir ici.',
        it: 'Completa il tuo primo viaggio per vederlo qui.',
      );

  // ─── Trip planner / search sheets ────────────────────────────────────────
  String get selectOriginLocation => _t(
        en: 'Select an origin location',
        uk: 'Виберіть початкове місце',
        es: 'Elige un punto de origen',
        de: 'Startort auswählen',
        fr: 'Sélectionne un point de départ',
        it: 'Seleziona un punto di partenza',
      );
  String get selectDestinationLocation => _t(
        en: 'Select a destination location',
        uk: 'Виберіть місце призначення',
        es: 'Elige un destino',
        de: 'Zielort auswählen',
        fr: 'Sélectionne une destination',
        it: 'Seleziona una destinazione',
      );
  String get tripPlannedSuccess => _t(
        en: 'Trip planned successfully!',
        uk: 'Поїздку успішно заплановано!',
        es: '¡Viaje planificado con éxito!',
        de: 'Fahrt erfolgreich geplant!',
        fr: 'Trajet planifié avec succès !',
        it: 'Viaggio pianificato con successo!',
      );
  String get locationNotAvailable => _t(
        en: 'Location not available',
        uk: 'Геолокація недоступна',
        es: 'Ubicación no disponible',
        de: 'Standort nicht verfügbar',
        fr: 'Position non disponible',
        it: 'Posizione non disponibile',
      );
  String get requestSent => _t(
        en: 'Request sent!',
        uk: 'Запит надіслано!',
        es: '¡Solicitud enviada!',
        de: 'Anfrage gesendet!',
        fr: 'Demande envoyée !',
        it: 'Richiesta inviata!',
      );
  String get requestFailed => _t(
        en: 'Failed to send request',
        uk: 'Не вдалося надіслати запит',
        es: 'Error al enviar la solicitud',
        de: 'Anfrage konnte nicht gesendet werden',
        fr: 'Échec de l\'envoi de la demande',
        it: 'Impossibile inviare la richiesta',
      );

  // ─── Promotions ──────────────────────────────────────────────────────────
  String get promotionsAndRewards => _t(
        en: 'Promotions & Rewards',
        uk: 'Акції та винагороди',
        es: 'Promociones y recompensas',
        de: 'Aktionen & Prämien',
        fr: 'Offres et récompenses',
        it: 'Promozioni e premi',
      );
  String get activeOffers => _t(
        en: 'Active Offers',
        uk: 'Активні пропозиції',
        es: 'Ofertas activas',
        de: 'Aktive Angebote',
        fr: 'Offres actives',
        it: 'Offerte attive',
      );
  String get expired => _t(
        en: 'Expired',
        uk: 'Минулі',
        es: 'Vencidas',
        de: 'Abgelaufen',
        fr: 'Expirées',
        it: 'Scadute',
      );
  String get noPromotions => _t(
        en: 'No promotions available',
        uk: 'Немає доступних акцій',
        es: 'No hay promociones disponibles',
        de: 'Keine Aktionen verfügbar',
        fr: 'Aucune offre disponible',
        it: 'Nessuna promozione disponibile',
      );

  // ─── Rating sheet ────────────────────────────────────────────────────────
  String get rateYourDriver => _t(
        en: 'Rate your driver',
        uk: 'Оцінити водія',
        es: 'Valora a tu conductor',
        de: 'Bewerte deinen Fahrer',
        fr: 'Évalue ton conducteur',
        it: 'Valuta il tuo conducente',
      );
  String get rateYourPassenger => _t(
        en: 'Rate your passenger',
        uk: 'Оцінити пасажира',
        es: 'Valora a tu pasajero',
        de: 'Bewerte deinen Fahrgast',
        fr: 'Évalue ton passager',
        it: 'Valuta il tuo passeggero',
      );
  String get howWasExperience => _t(
        en: 'How was your experience?',
        uk: 'Як вам поїздка?',
        es: '¿Cómo fue tu experiencia?',
        de: 'Wie war deine Erfahrung?',
        fr: 'Comment s\'est passé ton trajet ?',
        it: 'Com\'è andata l\'esperienza?',
      );
  String get addCommentOptional => _t(
        en: 'Add a comment (optional)',
        uk: 'Додати коментар (необов\'язково)',
        es: 'Añadir un comentario (opcional)',
        de: 'Kommentar hinzufügen (optional)',
        fr: 'Ajouter un commentaire (facultatif)',
        it: 'Aggiungi un commento (opzionale)',
      );
  String get submit => _t(
        en: 'Submit',
        uk: 'Надіслати',
        es: 'Enviar',
        de: 'Senden',
        fr: 'Envoyer',
        it: 'Invia',
      );
  String get skipRating => _t(
        en: 'Skip',
        uk: 'Пропустити',
        es: 'Saltar',
        de: 'Überspringen',
        fr: 'Passer',
        it: 'Salta',
      );

  // ─── Car edit sheet ──────────────────────────────────────────────────────
  String get myCar => _t(
        en: 'My Car',
        uk: 'Моє авто',
        es: 'Mi coche',
        de: 'Mein Auto',
        fr: 'Ma voiture',
        it: 'La mia auto',
      );
  String get carMake => _t(
        en: 'Make',
        uk: 'Марка',
        es: 'Marca',
        de: 'Marke',
        fr: 'Marque',
        it: 'Marca',
      );
  String get carModel => _t(
        en: 'Model',
        uk: 'Модель',
        es: 'Modelo',
        de: 'Modell',
        fr: 'Modèle',
        it: 'Modello',
      );
  String get carColor => _t(
        en: 'Color',
        uk: 'Колір',
        es: 'Color',
        de: 'Farbe',
        fr: 'Couleur',
        it: 'Colore',
      );
  String get carPlate => _t(
        en: 'Plate',
        uk: 'Номерний знак',
        es: 'Matrícula',
        de: 'Kennzeichen',
        fr: 'Plaque',
        it: 'Targa',
      );
  String get carMakeHint => _t(
        en: 'e.g. Toyota',
        uk: 'напр. Toyota',
        es: 'p. ej. Toyota',
        de: 'z. B. Toyota',
        fr: 'p. ex. Toyota',
        it: 'es. Toyota',
      );
  String get carModelHint => _t(
        en: 'e.g. Corolla',
        uk: 'напр. Corolla',
        es: 'p. ej. Corolla',
        de: 'z. B. Corolla',
        fr: 'p. ex. Corolla',
        it: 'es. Corolla',
      );
  String get carColorHint => _t(
        en: 'e.g. Silver',
        uk: 'напр. Сріблястий',
        es: 'p. ej. Plata',
        de: 'z. B. Silber',
        fr: 'p. ex. Argent',
        it: 'es. Argento',
      );
  String get carPlateHint => _t(
        en: 'e.g. KR 12345',
        uk: 'напр. КА 12345',
        es: 'p. ej. 1234 ABC',
        de: 'z. B. B-AB 1234',
        fr: 'p. ex. AB-123-CD',
        it: 'es. AB 123 CD',
      );
  String get carInfoSaved => _t(
        en: 'Car info saved!',
        uk: 'Інформацію про авто збережено!',
        es: '¡Información del coche guardada!',
        de: 'Fahrzeugdaten gespeichert!',
        fr: 'Infos véhicule enregistrées !',
        it: 'Dati dell\'auto salvati!',
      );

  // ─── Misc tiles / sheets ─────────────────────────────────────────────────
  String get testNotificationSent => _t(
        en: 'Test notification sent!',
        uk: 'Тестове сповіщення надіслано!',
        es: '¡Notificación de prueba enviada!',
        de: 'Testbenachrichtigung gesendet!',
        fr: 'Notification de test envoyée !',
        it: 'Notifica di prova inviata!',
      );
  String get mapStyle => _t(
        en: 'Map Style',
        uk: 'Стиль карти',
        es: 'Estilo del mapa',
        de: 'Kartenstil',
        fr: 'Style de carte',
        it: 'Stile mappa',
      );
  String get planATrip => _t(
        en: 'Plan a Trip',
        uk: 'Запланувати поїздку',
        es: 'Planificar un viaje',
        de: 'Fahrt planen',
        fr: 'Planifier un trajet',
        it: 'Pianifica un viaggio',
      );
  String get findPlannedTrips => _t(
        en: 'Find Planned Trips',
        uk: 'Знайти заплановані поїздки',
        es: 'Buscar viajes planificados',
        de: 'Geplante Fahrten finden',
        fr: 'Trouver des trajets planifiés',
        it: 'Trova viaggi pianificati',
      );
  String get testNotification => _t(
        en: 'Test Notification',
        uk: 'Тестове сповіщення',
        es: 'Notificación de prueba',
        de: 'Testbenachrichtigung',
        fr: 'Notification de test',
        it: 'Notifica di prova',
      );
  String get aiMatchingLabel => _t(
        en: 'AI-assisted matching',
        uk: 'AI-підбір',
        es: 'Coincidencia con IA',
        de: 'KI-gestütztes Matching',
        fr: 'Mise en relation assistée par IA',
        it: 'Abbinamento con IA',
      );
  String get aiMatchingSubtitle => _t(
        en: 'Experimental. Re-orders candidates using AI.',
        uk: 'Експериментально. Перевпорядковує кандидатів за допомогою AI.',
        es: 'Experimental. Reordena candidatos con IA.',
        de: 'Experimentell. Reiht Kandidaten mithilfe von KI neu.',
        fr: 'Expérimental. Réordonne les candidats avec l\'IA.',
        it: 'Sperimentale. Riordina i candidati con l\'IA.',
      );

  // ─── AI ranker self-test ─────────────────────────────────────────────────
  String get testAILabel => _t(
        en: 'Test AI matching',
        uk: 'Перевірити AI-підбір',
        es: 'Probar coincidencia con IA',
        de: 'KI-Matching testen',
        fr: 'Tester la mise en relation IA',
        it: 'Prova abbinamento IA',
      );
  String get testAIOK => _t(
        en: 'AI ranker working',
        uk: 'AI-підбір працює',
        es: 'IA funcionando',
        de: 'KI funktioniert',
        fr: 'IA opérationnelle',
        it: 'IA funzionante',
      );
  String get testAIFailed => _t(
        en: 'AI ranker failed',
        uk: 'AI-підбір не працює',
        es: 'La IA falló',
        de: 'KI fehlgeschlagen',
        fr: 'Échec de l\'IA',
        it: 'IA non riuscita',
      );
  String get testAIDisabled => _t(
        en: 'AI not configured — using geometric',
        uk: 'AI не налаштовано — використовується геометричний',
        es: 'IA no configurada — usando geométrico',
        de: 'KI nicht konfiguriert — geometrisches Matching',
        fr: 'IA non configurée — méthode géométrique',
        it: 'IA non configurata — uso del metodo geometrico',
      );

  // ─── Walk-to-pickup banner ───────────────────────────────────────────────
  String walkToPickup(String dist) => _t(
        en: 'Walk $dist to pickup',
        uk: 'Пройдіть $dist до точки посадки',
        es: 'Camina $dist hasta el punto de recogida',
        de: 'Gehe $dist zum Abholpunkt',
        fr: 'Marche $dist jusqu\'au point de prise en charge',
        it: 'Cammina $dist fino al punto di partenza',
      );
  // ─── Candidate driver list (pre-match) ───────────────────────────────────
  String get candidateDriversTitle => _t(
        en: 'Drivers going your way',
        uk: 'Водії, яким по дорозі',
        es: 'Conductores que van en tu dirección',
        de: 'Fahrer auf deinem Weg',
        fr: 'Conducteurs qui vont dans votre direction',
        it: 'Conducenti che vanno nella tua direzione',
      );
  String get candidateDriversEmpty => _t(
        en: 'No drivers going your way yet. We\'ll keep looking.',
        uk: 'Поки немає водіїв, яким по дорозі. Продовжуємо шукати.',
        es: 'Aún no hay conductores en tu dirección. Seguiremos buscando.',
        de: 'Noch keine Fahrer auf deinem Weg. Wir suchen weiter.',
        fr: 'Aucun conducteur dans votre direction pour l\'instant. Nous continuons à chercher.',
        it: 'Ancora nessun conducente nella tua direzione. Continuiamo a cercare.',
      );
  String get sameWayBadge => _t(
        en: 'Same way',
        uk: 'По дорозі',
        es: 'Mismo camino',
        de: 'Gleicher Weg',
        fr: 'Même route',
        it: 'Stessa strada',
      );
  String get newDriverBadge => _t(
        en: 'New',
        uk: 'Новий',
        es: 'Nuevo',
        de: 'Neu',
        fr: 'Nouveau',
        it: 'Nuovo',
      );
  String etaApprox(int min) => _t(
        en: '~$min min away',
        uk: '~$min хв їзди',
        es: 'a ~$min min',
        de: '~$min Min entfernt',
        fr: 'à ~$min min',
        it: 'a ~$min min',
      );
  String get driverDetails => _t(
        en: 'Driver details',
        uk: 'Деталі водія',
        es: 'Detalles del conductor',
        de: 'Fahrerdetails',
        fr: 'Détails du conducteur',
        it: 'Dettagli conducente',
      );
  String walkShort(String dist) => _t(
        en: '$dist walk',
        uk: '$dist пішки',
        es: '$dist a pie',
        de: '$dist Fußweg',
        fr: '$dist à pied',
        it: '$dist a piedi',
      );

  // ─── Driver pre-accept disclosure ────────────────────────────────────────
  String get pickupPointLabel => _t(
        en: 'Pick-up',
        uk: 'Посадка',
        es: 'Recogida',
        de: 'Abholung',
        fr: 'Prise en charge',
        it: 'Salita',
      );
  String get dropoffPointLabel => _t(
        en: 'Drop-off',
        uk: 'Висадка',
        es: 'Bajada',
        de: 'Ausstieg',
        fr: 'Dépose',
        it: 'Discesa',
      );
  String ridesWithYou(String dist) => _t(
        en: 'Rides $dist with you',
        uk: 'Їде з вами $dist',
        es: 'Viaja $dist contigo',
        de: 'Fährt $dist mit dir',
        fr: 'Roule $dist avec vous',
        it: 'Viaggia $dist con te',
      );
  String get zeroDetourLabel => _t(
        en: 'No detour — both stops are on your route',
        uk: 'Без об\'їзду — обидві зупинки на вашому маршруті',
        es: 'Sin desvío: ambas paradas están en tu ruta',
        de: 'Kein Umweg — beide Stopps liegen auf deiner Route',
        fr: 'Aucun détour — les deux arrêts sont sur votre itinéraire',
        it: 'Nessuna deviazione: entrambe le fermate sono sul tuo percorso',
      );
  String get noDestinationDeclared => _t(
        en: 'No destination set yet',
        uk: 'Пункт призначення ще не вказано',
        es: 'Aún sin destino',
        de: 'Noch kein Ziel angegeben',
        fr: 'Aucune destination définie',
        it: 'Nessuna destinazione impostata',
      );

  /// Middle-tier walk copy (100-300 m): names the flag the user is walking to,
  /// because at this distance it is already visible on the map.
  String walkToPickupShort(String dist) => _t(
        en: 'Walk $dist to the pickup flag',
        uk: 'Пройдіть $dist до позначки посадки',
        es: 'Camina $dist hasta el marcador de recogida',
        de: 'Gehe $dist zur Abholmarkierung',
        fr: 'Marchez $dist jusqu\'au repère de prise en charge',
        it: 'Cammina $dist fino al segnaposto di partenza',
      );
  String walkApproxMinutes(int min) => _t(
        en: 'about $min min',
        uk: 'близько $min хв',
        es: 'unos $min min',
        de: 'etwa $min Min.',
        fr: 'environ $min min',
        it: 'circa $min min',
      );
  String get openWalkingDirections => _t(
        en: 'Open in walking directions',
        uk: 'Відкрити пішохідний маршрут',
        es: 'Abrir indicaciones a pie',
        de: 'Fußweg öffnen',
        fr: 'Itinéraire piéton',
        it: 'Apri indicazioni a piedi',
      );
  String get driverGoingYourWay => _t(
        en: 'Driver is going your way',
        uk: 'Водій їде у вашому напрямку',
        es: 'El conductor va en tu dirección',
        de: 'Fahrer ist auf deinem Weg',
        fr: 'Le conducteur va dans ta direction',
        it: 'Il conducente va nella tua direzione',
      );
  String get tellCodeToPassenger => _t(
        en: 'Tell this code to your passenger when you arrive',
        uk: 'Скажіть цей код пасажиру при зустрічі',
        es: 'Dile este código a tu pasajero al llegar',
        de: 'Nenne diesen Code deinem Fahrgast bei Ankunft',
        fr: 'Donne ce code à ton passager à l\'arrivée',
        it: 'Comunica questo codice al passeggero quando arrivi',
      );
  String get askDriverForCode => _t(
        en: 'Ask your driver for the pickup code',
        uk: 'Запитайте у водія код посадки',
        es: 'Pide al conductor el código de recogida',
        de: 'Frag deinen Fahrer nach dem Abholcode',
        fr: 'Demande le code à ton conducteur',
        it: 'Chiedi al conducente il codice di partenza',
      );
  String get copyCode => _t(
        en: 'Copy code',
        uk: 'Копіювати код',
        es: 'Copiar código',
        de: 'Code kopieren',
        fr: 'Copier le code',
        it: 'Copia codice',
      );
  String get codeCopied => _t(
        en: 'Code copied',
        uk: 'Код скопійовано',
        es: 'Código copiado',
        de: 'Code kopiert',
        fr: 'Code copié',
        it: 'Codice copiato',
      );

  // ─── Friendly error messages (Phase 1.4) ─────────────────────────────────
  String get errSessionExpired => _t(
        en: 'Your session expired — please sign in again',
        uk: 'Сеанс завершено — увійдіть знову',
        es: 'Tu sesión expiró — inicia sesión de nuevo',
        de: 'Sitzung abgelaufen — bitte erneut anmelden',
        fr: 'Session expirée — connecte-toi à nouveau',
        it: 'Sessione scaduta — accedi di nuovo',
      );
  String get errNotFound => _t(
        en: 'Not found',
        uk: 'Не знайдено',
        es: 'No encontrado',
        de: 'Nicht gefunden',
        fr: 'Introuvable',
        it: 'Non trovato',
      );
  String get errServer => _t(
        en: 'Server is having trouble — try again in a moment',
        uk: 'Сервер перевантажений — спробуйте за хвилину',
        es: 'El servidor tiene problemas — inténtalo en un momento',
        de: 'Server-Probleme — versuche es gleich erneut',
        fr: 'Le serveur a un problème — réessaie dans un moment',
        it: 'Il server ha problemi — riprova tra poco',
      );
  String get errOffline => _t(
        en: 'Check your connection',
        uk: 'Перевірте з\'єднання',
        es: 'Comprueba tu conexión',
        de: 'Verbindung prüfen',
        fr: 'Vérifie ta connexion',
        it: 'Controlla la connessione',
      );
  String get errGeneric => _t(
        en: 'Something went wrong',
        uk: 'Щось пішло не так',
        es: 'Algo salió mal',
        de: 'Etwas ist schiefgelaufen',
        fr: 'Quelque chose s\'est mal passé',
        it: 'Qualcosa è andato storto',
      );
  String get errTimeout => _t(
        en: 'Taking too long — try again',
        uk: 'Занадто довго — спробуйте знову',
        es: 'Está tardando demasiado — vuelve a intentarlo',
        de: 'Dauert zu lange — bitte erneut versuchen',
        fr: 'Trop long — réessaie',
        it: 'Sta impiegando troppo — riprova',
      );
  String get retry => _t(
        en: 'Retry',
        uk: 'Повторити',
        es: 'Reintentar',
        de: 'Erneut',
        fr: 'Réessayer',
        it: 'Riprova',
      );
  String get noInternet => _t(
        en: 'No internet',
        uk: 'Немає інтернету',
        es: 'Sin internet',
        de: 'Kein Internet',
        fr: 'Pas d\'internet',
        it: 'Nessuna connessione',
      );

  /// Shown when the app has repeatedly failed to send the user's position to
  /// the server. Matching keys off the last received fix, so a user in this
  /// state is invisible to the other side while everything else looks normal —
  /// worth telling them about explicitly.
  String get locationNotSyncing => _t(
        en: 'Location not syncing — you may be hidden',
        uk: 'Локація не синхронізується — вас можуть не бачити',
        es: 'Ubicación sin sincronizar: puede que no te vean',
        de: 'Standort wird nicht übertragen – du bist evtl. unsichtbar',
        fr: 'Position non synchronisée — vous pouvez être invisible',
        it: 'Posizione non sincronizzata: potresti non essere visibile',
      );
  String get reconnecting => _t(
        en: 'Reconnecting…',
        uk: 'Перепідключення…',
        es: 'Reconectando…',
        de: 'Verbindung wird wiederhergestellt…',
        fr: 'Reconnexion…',
        it: 'Riconnessione…',
      );
  String get myLocation => _t(
        en: 'My location',
        uk: 'Моє місцезнаходження',
        es: 'Mi ubicación',
        de: 'Mein Standort',
        fr: 'Ma position',
        it: 'La mia posizione',
      );
  String get walkToDestination => _t(
        en: 'Walk to destination',
        uk: 'Пішки до місця призначення',
        es: 'Caminata al destino',
        de: 'Fußweg zum Ziel',
        fr: 'Marche jusqu\'à destination',
        it: 'A piedi fino a destinazione',
      );
  String get walkToDestinationHint => _t(
        en: 'Driver keeps their route — you walk from the nearest drop-off.',
        uk: 'Водій їде своїм маршрутом — ви йдете від найближчої точки висадки.',
        es: 'El conductor mantiene su ruta: caminas desde la bajada más cercana.',
        de: 'Fahrer behält seine Route — du läufst ab dem nächsten Ausstieg.',
        fr: 'Le conducteur garde son trajet — tu marches depuis l\'arrêt le plus proche.',
        it: 'Il conducente mantiene il percorso: cammini dalla fermata più vicina.',
      );
  String walkEstimate(int minutes, int metres) => _t(
        en: '≈ $minutes min · $metres m',
        uk: '≈ $minutes хв · $metres м',
        es: '≈ $minutes min · $metres m',
        de: '≈ $minutes Min · $metres m',
        fr: '≈ $minutes min · $metres m',
        it: '≈ $minutes min · $metres m',
      );

  // ─── Pre-permission rationale (Phase 1.7) ────────────────────────────────
  String get permLocationTitle => _t(
        en: 'Find rides near you',
        uk: 'Знайдіть поїздки поруч',
        es: 'Encuentra viajes cerca',
        de: 'Fahrten in deiner Nähe finden',
        fr: 'Trouve des trajets près de toi',
        it: 'Trova passaggi vicino a te',
      );
  String get permLocationBody => _t(
        en: 'Sameway uses your location to match you with drivers heading your way. We only share your exact location with the matched driver — never with anyone else.',
        uk: 'Sameway використовує вашу геолокацію, щоб знайти водіїв, які їдуть у вашому напрямку. Точне місцезнаходження ми передаємо лише підібраному водію — більше нікому.',
        es: 'Sameway usa tu ubicación para emparejarte con conductores que van por tu camino. Solo compartimos tu ubicación exacta con el conductor emparejado — con nadie más.',
        de: 'Sameway nutzt deinen Standort, um dich mit Fahrern auf deinem Weg zu verbinden. Deinen genauen Standort teilen wir nur mit dem gematchten Fahrer — mit sonst niemandem.',
        fr: 'Sameway utilise ta position pour te mettre en relation avec des conducteurs sur ton trajet. Ta position exacte n\'est partagée qu\'avec le conducteur correspondant — personne d\'autre.',
        it: 'Sameway usa la tua posizione per abbinarti a conducenti che vanno nella tua direzione. La tua posizione esatta viene condivisa solo con il conducente abbinato — con nessun altro.',
      );
  String get permNotifTitle => _t(
        en: 'Stay in the loop',
        uk: 'Будьте в курсі',
        es: 'Mantente al tanto',
        de: 'Bleib auf dem Laufenden',
        fr: 'Reste informé',
        it: 'Resta aggiornato',
      );
  String get permNotifBody => _t(
        en: 'We\'ll only notify you about ride-related events: a driver accepting, your driver arriving, or new messages on a trip.',
        uk: 'Ми сповіщатимемо лише про події поїздки: коли водій приймає, прибуває, або надсилає повідомлення.',
        es: 'Solo te avisaremos de eventos del viaje: cuando un conductor acepte, llegue o envíe mensajes durante el trayecto.',
        de: 'Wir benachrichtigen dich nur über fahrtbezogene Ereignisse: Fahrer akzeptiert, Fahrer ist da oder neue Nachrichten während der Fahrt.',
        fr: 'Nous t\'enverrons des notifications uniquement pour les événements du trajet : un conducteur accepte, ton conducteur arrive, ou nouveaux messages.',
        it: 'Ti invieremo notifiche solo per gli eventi della corsa: conducente che accetta, conducente che arriva o nuovi messaggi durante il viaggio.',
      );
  String get permContinue => _t(
        en: 'Continue',
        uk: 'Продовжити',
        es: 'Continuar',
        de: 'Weiter',
        fr: 'Continuer',
        it: 'Continua',
      );
  String get permNotNow => _t(
        en: 'Not now',
        uk: 'Не зараз',
        es: 'Ahora no',
        de: 'Nicht jetzt',
        fr: 'Pas maintenant',
        it: 'Non ora',
      );

  // ─── Mid-ride safety check-in ────────────────────────────────────────────
  String get checkInTitle => _t(
        en: 'Everything OK?',
        uk: 'Все гаразд?',
        es: '¿Todo bien?',
        de: 'Alles in Ordnung?',
        fr: 'Tout va bien ?',
        it: 'Tutto bene?',
      );
  String checkInBody(String otherParty) => _t(
        en: "You and your $otherParty look like you're in different places. "
            'If the ride is over, no action is needed.',
        uk: 'Здається, ви та ваш $otherParty перебуваєте в різних місцях. '
            'Якщо поїздку завершено, нічого робити не потрібно.',
        es: 'Parece que tú y tu $otherParty estáis en lugares distintos. '
            'Si el viaje ha terminado, no hace falta hacer nada.',
        de: 'Du und dein $otherParty scheint an verschiedenen Orten zu sein. '
            'Wenn die Fahrt vorbei ist, musst du nichts tun.',
        fr: 'Vous et votre $otherParty semblez être à des endroits différents. '
            "Si le trajet est terminé, aucune action n'est nécessaire.",
        it: 'Tu e il tuo $otherParty sembrate trovarvi in luoghi diversi. '
            'Se il viaggio è finito, non serve fare nulla.',
      );
  String get checkInAllGood => _t(
        en: "Yes, I'm fine",
        uk: 'Так, усе добре',
        es: 'Sí, estoy bien',
        de: 'Ja, mir geht es gut',
        fr: 'Oui, tout va bien',
        it: 'Sì, sto bene',
      );
  String get checkInNeedHelp => _t(
        en: 'No, I need help',
        uk: 'Ні, мені потрібна допомога',
        es: 'No, necesito ayuda',
        de: 'Nein, ich brauche Hilfe',
        fr: "Non, j'ai besoin d'aide",
        it: 'No, ho bisogno di aiuto',
      );

  // ─── SOS (Phase 1.2) ─────────────────────────────────────────────────────
  String get sos => _t(
        en: 'SOS',
        uk: 'SOS',
        es: 'SOS',
        de: 'SOS',
        fr: 'SOS',
        it: 'SOS',
      );
  String get sosTitle => _t(
        en: 'Need help?',
        uk: 'Потрібна допомога?',
        es: '¿Necesitas ayuda?',
        de: 'Brauchst du Hilfe?',
        fr: 'Besoin d\'aide ?',
        it: 'Hai bisogno di aiuto?',
      );
  String get sosBody => _t(
        en: 'You can call local emergency services or share your trip details with someone you trust.',
        uk: 'Ви можете зателефонувати в екстрені служби або поділитися деталями поїздки з близькою людиною.',
        es: 'Puedes llamar a servicios de emergencia o compartir los detalles del viaje con alguien de confianza.',
        de: 'Du kannst den Notruf wählen oder deine Fahrtdaten mit einer Vertrauensperson teilen.',
        fr: 'Tu peux appeler les secours ou partager les détails de ton trajet avec quelqu\'un de confiance.',
        it: 'Puoi chiamare i servizi di emergenza o condividere i dettagli del viaggio con una persona di fiducia.',
      );
  String get sosCall => _t(
        en: 'Call emergency services',
        uk: 'Зателефонувати в екстрену службу',
        es: 'Llamar a emergencias',
        de: 'Notruf wählen',
        fr: 'Appeler les secours',
        it: 'Chiama emergenze',
      );
  String get sosShare => _t(
        en: 'Share trip with contact',
        uk: 'Поділитися поїздкою з контактом',
        es: 'Compartir viaje con contacto',
        de: 'Fahrt mit Kontakt teilen',
        fr: 'Partager le trajet avec un contact',
        it: 'Condividi viaggio con un contatto',
      );
  String sosShareBody(String mapsUrl, String? driverName, String? plate) {
    final who = driverName ?? '—';
    final p = plate ?? '—';
    return _t(
      en: 'I\'m in a Sameway ride. My location: $mapsUrl  Driver: $who · Plate: $p',
      uk: 'Я в поїздці Sameway. Моя локація: $mapsUrl  Водій: $who · Номер: $p',
      es: 'Estoy en un viaje de Sameway. Mi ubicación: $mapsUrl  Conductor: $who · Matrícula: $p',
      de: 'Ich bin auf einer Sameway-Fahrt. Mein Standort: $mapsUrl  Fahrer: $who · Kennzeichen: $p',
      fr: 'Je suis dans un trajet Sameway. Ma position : $mapsUrl  Conducteur : $who · Plaque : $p',
      it: 'Sono in una corsa Sameway. La mia posizione: $mapsUrl  Conducente: $who · Targa: $p',
    );
  }
  // ─── Profile photo (Phase 1.3) ───────────────────────────────────────────
  String get profilePhoto => _t(
        en: 'Profile photo',
        uk: 'Фото профілю',
        es: 'Foto de perfil',
        de: 'Profilfoto',
        fr: 'Photo de profil',
        it: 'Foto profilo',
      );
  String get choosePhoto => _t(
        en: 'Choose a photo',
        uk: 'Виберіть фото',
        es: 'Elegir una foto',
        de: 'Foto auswählen',
        fr: 'Choisir une photo',
        it: 'Scegli una foto',
      );
  String get takePhoto => _t(
        en: 'Take photo',
        uk: 'Зробити фото',
        es: 'Tomar foto',
        de: 'Foto aufnehmen',
        fr: 'Prendre une photo',
        it: 'Scatta foto',
      );
  String get fromGallery => _t(
        en: 'From gallery',
        uk: 'З галереї',
        es: 'De la galería',
        de: 'Aus Galerie',
        fr: 'Depuis la galerie',
        it: 'Dalla galleria',
      );
  String get removePhoto => _t(
        en: 'Remove photo',
        uk: 'Видалити фото',
        es: 'Quitar foto',
        de: 'Foto entfernen',
        fr: 'Supprimer la photo',
        it: 'Rimuovi foto',
      );
  String get photoUpdated => _t(
        en: 'Photo updated',
        uk: 'Фото оновлено',
        es: 'Foto actualizada',
        de: 'Foto aktualisiert',
        fr: 'Photo mise à jour',
        it: 'Foto aggiornata',
      );

  // ─── Profile completion (Phase 3.3) ──────────────────────────────────────
  String get bio => _t(
        en: 'Bio',
        uk: 'Біо',
        es: 'Biografía',
        de: 'Bio',
        fr: 'Bio',
        it: 'Bio',
      );
  String get bioHint => _t(
        en: 'A short line about you (160 char max)',
        uk: 'Короткий рядок про вас (макс. 160 символів)',
        es: 'Una línea corta sobre ti (máx 160 caracteres)',
        de: 'Eine kurze Zeile über dich (max. 160 Zeichen)',
        fr: 'Une courte phrase à votre sujet (160 caractères max)',
        it: 'Una breve riga su di te (max 160 caratteri)',
      );
  String get phone => _t(
        en: 'Phone',
        uk: 'Телефон',
        es: 'Teléfono',
        de: 'Telefon',
        fr: 'Téléphone',
        it: 'Telefono',
      );
  String get phoneHint => _t(
        en: '+1 555 0100',
        uk: '+380 67 000 0000',
        es: '+34 600 000 000',
        de: '+49 30 0000000',
        fr: '+33 6 00 00 00 00',
        it: '+39 333 0000000',
      );
  String get profileCompletion => _t(
        en: 'Profile completion',
        uk: 'Заповнення профілю',
        es: 'Perfil completado',
        de: 'Profilvollständigkeit',
        fr: 'Profil complété',
        it: 'Completamento profilo',
      );
  String get verifyEmail => _t(
        en: 'Verify email',
        uk: 'Підтвердити email',
        es: 'Verificar correo',
        de: 'E-Mail verifizieren',
        fr: 'Vérifier l\'e-mail',
        it: 'Verifica email',
      );
  String get emailVerified => _t(
        en: 'Email verified',
        uk: 'Email підтверджено',
        es: 'Correo verificado',
        de: 'E-Mail verifiziert',
        fr: 'E-mail vérifié',
        it: 'Email verificata',
      );
  String get verificationCodeSent => _t(
        en: 'Code sent to your email',
        uk: 'Код надіслано на ваш email',
        es: 'Código enviado a tu correo',
        de: 'Code an deine E-Mail gesendet',
        fr: 'Code envoyé à votre e-mail',
        it: 'Codice inviato alla tua email',
      );
  String get enterVerificationCode => _t(
        en: 'Enter the 6-digit code',
        uk: 'Введіть 6-значний код',
        es: 'Introduce el código de 6 dígitos',
        de: 'Gib den 6-stelligen Code ein',
        fr: 'Entrez le code à 6 chiffres',
        it: 'Inserisci il codice a 6 cifre',
      );
  String get verifyAction => _t(
        en: 'Verify',
        uk: 'Підтвердити',
        es: 'Verificar',
        de: 'Verifizieren',
        fr: 'Vérifier',
        it: 'Verifica',
      );
  String get resendCode => _t(
        en: 'Resend code',
        uk: 'Надіслати код знову',
        es: 'Reenviar código',
        de: 'Code erneut senden',
        fr: 'Renvoyer le code',
        it: 'Reinvia codice',
      );
  String get profileUpdated => _t(
        en: 'Profile updated',
        uk: 'Профіль оновлено',
        es: 'Perfil actualizado',
        de: 'Profil aktualisiert',
        fr: 'Profil mis à jour',
        it: 'Profilo aggiornato',
      );

  // ─── Accessibility tooltips (Phase 3.5) ─────────────────────────────────
  String get back => _t(
        en: 'Back',
        uk: 'Назад',
        es: 'Atrás',
        de: 'Zurück',
        fr: 'Retour',
        it: 'Indietro',
      );
  String get dismiss => _t(
        en: 'Dismiss',
        uk: 'Закрити',
        es: 'Cerrar',
        de: 'Schließen',
        fr: 'Fermer',
        it: 'Chiudi',
      );
  String get clear => _t(
        en: 'Clear',
        uk: 'Очистити',
        es: 'Borrar',
        de: 'Löschen',
        fr: 'Effacer',
        it: 'Cancella',
      );
  String get togglePasswordVisibility => _t(
        en: 'Show/hide password',
        uk: 'Показати/сховати пароль',
        es: 'Mostrar/ocultar contraseña',
        de: 'Passwort anzeigen/verbergen',
        fr: 'Afficher/masquer le mot de passe',
        it: 'Mostra/nascondi password',
      );
  // Semantics narrations for the offer / accepted ride cards. Read by
  // TalkBack / VoiceOver so the screen reader announces a single coherent
  // phrase instead of the underlying widget tree leaves.
  String semOffer(String driverName) => _t(
        en: 'Ride offer from $driverName',
        uk: 'Пропозиція поїздки від $driverName',
        es: 'Oferta de viaje de $driverName',
        de: 'Fahrtangebot von $driverName',
        fr: 'Offre de trajet de $driverName',
        it: 'Offerta di viaggio da $driverName',
      );
  String semAccepted(String driverName) => _t(
        en: 'Ride accepted, driver $driverName is en route',
        uk: 'Поїздку прийнято, водій $driverName їде до вас',
        es: 'Viaje aceptado, el conductor $driverName está en camino',
        de: 'Fahrt angenommen, Fahrer $driverName ist unterwegs',
        fr: 'Trajet accepté, le conducteur $driverName est en route',
        it: 'Viaggio accettato, l\'autista $driverName sta arrivando',
      );
  String semInRide(String driverName) => _t(
        en: 'In ride with $driverName',
        uk: 'У поїздці з $driverName',
        es: 'En viaje con $driverName',
        de: 'In Fahrt mit $driverName',
        fr: 'En trajet avec $driverName',
        it: 'In viaggio con $driverName',
      );

  // ─── Bug reporting (Section C) ───────────────────────────────────────────
  String get reportABug => _t(
        en: 'Report a bug',
        uk: 'Повідомити про помилку',
        es: 'Reportar un error',
        de: 'Fehler melden',
        fr: 'Signaler un bug',
        it: 'Segnala un bug',
      );
  String get bugReportTitle => _t(
        en: 'What went wrong?',
        uk: 'Що пішло не так?',
        es: '¿Qué pasó?',
        de: 'Was lief schief?',
        fr: 'Que s\'est-il passé ?',
        it: 'Cosa è andato storto?',
      );
  String get bugReportDescription => _t(
        en: 'Describe what you were doing and what happened',
        uk: 'Опишіть, що ви робили та що сталося',
        es: 'Describe qué hacías y qué pasó',
        de: 'Beschreibe, was du gemacht hast und was passiert ist',
        fr: 'Décris ce que tu faisais et ce qui s\'est passé',
        it: 'Descrivi cosa stavi facendo e cosa è successo',
      );
  String get bugReportSubmit => _t(
        en: 'Send report',
        uk: 'Надіслати',
        es: 'Enviar reporte',
        de: 'Bericht senden',
        fr: 'Envoyer le rapport',
        it: 'Invia segnalazione',
      );
  String get bugReportThanks => _t(
        en: 'Thanks — we\'ll take a look',
        uk: 'Дякуємо — ми перевіримо',
        es: 'Gracias — lo revisaremos',
        de: 'Danke — wir schauen es uns an',
        fr: 'Merci — nous allons regarder',
        it: 'Grazie — daremo un\'occhiata',
      );

  // ─── Onboarding gate (Section D) ─────────────────────────────────────────
  String get showTutorialAgain => _t(
        en: 'Show tutorial again',
        uk: 'Показати посібник знову',
        es: 'Volver a ver el tutorial',
        de: 'Tutorial erneut anzeigen',
        fr: 'Revoir le tutoriel',
        it: 'Mostra di nuovo il tutorial',
      );
  String get onboardTitle4 => _t(
        en: 'Pickup code.',
        uk: 'Код посадки.',
        es: 'Código de recogida.',
        de: 'Abholcode.',
        fr: 'Code de prise en charge.',
        it: 'Codice di partenza.',
      );
  String get onboardSubtitle4 => _t(
        en: 'A shared 4-digit code confirms you and the driver have actually met.',
        uk: 'Спільний 4-значний код підтверджує, що ви з водієм зустрілися.',
        es: 'Un código compartido de 4 dígitos confirma que tú y el conductor se han encontrado.',
        de: 'Ein gemeinsamer 4-stelliger Code bestätigt, dass ihr euch wirklich getroffen habt.',
        fr: 'Un code à 4 chiffres partagé confirme que vous vous êtes bien retrouvés.',
        it: 'Un codice condiviso a 4 cifre conferma che voi e il conducente vi siete incontrati.',
      );

  // ─── Forgot password (Section E) ─────────────────────────────────────────
  String get forgotPassword => _t(
        en: 'Forgot password?',
        uk: 'Забули пароль?',
        es: '¿Olvidaste tu contraseña?',
        de: 'Passwort vergessen?',
        fr: 'Mot de passe oublié ?',
        it: 'Password dimenticata?',
      );
  String get forgotPasswordHint => _t(
        en: 'Enter the email on your account — we\'ll send a 6-digit code.',
        uk: 'Введіть email вашого акаунта — ми надішлемо 6-значний код.',
        es: 'Introduce el correo de tu cuenta — te enviaremos un código de 6 dígitos.',
        de: 'Gib die E-Mail deines Kontos ein — wir senden einen 6-stelligen Code.',
        fr: 'Entre l\'e-mail de ton compte — nous t\'enverrons un code à 6 chiffres.',
        it: 'Inserisci l\'e-mail del tuo account — invieremo un codice di 6 cifre.',
      );
  String get resetCodeHint => _t(
        en: '6-digit code',
        uk: '6-значний код',
        es: 'Código de 6 dígitos',
        de: '6-stelliger Code',
        fr: 'Code à 6 chiffres',
        it: 'Codice di 6 cifre',
      );
  String get newPasswordHint => _t(
        en: 'New password',
        uk: 'Новий пароль',
        es: 'Nueva contraseña',
        de: 'Neues Passwort',
        fr: 'Nouveau mot de passe',
        it: 'Nuova password',
      );
  String get resetSubmit => _t(
        en: 'Reset password',
        uk: 'Скинути пароль',
        es: 'Restablecer contraseña',
        de: 'Passwort zurücksetzen',
        fr: 'Réinitialiser',
        it: 'Reimposta password',
      );
  String get resetSuccess => _t(
        en: 'Password reset — you\'re signed in.',
        uk: 'Пароль скинуто — ви увійшли.',
        es: 'Contraseña restablecida — sesión iniciada.',
        de: 'Passwort zurückgesetzt — du bist angemeldet.',
        fr: 'Mot de passe réinitialisé — tu es connecté.',
        it: 'Password reimpostata — sei connesso.',
      );
  String get resetCodeSent => _t(
        en: 'If an account exists for that email, a code was sent.',
        uk: 'Якщо для цього email існує акаунт, код було надіслано.',
        es: 'Si existe una cuenta para ese correo, se envió un código.',
        de: 'Falls ein Konto für diese E-Mail existiert, wurde ein Code gesendet.',
        fr: 'Si un compte existe pour cet e-mail, un code a été envoyé.',
        it: 'Se esiste un account per quell\'e-mail, è stato inviato un codice.',
      );
  String get invalidCode => _t(
        en: 'Invalid or expired code',
        uk: 'Невірний або прострочений код',
        es: 'Código no válido o expirado',
        de: 'Ungültiger oder abgelaufener Code',
        fr: 'Code invalide ou expiré',
        it: 'Codice non valido o scaduto',
      );

  // ─── Localized toasts (Section B3 hardcoded-English conversion) ──────────
  String get rideRequestSent => _t(
        en: 'Ride request sent!',
        uk: 'Запит на поїздку надіслано!',
        es: '¡Solicitud de viaje enviada!',
        de: 'Fahrtanfrage gesendet!',
        fr: 'Demande de trajet envoyée !',
        it: 'Richiesta di passaggio inviata!',
      );
  String get noCarInfo => _t(
        en: 'No car info',
        uk: 'Немає інформації про авто',
        es: 'Sin info del coche',
        de: 'Keine Fahrzeuginfo',
        fr: 'Aucune info véhicule',
        it: 'Nessuna info auto',
      );
  String get passengerAcceptedRide => _t(
        en: 'A passenger accepted your ride offer!',
        uk: 'Пасажир прийняв вашу пропозицію!',
        es: '¡Un pasajero aceptó tu oferta!',
        de: 'Ein Fahrgast hat dein Fahrtangebot angenommen!',
        fr: 'Un passager a accepté ton offre !',
        it: 'Un passeggero ha accettato la tua offerta!',
      );
  String passengerSentRequest(String name) => _t(
        en: '$name sent you a ride request',
        uk: '$name надіслав запит на поїздку',
        es: '$name te envió una solicitud',
        de: '$name hat dir eine Fahrtanfrage gesendet',
        fr: '$name t\'a envoyé une demande',
        it: '$name ti ha inviato una richiesta',
      );
  String savedCO2(String kg) => _t(
        en: 'You saved $kg kg CO₂',
        uk: 'Ви заощадили $kg кг CO₂',
        es: 'Has ahorrado $kg kg de CO₂',
        de: 'Du hast $kg kg CO₂ gespart',
        fr: 'Tu as économisé $kg kg de CO₂',
        it: 'Hai risparmiato $kg kg di CO₂',
      );

  // ─── Role switch dialog (Section B3) ─────────────────────────────────────
  String get endRouteAndSwitch => _t(
        en: 'End route & switch',
        uk: 'Завершити маршрут і переключити',
        es: 'Terminar ruta y cambiar',
        de: 'Route beenden & wechseln',
        fr: 'Terminer le trajet et changer',
        it: 'Termina tragitto e cambia',
      );
  String get cancelRequestsAndSwitch => _t(
        en: 'Cancel requests & switch',
        uk: 'Скасувати запити і переключити',
        es: 'Cancelar solicitudes y cambiar',
        de: 'Anfragen abbrechen & wechseln',
        fr: 'Annuler les demandes et changer',
        it: 'Annulla richieste e cambia',
      );
  String get endDriverRouteQ => _t(
        en: 'End your driver route?',
        uk: 'Завершити маршрут водія?',
        es: '¿Terminar tu ruta de conductor?',
        de: 'Fahrtroute beenden?',
        fr: 'Terminer ton trajet conducteur ?',
        it: 'Terminare il tragitto da conducente?',
      );
  String get cancelPassengerSearchQ => _t(
        en: 'Cancel passenger search?',
        uk: 'Скасувати пошук пасажира?',
        es: '¿Cancelar búsqueda de pasajero?',
        de: 'Fahrgastsuche abbrechen?',
        fr: 'Annuler la recherche de passager ?',
        it: 'Annullare la ricerca passeggero?',
      );
  String get stayAsDriver => _t(
        en: 'Stay as driver',
        uk: 'Залишитися водієм',
        es: 'Seguir como conductor',
        de: 'Fahrer bleiben',
        fr: 'Rester conducteur',
        it: 'Resta conducente',
      );
  String get stayAsPassenger => _t(
        en: 'Stay as passenger',
        uk: 'Залишитися пасажиром',
        es: 'Seguir como pasajero',
        de: 'Fahrgast bleiben',
        fr: 'Rester passager',
        it: 'Resta passeggero',
      );

  // ─── Bottom navigation bars ───────────────────────────────────────────────
  String get navRoute => _t(
        en: 'Route',
        uk: 'Маршрут',
        es: 'Ruta',
        de: 'Route',
        fr: 'Trajet',
        it: 'Percorso',
      );
  String get navPlan => _t(
        en: 'Plan',
        uk: 'План',
        es: 'Plan',
        de: 'Planen',
        fr: 'Planifier',
        it: 'Pianifica',
      );
  String get navFind => _t(
        en: 'Find',
        uk: 'Пошук',
        es: 'Buscar',
        de: 'Suchen',
        fr: 'Chercher',
        it: 'Cerca',
      );
  String get navChat => _t(
        en: 'Chat',
        uk: 'Чат',
        es: 'Chat',
        de: 'Chat',
        fr: 'Chat',
        it: 'Chat',
      );
  String get navFindTrips => _t(
        en: 'Find Trips',
        uk: 'Поїздки',
        es: 'Viajes',
        de: 'Fahrten',
        fr: 'Trajets',
        it: 'Viaggi',
      );
  String get navOffers => _t(
        en: 'Offers',
        uk: 'Акції',
        es: 'Ofertas',
        de: 'Angebote',
        fr: 'Offres',
        it: 'Offerte',
      );
  String get navReportBug => _t(
        en: 'Report bug',
        uk: 'Звіт про баг',
        es: 'Reportar fallo',
        de: 'Fehler melden',
        fr: 'Signaler un bug',
        it: 'Segnala bug',
      );
  String get navAccount => _t(
        en: 'Account',
        uk: 'Акаунт',
        es: 'Cuenta',
        de: 'Konto',
        fr: 'Compte',
        it: 'Account',
      );

  // ─── Driver: set-route validation ────────────────────────────────────────
  String get errEnterDestination => _t(
        en: 'Enter a destination',
        uk: 'Введіть пункт призначення',
        es: 'Introduce un destino',
        de: 'Gib ein Ziel ein',
        fr: 'Saisissez une destination',
        it: 'Inserisci una destinazione',
      );
  String get errAddressNotFound => _t(
        en: 'Address not found',
        uk: 'Адресу не знайдено',
        es: 'Dirección no encontrada',
        de: 'Adresse nicht gefunden',
        fr: 'Adresse introuvable',
        it: 'Indirizzo non trovato',
      );

  // ─── Driver: bottom panel ────────────────────────────────────────────────
  String get endRouteQ => _t(
        en: 'End route?',
        uk: 'Завершити маршрут?',
        es: '¿Terminar la ruta?',
        de: 'Route beenden?',
        fr: 'Terminer le trajet ?',
        it: 'Terminare il percorso?',
      );
  String get endRouteBody => _t(
        en: 'Every passenger currently on board will be dropped off '
            "and you'll stop receiving new matches.",
        uk: 'Усі пасажири, що зараз у машині, будуть висаджені, '
            'і ви більше не отримуватимете нові збіги.',
        es: 'Todos los pasajeros a bordo serán dejados y dejarás de '
            'recibir nuevas coincidencias.',
        de: 'Alle Fahrgäste an Bord werden abgesetzt und du erhältst '
            'keine neuen Treffer mehr.',
        fr: 'Tous les passagers à bord seront déposés et vous ne '
            'recevrez plus de nouvelles correspondances.',
        it: 'Tutti i passeggeri a bordo verranno fatti scendere e non '
            'riceverai più nuove corrispondenze.',
      );
  String get endRouteAction => _t(
        en: 'End route',
        uk: 'Завершити маршрут',
        es: 'Terminar ruta',
        de: 'Route beenden',
        fr: 'Terminer le trajet',
        it: 'Termina percorso',
      );
  String rideRequestsCount(String n) => _t(
        en: 'Ride requests ($n)',
        uk: 'Запити на поїздку ($n)',
        es: 'Solicitudes de viaje ($n)',
        de: 'Fahrtanfragen ($n)',
        fr: 'Demandes de trajet ($n)',
        it: 'Richieste di corsa ($n)',
      );
  String dropOffName(String name) => _t(
        en: 'Drop off $name',
        uk: 'Висадити $name',
        es: 'Dejar a $name',
        de: '$name absetzen',
        fr: 'Déposer $name',
        it: 'Fai scendere $name',
      );
  String get cancelRide => _t(
        en: 'Cancel ride',
        uk: 'Скасувати поїздку',
        es: 'Cancelar viaje',
        de: 'Fahrt stornieren',
        fr: 'Annuler le trajet',
        it: 'Annulla corsa',
      );
  String get waitingForYourLocation => _t(
        en: 'Waiting for your location…',
        uk: 'Очікуємо вашу геолокацію…',
        es: 'Esperando tu ubicación…',
        de: 'Warte auf deinen Standort…',
        fr: 'En attente de votre position…',
        it: 'In attesa della tua posizione…',
      );
  String get waitingForPassengerLocation => _t(
        en: 'Waiting for passenger location…',
        uk: 'Очікуємо геолокацію пасажира…',
        es: 'Esperando la ubicación del pasajero…',
        de: 'Warte auf den Standort des Fahrgasts…',
        fr: 'En attente de la position du passager…',
        it: 'In attesa della posizione del passeggero…',
      );
  String kmBetweenYou(String km) => _t(
        en: '$km km between you',
        uk: '$km км між вами',
        es: '$km km entre vosotros',
        de: '$km km zwischen euch',
        fr: '$km km entre vous',
        it: '$km km tra di voi',
      );
  String routeSummary(String km, int count) => _t(
        en: '$km km · $count ${count == 1 ? 'passenger' : 'passengers'} notified',
        uk: '$km км · сповіщено пасажирів: $count',
        es: '$km km · $count ${count == 1 ? 'pasajero notificado' : 'pasajeros notificados'}',
        de: '$km km · $count ${count == 1 ? 'Fahrgast' : 'Fahrgäste'} benachrichtigt',
        fr: '$km km · $count ${count == 1 ? 'passager notifié' : 'passagers notifiés'}',
        it: '$km km · $count ${count == 1 ? 'passeggero avvisato' : 'passeggeri avvisati'}',
      );
  String pendingOffersCount(int count) => _t(
        en: '$count ${count == 1 ? 'offer' : 'offers'} awaiting reply',
        uk: 'очікують відповіді: $count',
        es: '$count ${count == 1 ? 'oferta pendiente' : 'ofertas pendientes'} de respuesta',
        de: '$count ${count == 1 ? 'Angebot wartet' : 'Angebote warten'} auf Antwort',
        fr: '$count ${count == 1 ? 'offre en attente' : 'offres en attente'} de réponse',
        it: '$count ${count == 1 ? 'offerta in attesa' : 'offerte in attesa'} di risposta',
      );

  /// Localized label for a ride_request status code from the backend.
  String rideStatusLabel(String status) => switch (status) {
        'pending' => _t(
            en: 'pending',
            uk: 'очікує',
            es: 'pendiente',
            de: 'ausstehend',
            fr: 'en attente',
            it: 'in attesa'),
        'accepted' => _t(
            en: 'accepted',
            uk: 'прийнято',
            es: 'aceptado',
            de: 'angenommen',
            fr: 'accepté',
            it: 'accettato'),
        'in_progress' => _t(
            en: 'in ride',
            uk: 'у поїздці',
            es: 'en viaje',
            de: 'unterwegs',
            fr: 'en cours',
            it: 'in corsa'),
        'declined' => _t(
            en: 'declined',
            uk: 'відхилено',
            es: 'rechazado',
            de: 'abgelehnt',
            fr: 'refusé',
            it: 'rifiutato'),
        'done' => _t(
            en: 'done',
            uk: 'завершено',
            es: 'completado',
            de: 'abgeschlossen',
            fr: 'terminé',
            it: 'completata'),
        'cancelled' => _t(
            en: 'cancelled',
            uk: 'скасовано',
            es: 'cancelado',
            de: 'storniert',
            fr: 'annulé',
            it: 'annullata'),
        'offered' => _t(
            en: 'offered',
            uk: 'запропоновано',
            es: 'ofrecido',
            de: 'angeboten',
            fr: 'proposé',
            it: 'proposta'),
        _ => status,
      };

  // ─── Passenger: home screen ──────────────────────────────────────────────
  String get whereDoYouWantToGo => _t(
        en: 'Where do you want to go?',
        uk: 'Куди ви хочете поїхати?',
        es: '¿A dónde quieres ir?',
        de: 'Wohin möchtest du?',
        fr: 'Où voulez-vous aller ?',
        it: 'Dove vuoi andare?',
      );
  String get waitingForDriver => _t(
        en: 'Waiting for driver…',
        uk: 'Очікуємо водія…',
        es: 'Esperando al conductor…',
        de: 'Warte auf den Fahrer…',
        fr: 'En attente du conducteur…',
        it: 'In attesa del conducente…',
      );
  String get driverAccepted => _t(
        en: 'Driver accepted',
        uk: 'Водій прийняв',
        es: 'El conductor aceptó',
        de: 'Fahrer hat angenommen',
        fr: 'Le conducteur a accepté',
        it: 'Il conducente ha accettato',
      );
  String walkPill(String m, String min) => _t(
        en: 'Walk $m m · $min min',
        uk: 'Пішки $m м · $min хв',
        es: 'A pie $m m · $min min',
        de: 'Zu Fuß $m m · $min Min.',
        fr: 'À pied $m m · $min min',
        it: 'A piedi $m m · $min min',
      );
  String driverInMin(String min) => _t(
        en: 'Driver in $min min',
        uk: 'Водій за $min хв',
        es: 'Conductor en $min min',
        de: 'Fahrer in $min Min.',
        fr: 'Conducteur dans $min min',
        it: 'Conducente tra $min min',
      );
  String get mapStyleStandard => _t(
        en: 'Standard',
        uk: 'Стандартна',
        es: 'Estándar',
        de: 'Standard',
        fr: 'Standard',
        it: 'Standard',
      );
  String get mapStyleSatellite => _t(
        en: 'Satellite',
        uk: 'Супутник',
        es: 'Satélite',
        de: 'Satellit',
        fr: 'Satellite',
        it: 'Satellite',
      );
  String get mapStyleDark => _t(
        en: 'Dark',
        uk: 'Темна',
        es: 'Oscuro',
        de: 'Dunkel',
        fr: 'Sombre',
        it: 'Scuro',
      );
  String seatsCorridorSummary(String seats, String km) => _t(
        en: 'Seats: $seats · corridor $km km',
        uk: 'Місць: $seats · коридор $km км',
        es: 'Asientos: $seats · corredor de $km km',
        de: 'Sitze: $seats · Korridor $km km',
        fr: 'Places : $seats · corridor $km km',
        it: 'Posti: $seats · corridoio $km km',
      );
  String get carLabel => _t(
        en: 'Car',
        uk: 'Автомобіль',
        es: 'Coche',
        de: 'Auto',
        fr: 'Voiture',
        it: 'Auto',
      );
  String get plateLabel => _t(
        en: 'Plate',
        uk: 'Номерний знак',
        es: 'Matrícula',
        de: 'Kennzeichen',
        fr: 'Plaque',
        it: 'Targa',
      );
  String get requestThisRide => _t(
        en: 'Request this ride',
        uk: 'Запросити цю поїздку',
        es: 'Solicitar este viaje',
        de: 'Diese Fahrt anfragen',
        fr: 'Demander ce trajet',
        it: 'Richiedi questa corsa',
      );

  // ─── Role switch: live-state reasons ─────────────────────────────────────
  String get reasonActiveDriverRoute => _t(
        en: 'an active driver route',
        uk: 'активний маршрут водія',
        es: 'una ruta de conductor activa',
        de: 'eine aktive Fahrtroute',
        fr: 'un trajet conducteur actif',
        it: 'un percorso conducente attivo',
      );
  String get reasonAcceptedPassengerRide => _t(
        en: 'an accepted passenger ride',
        uk: 'підтверджену поїздку з пасажиром',
        es: 'un viaje de pasajero aceptado',
        de: 'eine angenommene Fahrgast-Fahrt',
        fr: 'une course passager acceptée',
        it: 'una corsa passeggero accettata',
      );
  String get reasonAcceptedDriverRide => _t(
        en: 'an accepted driver ride',
        uk: 'підтверджену поїздку з водієм',
        es: 'un viaje con conductor aceptado',
        de: 'eine angenommene Fahrt',
        fr: 'une course acceptée',
        it: 'una corsa accettata',
      );
  String get reasonPendingRideRequests => _t(
        en: 'pending ride requests',
        uk: 'запити на поїздку в очікуванні',
        es: 'solicitudes de viaje pendientes',
        de: 'ausstehende Fahrtanfragen',
        fr: 'des demandes de trajet en attente',
        it: 'richieste di corsa in sospeso',
      );
  String get reasonActiveDestinationSearch => _t(
        en: 'an active destination search',
        uk: 'активний пошук поїздки',
        es: 'una búsqueda de destino activa',
        de: 'eine aktive Zielsuche',
        fr: 'une recherche de destination active',
        it: 'una ricerca destinazione attiva',
      );
  String switchWillEnd(String reason) => _t(
        en: 'You have $reason. Switching will end it and notify the other party.',
        uk: 'У вас є $reason. Перемикання завершить це та сповістить іншу сторону.',
        es: 'Tienes $reason. Cambiar lo terminará y avisará a la otra parte.',
        de: 'Du hast $reason. Beim Wechsel wird sie beendet und die Gegenseite benachrichtigt.',
        fr: "Vous avez $reason. Le changement y mettra fin et en informera l'autre partie.",
        it: "Hai $reason. Il cambio la terminerà e avviserà l'altra parte.",
      );

  // ─── Account: email verification ─────────────────────────────────────────
  String get enterSixDigitCode => _t(
        en: 'Enter the 6-digit code',
        uk: 'Введіть 6-значний код',
        es: 'Introduce el código de 6 dígitos',
        de: 'Gib den 6-stelligen Code ein',
        fr: 'Saisissez le code à 6 chiffres',
        it: 'Inserisci il codice a 6 cifre',
      );

  // ─── Known backend error messages (kept in sync with the Go backend's
  //     `error` strings; mapped in core/error_handling.dart) ────────────────
  String get errDriverUnavailable => _t(
        en: 'This driver is no longer available',
        uk: 'Цей водій уже недоступний',
        es: 'Este conductor ya no está disponible',
        de: 'Dieser Fahrer ist nicht mehr verfügbar',
        fr: "Ce conducteur n'est plus disponible",
        it: 'Questo conducente non è più disponibile',
      );
  String get errTooFarFromRoute => _t(
        en: "You're too far from the driver's route",
        uk: 'Ви занадто далеко від маршруту водія',
        es: 'Estás demasiado lejos de la ruta del conductor',
        de: 'Du bist zu weit von der Route des Fahrers entfernt',
        fr: "Vous êtes trop loin de l'itinéraire du conducteur",
        it: 'Sei troppo lontano dal percorso del conducente',
      );
  String get errDriverPassedYou => _t(
        en: 'The driver has already passed your pickup point',
        uk: 'Водій уже проїхав повз вашу точку посадки',
        es: 'El conductor ya pasó tu punto de recogida',
        de: 'Der Fahrer ist bereits an deinem Abholpunkt vorbei',
        fr: 'Le conducteur a déjà dépassé votre point de rencontre',
        it: 'Il conducente ha già superato il tuo punto di ritiro',
      );
  String get errDriverPositionStale => _t(
        en: "Driver's position is not up to date — try again shortly",
        uk: 'Позиція водія не оновлена — спробуйте трохи пізніше',
        es: 'La posición del conductor no está actualizada; inténtalo de nuevo en breve',
        de: 'Die Position des Fahrers ist nicht aktuell – versuche es gleich noch einmal',
        fr: "La position du conducteur n'est pas à jour — réessayez dans un instant",
        it: 'La posizione del conducente non è aggiornata: riprova tra poco',
      );
  String get errUpdateLocationFirst => _t(
        en: 'Update your location first',
        uk: 'Спочатку оновіть свою геолокацію',
        es: 'Primero actualiza tu ubicación',
        de: 'Aktualisiere zuerst deinen Standort',
        fr: "Mettez d'abord votre position à jour",
        it: 'Aggiorna prima la tua posizione',
      );
  String get errOfferGone => _t(
        en: 'This offer is no longer available',
        uk: 'Ця пропозиція вже недоступна',
        es: 'Esta oferta ya no está disponible',
        de: 'Dieses Angebot ist nicht mehr verfügbar',
        fr: "Cette offre n'est plus disponible",
        it: 'Questa offerta non è più disponibile',
      );
  String get errRideFull => _t(
        en: 'This ride is already full',
        uk: 'У цій поїздці вже немає місць',
        es: 'Este viaje ya está completo',
        de: 'Diese Fahrt ist bereits voll',
        fr: 'Ce trajet est déjà complet',
        it: 'Questa corsa è già al completo',
      );
  String get errWrongCode => _t(
        en: 'Wrong code — ask the driver again',
        uk: 'Неправильний код — перепитайте водія',
        es: 'Código incorrecto: vuelve a preguntar al conductor',
        de: 'Falscher Code – frag den Fahrer noch einmal',
        fr: 'Code incorrect — redemandez au conducteur',
        it: 'Codice errato: richiedi di nuovo al conducente',
      );
  String get errRideNotAccepted => _t(
        en: 'The ride is not in the accepted state',
        uk: 'Поїздка не в статусі «прийнято»',
        es: 'El viaje no está en estado aceptado',
        de: 'Die Fahrt ist nicht im Status „angenommen“',
        fr: "Le trajet n'est pas à l'état accepté",
        it: 'La corsa non è nello stato accettato',
      );
  String get errInvalidCredentials => _t(
        en: 'Wrong email or password',
        uk: 'Неправильна електронна пошта або пароль',
        es: 'Correo o contraseña incorrectos',
        de: 'Falsche E-Mail oder falsches Passwort',
        fr: 'E-mail ou mot de passe incorrect',
        it: 'Email o password errati',
      );
  String get errEmailTaken => _t(
        en: 'This email is already registered',
        uk: 'Ця електронна пошта вже зареєстрована',
        es: 'Este correo ya está registrado',
        de: 'Diese E-Mail ist bereits registriert',
        fr: 'Cet e-mail est déjà enregistré',
        it: 'Questa email è già registrata',
      );
  String get errCodeInvalidOrExpired => _t(
        en: 'Invalid or expired code',
        uk: 'Неправильний або прострочений код',
        es: 'Código no válido o caducado',
        de: 'Ungültiger oder abgelaufener Code',
        fr: 'Code invalide ou expiré',
        it: 'Codice non valido o scaduto',
      );
  String get errCurrentPasswordWrong => _t(
        en: 'Current password is incorrect',
        uk: 'Поточний пароль неправильний',
        es: 'La contraseña actual es incorrecta',
        de: 'Das aktuelle Passwort ist falsch',
        fr: 'Le mot de passe actuel est incorrect',
        it: 'La password attuale non è corretta',
      );

  // ─── Background location (driver) ────────────────────────────────────────
  String get backgroundLocationUnavailable => _t(
        en: "Background location couldn't start. Keep Sameway open on screen while driving, or passengers won't find you.",
        uk: 'Не вдалося запустити фонову геолокацію. Тримайте Sameway відкритим на екрані під час руху, інакше пасажири вас не знайдуть.',
        es: 'No se pudo iniciar la ubicación en segundo plano. Mantén Sameway abierto en pantalla mientras conduces o los pasajeros no te encontrarán.',
        de: 'Standort im Hintergrund konnte nicht gestartet werden. Lass Sameway während der Fahrt auf dem Bildschirm geöffnet, sonst finden dich Fahrgäste nicht.',
        fr: "Impossible de lancer la localisation en arrière-plan. Garde Sameway ouvert à l'écran pendant que tu conduis, sinon les passagers ne te trouveront pas.",
        it: 'Impossibile avviare la posizione in background. Tieni Sameway aperto sullo schermo mentre guidi, altrimenti i passeggeri non ti troveranno.',
      );

  // ─── Legal: age + terms consent ──────────────────────────────────────────
  String get ageConfirmLabel => _t(
        en: 'I confirm I am 18 or older',
        uk: 'Підтверджую, що мені виповнилося 18 років',
        es: 'Confirmo que tengo 18 años o más',
        de: 'Ich bestätige, dass ich mindestens 18 Jahre alt bin',
        fr: "Je confirme avoir 18 ans ou plus",
        it: 'Confermo di avere almeno 18 anni',
      );
  String get acceptTermsLabel => _t(
        en: 'I accept the Terms of Service and the Privacy Policy',
        uk: 'Я приймаю Умови використання та Політику конфіденційності',
        es: 'Acepto los Términos del servicio y la Política de privacidad',
        de: 'Ich akzeptiere die Nutzungsbedingungen und die Datenschutzerklärung',
        fr: "J'accepte les Conditions d'utilisation et la Politique de confidentialité",
        it: "Accetto i Termini di servizio e l'Informativa sulla privacy",
      );
  String get termsOfService => _t(
        en: 'Terms of Service',
        uk: 'Умови використання',
        es: 'Términos del servicio',
        de: 'Nutzungsbedingungen',
        fr: "Conditions d'utilisation",
        it: 'Termini di servizio',
      );
  String get privacyPolicy => _t(
        en: 'Privacy Policy',
        uk: 'Політика конфіденційності',
        es: 'Política de privacidad',
        de: 'Datenschutzerklärung',
        fr: 'Politique de confidentialité',
        it: 'Informativa sulla privacy',
      );
  String get consentRequiredError => _t(
        en: 'Confirm you are 18 or older and accept the terms to continue',
        uk: 'Підтвердьте, що вам 18+, і прийміть умови, щоб продовжити',
        es: 'Confirma que tienes 18 años o más y acepta los términos para continuar',
        de: 'Bestätige, dass du mindestens 18 bist, und akzeptiere die Bedingungen, um fortzufahren',
        fr: 'Confirme avoir 18 ans ou plus et accepte les conditions pour continuer',
        it: 'Conferma di avere almeno 18 anni e accetta i termini per continuare',
      );
  String get termsGateTitle => _t(
        en: 'Before you continue',
        uk: 'Перш ніж продовжити',
        es: 'Antes de continuar',
        de: 'Bevor es weitergeht',
        fr: 'Avant de continuer',
        it: 'Prima di continuare',
      );
  String get termsGateBody => _t(
        en: 'To keep using Sameway, please confirm your age and accept our Terms of Service and Privacy Policy.',
        uk: 'Щоб і далі користуватися Sameway, підтвердьте свій вік і прийміть наші Умови використання та Політику конфіденційності.',
        es: 'Para seguir usando Sameway, confirma tu edad y acepta nuestros Términos del servicio y nuestra Política de privacidad.',
        de: 'Um Sameway weiter zu nutzen, bestätige bitte dein Alter und akzeptiere unsere Nutzungsbedingungen und Datenschutzerklärung.',
        fr: "Pour continuer à utiliser Sameway, confirme ton âge et accepte nos Conditions d'utilisation et notre Politique de confidentialité.",
        it: "Per continuare a usare Sameway, conferma la tua età e accetta i nostri Termini di servizio e l'Informativa sulla privacy.",
      );

  // ─── Legal: analytics consent ────────────────────────────────────────────
  String get analyticsConsentTitle => _t(
        en: 'Help us improve Sameway',
        uk: 'Допоможіть нам покращити Sameway',
        es: 'Ayúdanos a mejorar Sameway',
        de: 'Hilf uns, Sameway zu verbessern',
        fr: 'Aide-nous à améliorer Sameway',
        it: 'Aiutaci a migliorare Sameway',
      );
  String get analyticsConsentBody => _t(
        en: "Can we collect usage statistics, crash reports and performance data? It's optional — Sameway works the same either way, and you can change it any time in Account & Security.",
        uk: "Чи можемо ми збирати статистику використання, звіти про збої та дані про продуктивність? Це необов'язково — Sameway працює однаково в будь-якому разі, і ви можете змінити це будь-коли в розділі «Акаунт і безпека».",
        es: '¿Podemos recopilar estadísticas de uso, informes de fallos y datos de rendimiento? Es opcional: Sameway funciona igual en ambos casos y puedes cambiarlo cuando quieras en Cuenta y seguridad.',
        de: 'Dürfen wir Nutzungsstatistiken, Absturzberichte und Leistungsdaten erfassen? Das ist freiwillig – Sameway funktioniert so oder so gleich, und du kannst es jederzeit unter Konto & Sicherheit ändern.',
        fr: "Pouvons-nous collecter des statistiques d'utilisation, des rapports de plantage et des données de performance ? C'est facultatif : Sameway fonctionne de la même façon dans les deux cas, et tu peux changer d'avis à tout moment dans Compte et sécurité.",
        it: 'Possiamo raccogliere statistiche di utilizzo, report sugli arresti anomali e dati sulle prestazioni? È facoltativo: Sameway funziona allo stesso modo in ogni caso e puoi cambiare idea in qualsiasi momento in Account e sicurezza.',
      );
  String get analyticsAllow => _t(
        en: 'Allow',
        uk: 'Дозволити',
        es: 'Permitir',
        de: 'Erlauben',
        fr: 'Autoriser',
        it: 'Consenti',
      );
  String get analyticsDeny => _t(
        en: 'No thanks',
        uk: 'Ні, дякую',
        es: 'No, gracias',
        de: 'Nein, danke',
        fr: 'Non merci',
        it: 'No, grazie',
      );
  String get analyticsSettingTitle => _t(
        en: 'Usage statistics & crash reports',
        uk: 'Статистика використання та звіти про збої',
        es: 'Estadísticas de uso e informes de fallos',
        de: 'Nutzungsstatistiken & Absturzberichte',
        fr: "Statistiques d'utilisation et rapports de plantage",
        it: 'Statistiche di utilizzo e report sugli arresti anomali',
      );
  String get analyticsSettingSubtitle => _t(
        en: 'Optional. Helps us find bugs and improve the app.',
        uk: "Необов'язково. Допомагає знаходити помилки та покращувати застосунок.",
        es: 'Opcional. Nos ayuda a encontrar errores y mejorar la app.',
        de: 'Freiwillig. Hilft uns, Fehler zu finden und die App zu verbessern.',
        fr: "Facultatif. Nous aide à trouver des bugs et à améliorer l'app.",
        it: "Facoltativo. Ci aiuta a trovare bug e migliorare l'app.",
      );
  String get legalAndPrivacy => _t(
        en: 'Legal & privacy',
        uk: 'Правова інформація та конфіденційність',
        es: 'Legal y privacidad',
        de: 'Rechtliches & Datenschutz',
        fr: 'Mentions légales et confidentialité',
        it: 'Note legali e privacy',
      );

  String get accountSuspended => _t(
        en: 'This account has been suspended. Contact support if you think this is a mistake.',
        uk: 'Цей акаунт заблоковано. Зверніться до підтримки, якщо вважаєте це помилкою.',
        es: 'Esta cuenta ha sido suspendida. Contacta con soporte si crees que es un error.',
        de: 'Dieses Konto wurde gesperrt. Wende dich an den Support, wenn du das für einen Fehler hältst.',
        fr: "Ce compte a été suspendu. Contacte le support si tu penses qu'il s'agit d'une erreur.",
        it: "Questo account è stato sospeso. Contatta l'assistenza se pensi che sia un errore.",
      );

  // ─── Account deletion ────────────────────────────────────────────────────
  String get deleteAccount => _t(
        en: 'Delete account',
        uk: 'Видалити акаунт',
        es: 'Eliminar cuenta',
        de: 'Konto löschen',
        fr: 'Supprimer le compte',
        it: 'Elimina account',
      );
  String get deleteAccountTitle => _t(
        en: 'Delete your account?',
        uk: 'Видалити акаунт?',
        es: '¿Eliminar tu cuenta?',
        de: 'Konto löschen?',
        fr: 'Supprimer ton compte ?',
        it: 'Eliminare il tuo account?',
      );
  String get deleteAccountBody => _t(
        en: "This permanently deletes your profile, chats, location and planned trips. Rides and ratings that involved other people are kept without your name. This can't be undone.",
        uk: 'Це остаточно видалить ваш профіль, чати, геолокацію та заплановані поїздки. Поїздки й оцінки за участю інших людей збережуться без вашого імені. Цю дію не можна скасувати.',
        es: 'Esto elimina para siempre tu perfil, chats, ubicación y viajes planificados. Los viajes y valoraciones en los que participaron otras personas se conservan sin tu nombre. No se puede deshacer.',
        de: 'Dadurch werden dein Profil, deine Chats, dein Standort und geplante Fahrten endgültig gelöscht. Fahrten und Bewertungen mit anderen Personen bleiben ohne deinen Namen erhalten. Das kann nicht rückgängig gemacht werden.',
        fr: 'Ton profil, tes discussions, ta position et tes trajets prévus seront définitivement supprimés. Les trajets et évaluations impliquant d\'autres personnes sont conservés sans ton nom. Cette action est irréversible.',
        it: "Il tuo profilo, le chat, la posizione e i viaggi pianificati verranno eliminati definitivamente. I viaggi e le valutazioni che coinvolgono altre persone restano senza il tuo nome. L'operazione non può essere annullata.",
      );
  String get deleteAccountPasswordLabel => _t(
        en: 'Enter your password to confirm',
        uk: 'Введіть пароль для підтвердження',
        es: 'Introduce tu contraseña para confirmar',
        de: 'Gib zur Bestätigung dein Passwort ein',
        fr: 'Saisis ton mot de passe pour confirmer',
        it: 'Inserisci la password per confermare',
      );
  String get deleteAccountConfirm => _t(
        en: 'Delete permanently',
        uk: 'Видалити назавжди',
        es: 'Eliminar para siempre',
        de: 'Endgültig löschen',
        fr: 'Supprimer définitivement',
        it: 'Elimina definitivamente',
      );
  String get accountDeleted => _t(
        en: 'Your account has been deleted',
        uk: 'Ваш акаунт видалено',
        es: 'Tu cuenta se ha eliminado',
        de: 'Dein Konto wurde gelöscht',
        fr: 'Ton compte a été supprimé',
        it: 'Il tuo account è stato eliminato',
      );
  String get deleteAccountActiveRide => _t(
        en: 'Finish or cancel your current ride before deleting your account',
        uk: 'Завершіть або скасуйте поточну поїздку перед видаленням акаунта',
        es: 'Termina o cancela tu viaje actual antes de eliminar tu cuenta',
        de: 'Beende oder storniere deine aktuelle Fahrt, bevor du dein Konto löschst',
        fr: 'Termine ou annule ton trajet en cours avant de supprimer ton compte',
        it: 'Termina o annulla il viaggio in corso prima di eliminare il tuo account',
      );
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLanguageCodes.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
