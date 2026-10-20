import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:efarm360/core/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef Handler = ({int status, Map<String, dynamic> body}) Function(RequestOptions o);

/// Faux serveur : répond selon la méthode et le chemin (`GET /me`), sans réseau.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.routes);
  final Map<String, Handler> routes;
  final calls = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    calls.add(o);
    final key = '${o.method} ${o.uri.path.replaceFirst('/api/mobile/v1', '')}';
    final h = routes[key];
    if (h == null) throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
    final r = h(o);
    return ResponseBody.fromString(jsonEncode(r.body), r.status, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

({int status, Map<String, dynamic> body}) ok(Object? data, {Map<String, dynamic>? meta}) => (status: 200, body: {'success': true, 'data': data, if (meta != null) 'meta': meta});
({int status, Map<String, dynamic> body}) ko(int status, String code, [String msg = 'x', Map<String, dynamic>? details]) =>
    (status: status, body: {'success': false, 'error': {'code': code, 'message': msg, if (details != null) 'details': details}});

Future<(ApiClient, FakeAdapter, TokenStore)> makeClient(Map<String, Handler> routes, {String? access = 'acc_old_token_aaaaaaaaaa', String? refresh = 'ref_old_token_aaaaaaaaaa'}) async {
  FlutterSecureStorage.setMockInitialValues({if (access != null) 'access': access, if (refresh != null) 'refresh': refresh});
  final tokens = TokenStore();
  final a = FakeAdapter(routes);
  final dio = Dio()..httpClientAdapter = a;
  return (ApiClient(tokens, dio: dio), a, tokens);
}
