import 'package:flutter/material.dart';

import 'theme.dart';

/// Centered message for an empty or failed page: an optional 56 dp accent
/// circle with [icon], a serif [title], a muted [body] and one [action].
class PbEmptyState extends StatelessWidget {
  const PbEmptyState({
    super.key,
    this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData? icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final text = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: pb.accentContainer,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 56,
                    child: Icon(icon, size: 28, color: pb.accent),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(title, textAlign: TextAlign.center, style: text.titleLarge),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: pb.inkMuted),
              ),
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}
