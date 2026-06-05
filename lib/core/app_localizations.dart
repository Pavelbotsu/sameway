import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const delegate = _AppLocalizationsDelegate();

  // Helper: pick by language code, falling back to English.
  String _t({
    required String en,
    String? uk,
    String? es,
    String? de,
  }) =>
      switch (locale.languageCode) {
        'uk' => uk ?? en,
        'es' => es ?? en,
        'de' => de ?? en,
        _ => en,
      };

  // ─── Role selection ──────────────────────────────────────────────────────
  String get iAm => _t(en: 'I am a…', uk: 'Я є…', es: 'Soy…', de: 'Ich bin…');
  String get chooseRole => _t(
        en: 'Choose your role to get started',
        uk: 'Виберіть свою роль для початку',
        es: 'Elige tu rol para empezar',
        de: 'Wähle deine Rolle, um zu starten',
      );
  String get driver => _t(en: 'Driver', uk: 'Водій', es: 'Conductor', de: 'Fahrer');
  String get driverSubtitle => _t(
        en: 'I have seats to share along my route',
        uk: 'У мене є місця по моєму маршруту',
        es: 'Tengo asientos para compartir en mi ruta',
        de: 'Ich habe Plätze entlang meiner Route frei',
      );
  String get passenger =>
      _t(en: 'Passenger', uk: 'Пасажир', es: 'Pasajero', de: 'Fahrgast');
  String get passengerSubtitle => _t(
        en: 'I need a ride to my destination',
        uk: 'Мені потрібна поїздка до місця призначення',
        es: 'Necesito un viaje a mi destino',
        de: 'Ich brauche eine Mitfahrt zu meinem Ziel',
      );
  String get continueAsGuest => _t(
        en: 'Continue as Guest',
        uk: 'Продовжити як гість',
        es: 'Continuar como invitado',
        de: 'Als Gast fortfahren',
      );
  String get canSwitchRoles => _t(
        en: 'You can switch roles anytime from settings.',
        uk: 'Ви можете змінити роль у будь-який час у налаштуваннях.',
        es: 'Puedes cambiar de rol en cualquier momento desde los ajustes.',
        de: 'Du kannst die Rolle jederzeit in den Einstellungen wechseln.',
      );
  String get exploreAsGuest => _t(
        en: 'Explore as Guest',
        uk: 'Досліджувати як гість',
        es: 'Explorar como invitado',
        de: 'Als Gast erkunden',
      );
  String get guestSubtitle => _t(
        en: 'Browse the map without an account.\nSign in later to unlock full features.',
        uk: 'Переглядайте карту без акаунта.\nВвійдіть пізніше, щоб розблокувати всі функції.',
        es: 'Explora el mapa sin cuenta.\nInicia sesión después para desbloquear todo.',
        de: 'Karte ohne Konto erkunden.\nMelde dich später an, um alle Funktionen freizuschalten.',
      );
  String get guestDriver => _t(
        en: 'Guest Driver',
        uk: 'Гість-водій',
        es: 'Conductor invitado',
        de: 'Gast-Fahrer',
      );
  String get guestPassenger => _t(
        en: 'Guest Passenger',
        uk: 'Гість-пасажир',
        es: 'Pasajero invitado',
        de: 'Gast-Fahrgast',
      );

  // ─── Auth screen ─────────────────────────────────────────────────────────
  String get welcomeBack => _t(
        en: 'Welcome back',
        uk: 'З поверненням',
        es: 'Bienvenido de nuevo',
        de: 'Willkommen zurück',
      );
  String get createAccount => _t(
        en: 'Create account',
        uk: 'Створити акаунт',
        es: 'Crear cuenta',
        de: 'Konto erstellen',
      );
  String get signInContinue => _t(
        en: 'Sign in to continue your journey',
        uk: 'Увійдіть, щоб продовжити подорож',
        es: 'Inicia sesión para continuar tu viaje',
        de: 'Melde dich an, um deine Reise fortzusetzen',
      );
  String get joinSameway => _t(
        en: 'Join sameway today',
        uk: 'Приєднайтесь до sameway сьогодні',
        es: 'Únete a sameway hoy',
        de: 'Werde noch heute Teil von sameway',
      );
  String get signIn => _t(en: 'Sign In', uk: 'Увійти', es: 'Iniciar sesión', de: 'Anmelden');
  String get signUp => _t(en: 'Sign Up', uk: 'Зареєструватися', es: 'Registrarse', de: 'Registrieren');
  String get continueWithGoogle => _t(
        en: 'Continue with Google',
        uk: 'Продовжити з Google',
        es: 'Continuar con Google',
        de: 'Mit Google fortfahren',
      );
  String get or => _t(en: 'or', uk: 'або', es: 'o', de: 'oder');

  // ─── Home top bar & account sheet ────────────────────────────────────────
  String get account => _t(en: 'Account', uk: 'Акаунт', es: 'Cuenta', de: 'Konto');
  String get switchRole => _t(
        en: 'Switch Role',
        uk: 'Змінити роль',
        es: 'Cambiar de rol',
        de: 'Rolle wechseln',
      );
  String get language => _t(en: 'Language', uk: 'Мова', es: 'Idioma', de: 'Sprache');
  String get signOut => _t(en: 'Sign Out', uk: 'Вийти', es: 'Cerrar sesión', de: 'Abmelden');
  String get guest => _t(en: 'GUEST', uk: 'ГІСТЬ', es: 'INVITADO', de: 'GAST');

  // ─── Forms / validators ──────────────────────────────────────────────────
  String get fieldRequired => _t(
        en: 'Required',
        uk: 'Обов\'язкове поле',
        es: 'Obligatorio',
        de: 'Pflichtfeld',
      );

  // ─── Quick role-switch sheet ─────────────────────────────────────────────
  String get switchRoleTo => _t(
        en: 'Switch role',
        uk: 'Змінити роль',
        es: 'Cambiar de rol',
        de: 'Rolle wechseln',
      );
  String get switchToDriver => _t(
        en: 'Switch to Driver',
        uk: 'Перейти у водія',
        es: 'Cambiar a conductor',
        de: 'Zum Fahrer wechseln',
      );
  String get switchToPassenger => _t(
        en: 'Switch to Passenger',
        uk: 'Перейти у пасажира',
        es: 'Cambiar a pasajero',
        de: 'Zum Fahrgast wechseln',
      );
  String get currentRole => _t(
        en: 'Current role',
        uk: 'Поточна роль',
        es: 'Rol actual',
        de: 'Aktuelle Rolle',
      );

  // ─── Account & Security ──────────────────────────────────────────────────
  String get accountSecurity => _t(
        en: 'Account & Security',
        uk: 'Акаунт і безпека',
        es: 'Cuenta y seguridad',
        de: 'Konto & Sicherheit',
      );

  // ─── Driver home ─────────────────────────────────────────────────────────
  String get readyToShare => _t(
        en: 'Ready to share your route?',
        uk: 'Готові поділитися маршрутом?',
        es: '¿Listo para compartir tu ruta?',
        de: 'Bereit, deine Route zu teilen?',
      );
  String get setRouteDesc => _t(
        en: 'Set your destination and find passengers heading your way.',
        uk: 'Вкажіть пункт призначення та знайдіть попутників.',
        es: 'Define tu destino y encuentra pasajeros que vayan por tu camino.',
        de: 'Lege dein Ziel fest und finde Fahrgäste auf deiner Strecke.',
      );
  String get setRoute => _t(
        en: 'Set Route',
        uk: 'Встановити маршрут',
        es: 'Definir ruta',
        de: 'Route festlegen',
      );
  String get settingRoute => _t(
        en: 'Setting route…',
        uk: 'Встановлення маршруту…',
        es: 'Definiendo ruta…',
        de: 'Route wird festgelegt…',
      );
  String get findPassengers => _t(
        en: 'Find Passengers',
        uk: 'Знайти пасажирів',
        es: 'Buscar pasajeros',
        de: 'Fahrgäste finden',
      );
  String get setYourRoute => _t(
        en: 'Set your route',
        uk: 'Встановіть свій маршрут',
        es: 'Define tu ruta',
        de: 'Lege deine Route fest',
      );
  String get destination => _t(
        en: 'Destination address',
        uk: 'Адреса призначення',
        es: 'Dirección de destino',
        de: 'Zieladresse',
      );
  String get corridorRadius => _t(
        en: 'Corridor radius',
        uk: 'Радіус коридору',
        es: 'Radio del corredor',
        de: 'Korridorradius',
      );
  String get availableSeats => _t(
        en: 'Available seats',
        uk: 'Доступні місця',
        es: 'Asientos disponibles',
        de: 'Verfügbare Plätze',
      );
  String get routeActive => _t(
        en: 'Route active',
        uk: 'Маршрут активний',
        es: 'Ruta activa',
        de: 'Route aktiv',
      );
  String get exploringAsGuest => _t(
        en: 'Exploring as Guest',
        uk: 'Досліджуєте як гість',
        es: 'Explorando como invitado',
        de: 'Als Gast unterwegs',
      );
  String get signInToShareRoute => _t(
        en: 'Sign In to Share Route',
        uk: 'Увійдіть, щоб поділитися маршрутом',
        es: 'Inicia sesión para compartir tu ruta',
        de: 'Anmelden, um Route zu teilen',
      );
  String get signInShareDesc => _t(
        en: 'Sign in to share your route and get matched with passengers.',
        uk: 'Увійдіть, щоб поділитися маршрутом та знайти пасажирів.',
        es: 'Inicia sesión para compartir tu ruta y encontrar pasajeros.',
        de: 'Melde dich an, um deine Route zu teilen und Fahrgäste zu finden.',
      );

  // ─── Passenger home ──────────────────────────────────────────────────────
  String get lookingForRides => _t(
        en: 'Looking for rides',
        uk: 'Шукаємо поїздки',
        es: 'Buscando viajes',
        de: 'Suche nach Fahrten',
      );
  String get lookingDesc => _t(
        en: "We'll notify you when a driver with a matching route is nearby.",
        uk: 'Ми повідомимо вас, коли поруч буде водій з відповідним маршрутом.',
        es: 'Te avisaremos cuando haya un conductor con una ruta compatible cerca.',
        de: 'Wir benachrichtigen dich, wenn ein passender Fahrer in der Nähe ist.',
      );
  String get signInToFindRides => _t(
        en: 'Sign In to Find Rides',
        uk: 'Увійдіть, щоб знайти поїздки',
        es: 'Inicia sesión para buscar viajes',
        de: 'Anmelden, um Fahrten zu finden',
      );
  String get signInFindDesc => _t(
        en: 'Sign in to get matched with drivers heading your way.',
        uk: 'Увійдіть, щоб отримати підбір водіїв, які їдуть у вашому напрямку.',
        es: 'Inicia sesión para encontrar conductores que vayan por tu camino.',
        de: 'Melde dich an, um Fahrer auf deinem Weg zu finden.',
      );

  // ─── Sign-in prompt sheet ────────────────────────────────────────────────
  String get signInToContinue => _t(
        en: 'Sign in to continue',
        uk: 'Увійдіть, щоб продовжити',
        es: 'Inicia sesión para continuar',
        de: 'Zum Fortfahren anmelden',
      );
  String get signInRegister => _t(
        en: 'Sign In / Register',
        uk: 'Увійти / Зареєструватися',
        es: 'Iniciar sesión / Registrarse',
        de: 'Anmelden / Registrieren',
      );

  // ─── Auth — fields and toggles ───────────────────────────────────────────
  String get fullName => _t(
        en: 'Full name',
        uk: 'Повне ім\'я',
        es: 'Nombre completo',
        de: 'Vollständiger Name',
      );
  String get emailAddress => _t(
        en: 'Email address',
        uk: 'Електронна пошта',
        es: 'Correo electrónico',
        de: 'E-Mail-Adresse',
      );
  String get password => _t(
        en: 'Password',
        uk: 'Пароль',
        es: 'Contraseña',
        de: 'Passwort',
      );
  String get invalidEmail => _t(
        en: 'Invalid email',
        uk: 'Невірна електронна пошта',
        es: 'Correo no válido',
        de: 'Ungültige E-Mail',
      );
  String get minSixChars => _t(
        en: 'Min 6 characters',
        uk: 'Мінімум 6 символів',
        es: 'Mín. 6 caracteres',
        de: 'Mind. 6 Zeichen',
      );
  String get noAccountYet => _t(
        en: "Don't have an account? ",
        uk: 'Немає акаунта? ',
        es: '¿No tienes cuenta? ',
        de: 'Noch kein Konto? ',
      );
  String get alreadyHaveAccount => _t(
        en: 'Already have an account? ',
        uk: 'Вже маєте акаунт? ',
        es: '¿Ya tienes cuenta? ',
        de: 'Bereits ein Konto? ',
      );

  // ─── Onboarding pages ────────────────────────────────────────────────────
  String get onboardTitle1 => _t(
        en: 'Smarter routes, together.',
        uk: 'Розумніші маршрути разом.',
        es: 'Rutas más inteligentes, juntos.',
        de: 'Klügere Routen, gemeinsam.',
      );
  String get onboardSubtitle1 => _t(
        en: 'Share rides with people heading your way.',
        uk: 'Поділіться поїздкою з тими, хто їде у тому ж напрямку.',
        es: 'Comparte viajes con personas que van por tu camino.',
        de: 'Teile Fahrten mit Menschen auf deinem Weg.',
      );
  String get onboardTitle2 => _t(
        en: 'Real-time matching.',
        uk: 'Підбір у реальному часі.',
        es: 'Emparejamiento en tiempo real.',
        de: 'Matching in Echtzeit.',
      );
  String get onboardSubtitle2 => _t(
        en: 'Drivers and passengers find each other instantly.',
        uk: 'Водії та пасажири миттєво знаходять одне одного.',
        es: 'Conductores y pasajeros se encuentran al instante.',
        de: 'Fahrer und Fahrgäste finden sich sofort.',
      );
  String get onboardTitle3 => _t(
        en: 'Save CO₂ together.',
        uk: 'Економте CO₂ разом.',
        es: 'Ahorra CO₂ juntos.',
        de: 'Gemeinsam CO₂ sparen.',
      );
  String get onboardSubtitle3 => _t(
        en: 'Every shared trip reduces emissions.',
        uk: 'Кожна спільна поїздка зменшує викиди.',
        es: 'Cada viaje compartido reduce las emisiones.',
        de: 'Jede geteilte Fahrt senkt die Emissionen.',
      );
  String get skip => _t(en: 'Skip', uk: 'Пропустити', es: 'Saltar', de: 'Überspringen');
  String get getStarted => _t(
        en: 'Get Started',
        uk: 'Почати',
        es: 'Comenzar',
        de: 'Loslegen',
      );
  String get continueLabel => _t(
        en: 'Continue',
        uk: 'Продовжити',
        es: 'Continuar',
        de: 'Weiter',
      );

  // ─── Common buttons / dialogs ────────────────────────────────────────────
  String get save => _t(en: 'Save', uk: 'Зберегти', es: 'Guardar', de: 'Speichern');
  String get cancel => _t(en: 'Cancel', uk: 'Скасувати', es: 'Cancelar', de: 'Abbrechen');
  String get later => _t(en: 'Later', uk: 'Пізніше', es: 'Más tarde', de: 'Später');
  String get openSettings => _t(
        en: 'Open Settings',
        uk: 'Відкрити налаштування',
        es: 'Abrir ajustes',
        de: 'Einstellungen öffnen',
      );
  String get gpsOff => _t(
        en: 'GPS is off',
        uk: 'GPS вимкнено',
        es: 'GPS desactivado',
        de: 'GPS ist aus',
      );
  String get gpsOffMessage => _t(
        en: 'Location services are required to find rides.',
        uk: 'Потрібно увімкнути геолокацію, щоб знаходити поїздки.',
        es: 'Se requiere ubicación para encontrar viajes.',
        de: 'Standortdienste sind nötig, um Fahrten zu finden.',
      );
  String get keepRide => _t(
        en: 'Keep ride',
        uk: 'Залишити поїздку',
        es: 'Mantener viaje',
        de: 'Fahrt behalten',
      );
  String get cancelRideQ => _t(
        en: 'Cancel ride?',
        uk: 'Скасувати поїздку?',
        es: '¿Cancelar viaje?',
        de: 'Fahrt abbrechen?',
      );
  String get cancelRideMessageDriver => _t(
        en: 'The passenger will be notified.',
        uk: 'Пасажир буде сповіщений.',
        es: 'Se avisará al pasajero.',
        de: 'Der Fahrgast wird benachrichtigt.',
      );
  String get cancelRideMessagePassenger => _t(
        en: 'Your driver will be notified.',
        uk: 'Водій буде сповіщений.',
        es: 'Se avisará a tu conductor.',
        de: 'Dein Fahrer wird benachrichtigt.',
      );

  // ─── Offer / Accepted / Looking cards ────────────────────────────────────
  String get rideOffer => _t(
        en: 'Ride offer!',
        uk: 'Пропозиція поїздки!',
        es: '¡Oferta de viaje!',
        de: 'Fahrtangebot!',
      );
  String get accept => _t(en: 'Accept', uk: 'Прийняти', es: 'Aceptar', de: 'Annehmen');
  String get decline => _t(en: 'Decline', uk: 'Відхилити', es: 'Rechazar', de: 'Ablehnen');
  String get rideAccepted => _t(
        en: 'Ride accepted!',
        uk: 'Поїздку прийнято!',
        es: '¡Viaje aceptado!',
        de: 'Fahrt angenommen!',
      );
  String get driverNotified => _t(
        en: 'Your driver has been notified. Stay at your location.',
        uk: 'Водія сповіщено. Залишайтеся на місці.',
        es: 'Tu conductor ha sido avisado. Quédate en tu ubicación.',
        de: 'Dein Fahrer wurde benachrichtigt. Bleib an deinem Standort.',
      );
  String get messageDriver => _t(
        en: 'Message Driver',
        uk: 'Написати водієві',
        es: 'Mensaje al conductor',
        de: 'Fahrer schreiben',
      );
  String get driverLabel => _t(en: 'Driver', uk: 'Водій', es: 'Conductor', de: 'Fahrer');
  String get corridorLabel => _t(
        en: 'km corridor',
        uk: 'км коридор',
        es: 'km de corredor',
        de: 'km Korridor',
      );
  String get seatLabel => _t(en: 'seat', uk: 'місце', es: 'asiento', de: 'Platz');
  String get seatsLabel => _t(en: 'seats', uk: 'місць', es: 'asientos', de: 'Plätze');

  // ─── Driver home — requests list ─────────────────────────────────────────
  String get noRideRequests => _t(
        en: 'No ride requests yet',
        uk: 'Поки немає запитів',
        es: 'Aún no hay solicitudes',
        de: 'Noch keine Fahrtanfragen',
      );
  String get noRideRequestsDesc => _t(
        en: 'Passengers near your route will appear here.',
        uk: 'Пасажири біля вашого маршруту з\'являться тут.',
        es: 'Los pasajeros cerca de tu ruta aparecerán aquí.',
        de: 'Fahrgäste in der Nähe deiner Route erscheinen hier.',
      );
  String get rideRequests => _t(
        en: 'Ride requests',
        uk: 'Запити на поїздку',
        es: 'Solicitudes de viaje',
        de: 'Fahrtanfragen',
      );

  // ─── Account & Security ──────────────────────────────────────────────────
  String get displayName => _t(
        en: 'Display name',
        uk: 'Ім\'я',
        es: 'Nombre visible',
        de: 'Anzeigename',
      );
  String get changePassword => _t(
        en: 'Change password',
        uk: 'Змінити пароль',
        es: 'Cambiar contraseña',
        de: 'Passwort ändern',
      );
  String get currentPassword => _t(
        en: 'Current password',
        uk: 'Поточний пароль',
        es: 'Contraseña actual',
        de: 'Aktuelles Passwort',
      );
  String get newPassword => _t(
        en: 'New password',
        uk: 'Новий пароль',
        es: 'Nueva contraseña',
        de: 'Neues Passwort',
      );
  String get confirmNewPassword => _t(
        en: 'Confirm new password',
        uk: 'Підтвердити новий пароль',
        es: 'Confirmar nueva contraseña',
        de: 'Neues Passwort bestätigen',
      );
  String get updatePassword => _t(
        en: 'Update Password',
        uk: 'Оновити пароль',
        es: 'Actualizar contraseña',
        de: 'Passwort aktualisieren',
      );
  String get passwordsNotMatch => _t(
        en: 'New passwords do not match',
        uk: 'Нові паролі не співпадають',
        es: 'Las contraseñas no coinciden',
        de: 'Neue Passwörter stimmen nicht überein',
      );
  String get passwordTooShort => _t(
        en: 'Password must be at least 6 characters',
        uk: 'Пароль має містити мінімум 6 символів',
        es: 'La contraseña debe tener al menos 6 caracteres',
        de: 'Passwort muss mindestens 6 Zeichen haben',
      );
  String get passwordUpdated => _t(
        en: 'Password updated',
        uk: 'Пароль оновлено',
        es: 'Contraseña actualizada',
        de: 'Passwort aktualisiert',
      );
  String get networkError => _t(
        en: 'Network error',
        uk: 'Помилка мережі',
        es: 'Error de red',
        de: 'Netzwerkfehler',
      );
  String get nameUpdated => _t(
        en: 'Name updated',
        uk: 'Ім\'я оновлено',
        es: 'Nombre actualizado',
        de: 'Name aktualisiert',
      );
  String get emailCopied => _t(
        en: 'Email copied',
        uk: 'Email скопійовано',
        es: 'Correo copiado',
        de: 'E-Mail kopiert',
      );

  // ─── Chat ────────────────────────────────────────────────────────────────
  String get activeTrip => _t(
        en: 'Active trip',
        uk: 'Активна поїздка',
        es: 'Viaje activo',
        de: 'Aktive Fahrt',
      );
  String get noMessages => _t(
        en: 'No messages yet.\nSay hello!',
        uk: 'Поки немає повідомлень.\nПривітайтеся!',
        es: 'Aún no hay mensajes.\n¡Saluda!',
        de: 'Noch keine Nachrichten.\nSag Hallo!',
      );
  String get messageHint => _t(
        en: 'Message…',
        uk: 'Повідомлення…',
        es: 'Mensaje…',
        de: 'Nachricht…',
      );

  // ─── Trip history ────────────────────────────────────────────────────────
  String get tripHistory => _t(
        en: 'Trip History',
        uk: 'Історія поїздок',
        es: 'Historial de viajes',
        de: 'Fahrtenverlauf',
      );
  String get noTripsYet => _t(
        en: 'No trips yet',
        uk: 'Поки немає поїздок',
        es: 'Aún no hay viajes',
        de: 'Noch keine Fahrten',
      );
  String get firstRidePrompt => _t(
        en: 'Complete your first ride to see it here.',
        uk: 'Завершіть першу поїздку, щоб побачити її тут.',
        es: 'Completa tu primer viaje para verlo aquí.',
        de: 'Schließe deine erste Fahrt ab, um sie hier zu sehen.',
      );

  // ─── Trip planner / search sheets ────────────────────────────────────────
  String get selectOriginLocation => _t(
        en: 'Select an origin location',
        uk: 'Виберіть початкове місце',
        es: 'Elige un punto de origen',
        de: 'Startort auswählen',
      );
  String get selectDestinationLocation => _t(
        en: 'Select a destination location',
        uk: 'Виберіть місце призначення',
        es: 'Elige un destino',
        de: 'Zielort auswählen',
      );
  String get tripPlannedSuccess => _t(
        en: 'Trip planned successfully!',
        uk: 'Поїздку успішно заплановано!',
        es: '¡Viaje planificado con éxito!',
        de: 'Fahrt erfolgreich geplant!',
      );
  String get locationNotAvailable => _t(
        en: 'Location not available',
        uk: 'Геолокація недоступна',
        es: 'Ubicación no disponible',
        de: 'Standort nicht verfügbar',
      );
  String get requestSent => _t(
        en: 'Request sent!',
        uk: 'Запит надіслано!',
        es: '¡Solicitud enviada!',
        de: 'Anfrage gesendet!',
      );
  String get requestFailed => _t(
        en: 'Failed to send request',
        uk: 'Не вдалося надіслати запит',
        es: 'Error al enviar la solicitud',
        de: 'Anfrage konnte nicht gesendet werden',
      );

  // ─── Promotions ──────────────────────────────────────────────────────────
  String get promotionsAndRewards => _t(
        en: 'Promotions & Rewards',
        uk: 'Акції та винагороди',
        es: 'Promociones y recompensas',
        de: 'Aktionen & Prämien',
      );
  String get activeOffers => _t(
        en: 'Active Offers',
        uk: 'Активні пропозиції',
        es: 'Ofertas activas',
        de: 'Aktive Angebote',
      );
  String get expired => _t(
        en: 'Expired',
        uk: 'Минулі',
        es: 'Vencidas',
        de: 'Abgelaufen',
      );
  String get noPromotions => _t(
        en: 'No promotions available',
        uk: 'Немає доступних акцій',
        es: 'No hay promociones disponibles',
        de: 'Keine Aktionen verfügbar',
      );

  // ─── Rating sheet ────────────────────────────────────────────────────────
  String get rateYourDriver => _t(
        en: 'Rate your driver',
        uk: 'Оцінити водія',
        es: 'Valora a tu conductor',
        de: 'Bewerte deinen Fahrer',
      );
  String get rateYourPassenger => _t(
        en: 'Rate your passenger',
        uk: 'Оцінити пасажира',
        es: 'Valora a tu pasajero',
        de: 'Bewerte deinen Fahrgast',
      );
  String get howWasExperience => _t(
        en: 'How was your experience?',
        uk: 'Як вам поїздка?',
        es: '¿Cómo fue tu experiencia?',
        de: 'Wie war deine Erfahrung?',
      );
  String get addCommentOptional => _t(
        en: 'Add a comment (optional)',
        uk: 'Додати коментар (необов\'язково)',
        es: 'Añadir un comentario (opcional)',
        de: 'Kommentar hinzufügen (optional)',
      );
  String get submit => _t(en: 'Submit', uk: 'Надіслати', es: 'Enviar', de: 'Senden');
  String get skipRating => _t(
        en: 'Skip',
        uk: 'Пропустити',
        es: 'Saltar',
        de: 'Überspringen',
      );

  // ─── Car edit sheet ──────────────────────────────────────────────────────
  String get myCar => _t(en: 'My Car', uk: 'Моє авто', es: 'Mi coche', de: 'Mein Auto');
  String get carMake => _t(en: 'Make', uk: 'Марка', es: 'Marca', de: 'Marke');
  String get carModel => _t(en: 'Model', uk: 'Модель', es: 'Modelo', de: 'Modell');
  String get carColor => _t(en: 'Color', uk: 'Колір', es: 'Color', de: 'Farbe');
  String get carPlate => _t(
        en: 'Plate',
        uk: 'Номерний знак',
        es: 'Matrícula',
        de: 'Kennzeichen',
      );
  String get carMakeHint =>
      _t(en: 'e.g. Toyota', uk: 'напр. Toyota', es: 'p. ej. Toyota', de: 'z. B. Toyota');
  String get carModelHint =>
      _t(en: 'e.g. Corolla', uk: 'напр. Corolla', es: 'p. ej. Corolla', de: 'z. B. Corolla');
  String get carColorHint => _t(
        en: 'e.g. Silver',
        uk: 'напр. Сріблястий',
        es: 'p. ej. Plata',
        de: 'z. B. Silber',
      );
  String get carPlateHint => _t(
        en: 'e.g. KR 12345',
        uk: 'напр. КА 12345',
        es: 'p. ej. 1234 ABC',
        de: 'z. B. B-AB 1234',
      );
  String get carInfoSaved => _t(
        en: 'Car info saved!',
        uk: 'Інформацію про авто збережено!',
        es: '¡Información del coche guardada!',
        de: 'Fahrzeugdaten gespeichert!',
      );

  // ─── Misc tiles / sheets ─────────────────────────────────────────────────
  String get testNotificationSent => _t(
        en: 'Test notification sent!',
        uk: 'Тестове сповіщення надіслано!',
        es: '¡Notificación de prueba enviada!',
        de: 'Testbenachrichtigung gesendet!',
      );
  String get mapStyle => _t(
        en: 'Map Style',
        uk: 'Стиль карти',
        es: 'Estilo del mapa',
        de: 'Kartenstil',
      );
  String get planATrip => _t(
        en: 'Plan a Trip',
        uk: 'Запланувати поїздку',
        es: 'Planificar un viaje',
        de: 'Fahrt planen',
      );
  String get findPlannedTrips => _t(
        en: 'Find Planned Trips',
        uk: 'Знайти заплановані поїздки',
        es: 'Buscar viajes planificados',
        de: 'Geplante Fahrten finden',
      );
  String get testNotification => _t(
        en: 'Test Notification',
        uk: 'Тестове сповіщення',
        es: 'Notificación de prueba',
        de: 'Testbenachrichtigung',
      );
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'uk', 'es', 'de'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
