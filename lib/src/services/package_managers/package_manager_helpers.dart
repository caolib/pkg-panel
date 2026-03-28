import 'dart:convert';

import '../../models/package_models.dart';
import '../shell_executor.dart';

class PackageAdapterException implements Exception {
  const PackageAdapterException(this.managerName, this.message);

  final String managerName;
  final String message;

  @override
  String toString() => '$managerName 失败：$message';
}

PackageCommand buildPackageCommand({
  required String managerId,
  required String label,
  required String command,
  Duration timeout = const Duration(minutes: 5),
}) {
  return PackageCommand(
    managerId: managerId,
    busyKey: '$managerId::$label',
    label: label,
    command: command,
    timeout: timeout,
  );
}

dynamic decodeJson(ShellResult result, {required String managerName}) {
  if (!result.isSuccess) {
    throw PackageAdapterException(managerName, result.combinedOutput);
  }

  final raw = extractJsonPayload(result.stdout);
  try {
    return jsonDecode(raw);
  } on FormatException catch (error) {
    throw PackageAdapterException(managerName, '解析 JSON 输出失败：$error');
  }
}

Map<String, dynamic> decodeJsonObject(
  ShellResult result, {
  required String managerName,
}) {
  final decoded = decodeJson(result, managerName: managerName);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  throw PackageAdapterException(managerName, '返回结果不是 JSON 对象。');
}

List<Map<String, dynamic>> decodeJsonArray(
  ShellResult result, {
  required String managerName,
}) {
  final decoded = decodeJson(result, managerName: managerName);
  if (decoded is List) {
    return decoded.cast<Map<String, dynamic>>();
  }
  throw PackageAdapterException(managerName, '返回结果不是 JSON 数组。');
}

String extractJsonPayload(String output) {
  final trimmed = output.trim();
  final arrayStart = trimmed.indexOf('[');
  final objectStart = trimmed.indexOf('{');

  final starts = <int>[
    if (arrayStart >= 0) arrayStart,
    if (objectStart >= 0) objectStart,
  ]..sort();

  if (starts.isEmpty) {
    return trimmed;
  }

  final start = starts.first;
  final end = [trimmed.lastIndexOf(']'), trimmed.lastIndexOf('}')]..sort();

  final last = end.last;
  if (last < start) {
    return trimmed.substring(start);
  }

  return trimmed.substring(start, last + 1);
}

String psQuote(String value) {
  return "'${value.replaceAll("'", "''")}'";
}

String? normalizeVersion(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return text;
}

String stringOrUnknown(Object? value) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty) {
    return unknownVersionLabel;
  }
  return text;
}

int packageSort(ManagedPackage a, ManagedPackage b) {
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

String sliceColumn(String line, int start, int? end) {
  if (start >= line.length) {
    return '';
  }
  final raw = end == null || end > line.length
      ? line.substring(start)
      : line.substring(start, end);
  return raw.trim();
}

String? firstNonEmptyLine(String text) {
  for (final line in LineSplitter.split(text)) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

String parseSingleVersionValue(
  ShellResult result, {
  required String managerName,
}) {
  if (!result.isSuccess) {
    throw PackageAdapterException(managerName, result.combinedOutput);
  }

  final trimmed = result.stdout.trim();
  if (trimmed.isEmpty) {
    throw PackageAdapterException(managerName, '没有返回版本信息。');
  }

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is String && decoded.trim().isNotEmpty) {
      return decoded.trim();
    }
  } catch (_) {
    // Fall back to plain-text parsing below.
  }

  final firstLine = firstNonEmptyLine(trimmed);
  if (firstLine == null || firstLine.isEmpty) {
    throw PackageAdapterException(managerName, '没有返回版本信息。');
  }
  return firstLine.replaceAll('"', '').trim();
}

String parseDetailOutput(ShellResult result, {required String managerName}) {
  if (!result.isSuccess) {
    throw PackageAdapterException(managerName, result.combinedOutput);
  }

  final output = result.combinedOutput.trim();
  if (output.isEmpty) {
    throw PackageAdapterException(managerName, '没有返回详情信息。');
  }
  return output;
}

List<SearchPackage> parseNpmSearchResults(
  ShellResult result, {
  required PackageManagerDefinition manager,
}) {
  final payload = decodeJsonArray(result, managerName: manager.displayName);
  return payload
      .map((entry) {
        final package = entry['package'] is Map<String, dynamic>
            ? entry['package'] as Map<String, dynamic>
            : entry;
        return SearchPackage(
          name: '${package['name'] ?? ''}'.trim(),
          managerId: manager.id,
          managerName: manager.displayName,
          version: nullableSearchValue(package['version']),
          description: nullableSearchValue(package['description']),
          identifier: nullableSearchValue(package['name']),
          source: nullableSearchValue(package['publisher']?['username']),
          installOptions: <SearchPackageInstallOption>[
            SearchPackageInstallOption(
              managerId: manager.id,
              managerName: manager.displayName,
              packageName: '${package['name'] ?? ''}'.trim(),
              identifier: nullableSearchValue(package['name']),
              version: nullableSearchValue(package['version']),
              source: nullableSearchValue(package['publisher']?['username']),
            ),
          ],
        );
      })
      .where((item) => item.name.isNotEmpty)
      .toList(growable: false);
}

List<SearchPackage> parseCargoSearchResults(
  ShellResult result, {
  required PackageManagerDefinition manager,
}) {
  if (!result.isSuccess) {
    throw PackageAdapterException(manager.displayName, result.combinedOutput);
  }

  final output = <SearchPackage>[];
  final pattern = RegExp(r'^([\w\-.]+)\s*=\s*"([^"]+)"\s*#\s*(.*)$');
  for (final line in LineSplitter.split(result.stdout)) {
    final match = pattern.firstMatch(line.trim());
    if (match == null) {
      continue;
    }
    output.add(
      SearchPackage(
        name: match.group(1)!.trim(),
        managerId: manager.id,
        managerName: manager.displayName,
        version: match.group(2)!.trim(),
        description: match.group(3)!.trim(),
        identifier: match.group(1)!.trim(),
        installOptions: <SearchPackageInstallOption>[
          SearchPackageInstallOption(
            managerId: manager.id,
            managerName: manager.displayName,
            packageName: match.group(1)!.trim(),
            identifier: match.group(1)!.trim(),
            version: match.group(2)!.trim(),
          ),
        ],
      ),
    );
  }
  return output;
}

List<SearchPackage> parseScoopSearchResults(
  ShellResult result, {
  required PackageManagerDefinition manager,
}) {
  if (!result.isSuccess) {
    throw PackageAdapterException(manager.displayName, result.combinedOutput);
  }

  final lines = LineSplitter.split(result.stdout)
      .map((line) => line.trimRight())
      .where((line) => line.trim().isNotEmpty)
      .toList(growable: false);

  final headerLine = lines.cast<String?>().firstWhere(
    (line) => line != null && line.trimLeft().startsWith('Name'),
    orElse: () => null,
  );
  if (headerLine == null) {
    return const <SearchPackage>[];
  }

  final headerIndex = lines.indexOf(headerLine);
  final versionStart = headerLine.indexOf('Version');
  final sourceStart = headerLine.indexOf('Source');
  final binariesStart = headerLine.indexOf('Binaries');

  if (versionStart < 0 || sourceStart < 0) {
    return const <SearchPackage>[];
  }

  final output = <SearchPackage>[];
  for (final line in lines.skip(headerIndex + 2)) {
    final name = sliceColumn(line, 0, versionStart);
    if (name.isEmpty) {
      continue;
    }
    final version = sliceColumn(line, versionStart, sourceStart);
    final source = sliceColumn(
      line,
      sourceStart,
      binariesStart >= 0 ? binariesStart : null,
    );
    final binaries = binariesStart >= 0
        ? sliceColumn(line, binariesStart, null)
        : '';
    final description = binaries.isEmpty ? null : '命令: $binaries';

    output.add(
      SearchPackage(
        name: name,
        managerId: manager.id,
        managerName: manager.displayName,
        version: version.isEmpty ? null : version,
        description: description,
        identifier: name,
        source: source.isEmpty ? null : source,
        installOptions: <SearchPackageInstallOption>[
          SearchPackageInstallOption(
            managerId: manager.id,
            managerName: manager.displayName,
            packageName: name,
            identifier: name,
            version: version.isEmpty ? null : version,
            source: source.isEmpty ? null : source,
          ),
        ],
      ),
    );
  }
  return output;
}

List<SearchPackage> parseChocolateySearchResults(
  ShellResult result, {
  required PackageManagerDefinition manager,
}) {
  if (!result.isSuccess) {
    throw PackageAdapterException(manager.displayName, result.combinedOutput);
  }

  final output = <SearchPackage>[];
  for (final line in LineSplitter.split(result.stdout)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('Chocolatey v') ||
        trimmed.startsWith('packages found.')) {
      continue;
    }
    final separatorIndex = trimmed.indexOf('|');
    if (separatorIndex <= 0 || separatorIndex >= trimmed.length - 1) {
      continue;
    }
    output.add(
      SearchPackage(
        name: trimmed.substring(0, separatorIndex).trim(),
        managerId: manager.id,
        managerName: manager.displayName,
        version: trimmed.substring(separatorIndex + 1).trim(),
        identifier: trimmed.substring(0, separatorIndex).trim(),
        installOptions: <SearchPackageInstallOption>[
          SearchPackageInstallOption(
            managerId: manager.id,
            managerName: manager.displayName,
            packageName: trimmed.substring(0, separatorIndex).trim(),
            identifier: trimmed.substring(0, separatorIndex).trim(),
            version: trimmed.substring(separatorIndex + 1).trim(),
          ),
        ],
      ),
    );
  }
  return output;
}

List<SearchPackage> parseWingetSearchResults(
  ShellResult result, {
  required PackageManagerDefinition manager,
}) {
  if (!result.isSuccess) {
    throw PackageAdapterException(manager.displayName, result.combinedOutput);
  }

  final output = <SearchPackage>[];
  final lines = LineSplitter.split(result.stdout)
      .map((line) => line.trimRight())
      .where((line) => line.trim().isNotEmpty)
      .toList(growable: false);
  final headerLine = lines.cast<String?>().firstWhere(
    (line) =>
        line != null &&
        firstIndexOfAny(line, const <String>['ID', 'Id']) >= 0 &&
        firstIndexOfAny(line, const <String>['Version', '版本']) >= 0,
    orElse: () => null,
  );
  if (headerLine == null) {
    return const <SearchPackage>[];
  }

  final headerIndex = lines.indexOf(headerLine);
  final idStart = firstIndexOfAny(headerLine, const <String>['ID', 'Id']);
  final versionStart = firstIndexOfAny(headerLine, const <String>[
    'Version',
    '版本',
  ]);
  final sourceStart = firstIndexOfAny(headerLine, const <String>[
    'Source',
    '源',
  ]);

  if (idStart < 0 || versionStart < 0) {
    return const <SearchPackage>[];
  }

  for (final line in lines.skip(headerIndex + 2)) {
    final name = sliceColumn(line, 0, idStart);
    final identifier = sliceColumn(line, idStart, versionStart);
    final version = sliceColumn(
      line,
      versionStart,
      sourceStart >= 0 ? sourceStart : null,
    );
    final source = sourceStart >= 0 ? sliceColumn(line, sourceStart, null) : '';
    if (name.isEmpty || identifier.isEmpty || version.isEmpty) {
      continue;
    }
    output.add(
      SearchPackage(
        name: name,
        managerId: manager.id,
        managerName: manager.displayName,
        identifier: identifier,
        version: version,
        source: source.isEmpty ? null : source,
        installOptions: <SearchPackageInstallOption>[
          SearchPackageInstallOption(
            managerId: manager.id,
            managerName: manager.displayName,
            packageName: name,
            identifier: identifier,
            version: version,
            source: source.isEmpty ? null : source,
          ),
        ],
      ),
    );
  }
  return output;
}

String? nullableSearchValue(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}

int firstIndexOfAny(String text, List<String> needles) {
  for (final needle in needles) {
    final index = text.indexOf(needle);
    if (index >= 0) {
      return index;
    }
  }
  return -1;
}

String extractUvToolDetails(
  ShellResult result, {
  required String managerName,
  required String packageName,
}) {
  if (!result.isSuccess) {
    throw PackageAdapterException(managerName, result.combinedOutput);
  }

  final lines = LineSplitter.split(result.stdout)
      .map((line) => line.trimRight())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  final headerPattern = RegExp(r'^(.+?)\s+v([^\s]+)$');
  final normalizedTarget = packageName.trim().toLowerCase();

  for (var i = 0; i < lines.length; i++) {
    final match = headerPattern.firstMatch(lines[i].trim());
    if (match == null) {
      continue;
    }
    final currentName = (match.group(1) ?? '').trim();
    if (currentName.toLowerCase() != normalizedTarget) {
      continue;
    }

    final buffer = <String>[lines[i]];
    for (var j = i + 1; j < lines.length; j++) {
      final nextLine = lines[j];
      if (headerPattern.hasMatch(nextLine.trim())) {
        break;
      }
      buffer.add(nextLine);
    }
    return buffer.join('\n').trim();
  }

  throw PackageAdapterException(managerName, '无法读取 $packageName 的详情信息。');
}

String extractCargoInstalledDetails(
  ShellResult result, {
  required String managerName,
  required String packageName,
}) {
  if (!result.isSuccess) {
    throw PackageAdapterException(managerName, result.combinedOutput);
  }

  final lines = LineSplitter.split(result.stdout)
      .map((line) => line.trimRight())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  final headerPattern = RegExp(r'^([\w\-.]+)\s+v([^\s:]+):$');
  final normalizedTarget = packageName.trim().toLowerCase();

  for (var i = 0; i < lines.length; i++) {
    final match = headerPattern.firstMatch(lines[i]);
    if (match == null) {
      continue;
    }
    final currentName = (match.group(1) ?? '').trim();
    if (currentName.toLowerCase() != normalizedTarget) {
      continue;
    }

    final buffer = <String>[lines[i]];
    for (var j = i + 1; j < lines.length; j++) {
      final nextLine = lines[j];
      if (headerPattern.hasMatch(nextLine)) {
        break;
      }
      buffer.add(nextLine);
    }
    return buffer.join('\n').trim();
  }

  throw PackageAdapterException(managerName, '无法读取 $packageName 的详情信息。');
}

String parsePipLatestVersion(
  ShellResult result, {
  required String managerName,
}) {
  if (!result.isSuccess) {
    throw PackageAdapterException(managerName, result.combinedOutput);
  }

  for (final line in LineSplitter.split(result.stdout)) {
    final trimmed = line.trim();
    if (trimmed.startsWith('LATEST:')) {
      final latest = trimmed.substring('LATEST:'.length).trim();
      if (latest.isNotEmpty) {
        return latest;
      }
    }
  }

  throw PackageAdapterException(managerName, '无法从 pip 输出中解析最新版本。');
}

String parseCargoLatestVersion(
  ShellResult result, {
  required String managerName,
  required String packageName,
}) {
  if (!result.isSuccess) {
    throw PackageAdapterException(managerName, result.combinedOutput);
  }

  final exactPattern = RegExp(
    '^${RegExp.escape(packageName)}\\s*=\\s*"([^"]+)"',
    caseSensitive: false,
  );
  final genericPattern = RegExp(r'^[^=]+\s*=\s*"([^"]+)"');

  for (final line in LineSplitter.split(result.stdout)) {
    final trimmed = line.trim();
    final exactMatch = exactPattern.firstMatch(trimmed);
    if (exactMatch != null) {
      return exactMatch.group(1)!.trim();
    }
  }

  for (final line in LineSplitter.split(result.stdout)) {
    final trimmed = line.trim();
    final genericMatch = genericPattern.firstMatch(trimmed);
    if (genericMatch != null) {
      return genericMatch.group(1)!.trim();
    }
  }

  throw PackageAdapterException(managerName, '无法从 cargo 搜索结果中解析最新版本。');
}

String parseChocolateyLatestVersion(
  ShellResult result, {
  required String managerName,
  required String packageName,
}) {
  if (!result.isSuccess) {
    throw PackageAdapterException(managerName, result.combinedOutput);
  }

  for (final line in LineSplitter.split(result.stdout)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('Chocolatey v') ||
        trimmed.startsWith('packages found.')) {
      continue;
    }

    final separatorIndex = trimmed.indexOf('|');
    if (separatorIndex <= 0 || separatorIndex >= trimmed.length - 1) {
      continue;
    }

    final name = trimmed.substring(0, separatorIndex).trim();
    final version = trimmed.substring(separatorIndex + 1).trim();
    if (name.toLowerCase() == packageName.toLowerCase() && version.isNotEmpty) {
      return version;
    }
  }

  throw PackageAdapterException(managerName, '无法从 choco 输出中解析最新版本。');
}

bool looksLikeWingetHeaderRow(List<String> columns) {
  if (columns.length < 4) {
    return false;
  }

  final name = columns[0].trim().toLowerCase();
  final identifier = columns[1].trim().toLowerCase();
  final version = columns[2].trim().toLowerCase();
  final fourth = columns[3].trim().toLowerCase();
  final trailing = columns.length > 4
      ? columns.sublist(4).join(' ').trim().toLowerCase()
      : '';

  final headerNames = <String>{'name', '名称'};
  final headerIdentifiers = <String>{'id', 'identifier', '标识', '软件包标识'};
  final headerVersions = <String>{'version', '版本'};
  final headerAvailable = <String>{'available', '可用'};
  final headerSource = <String>{'source', '源'};

  final hasHeaderName = headerNames.contains(name);
  final hasHeaderIdentifier = headerIdentifiers.contains(identifier);
  final hasHeaderVersion = headerVersions.contains(version);
  final hasHeaderAvailable = headerAvailable.contains(fourth);
  final hasHeaderSource =
      headerSource.contains(fourth) || headerSource.contains(trailing);

  return hasHeaderName &&
      hasHeaderVersion &&
      (hasHeaderIdentifier || hasHeaderAvailable || hasHeaderSource);
}

const String unknownVersionLabel = '未知';
const String globalSourceLabel = '全局';
