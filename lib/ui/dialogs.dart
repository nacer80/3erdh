import 'package:flutter/material.dart';
import 'package:recite_quran/recite_quran.dart';

import '../app_state.dart';

// ── Windows Fluent Dialog Container ──────────────────────────────────────────

class AppDialogContainer extends StatelessWidget {
  final ThemeColors colors;
  final Widget child;
  final double maxWidth;
  final double? maxHeight;
  final EdgeInsetsGeometry padding;

  const AppDialogContainer({
    super.key,
    required this.colors,
    required this.child,
    this.maxWidth = 520,
    this.maxHeight,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ColorFilter.mode(Colors.black.withValues(alpha: 0.1), BlendMode.srcOver),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight ?? MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.border.withValues(alpha: 0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 40, offset: const Offset(0, 15)),
                ],
              ),
              padding: padding,
              child: child,
            ),
          ),
        ),
      );
}

// ── Windows Dialog Header Helper ─────────────────────────────────────────────

class DialogHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final ThemeColors colors;
  final VoidCallback? onClose;

  const DialogHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.colors,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: colors.gold, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: onClose ?? () => Navigator.of(context).pop(),
          icon: Icon(Icons.close_rounded, color: colors.muted, size: 20),
          splashRadius: 18,
          tooltip: 'إغلاق (Esc)',
        ),
      ],
    );
  }
}

// ── Theme Selection Dialog ───────────────────────────────────────────────────

class ThemeSelectionDialog extends StatefulWidget {
  final VoidCallback onThemeSelected;
  const ThemeSelectionDialog({super.key, required this.onThemeSelected});

  @override
  State<ThemeSelectionDialog> createState() => _ThemeSelectionDialogState();
}

class _ThemeSelectionDialogState extends State<ThemeSelectionDialog> {
  int? _selected;

  Widget _buildSwatch(String label, bool isDark, ThemeColors c, AppState app, int index) {
    final sel = (_selected ?? (app.isDarkMode ? 0 : 1)) == index;
    final swatchColors = isDark ? ThemeColors.darkTheme : ThemeColors.lightTheme;
    return GestureDetector(
      onTap: () {
        setState(() => _selected = index);
        app.setTheme(isDark ? AppThemeMode.dark : AppThemeMode.light);
        Future.delayed(const Duration(milliseconds: 250), widget.onThemeSelected);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 100,
              decoration: BoxDecoration(
                color: swatchColors.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: sel ? c.gold : c.border.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  if (sel)
                    BoxShadow(color: c.gold.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: c.gold, size: 30),
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: c.gold, borderRadius: BorderRadius.circular(2)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: sel ? c.gold : c.muted,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final c = app.colors;
    final isAr = app.isArabic;

    return AppDialogContainer(
      colors: c,
      maxWidth: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DialogHeader(
            icon: Icons.palette_rounded,
            title: isAr ? 'اختر مظهر التطبيق' : 'Choose Theme',
            subtitle: isAr ? 'يمكنك تغييره لاحقاً من الإعدادات' : 'Changeable anytime in settings',
            colors: c,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSwatch(isAr ? 'داكن (زمردي)' : 'Dark (Emerald)', true, c, app, 0),
              const SizedBox(width: 24),
              _buildSwatch(isAr ? 'فاتح (دافئ)' : 'Light (Warm)', false, c, app, 1),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Mic Permission Dialog ───────────────────────────────────────────────────

enum PermissionReason { tracking, voiceSearch }

class MicPermissionDialog extends StatelessWidget {
  final PermissionReason reason;
  const MicPermissionDialog({super.key, required this.reason});

  static Future<void> show(BuildContext context, PermissionReason reason) => showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => MicPermissionDialog(reason: reason),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final c = app.colors;
    final isAr = app.isArabic;

    return AppDialogContainer(
      colors: c,
      maxWidth: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: c.red.withValues(alpha: 0.12),
            radius: 28,
            child: Icon(Icons.mic_off_rounded, color: c.red, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            isAr ? 'مطلوب إذن الميكروفون' : 'Microphone Access Required',
            style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'يرجى السماح باستخدام الميكروفون للتعرف على التلاوة بدقة.'
                : 'Please grant microphone access for real-time recitation tracking.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.gold,
              foregroundColor: Colors.black,
              minimumSize: const Size(120, 42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isAr ? 'حسناً' : 'OK', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Voice Search Dialog (Windows Modal) ──────────────────────────────────────

class VoiceSearchDialog extends StatelessWidget {
  final VoidCallback onStop;
  final ValueNotifier<bool>? isLoading;

  const VoiceSearchDialog({super.key, required this.onStop, this.isLoading});

  static void show(
    BuildContext context, {
    required VoidCallback onStop,
    ValueNotifier<bool>? isLoading,
  }) =>
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => VoiceSearchDialog(onStop: onStop, isLoading: isLoading),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final c = app.colors;
    final isAr = app.isArabic;

    return PopScope(
      canPop: false,
      child: AppDialogContainer(
        colors: c,
        maxWidth: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: c.green.withValues(alpha: 0.35), width: 2),
              ),
              child: Icon(Icons.mic_rounded, color: c.green, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              isAr ? 'استمع إلى تلاوتك…' : 'Listening…',
              style: TextStyle(color: c.text, fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              isAr
                  ? 'اتلُ أي آية للبحث عنها مباشرة والانتقال إليها في المصحف'
                  : 'Recite any verse to locate it and jump directly to it',
              style: TextStyle(color: c.muted, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                onStop();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.stop_rounded, size: 18),
              label: Text(isAr ? 'إلغاء البحث' : 'Cancel Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.red.withValues(alpha: 0.15),
                foregroundColor: c.red,
                elevation: 0,
                minimumSize: const Size(140, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Windows Command Palette: Surah Selector Dialog ───────────────────────────

class SurahPickerSheet extends StatefulWidget {
  final int current;
  final void Function(int surah, {int? ayah}) onPick;
  final HighlightingController controller;
  final bool isRecording;
  final bool isVoiceSearching;
  final VoidCallback onToggleRecord;
  final VoidCallback onVoiceSearchToggle;

  const SurahPickerSheet({
    super.key,
    required this.current,
    required this.onPick,
    required this.controller,
    required this.isRecording,
    required this.isVoiceSearching,
    required this.onToggleRecord,
    required this.onVoiceSearchToggle,
  });

  /// Opens the Windows desktop Command-Palette style Surah selector dialog.
  static void show(
    BuildContext context, {
    required int current,
    required void Function(int surah, {int? ayah}) onPick,
    required HighlightingController controller,
    required bool isRecording,
    required bool isVoiceSearching,
    required VoidCallback onToggleRecord,
    required VoidCallback onVoiceSearchToggle,
  }) =>
      showDialog(
        context: context,
        builder: (_) => SurahPickerSheet(
          current: current,
          onPick: onPick,
          controller: controller,
          isRecording: isRecording,
          isVoiceSearching: isVoiceSearching,
          onToggleRecord: onToggleRecord,
          onVoiceSearchToggle: onVoiceSearchToggle,
        ),
      );

  @override
  State<SurahPickerSheet> createState() => _SurahPickerSheetState();
}

class _SurahPickerSheetState extends State<SurahPickerSheet> {
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  late final List<QuranVerse> _surahs = widget.controller.repository.surahMetadata;
  late final List<String> _normalizedNames = _surahs.map((s) => s.surahName.normalizeArabic()).toList();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final c = app.colors;
    final isAr = app.isArabic;
    final normQuery = _query.normalizeArabic();

    final items = [
      for (int i = 0; i < _surahs.length; i++)
        if (_query.isEmpty ||
            _normalizedNames[i].contains(normQuery) ||
            _surahs[i].surahNameEn.toLowerCase().contains(_query.toLowerCase()) ||
            '${i + 1}'.contains(_query))
          i
    ];

    return AppDialogContainer(
      colors: c,
      maxWidth: 680,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── Header Bar ───────────────────────────────────────────────
          DialogHeader(
            icon: Icons.menu_book_rounded,
            title: isAr ? 'فهرس سور القرآن الكريم' : 'Surahs of the Holy Quran',
            subtitle: isAr ? 'اختر سورة للانتقال إليها (114 سورة)' : 'Select a Surah to jump to (114 Surahs)',
            colors: c,
          ),

          const SizedBox(height: 16),

          // ── Search Bar ───────────────────────────────────────────────
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            onChanged: (v) => setState(() => _query = v.trim()),
            style: TextStyle(color: c.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: isAr ? 'ابحث باسم السورة أو رقمها (مثال: الكهف أو 18)...' : 'Search by Surah name or number...',
              hintStyle: TextStyle(color: c.muted, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: c.gold, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: c.muted, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: c.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.border.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.border.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.gold, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),

          const SizedBox(height: 14),

          // ── Surah Grid / List ────────────────────────────────────────
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      isAr ? 'لم يتم العثور على سور مطابقة للبحث' : 'No matching Surahs found',
                      style: TextStyle(color: c.muted, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (ctx, idx) {
                      final int sIdx = items[idx];
                      final meta = _surahs[sIdx];
                      final surahNumber = sIdx + 1;
                      final isSelected = widget.current == surahNumber;

                      return _SurahListItem(
                        number: surahNumber,
                        meta: meta,
                        isSelected: isSelected,
                        c: c,
                        isAr: isAr,
                        onTap: () => widget.onPick(surahNumber),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SurahListItem extends StatefulWidget {
  final int number;
  final QuranVerse meta;
  final bool isSelected;
  final ThemeColors c;
  final bool isAr;
  final VoidCallback onTap;

  const _SurahListItem({
    required this.number,
    required this.meta,
    required this.isSelected,
    required this.c,
    required this.isAr,
    required this.onTap,
  });

  @override
  State<_SurahListItem> createState() => _SurahListItemState();
}

class _SurahListItemState extends State<_SurahListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final isSelected = widget.isSelected;
    final meta = widget.meta;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? c.gold.withValues(alpha: 0.15)
                : (_isHovered ? c.surfaceHigh : c.surfaceHigh.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? c.gold : (_isHovered ? c.border : Colors.transparent),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              // Surah Number
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? c.gold : c.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? c.gold : c.border.withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${widget.number}',
                    style: TextStyle(
                      color: isSelected ? (c.isDark ? Colors.black : Colors.white) : c.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Surah Name (Calligraphic)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.surahName,
                      style: TextStyle(
                        fontFamily: AppConstants.hafsFontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? c.gold : c.text,
                      ),
                    ),
                    Text(
                      meta.surahNameEn,
                      style: TextStyle(color: c.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Ayahs count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${AppConstants.getSurahAyahCount(widget.number)} ${widget.isAr ? "آية" : "verses"}',
                  style: TextStyle(color: c.muted, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),

              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isSelected ? c.gold : c.muted.withValues(alpha: 0.4),
                size: 13,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Windows Tajweed Error Detail Dialog ───────────────────────────────────────

class ErrorDetailDialog extends StatelessWidget {
  final String word;
  final List<ReciterError> errors;

  const ErrorDetailDialog({super.key, required this.word, required this.errors});

  static void show(BuildContext context, {required String word, required List<ReciterError> errors}) {
    if (errors.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => ErrorDetailDialog(word: word, errors: errors),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final c = app.colors;
    final isAr = app.isArabic;

    return AppDialogContainer(
      colors: c,
      maxWidth: 520,
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DialogHeader(
            icon: Icons.format_color_text_rounded,
            title: isAr ? 'ملاحظات التجويد والنطق' : 'Tajweed & Pronunciation Notes',
            colors: c,
          ),
          const SizedBox(height: 16),

          // Word Display Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: c.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  word,
                  style: TextStyle(
                    fontFamily: AppConstants.hafsFontFamily,
                    fontSize: 26,
                    color: c.text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isAr ? '${errors.length} ملاحظات' : '${errors.length} Notes',
                    style: TextStyle(color: c.red, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Errors list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: errors.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _buildCard(errors[i], c, isAr),
            ),
          ),

          const SizedBox(height: 18),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isAr ? 'حسناً' : 'Close', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(ReciterError e, ThemeColors c, bool isAr) {
    final exp = e.expectedPh.isEmpty ? '—' : ArabicUtils.cleanPhonetic(e.expectedPh);
    final pred = e.predictedPh.isEmpty ? '—' : ArabicUtils.cleanPhonetic(e.predictedPh);

    final (String title, Color accent, String desc) = switch (e.errorType) {
      ErrorCategory.tajweed => (
        (isAr ? e.expectedRule?.name.ar : e.expectedRule?.name.en) ?? (isAr ? 'حكم تجويد' : 'Tajweed'),
        const Color(0xFFDAA520),
        isAr ? 'لم يطبق الحكم بالشكل الصحيح' : 'Rule not applied properly',
      ),
      ErrorCategory.tashkeel => (
        isAr ? 'خطأ في التشكيل' : 'Vowel Error',
        const Color(0xFF5B8DEF),
        isAr ? 'الحركة تختلف عن الصحيحة' : 'Vowel differs',
      ),
      ErrorCategory.normal => (
        isAr ? 'خطأ في النطق' : 'Pronunciation',
        c.red,
        isAr ? 'نطق الحرف يختلف عن النص' : 'Letter differs',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Text(desc, style: TextStyle(color: c.muted, fontSize: 11)),
            ],
          ),
          if (exp != '—' || pred != '—') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _box(isAr ? 'الصواب في التلاوة' : 'Expected', exp, c.green, c)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward_rounded, color: c.border, size: 14),
                ),
                Expanded(child: _box(isAr ? 'نطقك المسجل' : 'Your recitation', pred, c.red, c)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _box(String label, String text, Color col, ThemeColors c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              text,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppConstants.hafsFontFamily,
                color: c.text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
}
