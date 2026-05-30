import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const delegate = _AppLocalizationsDelegate();

  bool get _isUk => locale.languageCode == 'uk';

  // Role selection
  String get iAm => _isUk ? 'Я є…' : 'I am a…';
  String get chooseRole =>
      _isUk ? 'Виберіть свою роль для початку' : 'Choose your role to get started';
  String get driver => _isUk ? 'Водій' : 'Driver';
  String get driverSubtitle =>
      _isUk ? 'У мене є місця по моєму маршруту' : 'I have seats to share along my route';
  String get passenger => _isUk ? 'Пасажир' : 'Passenger';
  String get passengerSubtitle =>
      _isUk ? 'Мені потрібна поїздка до місця призначення' : 'I need a ride to my destination';
  String get continueAsGuest => _isUk ? 'Продовжити як гість' : 'Continue as Guest';
  String get canSwitchRoles =>
      _isUk ? 'Ви можете змінити роль у будь-який час у налаштуваннях.' : 'You can switch roles anytime from settings.';
  String get exploreAsGuest => _isUk ? 'Досліджувати як гість' : 'Explore as Guest';
  String get guestSubtitle =>
      _isUk ? 'Переглядайте карту без акаунта.\nВвійдіть пізніше, щоб розблокувати всі функції.' : 'Browse the map without an account.\nSign in later to unlock full features.';
  String get guestDriver => _isUk ? 'Гість-водій' : 'Guest Driver';
  String get guestPassenger => _isUk ? 'Гість-пасажир' : 'Guest Passenger';

  // Auth screen
  String get welcomeBack => _isUk ? 'З поверненням' : 'Welcome back';
  String get createAccount => _isUk ? 'Створити акаунт' : 'Create account';
  String get signInContinue =>
      _isUk ? 'Увійдіть, щоб продовжити подорож' : 'Sign in to continue your journey';
  String get joinSameway => _isUk ? 'Приєднайтесь до sameway сьогодні' : 'Join sameway today';
  String get signIn => _isUk ? 'Увійти' : 'Sign In';
  String get signUp => _isUk ? 'Зареєструватися' : 'Sign Up';
  String get continueWithGoogle =>
      _isUk ? 'Продовжити з Google' : 'Continue with Google';
  String get or => _isUk ? 'або' : 'or';

  // Home screens — top bar & account sheet
  String get account => _isUk ? 'Акаунт' : 'Account';
  String get switchRole => _isUk ? 'Змінити роль' : 'Switch Role';
  String get language => _isUk ? 'Мова' : 'Language';
  String get signOut => _isUk ? 'Вийти' : 'Sign Out';
  String get guest => _isUk ? 'ГІСТЬ' : 'GUEST';

  // Driver home
  String get readyToShare =>
      _isUk ? 'Готові поділитися маршрутом?' : 'Ready to share your route?';
  String get setRouteDesc =>
      _isUk ? 'Вкажіть пункт призначення та знайдіть попутників.' : 'Set your destination and find passengers heading your way.';
  String get setRoute => _isUk ? 'Встановити маршрут' : 'Set Route';
  String get settingRoute => _isUk ? 'Встановлення маршруту…' : 'Setting route…';
  String get findPassengers => _isUk ? 'Знайти пасажирів' : 'Find Passengers';
  String get setYourRoute => _isUk ? 'Встановіть свій маршрут' : 'Set your route';
  String get destination => _isUk ? 'Адреса призначення' : 'Destination address';
  String get corridorRadius => _isUk ? 'Радіус коридору' : 'Corridor radius';
  String get availableSeats => _isUk ? 'Доступні місця' : 'Available seats';
  String get routeActive => _isUk ? 'Маршрут активний' : 'Route active';
  String get exploringAsGuest => _isUk ? 'Досліджуєте як гість' : 'Exploring as Guest';
  String get signInToShareRoute =>
      _isUk ? 'Увійдіть, щоб поділитися маршрутом' : 'Sign In to Share Route';
  String get signInShareDesc =>
      _isUk ? 'Увійдіть, щоб поділитися маршрутом та знайти пасажирів.' : 'Sign in to share your route and get matched with passengers.';

  // Passenger home
  String get lookingForRides => _isUk ? 'Шукаємо поїздки' : 'Looking for rides';
  String get lookingDesc =>
      _isUk ? 'Ми повідомимо вас, коли поруч буде водій з відповідним маршрутом.' : 'We\'ll notify you when a driver with a matching route is nearby.';
  String get signInToFindRides =>
      _isUk ? 'Увійдіть, щоб знайти поїздки' : 'Sign In to Find Rides';
  String get signInFindDesc =>
      _isUk ? 'Увійдіть, щоб отримати підбір водіїв, які їдуть у вашому напрямку.' : 'Sign in to get matched with drivers heading your way.';

  // Sign-in prompt sheet
  String get signInToContinue => _isUk ? 'Увійдіть, щоб продовжити' : 'Sign in to continue';
  String get signInRegister => _isUk ? 'Увійти / Зареєструватися' : 'Sign In / Register';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'uk'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
