import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart' show StatelessWidget, Widget, BuildContext, TextStyle, TextAlign, TextOverflow, TextDirection, Locale, TextScaler, StrutStyle, TextWidthBasis, TextHeightBehavior;

import '../core/i18n.dart';

/// Remplace `Text` de Flutter dans l'application : le texte source (français) est traduit dans la langue choisie, comme le fait le site web.
/// Chaque fichier d'interface importe `material.dart` avec `hide Text` et ce fichier.
class Text extends StatelessWidget {
  const Text(this.data, {super.key, this.style, this.textAlign, this.overflow, this.maxLines, this.softWrap, this.textDirection, this.textScaler, this.semanticsLabel, this.strutStyle, this.textWidthBasis, this.textHeightBehavior, this.locale});
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;
  final TextDirection? textDirection;
  final TextScaler? textScaler;
  final String? semanticsLabel;
  final StrutStyle? strutStyle;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Locale? locale;

  @override
  Widget build(BuildContext context) => m.Text(
        tr(data),
        style: style,
        textAlign: textAlign,
        overflow: overflow,
        maxLines: maxLines,
        softWrap: softWrap,
        textDirection: textDirection,
        textScaler: textScaler,
        semanticsLabel: semanticsLabel == null ? null : tr(semanticsLabel!),
        strutStyle: strutStyle,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        locale: locale,
      );
}
