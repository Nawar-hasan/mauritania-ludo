class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'http://10.0.2.2:3000/matches',
  );

  static String resolveAssetUrl(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    final root = baseUrl.endsWith('/api/v1') ? baseUrl.substring(0, baseUrl.length - 7) : baseUrl;
    return value.startsWith('/') ? '$root$value' : '$root/$value';
  }
}
