import 'package:flutter/material.dart' hide Text;
import '../../core/i18n.dart';
import '../../ui/tr_text.dart';
import '../../ui/language_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../ui/common.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  final _company = TextEditingController();
  final _server = TextEditingController(text: defaultServer);
  String _type = 'ferme'; // ferme | veterinaire
  bool _byCode = false;
  bool _busy = false;
  bool _hidePw = true;
  bool _advanced = false;

  @override
  void initState() {
    super.initState();
    ref.read(tokenStoreProvider).server.then((s) {
      if (mounted) _server.text = s;
    });
  }

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    _company.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).setServer(_server.text);
      await f();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handle(LoginResult r) async {
    switch (r) {
      case LoginOk():
        break; // la racine de l'application bascule sur l'accueil
      case LoginNeeds2fa(:final token):
        await _ask2fa(token);
      case LoginNeedsCompany(:final choices):
        final c = await showDialog<String>(
            context: context,
            builder: (_) => SimpleDialog(title: const Text('Choisissez votre exploitation'), children: [
                  for (final ch in choices) SimpleDialogOption(onPressed: () => Navigator.pop(context, ch.code), child: Text('${ch.name} (${ch.code})')),
                ]));
        if (c != null) {
          _company.text = c;
          await _submit();
        }
    }
  }

  Future<void> _ask2fa(String token) async {
    final ctl = TextEditingController();
    var recovery = false;
    final result = await showDialog<({String value, bool recovery})>(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (c, set) => AlertDialog(
                  title: const Text('Double authentification'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: ctl,
                        autofocus: true,
                        keyboardType: recovery ? TextInputType.text : TextInputType.number,
                        decoration: InputDecoration(labelText: recovery ? 'Code de récupération' : 'Code à 6 chiffres')),
                    TextButton(onPressed: () => set(() => recovery = !recovery), child: Text(recovery ? 'Utiliser le code de l\'application' : 'Utiliser un code de récupération')),
                  ]),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
                    FilledButton(onPressed: () => Navigator.pop(c, (value: ctl.text.trim(), recovery: recovery)), child: const Text('Valider')),
                  ],
                )));
    if (result == null || result.value.isEmpty) return;
    final n = ref.read(sessionProvider.notifier);
    await _handle(await n.twoFactor(token, code: result.recovery ? null : result.value, recoveryCode: result.recovery ? result.value : null));
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await _run(() async {
      final n = ref.read(sessionProvider.notifier);
      if (_type == 'ferme' && _byCode) {
        await _codeFlow(n);
      } else {
        await _handle(await n.login(type: _type, identifier: _id.text.trim(), password: _pw.text, company: _company.text.trim()));
      }
    });
  }

  Future<void> _codeFlow(SessionNotifier n) async {
    final channel = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const ListTile(title: Text('Recevoir le code par…')),
              ListTile(leading: const Icon(Icons.email_outlined), title: const Text('E-mail'), onTap: () => Navigator.pop(context, 'email')),
              ListTile(leading: const Icon(Icons.sms_outlined), title: const Text('SMS'), onTap: () => Navigator.pop(context, 'sms')),
            ])));
    if (channel == null) return;
    try {
      final challenge = await n.requestCode(identifier: _id.text.trim(), channel: channel, company: _company.text.trim());
      if (!mounted) return;
      final code = await showDialog<String>(
          context: context,
          builder: (_) {
            final ctl = TextEditingController();
            return AlertDialog(
              title: const Text('Code reçu'),
              content: TextField(controller: ctl, autofocus: true, keyboardType: TextInputType.number, maxLength: 6, decoration: InputDecoration(labelText: tr('Code à 6 chiffres'))),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                FilledButton(onPressed: () => Navigator.pop(context, ctl.text.trim()), child: const Text('Valider')),
              ],
            );
          });
      if (code == null || code.isEmpty) return;
      await _handle(await n.verifyCode(challenge, code));
    } on ApiException catch (e) {
      if (e.code == 'societe_a_choisir') {
        final choices = (e.details?['choix'] as List? ?? const []).cast<Map>();
        await _handle(LoginNeedsCompany([for (final c in choices) (code: '${c['code']}', name: '${c['nom']}')]));
      } else {
        rethrow;
      }
    }
  }

  /// Vérifie l'adresse saisie : le serveur répond-il sur `/status` de l'API mobile ?
  Future<void> _testServer() async {
    final url = _server.text.trim();
    if (!(url.startsWith('https://') || url.startsWith('http://'))) return showError(context, StateError('Adresse http(s) requise'));
    try {
      await ref.read(sessionProvider.notifier).setServer(url);
      final r = await ref.read(apiProvider).get<Map>('/status', auth: false);
      if (mounted) showInfo(context, 'Serveur joignable : ${r['service'] ?? 'EFarm360'}, API mobile v${r['version'] ?? '?'}.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farm = _type == 'ferme';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Align(alignment: AlignmentDirectional.centerEnd, child: LanguageButton()),
                  ValueListenableBuilder<String?>(
                    valueListenable: ref.watch(apiProvider).sessionIssue,
                    builder: (c, issue, _) => issue == null
                        ? const SizedBox.shrink()
                        : Card(color: Theme.of(c).colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(12), child: Text(issue))),
                  ),
                  Image.asset('assets/icon/icon.png', height: 96, semanticLabel: 'Logo EFarm360', errorBuilder: (_, _, _) => Icon(Icons.agriculture, size: 64, color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 8),
                  Text('EFarm360', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ferme', label: Text('Exploitation'), icon: Icon(Icons.home_work_outlined)),
                      ButtonSegment(value: 'veterinaire', label: Text('Vétérinaire'), icon: Icon(Icons.medical_services_outlined)),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() {
                      _type = s.first;
                      _byCode = false;
                    }),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _id,
                    keyboardType: farm ? TextInputType.emailAddress : TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: InputDecoration(labelText: farm ? 'E-mail ou téléphone' : 'E-mail', prefixIcon: const Icon(Icons.person_outline)),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Requis' : null,
                  ),
                  if (!(farm && _byCode)) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pw,
                      obscureText: _hidePw,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                          labelText: tr('Mot de passe'),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(icon: Icon(_hidePw ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _hidePw = !_hidePw))),
                      validator: (v) => (v ?? '').isEmpty ? 'Requis' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ],
                  if (farm && _advanced) ...[
                    const SizedBox(height: 12),
                    TextFormField(controller: _company, decoration: InputDecoration(labelText: tr('Code société (facultatif)'), prefixIcon: Icon(Icons.business))),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(farm && _byCode ? 'Recevoir un code' : 'Se connecter'),
                  ),
                  if (farm)
                    TextButton(onPressed: _busy ? null : () => setState(() => _byCode = !_byCode), child: Text(_byCode ? 'Utiliser mon mot de passe' : 'Connexion par code (e-mail ou SMS)')),
                  const Divider(height: 32),
                  InkWell(
                    onTap: () => setState(() => _advanced = !_advanced),
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(_advanced ? 'Masquer les options' : 'Options avancées', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)),
                  ),
                  if (_advanced) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _server,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(labelText: tr('Adresse du serveur'), prefixIcon: Icon(Icons.dns_outlined)),
                      validator: (v) => (v ?? '').startsWith('https://') || (v ?? '').startsWith('http://') ? null : 'Adresse http(s) requise',
                    ),
                    Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _busy ? null : _testServer, icon: const Icon(Icons.wifi_tethering), label: const Text('Tester la connexion au serveur'))),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
