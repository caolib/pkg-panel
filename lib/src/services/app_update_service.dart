import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'external_link_opener.dart';

const String defaultGithubMirrorBaseUrl = 'https://ghproxy.net/';

enum AppReleaseAssetKind { installer, portable, other }

class AppReleaseAsset {
  const AppReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
    required this.kind,
  });

  final String name;
  final String downloadUrl;
  final int size;
  final AppReleaseAssetKind kind;

  bool get startsInstaller => kind == AppReleaseAssetKind.installer;
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.currentDisplayVersion,
    required this.latestVersion,
    required this.releaseName,
    required this.releaseBody,
    required this.releasePageUrl,
    required this.assets,
    required this.hasUpdate,
  });

  final String currentVersion;
  final String currentDisplayVersion;
  final String latestVersion;
  final String releaseName;
  final String releaseBody;
  final String releasePageUrl;
  final List<AppReleaseAsset> assets;
  final bool hasUpdate;
}

class AppUpdateDownloadProgress {
  const AppUpdateDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int? totalBytes;

  double? get progress {
    final total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }
    final ratio = receivedBytes / total;
    if (ratio < 0) {
      return 0;
    }
    if (ratio > 1) {
      return 1;
    }
    return ratio;
  }
}

class AppUpdateDownloadResult {
  const AppUpdateDownloadResult({
    required this.filePath,
    required this.startedInstaller,
    required this.openedLocation,
  });

  final String filePath;
  final bool startedInstaller;
  final bool openedLocation;
}

class AppUpdateService {
  const AppUpdateService();

  static final Uri _latestReleaseApi = Uri.https(
    'api.github.com',
    '/repos/caolib/pkg-panel/releases/latest',
  );

  Future<AppUpdateInfo> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final response = await _loadLatestReleasePayload();
    final releaseVersion = _normalizeVersion(
      '${response['tag_name'] ?? response['name'] ?? ''}',
    );
    if (releaseVersion.isEmpty) {
      throw const FormatException('未能读取最新版本号。');
    }

    final releaseName = '${response['name'] ?? response['tag_name'] ?? ''}'
        .trim();
    final releaseBody = '${response['body'] ?? ''}'.trim();
    final releasePageUrl = '${response['html_url'] ?? ''}'.trim();
    final assets = _parseAssets(response['assets']);
    final currentVersion = _normalizeVersion(packageInfo.version);
    final currentDisplayVersion = packageInfo.buildNumber.trim().isEmpty
        ? packageInfo.version.trim()
        : '${packageInfo.version.trim()}+${packageInfo.buildNumber.trim()}';

    return AppUpdateInfo(
      currentVersion: currentVersion,
      currentDisplayVersion: currentDisplayVersion,
      latestVersion: releaseVersion,
      releaseName: releaseName.isEmpty ? releaseVersion : releaseName,
      releaseBody: releaseBody,
      releasePageUrl: releasePageUrl,
      assets: assets,
      hasUpdate: _compareVersions(releaseVersion, currentVersion) > 0,
    );
  }

  Future<AppUpdateDownloadResult> downloadAsset(
    AppReleaseAsset asset, {
    void Function(AppUpdateDownloadProgress progress)? onProgress,
    bool useGithubMirror = false,
    String? githubMirrorBaseUrl,
  }) async {
    final destinationDirectory = asset.startsInstaller
        ? await _resolveInstallerDirectory()
        : await _resolveDownloadDirectory();
    final destinationFile = await _createDestinationFile(
      destinationDirectory,
      asset.name,
    );
    await _downloadToFile(
      useGithubMirror
          ? _resolveGithubMirrorUrl(
              asset.downloadUrl,
              githubMirrorBaseUrl ?? defaultGithubMirrorBaseUrl,
            )
          : asset.downloadUrl,
      destinationFile,
      onProgress: onProgress,
    );

    var startedInstaller = false;
    var openedLocation = false;
    if (asset.startsInstaller) {
      startedInstaller = await _launchInstaller(destinationFile);
    } else {
      openedLocation = await openExternalLinkWithSystem(
        destinationFile.parent.path,
      );
    }

    return AppUpdateDownloadResult(
      filePath: destinationFile.path,
      startedInstaller: startedInstaller,
      openedLocation: openedLocation,
    );
  }

  Future<Map<String, dynamic>> _loadLatestReleasePayload() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(_latestReleaseApi);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set(HttpHeaders.userAgentHeader, 'pkg-panel');
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'GitHub 返回 ${response.statusCode}${body.trim().isEmpty ? '' : '：$body'}',
          uri: _latestReleaseApi,
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('最新 Release 响应格式不正确。');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  List<AppReleaseAsset> _parseAssets(Object? rawAssets) {
    if (rawAssets is! List) {
      return const <AppReleaseAsset>[];
    }

    final assets = rawAssets
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final name = '${item['name'] ?? ''}'.trim();
          final downloadUrl = '${item['browser_download_url'] ?? ''}'.trim();
          if (name.isEmpty || downloadUrl.isEmpty) {
            return null;
          }
          return AppReleaseAsset(
            name: name,
            downloadUrl: downloadUrl,
            size: switch (item['size']) {
              int value => value,
              _ => 0,
            },
            kind: _classifyAssetKind(name),
          );
        })
        .where((asset) => asset?.kind != AppReleaseAssetKind.other)
        .whereType<AppReleaseAsset>()
        .toList(growable: false);

    assets.sort((a, b) {
      final kindCompare = _assetPriority(
        a.kind,
      ).compareTo(_assetPriority(b.kind));
      if (kindCompare != 0) {
        return kindCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return assets;
  }

  int _assetPriority(AppReleaseAssetKind kind) {
    return switch (kind) {
      AppReleaseAssetKind.installer => 0,
      AppReleaseAssetKind.portable => 1,
      AppReleaseAssetKind.other => 2,
    };
  }

  AppReleaseAssetKind _classifyAssetKind(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.exe') || lower.endsWith('.msi')) {
      return AppReleaseAssetKind.installer;
    }
    if (lower.contains('portable') ||
        lower.contains('green') ||
        lower.contains('绿色') ||
        lower.endsWith('.zip') ||
        lower.endsWith('.7z')) {
      return AppReleaseAssetKind.portable;
    }
    return AppReleaseAssetKind.other;
  }

  String _normalizeVersion(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    var normalized = trimmed;
    if (normalized.startsWith('v') || normalized.startsWith('V')) {
      normalized = normalized.substring(1);
    }
    normalized = normalized.split('+').first.trim();
    return normalized;
  }

  int _compareVersions(String left, String right) {
    final leftParts = _parseVersionParts(left);
    final rightParts = _parseVersionParts(right);
    final length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var index = 0; index < length; index++) {
      final leftPart = index < leftParts.length ? leftParts[index] : 0;
      final rightPart = index < rightParts.length ? rightParts[index] : 0;
      if (leftPart != rightPart) {
        return leftPart.compareTo(rightPart);
      }
    }
    return 0;
  }

  List<int> _parseVersionParts(String value) {
    return _normalizeVersion(value)
        .split(RegExp(r'[.-]'))
        .map(
          (part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        )
        .toList(growable: false);
  }

  Future<Directory> _resolveInstallerDirectory() async {
    final directory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}pkg_panel'
      '${Platform.pathSeparator}updates',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> _resolveDownloadDirectory() async {
    final userProfile = Platform.environment['USERPROFILE']?.trim() ?? '';
    final home = Platform.environment['HOME']?.trim() ?? '';
    final xdgDownload = Platform.environment['XDG_DOWNLOAD_DIR']?.trim() ?? '';
    final candidates = <String>[
      if (xdgDownload.isNotEmpty) xdgDownload,
      if (userProfile.isNotEmpty)
        '$userProfile${Platform.pathSeparator}Downloads',
      if (home.isNotEmpty) '$home${Platform.pathSeparator}Downloads',
      Directory.systemTemp.path,
    ];

    for (final candidate in candidates) {
      final directory = Directory(candidate);
      try {
        await directory.create(recursive: true);
        return directory;
      } catch (_) {
        continue;
      }
    }

    return Directory.systemTemp;
  }

  Future<File> _createDestinationFile(
    Directory directory,
    String originalName,
  ) async {
    final fileName = originalName.trim().isEmpty
        ? 'pkg-panel-update.bin'
        : originalName.trim();
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex <= 0 ? fileName : fileName.substring(0, dotIndex);
    final extension = dotIndex <= 0 ? '' : fileName.substring(dotIndex);

    var candidate = File('${directory.path}${Platform.pathSeparator}$fileName');
    var suffix = 1;
    while (await candidate.exists()) {
      candidate = File(
        '${directory.path}${Platform.pathSeparator}$baseName-$suffix$extension',
      );
      suffix += 1;
    }
    return candidate;
  }

  Future<void> _downloadToFile(
    String url,
    File destination, {
    void Function(AppUpdateDownloadProgress progress)? onProgress,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'pkg-panel');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        final body = await utf8.decoder.bind(response).join();
        throw HttpException(
          '下载失败，服务器返回 ${response.statusCode}${body.trim().isEmpty ? '' : '：$body'}',
          uri: Uri.parse(url),
        );
      }

      final sink = destination.openWrite();
      try {
        final totalBytes = response.contentLength > 0
            ? response.contentLength
            : null;
        var receivedBytes = 0;
        onProgress?.call(
          AppUpdateDownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
          ),
        );
        await for (final chunk in response) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          onProgress?.call(
            AppUpdateDownloadProgress(
              receivedBytes: receivedBytes,
              totalBytes: totalBytes,
            ),
          );
        }
        await sink.close();
      } catch (_) {
        await sink.close();
        if (await destination.exists()) {
          await destination.delete();
        }
        rethrow;
      }
    } finally {
      client.close(force: true);
    }
  }

  String _resolveGithubMirrorUrl(String url, String baseUrl) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final normalizedBase = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalizedBase.isEmpty) {
      return trimmed;
    }
    return '$normalizedBase/$trimmed';
  }

  Future<bool> _launchInstaller(File file) async {
    try {
      final lower = file.path.toLowerCase();
      if (Platform.isWindows && lower.endsWith('.msi')) {
        await Process.start('msiexec', <String>[
          '/i',
          file.path,
        ], mode: ProcessStartMode.detached);
        return true;
      }
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await Process.start(
          file.path,
          const <String>[],
          mode: ProcessStartMode.detached,
        );
        return true;
      }
    } catch (_) {
      return openExternalLinkWithSystem(file.path);
    }
    return false;
  }
}
