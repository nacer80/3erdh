import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import 'package:recite_quran/recite_quran.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../app_state.dart';
import '../mushaf_service.dart';
import 'dialogs.dart';

/// Central Quran Canvas.
/// Authentic 15-Line Medina Mushaf layout: exact 15 lines per page, fixed word positions,
/// ornate Islamic headers/frames, circular Ayah rosettes, and real-time recitation tracking.
class QuranCanvas extends StatelessWidget {
  final HighlightingController controller;
  final ScrollController scrollController;
  final ListController? listController;
  final bool isRecording;
  final bool showTajweedBanner;
  final VoidCallback? onToggleRecord;
  final bool isLoadingEngine;
  final EdgeInsetsGeometry? padding;

  const QuranCanvas({
    super.key,
    required this.controller,
    required this.scrollController,
    this.listController,
    required this.isRecording,
    this.showTajweedBanner = false,
    this.onToggleRecord,
    this.isLoadingEngine = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final c = app.colors;

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Stack(
        children: [
          // ── Virtualized 15-Line Medina Mushaf Pages ────────────────
          Positioned.fill(
            child: MedinaMushafView(
              controller: controller,
              scrollController: scrollController,
              isRecording: isRecording,
            ),
          ),

          // ── Tajweed Active Notification Toast ──────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: showTajweedBanner ? 16 : -60,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 20),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.gold.withValues(alpha: 0.5)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: c.gold, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        app.isArabic
                            ? 'وضع التجويد مفعّل: اضغط على الكلمات الملونة لعرض الملاحظات'
                            : 'Tajweed active: Tap colored words to inspect rules',
                        style: TextStyle(
                          color: c.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Backward compatibility alias
typedef QuranCanvasDesktop = QuranCanvas;

// ── Medina Mushaf Virtualized Scroll View ───────────────────────────────────

class MedinaMushafView extends StatefulWidget {
  final HighlightingController controller;
  final ScrollController scrollController;
  final bool isRecording;

  const MedinaMushafView({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.isRecording,
  });

  @override
  State<MedinaMushafView> createState() => _MedinaMushafViewState();
}

class _MedinaMushafViewState extends State<MedinaMushafView> {
  late List<MushafPage> _pages = [];
  int? _lastSurah;

  @override
  void initState() {
    super.initState();
    _updatePages();
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void didUpdateWidget(MedinaMushafView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChange);
      widget.controller.addListener(_onControllerChange);
      _updatePages();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    if (widget.controller.targetSurah != _lastSurah) {
      _updatePages();
      if (mounted) setState(() {});
    }
  }

  void _updatePages() {
    _lastSurah = widget.controller.targetSurah;
    if (_lastSurah == null) {
      _pages = [];
      return;
    }

    final pages = MushafService.instance.getPagesForSurah(_lastSurah!);
    if (pages.isNotEmpty) {
      _pages = pages;
    } else {
      _pages = MushafService.instance.allPages;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 600;

    // Virtualized ListView ensures instant loading even with Surah Al-Baqarah (48 pages)
    return ListView.builder(
      controller: widget.scrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 16,
        vertical: 20,
      ),
      itemCount: _pages.length,
      itemBuilder: (context, index) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Medina15LinePageCard(
                key: ValueKey('medina_page_${_pages[index].pageNumber}'),
                page: _pages[index],
                controller: widget.controller,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── 15-Line Medina Page Card ────────────────────────────────────────────────

class Medina15LinePageCard extends StatefulWidget {
  final MushafPage page;
  final HighlightingController controller;

  const Medina15LinePageCard({
    super.key,
    required this.page,
    required this.controller,
  });

  @override
  State<Medina15LinePageCard> createState() => _Medina15LinePageCardState();
}

class _Medina15LinePageCardState extends State<Medina15LinePageCard> {
  @override
  void initState() {
    super.initState();
    widget.controller.activeAyah.addListener(_onStateChanged);
    widget.controller.globalRevision.addListener(_onStateChanged);
    AppState.instance.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(Medina15LinePageCard old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller || old.page != widget.page) {
      old.controller.activeAyah.removeListener(_onStateChanged);
      old.controller.globalRevision.removeListener(_onStateChanged);
      widget.controller.activeAyah.addListener(_onStateChanged);
      widget.controller.globalRevision.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.activeAyah.removeListener(_onStateChanged);
    widget.controller.globalRevision.removeListener(_onStateChanged);
    AppState.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final c = app.colors;
    final page = widget.page;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 600;

    // Header metadata
    final surahNum = page.firstSurah ?? (page.surahNumbers.isNotEmpty ? page.surahNumbers.first : 1);
    final surahName = quran.getSurahNameArabic(surahNum);
    final juzNum = page.juzNumber;
    final pageNumStr = page.pageNumber.toArabicDigits();

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.surface,
            c.surfaceHigh,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.gold.withValues(alpha: 0.65), width: isSmallScreen ? 1.5 : 2.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: c.isDark ? 0.35 : 0.08),
            blurRadius: 28,
            spreadRadius: 1,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: c.isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        margin: EdgeInsets.all(isSmallScreen ? 4 : 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border.withValues(alpha: 0.4), width: 1),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 10 : 20,
          vertical: isSmallScreen ? 12 : 18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Header Ribbon (Surah Name & Juz Number) ──────────
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'سُورَةُ $surahName',
                    style: TextStyle(
                      fontFamily: AppConstants.hafsFontFamily,
                      fontSize: isSmallScreen ? 13 : 15,
                      fontWeight: FontWeight.bold,
                      color: c.gold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: c.gold.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'الجُزْءُ ${juzNum.toArabicDigits()}',
                        style: TextStyle(
                          fontFamily: AppConstants.hafsFontFamily,
                          fontSize: isSmallScreen ? 13 : 15,
                          fontWeight: FontWeight.bold,
                          color: c.gold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: c.border.withValues(alpha: 0.25)),
            const SizedBox(height: 8),

            // ── Exactly 15 Lines of Authentic Medina Mushaf ──────────
            for (int i = 0; i < page.lines.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: MedinaLineWidget(
                  line: page.lines[i],
                  controller: widget.controller,
                  app: app,
                  colors: c,
                ),
              ),

            const SizedBox(height: 8),
            Divider(height: 1, color: c.border.withValues(alpha: 0.25)),
            const SizedBox(height: 8),

            // ── Bottom Page Number ──────────────────────────────────
            Center(
              child: Text(
                '— $pageNumStr —',
                style: TextStyle(
                  fontFamily: AppConstants.hafsFontFamily,
                  color: c.gold.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Line Renderer for Authentic Medina Mushaf ────────────────────────────────

class MedinaLineWidget extends StatefulWidget {
  final MushafLine line;
  final HighlightingController controller;
  final AppState app;
  final ThemeColors colors;

  const MedinaLineWidget({
    super.key,
    required this.line,
    required this.controller,
    required this.app,
    required this.colors,
  });

  @override
  State<MedinaLineWidget> createState() => _MedinaLineWidgetState();
}

class _MedinaLineWidgetState extends State<MedinaLineWidget> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.line.type == MushafLineType.surahHeader) {
      return SurahHeaderBanner(
        surahNumber: widget.line.surah ?? 1,
        title: widget.line.text ?? 'سورة',
        colors: widget.colors,
      );
    }

    if (widget.line.type == MushafLineType.basmala) {
      return BasmalaBanner(colors: widget.colors);
    }

    _disposeRecognizers();

    final targetSurah = widget.controller.targetSurah;
    final activeAyah = widget.controller.activeAyah.value;
    final bool isShortLine = widget.line.words.length <= 3;
    final spans = <InlineSpan>[];
    final double fontSize = widget.app.fontSize;

    for (int i = 0; i < widget.line.words.length; i++) {
      final w = widget.line.words[i];
      final bool isTargetSurah = (w.surah == targetSurah);
      final bool isActiveAyah = isTargetSurah && (activeAyah != null) && (w.ayah == activeAyah);

      final isRead = isTargetSurah &&
          (widget.controller.isWordGreen(w.ayah, w.wordIndex) ||
              widget.controller.isWordRed(w.ayah, w.wordIndex) ||
              widget.controller.isWordYellow(w.ayah, w.wordIndex) ||
              widget.controller.isWordNeutral(w.ayah, w.wordIndex));

      final bool isGreen = isTargetSurah && widget.controller.isWordGreen(w.ayah, w.wordIndex);
      final bool isRed = isTargetSurah && widget.controller.isWordRed(w.ayah, w.wordIndex);
      final bool isYellow = isTargetSurah && widget.controller.isWordYellow(w.ayah, w.wordIndex);

      final Color wordColor = (widget.app.isBlurMode && !isRead)
          ? Colors.transparent
          : (isGreen
              ? widget.colors.green
              : (isRed
                  ? widget.colors.red
                  : (isYellow ? widget.colors.currentWord : widget.colors.text)));

      final rec = TapGestureRecognizer()
        ..onTap = () {
          widget.controller.setManualAyah(w.surah, w.ayah);
          if (isYellow) {
            widget.app.markTajweedWordClicked();
            final errs = widget.controller.getWordErrors(w.ayah, w.wordIndex);
            if (errs != null && errs.isNotEmpty) {
              ErrorDetailDialog.show(context, word: w.cleanWord, errors: errs);
            }
          }
        };
      _recognizers.add(rec);

      // 1. Exact HafsSmart PUA Glyph for this authentic Medina word
      spans.add(
        TextSpan(
          text: w.puaText,
          style: TextStyle(
            fontFamily: AppConstants.hafsFontFamily,
            fontSize: fontSize,
            color: wordColor,
            fontWeight: FontWeight.normal,
            backgroundColor: isActiveAyah ? widget.colors.gold.withValues(alpha: 0.14) : null,
            shadows: isActiveAyah
                ? [
                    Shadow(color: widget.colors.gold.withValues(alpha: 0.6), blurRadius: 10),
                  ]
                : null,
            height: 1.15,
          ),
          recognizer: rec,
        ),
      );

      // 2. Circular Ayah End Rosette
      if (w.isAyahEnd) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => widget.controller.setManualAyah(w.surah, w.ayah),
                child: Container(
                  color: isActiveAyah ? widget.colors.gold.withValues(alpha: 0.15) : null,
                  padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1.5),
                  child: Container(
                    width: fontSize * 0.74,
                    height: fontSize * 0.74,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActiveAyah ? widget.colors.gold : widget.colors.gold.withValues(alpha: 0.65),
                        width: isActiveAyah ? 1.4 : 1.0,
                      ),
                      color: isActiveAyah ? widget.colors.gold.withValues(alpha: 0.22) : null,
                      boxShadow: isActiveAyah
                          ? [
                              BoxShadow(color: widget.colors.gold.withValues(alpha: 0.4), blurRadius: 8),
                            ]
                          : null,
                    ),
                    child: Text(
                      w.ayah.toArabicDigits(),
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: AppConstants.hafsFontFamily,
                        fontSize: fontSize * 0.38,
                        fontWeight: FontWeight.bold,
                        color: isActiveAyah ? widget.colors.gold : widget.colors.gold.withValues(alpha: 0.9),
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // 3. Spacing between words
      if (i < widget.line.words.length - 1) {
        final nextWord = widget.line.words[i + 1];
        final bool isNextTargetSurah = nextWord.surah == targetSurah;
        final bool shouldHighlightSpace = isActiveAyah &&
            !w.isAyahEnd &&
            isNextTargetSurah &&
            (nextWord.ayah == activeAyah);

        spans.add(
          TextSpan(
            text: ' ',
            style: TextStyle(
              fontFamily: AppConstants.hafsFontFamily,
              fontSize: fontSize,
              backgroundColor: shouldHighlightSpace ? widget.colors.gold.withValues(alpha: 0.14) : null,
              height: 1.15,
            ),
          ),
        );
      }
    }

    // FittedBox ensures the exact Medina line NEVER goes out of bounds on Android/small screens,
    // while keeping all words in their authentic Medina layout!
    return Container(
      constraints: BoxConstraints(minHeight: fontSize * 1.55),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: RichText(
          textAlign: isShortLine ? TextAlign.center : TextAlign.justify,
          textDirection: TextDirection.rtl,
          softWrap: false,
          overflow: TextOverflow.visible,
          text: TextSpan(children: spans),
        ),
      ),
    );
  }
}

// ── Ornate Surah Header Banner ───────────────────────────────────────────────

class SurahHeaderBanner extends StatelessWidget {
  final int surahNumber;
  final String title;
  final ThemeColors colors;

  const SurahHeaderBanner({
    super.key,
    required this.surahNumber,
    required this.title,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final cleanTitle = title.replaceAll('سورة ', '').replaceAll('سُورَةُ ', '').trim();
    final place = quran.getPlaceOfRevelation(surahNumber);
    final isMakki = place.toLowerCase().contains('makkah') || place.contains('مكة');
    final placeAr = isMakki ? 'مَكِّيَّة' : 'مَدَنِيَّة';
    final verseCount = quran.getVerseCount(surahNumber).toArabicDigits();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.gold.withValues(alpha: 0.5), width: 1.4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'آيَاتُهَا $verseCount',
            style: TextStyle(
              fontFamily: AppConstants.hafsFontFamily,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: colors.gold,
            ),
          ),
          Text(
            'سُورَةُ $cleanTitle',
            style: TextStyle(
              fontFamily: AppConstants.hafsFontFamily,
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
              color: colors.gold,
            ),
          ),
          Text(
            placeAr,
            style: TextStyle(
              fontFamily: AppConstants.hafsFontFamily,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: colors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Centered Calligraphic Basmala Banner ────────────────────────────────────

class BasmalaBanner extends StatelessWidget {
  final ThemeColors colors;

  const BasmalaBanner({super.key, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Center(
        child: Text(
          quran.basmala,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: AppConstants.hafsFontFamily,
            fontSize: 17,
            color: colors.gold.withValues(alpha: 0.95),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ── Authentic Circular Quranic Ayah Rosette ─────────────────────────────────

class AyahRosetteWidget extends StatelessWidget {
  final int ayahNumber;
  final String ayahStr;
  final bool isActive;
  final ThemeColors colors;
  final double fontSize;

  const AyahRosetteWidget({
    super.key,
    required this.ayahNumber,
    required this.ayahStr,
    required this.isActive,
    required this.colors,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final size = fontSize * 0.92;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? colors.gold.withValues(alpha: 0.28) : colors.surfaceHigh,
        border: Border.all(
          color: isActive ? colors.gold : colors.gold.withValues(alpha: 0.65),
          width: isActive ? 1.5 : 1.1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: colors.gold.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        ayahStr,
        style: TextStyle(
          fontFamily: AppConstants.hafsFontFamily,
          fontSize: size * 0.48,
          fontWeight: FontWeight.bold,
          color: isActive ? colors.gold : colors.gold.withValues(alpha: 0.9),
          height: 1.1,
        ),
      ),
    );
  }
}
