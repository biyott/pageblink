import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Semantic icon names, mapped to Lucide in one place (ADR 016).
/// Swapping the icon set means editing only this file.
abstract final class AppIcons {
  // Content kinds
  static const note = LucideIcons.stickyNote;
  static const pdf = LucideIcons.fileText; // Lucide has no PDF glyph
  static const projects = LucideIcons.users;

  // Wordmark glyph: the 4-point star of the V1b app icon (ADR 016).
  static const brand = LucideIcons.sparkle;

  // Ask tab, and the citation chip (the only place the bolt is used, ADR 016).
  // Violet is applied by callers.
  static const ask = LucideIcons.messageCircleQuestion;
  static const citation = LucideIcons.zap;
  // Heavier stroke for the 10px bolt in the inline ⚡n marker pill.
  static const citationMarker = LucideIcons.zap600;

  // Selected variants for NavigationBar/Rail (Lucide has no fill; heavier stroke instead)
  static const askSelected = LucideIcons.messageCircleQuestion600;
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
  static const newProject = LucideIcons.folderPlus;
  static const invite = LucideIcons.userPlus;
  static const add = LucideIcons.plus;
  static const upload = LucideIcons.upload;
  static const edit = LucideIcons.pencil;
  static const delete = LucideIcons.trash2;
  static const more = LucideIcons.ellipsisVertical;
  static const preview = LucideIcons.bookOpen;
  static const search = LucideIcons.search;
  static const copy = LucideIcons.copy;
  static const send = LucideIcons.arrowUp;
  static const refresh = LucideIcons.refreshCw;
  static const settings = LucideIcons.settings;
  static const language = LucideIcons.languages;
  static const signOut = LucideIcons.logOut;
  static const demo = LucideIcons.play;
  static const check = LucideIcons.check;
  static const close = LucideIcons.x;
  // Password field: the icon shows what tapping does.
  static const showPassword = LucideIcons.eye;
  static const hidePassword = LucideIcons.eyeOff;

  // Navigation
  static const back = LucideIcons.arrowLeft;
  static const previous = LucideIcons.chevronLeft;
  static const next = LucideIcons.chevronRight;
  static const expand = LucideIcons.chevronDown;

  // Status
  static const error = LucideIcons.circleAlert;
  static const warning = LucideIcons.triangleAlert;
  static const syncFailed = LucideIcons.refreshCwOff;
  static const info = LucideIcons.info;
  static const done = LucideIcons.circleCheck;

  // PDF drop zone + upload tray
  static const fileUp = LucideIcons.fileUp;
  static const fileWarning = LucideIcons.fileWarning;

  // Markdown toolbar
  static const heading = LucideIcons.heading;
  static const bold = LucideIcons.bold;
  static const italic = LucideIcons.italic;
  static const bulletList = LucideIcons.list;
  static const checklist = LucideIcons.squareCheck;
  static const quote = LucideIcons.quote;
  static const code = LucideIcons.code;
  static const link = LucideIcons.link;
  static const strikethrough = LucideIcons.strikethrough;
  static const orderedList = LucideIcons.listOrdered;
  static const openLink = LucideIcons.externalLink;
  static const unlink = LucideIcons.unlink;

  // Live | Source toggle (narrow phones show icons only)
  static const modeLive = LucideIcons.pencilLine;
  static const modeSource = LucideIcons.fileCode;
}
