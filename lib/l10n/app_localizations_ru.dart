// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppL10nRu extends AppL10n {
  AppL10nRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Telegram Liquid';

  @override
  String get signInSubtitle => 'Войдите по номеру телефона, чтобы продолжить';

  @override
  String get enterCodeTitle => 'Введите код';

  @override
  String get enterCodeSubtitle => 'Мы отправили код в ваш Telegram';

  @override
  String get passwordTitle => 'Ещё один шаг';

  @override
  String get passwordSubtitle => 'Аккаунт защищён облачным паролем';

  @override
  String get phoneNumber => 'Номер телефона';

  @override
  String get phoneHint => '+7 900 000 00 00';

  @override
  String get confirmationCode => 'Код подтверждения';

  @override
  String get codeHint => '• • • • •';

  @override
  String get twoStepVerification => 'Двухэтапная проверка';

  @override
  String get cloudPasswordHelper => 'Облачный пароль защищает ваш аккаунт';

  @override
  String get password => 'Пароль';

  @override
  String get sendCode => 'Отправить код';

  @override
  String get continueAction => 'Продолжить';

  @override
  String get demoAnyPhone => 'Демо-режим — подойдёт любой номер';

  @override
  String get demoCodeHint => 'Демо-режим — код 12345';

  @override
  String get demoPasswordHint => 'Демо-режим — пароль «telegram»';

  @override
  String get chats => 'Чаты';

  @override
  String chatsWithCount(int count) {
    return 'Чаты ($count)';
  }

  @override
  String get contacts => 'Контакты';

  @override
  String get calls => 'Звонки';

  @override
  String get settings => 'Настройки';

  @override
  String get searchChats => 'Поиск чатов и сообщений';

  @override
  String get searchContacts => 'Поиск контактов';

  @override
  String get searchInChat => 'Поиск в чате';

  @override
  String get searchInChatHint => 'Начните вводить, чтобы искать в переписке';

  @override
  String get noMatches => 'Ничего не найдено';

  @override
  String get nothingFound => 'Ничего не найдено';

  @override
  String get tryAnotherSearch => 'Попробуйте другой запрос';

  @override
  String get noChatsInFolder => 'В этой папке нет чатов';

  @override
  String get pickAnotherFolder => 'Выберите другую папку выше';

  @override
  String get edit => 'Изменить';

  @override
  String get chatList => 'Список чатов';

  @override
  String get markAllAsRead => 'Прочитать все';

  @override
  String get markAsRead => 'Отметить прочитанным';

  @override
  String get pinToTop => 'Закрепить';

  @override
  String get unpin => 'Открепить';

  @override
  String get mute => 'Выключить звук';

  @override
  String get unmute => 'Включить звук';

  @override
  String get deleteChat => 'Удалить чат';

  @override
  String get deleteChatMessage => 'Переписка будет убрана из списка.';

  @override
  String chatDeleted(String title) {
    return 'Чат «$title» удалён';
  }

  @override
  String get newMessageHint =>
      'Новое сообщение — выберите контакт на вкладке «Контакты»';

  @override
  String get reply => 'Ответить';

  @override
  String get copy => 'Копировать';

  @override
  String get forward => 'Переслать';

  @override
  String get forwardTo => 'Переслать в';

  @override
  String forwardedTo(String title) {
    return 'Переслано в «$title»';
  }

  @override
  String get delete => 'Удалить';

  @override
  String get message => 'Сообщение';

  @override
  String get editMessage => 'Редактирование';

  @override
  String replyToSender(String name) {
    return 'Ответ: $name';
  }

  @override
  String get edited => 'изменено';

  @override
  String get typing => 'печатает…';

  @override
  String get today => 'Сегодня';

  @override
  String get yesterday => 'Вчера';

  @override
  String get statusSending => 'Отправляется…';

  @override
  String get statusSent => 'Отправлено';

  @override
  String get statusDelivered => 'Доставлено';

  @override
  String get statusRead => 'Прочитано';

  @override
  String get statusFailed => 'Не доставлено';

  @override
  String get send => 'Отправить';

  @override
  String get photo => 'Фото';

  @override
  String get file => 'Файл';

  @override
  String get location => 'Геопозиция';

  @override
  String get recent => 'Недавнее';

  @override
  String get cameraRoll => 'Галерея';

  @override
  String cameraRollSubtitle(int count) {
    return '$count объектов';
  }

  @override
  String get documents => 'Документы';

  @override
  String get browseFiles => 'Выбрать файлы';

  @override
  String get locationNotWired => 'Отправка геопозиции пока не подключена';

  @override
  String get chatInfo => 'Информация о чате';

  @override
  String get clearHistory => 'Очистить историю';

  @override
  String get clearHistoryTitle => 'Очистить историю?';

  @override
  String get clearHistoryMessage =>
      'Все сообщения этого чата будут удалены на этом устройстве.';

  @override
  String get clear => 'Очистить';

  @override
  String get cancel => 'Отмена';

  @override
  String get call => 'Звонок';

  @override
  String get video => 'Видео';

  @override
  String get search => 'Поиск';

  @override
  String get info => 'Информация';

  @override
  String get notifications => 'Уведомления';

  @override
  String get mediaLinksDocs => 'Медиа, ссылки и файлы';

  @override
  String get chatWallpaper => 'Обои чата';

  @override
  String get noMediaYet => 'В этом чате пока нет медиа';

  @override
  String photosCount(int count) {
    return '$count фото';
  }

  @override
  String get presenceOnline => 'в сети';

  @override
  String get presenceLastSeen => 'был(а) недавно';

  @override
  String get presenceBot => 'бот';

  @override
  String get presenceSaved => 'ваше облачное хранилище';

  @override
  String membersCount(int count) {
    return '$count участников';
  }

  @override
  String subscribersCount(String count) {
    return '$count подписчиков';
  }

  @override
  String contactsCount(int count) {
    return '$count контактов';
  }

  @override
  String onlineCount(int count) {
    return '$count в сети';
  }

  @override
  String get addContactHint =>
      'Добавление контактов работает только с живым TDLib';

  @override
  String get all => 'Все';

  @override
  String get missed => 'Пропущенные';

  @override
  String get noCalls => 'Здесь пока нет звонков';

  @override
  String get callCancelled => 'Отменён';

  @override
  String callingName(String name) {
    return 'Звоним: $name…';
  }

  @override
  String get newCallHint => 'Звонки работают только с живым TDLib';

  @override
  String get appearance => 'Оформление';

  @override
  String get wallpaper => 'Обои чата';

  @override
  String get wallpaperSubtitle => 'Стекло преломляет то, что за ним.';

  @override
  String get choose => 'Выбрать';

  @override
  String get autoNightMode => 'Авторежим';

  @override
  String get autoNightModeSubtitle => 'Следовать системной теме';

  @override
  String get darkMode => 'Тёмная тема';

  @override
  String get reduceTransparency => 'Меньше прозрачности';

  @override
  String get reduceTransparencySubtitle => 'Останавливает анимацию обоев';

  @override
  String get glassIntensity => 'Интенсивность стекла';

  @override
  String get messageTextSize => 'Размер текста сообщений';

  @override
  String get textSizeSample => 'Съешь ещё этих мягких французских булок';

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Системный';

  @override
  String get unreadMessages => 'Непрочитанные сообщения';

  @override
  String get voiceUnavailable => 'Не удалось записать';

  @override
  String get voiceUnavailableMessage =>
      'Разрешите доступ к микрофону, чтобы отправлять голосовые сообщения.';

  @override
  String get slideToCancel => 'Влево — отмена';

  @override
  String get releaseToCancel => 'Отпустите для отмены';

  @override
  String get ok => 'OK';

  @override
  String get archive => 'В архив';

  @override
  String get unarchive => 'Из архива';

  @override
  String get archivedChats => 'Архив';

  @override
  String get archiveEmpty => 'В архиве пусто';

  @override
  String get messagesSection => 'Сообщения';

  @override
  String get pinnedMessage => 'Закреплённое сообщение';

  @override
  String get pinMessage => 'Закрепить';

  @override
  String get unpinMessage => 'Открепить';

  @override
  String get attachment => 'Вложение';

  @override
  String get privacy => 'Конфиденциальность';

  @override
  String get messageNotifications => 'Уведомления о сообщениях';

  @override
  String get messageNotificationsSubtitle =>
      'Держит соединение, чтобы сообщения приходили при закрытом приложении';

  @override
  String get readReceipts => 'Отчёты о прочтении';

  @override
  String get activeSessions => 'Активные сеансы';

  @override
  String get backend => 'Подключение';

  @override
  String get mode => 'Режим';

  @override
  String get backendLive =>
      'Подключено через официальный JSON-интерфейс TDLib.';

  @override
  String get backendDemo =>
      'Демо-данные. Передайте --dart-define=TELEGRAM_API_ID и TELEGRAM_API_HASH и добавьте libtdjson.so, чтобы работать с реальными серверами Telegram.';

  @override
  String get logOut => 'Выйти';

  @override
  String get logOutTitle => 'Выйти из аккаунта?';

  @override
  String get logOutMessage =>
      'Чтобы снова читать переписку, придётся войти заново.';

  @override
  String get aboutTitle => 'Об этой сборке';

  @override
  String get aboutBody =>
      'Telegram-клиент на Flutter, отрисованный материалом Liquid Glass из iOS 26. Качество стекла подстраивается под устройство.';

  @override
  String get profileEditHint =>
      'Редактирование профиля работает только с живым бэкендом';

  @override
  String get myStory => 'Моя история';

  @override
  String get replyToStory => 'Ответить на историю';

  @override
  String get errorInvalidPhone => 'Введите корректный номер телефона';

  @override
  String get errorInvalidCode => 'Неверный код — в демо-режиме нужен 12345';

  @override
  String get errorInvalidPassword =>
      'Неверный пароль — в демо-режиме нужен «telegram»';

  @override
  String get draft => 'Черновик';

  @override
  String get folderAll => 'Все чаты';

  @override
  String get folderPersonal => 'Личные';

  @override
  String get folderGroups => 'Группы';

  @override
  String get folderChannels => 'Каналы';

  @override
  String get folderUnread => 'Непрочитанные';

  @override
  String get folderBots => 'Боты';

  @override
  String get camera => 'Камера';

  @override
  String get chooseFromGallery => 'Выбрать из галереи';

  @override
  String get attachmentFailed => 'Не удалось приложить файл';

  @override
  String get diagnostics => 'Диагностика';

  @override
  String get diagnosticsHint =>
      'Что сообщил бэкенд Telegram с момента запуска.';

  @override
  String get diagnosticsEmpty => 'Пока ничего не записано.';

  @override
  String get diagnosticsCopied => 'Лог скопирован';

  @override
  String get connecting => 'Подключаемся к Telegram…';

  @override
  String get demoBanner =>
      'Работают демо-данные — код на реальный номер не придёт.';

  @override
  String get openDiagnostics => 'Почему?';

  @override
  String get proxy => 'Прокси';

  @override
  String get proxyHint => 'Пригодится, если Telegram недоступен напрямую.';

  @override
  String get proxyServer => 'Сервер';

  @override
  String get proxyPort => 'Порт';

  @override
  String get proxySecret => 'Секрет';

  @override
  String get proxyUsername => 'Логин';

  @override
  String get proxyPassword => 'Пароль';

  @override
  String get proxyUse => 'Использовать прокси';

  @override
  String get proxyEnabled => 'Прокси включён';

  @override
  String get proxyDisabled => 'Прокси выключен';

  @override
  String get proxyInvalid => 'Укажите сервер и порт';

  @override
  String get save => 'Сохранить';

  @override
  String get connection => 'Соединение';

  @override
  String get proxyOff => 'Выключен';
}
