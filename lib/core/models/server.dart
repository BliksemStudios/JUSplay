import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class Server {
  final String id;
  final String name;
  final String url;
  final String username;
  final String password;
  final String token;
  final String salt;

  const Server({
    required this.id,
    required this.name,
    required this.url,
    required this.username,
    required this.password,
    required this.token,
    required this.salt,
  });

  /// Creates a [Server] and automatically generates the auth token and salt.
  ///
  /// The salt is a random 12-character hex string. The token is the MD5 hash
  /// of the password concatenated with the salt.
  factory Server.create({
    required String id,
    required String name,
    required String url,
    required String username,
    required String password,
  }) {
    final salt = _generateSalt();
    final token = _generateToken(password, salt);
    return Server(
      id: id,
      name: name,
      url: url.endsWith('/') ? url.substring(0, url.length - 1) : url,
      username: username,
      password: password,
      token: token,
      salt: salt,
    );
  }

  /// Generates a random 12-character hex salt.
  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(6, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generates the MD5 authentication token: md5(password + salt).
  static String _generateToken(String password, String salt) {
    final data = utf8.encode(password + salt);
    return md5.convert(data).toString();
  }

  /// Returns the Subsonic API authentication query parameters.
  ///
  /// Includes:
  /// - `u` - username
  /// - `t` - authentication token (md5(password + salt))
  /// - `s` - salt
  /// - `v` - API version (1.16.1)
  /// - `c` - client identifier (jusplay)
  /// - `f` - response format (json)
  Map<String, String> authParams() {
    return {
      'u': username,
      't': token,
      's': salt,
      'v': '1.16.1',
      'c': 'jusplay',
      'f': 'json',
    };
  }

  /// Regenerates the token and salt, returning a new [Server] instance.
  Server refreshAuth() {
    final newSalt = _generateSalt();
    final newToken = _generateToken(password, newSalt);
    return Server(
      id: id,
      name: name,
      url: url,
      username: username,
      password: password,
      token: newToken,
      salt: newSalt,
    );
  }

  Server copyWith({
    String? id,
    String? name,
    String? url,
    String? username,
    String? password,
    String? token,
    String? salt,
  }) {
    final newPassword = password ?? this.password;
    final newSalt = salt ?? this.salt;
    final newToken = (password != null || salt != null)
        ? _generateToken(newPassword, newSalt)
        : (token ?? this.token);

    return Server(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      username: username ?? this.username,
      password: newPassword,
      token: newToken,
      salt: newSalt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'username': username,
      'password': password,
      'token': token,
      'salt': salt,
    };
  }

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      token: json['token'] as String,
      salt: json['salt'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Server && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Server(id: $id, name: $name, url: $url)';
}
