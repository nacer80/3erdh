import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:quran/quran.dart' as quran;
import 'app_state.dart';

enum MushafLineType { text, surahHeader, basmala }

class MushafWord {
  final String location; // e.g. "2:1:1"
  final int surah;
  final int ayah;
  final int wordIndex; // 0-based word index in the ayah
  final String rawText; // Original text from JSON
  final String cleanWord; // Word without trailing ayah number
  final String puaText; // Exact HafsSmart PUA Unicode glyph string
  final bool isAyahEnd;
  final String? ayahNumberStr;
  final String? endRosette; // Exact HafsSmart PUA Ayah Rosette glyph (e.g. )
  final String? qpc;

  const MushafWord({
    required this.location,
    required this.surah,
    required this.ayah,
    required this.wordIndex,
    required this.rawText,
    required this.cleanWord,
    required this.puaText,
    required this.isAyahEnd,
    this.ayahNumberStr,
    this.endRosette,
    this.qpc,
  });

  factory MushafWord.fromJson(Map<String, dynamic> json) {
    final loc = json['loc'] as String? ?? '1:1:1';
    final parts = loc.split(':');
    final s = int.tryParse(parts.isNotEmpty ? parts[0] : '1') ?? 1;
    final a = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
    final wIdx = (int.tryParse(parts.length > 2 ? parts[2] : '1') ?? 1) - 1;

    final raw = (json['w'] as String? ?? '').trim();
    final pua = (json['pua'] as String? ?? raw).trim();
    final endR = json['end'] as String?;
    final qpc = json['qpc'] as String?;

    final match = RegExp(r'^(.+?)\s+([٠-٩\d]+)$').firstMatch(raw);
    final isEnd = endR != null || match != null;

    return MushafWord(
      location: loc,
      surah: s,
      ayah: a,
      wordIndex: wIdx,
      rawText: raw,
      cleanWord: match != null ? match.group(1)!.trim() : raw,
      puaText: pua,
      isAyahEnd: isEnd,
      ayahNumberStr: match?.group(2),
      endRosette: endR,
      qpc: qpc,
    );
  }
}

class MushafLine {
  final int lineNumber; // 1 to 15
  final MushafLineType type;
  final String? text;
  final int? surah;
  final String? verseRange;
  final List<MushafWord> words;
  final String? qpcV2;

  const MushafLine({
    required this.lineNumber,
    required this.type,
    this.text,
    this.surah,
    this.verseRange,
    this.words = const [],
    this.qpcV2,
  });

  factory MushafLine.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'text';
    final MushafLineType type = switch (typeStr) {
      'surah-header' => MushafLineType.surahHeader,
      'basmala' => MushafLineType.basmala,
      _ => MushafLineType.text,
    };

    final wordsList = <MushafWord>[];
    if (json['words'] is List) {
      for (final w in json['words'] as List) {
        if (w is Map<String, dynamic>) {
          wordsList.add(MushafWord.fromJson(w));
        }
      }
    }

    return MushafLine(
      lineNumber: json['line'] as int? ?? 1,
      type: type,
      text: json['text'] as String?,
      surah: json['surah'] as int?,
      verseRange: json['verseRange'] as String?,
      words: wordsList,
      qpcV2: json['qpcV2'] as String?,
    );
  }
}

class MushafPage {
  final int pageNumber; // 1 to 604
  final List<MushafLine> lines; // Always 15 lines
  final List<int> surahNumbers;
  final int? firstSurah;
  final int? firstAyah;
  final int juzNumber;

  const MushafPage({
    required this.pageNumber,
    required this.lines,
    required this.surahNumbers,
    this.firstSurah,
    this.firstAyah,
    required this.juzNumber,
  });

  factory MushafPage.fromJson(Map<String, dynamic> json) {
    final pageNum = json['page'] as int? ?? 1;
    final linesList = <MushafLine>[];
    final surahsSet = <int>{};
    int? fSurah;
    int? fAyah;

    if (json['lines'] is List) {
      for (final l in json['lines'] as List) {
        if (l is Map<String, dynamic>) {
          final line = MushafLine.fromJson(l);
          linesList.add(line);

          if (line.surah != null) {
            surahsSet.add(line.surah!);
          }
          for (final w in line.words) {
            surahsSet.add(w.surah);
            if (fSurah == null) {
              fSurah = w.surah;
              fAyah = w.ayah;
            }
          }
        }
      }
    }

    final sNum = fSurah ?? (surahsSet.isNotEmpty ? surahsSet.first : 1);
    final aNum = fAyah ?? 1;
    int juz = 1;
    try {
      juz = quran.getJuzNumber(sNum, aNum);
    } catch (_) {}

    return MushafPage(
      pageNumber: pageNum,
      lines: linesList,
      surahNumbers: surahsSet.toList(),
      firstSurah: fSurah,
      firstAyah: fAyah,
      juzNumber: juz,
    );
  }
}

/// Global service managing the canonical 604-page 15-line Medina Mushaf dataset.
class MushafService {
  MushafService._();
  static final MushafService instance = MushafService._();

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  final List<MushafPage> _pages = [];
  final Map<int, List<MushafPage>> _surahToPages = {};
  final Map<String, int> _ayahToPage = {};

  List<MushafPage> get allPages => _pages;

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/mushaf_layout.json');
      final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;

      _pages.clear();
      _surahToPages.clear();
      _ayahToPage.clear();

      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final page = MushafPage.fromJson(item);
          _pages.add(page);

          for (final s in page.surahNumbers) {
            _surahToPages.putIfAbsent(s, () => []).add(page);
          }

          for (final line in page.lines) {
            for (final w in line.words) {
              _ayahToPage.putIfAbsent('${w.surah}:${w.ayah}', () => page.pageNumber);
            }
          }
        }
      }

      _isLoaded = true;
      AppLogger.log('MUSHAF_SERVICE', 'Loaded ${_pages.length} Medina Mushaf pages.');
    } catch (e) {
      AppLogger.log('MUSHAF_SERVICE', 'Error loading mushaf_layout.json: $e');
    }
  }

  MushafPage? getPage(int pageNumber) {
    if (pageNumber >= 1 && pageNumber <= _pages.length) {
      return _pages[pageNumber - 1];
    }
    return null;
  }

  List<MushafPage> getPagesForSurah(int surahNumber) {
    return _surahToPages[surahNumber] ?? [];
  }

  int getPageForAyah(int surah, int ayah) {
    return _ayahToPage['$surah:$ayah'] ?? 1;
  }

  /// Returns the Medina page number and 0-based line index for a specific Ayah in a Surah.
  ({int pageNumber, int lineIndex})? getPageAndLineForAyah(int surah, int ayah) {
    final pageNum = _ayahToPage['$surah:$ayah'];
    if (pageNum == null) return null;
    final page = getPage(pageNum);
    if (page == null) return (pageNumber: pageNum, lineIndex: 0);

    for (int i = 0; i < page.lines.length; i++) {
      if (page.lines[i].words.any((w) => w.surah == surah && w.ayah == ayah)) {
        return (pageNumber: pageNum, lineIndex: i);
      }
    }
    return (pageNumber: pageNum, lineIndex: 0);
  }
}
