import 'package:flutter/material.dart';
import 'package:recite_quran/recite_quran.dart';

import '../app_state.dart';

/// Real-time recitation inspector & e-learning studio sidebar for Windows desktop (Left Bar).
/// Displays:
/// 1. Tajweed errors per word (with phonetic breakdown)
/// 2. Missed & misread words per word
/// 3. Live performance statistics & surah progress
/// 4. Upcoming AI feature telemetry cards (Makhaarij, Hifz Retention, Confidence)
class FeedbackSidebar extends StatefulWidget {
  final HighlightingController controller;
  final bool isRecording;
  final bool isLoadingEngine;
  final VoidCallback? onToggleRecord;
  final VoidCallback? onClearBuffer;
  final VoidCallback? onTajweedToggle;
  final double? width;
  final VoidCallback? onClose;

  const FeedbackSidebar({
    super.key,
    required this.controller,
    required this.isRecording,
    this.isLoadingEngine = false,
    this.onToggleRecord,
    this.onClearBuffer,
    this.onTajweedToggle,
    this.width,
    this.onClose,
  });

  @override
  State<FeedbackSidebar> createState() => _FeedbackSidebarState();
}

class _FeedbackSidebarState extends State<FeedbackSidebar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
    widget.controller.activeAyah.addListener(_onUpdate);
    widget.controller.globalRevision.addListener(_onUpdate);
  }

  @override
  void didUpdateWidget(FeedbackSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onUpdate);
      oldWidget.controller.activeAyah.removeListener(_onUpdate);
      oldWidget.controller.globalRevision.removeListener(_onUpdate);
      widget.controller.addListener(_onUpdate);
      widget.controller.activeAyah.addListener(_onUpdate);
      widget.controller.globalRevision.addListener(_onUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    widget.controller.activeAyah.removeListener(_onUpdate);
    widget.controller.globalRevision.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final c = app.colors;
    final isAr = app.isArabic;
    final ctrl = widget.controller;

    final targetSurah = ctrl.targetSurah;
    final surahs = ctrl.repository.surahMetadata;
    final surahMeta = (targetSurah >= 1 && targetSurah <= surahs.length) ? surahs[targetSurah - 1] : null;
    final surahName = surahMeta?.surahName ?? 'سورة $targetSurah';
    final totalAyahs = AppConstants.getSurahAyahCount(targetSurah);

    final activeAyahNum = ctrl.activeAyah.value ?? 1;
    final displayVerses = ctrl.repository.getSurah(targetSurah);
    final activeVerse = displayVerses.cast<QuranVerse?>().firstWhere(
          (v) => v?.ayah == activeAyahNum,
          orElse: () => null,
        );

    // 1. Collect Tajweed and Phonemic Errors for active verse
    final activeTajweedErrors = <_WordErrorInfo>[];
    // 2. Collect Missed / Misread words (marked Red) for active verse
    final missedWords = <_MissedWordInfo>[];

    int correctWords = 0;
    int redWords = 0;
    int yellowWords = 0;

    if (activeVerse != null) {
      for (int i = 0; i < activeVerse.uthmaniWords.length; i++) {
        final w = activeVerse.uthmaniWords[i];
        final isGreen = ctrl.isWordGreen(activeAyahNum, i);
        final isRed = ctrl.isWordRed(activeAyahNum, i);
        final isYellow = ctrl.isWordYellow(activeAyahNum, i);

        if (isGreen) correctWords++;
        if (isRed) {
          redWords++;
          missedWords.add(_MissedWordInfo(
            word: w,
            wordIndex: i,
            ayah: activeAyahNum,
          ));
        }
        if (isYellow) yellowWords++;

        final errs = ctrl.getWordErrors(activeAyahNum, i);
        if (errs != null && errs.isNotEmpty) {
          activeTajweedErrors.add(_WordErrorInfo(
            word: w,
            wordIndex: i,
            ayah: activeAyahNum,
            errors: errs,
          ));
        }
      }
    }

    final completedCount = ctrl.completedAyahs.length;
    final progress = totalAyahs > 0 ? (completedCount / totalAyahs).clamp(0.0, 1.0) : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ColorFilter.mode(Colors.black.withValues(alpha: 0.05), BlendMode.srcOver),
        child: Container(
          width: widget.width ?? 320,
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.88),
            border: Border.all(color: c.border.withValues(alpha: 0.6), width: 1.5),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: c.isDark ? 0.25 : 0.06),
                blurRadius: 24,
                offset: Offset(isAr ? -2 : 2, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Bar ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: c.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.analytics_outlined, color: c.gold, size: 19),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isAr ? 'لوحة التقييم والتشخيص' : 'Recitation Inspector',
                        style: TextStyle(
                          color: c.text,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildLiveBadge(c, isAr),
                    if (widget.onClose != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 18, color: c.muted),
                        onPressed: widget.onClose,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: c.border.withValues(alpha: 0.25)),

              // ── Scrollable Body ──────────────────────────────────────────
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  children: [
                    // 1. Current Surah & Progress Card
                    _buildProgressCard(
                      c: c,
                      isAr: isAr,
                      surahName: surahName,
                      totalAyahs: totalAyahs,
                      completedCount: completedCount,
                      progress: progress,
                    ),

                    const SizedBox(height: 12),

                    // 2. Active Ayah Live Status Card
                    _buildActiveAyahCard(
                      c: c,
                      isAr: isAr,
                      activeAyahNum: activeAyahNum,
                      totalAyahs: totalAyahs,
                      correctWords: correctWords,
                      redWords: redWords,
                      yellowWords: yellowWords,
                      totalWords: activeVerse?.uthmaniWords.length ?? 0,
                    ),

                    const SizedBox(height: 12),

                    // 3. Live Tajweed Errors Per Word Section
                    _buildTajweedErrorsSection(
                      c: c,
                      isAr: isAr,
                      errors: activeTajweedErrors,
                      activeAyahNum: activeAyahNum,
                    ),

                    const SizedBox(height: 12),

                    // 4. Missed / Misread Words Per Word Section
                    _buildMissedWordsSection(
                      c: c,
                      isAr: isAr,
                      missedWords: missedWords,
                      activeAyahNum: activeAyahNum,
                    ),

                    const SizedBox(height: 14),

                    // 5. Other Coming Features Section (الميزات القادمة)
                    _buildUpcomingFeaturesCard(c: c, isAr: isAr),

                    const SizedBox(height: 12),

                    // 6. Compact Keyboard Shortcuts Guide
                    _buildCompactShortcutsCard(c: c, isAr: isAr),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveBadge(ThemeColors c, bool isAr) {
    if (widget.isLoadingEngine) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 9,
              height: 9,
              child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation(c.gold)),
            ),
            const SizedBox(width: 5),
            Text(isAr ? 'تحميل...' : 'Loading...', style: TextStyle(color: c.gold, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    if (widget.isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.red.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.red.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: c.red,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: c.red.withValues(alpha: 0.6), blurRadius: 4)],
              ),
            ),
            const SizedBox(width: 5),
            Text(isAr ? 'مباشر' : 'LIVE', style: TextStyle(color: c.red, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c.muted.withValues(alpha: 0.5), shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(isAr ? 'جاهز' : 'Ready', style: TextStyle(color: c.muted, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildProgressCard({
    required ThemeColors c,
    required bool isAr,
    required String surahName,
    required int totalAyahs,
    required int completedCount,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 52,
            width: 52,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4.5,
                  backgroundColor: c.bg.withValues(alpha: 0.6),
                  valueColor: AlwaysStoppedAnimation(c.green),
                ),
                Center(
                  child: Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      color: c.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  surahName,
                  style: TextStyle(
                    fontFamily: AppConstants.hafsFontFamily,
                    color: c.gold,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$completedCount / $totalAyahs ${isAr ? "آية مكتملة" : "completed"}',
                  style: TextStyle(color: c.muted, fontSize: 11.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAyahCard({
    required ThemeColors c,
    required bool isAr,
    required int activeAyahNum,
    required int totalAyahs,
    required int correctWords,
    required int redWords,
    required int yellowWords,
    required int totalWords,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.graphic_eq_rounded, color: c.gold, size: 15),
              const SizedBox(width: 6),
              Text(
                isAr ? 'الآية الحالية: $activeAyahNum' : 'Current Ayah: $activeAyahNum',
                style: TextStyle(
                  color: c.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '$totalWords ${isAr ? "كلمات" : "words"}',
                style: TextStyle(color: c.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatChip(c.green, '$correctWords', isAr ? 'صحيح' : 'Correct', c),
              const SizedBox(width: 6),
              _buildStatChip(c.gold, '$yellowWords', isAr ? 'تجويد' : 'Tajweed', c),
              const SizedBox(width: 6),
              _buildStatChip(c.red, '$redWords', isAr ? 'أخطاء' : 'Errors', c),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(Color color, String count, String label, ThemeColors c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTajweedErrorsSection({
    required ThemeColors c,
    required bool isAr,
    required List<_WordErrorInfo> errors,
    required int activeAyahNum,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.verified_rounded, color: c.gold, size: 15),
            const SizedBox(width: 5),
            Text(
              isAr ? 'أحكام التجويد (لكل كلمة)' : 'Tajweed Diagnostics',
              style: TextStyle(color: c.gold, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: c.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${errors.length}',
                style: TextStyle(color: c.gold, fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (errors.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surfaceHigh.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: c.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAr ? 'لا توجد ملاحظات تجويد في هذه الآية' : 'No tajweed errors in this ayah',
                    style: TextStyle(color: c.muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          )
        else
          for (final info in errors)
            for (final err in info.errors)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildTajweedErrorCard(info.word, err, c, isAr),
              ),
      ],
    );
  }

  Widget _buildTajweedErrorCard(String word, ReciterError e, ThemeColors c, bool isAr) {
    final exp = e.expectedPh.isEmpty ? '—' : ArabicUtils.cleanPhonetic(e.expectedPh);
    final pred = e.predictedPh.isEmpty ? '—' : ArabicUtils.cleanPhonetic(e.predictedPh);

    final (String title, Color accent, String desc) = switch (e.errorType) {
      ErrorCategory.tajweed => (
        (isAr ? e.expectedRule?.name.ar : e.expectedRule?.name.en) ?? (isAr ? 'حكم تجويد' : 'Tajweed'),
        const Color(0xFFF5B738),
        isAr ? 'لم يطبق الحكم بالشكل الصحيح' : 'Rule not applied properly',
      ),
      ErrorCategory.tashkeel => (
        isAr ? 'خطأ في التشكيل' : 'Vowel Discrepancy',
        const Color(0xFF60A5FA),
        isAr ? 'الحركة تختلف عن الصحيحة' : 'Vowel differs',
      ),
      ErrorCategory.normal => (
        isAr ? 'خطأ في النطق' : 'Pronunciation',
        c.red,
        isAr ? 'نطق الحرف يختلف عن النص' : 'Letter differs',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                word,
                style: TextStyle(
                  fontFamily: AppConstants.hafsFontFamily,
                  color: c.text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  title,
                  style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(desc, style: TextStyle(color: c.muted, fontSize: 11)),
          if (exp != '—' || pred != '—') ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _box(isAr ? 'الصواب' : 'Correct', exp, c.green, c),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.arrow_forward_rounded, color: c.border, size: 12),
                ),
                Expanded(
                  child: _box(isAr ? 'نطقك' : 'Recited', pred, c.red, c),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMissedWordsSection({
    required ThemeColors c,
    required bool isAr,
    required List<_MissedWordInfo> missedWords,
    required int activeAyahNum,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline_rounded, color: c.red, size: 15),
            const SizedBox(width: 5),
            Text(
              isAr ? 'الكلمات المتعثرة أو المتروكة' : 'Missed / Misread Words',
              style: TextStyle(color: c.red, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: c.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${missedWords.length}',
                style: TextStyle(color: c.red, fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (missedWords.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surfaceHigh.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: c.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAr ? 'لا توجد كلمات متروكة في هذه الآية' : 'All words pronounced clearly',
                    style: TextStyle(color: c.muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: missedWords.map((mw) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: c.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.red.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mw.word,
                      style: TextStyle(
                        fontFamily: AppConstants.hafsFontFamily,
                        color: c.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '#${mw.wordIndex + 1}',
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildUpcomingFeaturesCard({required ThemeColors c, required bool isAr}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: c.gold, size: 15),
              const SizedBox(width: 6),
              Text(
                isAr ? 'ميزات قادمة في التحديث' : 'Upcoming AI Features',
                style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Feature 1: Makhaarij
          _upcomingFeatureRow(
            icon: Icons.record_voice_over_outlined,
            title: isAr ? 'مخارج الحروف الذكية' : 'AI Articulation (Makhaarij)',
            subtitle: isAr ? 'تحليل صوتي لمخارج الحلق واللسان والشفتين' : 'Acoustic throat/tongue articulation points',
            c: c,
          ),
          const SizedBox(height: 6),

          // Feature 2: Hifz Score
          _upcomingFeatureRow(
            icon: Icons.trending_up_rounded,
            title: isAr ? 'مؤشر جودة وتثبيت الحفظ' : 'Hifz Retention Index',
            subtitle: isAr ? 'قياس الطلاقة ومعدل التردد بالذكاء الاصطناعي' : 'Real-time fluency and hesitation analytics',
            c: c,
          ),
          const SizedBox(height: 6),

          // Feature 3: Audio Confidence
          _upcomingFeatureRow(
            icon: Icons.graphic_eq_rounded,
            title: isAr ? 'مؤشر الثقة الصوتي' : 'Acoustic Confidence Meter',
            subtitle: isAr ? 'مستوى دقة التطابق اللحظي للصوت' : 'Instant phoneme recognition confidence',
            c: c,
          ),
        ],
      ),
    );
  }

  Widget _upcomingFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeColors c,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.bg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.gold, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(color: c.text, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: c.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'قريباً',
                        style: TextStyle(color: c.gold, fontSize: 8.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: c.muted, fontSize: 9.5, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactShortcutsCard({required ThemeColors c, required bool isAr}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.surfaceHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.keyboard_outlined, color: c.muted, size: 13),
              const SizedBox(width: 5),
              Text(
                isAr ? 'اختصارات لوحة المفاتيح' : 'Shortcuts',
                style: TextStyle(color: c.muted, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _microChip('Space', isAr ? 'تلاوة' : 'Recite', c),
              _microChip('Ctrl+F', isAr ? 'بحث' : 'Search', c),
              _microChip('T', isAr ? 'تجويد' : 'Tajweed', c),
              _microChip('M', isAr ? 'تسميع' : 'Blur', c),
              _microChip('+ / -', isAr ? 'الخط' : 'Font', c),
            ],
          ),
        ],
      ),
    );
  }

  Widget _microChip(String keyStr, String label, ThemeColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.border.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            keyStr,
            style: TextStyle(color: c.gold, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(color: c.muted, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _box(String label, String text, Color col, ThemeColors c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 5),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: col, fontSize: 8.5, fontWeight: FontWeight.bold)),
            Text(
              text,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppConstants.hafsFontFamily,
                color: c.text,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
}

class _WordErrorInfo {
  final String word;
  final int wordIndex;
  final int ayah;
  final List<ReciterError> errors;

  _WordErrorInfo({
    required this.word,
    required this.wordIndex,
    required this.ayah,
    required this.errors,
  });
}

class _MissedWordInfo {
  final String word;
  final int wordIndex;
  final int ayah;

  _MissedWordInfo({
    required this.word,
    required this.wordIndex,
    required this.ayah,
  });
}
