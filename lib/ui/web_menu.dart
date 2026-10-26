/// Clé = titre dans l'application → (section, emoji, libellé, rang) du menu latéral du site web.
const webMenu = <String, (String, String, String, int)>{
  'Messagerie': ('Principal', '💬', 'Messagerie', 10),
  'Poules pondeuses': ('Principal', '🐓', 'Poules pondeuses', 40),
  'Troupeau bovin': ('Principal', '🐄', 'Bovins', 50),
  'Bovins — tableau de bord': ('Principal', '📈', 'Bovins — tableau de bord', 51),
  'Traite (lait)': ('Principal', '🥛', 'Traite (lait)', 52),
  'Embouche bovine': ('Principal', '🥩', 'Embouche bovine', 60),
  'Couvoir et incubation': ('Principal', '🥚', 'Couvoir & Incubation', 70),
  'Capteurs': ('Principal', '📡', 'Capteurs IoT', 80),
  'Ambiance (capteurs)': ('Principal', '🌡️', 'Ambiance du bâtiment', 81),
  'Comparer les bandes': ('Principal', '📊', 'Performances bande', 90),
  'Alertes': ('Principal', '🔔', 'Alertes', 100),
  'Ventes': ('Gestion', '🛒', 'Ventes commerciales', 110),
  'Clients': ('Gestion', '👥', 'Clients', 120),
  'Finance et dépenses': ('Gestion', '💰', 'Finance & ROI', 140),
  'ROI et performance': ('Gestion', '📈', 'ROI et performance', 141),
  'Contrôle des chiffres': ('Gestion', '✅', 'Contrôle des chiffres', 142),
  'Investissements': ('Gestion', '🏗️', 'Investissements', 143),
  'Fournisseurs': ('Gestion', '🚚', 'Fournisseurs', 150),
  'Employés': ('Gestion', '👷', 'Employés', 160),
  'Paie': ('Gestion', '💵', 'RH & Paie', 161),
  'Mes vétérinaires': ('Gestion', '🩺', 'Vétérinaires', 170),
  'Documents du vétérinaire': ('Gestion', '📄', 'Documents du vétérinaire', 171),
  'Messages des vétérinaires': ('Gestion', '💬', 'Messages des vétérinaires', 172),
  'Formation': ('Gestion', '🎓', 'Formation', 180),
  'Aide et support': ('Gestion', '🛟', 'Aide et support', 190),
  'Parrainage': ('Gestion', '🎁', 'Parrainage', 200),
  'Écritures comptables': ('Gestion', '📊', 'Export comptable', 210),
  'Seuils d\'alerte': ('Gestion', '⚙️', 'Seuils d\'alerte', 240),
  'Sites': ('Administration', '🏭', 'Sites & Fermes', 300),
  'Mon compte': ('Administration', '👤', 'Mon compte', 310),
};

/// Titre d'écran avec l'emoji du menu du site web (« 🐄 Bovins »), sinon inchangé.
String webTitle(String title) {
  final m = webMenu[title];
  return m == null ? title : '${m.$2} ${m.$3}';
}
