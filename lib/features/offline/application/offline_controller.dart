import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../data/offline_repository.dart';
import '../domain/offline_snapshot.dart';

final offlineProvider = ChangeNotifierProvider<OfflineController>((ref) {
  final user = ref.watch(currentUserProvider);
  final controller = OfflineController(
    user?.offlineStaffId,
    OfflineRepository(),
    () => user != null && identical(ref.read(currentUserProvider), user),
    authenticated: user != null,
    authRepository: ref.read(authRepositoryProvider),
  );
  return controller;
});

class OfflineController extends ChangeNotifier {
  OfflineController(
    this.owner,
    this.repository,
    this.stillOwner, {
    this.authenticated = true,
    AuthRepository? authRepository,
  }) : authRepository = authRepository ?? AuthRepository(),
       authSession = AuthRepository.sessionVersion {
    unawaited(load());
  }
  String? owner;
  final bool authenticated;
  final AuthRepository authRepository;
  final int authSession;
  final OfflineRepository repository;
  final bool Function() stillOwner;
  bool _disposed = false;
  bool loading = true, downloading = false, syncing = false;
  String connection = 'Connection not checked';
  String? error;
  bool get requiresSignIn => !authenticated || authenticationRequired;
  bool authenticationRequired = false;
  String? downloadError;
  double downloadProgress = 0;
  String downloadStage = '';
  bool downloadAttempted = false;
  int downloadAttemptId = 0;
  bool downloadServerUnreachable = false;
  String? syncSummary;
  double syncProgress = 0;
  OfflineSnapshot? snapshot;
  Map<String, Object?>? metadata;
  List<Map<String, Object?>> scans = [];
  int get pending => scans.where((s) => s['outcome'] == null).length;
  int get review => scans.where((s) => s['outcome'] == 'REJECTED').length;
  int get synced => scans.length - pending - review;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (owner == null) {
      loading = false;
      changed();
      return;
    }
    try {
      final cached = await repository.cached(owner!);
      final rows = await repository.history(owner!);
      if (_disposed || !stillOwner()) return;
      metadata = cached;
      snapshot = cached == null
          ? null
          : OfflineSnapshot(
              Map<String, dynamic>.from(
                jsonDecode(cached['payload'] as String) as Map,
              ),
            );
      scans = rows;
    } catch (_) {
      error =
          'Unable to read local attendance storage. Retry before capturing.';
    }
    loading = false;
    changed();
  }

  void failed(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 401) authenticationRequired = true;
      connection = e.response == null
          ? 'Offline / server unreachable'
          : 'Server reachable';
      error = status == 401
          ? 'Sign in again with the same staff account. Your queue is preserved.'
          : status == 403
          ? 'Access denied. Check your invigilator role and exam assignment.'
          : 'Request failed. Saved scans and the previous snapshot are preserved. Retry when connected.';
    } else {
      error =
          'Operation failed. Local data was preserved. ${e is StateError ? e.message : ''}';
    }
  }

  Future<void> download() async {
    if (downloading || _disposed) return;
    if (!authenticated || !stillOwner()) {
      authenticationRequired = true;
      downloadAttempted = true;
      downloadError =
          'No active login session. Sign in again before downloading.';
      downloadStage = 'Download could not start';
      changed();
      return;
    }
    downloading = true;
    downloadAttemptId++;
    downloadServerUnreachable = false;
    downloadAttempted = true;
    downloadProgress = 0;
    downloadStage = 'Preparing download…';
    connection = 'Connecting…';
    downloadError = null;
    changed();
    try {
      await repository.download(
        owner,
        authSession: authSession,
        isCurrentSession: () =>
            !_disposed &&
            stillOwner() &&
            AuthRepository.sessionVersion == authSession,
        onOwnerResolved: (resolvedOwner) async {
          if (_disposed || !stillOwner()) {
            throw StateError('Account changed during download');
          }
          await authRepository.bindOfflineOwner(resolvedOwner, authSession);
          if (_disposed || !stillOwner()) {
            throw StateError('Account changed during download');
          }
          owner = resolvedOwner;
        },
        onProgress: (progress, stage) {
          if (_disposed || !stillOwner()) return;
          downloadProgress = progress > downloadProgress
              ? progress
              : downloadProgress;
          downloadStage = stage;
          changed();
        },
      );
      error = null;
      authenticationRequired = false;
      connection = 'Online';
    } catch (e) {
      downloadServerUnreachable = e is DioException && e.response == null;
      failed(e);
      downloadError = describeDownloadFailure(e, downloadStage);
      error = downloadError;
      downloadStage = 'Download interrupted';
    } finally {
      downloading = false;
      await load();
    }
  }

  static String describeDownloadFailure(Object failure, String stage) {
    if (failure is DioException) {
      final status = failure.response?.statusCode;
      if (status == 401) {
        return 'Login expired (HTTP 401). Sign in again; your saved scans are preserved.';
      }
      if (status == 403) {
        return 'Download denied (HTTP 403). Check your invigilator role and exam assignment.';
      }
      if (status == 404) {
        return 'Offline download endpoint not found (HTTP 404). Check that the configured API server has /api/attendance/offline-exam-data deployed.';
      }
      if (status != null) {
        return 'Server request failed (HTTP $status) during: $stage. Your previous offline data is preserved.';
      }
      if (failure.type == DioExceptionType.connectionTimeout ||
          failure.type == DioExceptionType.receiveTimeout ||
          failure.type == DioExceptionType.sendTimeout) {
        return 'The server timed out during: $stage. Check your connection and retry.';
      }
      return 'Could not reach the API during: $stage. Check the server address and connection. On a browser, also check the server CORS configuration.';
    }
    if (failure is MissingPluginException || failure is UnsupportedError) {
      return 'Local storage is unavailable on this platform. This app currently configures SQLite for Android, iOS and macOS. A full restart is needed after adding native plugins.';
    }
    if (failure is FormatException || failure is TypeError) {
      return 'The server response does not match the offline roster contract (success, data, snapshotId, staffId, assignments and students). No new roster was saved.';
    }
    if (stage.startsWith('Saving')) {
      return 'Could not save the downloaded roster in SQLite. Check available device storage and restart the app. Your previous offline data is preserved.';
    }
    if (failure is StateError) return failure.message.toString();
    return 'Download failed during: $stage. Your previous offline data is preserved.';
  }

  Future<void> sync() async {
    if (owner == null || syncing || _disposed || !stillOwner()) return;
    syncing = true;
    syncProgress = 0;
    final before = pending;
    final pendingIds = scans
        .where((scan) => scan['outcome'] == null)
        .map((scan) => scan['id'])
        .toSet();
    var failedRequest = false;
    Future<void>? progressRead;
    final progressTimer = Timer.periodic(const Duration(milliseconds: 250), (
      _,
    ) {
      if (progressRead != null || _disposed || !stillOwner()) return;
      progressRead = (() async {
        try {
          final rows = await repository.history(owner!);
          if (!_disposed && stillOwner()) {
            scans = rows;
            syncProgress = before == 0
                ? 1
                : scans
                          .where(
                            (scan) =>
                                pendingIds.contains(scan['id']) &&
                                scan['outcome'] != null,
                          )
                          .length /
                      before;
            changed();
          }
        } catch (_) {
          // Final load handles storage errors; keep the current progress visible.
        } finally {
          progressRead = null;
        }
      })();
    });
    changed();
    try {
      await repository.sync(owner!, () => !_disposed && stillOwner());
      if (before > 0) {
        connection = 'Online';
        authenticationRequired = false;
        error = null;
      }
    } catch (e) {
      failedRequest = true;
      failed(e);
    } finally {
      progressTimer.cancel();
      await progressRead;
      await load();
      syncing = false;
      changed();
      if (before > 0) {
        final results = scans.where((scan) => pendingIds.contains(scan['id']));
        final recorded = results
            .where((scan) => scan['outcome'] == 'ACCEPTED')
            .length;
        final existing = results
            .where((scan) => scan['outcome'] == 'ALREADY_RECORDED')
            .length;
        syncSummary =
            '$recorded new attendance recorded · $existing already recorded · ${(before - pending).clamp(0, before)} results received · $pending pending · $review need review${failedRequest
                ? ' · Retry when connected'
                : pending > 0
                ? ' · Some results were missing or malformed; retry pending scans'
                : ''}';
        changed();
      }
    }
  }

  Future<void> capture(
    Map<String, dynamic> assignment,
    String number,
    String method,
    String token,
  ) async {
    if (owner == null || snapshot == null || !stillOwner()) {
      throw StateError('Sign in and download a snapshot first');
    }
    await repository.queue(
      owner: owner!,
      snapshot: snapshot!,
      assignment: assignment,
      number: number,
      method: method,
      token: token,
    );
    await load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
