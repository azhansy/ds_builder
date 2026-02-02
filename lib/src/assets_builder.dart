import 'dart:async';
import 'dart:io';

import 'package:build/build.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Assets Builder for generating R.dart file
/// Scans assets directory and generates resource constants
/// Configure ignore directories in ds_builder_config.yaml
Builder assetsBuilder(BuilderOptions options) => AssetsBuilder();

class AssetsBuilder implements Builder {
  /// Directories to ignore when scanning assets
  /// Default values (overridden by ds_builder_config.yaml if present)
  static const List<String> DEFAULT_IGNORE_DIRS = [
    'images/emoji',
    'images/country',
    'fonts',
  ];

  @override
  Map<String, List<String>> get buildExtensions => {
        r'$lib$': ['res/r.g.dart'],
      };

  /// Load ignore directories from ds_builder_config.yaml
  Future<List<String>> _loadIgnoreDirs(String projectRoot) async {
    final configFile = File(p.join(projectRoot, 'ds_builder_config.yaml'));

    if (!await configFile.exists()) {
      log.info('ds_builder_config.yaml not found, using defaults');
      return DEFAULT_IGNORE_DIRS;
    }

    try {
      final content = await configFile.readAsString();
      final yamlMap = loadYaml(content) as YamlMap?;

      if (yamlMap != null && yamlMap.containsKey('ignoreDirs')) {
        final ignoreDirs = yamlMap['ignoreDirs'] as YamlList?;
        if (ignoreDirs != null) {
          final result = List<String>.from(ignoreDirs);
          log.info('Loaded ignoreDirs from ds_builder_config.yaml: $result');
          return result;
        }
      }
    } catch (e) {
      log.warning('Error reading ds_builder_config.yaml: $e, using defaults');
    }

    return DEFAULT_IGNORE_DIRS;
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    log.info('Starting assets generation...');

    try {
      // Get project root directory
      final packageRoot = p.dirname(p.dirname(buildStep.inputId.path));
      final assetsDir = Directory(p.join(packageRoot, 'assets'));

      if (!await assetsDir.exists()) {
        log.warning('Assets directory not found: ${assetsDir.path}');
        return;
      }

      // Load ignore directories from config
      final ignoreDirs = await _loadIgnoreDirs(packageRoot);

      // Scan assets and generate R.dart
      final rContent = await _generateRFile(assetsDir, ignoreDirs);

      // Write to lib/res/r.dart
      final outputId = AssetId(buildStep.inputId.package, 'lib/res/r.g.dart');
      await buildStep.writeAsString(outputId, rContent);

      log.info('✅ Generated: ${outputId.path}');
    } catch (e, stackTrace) {
      log.severe('Error generating assets', e, stackTrace);
      rethrow;
    }
  }

  /// Generate R.dart file content
  Future<String> _generateRFile(Directory assetsDir, List<String> ignoreDirs) async {
    final buffer = StringBuffer();
    final varNames = <String>{}; // Track used variable names

    // Header
    buffer.writeln('class R {');
    buffer.writeln('  R._();');
    buffer.writeln('');

    // Scan assets directory recursively
    await for (final entity in assetsDir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = p.relative(entity.path, from: assetsDir.parent.path);

        // Skip if in ignore list
        if (_shouldIgnore(relativePath, ignoreDirs)) {
          continue;
        }

        // Generate variable name
        final varName = _generateVarName(relativePath, varNames);
        varNames.add(varName);

        // Add constant
        buffer.writeln("  static const String $varName = '$relativePath';");
      }
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  /// Check if path should be ignored
  bool _shouldIgnore(String path, List<String> ignoreDirs) {
    for (final ignoreDir in ignoreDirs) {
      if (path.contains('assets/$ignoreDir/')) {
        return true;
      }
    }
    return false;
  }

  /// Generate variable name from file path
  String _generateVarName(String path, Set<String> usedNames) {
    // Extract filename without extension
    final fileName = p.basenameWithoutExtension(path);
    final extension = p.extension(path).replaceAll('.', '');

    // Convert to camelCase: ic_form_text.svg -> icFormTextSvg
    var varName = _toCamelCase(fileName) + _capitalize(extension);

    // Handle duplicates by adding parent directory
    if (usedNames.contains(varName)) {
      final parentDir = p.basename(p.dirname(path));
      varName = _toCamelCase(parentDir) + _capitalize(varName);
    }

    return varName;
  }

  /// Convert snake_case or kebab-case to camelCase
  String _toCamelCase(String text) {
    // Replace - and . with _
    text = text.replaceAll(RegExp(r'[-.]'), '_');

    final parts = text.split('_');
    if (parts.isEmpty) return '';

    final buffer = StringBuffer(parts[0].toLowerCase());
    for (var i = 1; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        buffer.write(_capitalize(parts[i]));
      }
    }

    return buffer.toString();
  }

  /// Capitalize first letter
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
