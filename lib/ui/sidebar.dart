import 'package:flutter/material.dart' hide Text;

import '../core/theme.dart';
import 'tr_text.dart';

/// Entrée du menu latéral (même rendu que `.nav-link` / `.nav-section` du site web).
class SideItem {
  const SideItem(this.section, this.emoji, this.label, this.onTap, {this.active = false, this.badge = 0});
  final String section, emoji, label;
  final VoidCallback onTap;
  final bool active;
  final int badge;
}

/// Menu latéral du site web : dégradé vert-900 → vert-950 (cyan pour le cabinet vétérinaire), titre, sections, entrée active en vert 700, pied avec l'utilisateur.
class SidebarMenu extends StatelessWidget {
  const SidebarMenu({super.key, required this.title, required this.subtitle, required this.items, required this.userName, this.logo = '🐓', this.vet = false, this.onProfile, this.footer = const []});
  final String title, subtitle, userName, logo;
  final List<SideItem> items;
  final bool vet;
  final VoidCallback? onProfile;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final top = vet ? efarmCyanDeep : efarmDeep;
    final bottom = vet ? const Color(0xFF083344) : const Color(0xFF052E16);
    final activeBg = vet ? const Color(0xFF0891B2) : const Color(0xFF15803D);
    final sectionColor = vet ? const Color(0xFF22D3EE) : const Color(0xFF4ADE80);
    final linkColor = vet ? const Color(0xFFCFFAFE) : const Color(0xFFD1FAE5);
    final initials = userName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    final children = <Widget>[];
    String? section;
    for (final it in items) {
      if (it.section != section) {
        section = it.section;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
          child: Text(it.section.toUpperCase(), style: TextStyle(fontSize: 10.4, letterSpacing: 1.1, color: sectionColor, fontWeight: FontWeight.w700)),
        ));
      }
      children.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        child: Material(
          color: it.active ? activeBg : Colors.transparent,
          elevation: it.active ? 1 : 0,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: it.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                SizedBox(width: 24, child: Text(it.emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16))),
                const SizedBox(width: 9),
                Expanded(child: Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: it.active ? Colors.white : linkColor, fontWeight: it.active ? FontWeight.w600 : FontWeight.w400))),
                if (it.badge > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(9)),
                    alignment: Alignment.center,
                    child: Text(it.badge > 99 ? '99+' : '${it.badge}', style: const TextStyle(fontSize: 10.4, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
              ]),
            ),
          ),
        ),
      ));
    }
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom])),
      child: SafeArea(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF)))),
            child: Row(children: [
              Text(logo, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(color: vet ? const Color(0xFF67E8F9) : const Color(0xFF86EFAC), fontSize: 12)),
                ]),
              ),
            ]),
          ),
          Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 4), children: children)),
          ...footer,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x1AFFFFFF)))),
            child: InkWell(
              onTap: onProfile,
              child: Row(children: [
                CircleAvatar(radius: 18, backgroundColor: activeBg, child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                const SizedBox(width: 10),
                Expanded(child: Text(userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
