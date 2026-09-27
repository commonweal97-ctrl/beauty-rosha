class ApiConfig {
  // Используй закодированный URL вместо кириллицы
  static const String baseUrl = 'https://xn--80abvyjk6cts.xn--p1ai';
  
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}