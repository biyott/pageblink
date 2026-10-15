import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for direction "AB · Glass Paper" (docs/design/ab-glass-paper/spec.md).
@immutable
class Pb extends ThemeExtension<Pb> {
  const Pb({
    required this.bgStart,
    required this.bgMid,
    required this.bgEnd,
    required this.blobA,
    required this.blobB,
    required this.glass,
    required this.glassStrong,
    required this.glassBorder,
    required this.glassShadow,
    required this.ink,
    required this.inkMuted,
    required this.hairline,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.accentGradient,
    required this.notes,
    required this.pdfPaper,
    required this.warn,
    required this.warnContainer,
    required this.warnBorder,
    required this.tile,
    required this.thumbBg,
    required this.warnTint,
    required this.chipBg,
    required this.scrim,
    required this.sheet,
    required this.success,
    required this.accent,
  });

  final Color bgStart, bgMid, bgEnd, blobA, blobB;
  final Color glass, glassStrong, glassBorder, glassShadow;
  final Color ink, inkMuted, hairline;
  final Color accentContainer, onAccentContainer;
  final List<Color> accentGradient;
  final List<Color> notes;
  final Color pdfPaper, warn, warnContainer, warnBorder;
  final Color tile, thumbBg, warnTint, chipBg, scrim, sheet, success, accent;

  static const light = Pb(
    bgStart: Color(0xFFEDE6FA),
    bgMid: Color(0xFFF7E8EE),
    bgEnd: Color(0xFFFFE9DC),
    blobA: Color(0x73CDBBFA),
    blobB: Color(0x73FFC9A8),
    glass: Color(0x9EFFFFFF),
    glassStrong: Color(0xBDFFFFFF),
    glassBorder: Color(0xCCFFFFFF),
    glassShadow: Color(0x1A6C4CF5),
    ink: Color(0xFF1F1B16),
    inkMuted: Color(0xFF6B6358),
    hairline: Color(0xFFE4DDD0),
    accentContainer: Color(0xFFEAE4FD),
    onAccentContainer: Color(0xFF2E1F85),
    accentGradient: [Color(0xFF6C4CF5), Color(0xFF8F6BFF)],
    notes: [
      Color(0xFFFFF1B8),
      Color(0xFFD9F0E1),
      Color(0xFFFFDCCB),
      Color(0xFFD6E8F8),
      Color(0xFFE9E3FC),
    ],
    pdfPaper: Colors.white,
    warn: Color(0xFFB45309),
    warnContainer: Color(0xFFFEF3C7),
    warnBorder: Color(0x8CB45309),
    tile: Color(0x141F1B16),
    thumbBg: Color(0x0B1F1B16),
    warnTint: Color(0xFFFFF8EC),
    chipBg: Color(0x8CFFFFFF),
    scrim: Color(0x661E160C),
    sheet: Color(0xDBFFFDFA),
    success: Color(0xFF2E7D4F),
    accent: Color(0xFF6C4CF5),
  );

  static const dark = Pb(
    bgStart: Color(0xFF1E1830),
    bgMid: Color(0xFF251C27),
    bgEnd: Color(0xFF2A1F1C),
    blobA: Color(0x386C4CF5),
    blobB: Color(0x24FF9A6B),
    glass: Color(0x14FFFFFF),
    glassStrong: Color(0x1FFFFFFF),
    glassBorder: Color(0x29FFFFFF),
    glassShadow: Color(0x4D000000),
    ink: Color(0xFFF2EDE3),
    inkMuted: Color(0xFFA59D8F),
    hairline: Color(0x24FFFFFF),
    accentContainer: Color(0xFF3A2F7A),
    onAccentContainer: Color(0xFFE9E3FC),
    accentGradient: [Color(0xFF6C4CF5), Color(0xFF7A5CFF)],
    notes: [
      Color(0xFF4A3F16),
      Color(0xFF1F3D2C),
      Color(0xFF4D2E21),
      Color(0xFF1F3548),
      Color(0xFF35295E),
    ],
    pdfPaper: Color(0xFF2A2620),
    warn: Color(0xFFFBBF24),
    warnContainer: Color(0xFF3A2A0A),
    warnBorder: Color(0x80FBBF24),
    tile: Color(0x1FFFFFFF),
    thumbBg: Color(0x0DFFFFFF),
    warnTint: Color(0xFF2D2410),
    chipBg: Color(0x0DFFFFFF),
    scrim: Color(0x661E160C),
    sheet: Color(0xE0282130),
    success: Color(0xFF6FCF97),
    accent: Color(0xFFB7A6FF),
  );

  /// Stable pastel per note so cards keep their color between refreshes.
  Color noteColor(int? id) => notes[(id ?? 0) % notes.length];

  @override
  Pb copyWith() => this;

  @override
  Pb lerp(Pb? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension PbContext on BuildContext {
  Pb get pb => Theme.of(this).extension<Pb>()!;
}

/// Bundled Hangul fallback family (assets/fonts/NotoSansKR-*-subset.ttf,
/// KS X 1001 2,350 syllables + compat jamo + punctuation; weights 400/600).
const pbHangulFamily = 'NotoSansKRSubset';

ThemeData buildPbTheme(Brightness brightness) {
  final pb = brightness == Brightness.light ? Pb.light : Pb.dark;
  final accent = brightness == Brightness.light
      ? const Color(0xFF6C4CF5)
      : const Color(0xFFB7A6FF);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF6C4CF5),
        brightness: brightness,
      ).copyWith(
        primary: accent,
        onPrimary: brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF251A63),
        primaryContainer: pb.accentContainer,
        onPrimaryContainer: pb.onAccentContainer,
        secondaryContainer: pb.accentContainer,
        onSecondaryContainer: pb.onAccentContainer,
        surface: pb.pdfPaper,
        onSurface: pb.ink,
        onSurfaceVariant: pb.inkMuted,
        outline: pb.hairline,
        outlineVariant: pb.hairline,
        surfaceTint: Colors.transparent,
      );

  // Latin: Inter / Fraunces (google_fonts). Hangul: bundled Noto Sans KR
  // subset (pubspec `fonts:`), loaded before the first frame. Applied to every
  // TextTheme style below so no widget falls back to the engine's CDN fonts.
  const hangul = [pbHangulFamily];
  final inter = GoogleFonts.interTextTheme(
    ThemeData(brightness: brightness).textTheme,
  ).apply(bodyColor: pb.ink, displayColor: pb.ink);
  TextStyle serif(double size, {FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        height: 1.2,
        color: pb.ink,
      ).copyWith(fontFamilyFallback: hangul);

  final text = inter
      .copyWith(
        headlineMedium: serif(30),
        headlineSmall: serif(26),
        titleLarge: serif(22),
        titleMedium: serif(18),
        bodyLarge: inter.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
        bodyMedium: inter.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
        labelLarge: inter.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      )
      .apply(fontFamilyFallback: hangul);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    textTheme: text,
    extensions: [pb],
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: pb.ink,
      titleTextStyle: serif(22),
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: pb.ink.withValues(alpha: 0.10)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.55)
              : pb.hairline,
        ),
      ),
      backgroundColor: pb.chipBg,
      selectedColor: pb.accentContainer,
      checkmarkColor: pb.onAccentContainer,
      secondarySelectedColor: pb.accentContainer,
      labelStyle: text.labelMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: pb.ink,
      ),
      secondaryLabelStyle: text.labelMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: pb.onAccentContainer,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: scheme.onPrimary,
      elevation: 6,
      shape: const StadiumBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: pb.glass,
      surfaceTintColor: Colors.transparent,
      indicatorColor: pb.accentContainer,
      elevation: 0,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: pb.accentContainer,
      selectedIconTheme: IconThemeData(color: pb.accent),
      unselectedIconTheme: IconThemeData(color: pb.inkMuted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: pb.glassStrong,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: pb.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: pb.hairline),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ),
    dividerTheme: DividerThemeData(color: pb.hairline, space: 1),
  );
}

/// Warm lavender → peach gradient with two soft blobs.
class PbBackground extends StatelessWidget {
  const PbBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [pb.bgStart, pb.bgMid, pb.bgEnd],
        ),
      ),
      child: Stack(
        children: [
          Positioned(left: -140, top: -140, child: _Glow(pb.blobA, 460)),
          Positioned(right: -140, bottom: -140, child: _Glow(pb.blobB, 460)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// Soft corner glow (radial falloff, no blur filter so it stays cheap).
class _Glow extends StatelessWidget {
  const _Glow(this.color, this.size);
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    ),
  );
}

/// Frosted glass surface for the shell (sidebar, Ask panel). Blur only here.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 24,
    this.strong = false,
  });
  final Widget child;
  final double radius;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: pb.glassShadow,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: strong ? pb.glassStrong : pb.glass,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: pb.glassBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
