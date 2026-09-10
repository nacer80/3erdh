import 'package:flutter/material.dart';

import '../app_state.dart';
import 'dialogs.dart';

/// Settings dialog designed for Windows desktop.
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  static void show(BuildContext context) => showDialog(
        context: context,
        builder: (_) => const SettingsDialog(),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;

    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final c = app.colors;
        final isAr = app.isArabic;

        return AppDialogContainer(
          colors: c,
          maxWidth: 560,
          padding: const EdgeInsets.all(22),
          child: Directionality(
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header Bar ─────────────────────────────────────────
                DialogHeader(
                  icon: Icons.settings_rounded,
                  title: isAr ? 'الإعدادات' : 'Settings',
                  subtitle: isAr ? 'تخصيص مظهر وتجربة تلاوة القرآن' : 'Customize app theme and reading experience',
                  colors: c,
                ),

                const SizedBox(height: 16),

                // ── Settings Body ──────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: c.surfaceHigh,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: c.border.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            children: [
                              // Language
                              SettingTile(
                                icon: Icons.language_rounded,
                                title: isAr ? 'اللغة' : 'Language',
                                c: c,
                                trailing: PremiumPillSelector(
                                  labels: const ['عربي', 'English'],
                                  selected: isAr ? 0 : 1,
                                  c: c,
                                  onSelected: (i) {
                                    if ((i == 0 && !isAr) || (i == 1 && isAr)) app.toggleLanguage();
                                  },
                                ),
                              ),
                              Divider(height: 1, color: c.border.withValues(alpha: 0.15)),

                              // Theme
                              SettingTile(
                                icon: Icons.palette_rounded,
                                title: isAr ? 'المظهر' : 'Theme',
                                c: c,
                                trailing: PremiumPillSelector(
                                  labels: isAr ? ['داكن', 'فاتح'] : ['Dark', 'Light'],
                                  selected: app.isDarkMode ? 0 : 1,
                                  c: c,
                                  onSelected: (i) => app.setTheme(i == 0 ? AppThemeMode.dark : AppThemeMode.light),
                                ),
                              ),
                              Divider(height: 1, color: c.border.withValues(alpha: 0.15)),

                              // Font Size with Live Preview
                              FontSliderTile(c: c, app: app, isAr: isAr),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Bottom Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                await app.resetSettings();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isAr ? 'تمت استعادة الإعدادات الافتراضية.' : 'Settings reset to default.'),
                                      backgroundColor: c.gold,
                                    ),
                                  );
                                }
                              },
                              icon: Icon(Icons.refresh_rounded, size: 16, color: c.muted),
                              label: Text(
                                isAr ? 'استعادة الافتراضي' : 'Reset to Default',
                                style: TextStyle(color: c.muted, fontSize: 12),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: c.gold,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(isAr ? 'حفظ وإغلاق' : 'Done', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            'ربنا تقبل منا إنك أنت السميع العليم',
                            style: TextStyle(
                              fontFamily: AppConstants.hafsFontFamily,
                              color: c.gold.withValues(alpha: 0.45),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Setting Tile Widgets ─────────────────────────────────────────────────────

class SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final ThemeColors c;
  final Widget? trailing;
  final Widget? bottom;

  const SettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.c,
    this.trailing,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: c.gold, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (bottom != null) ...[const SizedBox(height: 8), bottom!],
          ],
        ),
      );
}

class PremiumPillSelector extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ThemeColors c;
  final ValueChanged<int> onSelected;

  const PremiumPillSelector({
    super.key,
    required this.labels,
    required this.selected,
    required this.c,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border.withValues(alpha: 0.25)),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(labels.length, (i) {
            final isSel = selected == i;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSel ? c.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSel
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: isSel ? c.gold : c.muted,
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );
}

class FontSliderTile extends StatefulWidget {
  final ThemeColors c;
  final AppState app;
  final bool isAr;

  const FontSliderTile({
    super.key,
    required this.c,
    required this.app,
    required this.isAr,
  });

  @override
  State<FontSliderTile> createState() => _FontSliderTileState();
}

class _FontSliderTileState extends State<FontSliderTile> {
  late double _localSize = widget.app.fontSize;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.format_size_rounded, color: c.gold, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.isAr ? 'حجم خط المصحف' : 'Mushaf Font Size',
                  style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: c.border.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${_localSize.round()} pt',
                  style: TextStyle(color: c.gold, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Live Ayah Preview Box
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: AppConstants.hafsFontFamily,
                  fontSize: _localSize * 0.85,
                  color: c.text,
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: c.gold,
              inactiveTrackColor: c.border.withValues(alpha: 0.3),
              thumbColor: c.gold,
              overlayColor: c.gold.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: _localSize,
              min: AppConstants.minFontSize,
              max: AppConstants.maxFontSize,
              onChanged: (v) => setState(() => _localSize = v),
              onChangeEnd: (v) => widget.app.setFontSize(v),
            ),
          ),
        ],
      ),
    );
  }
}
