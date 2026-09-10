import 'package:flutter/material.dart';

import '../app_state.dart';

/// Discord-inspired minimalist vertical navigation rail for Windows desktop & wide screens.
/// Features clean squircles, side pill indicators, smooth hovers, and clear labels for all actions.
class SlimNavBar extends StatelessWidget {
  final VoidCallback onToggleRecord;
  final bool isRecording;
  final bool isLoadingEngine;
  final VoidCallback onSettingsTap;
  final VoidCallback onTajweedToggle;
  final VoidCallback onSurahTap;
  final VoidCallback onVoiceSearchToggle;
  final bool isVoiceSearching;

  const SlimNavBar({
    super.key,
    required this.onToggleRecord,
    this.isRecording = false,
    this.isLoadingEngine = false,
    required this.onSettingsTap,
    required this.onTajweedToggle,
    required this.onSurahTap,
    required this.onVoiceSearchToggle,
    this.isVoiceSearching = false,
  });

  void _showFontSliderFlyout(BuildContext context, bool isRtl) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'FontSliderFlyout',
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            Positioned(
              right: isRtl ? 96 : null,
              left: isRtl ? null : 96,
              bottom: 80,
              child: const Material(
                color: Colors.transparent,
                child: _FontFlyoutCard(),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;

    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final c = app.colors;
        final isAr = app.isArabic;
        final isTajweed = app.currentMode == AppMode.tajweed;
        final isBlur = app.isBlurMode;

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ColorFilter.mode(Colors.black.withValues(alpha: 0.05), BlendMode.srcOver),
            child: Container(
              width: 86,
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: c.border.withValues(alpha: 0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: c.isDark ? 0.25 : 0.06),
                    blurRadius: 24,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // ── Top App Brand Badge: Ayat / 3erdh ────────────────
                  Tooltip(
                    message: AppConstants.appName,
                    preferBelow: false,
                    child: Container(
                      width: 52,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [c.gold, c.gold.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: c.gold.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'عِرضْ',
                          style: TextStyle(
                            fontFamily: AppConstants.hafsFontFamily,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: c.isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                  Divider(height: 1, indent: 16, endIndent: 16, color: c.border.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),

                  // ── 1. Hero Record / Recite Button ──────────────────
                  _DiscordNavButton(
                    icon: isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    label: isRecording ? (isAr ? 'إيقاف' : 'Stop') : (isAr ? 'تلاوة' : 'Recite'),
                    tooltip: isRecording
                        ? (isAr ? 'إنهاء التلاوة [Space]' : 'Stop Reciting [Space]')
                        : (isAr ? 'بدء التلاوة والمطابقة [Space]' : 'Start Reciting [Space]'),
                    color: isRecording ? c.red : c.gold,
                    isActive: isRecording,
                    activeColor: isRecording ? c.red : c.gold,
                    isHero: true,
                    isLoading: isLoadingEngine,
                    onTap: onToggleRecord,
                  ),

                  const SizedBox(height: 8),

                  // ── 2. Surah Selector ───────────────────────────────
                  _DiscordNavButton(
                    icon: Icons.menu_book_rounded,
                    label: isAr ? 'السور' : 'Surahs',
                    tooltip: isAr ? 'فهرس سور القرآن الكريم' : 'Surah Directory',
                    color: c.gold,
                    onTap: onSurahTap,
                  ),

                  const SizedBox(height: 8),

                  // ── 3. Voice Search ─────────────────────────────────
                  _DiscordNavButton(
                    icon: Icons.search_rounded,
                    label: isAr ? 'بحث صوتي' : 'Search',
                    tooltip: isAr ? 'البحث الصوتي عن آية (Ctrl+F)' : 'Voice Search (Ctrl+F)',
                    color: isVoiceSearching ? c.gold : c.text.withValues(alpha: 0.85),
                    isActive: isVoiceSearching,
                    activeColor: c.gold,
                    onTap: onVoiceSearchToggle,
                  ),

                  const SizedBox(height: 8),

                  // ── 4. Hide Verse / Memorization (التسميع) ─────────
                  _DiscordNavButton(
                    icon: isBlur ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    label: isAr ? 'تسميع' : 'Memorize',
                    tooltip: isBlur
                        ? (isAr ? 'وضع التسميع: مفعّل (إخفاء حتى تنطق) (M)' : 'Memorize Mode: ON (M)')
                        : (isAr ? 'وضع التسميع: معطّل (M)' : 'Memorize Mode: OFF (M)'),
                    color: isBlur ? c.green : c.text.withValues(alpha: 0.85),
                    isActive: isBlur,
                    activeColor: c.green,
                    onTap: app.toggleBlurMode,
                  ),

                  const SizedBox(height: 8),

                  // ── 5. Tajweed Diagnostic (التجويد) ────────────────
                  _DiscordNavButton(
                    icon: Icons.verified_rounded,
                    label: isAr ? 'تجويد' : 'Tajweed',
                    tooltip: isTajweed
                        ? (isAr ? 'تشخيص التجويد: مفعّل (T)' : 'Tajweed Diagnostics: ON (T)')
                        : (isAr ? 'تشخيص التجويد: معطّل (T)' : 'Tajweed Diagnostics: OFF (T)'),
                    color: isTajweed ? c.gold : c.text.withValues(alpha: 0.85),
                    isActive: isTajweed,
                    activeColor: c.gold,
                    onTap: onTajweedToggle,
                  ),

                  const Spacer(),

                  // ── 6. Font Scale Flyout ────────────────────────────
                  _DiscordNavButton(
                    icon: Icons.format_size_rounded,
                    label: isAr ? 'الخط' : 'Font',
                    tooltip: isAr ? 'تعديل حجم خط المصحف' : 'Adjust Font Size',
                    color: c.muted,
                    onTap: () => _showFontSliderFlyout(context, isAr),
                  ),

                  const SizedBox(height: 6),

                  // ── 7. Theme Switcher ───────────────────────────────
                  _DiscordNavButton(
                    icon: app.theme == AppThemeMode.dark
                        ? Icons.dark_mode_rounded
                        : (app.theme == AppThemeMode.sepia ? Icons.menu_book_outlined : Icons.light_mode_rounded),
                    label: isAr ? 'المظهر' : 'Theme',
                    tooltip: isAr ? 'تبديل المظهر (داكن / فاتح / صحراوي)' : 'Switch Theme',
                    color: c.gold,
                    onTap: app.cycleTheme,
                  ),

                  const SizedBox(height: 6),

                  // ── 8. Settings ────────────────────────────────────
                  _DiscordNavButton(
                    icon: Icons.settings_rounded,
                    label: isAr ? 'الإعدادات' : 'Settings',
                    tooltip: isAr ? 'إعدادات التطبيق' : 'Settings',
                    color: c.text.withValues(alpha: 0.85),
                    onTap: onSettingsTap,
                  ),

                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Discord-style navigation rail button with rounded squircle, side active pill, smooth hover, and bold label.
class _DiscordNavButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final Color color;
  final bool isActive;
  final Color? activeColor;
  final bool isHero;
  final bool isLoading;
  final VoidCallback onTap;

  const _DiscordNavButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.color,
    this.isActive = false,
    this.activeColor,
    this.isHero = false,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  State<_DiscordNavButton> createState() => _DiscordNavButtonState();
}

class _DiscordNavButtonState extends State<_DiscordNavButton> with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = AppState.instance.colors;
    final highlightColor = widget.activeColor ?? widget.color;

    return Tooltip(
      message: widget.tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 250),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.isLoading ? null : widget.onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Discord Pill Active Indicator Bar (outer side) ──
              if (widget.isActive && !widget.isHero)
                Positioned(
                  right: 3,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 4,
                    height: 28,
                    decoration: BoxDecoration(
                      color: highlightColor,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: highlightColor.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Button Body ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(
                  gradient: widget.isHero
                      ? LinearGradient(
                          colors: widget.isActive
                              ? [c.red, c.red.withValues(alpha: 0.85)]
                              : [c.gold, c.gold.withValues(alpha: 0.85)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: widget.isHero
                      ? null
                      : (widget.isActive
                          ? highlightColor.withValues(alpha: 0.18)
                          : (_isHovered ? c.surfaceHigh : Colors.transparent)),
                  borderRadius: BorderRadius.circular(widget.isHero ? 18 : 14),
                  border: Border.all(
                    color: widget.isHero
                        ? (widget.isActive ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A))
                        : (widget.isActive
                            ? highlightColor.withValues(alpha: 0.6)
                            : (_isHovered ? c.border.withValues(alpha: 0.4) : Colors.transparent)),
                    width: widget.isHero ? 1.5 : 1.2,
                  ),
                  boxShadow: widget.isHero
                      ? [
                          BoxShadow(
                            color: (widget.isActive ? c.red : c.gold).withValues(alpha: widget.isActive ? 0.5 : 0.3),
                            blurRadius: widget.isActive ? 16 : 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 26,
                      child: Center(
                        child: widget.isLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    widget.isHero ? Colors.white : highlightColor,
                                  ),
                                ),
                              )
                            : Icon(
                                widget.icon,
                                color: widget.isHero
                                    ? (c.isDark ? Colors.black : Colors.white)
                                    : (widget.isActive ? highlightColor : (_isHovered ? c.text : c.muted)),
                                size: widget.isHero ? 23 : 21,
                              ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: (widget.isActive || widget.isHero) ? FontWeight.bold : FontWeight.w600,
                        color: widget.isHero
                            ? (c.isDark ? Colors.black : Colors.white)
                            : (widget.isActive ? highlightColor : (_isHovered ? c.text : c.muted)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating Flyout card for adjusting font size with a live slider.
class _FontFlyoutCard extends StatefulWidget {
  const _FontFlyoutCard();

  @override
  State<_FontFlyoutCard> createState() => _FontFlyoutCardState();
}

class _FontFlyoutCardState extends State<_FontFlyoutCard> {
  late double _val = AppState.instance.fontSize;

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final c = app.colors;
    final isAr = app.isArabic;

    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border.withValues(alpha: 0.5), width: 1.4),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 28, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAr ? 'حجم خط المصحف' : 'Font Size',
                style: TextStyle(color: c.text, fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: c.surfaceHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_val.round()} pt',
                  style: TextStyle(color: c.gold, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.remove_rounded, color: c.muted, size: 18),
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  if (_val > AppConstants.minFontSize) {
                    final nv = (_val - 2).clamp(AppConstants.minFontSize, AppConstants.maxFontSize);
                    setState(() => _val = nv);
                    app.setFontSize(nv);
                  }
                },
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3.5,
                    activeTrackColor: c.gold,
                    inactiveTrackColor: c.border.withValues(alpha: 0.3),
                    thumbColor: c.gold,
                    overlayColor: c.gold.withValues(alpha: 0.15),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                  ),
                  child: Slider(
                    value: _val,
                    min: AppConstants.minFontSize,
                    max: AppConstants.maxFontSize,
                    onChanged: (v) => setState(() => _val = v),
                    onChangeEnd: (v) => app.setFontSize(v),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_rounded, color: c.muted, size: 18),
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  if (_val < AppConstants.maxFontSize) {
                    final nv = (_val + 2).clamp(AppConstants.minFontSize, AppConstants.maxFontSize);
                    setState(() => _val = nv);
                    app.setFontSize(nv);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
