import 'dart:async';
import 'dart:io';

import 'package:build/build.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Router Builder for AB Router
/// Generates router.g.dart in lib/ directory based on route_config.dart configuration.
class RouterBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => {
    'route_config.dart': ['router.g.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    // Only process route_config.dart files
    if (!buildStep.inputId.path.endsWith('route_config.dart')) {
      return;
    }

    log.info('Processing: ${buildStep.inputId.path}');

    try {
      // Read route configuration
      final configContent = await buildStep.readAsString(buildStep.inputId);
      final routes = _parseRouteConfig(configContent);

      if (routes.isEmpty) {
        log.warning('No routes found in ${buildStep.inputId.path}');
        return;
      }

      // Load custom configuration first and get package name
      final customConfig = await _loadConfig(buildStep);
      final packageName = buildStep.inputId.package; // Use actual package name

      // Auto-generate missing page files
      await _checkAndCreatePages(routes, buildStep, packageName);

      // Auto-generate missing controller/state/repository files
      await _checkAndCreateControllers(routes, buildStep, packageName);

      // Generate router code
      final generatedCode = _generateRouterCode(routes, customConfig, packageName);

      // Write output to lib/router.g.dart
      final outputId = AssetId(buildStep.inputId.package, 'lib/router.g.dart');
      await buildStep.writeAsString(outputId, generatedCode);

      log.info('Generated: ${outputId.path} with ${routes.length} routes');
    } catch (e, stackTrace) {
      log.severe('Error building router', e, stackTrace);
      rethrow;
    }
  }

  /// Load configuration from ds_builder_config.yaml
  Future<Map<String, dynamic>> _loadConfig(BuildStep buildStep) async {
    final projectRootPath = _getProjectRootPath(buildStep);
    final configFile = File(p.join(projectRootPath, 'ds_builder_config.yaml'));

    if (!await configFile.exists()) {
      log.info('ds_builder_config.yaml not found, using defaults');
      return {'customImports': [], 'customCode': ''};
    }

    try {
      final content = await configFile.readAsString();
      final yamlMap = loadYaml(content) as YamlMap?;

      if (yamlMap != null) {
        final customImports = <String>[];
        if (yamlMap.containsKey('customImports')) {
          final imports = yamlMap['customImports'] as YamlList?;
          if (imports != null) {
            customImports.addAll(List<String>.from(imports));
          }
        }

        final customCode = yamlMap['customCode'] as String? ?? '';
        log.info('Loaded custom configuration from ds_builder_config.yaml');
        return {
          'customImports': customImports,
          'customCode': customCode,
        };
      }
    } catch (e) {
      log.warning('Error reading ds_builder_config.yaml: $e, using defaults');
    }

    return {'customImports': [], 'customCode': ''};
  }

  /// Get project root path from BuildStep
  String _getProjectRootPath(BuildStep buildStep) {
    // The input path is like: lib/route_config.dart
    // We need to get the directory containing the project root
    final inputPath = buildStep.inputId.path;
    final libIndex = inputPath.indexOf('lib/');
    if (libIndex > 0) {
      return inputPath.substring(0, libIndex);
    }
    return Directory.current.path;
  }
  }
  /// Parse route configuration from Dart code
  List<RouteEntry> _parseRouteConfig(String content) {
    final routes = <RouteEntry>[];

    // Extract routesConfig list using regex
    final configRegex = RegExp(
      r'const\s+List<List<Object>>\s+routesConfig\s*=\s*\[(.*?)\];',
      multiLine: true,
      dotAll: true,
    );

    final match = configRegex.firstMatch(content);
    if (match == null) {
      log.warning('Could not find routesConfig in file');
      return routes;
    }

    final configBody = match.group(1) ?? '';

    // Parse each route entry - handle both single and double quotes
    final entryRegex = RegExp(
      r"""\[\s*['"]([^'"]*)['"][\s,]+['"]([^'"]*)['"][\s,]+['"]([^'"]*)['"][\s,]+(true|false)\s*\]""",
      multiLine: true,
    );

    for (final entryMatch in entryRegex.allMatches(configBody)) {
      final group = entryMatch.group(1) ?? '';
      final path = entryMatch.group(2) ?? '';
      final page = entryMatch.group(3) ?? '';
      final param = entryMatch.group(4) == 'true';

      _ensurePageNameValid(page);

      routes.add(RouteEntry(group: group, path: path, page: page, param: param));
    }

    log.info('Parsed ${routes.length} routes');
    return routes;
  }

  void _ensurePageNameValid(String pageName) {
    if (pageName.isEmpty) return;
    if (!pageName.endsWith('Page')) {
      throw PackageNotFoundException('Page class name must end with "Page": $pageName');
    }
  }

  /// Generate router code
  String _generateRouterCode(List<RouteEntry> routes, [Map<String, dynamic> config = const {}, String packageName = 'app']) {
    final buffer = StringBuffer();
    final customImports = config['customImports'] as List<String>? ?? [];

    // Header
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// **************************************************************************');
    buffer.writeln('// Router Auto Generated');
    buffer.writeln('// **************************************************************************\n');

    // Imports
    buffer.writeln("import 'package:flutter/material.dart';");
    buffer.writeln("import 'package:go_router/go_router.dart';");

    // Add custom imports from configuration
    for (final import in customImports) {
      buffer.writeln(import);
    }

    // Generate imports for pages
    final pageImports = _generatePageImports(routes, packageName);
    for (final import in pageImports) {
      buffer.writeln(import);
    }

    buffer.writeln("\nimport 'core/di/providers.dart';\n");

    // Generate RouteNames class
    buffer.write(_generateRouteNames(routes));

    // Generate no-parameter routes list
    buffer.write(_generateNoParamRoutes(routes));

    // Generate branch paths configuration
    buffer.write(_generateBranchPaths(routes));

    // Generate GoRouter
    buffer.write(_generateGoRouter(routes));

    return buffer.toString();
  }

  /// Generate page imports
  Set<String> _generatePageImports(List<RouteEntry> routes, String packageName) {
    final imports = <String>{};

    for (final route in routes) {
      if (route.group.isEmpty) continue;

      final fileName = _toSnakeCase(route.page);
      final importPath = "import 'package:$packageName/features/${route.group}/$fileName.dart';";
      imports.add(importPath);
    }

    return imports;
  }

  /// Generate RouteNames class
  String _generateRouteNames(List<RouteEntry> routes) {
    final buffer = StringBuffer();
    final seen = <String>{};

    buffer.writeln('class RouteNames {');

    for (final route in routes) {
      final fullPath = _getFullPath(route);
      final routeName = _getRouteName(route);

      if (routeName.isEmpty || !seen.add(routeName)) continue;

      buffer.writeln("  static const String $routeName = '$fullPath';");
    }

    buffer.writeln('}\n');
    return buffer.toString();
  }

  /// Generate list of routes that do not require params
  String _generateNoParamRoutes(List<RouteEntry> routes) {
    final buffer = StringBuffer();
    final seen = <String>{};

    buffer.writeln('/// 不需要传参的路由列表（用于快捷跳转下拉）');
    buffer.writeln('class RouteNoParamList {');
    buffer.writeln('  static const List<String> routes = [');

    for (final route in routes) {
      if (route.param) continue;

      final fullPath = _getFullPath(route);
      final routeName = _getRouteName(route);
      if (fullPath == '/' || routeName == 'auth' || routeName == 'home') continue;
      final key = routeName.isNotEmpty ? 'RouteNames.$routeName' : fullPath;

      if (!seen.add(key)) continue;

      if (routeName.isNotEmpty) {
        buffer.writeln('    RouteNames.$routeName,');
      } else {
        buffer.writeln("    '$fullPath',");
      }
    }

    buffer.writeln('  ];');
    buffer.writeln('}\n');

    return buffer.toString();
  }

  /// Generate branch paths configuration for StatefulShellRoute
  /// This list must match the order of branches in StatefulShellRoute.indexedStack
  String _generateBranchPaths(List<RouteEntry> routes) {
    final buffer = StringBuffer();

    buffer.writeln('/// 分支路由路径配置，顺序与 StatefulShellRoute branches 一致');
    buffer.writeln('/// 用于 HomeScreen 等组件正确映射导航索引');
    buffer.writeln('class RouterBranchPaths {');
    buffer.writeln('  static const List<String> branchRootPaths = [');

    // Get shell groups in the same order they will appear in branches (sorted)
    final shellGroups = routes.map((r) => r.group).where((g) => g != 'auth').toSet().toList()..sort();

    for (final group in shellGroups) {
      final routePath = group.isEmpty ? "'/'," : "RouteNames.$group,";
      buffer.writeln('    $routePath');
    }

    buffer.writeln('  ];');
    buffer.writeln('}\n');
    return buffer.toString();
  }

  /// Generate GoRouter configuration
  String _generateGoRouter(List<RouteEntry> routes) {
    final buffer = StringBuffer();

    buffer.writeln('final GoRouter router = GoRouter(');
    buffer.writeln('  navigatorKey: GlobalKey<NavigatorState>(),');
    buffer.writeln('  refreshListenable: authStatus,');
    buffer.writeln('  redirect: (context, state) {');
    buffer.writeln('    final loggedIn = authStatus.value;');
    buffer.writeln("    final isLoggingIn = state.matchedLocation == RouteNames.auth;");
    buffer.writeln();
    buffer.writeln('    if (!loggedIn) {');
    buffer.writeln('      return isLoggingIn ? null : RouteNames.auth;');
    buffer.writeln('    }');
    buffer.writeln('    if (isLoggingIn) return RouteNames.home;');
    buffer.writeln();
    buffer.writeln('    return null;');
    buffer.writeln('  },');
    buffer.writeln('  errorBuilder: (context, state) => UpgradeNoticePage(missingRoute: state.uri.toString()),');
    buffer.writeln('  routes: [');

    // Auth routes
    final authRoutes = routes.where((r) => r.group == 'auth').toList();
    for (final route in authRoutes) {
      buffer.write(_generateRoute(route, isTopLevel: true));
    }

    // Shell routes
    // include empty group ('') as root branch; exclude only auth
    final shellGroups = routes.map((r) => r.group).where((g) => g != 'auth').toSet().toList()..sort();

    buffer.writeln('    StatefulShellRoute.indexedStack(');
    buffer.writeln('      builder: (context, state, shell) => HomeScreen(navigationShell: shell),');
    buffer.writeln('      branches: [');

    for (final group in shellGroups) {
      buffer.write(_generateShellBranch(group, routes));
    }

    buffer.writeln('      ],');
    buffer.writeln('    ),');
    buffer.writeln('  ],');
    buffer.writeln(');');

    return buffer.toString();
  }

  /// Generate a single route
  String _generateRoute(RouteEntry route, {bool isTopLevel = false}) {
    final buffer = StringBuffer();
    final fullPath = isTopLevel ? _getFullPath(route) : _getChildPath(route);

    buffer.writeln('    GoRoute(');
    buffer.writeln("      path: '$fullPath',");

    if (route.param) {
      buffer.writeln('      builder: (context, state) {');
      buffer.writeln('        final params = (state.extra as Map<String, dynamic>?) ?? {};');
      buffer.writeln('        return ${route.page}(params: params);');
      buffer.writeln('      },');
    } else {
      buffer.writeln("      builder: (context, state) => const ${route.page}(),");
    }

    buffer.writeln('    ),');
    return buffer.toString();
  }

  /// Generate shell branch
  String _generateShellBranch(String group, List<RouteEntry> allRoutes) {
    final buffer = StringBuffer();
    final groupRoutes = allRoutes.where((r) => r.group == group).toList();
    final root = groupRoutes.firstWhere((r) => r.path == '/', orElse: () => groupRoutes.first);
    final children = groupRoutes.where((r) => r != root).toList();

    buffer.writeln('        StatefulShellBranch(');
    buffer.writeln('          navigatorKey: GlobalKey<NavigatorState>(),');
    buffer.writeln('          routes: [');
    buffer.writeln('            GoRoute(');
    final routePath = group.isEmpty ? '/' : '/$group';
    buffer.writeln("              path: '$routePath',");

    if (root.param) {
      buffer.writeln('              pageBuilder: (context, state) {');
      buffer.writeln('                final params = (state.extra as Map<String, dynamic>?) ?? {};');
      buffer.writeln('                return NoTransitionPage(child: ${root.page}(params: params));');
      buffer.writeln('              },');
    } else {
      buffer.writeln('              pageBuilder: (context, state) => NoTransitionPage(child: const ${root.page}()),');
    }

    if (children.isNotEmpty) {
      buffer.writeln('              routes: [');
      for (final child in children) {
        buffer.write(_generateChildRoute(child));
      }
      buffer.writeln('              ],');
    }

    buffer.writeln('            ),');
    buffer.writeln('          ],');
    buffer.writeln('        ),');

    return buffer.toString();
  }

  /// Generate child route
  String _generateChildRoute(RouteEntry route) {
    final buffer = StringBuffer();
    final childPath = _getChildPath(route);

    buffer.writeln('                GoRoute(');
    buffer.writeln("                  path: '$childPath',");

    if (route.param) {
      buffer.writeln('                  pageBuilder: (context, state) {');
      buffer.writeln('                    final params = (state.extra as Map<String, dynamic>?) ?? {};');
      buffer.writeln('                    return NoTransitionPage(child: ${route.page}(params: params));');
      buffer.writeln('                  },');
    } else {
      buffer.writeln(
        '                  pageBuilder: (context, state) => NoTransitionPage(child: const ${route.page}()),',
      );
    }

    buffer.writeln('                ),');
    return buffer.toString();
  }

  /// Helper: Get full path
  String _getFullPath(RouteEntry route) {
    if (route.path == '/') {
      return '/${route.group}';
    }
    final pathWithoutSlash = route.path.startsWith('/') ? route.path.substring(1) : route.path;
    return '/${route.group}/$pathWithoutSlash';
  }

  /// Helper: Get child path (without leading slash)
  String _getChildPath(RouteEntry route) {
    return route.path.startsWith('/') ? route.path.substring(1) : route.path;
  }

  /// Helper: Get route name
  String _getRouteName(RouteEntry route) {
    if (route.path == '/') {
      return route.group;
    }
    return _toRouteName(route.page);
  }

  /// Helper: Convert to snake_case
  String _toSnakeCase(String str) {
    if (str.endsWith('Page')) {
      str = str.substring(0, str.length - 4);
    }
    final snake = str
        .replaceAllMapped(
          RegExp(r'([A-Z]+)([A-Z][a-z])'),
          (m) => '${m[1]?.toLowerCase() ?? ''}_${m[2]?.toLowerCase() ?? ''}',
        )
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1] ?? ''}_${m[2]?.toLowerCase() ?? ''}')
        .replaceAllMapped(RegExp(r'([A-Z])([A-Z])'), (m) => '${m[1]?.toLowerCase() ?? ''}${m[2]?.toLowerCase() ?? ''}')
        .toLowerCase();
    return '${snake}_page';
  }

  /// Helper: Convert to route name
  String _toRouteName(String pageName) {
    final base = pageName.endsWith('Page') ? pageName.substring(0, pageName.length - 4) : pageName;
    if (base.isEmpty) return '';
    return '${base[0].toLowerCase()}${base.substring(1)}';
  }

  /// Check and create missing page files
  Future<void> _checkAndCreatePages(List<RouteEntry> routes, BuildStep buildStep, String packageName) async {
    for (final route in routes) {
      if (route.group.isEmpty || route.group == 'auth') continue;

      final pageName = route.page;
      if (pageName.isEmpty) continue;

      // Convert page name to file name
      final pageFileName = _toSnakeCase(pageName);

      // Construct page file path
      final pagePath = 'lib/features/${route.group}/$pageFileName.dart';
      final pageFile = File(pagePath);

      // Check if page exists
      if (!await pageFile.exists()) {
        log.info('📝 Creating missing page: $pagePath');
        await _createPageFile(route, pageFile, packageName);
      }
    }
  }

  /// Create page file if missing
  Future<void> _createPageFile(RouteEntry route, File pageFile, String packageName) async {
    try {
      // Ensure directory exists
      await pageFile.parent.create(recursive: true);

      // Generate page template
      final pageContent = _generatePageTemplate(route.page, packageName, param: route.param);

      // Write page file
      await pageFile.writeAsString(pageContent);

      log.info('✅ Created page: ${pageFile.path}');
    } catch (e) {
      log.warning('Failed to create page: $e');
    }
  }

  /// Generate page template
  String _generatePageTemplate(String pageName, String packageName, {bool param = false}) {
    final pageFileName = _toSnakeCase(pageName);
    final controllerFileName = pageFileName.replaceAll('_page', '_controller');
    final stateFileName = pageFileName.replaceAll('_page', '_state');
    final providerName = '${_toRouteName(pageName)}ControllerProvider';

    if (param) {
      return '''import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:$packageName/widgets/common_scaffold.dart';
import 'controllers/$controllerFileName.dart';
import 'models/$stateFileName.dart';

class $pageName extends ConsumerStatefulWidget {
  final Map<String, dynamic> params;

  const $pageName({
    super.key,
    required this.params,
  });

  @override
  ConsumerState<$pageName> createState() => _${pageName}State();
}

class _${pageName}State extends ConsumerState<$pageName> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch($providerName);
    
    return CommonScaffold(
      titleStr: '$pageName',
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        success: () => const Center(child: Text('TODO: Implement $pageName')),
        error: (message) => Center(child: Text('Error: \$message')),
      ),
    );
  }
}
''';
    } else {
      return '''import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:$packageName/widgets/common_scaffold.dart';
import 'controllers/$controllerFileName.dart';
import 'models/$stateFileName.dart';

class $pageName extends ConsumerStatefulWidget {
  const $pageName({super.key});

  @override
  ConsumerState<$pageName> createState() => _${pageName}State();
}

class _${pageName}State extends ConsumerState<$pageName> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch($providerName);
    
    return CommonScaffold(
      titleStr: '$pageName',
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        success: () => const Center(child: Text('TODO: Implement $pageName')),
        error: (message) => Center(child: Text('Error: \$message')),
      ),
    );
  }
}
''';
    }
  }

  /// Check and create missing controller/state/repository files
  Future<void> _checkAndCreateControllers(List<RouteEntry> routes, BuildStep buildStep, String packageName) async {
    for (final route in routes) {
      if (route.group.isEmpty || route.group == 'auth') continue;

      final pageName = route.page;
      if (pageName.isEmpty) continue;

      // Convert page name to controller file name
      final pageFileName = _toSnakeCase(pageName);
      final controllerFileName = pageFileName.replaceAll('_page', '_controller');

      // Construct controller file path
      final controllerPath = 'lib/features/${route.group}/controllers/$controllerFileName.dart';
      final controllerFile = File(controllerPath);

      // Check if controller exists
      if (!await controllerFile.exists()) {
        log.info('🔧 Creating missing controller: $controllerPath');
        await _createControllerIfMissing(route, controllerFile, packageName);
      }
    }
  }

  /// Create controller file if missing
  Future<void> _createControllerIfMissing(RouteEntry route, File controllerFile, String packageName) async {
    try {
      // Ensure directory exists
      await controllerFile.parent.create(recursive: true);

      // Generate controller template
      final controllerContent = _generateControllerTemplate(route, packageName);

      // Write controller file
      await controllerFile.writeAsString(controllerContent);

      log.info('✅ Created controller: ${controllerFile.path}');

      // Also create state and repository files
      await _createStateIfMissing(route);
      await _createRepositoryIfMissing(route);
    } catch (e) {
      log.warning('Failed to create controller: $e');
    }
  }

  /// Create state file if missing
  Future<void> _createStateIfMissing(RouteEntry route) async {
    final pageFileName = _toSnakeCase(route.page);
    final stateFileName = pageFileName.replaceAll('_page', '_state');
    final statePath = 'lib/features/${route.group}/models/$stateFileName.dart';
    final stateFile = File(statePath);

    if (await stateFile.exists()) return;

    try {
      await stateFile.parent.create(recursive: true);
      final stateContent = _generateStateTemplate(route);
      await stateFile.writeAsString(stateContent);
      log.info('✅ Created state: ${stateFile.path}');
    } catch (e) {
      log.warning('Failed to create state: $e');
    }
  }

  /// Create repository file if missing
  Future<void> _createRepositoryIfMissing(RouteEntry route) async {
    final pageFileName = _toSnakeCase(route.page);
    final repoFileName = pageFileName.replaceAll('_page', '_repository');
    final repoPath = 'lib/features/${route.group}/repositories/$repoFileName.dart';
    final repoFile = File(repoPath);

    if (await repoFile.exists()) return;

    try {
      await repoFile.parent.create(recursive: true);
      final repoContent = _generateRepositoryTemplate(route);
      await repoFile.writeAsString(repoContent);
      log.info('✅ Created repository: ${repoFile.path}');
    } catch (e) {
      log.warning('Failed to create repository: $e');
    }
  }

  /// Generate controller template
  String _generateControllerTemplate(RouteEntry route, String packageName) {
    final pageName = route.page;
    final pageBaseName = pageName.replaceAll('Page', '');
    final controllerClassName = '${pageBaseName}Controller';
    final stateClassName = '${pageBaseName}State';
    final pageFileName = _toSnakeCase(pageName);
    final stateFileName = pageFileName.replaceAll('_page', '_state');
    final repoFileName = pageFileName.replaceAll('_page', '_repository');
    final providerName = '${_toRouteName(pageName)}ControllerProvider';
    final repoProviderName = '${_toRouteName(pageName)}RepositoryProvider';

    return '''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:$packageName/features/${route.group}/models/$stateFileName.dart';
import 'package:$packageName/features/${route.group}/repositories/$repoFileName.dart';

/// Page controller for ${route.page}
final $providerName = StateNotifierProvider.autoDispose<
    $controllerClassName,
    $stateClassName
>(
  (ref) => $controllerClassName(ref),
);

class $controllerClassName extends StateNotifier<$stateClassName> {
  final Ref _ref;

  $controllerClassName(this._ref) : super(const $stateClassName.loading()) {
    _loadData();
  }

  /// Load initial data
  Future<void> _loadData() async {
    try {
      final repository = _ref.watch($repoProviderName);
      // TODO: Implement data loading logic
      
      state = const $stateClassName.success();
    } catch (e) {
      state = $stateClassName.error(message: e.toString());
    }
  }

  /// Refresh data
  Future<void> refresh() => _loadData();

  // TODO: Add your business logic methods here
}
''';
  }

  /// Generate state template
  String _generateStateTemplate(RouteEntry route) {
    final pageName = route.page;
    final pageBaseName = pageName.replaceAll('Page', '');
    final stateClassName = '${pageBaseName}State';
    final pageFileName = _toSnakeCase(pageName);
    final stateFileName = pageFileName.replaceAll('_page', '_state');

    return 'import \'package:freezed_annotation/freezed_annotation.dart\';\n\n'
        'part \'$stateFileName.freezed.dart\';\n\n'
        '/// State for ${route.page}\n'
        '@freezed\n'
        'sealed class $stateClassName with _\$$stateClassName {\n'
        '  const $stateClassName._();\n'
        '  \n'
        '  const factory $stateClassName.loading() = _Loading;\n'
        '  const factory $stateClassName.success() = _Success;\n'
        '  const factory $stateClassName.error({required String message}) = _Error;\n'
        '\n'
        '  // Convenience getters\n'
        '  bool get isLoading => this is _Loading;\n'
        '  bool get isSuccess => this is _Success;\n'
        '  bool get isError => this is _Error;\n'
        '}\n';
  }

  /// Generate repository template
  String _generateRepositoryTemplate(RouteEntry route) {
    final pageName = route.page;
    final pageBaseName = pageName.replaceAll('Page', '');
    final repoClassName = '${pageBaseName}Repository';
    final providerName = '${_toRouteName(pageName)}RepositoryProvider';

    return '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository for ${route.page}
final $providerName = Provider((ref) => $repoClassName());

class $repoClassName {
  // TODO: Inject API dependencies
  
  // TODO: Add data fetching methods
}
''';
  }

/// Route entry data class
class RouteEntry {
  final String group;
  final String path;
  final String page;
  final bool param;

  const RouteEntry({required this.group, required this.path, required this.page, required this.param});

  @override
  String toString() => 'RouteEntry(group: $group, path: $path, page: $page, param: $param)';
}

/// Builder factory for build_runner
Builder routerBuilder(BuilderOptions options) => RouterBuilder();
