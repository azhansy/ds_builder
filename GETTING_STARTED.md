# DS Builder 开始使用指南

快速指南，让 DS Builder 在你的 Flutter 项目中运行。

## 5 分钟设置

### 第 1 步：添加依赖

```bash
cd your_flutter_project
flutter pub add --dev ds_builder build_runner
```

或在 `pubspec.yaml` 中手动添加：

```yaml
dev_dependencies:
  build_runner: ^2.4.0
  ds_builder: ^1.0.0
```

然后运行：

```bash
flutter pub get
```

### 第 2 步：创建 route_config.dart（如果使用路由）

```dart
// lib/route_config.dart
const List<List<Object>> routesConfig = [
  ['home', '/', 'HomePage', false],
  ['profile', '/profile', 'ProfilePage', false],
  ['detail', '/detail/:id', 'DetailPage', true],
];
```

格式：`[group, path, pageName, hasParams]`

### 第 3 步：生成代码

```bash
dart run build_runner build
```

这会生成：
- `lib/router.g.dart`（如果存在 route_config.dart）
- `lib/res/r.dart`（如果存在 assets/ 目录）

### 第 4 步：在代码中使用

**路由：**
```dart
import 'router.g.dart';

// 导航
context.go(RouteNames.home);
context.push(RouteNames.detail, extra: {'id': 123});
```

**资源：**
```dart
import 'res/r.dart';

Image.asset(R.logoSvg);
SvgPicture.asset(R.backgroundPng);
```

## 常见任务

### 监视模式（开发中使用）

```bash
dart run build_runner watch
```

文件更改时自动重新生成。

### 清洁构建

```bash
dart run build_runner clean
dart run build_runner build
```

### 自定义资源忽略目录

创建 `ds_builder_config.yaml`：

```yaml
ignoreDirs:
  - images/emoji
  - images/country
  - fonts
```

然后重新构建：

```bash
dart run build_runner build
```

## File Structure

After running ds_builder, your project structure looks like:

```
your_project/
├── lib/
│   ├── router.g.dart          ← Generated
│   ├── res/
│   │   └── r.dart              ← Generated
│   ├── route_config.dart        ← You create this
│   └── main.dart
├── assets/
│   ├── images/
│   └── ...
├── pubspec.yaml
├── ds_builder_config.yaml       ← Optional
└── build.yaml                   ← Optional
```

## Troubleshooting

**Q: Build fails with "line 1, column 1 of route_config.dart: Expected an identifier"**

A: Check your `route_config.dart` syntax. It should only contain:
```dart
const List<List<Object>> routesConfig = [ ... ];
```

**Q: R.dart is empty or missing assets**

A: Check that:
1. Assets are in `assets/` directory (not somewhere else)
2. pubspec.yaml has `assets:` section
3. Re-run with `--delete-conflicting-outputs`:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

**Q: How do I ignore more directories?**

A: Add to `ds_builder_config.yaml`:
```yaml
ignoreDirs:
  - images/emoji
  - images/country
  - fonts
  - my_custom_ignore_dir
```

**Q: Can I commit generated files?**

A: Yes, it's recommended for consistency in version control.

## Next Steps

- Check [README.md](README.md) for full documentation
- Review [route_config.dart format](../lib/src/router_builder.dart) for advanced routing
- See [examples/](examples/) directory for sample projects

## Need Help?

- [GitHub Issues](https://github.com/yourusername/ds_builder/issues)
- [Pub.dev Documentation](https://pub.dev/packages/ds_builder)
