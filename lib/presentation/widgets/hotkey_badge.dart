import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class HotkeyBadge extends StatelessWidget {
  final String label;
  final String keyName;
  final VoidCallback? onTap;
  final Color? color;

  const HotkeyBadge({
    super.key,
    required this.label,
    required this.keyName,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color?.withValues(alpha: 0.15) ?? AppTheme.hotkeyBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: color ?? AppTheme.cardBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color ?? const Color(0xFF475569),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                keyName,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color ?? AppTheme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
