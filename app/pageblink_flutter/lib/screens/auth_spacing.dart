import 'package:flutter/widgets.dart';

/// Layout offsets shared by every sign-in step (login, sign-up, code,
/// password, reset) so they all breathe the same. Values are sibling
/// offsets; a TextButton's own inner padding is not included.
/// Spec: docs/design/login-layout/spec.md §3.3.
abstract final class AuthSpacing {
  static const double cardPad = 32; // card inner padding, card width >= 600
  static const double cardPadCompact = 24; // card inner padding, < 600
  static const double title = 24; // form title -> first element
  static const double field = 16; // field <-> field, hint -> field
  static const double action = 24; // last field/link -> primary button
  static const double secondary = 8; // primary button -> secondary row
  static const double section = 24; // card -> note, hero -> card
  static const double buttonHeight = 52; // primary button min height (grows)

  /// Scroll padding for every TextField: keeps the link and the primary
  /// button above the keyboard when a field is focused.
  static const scrollPadding = EdgeInsets.fromLTRB(20, 20, 20, 152);
}

/// Stops Korean words breaking mid-word (U+2060 WORD JOINER between runes).
/// Titles and headlines only: copy, search and screen readers see the joiner.
/// ⚠️ Not yet checked on Flutter web (CanvasKit/skwasm).
String keepAll(String s) => s
    .split(' ')
    .map((w) => w.runes.map(String.fromCharCode).join('⁠'))
    .join(' ');
