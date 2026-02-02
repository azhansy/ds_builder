# DS Builder

[![pub.dev](https://img.shields.io/pub/v/ds_builder.svg)](https://pub.dev/packages/ds_builder)

Flutter项目的构建工具集合。包括路由代码生成和资源R文件生成。

## 功能特性

- **路由生成器**：从 `route_config.dart` 自动生成路由配置
- **资源生成器**：扫描assets目录并生成类型安全的R类，包含所有资源常量
- **灵活配置**：通过 `ds_builder_config.yaml` 进行灵活配置
- **零配置**：开箱即用，提供合理的默认值- **通用设计**：自动检测项目包名，支持任何Flutter项目
## 安装

在 `pubspec.yaml` 中添加：

```yaml
dev_dependencies:
  build_runner: ^2.4.0
  ds_builder: ^1.0.0
```

## 使用

### 路由生成器

1. 创建 `lib/route_config.dart`：

```dart
const List<List<Object>> routesConfig = [
  ['auth', '/login', 'LoginPage', false],
  ['home', '/home', 'HomePage', false],
  ['workflow', '/workflow/:id', 'WorkflowPage', true],
];
```

2. 运行build_runner：

```bash
dart run build_runner build
```

这会生成 `lib/router.g.dart`，包含：
- `RouteNames` 类，含所有路由常量
- GoRouter 配置
- 命名路由定义

### 资源生成器

1. 在 `assets/` 目录中放置资源：

```
assets/
├── images/
│   ├── home/
│   │   ├── logo.png
│   │   └── avatar.png
│   └── form/
│       └── attachment.svg
└── file/
    └── config.json
```

2. 运行build_runner：

```bash
dart run build_runner build
```

这会生成 `lib/res/r.dart`，包含：

```dart
class R {
  R._();
  
  static const String logoPng = 'assets/images/home/logo.png';
  static const String avatarPng = 'assets/images/home/avatar.png';
  static const String attachmentSvg = 'assets/images/form/attachment.svg';
  static const String configJson = 'assets/file/config.json';
}
```

## 配置

在项目根目录创建 `ds_builder_config.yaml` 来自定义行为：

```yaml
# 扫描资源时忽略的目录
ignoreDirs:
  - images/emoji
  - images/country
  - fonts
```

如果配置文件缺失，将使用默认值。

## 项目设置

### 最小配置（使用默认值）

```bash
# 仅需运行build_runner
dart run build_runner build
```

### 完整配置（带自定义设置）

1. 在 `dev_dependencies` 中添加 `ds_builder`
2. 创建 `ds_builder_config.yaml` 进行自定义
3. 运行：`dart run build_runner build`

## 生成的文件

- `lib/router.g.dart` - 路由配置
- `lib/res/r.dart` - 资源常量

将这些添加到 `.gitignore` （可选 - 通常建议提交以确保版本一致性）：

```gitignore
# 生成的文件（保留以确保一致的构建）
lib/router.g.dart
lib/res/r.dart
```

## 使用示例

### 使用生成的路由

```dart
import 'package:go_router/go_router.dart';
import 'router.g.dart';

final router = goRouter;

// 导航
context.go(RouteNames.home);
context.push(RouteNames.workflow, extra: {'id': 123});
```

### 使用生成的资源

```dart
import 'res/r.dart';

Image.asset(R.logoPng);
SvgPicture.asset(R.attachmentSvg);
```

## 故障排查

### 构建失败 "找不到 route_config.dart"

确保 `lib/route_config.dart` 存在于你的项目中。

### 资源未出现在 R.dart 中

1. 检查资源是否在 `assets/` 目录中
2. 验证 `pubspec.yaml` 中的路径：
   ```yaml
   flutter:
     assets:
       - assets/
   ```

### 配置文件未被读取

确保 `ds_builder_config.yaml` 在项目根目录，而不是子目录中。

## 性能

Builder在 `dart run build_runner build` 期间运行，并被缓存。后续构建由于增量生成而更快。

开发模式下的监听模式：

```bash
dart run build_runner watch
```

## 许可证

MIT

## 贡献

欢迎贡献！请向仓库提交Pull Request。

## 支持

遇到问题或功能请求，请访问 [GitHub仓库](https://github.com/azhansy/ds_builder)。
