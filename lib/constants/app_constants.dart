class AppConstants {
  // Together AI API Configuration
  static const String apiKey = 'febba54eacf451bd69f0335d5c5e47bafd463a807277e8a3d2d7706db639fdb6';
  static const String togetherUrl = 'https://api.together.xyz/v1/chat/completions';
  static const String model = 'ServiceNow-AI/Apriel-1.6-15b-Thinker';

  // System Prompt (in Bulgarian)
  static const String systemPrompt =
      'You are just an AI assistant';

  // App Configuration
  static const String appTitle = 'NOA AI Очила';
  static const String language = 'bg-BG';

  // UI Strings (Bulgarian)
  static const Map<String, String> strings = {
    'initialStatus': 'Натисни "Свържи" за да започнеш',
    'connecting': 'Свързване...',
    'connected': 'Свързан! Готов за употреба.',
    'connectionFailed': 'Неуспешно свързване. Опитай пак.',
    'listening': 'Слушам...',
    'noSpeech': 'Не чух нищо!',
    'thinking': 'Мисля...',
    'ready': 'Готов',
    'takingPhoto': 'Правя снимка...',
    'analyzing': 'Анализирам...',
    'photoError': 'Грешка при снимане',
    'memoryCleared': 'Паметта е изчистена!',
    'newConversation': 'Нов разговор!',
    'lastResponse': 'Последен отговор:',
    'controls': 'Контроли:',
    'conversation': 'Разговор:',
    'connectButton': 'Свържи с очилата',
    'voiceTestButton': 'Тест: Глас',
    'photoTestButton': 'Тест: Снимка',
    'clearButton': 'Изчисти',
    'tapControl': '👆 1 докосване на очилата',
    'tapAction': 'Гласов разговор с AI',
    'photoDescription': 'Какво виждаш на тази снимка от моите умни очила? Бъди кратък.',
  };

  // AI Response Configuration
  static const int maxTokens = 1024;
  static const Duration speechListenDuration = Duration(seconds: 8);

  // Display Configuration
  static const int maxDisplayLength = 150;
}
