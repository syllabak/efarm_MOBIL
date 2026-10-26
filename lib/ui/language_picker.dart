import 'package:flutter/material.dart' hide Text;

import '../core/i18n.dart';
import 'tr_text.dart';

/// Choix de la langue (fr, en, pt, es, ar) comme le sélecteur du site web.
class LanguageTile extends StatelessWidget {
  const LanguageTile({super.key});
  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.language),
        title: const Text('Langue'),
        subtitle: Text(I18n.languages[I18n.instance.code]!.$1),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showLanguageSheet(context),
      );
}

Future<void> showLanguageSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final e in I18n.languages.entries)
            ListTile(
              title: Text(e.value.$1),
              trailing: e.key == I18n.instance.code ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.pop(c);
                I18n.instance.setLanguage(e.key);
              },
            ),
        ]),
      ),
    );

/// Bouton « 🌐 Français » compact, pour l'écran de connexion.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});
  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: () => showLanguageSheet(context),
        icon: const Icon(Icons.language, size: 18),
        label: Text(I18n.languages[I18n.instance.code]!.$1),
      );
}
