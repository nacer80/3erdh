import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:recite_quran/recite_quran.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../app_state.dart';
import '../mushaf_service.dart';
import 'dialogs.dart';
import 'feedback_sidebar.dart';
import 'quran_canvas.dart';
import 'settings.dart';
import 'slim_nav_bar.dart';

/// 3erdh (عِرضْ) — Modern Real-time AI Quran Recitation & Memorization Studio.
/// Windows 3-Column Architecture:
/// - Right Bar: Discord-style minimal vertical rail with labels & hero record button
/// - Center Canvas: Pure authentic 15-line Medina Mushaf verses without any clutter
/// - Left Bar: Recitation inspector with live Tajweed errors per word, missed words, and stats
/// Adaptive Mobile Layout:
/// - Full-width Mushaf canvas + sleek modern bottom floating action rail & draggable sheet inspector
class TrackingScreen extends StatefulWidget {
  final HighlightingController controller;
  final bool isRecording;
  final bool isVoiceSearching;
  final String voiceSearchText;
  final VoidCallback onToggleRecord;
  final VoidCallback onVoiceSearchToggle;
  final bool isLoadingEngine;
  final ValueNotifier<bool>? isVoiceSearchLoading;
  final VoidCallback onClearBuffer;

  const TrackingScreen({
    super.key,
    required this.controller,
    required this.isRecording,
    required this.isVoiceSearching,
    this.voiceSearchText = '',
    required this.onToggleRecord,
    required this.onVoiceSearchToggle,
    this.isLoadingEngine = false,
    this.isVoiceSearchLoading,
    required this.onClearBuffer,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  final ListController _listController = ListController();
  final FocusNode _focusNode = FocusNode();
  int? _lastAyah;
  int? _lastSurah;
  bool _showTajweedBanner = false;
  bool _showDesktopLeftBar = true;

  // Recording session stopwatch timer
  Timer? _sessionTimer;
  int _sessionSeconds = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
    widget.controller.activeAyah.addListener(_onActiveAyahChanged);
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    widget.controller.removeListener(_onControllerUpdate);
    widget.controller.activeAyah.removeListener(_onActiveAyahChanged);
    _scroll.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TrackingScreen old) {
    super.didUpdateWidget(old);
    if (widget.isRecording && !old.isRecording) {
      _lastAyah = null;
      _sessionSeconds = 0;
      _sessionTimer?.cancel();
      _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _sessionSeconds++);
      });

      final active = widget.controller.activeAyah.value ?? 1;
      _forceScrollToAyah(active);
    } else if (!widget.isRecording && old.isRecording) {
      _sessionTimer?.cancel();
    }

    if (widget.isVoiceSearching && !old.isVoiceSearching) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          VoiceSearchDialog.show(
            context,
            onStop: widget.onVoiceSearchToggle,
            isLoading: widget.isVoiceSearchLoading,
          );
        }
      });
    } else if (!widget.isVoiceSearching && old.isVoiceSearching) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
      });
    }
  }

  void _onControllerUpdate() {
    if (widget.controller.targetSurah != _lastSurah) {
      setState(() {
        _lastSurah = widget.controller.targetSurah;
        _lastAyah = null;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  void _onActiveAyahChanged() {
    final active = widget.controller.activeAyah.value;
    if (active != null && active != _lastAyah) {
      _lastAyah = active;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _forceScrollToAyah(active);
      });
    }
  }

  void _forceScrollToAyah(int ayah) {
    if (!_scroll.hasClients) return;
    final surah = widget.controller.targetSurah;

    if (surah == 1 && ayah == 1) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    final loc = MushafService.instance.getPageAndLineForAyah(surah, ayah);
    if (loc == null) return;

    final surahPages = MushafService.instance.getPagesForSurah(surah);
    final pageIndex = surahPages.indexWhere((p) => p.pageNumber == loc.pageNumber);
    if (pageIndex < 0) return;

    final app = AppState.instance;
    final lineSlotHeight = app.fontSize * 1.55;

    double accumulatedTopOffset = 24.0;
    for (int p = 0; p < pageIndex; p++) {
      final prevPageLines = surahPages[p].lines.length;
      final prevCardHeight = 150.0 + (prevPageLines * lineSlotHeight);
      accumulatedTopOffset += prevCardHeight;
    }

    final double max = _scroll.position.maxScrollExtent;
    final double desiredOffset = (accumulatedTopOffset - 20.0).clamp(0.0, max > 0 ? max : double.infinity);

    final currentOffset = _scroll.offset;
    if ((currentOffset - desiredOffset).abs() > 30) {
      _scroll.animateTo(
        desiredOffset.clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onTajweedToggle() {
    final app = AppState.instance;
    final newMode = app.currentMode == AppMode.tajweed ? AppMode.wordChecker : AppMode.tajweed;
    app.setMode(newMode);
    widget.controller.setTajweedMode(newMode == AppMode.tajweed);
    if (newMode == AppMode.tajweed) {
      setState(() => _showTajweedBanner = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showTajweedBanner = false);
      });
    }
  }

  void _openSurahPicker() {
    SurahPickerSheet.show(
      context,
      current: widget.controller.targetSurah,
      onPick: (surah, {int? ayah}) {
        Navigator.pop(context);
        widget.controller.setTargetSurah(surah);
        if (ayah != null) widget.controller.setManualAyah(surah, ayah);
      },
      controller: widget.controller,
      isRecording: widget.isRecording,
      isVoiceSearching: widget.isVoiceSearching,
      onToggleRecord: widget.onToggleRecord,
      onVoiceSearchToggle: widget.onVoiceSearchToggle,
    );
  }

  void _openMobileInspector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final app = AppState.instance;
        final c = app.colors;
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: c.border.withValues(alpha: 0.6)),
              ),
              child: FeedbackSidebar(
                controller: widget.controller,
                isRecording: widget.isRecording,
                isLoadingEngine: widget.isLoadingEngine,
                onToggleRecord: widget.onToggleRecord,
                onClearBuffer: widget.onClearBuffer,
                onTajweedToggle: _onTajweedToggle,
                width: double.infinity,
                onClose: () => Navigator.pop(ctx),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final c = app.colors;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.space): () {
          if (widget.isVoiceSearching) {
            widget.onVoiceSearchToggle();
          } else {
            widget.onToggleRecord();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          widget.onVoiceSearchToggle();
        },
        const SingleActivator(LogicalKeyboardKey.keyT): () {
          _onTajweedToggle();
        },
        const SingleActivator(LogicalKeyboardKey.keyM): () {
          app.toggleBlurMode();
        },
        const SingleActivator(LogicalKeyboardKey.equal, control: true): () {
          if (app.fontSize < AppConstants.maxFontSize) {
            app.setFontSize((app.fontSize + 2).clamp(AppConstants.minFontSize, AppConstants.maxFontSize));
          }
        },
        const SingleActivator(LogicalKeyboardKey.minus, control: true): () {
          if (app.fontSize > AppConstants.minFontSize) {
            app.setFontSize((app.fontSize - 2).clamp(AppConstants.minFontSize, AppConstants.maxFontSize));
          }
        },
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: c.bg,
            body: LayoutBuilder(
              builder: (context, constraints) {
                final bool isDesktop = constraints.maxWidth >= 850;

                // ══════════════════════════════════════════════════════════════
                // 1. WINDOWS DESKTOP 3-COLUMN ARCHITECTURE (RTL: Right, Center, Left)
                // ══════════════════════════════════════════════════════════════
                if (isDesktop) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Right Bar (First in RTL Row): Discord-style Nav Rail ──
                        SlimNavBar(
                          onToggleRecord: widget.onToggleRecord,
                          isRecording: widget.isRecording,
                          isLoadingEngine: widget.isLoadingEngine,
                          onSettingsTap: () => SettingsDialog.show(context),
                          onTajweedToggle: _onTajweedToggle,
                          onSurahTap: _openSurahPicker,
                          onVoiceSearchToggle: widget.onVoiceSearchToggle,
                          isVoiceSearching: widget.isVoiceSearching,
                        ),

                        const SizedBox(width: 14),

                        // ── Center Canvas (Second in RTL Row): PURE MUSHAF ONLY ──
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: QuranCanvas(
                                  controller: widget.controller,
                                  scrollController: _scroll,
                                  listController: _listController,
                                  isRecording: widget.isRecording,
                                  showTajweedBanner: _showTajweedBanner,
                                  onToggleRecord: widget.onToggleRecord,
                                  isLoadingEngine: widget.isLoadingEngine,
                                  padding: EdgeInsets.zero,
                                ),
                              ),

                              // Quick Left Bar Toggle Floating Pill (if collapsed)
                              if (!_showDesktopLeftBar)
                                Positioned(
                                  left: 12,
                                  top: 12,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _showDesktopLeftBar = true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: c.surface.withValues(alpha: 0.9),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: c.gold.withValues(alpha: 0.5)),
                                          boxShadow: const [
                                            BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 3)),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.analytics_outlined, color: c.gold, size: 17),
                                            const SizedBox(width: 6),
                                            Text(
                                              'لوحة التقييم',
                                              style: TextStyle(
                                                color: c.text,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // ── Left Bar (Third in RTL Row): Recitation & Tajweed Errors Inspector ──
                        if (_showDesktopLeftBar) ...[
                          const SizedBox(width: 14),
                          FeedbackSidebar(
                            controller: widget.controller,
                            isRecording: widget.isRecording,
                            isLoadingEngine: widget.isLoadingEngine,
                            onToggleRecord: widget.onToggleRecord,
                            onClearBuffer: widget.onClearBuffer,
                            onTajweedToggle: _onTajweedToggle,
                            width: 320,
                            onClose: () => setState(() => _showDesktopLeftBar = false),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                // ══════════════════════════════════════════════════════════════
                // 2. ANDROID MOBILE / NARROW SCREEN ADAPTATION
                // ══════════════════════════════════════════════════════════════
                return Stack(
                  children: [
                    // ── Full-Width Pure Medina Mushaf Canvas ──
                    Positioned.fill(
                      child: QuranCanvas(
                        controller: widget.controller,
                        scrollController: _scroll,
                        listController: _listController,
                        isRecording: widget.isRecording,
                        showTajweedBanner: _showTajweedBanner,
                        onToggleRecord: widget.onToggleRecord,
                        isLoadingEngine: widget.isLoadingEngine,
                        padding: const EdgeInsets.only(bottom: 96, top: 8, left: 6, right: 6),
                      ),
                    ),

                    // ── Mobile Bottom Action Dock ──
                    Positioned(
                      bottom: 14,
                      left: 14,
                      right: 14,
                      child: _MobileBottomBar(
                        isRecording: widget.isRecording,
                        isLoadingEngine: widget.isLoadingEngine,
                        isVoiceSearching: widget.isVoiceSearching,
                        onToggleRecord: widget.onToggleRecord,
                        onSurahTap: _openSurahPicker,
                        onVoiceSearchToggle: widget.onVoiceSearchToggle,
                        onTajweedToggle: _onTajweedToggle,
                        onInspectorTap: _openMobileInspector,
                        onSettingsTap: () => SettingsDialog.show(context),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Sleek floating mobile action dock for Android phones and small tablets.
class _MobileBottomBar extends StatelessWidget {
  final bool isRecording;
  final bool isLoadingEngine;
  final bool isVoiceSearching;
  final VoidCallback onToggleRecord;
  final VoidCallback onSurahTap;
  final VoidCallback onVoiceSearchToggle;
  final VoidCallback onTajweedToggle;
  final VoidCallback onInspectorTap;
  final VoidCallback onSettingsTap;

  const _MobileBottomBar({
    required this.isRecording,
    required this.isLoadingEngine,
    required this.isVoiceSearching,
    required this.onToggleRecord,
    required this.onSurahTap,
    required this.onVoiceSearchToggle,
    required this.onTajweedToggle,
    required this.onInspectorTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final c = app.colors;
    final isTajweed = app.currentMode == AppMode.tajweed;
    final isBlur = app.isBlurMode;

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ColorFilter.mode(Colors.black.withValues(alpha: 0.1), BlendMode.srcOver),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: c.border.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 1. Surahs Directory
              _mobileIconBtn(
                icon: Icons.menu_book_rounded,
                tooltip: 'السور',
                c: c,
                onTap: onSurahTap,
              ),

              // 2. Voice Search
              _mobileIconBtn(
                icon: Icons.search_rounded,
                tooltip: 'بحث صوتي',
                color: isVoiceSearching ? c.gold : null,
                c: c,
                onTap: onVoiceSearchToggle,
              ),

              // 3. Hero Center Record Button
              GestureDetector(
                onTap: isLoadingEngine ? null : onToggleRecord,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isRecording
                          ? [c.red, c.red.withValues(alpha: 0.85)]
                          : [c.gold, c.gold.withValues(alpha: 0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (isRecording ? c.red : c.gold).withValues(alpha: 0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoadingEngine)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      else
                        Icon(
                          isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          color: c.isDark ? Colors.black : Colors.white,
                          size: 21,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        isRecording ? 'إيقاف' : 'تلاوة',
                        style: TextStyle(
                          color: c.isDark ? Colors.black : Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Tajweed Toggle
              _mobileIconBtn(
                icon: Icons.verified_rounded,
                tooltip: 'تجويد',
                color: isTajweed ? c.gold : null,
                c: c,
                onTap: onTajweedToggle,
              ),

              // 5. Memorize / Blur Mode
              _mobileIconBtn(
                icon: isBlur ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                tooltip: 'تسميع',
                color: isBlur ? c.green : null,
                c: c,
                onTap: app.toggleBlurMode,
              ),

              // 6. Recitation Inspector Sheet
              _mobileIconBtn(
                icon: Icons.analytics_outlined,
                tooltip: 'التقييم والأخطاء',
                color: c.gold,
                c: c,
                onTap: onInspectorTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileIconBtn({
    required IconData icon,
    required String tooltip,
    Color? color,
    required ThemeColors c,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(
            icon,
            color: color ?? c.text.withValues(alpha: 0.8),
            size: 22,
          ),
        ),
      ),
    );
  }
}
