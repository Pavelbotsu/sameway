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

  // Forms / validators
  String get fieldRequired => _isUk ? 'Обов\'язкове поле' : 'Required';

  // Quick role-switch sheet (top-left badge tap)
  String get switchRoleTo => _isUk ? 'Змінити роль' : 'Switch role';
  String get switchToDriver => _isUk ? 'Перейти у водія' : 'Switch to Driver';
  String get switchToPassenger => _isUk ? 'Перейти у пасажира' : 'Switch to Passenger';
  String get currentRole => _isUk ? 'Поточна роль' : 'Current role';

  // Account & Security screen
  String get accountSecurity => _isUk ? 'Акаунт і безпека' : 'Account & Security';

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

  // Auth screen — fields and toggles
  String get fullName => _isUk ? 'Повне ім\'я' : 'Full name';
  String get emailAddress => _isUk ? 'Електронна пошта' : 'Email address';
  String get password => _isUk ? 'Пароль' : 'Password';
  String get invalidEmail => _isUk ? 'Невірна електронна пошта' : 'Invalid email';
  String get minSixChars => _isUk ? 'Мінімум 6 символів' : 'Min 6 characters';
  String get noAccountYet => _isUk ? 'Немає акаунта? ' : "Don't have an account? ";
  String get alreadyHaveAccount => _isUk ? 'Вже маєте акаунт? ' : 'Already have an account? ';

  // Onboarding pages
  String get onboardTitle1 => _isUk ? 'Розумніші маршрути разом.' : 'Smarter routes, together.';
  String get onboardSubtitle1 => _isUk
      ? 'Поділіться поїздкою з тими, хто їде у тому ж напрямку.'
      : 'Share rides with people heading your way.';
  String get onboardTitle2 => _isUk ? 'Підбір у реальному часі.' : 'Real-time matching.';
  String get onboardSubtitle2 => _isUk
      ? 'Водії та пасажири миттєво знаходять одне одного.'
      : 'Drivers and passengers find each other instantly.';
  String get onboardTitle3 => _isUk ? 'Економте CO₂ разом.' : 'Save CO₂ together.';
  String get onboardSubtitle3 => _isUk
      ? 'Кожна спільна поїздка зменшує викиди.'
      : 'Every shared trip reduces emissions.';
  String get skip => _isUk ? 'Пропустити' : 'Skip';
  String get getStarted => _isUk ? 'Почати' : 'Get Started';
  String get continueLabel => _isUk ? 'Продовжити' : 'Continue';

  // Common buttons / dialogs
  String get save => _isUk ? 'Зберегти' : 'Save';
  String get cancel => _isUk ? 'Скасувати' : 'Cancel';
  String get later => _isUk ? 'Пізніше' : 'Later';
  String get openSettings => _isUk ? 'Відкрити налаштування' : 'Open Settings';
  String get gpsOff => _isUk ? 'GPS вимкнено' : 'GPS is off';
  String get gpsOffMessage => _isUk
      ? 'Потрібно увімкнути геолокацію, щоб знаходити поїздки.'
      : 'Location services are required to find rides.';
  String get keepRide => _isUk ? 'Залишити поїздку' : 'Keep ride';
  String get cancelRideQ => _isUk ? 'Скасувати поїздку?' : 'Cancel ride?';
  String get cancelRideMessageDriver =>
      _isUk ? 'Пасажир буде сповіщений.' : 'The passenger will be notified.';
  String get cancelRideMessagePassenger =>
      _isUk ? 'Водій буде сповіщений.' : 'Your driver will be notified.';

  // Offer / Accepted / Looking cards
  String get rideOffer => _isUk ? 'Пропозиція поїздки!' : 'Ride offer!';
  String get accept => _isUk ? 'Прийняти' : 'Accept';
  String get decline => _isUk ? 'Відхилити' : 'Decline';
  String get rideAccepted => _isUk ? 'Поїздку прийнято!' : 'Ride accepted!';
  String get driverNotified => _isUk
      ? 'Водія сповіщено. Залишайтеся на місці.'
      : 'Your driver has been notified. Stay at your location.';
  String get messageDriver => _isUk ? 'Написати водієві' : 'Message Driver';
  String get driverLabel => _isUk ? 'Водій' : 'Driver';
  String get corridorLabel => _isUk ? 'км коридор' : 'km corridor';
  String get seatLabel => _isUk ? 'місце' : 'seat';
  String get seatsLabel => _isUk ? 'місць' : 'seats';

  // Driver home — requests list
  String get noRideRequests => _isUk ? 'Поки немає запитів' : 'No ride requests yet';
  String get noRideRequestsDesc => _isUk
      ? 'Пасажири біля вашого маршруту з\'являться тут.'
      : 'Passengers near your route will appear here.';
  String get rideRequests => _isUk ? 'Запити на поїздку' : 'Ride requests';

  // Account & Security screen
  String get displayName => _isUk ? 'Ім\'я' : 'Display name';
  String get changePassword => _isUk ? 'Змінити пароль' : 'Change password';
  String get currentPassword => _isUk ? 'Поточний пароль' : 'Current password';
  String get newPassword => _isUk ? 'Новий пароль' : 'New password';
  String get confirmNewPassword =>
      _isUk ? 'Підтвердити новий пароль' : 'Confirm new password';
  String get updatePassword => _isUk ? 'Оновити пароль' : 'Update Password';
  String get passwordsNotMatch =>
      _isUk ? 'Нові паролі не співпадають' : 'New passwords do not match';
  String get passwordTooShort => _isUk
      ? 'Пароль має містити мінімум 6 символів'
      : 'Password must be at least 6 characters';
  String get passwordUpdated => _isUk ? 'Пароль оновлено' : 'Password updated';
  String get networkError => _isUk ? 'Помилка мережі' : 'Network error';
  String get nameUpdated => _isUk ? 'Ім\'я оновлено' : 'Name updated';
  String get emailCopied => _isUk ? 'Email скопійовано' : 'Email copied';

  // Chat
  String get activeTrip => _isUk ? 'Активна поїздка' : 'Active trip';
  String get noMessages => _isUk
      ? 'Поки немає повідомлень.\nПривітайтеся!'
      : 'No messages yet.\nSay hello!';
  String get messageHint => _isUk ? 'Повідомлення…' : 'Message…';

  // Trip history
  String get tripHistory => _isUk ? 'Історія поїздок' : 'Trip History';
  String get noTripsYet => _isUk ? 'Поки немає поїздок' : 'No trips yet';
  String get firstRidePrompt => _isUk
      ? 'Завершіть першу поїздку, щоб побачити її тут.'
      : 'Complete your first ride to see it here.';

  // Trip planner / search sheets
  String get selectOriginLocation =>
      _isUk ? 'Виберіть початкове місце' : 'Select an origin location';
  String get selectDestinationLocation =>
      _isUk ? 'Виберіть місце призначення' : 'Select a destination location';
  String get tripPlannedSuccess =>
      _isUk ? 'Поїздку успішно заплановано!' : 'Trip planned successfully!';
  String get locationNotAvailable =>
      _isUk ? 'Геолокація недоступна' : 'Location not available';
  String get requestSent => _isUk ? 'Запит надіслано!' : 'Request sent!';
  String get requestFailed =>
      _isUk ? 'Не вдалося надіслати запит' : 'Failed to send request';

  // Promotions
  String get promotionsAndRewards =>
      _isUk ? 'Акції та винагороди' : 'Promotions & Rewards';
  String get activeOffers => _isUk ? 'Активні пропозиції' : 'Active Offers';
  String get expired => _isUk ? 'Минулі' : 'Expired';
  String get noPromotions =>
      _isUk ? 'Немає доступних акцій' : 'No promotions available';

  // Rating sheet
  String get rateYourDriver => _isUk ? 'Оцінити водія' : 'Rate your driver';
  String get rateYourPassenger =>
      _isUk ? 'Оцінити пасажира' : 'Rate your passenger';
  String get howWasExperience =>
      _isUk ? 'Як вам поїздка?' : 'How was your experience?';
  String get addCommentOptional =>
      _isUk ? 'Додати коментар (необов\'язково)' : 'Add a comment (optional)';
  String get submit => _isUk ? 'Надіслати' : 'Submit';
  String get skipRating => _isUk ? 'Пропустити' : 'Skip';

  // Car edit sheet
  String get myCar => _isUk ? 'Моє авто' : 'My Car';
  String get carMake => _isUk ? 'Марка' : 'Make';
  String get carModel => _isUk ? 'Модель' : 'Model';
  String get carColor => _isUk ? 'Колір' : 'Color';
  String get carPlate => _isUk ? 'Номерний знак' : 'Plate';
  String get carMakeHint => _isUk ? 'напр. Toyota' : 'e.g. Toyota';
  String get carModelHint => _isUk ? 'напр. Corolla' : 'e.g. Corolla';
  String get carColorHint => _isUk ? 'напр. Сріблястий' : 'e.g. Silver';
  String get carPlateHint => _isUk ? 'напр. КА 12345' : 'e.g. KR 12345';
  String get carInfoSaved =>
      _isUk ? 'Інформацію про авто збережено!' : 'Car info saved!';

  // Misc tiles / sheets
  String get testNotificationSent =>
      _isUk ? 'Тестове сповіщення надіслано!' : 'Test notification sent!';
  String get mapStyle => _isUk ? 'Стиль карти' : 'Map Style';
  String get planATrip => _isUk ? 'Запланувати поїздку' : 'Plan a Trip';
  String get findPlannedTrips =>
      _isUk ? 'Знайти заплановані поїздки' : 'Find Planned Trips';
  String get testNotification =>
      _isUk ? 'Тестове сповіщення' : 'Test Notification';
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
