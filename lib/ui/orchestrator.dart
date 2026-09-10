import 'dart:async';
import 'package:flutter/material.dart';
import 'package:recite_quran/recite_quran.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_state.dart';
import '../mushaf_service.dart';
import 'dialogs.dart';
import 'tracker.dart';

/// The engine conductor — owns the ASR engine, audio processor, and highlighting controller.
class Orchestrator extends StatefulWidget {
  const Orchestrator({super.key});

  @override
  State<Orchestrator> createState() => _OrchestratorState();
}

class _OrchestratorState extends State<Orchestrator> {
  final SherpaEngine _engine = SherpaEngine();
  final AudioProcessor _audio = AudioProcessor();
  late final VoiceSearchController _voiceSearchCtrl = VoiceSearchController(engine: _engine);

  HighlightingController? _ctrl;
  bool _isInit = true;
  bool _isRecording = false;
  String _initStatus = 'Starting…';
  bool _isToggling = false;
  bool _isEngineLoading = false;
  bool _isVoiceSearching = false;
  String _voiceSearchAsrText = '';

  @override
  void initState() {
    super.initState();
    _engine.transcriptionStream.listen((res) {
      if (_isVoiceSearching && mounted) {
        setState(() => _voiceSearchAsrText = res.text);
        _voiceSearchCtrl.processRealtime(res.text).then((rt) {
          if (rt != null) {
            _stopVoiceSearch(precalculatedResult: rt);
          } else if (res.isFinal) {
            _stopVoiceSearch();
          }
        });
      }
    });
    _init();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      if (mounted) setState(() => _initStatus = 'Loading Quran database…');
      final repo = QuranRepository(QuranMetadataService());
      await repo.loadSurahAsync(1);
      await MushafService.instance.load();

      _ctrl = HighlightingController(
        engine: _engine,
        repository: repo,
        isTajweed: AppState.instance.currentMode == AppMode.tajweed,
        onAyahChanged: () => _audio.clearBuffer(),
      );

      try { await WakelockPlus.enable(); } catch (_) {}
      // Default dark theme is active immediately
      if (mounted) setState(() => _isInit = false);
    } catch (e) {
      AppLogger.log('INIT', 'Error: $e');
      if (mounted) setState(() => _initStatus = 'Error: $e');
    }
  }

  Future<void> _toggleRecord() async {
    if (_isToggling) return;
    _isToggling = true;
    try {
      if (_isRecording) {
        await _audio.stop();
        _engine.resetBuffer();
        _ctrl?.finalize();
        if (mounted) setState(() => _isRecording = false);
      } else {
        if (!_engine.isInitialized) {
          if (mounted) setState(() => _isEngineLoading = true);
          try {
            await _engine.initialize();
          } finally {
            if (mounted) setState(() => _isEngineLoading = false);
          }
        }
        if (!_engine.isInitialized) {
          return;
        }
        _engine.resetBuffer();
        if (mounted) setState(() => _isRecording = true);
        if (_ctrl != null) {
          _ctrl!.startRecordingSession();
          _audio.start(onChunk: (chunk, isFinal) => _ctrl?.feed(chunk, isFinal: isFinal)).catchError((e) {
            AppLogger.log('AUDIO', 'Mic error: $e');
            if (mounted) {
              setState(() => _isRecording = false);
              MicPermissionDialog.show(context, PermissionReason.tracking);
            }
          });
        }
      }
    } finally {
      _isToggling = false;
    }
  }

  Future<void> _toggleVoiceSearch() async {
    if (_isToggling) return;
    if (_isVoiceSearching) {
      await _stopVoiceSearch();
    } else {
      if (_isRecording) await _toggleRecord();
      await _startVoiceSearch();
    }
  }

  Future<void> _startVoiceSearch() async {
    if (_isVoiceSearching || _isToggling) return;
    _isToggling = true;
    try {
      if (!_engine.isInitialized) {
        if (mounted) setState(() => _isEngineLoading = true);
        try {
          await _engine.initialize();
        } finally {
          if (mounted) setState(() => _isEngineLoading = false);
        }
      }
      if (!_engine.isInitialized) {
        return;
      }
      _ctrl?.finalize();
      if (mounted) setState(() { _isVoiceSearching = true; _voiceSearchAsrText = ''; });
      await _voiceSearchCtrl.startSearch();
      _audio.start(onChunk: (chunk, isFinal) => _engine.transcribe(chunk, isFinal: isFinal)).catchError((e) {
        AppLogger.log('AUDIO', 'Voice search mic error: $e');
        if (mounted) {
          setState(() => _isVoiceSearching = false);
          MicPermissionDialog.show(context, PermissionReason.voiceSearch);
        }
      });
    } finally {
      _isToggling = false;
    }
  }

  Future<void> _stopVoiceSearch({AnchorResult? precalculatedResult}) async {
    if (!_isVoiceSearching || _isToggling) return;
    _isToggling = true;
    try {
      await _audio.stop();
      _engine.resetBuffer();
      if (mounted) setState(() => _isVoiceSearching = false);

      final result = precalculatedResult ?? await _voiceSearchCtrl.stopSearch(_voiceSearchAsrText);
      if (result != null && _ctrl != null) {
        await _ctrl!.setTargetSurah(result.surah);
        _ctrl!.setManualAyah(result.surah, result.ayah);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم الانتقال إلى سورة ${result.surah} آية ${result.ayah}'), backgroundColor: AppState.instance.colors.gold),
          );
        }
      } else {
        _ctrl?.resumeTracking();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على الآية، حاول مرة أخرى')));
        }
      }
    } finally {
      _isToggling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInit) return SplashScreen(status: _initStatus);

    return TrackingScreen(
      controller: _ctrl!,
      isRecording: _isRecording,
      isLoadingEngine: _isEngineLoading,
      isVoiceSearching: _isVoiceSearching,
      voiceSearchText: _voiceSearchAsrText,
      onToggleRecord: _toggleRecord,
      onVoiceSearchToggle: _toggleVoiceSearch,
      isVoiceSearchLoading: _voiceSearchCtrl.isIndexLoading,
      onClearBuffer: () {
        _engine.resetBuffer();
        _audio.clearBuffer();
      },
    );
  }
}

/// Minimalist splash screen displayed while Sherpa & Quran DB load.
class SplashScreen extends StatelessWidget {
  final String status;
  const SplashScreen({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = AppState.instance.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'وَلَقَدْ يَسَّرْنَا الْقُرْآنَ لِلذِّكْرِ فَهَلْ مِن مُّدَّكِرٍ',
                style: TextStyle(fontFamily: AppConstants.hafsFontFamily, color: c.text, fontSize: 24),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 32),
              SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(c.gold))),
              const SizedBox(height: 14),
              Text(status, style: TextStyle(color: c.muted, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
