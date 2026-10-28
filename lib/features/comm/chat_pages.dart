import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../../ui/web_menu.dart';
import '../../core/i18n.dart';
import '../../ui/tr_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../ui/common.dart';
import '../modules/module_pages.dart';
import '../modules/spec.dart';

/// Messagerie interne : conversations de l'équipe.
class ChatRoomsPage extends ConsumerStatefulWidget {
  const ChatRoomsPage({super.key});
  @override
  ConsumerState<ChatRoomsPage> createState() => _ChatRoomsPageState();
}

class _ChatRoomsPageState extends ConsumerState<ChatRoomsPage> {
  Key _k = UniqueKey();

  Future<void> _openDirect() async {
    final api = ref.read(apiProvider);
    try {
      final cols = [for (final c in await api.get<List>('/chat/colleagues')) Map<String, dynamic>.from(c as Map)];
      if (!mounted) return;
      final pick = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          isScrollControlled: true,
          builder: (c) => SafeArea(
                child: SizedBox(
                  height: MediaQuery.of(c).size.height * 0.6,
                  child: cols.isEmpty
                      ? const EmptyView('Aucun collègue.')
                      : ListView(children: [for (final x in cols) ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text('${x['nom']}'), onTap: () => Navigator.pop(c, x))]),
                ),
              ));
      if (pick == null) return;
      final r = await api.post<Map>('/chat/direct/${pick['id']}');
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatThreadPage(roomId: r['salon_id'] as int, title: '${pick['nom']}')));
      if (mounted) setState(() => _k = UniqueKey());
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _newGroup() async {
    final api = ref.read(apiProvider);
    final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => DynamicFormPage(title: 'Nouveau groupe', successMessage: 'Groupe créé.', submit: (b) => api.post('/chat/groups', body: b), fields: const [
                  FieldSpec('nom', 'Nom du groupe', required: true),
                  FieldSpec('membres', 'Membres', type: FieldType.multi, required: true, optionsPath: '/chat/colleagues', optionLabel: 'nom'),
                ])));
    if (ok == true && mounted) setState(() => _k = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final canGroup = const {'admin', 'siege', 'responsable'}.contains(ref.watch(sessionProvider).value?.role);
    return Scaffold(
      appBar: AppBar(title: Text(webTitle('Messagerie')), actions: [if (canGroup) IconButton(tooltip: tr('Nouveau groupe'), icon: const Icon(Icons.group_add_outlined), onPressed: _newGroup)]),
      floatingActionButton: FloatingActionButton(onPressed: _openDirect, child: const Icon(Icons.edit_outlined)),
      body: AsyncView<List>(
        key: _k,
        load: () => api.get<List>('/chat/rooms'),
        builder: (c, rows) => rows.isEmpty
            ? ListView(children: const [SizedBox(height: 300, child: EmptyView('Aucune conversation.'))])
            : ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                for (final r in rows.cast<Map>())
                  Card(
                    child: ListTile(
                    leading: CircleAvatar(backgroundColor: Theme.of(c).colorScheme.primaryContainer, child: Text(r['type'] == 'direct' ? '👤' : (r['type'] == 'general' ? '💬' : '👥'), style: const TextStyle(fontSize: 18))),
                    title: Text('${r['titre']}', style: TextStyle(fontWeight: (r['non_lus'] as int) > 0 ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text('${r['dernier_message'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: (r['non_lus'] as int) > 0 ? Badge(label: Text('${r['non_lus']}')) : null,
                    onTap: () async {
                      await Navigator.push(c, MaterialPageRoute(builder: (_) => ChatThreadPage(roomId: r['id'] as int, title: '${r['titre']}')));
                      if (mounted) setState(() => _k = UniqueKey());
                    },
                  )),
              ]),
      ),
    );
  }
}

/// Fil d'une conversation : relève des nouveaux messages toutes les 6 secondes.
class ChatThreadPage extends ConsumerStatefulWidget {
  const ChatThreadPage({super.key, required this.roomId, required this.title});
  final int roomId;
  final String title;
  @override
  ConsumerState<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends ConsumerState<ChatThreadPage> {
  final _items = <Map<String, dynamic>>[];
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  bool _loading = true, _sending = false;
  Object? _error;
  int _last = 0;

  @override
  void initState() {
    super.initState();
    _poll(first: true);
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _poll({bool first = false}) async {
    try {
      final rows = [for (final m in await ref.read(apiProvider).get<List>('/chat/rooms/${widget.roomId}/messages', query: {if (_last > 0) 'depuis': _last})) Map<String, dynamic>.from(m as Map)];
      if (!mounted) return;
      if (rows.isNotEmpty) {
        setState(() {
          _items.addAll(rows.where((m) => !_items.any((x) => x['id'] == m['id'])));
          _last = _items.map((m) => m['id'] as int).reduce((a, b) => a > b ? a : b);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
      if (first) setState(() => _loading = false);
    } catch (e) {
      if (first && mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _send() async {
    final t = _ctl.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(apiProvider).post('/chat/rooms/${widget.roomId}/messages', body: {'corps': t});
      _ctl.clear();
      await _poll();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> m) async {
    try {
      await ref.read(apiProvider).post('/chat/messages/${m['id']}/delete');
      if (mounted) setState(() => m
        ..['supprime'] = true
        ..['corps'] = null);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorView(_error!)
                : Column(children: [
                    Expanded(
                      child: _items.isEmpty
                          ? const EmptyView('Aucun message. Écrivez le premier.')
                          : ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.all(8),
                              itemCount: _items.length,
                              itemBuilder: (c, i) {
                                final m = _items[i];
                                final moi = m['moi'] == true;
                                final scheme = Theme.of(c).colorScheme;
                                return Align(
                                  alignment: moi ? Alignment.centerRight : Alignment.centerLeft,
                                  child: GestureDetector(
                                    onLongPress: moi && m['supprime'] != true ? () => _delete(m) : null,
                                    child: Container(
                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(c).size.width * 0.78),
                                      margin: const EdgeInsets.symmetric(vertical: 3),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(color: moi ? scheme.primaryContainer : scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        if (!moi) Text('${m['auteur'] ?? ''}', style: Theme.of(c).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                                        if (m['supprime'] == true)
                                          const Text('Message supprimé', style: TextStyle(fontStyle: FontStyle.italic))
                                        else ...[
                                          if (m['piece_type'] != null) Text(m['piece_type'] == 'audio' ? '🎤 Note vocale (à écouter sur le site web)' : '📷 Photo (à voir sur le site web)', style: const TextStyle(fontStyle: FontStyle.italic)),
                                          if (m['corps'] != null) Text('${m['corps']}'),
                                        ],
                                        Text(fmtDateTime(m['created_at']), style: Theme.of(c).textTheme.labelSmall),
                                      ]),
                                    ),
                                  ),
                                );
                              }),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                        child: Row(children: [
                          Expanded(child: TextField(controller: _ctl, minLines: 1, maxLines: 4, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(hintText: tr('Votre message'), isDense: true), onSubmitted: (_) => _send())),
                          const SizedBox(width: 6),
                          IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
                        ]),
                      ),
                    ),
                  ]),
      );
}
