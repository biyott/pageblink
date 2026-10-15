import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Semantic icon names, mapped to Lucide in one place (ADR 016).
/// Swapping the icon set means editing only this file.
abstract final class AppIcons {
  // Content kinds
  static const note = LucideIcons.stickyNote;
  static const pdf = LucideIcons.fileText; // Lucide has no PDF glyph
  static const projects = LucideIcons.users;

  // Brand / Ask tab (existing bolt) and the citation chip. Violet is applied by callers.
  static const ask = LucideIcons.zap;
  static const citation = LucideIcons.zap;

  // Selected variants for NavigationBar/Rail (Lucide has no fill; heavier stroke instead)
  static const askSelected = LucideIcons.zap600;
  static const noteSelected = LucideIcons.stickyNote600;
  static const projectsSelected = LucideIcons.users600;

  // Scope / tier
  static const tierCloud = LucideIcons.cloud;
  static const tierDevice = LucideIcons.smartphone;
  static const tierShared = LucideIcons.users;
  static const privacy = LucideIcons.shield;
  static const scope = LucideIcons.textSearch;

  // Actions
  static const newQuestion = LucideIcons.messageSquarePlus;
  static const newNote = LucideIcons.squarePen;
  static const newProject = LucideIcons.userPlus;
  static const invite = LucideIcons.userPlus;
  static const add = LucideIcons.plus;
  static const upload = LucideIcons.upload;
  static const edit = LucideIcons.pencil;
  static const preview = LucideIcons.bookOpen;
  static const search = LucideIcons.search;
  static const copy = LucideIcons.copy;
  static const send = LucideIcons.arrowUp;
  static const refresh = LucideIcons.refreshCw;
  static const settings = LucideIcons.settings;
  static const signOut = LucideIcons.logOut;
  static const check = LucideIcons.check;
  static const close = LucideIcons.x;

  // Navigation
  static const back = LucideIcons.arrowLeft;
  static const previous = LucideIcons.chevronLeft;
  static const next = LucideIcons.chevronRight;
  static const expand = LucideIcons.chevronDown;

  // Status
  static const error = LucideIcons.circleAlert;
  static const warning = LucideIcons.triangleAlert;
  static const syncFailed = LucideIcons.refreshCwOff;

  // Markdown toolbar
  static const heading = LucideIcons.heading;
  static const bold = LucideIcons.bold;
  static const italic = LucideIcons.italic;
  static const bulletList = LucideIcons.list;
  static const checklist = LucideIcons.squareCheck;
  static const quote = LucideIcons.quote;
  static const code = LucideIcons.code;
}
