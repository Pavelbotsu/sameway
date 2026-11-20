/// EN / UK sample text for component goldens, from
/// design-pack/l10n/copy_deck.csv (key in the comment). Test data only:
/// the app's strings come from the l10n files.
class SampleText {
  const SampleText(this.lang);
  final String lang;
  bool get uk => lang == 'uk';
  String _t(String en, String ukText) => uk ? ukText : en;

  // Buttons
  String get bookSeat => _t('Book seat · 16 zł', 'Забронювати · 16 zł'); // i_book_seat_16_z
  String get startSharing => _t('Start sharing route', 'Шукати попутників'); // d_start_sharing_route
  String get keepBrowsing => _t('Keep browsing', 'Переглядати далі'); // i_keep_browsing
  String get cancelSeat => _t('Cancel seat', 'Скасувати місце'); // i_cancel_seat
  String get leaveWithout => _t('Leave without Olena', 'Їхати без пасажирки (Olena)'); // i_leave_without_olena
  String availableAt(String time, int min) =>
      _t('Available at $time · in $min min', 'Доступно о $time · за $min хв'); // i_available_at_0910_in_6

  // Fields
  String get whereTo => _t('Where to?', 'Куди їдемо?'); // p_where_to
  String get email => _t('Email', 'Пошта'); // errors_email
  String get emailError => _t('Enter a full email, like name@example.com',
      'Введи повну адресу, наприклад name@example.com'); // errors_enter_a_full_email_like (UK not in deck)

  // Selection
  String get instantBooking => _t('Instant booking', 'Миттєве бронювання'); // i_instant_booking
  String get askMe => _t('Ask me', 'Питати мене'); // i_ask_me
  String minutes(int n) => _t('$n min', '$n хв');
  String get autoAccept => _t('Auto-accept your people', 'Автоматично брати своїх'); // d_autoaccept_your_people
  String get fewerSeats => _t('Fewer seats', 'Менше місць'); // d_fewer_seats
  String get moreSeats => _t('More seats', 'Більше місць'); // d_more_seats

  // Status badges
  String get confirmed => _t('Confirmed', 'Підтверджено'); // s_confirmed
  String get requested => _t('Requested', 'Запит надіслано'); // s_requested
  String get searching => _t('Searching', 'Шукаємо водія'); // s_searching
  String get answerBy => _t('Answer by Thu 10:00', 'Відповісти до чт 10:00'); // i_answer_by_thu_1000

  // Ride card
  String get arrival => _t('→ 11:20 · 2 h 20', '→ 11:20 · 2 год 20');
  String get seatsLeft => _t('2 seats left', 'Ще 2 місця'); // i_2_seats_left
  List<String> get stops =>
      uk ? const ['Краків', 'Тарнів', 'Ряшів'] : const ['Kraków', 'Tarnów', 'Rzeszów'];
  String get yourPeople => _t('Your people', 'Свої попутники'); // d_your_people
  String get instant => _t('Instant', 'Миттєво'); // i_instant

  // Driver offer
  String get offerTitle => _t('Kasia · 9 min', 'Kasia · 9 хв');
  String get offerSubtitle => _t('Walk 450 m · drops you at the door',
      'Пішки 450 м · довезе під самі двері'); // p_walk_450_m + p_drops_you_at_the_door
  String get request => _t('Request', 'Запит'); // p_request

  // Pickup code
  String get yourPickupCode => _t('Your pickup code', 'Твій код зустрічі'); // i_your_pickup_code

  // Price, fuel, seats, key–value
  String get pricePerSeat => _t('Price per seat', 'Ціна за місце'); // i_price_per_seat
  String get fuelCovered => _t('Fuel covered', 'Покрито пального'); // i_fuel_covered
  String get fuelCoveredValue => _t('24 of 65 zł', '24 з 65 zł');
  String get seatsByPart => _t('Seats by part of the route', 'Хто де сидить'); // i_seats_by_part_of_the
  String segment(int from, int to) => '${stops[from]} → ${stops[to]}';
  String seatsTaken(int n, int of) => _t('$n of $of seats taken', 'Зайнято $n з $of місць');
  String get fuelForRoute => _t('Fuel for the route', 'Пальне на маршрут'); // i_fuel_for_the_route
  String get suggestedPerSeat => _t('Suggested per seat', 'Рекомендовано за місце'); // rules_suggested_per_seat

  // Feedback
  String get routeEnded => _t('Route ended', 'Маршрут завершено'); // d_route_ended_passengers_cant_see
  String get undo => _t('Undo', 'Відмінити'); // s_undo
  String get locationOff => _t('Location access is off.', 'Доступ до геолокації вимкнено.'); // d_location_access_is_off_passengers
  String get openSettings => _t('Open Settings', 'Відкрити Параметри'); // x_open_settings

  // Sheet, list
  String get cancelYourSeat => _t('Cancel your seat?', 'Скасувати твоє місце?'); // i_cancel_your_seat
  String get yourBooking => _t('Your booking', 'Твоє бронювання'); // i_your_booking
  String get requestsWhileDriving => _t('Requests while driving', 'Запити за кермом'); // d_requests_while_driving
}
