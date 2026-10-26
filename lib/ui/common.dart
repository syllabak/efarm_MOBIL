import 'package:flutter/material.dart' hide Text;
import 'tr_text.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';

String errorText(Object e) => e is ApiException ? e.message : (e is StateError ? e.message : 'Une erreur est survenue.');

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(errorText(e)), backgroundColor: Theme.of(context).colorScheme.error));
}

void showInfo(BuildContext context, String m) =>
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(m)));

String fmtDate(Object? v) {
  if (v == null) return '—';
  final d = DateTime.tryParse('$v'.replaceFirst(' ', 'T'));
  return d == null ? '$v' : DateFormat('dd/MM/yyyy').format(d);
}

String fmtDateTime(Object? v) {
  if (v == null) return '—';
  final d = DateTime.tryParse('$v'.replaceFirst(' ', 'T'));
  return d == null ? '$v' : DateFormat('dd/MM/yyyy HH:mm').format(d);
}

String fmtNum(Object? v, {int digits = 0}) {
  final n = v is num ? v : num.tryParse('$v');
  if (n == null) return '—';
  return NumberFormat.decimalPatternDigits(locale: 'fr_FR', decimalDigits: digits).format(n);
}

String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

class ErrorView extends StatelessWidget {
  const ErrorView(this.error, {super.key, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon((error is ApiException && (error as ApiException).isNetwork) ? Icons.wifi_off : Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(errorText(error), textAlign: TextAlign.center),
            if (onRetry != null) ...[const SizedBox(height: 12), FilledButton.tonal(onPressed: onRetry, child: const Text('Réessayer'))],
          ]),
        ),
      );
}

class EmptyView extends StatelessWidget {
  const EmptyView(this.text, {super.key, this.icon = Icons.inbox_outlined});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: Theme.of(context).disabledColor),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: Theme.of(context).disabledColor)),
        ]),
      );
}

typedef PageFetcher = Future<({List<Map<String, dynamic>> items, Map<String, dynamic> meta})> Function(int page);

/// Liste à défilement infini sur une API paginée (`meta.pages`). Pour recharger avec d'autres filtres, changer la `key`.
class PagedList extends StatefulWidget {
  const PagedList({super.key, required this.fetch, required this.itemBuilder, this.emptyText = 'Aucun élément.', this.header});
  final PageFetcher fetch;
  final Widget Function(BuildContext, Map<String, dynamic>) itemBuilder;
  final String emptyText;
  final Widget? header;

  @override
  State<PagedList> createState() => _PagedListState();
}

class _PagedListState extends State<PagedList> {
  final _items = <Map<String, dynamic>>[];
  final _scroll = ScrollController();
  int _page = 0, _pages = 1;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _more();
    });
    _more();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    _items.clear();
    _page = 0;
    _pages = 1;
    _error = null;
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _page >= _pages) return;
    setState(() => _loading = true);
    try {
      final r = await widget.fetch(_page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(r.items);
        _page = (r.meta['page'] as int?) ?? _page + 1;
        _pages = (r.meta['pages'] as int?) ?? 1;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty && _error != null) return ErrorView(_error!, onRetry: _reset);
    return RefreshIndicator(
      onRefresh: _reset,
      child: _items.isEmpty
          ? ListView(children: [if (widget.header != null) widget.header!, SizedBox(height: 300, child: EmptyView(widget.emptyText))])
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _items.length + 1 + (widget.header != null ? 1 : 0),
              itemBuilder: (c, i) {
                if (widget.header != null) {
                  if (i == 0) return widget.header!;
                  i--;
                }
                if (i == _items.length) {
                  return _loading
                      ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                      : _error != null
                          ? TextButton(onPressed: _more, child: const Text('Erreur de chargement — réessayer'))
                          : const SizedBox(height: 80);
                }
                return widget.itemBuilder(c, _items[i]);
              }),
    );
  }
}

class Stat extends StatelessWidget {
  const Stat(this.label, this.value, {super.key, this.icon, this.emoji, this.color});
  final String label;
  final String value;
  final IconData? icon;

  /// Emoji de l'indicateur sur le site web (prioritaire sur [icon]).
  final String? emoji;
  final Color? color;

  /// Carte à la manière des indicateurs du site web : filet coloré à gauche, icône et valeur sur la même ligne.
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: c, width: 4))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              if (emoji != null) Text(emoji!, style: const TextStyle(fontSize: 24)) else if (icon != null) Icon(icon, color: c) else const SizedBox.shrink(),
              const SizedBox(width: 8),
              Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: c)))),
            ]),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

class KeyValue extends StatelessWidget {
  const KeyValue(this.k, this.v, {super.key});
  final String k;
  final Object? v;
  @override
  Widget build(BuildContext context) {
    final s = v == null || '$v'.isEmpty ? '—' : '$v';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 140, child: Text(k, style: TextStyle(color: Theme.of(context).hintColor))),
        Expanded(child: Text(s)),
      ]),
    );
  }
}

/// Charge une ressource, affiche chargement/erreur, et permet le « tirer pour rafraîchir ».
class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext, T) builder;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _f = widget.load();

  Future<void> _reload() async {
    setState(() => _f = widget.load());
    try {
      await _f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (s.hasError) return ErrorView(s.error!, onRetry: _reload);
          return RefreshIndicator(onRefresh: _reload, child: widget.builder(c, s.data as T));
        },
      );
}
