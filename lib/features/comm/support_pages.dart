import 'package:flutter/material.dart' hide Text;
import '../../ui/web_menu.dart';
import '../../core/i18n.dart';
import '../../ui/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../ui/common.dart';
import '../modules/module_pages.dart';
import '../modules/spec.dart';

const _statuts = {'bot': 'Assistant', 'ouvert': 'Ouvert', 'en_cours': 'En cours', 'resolu': 'Résolu', 'ferme': 'Fermé'};

/// Aide et support : mes demandes, assistant, signalement d'un problème.
class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});
  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  Key _k = UniqueKey();

  Future<void> _open(int? ticket, String title) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SupportThreadPage(ticketId: ticket, title: title)));
    if (mounted) setState(() => _k = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: Text(webTitle('Aide et support'))),
      body: AsyncView<List>(
        key: _k,
        load: () => api.get<List>('/support/tickets'),
        builder: (c, rows) => ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          ListTile(leading: const Icon(Icons.smart_toy_outlined), title: const Text('Poser une question à l\'assistant'), trailing: const Icon(Icons.chevron_right), onTap: () => _open(null, 'Assistant')),
          ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Signaler un problème'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final ok = await Navigator.push<bool>(
                    c,
                    MaterialPageRoute(
                        builder: (_) => DynamicFormPage(title: 'Signaler un problème', successMessage: 'Signalement envoyé.', submit: (b) => api.post('/support/report', body: b), fields: const [
                              FieldSpec('sujet', 'Titre', required: true),
                              FieldSpec('description', 'Description (10 caractères au moins)', type: FieldType.multiline, required: true),
                              FieldSpec('priorite', 'Priorité', type: FieldType.select, initial: 'normale', options: {'basse': 'Basse', 'normale': 'Normale', 'haute': 'Haute'}),
                            ])));
                if (ok == true && mounted) setState(() => _k = UniqueKey());
              }),
          const Divider(),
          const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 4), child: Text('Mes demandes', style: TextStyle(fontWeight: FontWeight.bold))),
          if (rows.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucune demande.'))),
          for (final t in rows.cast<Map>())
            ListTile(
              leading: Icon(Icons.chat_bubble_outline, color: '${t['non_lu_client']}' == '1' ? Theme.of(c).colorScheme.error : null),
              title: Text('${t['sujet']}', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${_statuts['${t['statut']}'] ?? t['statut']} · ${fmtDateTime(t['updated_at'])}'),
              onTap: () => _open(int.tryParse('${t['id']}'), '${t['sujet']}'),
            ),
        ]),
      ),
    );
  }
}

class SupportThreadPage extends ConsumerStatefulWidget {
  const SupportThreadPage({super.key, this.ticketId, required this.title});
  final int? ticketId;
  final String title;
  @override
  ConsumerState<SupportThreadPage> createState() => _SupportThreadPageState();
}

class _SupportThreadPageState extends ConsumerState<SupportThreadPage> {
  final _msgs = <Map<String, dynamic>>[];
  final _ctl = TextEditingController();
  int? _ticket;
  String _statut = 'bot';
  bool _loading = true, _sending = false, _propose = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticketId;
    _load();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_ticket == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final d = await ref.read(apiProvider).get<Map>('/support/tickets/$_ticket/messages');
      _msgs
        ..clear()
        ..addAll([for (final m in (d['messages'] as List)) Map<String, dynamic>.from(m as Map)]);
      _statut = '${d['statut']}';
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _merge(Map d) {
    _ticket = d['ticket_id'] as int? ?? _ticket;
    _statut = '${d['statut']}';
    for (final m in (d['messages'] as List? ?? const [])) {
      final mm = Map<String, dynamic>.from(m as Map);
      if (!_msgs.any((x) => x['id'] == mm['id'])) _msgs.add(mm);
    }
  }

  Future<void> _send() async {
    final t = _ctl.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final d = await ref.read(apiProvider).post<Map>('/support/chat', body: {'message': t, if (_ticket != null) 'ticket_id': _ticket});
      _ctl.clear();
      // La réponse ne contient que les nouveaux messages : on garde aussi la question posée
      _msgs.add({'id': -DateTime.now().millisecondsSinceEpoch, 'auteur': 'client', 'message': t});
      setState(() {
        _propose = d['proposer_agent'] == true;
        _merge(d);
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _agent() async {
    try {
      final d = await ref.read(apiProvider).post<Map>('/support/escalate', body: {if (_ticket != null) 'ticket_id': _ticket});
      setState(() {
        _propose = false;
        _merge(d);
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final closed = _statut == 'ferme';
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis), actions: [
        if (_ticket != null && !closed)
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'agent') await _agent();
              if (v == 'close') {
                try {
                  await ref.read(apiProvider).post('/support/tickets/$_ticket/close');
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) showError(context, e);
                }
              }
            },
            itemBuilder: (_) => [if (_statut == 'bot') const PopupMenuItem(value: 'agent', child: Text('Parler à un agent')), const PopupMenuItem(value: 'close', child: Text('Fermer la demande'))],
          ),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorView(_error!, onRetry: _load)
              : Column(children: [
                  Expanded(
                    child: _msgs.isEmpty
                        ? const EmptyView('Posez votre question, l\'assistant vous répond.', icon: Icons.smart_toy_outlined)
                        : ListView(padding: const EdgeInsets.all(8), children: [
                            for (final m in _msgs)
                              Align(
                                alignment: m['auteur'] == 'client' ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                                  margin: const EdgeInsets.symmetric(vertical: 3),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      color: m['auteur'] == 'client' ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                                  child: Text('${m['message'] ?? ''}'),
                                ),
                              ),
                            if (_propose) Padding(padding: const EdgeInsets.all(8), child: FilledButton.tonal(onPressed: _agent, child: const Text('Parler à un agent'))),
                          ]),
                  ),
                  if (closed)
                    const Padding(padding: EdgeInsets.all(12), child: Text('Cette demande est fermée.'))
                  else
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                        child: Row(children: [
                          Expanded(child: TextField(controller: _ctl, minLines: 1, maxLines: 4, maxLength: 1500, decoration: InputDecoration(hintText: tr('Votre message'), isDense: true, counterText: ''), onSubmitted: (_) => _send())),
                          const SizedBox(width: 6),
                          IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
                        ]),
                      ),
                    ),
                ]),
    );
  }
}
