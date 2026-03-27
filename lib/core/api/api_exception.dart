/// Exception thrown when the Subsonic API returns an error response.
class SubsonicApiException implements Exception {
  /// The Subsonic error code.
  final int code;

  /// The human-readable error message from the server.
  final String message;

  const SubsonicApiException({
    required this.code,
    required this.message,
  });

  /// A generic error.
  static const int genericError = 0;

  /// Required parameter is missing.
  static const int missingParameter = 10;

  /// Incompatible Subsonic REST protocol version. Client must upgrade.
  static const int clientOutdated = 20;

  /// Incompatible Subsonic REST protocol version. Server must upgrade.
  static const int serverOutdated = 30;

  /// Wrong username or password.
  static const int wrongCredentials = 40;

  /// Token authentication not supported for LDAP users.
  static const int tokenAuthNotSupported = 41;

  /// User is not authorized for the given operation.
  static const int notAuthorized = 50;

  /// The trial period for the Subsonic server is over.
  static const int trialExpired = 60;

  /// The requested data was not found.
  static const int notFound = 70;

  factory SubsonicApiException.fromJson(Map<String, dynamic> json) {
    return SubsonicApiException(
      code: json['code'] as int? ?? genericError,
      message: json['message'] as String? ?? 'Unknown Subsonic API error',
    );
  }

  @override
  String toString() => 'SubsonicApiException($code): $message';
}
