import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'response_cache.dart';

const defaultServer = 'https://efarm360.danov.sn';

/// Erreur renvoyée par l'API : l'application se base sur [code], jamais sur [message].
class ApiException implements Exception {
  ApiException(this.code, this.message, {this.status, this.details});
  final String code;
  final String message;
  final int? status;
  final Map<String, dynamic>? details;

  bool get isNetwork => code == 'reseau';
  @override
  String toString() => message;
}

/// Jetons et adresse du serveur, dans le stockage sécurisé du téléphone.
class TokenStore {
  TokenStore([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;

  Future<String?> get access => _s.read(key: 'access');
  Future<String?> get refresh => _s.read(key: 'refresh');
  Future<String> get server async => (await _s.read(key: 'server')) ?? defaultServer;

  Future<void> saveTokens(String access, String refresh) async {
    await _s.write(key: 'access', value: access);
    await _s.write(key: 'refresh', value: refresh);
  }

  Future<void> saveServer(String url) => _s.write(key: 'server', value: url);
  Future<void> saveProfile(String json) => _s.write(key: 'profile', value: json);
  Future<String?> get profile => _s.read(key: 'profile');

  Future<void> clear() async {
    await _s.delete(key: 'access');
    await _s.delete(key: 'refresh');
    await _s.delete(key: 'profile');
  }
}

/// Client HTTP de l'API mobile `/api/mobile/v1`.
/// Rafraîchit le jeton d'accès sur `401 jeton_invalide` (un seul rafraîchissement à la fois), puis rejoue la requête.
class ApiClient {
  ApiClient(this.tokens, {Dio? dio, this.onSessionExpired, ResponseCache? cache})
      : _dio = dio ?? Dio(),
        _cache = cache ?? MemoryCache() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 40)
      ..headers = {'Accept': 'application/json'}
      ..validateStatus = (_) => true;
  }

  final TokenStore tokens;
  final Dio _dio;
  void Function()? onSessionExpired;
  Completer<bool>? _refreshing;
  final ResponseCache _cache;

  /// Renseigné quand la dernière lecture a été servie depuis la copie locale (réseau coupé).
  final ValueNotifier<DateTime?> offlineSince = ValueNotifier(null);

  /// Récupère le contrat OpenAPI publié par le serveur (route publique, JSON brut) ; copie locale si le réseau est coupé.
  Future<Map<String, dynamic>?> contract() async {
    const key = 'contract';
    try {
      final res = await _dio.get<dynamic>('${await _base()}/openapi.json');
      if (res.statusCode == 200 && res.data is Map) {
        final j = Map<String, dynamic>.from(res.data as Map);
        await _cache.write(key, j);
        return j;
      }
      return null;
    } on DioException {
      return _cache.read(key);
    }
  }

  Future<void> clearCache() async {
    offlineSince.value = null;
    await _cache.clear();
  }

  String _cacheKey(String base, String path, Map<String, dynamic>? query) {
    final q = (query?.entries.where((e) => e.value != null).map((e) => '${e.key}=${e.value}').toList() ?? [])..sort();
    return '$base$path?${q.join('&')}';
  }

  Future<String> _base() async {
    // On accepte aussi une adresse collée avec le chemin de l'API (…/api/mobile/v1/status) : seule la racine du site compte.
    final s = (await tokens.server).trim().replaceFirst(RegExp(r'/api(/.*)?$'), '').replaceAll(RegExp(r'/+$'), '');
    return '$s/api/mobile/v1';
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query, bool auth = true}) =>
      _send<T>('GET', path, query: query, auth: auth);
  Future<T> post<T>(String path, {Object? body, bool auth = true}) =>
      _send<T>('POST', path, body: body ?? <String, dynamic>{}, auth: auth);

  /// Liste paginée : renvoie les éléments et `meta`.
  Future<({List<Map<String, dynamic>> items, Map<String, dynamic> meta})> list(String path, {Map<String, dynamic>? query}) async {
    final r = await _raw('GET', path, query: query, auth: true);
    final data = r['data'];
    return (
      items: [for (final e in (data as List? ?? const [])) Map<String, dynamic>.from(e as Map)],
      meta: Map<String, dynamic>.from(r['meta'] as Map? ?? const {}),
    );
  }

  Future<T> _send<T>(String method, String path, {Map<String, dynamic>? query, Object? body, required bool auth}) async {
    final r = await _raw(method, path, query: query, body: body, auth: auth);
    return r['data'] as T;
  }

  Future<Map<String, dynamic>> _raw(String method, String path,
      {Map<String, dynamic>? query, Object? body, required bool auth, bool retried = false}) async {
    final Response<dynamic> res;
    try {
      final headers = <String, dynamic>{};
      if (auth) {
        final t = await tokens.access;
        if (t != null) headers['Authorization'] = 'Bearer $t';
      }
      res = await _dio.request<dynamic>('${await _base()}$path',
          data: body, queryParameters: query, options: Options(method: method, headers: headers));
    } on DioException catch (e) {
      if (method == 'GET' && auth) {
        final hit = await _cache.read(_cacheKey(await _base(), path, query));
        if (hit != null) {
          offlineSince.value ??= DateTime.now();
          return hit;
        }
      }
      throw ApiException('reseau', 'Connexion impossible. Vérifiez votre réseau.', details: {'type': e.type.name});
    }
    final json = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final status = res.statusCode ?? 0;
    if (json['success'] == true) {
      if (method == 'GET' && auth) {
        offlineSince.value = null;
        await _cache.write(_cacheKey(await _base(), path, query), json);
      }
      return json;
    }

    if (json.isEmpty && (status == 404 || status == 405)) {
      throw ApiException('non_disponible', 'Cette fonction n\'est pas disponible sur ce serveur.', status: status);
    }
    if (json.isEmpty && status < 500) {
      throw ApiException('reponse_invalide', 'Réponse inattendue du serveur : vérifiez son adresse.', status: status);
    }
    final err = json['error'] is Map ? Map<String, dynamic>.from(json['error'] as Map) : <String, dynamic>{};
    final code = (err['code'] as String?) ?? (status >= 500 ? 'erreur_serveur' : 'erreur');
    if (auth && status == 401 && code == 'jeton_invalide' && !retried) {
      if (await _refresh()) return _raw(method, path, query: query, body: body, auth: auth, retried: true);
      throw ApiException('session_expiree', 'Votre session a expiré. Reconnectez-vous.', status: 401);
    }
    if (auth && status == 401 && (code == 'compte_desactive' || code == 'non_authentifie')) onSessionExpired?.call();
    throw ApiException(code, (err['message'] as String?) ?? 'Erreur $status.', status: status,
        details: err['details'] is Map ? Map<String, dynamic>.from(err['details'] as Map) : null);
  }

  Future<bool> _refresh() async {
    if (_refreshing != null) return _refreshing!.future;
    final c = _refreshing = Completer<bool>();
    try {
      final rt = await tokens.refresh;
      if (rt == null) {
        c.complete(false);
      } else {
        try {
          final r = await _raw('POST', '/auth/refresh', body: {'refresh_token': rt}, auth: false);
          final d = r['data'] as Map;
          await tokens.saveTokens(d['access_token'] as String, d['refresh_token'] as String);
          c.complete(true);
        } on ApiException catch (e) {
          // Réseau coupé : on garde les jetons ; refus du serveur : session perdue
          if (!e.isNetwork) {
            await tokens.clear();
            onSessionExpired?.call();
          }
          c.complete(false);
        }
      }
    } catch (_) {
      if (!c.isCompleted) c.complete(false);
    }
    final ok = await c.future;
    _refreshing = null;
    return ok;
  }
}
