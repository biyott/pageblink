import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pb_interactive.dart';

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
    required this.cardMeta,
    required this.hairline,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.accentGradient,
    required this.notes,
    required this.notesExtra,
    required this.noteRainbow,
    required this.noteRainbowFlat,
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
    required this.warnText,
    required this.linkInk,
    required this.dropFill,
    required this.dropFillOver,
    required this.dropBorder,
    required this.dropScrim,
    required this.paneVeil,
    required this.dropSub,
    required this.citeFill,
    required this.citePulse,
    required this.citeEdge,
    required this.citePdfFill,
    required this.citePdfEdge,
    required this.selection,
    required this.focusRing,
    required this.hover,
    required this.press,
    required this.filledHover,
    required this.filledPress,
    required this.disabledFg,
    required this.disabledBg,
    required this.controlEdge,
    required this.warnHover,
  });

  final Color bgStart, bgMid, bgEnd, blobA, blobB;
  final Color glass, glassStrong, glassBorder, glassShadow;
  final Color ink, inkMuted, hairline;

  /// 12px meta text on note / PDF cards ([inkMuted] elsewhere). A card keeps
  /// its face color under the 6% hover / 12% pressed tint, so in dark
  /// [inkMuted] fell to 4.00:1 (hover) and 3.34:1 (pressed) on the notes; this
  /// stays >= 4.5:1 on every note color, the rainbow and the PDF paper in all
  /// three states. Same as [inkMuted] in light, which already passes.
  final Color cardMeta;
  final Color accentContainer, onAccentContainer;
  final List<Color> accentGradient;

  /// Automatic note colors (cycled by id). Stays at five so notes that were
  /// colored automatically before the extra colors existed keep their color.
  final List<Color> notes;

  /// Hand-picked only, `colorIndex` 5..7 (rose, aqua, lime).
  final List<Color> notesExtra;

  /// Six evenly spaced stops of the rainbow card gradient (`colorIndex` 8).
  final List<Color> noteRainbow;

  /// Plain-color stand-in for the rainbow where a gradient cannot be drawn.
  final Color noteRainbowFlat;
  final Color pdfPaper, warn, warnContainer, warnBorder;
  final Color tile, thumbBg, warnTint, chipBg, scrim, sheet, success, accent;

  /// Re-index status line + PDF drop zone (docs/design/upload-dnd-reindex §4).
  /// [warnText] is `warn` darkened to AA on the note pastels; [linkInk] is the
  /// text-link color on cards and the board (accent fails AA on pastels).
  final Color warnText, linkInk;
  final Color dropFill, dropFillOver, dropBorder, dropScrim, paneVeil, dropSub;

  /// Cited passage (research 027 §3, U2). [citeFill] is the resting block
  /// behind the text, [citePulse] its first 600 ms, [citeEdge] the 3px rail
  /// (and the sheet's rail). Non-text contrast comes from the rail (accent vs
  /// panel >= 4.9:1), not from the fill.
  final Color citeFill, citePulse, citeEdge;

  /// The same on a PDF page: the page is white paper in both themes, so these
  /// are built on the light accent in dark mode too.
  final Color citePdfFill, citePdfEdge;

  /// Text selection: a neutral blue-grey, so violet stays for citations.
  final Color selection;

  /// Interaction states (docs/design/ui-polish/spec.md §5.3, a11y spec §3).
  /// [focusRing] is the neutral keyboard ring (2px, 2px gap; violet stays for
  /// citations). [hover] 6% / [press] 12% of `ink` (white in dark) are for
  /// clear, pastel and glass faces; [filledHover] / [filledPress] are black
  /// 8% / 14% for violet fills. [disabledFg] / [disabledBg] are ink 38% / 8%.
  /// [controlEdge] (ink 50%, >= 3:1 on the field face) is the boundary of a
  /// control: form inputs and the unselected note-color swatch (WCAG 1.4.11);
  /// every other hairline stays. [warnHover] is
  /// the amber face's hover.
  final Color focusRing, hover, press, filledHover, filledPress;
  final Color disabledFg, disabledBg, controlEdge, warnHover;

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
    inkMuted: Color(0xFF5C5348),
    cardMeta: Color(0xFF5C5348),
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
    notesExtra: [Color(0xFFFFD7E9), Color(0xFFBDEDF2), Color(0xFFE4F0C5)],
    noteRainbow: [
      Color(0xFFFFD7E9),
      Color(0xFFFFDCCB),
      Color(0xFFFFF1B8),
      Color(0xFFD9F0E1),
      Color(0xFFD6E8F8),
      Color(0xFFE9E3FC),
    ],
    noteRainbowFlat: Color(0xFFF4DEF2),
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
    warnText: Color(0xFF92400E),
    linkInk: Color(0xFF2E1F85),
    dropFill: Color(0x146C4CF5),
    dropFillOver: Color(0x246C4CF5),
    dropBorder: Color(0x8C6C4CF5),
    dropScrim: Color(0x291E160C),
    paneVeil: Color(0xEDF7E8EE),
    dropSub: Color(0xCC1F1B16),
    // accent #6C4CF5 at 12% resting / 28% pulse; rail = accent.
    citeFill: Color(0x1F6C4CF5),
    citePulse: Color(0x476C4CF5),
    citeEdge: Color(0xFF6C4CF5),
    citePdfFill: Color(0x386C4CF5),
    citePdfEdge: Color(0xFF6C4CF5),
    // slate #44546F at 22%.
    selection: Color(0x3844546F),
    focusRing: Color(0xFF1F1B16),
    hover: Color(0x0F1F1B16),
    press: Color(0x1F1F1B16),
    filledHover: Color(0x14000000),
    filledPress: Color(0x24000000),
    disabledFg: Color(0x611F1B16),
    disabledBg: Color(0x141F1B16),
    controlEdge: Color(0x801F1B16),
    warnHover: Color(0x14B45309),
  );

  static const dark = Pb(
    bgStart: Color(0xFF1E1830),
    bgMid: Color(0xFF251C27),
    bgEnd: Color(0xFF2A1F1C),
    blobA: Color(0x386C4CF5),
    blobB: Color(0x24FF9A6B),
    glass: Color(0x14FFFFFF),
    glassStrong: Color(0x24FFFFFF),
    glassBorder: Color(0x29FFFFFF),
    glassShadow: Color(0x4D000000),
    ink: Color(0xFFF2EDE3),
    inkMuted: Color(0xFFB5AD9F),
    cardMeta: Color(0xFFD2CBBF),
    hairline: Color(0x24FFFFFF),
    accentContainer: Color(0xFF3A2F7A),
    onAccentContainer: Color(0xFFE9E3FC),
    accentGradient: [Color(0xFF6C4CF5), Color(0xFF7A5CFF)],
    notes: [
      Color(0xFF463E22),
      Color(0xFF223A2E),
      Color(0xFF47302A),
      Color(0xFF22364A),
      Color(0xFF342C58),
    ],
    notesExtra: [Color(0xFF472737), Color(0xFF073338), Color(0xFF333813)],
    noteRainbow: [
      Color(0xFF472737),
      Color(0xFF47302A),
      Color(0xFF463E22),
      Color(0xFF223A2E),
      Color(0xFF22364A),
      Color(0xFF342C58),
    ],
    noteRainbowFlat: Color(0xFF452F43),
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
    warnText: Color(0xFFFBBF24),
    linkInk: Color(0xFFB7A6FF),
    dropFill: Color(0x24B7A6FF),
    dropFillOver: Color(0x38B7A6FF),
    dropBorder: Color(0x8CB7A6FF),
    dropScrim: Color(0x4D000000),
    paneVeil: Color(0xED251C27),
    dropSub: Color(0xBFF2EDE3),
    // accent #B7A6FF at 14% resting / 30% pulse; rail = accent.
    citeFill: Color(0x24B7A6FF),
    citePulse: Color(0x4DB7A6FF),
    citeEdge: Color(0xFFB7A6FF),
    // PDF pages stay white in dark mode: light accent, 22%.
    citePdfFill: Color(0x386C4CF5),
    citePdfEdge: Color(0xFF6C4CF5),
    // blue-grey #9FB4D6 at 24%.
    selection: Color(0x3D9FB4D6),
    focusRing: Color(0xFFF2EDE3),
    hover: Color(0x0FFFFFFF),
    press: Color(0x1FFFFFFF),
    filledHover: Color(0x14000000),
    filledPress: Color(0x24000000),
    disabledFg: Color(0x61F2EDE3),
    disabledBg: Color(0x14FFFFFF),
    controlEdge: Color(0x80F2EDE3),
    warnHover: Color(0x14FBBF24),
  );

  /// `Document.colorIndex` of the rainbow gradient (server: noteColorCount 9).
  static const rainbowIndex = 8;

  /// Card color: the chosen [colorIndex] (0..4 [notes], 5..7 [notesExtra])
  /// wins, else a stable pastel per note. The rainbow and unknown values fall
  /// back as follows: rainbow -> [noteRainbowFlat] (use [noteGradient] where a
  /// gradient can be drawn), unknown -> automatic.
  Color noteColor(int? id, {int? colorIndex}) {
    final c = colorIndex;
    if (c == rainbowIndex) return noteRainbowFlat;
    if (c != null && c >= 0 && c < notes.length + notesExtra.length) {
      return c < notes.length ? notes[c] : notesExtra[c - notes.length];
    }
    return notes[(id ?? 0) % notes.length];
  }

  /// The rainbow card gradient for [colorIndex], null for any other value.
  Gradient? noteGradient(int? colorIndex) => colorIndex == rainbowIndex
      ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: noteRainbow,
        )
      : null;

  @override
  Pb copyWith() => this;

  @override
  Pb lerp(Pb? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension PbContext on BuildContext {
  Pb get pb => Theme.of(this).extension<Pb>()!;
}

/// Bundled body family for Latin and Hangul (assets/fonts/Pretendard-*-subset.otf,
/// Pretendard 1.3.9: KS X 1001 2,350 syllables + compat jamo + Latin/punctuation;
/// weights 400/500/600, so w700/bold resolves to the 600 face).
const pbSansFamily = 'PretendardSubset';

/// Bundled Hangul serif family for titles (assets/fonts/NotoSerifKR-600-subset.ttf,
/// KS X 1001 subset, weight 600 only: every serif style is w600).
const pbHangulSerifFamily = 'NotoSerifKRSubset';

/// [platform] only for tests; the app uses the platform it runs on.
ThemeData buildPbTheme(Brightness brightness, {TargetPlatform? platform}) {
  final pb = brightness == Brightness.light ? Pb.light : Pb.dark;
  final touch = const {
    TargetPlatform.android,
    TargetPlatform.iOS,
  }.contains(platform ?? defaultTargetPlatform);
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

  // Body: bundled Pretendard (Latin + Hangul, one family) declared in pubspec
  // `fonts:`, so it is loaded before the first frame and nothing falls back to
  // the engine's CDN fonts. Titles: Fraunces w600 (bundled under
  // assets/google_fonts/, no runtime fetch) -> Noto Serif KR subset -> Pretendard.
  // The serif fallback is set per style below: TextStyle.apply replaces
  // fontFamilyFallback, so a final apply() on the whole theme would lose it.
  const serifFallback = [pbHangulSerifFamily, pbSansFamily];
  final sans = ThemeData(brightness: brightness).textTheme.apply(
    fontFamily: pbSansFamily,
    bodyColor: pb.ink,
    displayColor: pb.ink,
  );
  TextStyle serif(
    double size, {
    double height = 1.3,
    double letterSpacing = 0,
  }) => GoogleFonts.fraunces(
    fontSize: size,
    fontWeight: FontWeight.w600,
    height: height,
    letterSpacing: letterSpacing,
    color: pb.ink,
  ).copyWith(fontFamilyFallback: serifFallback);

  // Type scale: docs/design/ui-polish/spec.md §3 (UP-02). M3 defaults add
  // +0.25..+0.8 tracking, which spreads small Hangul, so every role sets it to 0
  // (titles keep -0.3 on the screen headline). Sizes <= 13 are w500+ (bundled).
  TextStyle? role(
    TextStyle? base,
    double size,
    FontWeight weight,
    double height,
  ) => base?.copyWith(
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: 0,
  );
  final text = sans.copyWith(
    headlineMedium: serif(32, height: 1.25, letterSpacing: -0.3),
    headlineSmall: serif(26),
    titleLarge: serif(20),
    titleMedium: serif(18),
    titleSmall: role(sans.titleSmall, 14, FontWeight.w500, 1.3),
    bodyLarge: role(sans.bodyLarge, 15, FontWeight.w400, 1.5),
    bodyMedium: role(sans.bodyMedium, 15, FontWeight.w400, 1.6),
    bodySmall: role(sans.bodySmall, 12, FontWeight.w500, 1.35),
    labelLarge: role(sans.labelLarge, 14, FontWeight.w600, 1.2),
    labelMedium: role(sans.labelMedium, 13, FontWeight.w500, 1.2),
    labelSmall: role(sans.labelSmall, 12, FontWeight.w600, 1.3),
  );

  // ── Interaction states (a11y state spec §3, §7.2) ───────────────────────
  // Overlays are explicit: a null falls back to the Material default, which is
  // violet (and white on a violet fill). Pressed > hovered > focused.
  WidgetStateProperty<Color?> overlay(
    Color hover,
    Color press, [
    Color focus = Colors.transparent,
  ]) => WidgetStateProperty.resolveWith((s) {
    if (s.contains(WidgetState.pressed)) return press;
    if (s.contains(WidgetState.hovered)) return hover;
    if (s.contains(WidgetState.focused)) return focus;
    return null;
  });
  // The ring is a 2px inset `side` (the floor for buttons and chips without
  // an outer ring); only in keyboard mode, since WidgetState.focused is raw
  // focus (a dialog may focus a button on a phone).
  BorderSide ringSide() => BorderSide(color: pb.focusRing, width: 2);
  WidgetStateProperty<BorderSide?> focusSide([
    BorderSide? Function(Set<WidgetState>)? other,
  ]) => WidgetStateProperty.resolveWith((s) {
    if (s.contains(WidgetState.focused) && pbKeyboardMode) return ringSide();
    return other?.call(s);
  });
  WidgetStateProperty<Color?> fgDisabled() => WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.disabled) ? pb.disabledFg : null,
  );
  final cursor = WidgetStateMouseCursor.clickable;
  // The outer ring (2px, 2px gap) as the button's shape: only painted, the
  // geometry is [base]'s. Buttons, icon buttons; chips and segmented buttons
  // cannot (their shape does not depend on state), they keep the inset side.
  OutlinedBorder ringShape(OutlinedBorder base, Set<WidgetState> s) =>
      s.contains(WidgetState.focused) && pbKeyboardMode
      ? PbRingBorder(base, pb.focusRing)
      : base;
  WidgetStateProperty<OutlinedBorder?> stadiumRing() =>
      WidgetStateProperty.resolveWith(
        (s) => ringShape(const StadiumBorder(), s),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    textTheme: text,
    extensions: [pb],
    // Only the selection fill: caret and handles stay the accent.
    textSelectionTheme: TextSelectionThemeData(selectionColor: pb.selection),
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: pb.ink,
      titleTextStyle: serif(20),
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
        (states) =>
            focusSide().resolve(states) ??
            BorderSide(
              color: states.contains(WidgetState.selected)
                  ? accent.withValues(alpha: 0.55)
                  : states.contains(WidgetState.hovered)
                  ? pb.ink.withValues(alpha: 0.28)
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
      style: ButtonStyle(
        shape: WidgetStateProperty.resolveWith(
          (s) => ringShape(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            s,
          ),
        ),
        overlayColor: overlay(pb.filledHover, pb.filledPress),
        mouseCursor: cursor,
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? pb.disabledBg : null,
        ),
        foregroundColor: fgDisabled(),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        overlayColor: overlay(pb.filledHover, pb.filledPress),
        mouseCursor: cursor,
        foregroundColor: fgDisabled(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        overlayColor: overlay(pb.hover, pb.press),
        mouseCursor: cursor,
        shape: stadiumRing(),
        foregroundColor: fgDisabled(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        overlayColor: overlay(pb.hover, pb.press),
        mouseCursor: cursor,
        foregroundColor: fgDisabled(),
        shape: stadiumRing(),
        side: WidgetStateProperty.resolveWith(
          (s) => BorderSide(
            color: s.contains(WidgetState.hovered)
                ? pb.ink.withValues(alpha: 0.28)
                : pb.hairline,
          ),
        ),
      ),
    ),
    // IconButton.filled (the send button) overrides overlay and side itself.
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        overlayColor: overlay(pb.hover, pb.press),
        mouseCursor: cursor,
        shape: stadiumRing(),
        foregroundColor: fgDisabled(),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        overlayColor: overlay(pb.hover, pb.press),
        mouseCursor: cursor,
        side: focusSide(),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      // The sheet colour is translucent (it sits on a blur elsewhere); a menu
      // has no blur, so it is laid on the paper first.
      color: Color.alphaBlend(pb.sheet, pb.pdfPaper),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      mouseCursor: cursor,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      mouseCursor: cursor,
    ),
    // Hover 6%, pressed 12% (desktop: hover under the press highlight, so the
    // press reads as ~12%; touch: the ripple carries it). Focus stays a 12%
    // neutral tint for the rows without a ring (list tiles, menu rows, the
    // navigation bar); ringed controls switch it off themselves.
    hoverColor: pb.hover,
    focusColor: pb.press,
    highlightColor: touch ? Colors.transparent : pb.hover,
    splashColor: pb.press,
    splashFactory: touch ? null : NoSplash.splashFactory,
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: scheme.onPrimary,
      elevation: 6,
      shape: const StadiumBorder(),
      // The ring is a PbFocusRing around it; the fill darkens on hover.
      hoverColor: pb.filledHover,
      focusColor: Colors.transparent,
      splashColor: pb.filledPress,
      mouseCursor: cursor,
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
    // Form inputs only get the darker edge (controlEdge, 3:1); a focused
    // field is the neutral 2px ring colour, on click too (a text field is
    // always focused to type).
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: pb.glassStrong,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: pb.controlEdge),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: pb.controlEdge),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: pb.hairline),
      ),
      // Without this a focused field fell back to a form's own `border`.
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: pb.focusRing, width: 2),
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
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
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
            // Ink paints on the nearest Material, below this translucent
            // face, which dimmed any bare InkWell in a panel to ~26% (the
            // hover/focus looked dead). A transparent Material here puts the
            // ink above the face.
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
}
