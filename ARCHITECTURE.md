# DS Builder - 架构与开发

## 项目结构

```
ds_builder/
├── lib/
│   ├── builder.dart                 # 主导出
│   └── src/
│       ├── router_builder.dart      # 路由代码生成器
│       └── assets_builder.dart      # 资源R文件生成器
├── README.md                        # 用户文档
├── GETTING_STARTED.md              # 快速入门指南
├── CHANGELOG.md                     # 版本历史
├── build.yaml                       # 构建器配置
├── pubspec.yaml                     # 包元数据
└── ...
```

## 工作原理

### 路由构建器

1. **输入**：`lib/route_config.dart` 包含路由定义
2. **处理**：使用正则表达式解析路由配置
3. **输出**：`lib/router.g.dart` 包含：
   - `RouteNames` 类包含静态常量
   - go_router 的路由配置
   - 自动嵌套路由处理

**主要功能**：
- 强制执行 Page 类命名（必须以 "Page" 结尾）
- 按组处理嵌套路由
- 生成类型安全的路由引用

### 资源构建器

1. **输入**：`assets/` 目录（递归扫描）
2. **处理**：
   - 递归列出所有文件
   - 根据配置中的 `ignoreDirs` 过滤文件
   - 将文件名转换为驼峰式 + 扩展名
3. **输出**：`lib/res/r.dart` 包含静态字符串常量

**主要功能**：
- 递归目录扫描
- 智能变量命名（避免重复）
- 可配置的忽略目录
- 从 `ds_builder_config.yaml` 读取自定义

## 配置文件

### `build.yaml`（构建器配置）

位于包根目录。告诉 build_runner 关于可用的构建器：

```yaml
builders:
  router:
    import: "package:ds_builder/builder.dart"
    builder_factories: ["routerBuilder"]
    build_extensions:
      "route_config.dart": ["../lib/router.g.dart"]
    auto_apply: dependents
    build_to: source

  assets:
    import: "package:ds_builder/builder.dart"
    builder_factories: ["assetsBuilder"]
    build_extensions:
      "$lib$": ["res/r.dart"]
    auto_apply: dependents
    build_to: source
    runs_before: [":router"]
```

### `ds_builder_config.yaml`（运行时配置）

由 `AssetsBuilder` 使用以自定义行为：

```yaml
ignoreDirs:
  - images/emoji
  - images/country
  - fonts
```

## 开发指南

### 添加新的构建器

1. 在 `lib/src/` 中创建新文件
2. 实现 `Builder` 接口：
   ```dart
   Builder myBuilder(BuilderOptions options) => MyBuilder();
   
   class MyBuilder implements Builder {
     @override
     Map<String, List<String>> get buildExtensions => { ... };
     
     @override
     Future<void> build(BuildStep buildStep) async { ... }
   }
   ```
3. 在 `lib/builder.dart` 中导出：
   ```dart
   export 'src/my_builder.dart';
   ```
4. 在 `build.yaml` 中注册：
   ```yaml
   builders:
     my_builder:
       import: "package:ds_builder/builder.dart"
       builder_factories: ["myBuilder"]
       ...
   ```

### 测试

运行 build_runner：

```bash
dart run build_runner build --delete-conflicting-outputs
```

检查生成的文件是否与预期输出匹配。

### 发布

1. 更新 `pubspec.yaml` 中的版本
2. 更新 `CHANGELOG.md`
3. 确保测试通过
4. 运行：
   ```bash
   dart pub publish
   ```

## 关键类

### `RouterBuilder`

**位置**：`lib/src/router_builder.dart`

**方法**：
- `_parseRouteConfig(String)` - 提取路由定义
- `_generateRouterCode(List<RouteEntry>)` - 创建输出代码
- `_toSnakeCase(String)` - 案例转换辅助
- `_toRouteName(String)` - 路由名生成

### `AssetsBuilder`

**位置**：`lib/src/assets_builder.dart`

**方法**：
- `_loadIgnoreDirs(String)` - 读取配置
- `_generateRFile(Directory, List<String>)` - 生成R类
- `_shouldIgnore(String, List<String>)` - 检查忽略列表
- `_generateVarName(String, Set<String>)` - 变量名生成

## 故障排查开发

**构建因解析错误失败**：
- 检查 `route_config.dart` 格式
- 验证 `_parseRouteConfig` 中的正则表达式

**资源未生成**：
- 检查 `assets/` 目录是否存在
- 验证 `ignoreDirs` 配置

**更改未反映**：
- 运行：`dart run build_runner clean`
- 然后：`dart run build_runner build --delete-conflicting-outputs`

## 未来增强

- [ ] 支持 i18n/l10n 文件生成
- [ ] 数据库迁移生成器
- [ ] API 客户端代码生成
- [ ] 表单验证生成器
- [ ] 自定义构建器的插件系统

## 贡献

1. Fork 仓库
2. 创建功能分支
3. 进行更改并添加测试
4. 提交带有描述的 PR
5. 处理审查反馈

## 许可证

MIT
