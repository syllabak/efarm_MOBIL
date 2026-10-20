import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'server_support.dart';
import 'response_cache.dart';

/// Profil renvoyé par `/auth/login` et `/me`.
class Profile {
  Profile(this.raw);
  final Map<String, dynamic> raw;

  bool get isFarm => raw['type'] == 'ferme';
  bool get isVet => raw['type'] == 'veterinaire';
  int get id => raw['id'] as int;
  String get email => (raw['email'] as String?) ?? '';
  String get fullName => [raw['prenom'], raw['nom']].whereType<String>().where((s) => s.isNotEmpty).join(' ');
  String get role => (raw['role'] as String?) ?? (raw['profil'] as String?) ?? '';
  bool get allSites => raw['tous_les_sites'] == true;
  int? get siteId => raw['site_id'] as int?;
  String? get companyName => (raw['societe'] as Map?)?['nom'] as String?;
  Map<String, dynamic>? get licence => (raw['licence'] as Map?)?.cast<String, dynamic>();
  bool get twoFactor => raw['deux_facteurs'] == true;

  /// Fonctionnalité incluse dans l'offre (true par défaut tant que le serveur ne l'a pas indiquée).
  bool has(String feature) => (raw['fonctions'] as Map?)?[feature] != false;
  bool get isOwnerVet => raw['titulaire'] == true;
  String? get cabinetOwner => raw['cabinet_titulaire'] as String?;

  /// Droit sur une rubrique du cabinet (le titulaire a tout).
  bool can(String section) => isOwnerVet || (raw['droits'] as Map?)?[section] == true;

  /// Saisie du rapport journalier : mêmes rôles que sur le web.
  bool get canReport => const {'admin', 'responsable', 'employe'}.contains(role);
}

sealed class LoginResult {}

class LoginOk extends LoginResult {}

class LoginNeeds2fa extends LoginResult {
  LoginNeeds2fa(this.token);
  final String token;
}

class LoginNeedsCompany extends LoginResult {
  LoginNeedsCompany(this.choices);
  final List<({String code, String name})> choices;
}

final tokenStoreProvider = Provider<TokenStore>((_) => TokenStore());

final apiProvider = Provider<ApiClient>((ref) {
  final api = ApiClient(ref.watch(tokenStoreProvider), cache: defaultCache());
  api.onSessionExpired = () => ref.read(sessionProvider.notifier).expire();
  return api;
});

final sessionProvider = AsyncNotifierProvider<SessionNotifier, Profile?>(SessionNotifier.new);

class SessionNotifier extends AsyncNotifier<Profile?> {
  ApiClient get _api => ref.read(apiProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  // `dart:io` Platform n'existe pas sur le web : on passe par defaultTargetPlatform.
  String get _platform => kIsWeb ? 'web' : switch (defaultTargetPlatform) { TargetPlatform.iOS => 'ios', TargetPlatform.android => 'android', _ => 'autre' };
  String get _device => kIsWeb ? 'web' : defaultTargetPlatform.name;

  @override
  Future<Profile?> build() async {
    if (await _tokens.access == null) return null;
    useContract(await _api.contract());
    final cached = await _tokens.profile;
    try {
      final me = await _api.get<Map>('/me');
      final p = Profile(Map<String, dynamic>.from(me));
      await _tokens.saveProfile(jsonEncode(p.raw));
      return p;
    } on ApiException catch (e) {
      // Hors ligne : on garde le dernier profil connu (le cabinet vétérinaire fonctionne sans réseau)
      if (e.isNetwork && cached != null) return Profile(Map<String, dynamic>.from(jsonDecode(cached) as Map));
      if (e.isNetwork) rethrow;
      await _tokens.clear();
      return null;
    }
  }

  Future<void> setServer(String url) => _tokens.saveServer(url.trim());

  Future<LoginResult> login({required String type, required String identifier, required String password, String? company}) async {
    final r = await _call(() => _api.post<Map>('/auth/login', auth: false, body: {
          'type': type,
          'email': identifier,
          'password': password,
          if (company != null && company.isNotEmpty) 'societe': company,
          'device_name': _device,
          'platform': _platform,
        }));
    return r;
  }

  Future<String> requestCode({required String identifier, required String channel, String? company}) async {
    final d = await _api.post<Map>('/auth/code/request',
        auth: false, body: {'identifier': identifier, 'channel': channel, if (company != null && company.isNotEmpty) 'societe': company});
    return d['challenge'] as String;
  }

  Future<LoginResult> verifyCode(String challenge, String code) => _call(
      () => _api.post<Map>('/auth/code/verify', auth: false, body: {'challenge': challenge, 'code': code, 'device_name': _device, 'platform': _platform}));

  Future<LoginResult> twoFactor(String token, {String? code, String? recoveryCode}) => _call(() => _api.post<Map>('/auth/2fa', auth: false, body: {
        'token': token,
        'code': ?code,
        'recovery_code': ?recoveryCode,
      }));

  Future<LoginResult> _call(Future<Map> Function() f) async {
    try {
      final d = await f();
      if (d['two_factor_required'] == true) return LoginNeeds2fa(d['token'] as String);
      await _tokens.saveTokens(d['access_token'] as String, d['refresh_token'] as String);
      useContract(await _api.contract());
      final p = Profile(Map<String, dynamic>.from(d['profile'] as Map));
      await _tokens.saveProfile(jsonEncode(p.raw));
      state = AsyncData(p);
      return LoginOk();
    } on ApiException catch (e) {
      if (e.code == 'societe_a_choisir') {
        final ch = (e.details?['choix'] as List? ?? const []).cast<Map>();
        return LoginNeedsCompany([for (final c in ch) (code: '${c['code']}', name: '${c['nom']}')]);
      }
      rethrow;
    }
  }

  Future<void> logout({bool everywhere = false}) async {
    try {
      await _api.post(everywhere ? '/auth/logout-all' : '/auth/logout');
    } catch (_) {/* hors ligne : les jetons locaux sont tout de même effacés */}
    await _tokens.clear();
    await _api.clearCache();
    state = const AsyncData(null);
  }

  /// Session perdue côté serveur (compte désactivé, jeton de rafraîchissement refusé).
  void expire() {
    _api.clearCache();
    state = const AsyncData(null);
  }
}
