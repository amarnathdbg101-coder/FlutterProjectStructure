import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Top-Tier Background Audio Handler for StudySilo
/// Enables full Lockscreen Controls, Notification Tray Media Player,
/// Background Audio Playback, and seamless seeking across sentences.
class StudyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  // Callbacks to notify UI when user interacts with lockscreen or media notification
  VoidCallback? onSkipNextRequested;
  VoidCallback? onSkipPreviousRequested;
  VoidCallback? onPlayRequested;
  VoidCallback? onPauseRequested;
  VoidCallback? onStopRequested;
  VoidCallback? onPlaybackCompleted;

  StudyAudioHandler() {
    _initAudioPipeline();
  }

  bool isNavigating = false;

  void _initAudioPipeline() {
    // 1. Broadcast playback state changes to Android & iOS lockscreen
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(
        PlaybackState(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: event.currentIndex,
        ),
      );
    });

    // 2. Strict LoopMode.off Enforcement and track completion handler
    _player.setLoopMode(LoopMode.off);
    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed && !isNavigating) {
        onPlaybackCompleted?.call();
      }
    });

    // 3. Broadcast duration updates
    _player.durationStream.listen((duration) {
      if (duration != null && mediaItem.value != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: duration));
      }
    });
  }

  /// Plays either a local file path or an HTTP(s) streaming URL with active Lockscreen Metadata
  Future<void> playAudioSource(
    String pathOrUrl, {
    required String title,
    required String subtitle,
    String? personaName,
    Duration? initialDuration,
  }) async {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      await playAudioUrl(
        pathOrUrl,
        title: title,
        subtitle: subtitle,
        personaName: personaName,
      );
    } else {
      await playAudioFile(
        pathOrUrl,
        title: title,
        subtitle: subtitle,
        personaName: personaName,
        initialDuration: initialDuration,
      );
    }
  }

  /// Plays a local audio file with active Lockscreen Metadata
  Future<void> playAudioFile(
    String filePath, {
    required String title,
    required String subtitle,
    String? personaName,
    Duration? initialDuration,
  }) async {
    try {
      mediaItem.add(
        MediaItem(
          id: filePath,
          album: 'StudySilo AI Masterclass',
          title: title,
          artist: personaName ?? 'StudySilo Tutor',
          displaySubtitle: subtitle,
          duration: initialDuration,
        ),
      );

      // State Guarding: Prevent duplicate completion events during track setup
      isNavigating = true;
      try {
        await _player.stop();
        await _player.setLoopMode(LoopMode.off);
      } catch (_) {}
      await _player.setFilePath(filePath);
      isNavigating = false;
      await _player.play();
    } catch (e) {
      isNavigating = false;
      debugPrint('StudyAudioHandler playAudioFile error: $e');
    }
  }

  /// Plays an online audio stream URL with active Lockscreen Metadata
  Future<void> playAudioUrl(
    String url, {
    required String title,
    required String subtitle,
    String? personaName,
  }) async {
    try {
      mediaItem.add(
        MediaItem(
          id: url,
          album: 'StudySilo AI Masterclass',
          title: title,
          artist: personaName ?? 'StudySilo Neural Voice',
          displaySubtitle: subtitle,
        ),
      );

      // State Guarding: Prevent duplicate completion events during track setup
      isNavigating = true;
      try {
        await _player.stop();
        await _player.setLoopMode(LoopMode.off);
      } catch (_) {}
      await _player.setUrl(url);
      isNavigating = false;
      await _player.play();
    } catch (e) {
      isNavigating = false;
      debugPrint('StudyAudioHandler playAudioUrl error: $e');
    }
  }

  @override
  Future<void> play() async {
    if (onPlayRequested != null) {
      onPlayRequested!();
    } else {
      await _player.play();
    }
  }

  @override
  Future<void> pause() async {
    if (onPauseRequested != null) {
      onPauseRequested!();
    } else {
      await _player.pause();
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      await super.stop();
    } catch (_) {}
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> skipToNext() async {
    if (onSkipNextRequested != null) {
      onSkipNextRequested!();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipPreviousRequested != null) {
      onSkipPreviousRequested!();
    }
  }

  AudioPlayer get internalPlayer => _player;
}
