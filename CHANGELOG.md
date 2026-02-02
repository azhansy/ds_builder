## [1.1.0] - 2026-02-02

### 新功能

#### 灵活的自定义导入配置
- 添加了 `customImports` 配置选项，允许在 `ds_builder_config.yaml` 中指定自定义导入
- 生成器现在自动检测项目的包名，无需硬编码
- 支持多项目部署 - 相同的 builder 可以用于任何 Flutter 项目

#### 动态包名检测
- 移除所有硬编码的 `package:ugos` 引用
- RouterBuilder 现在使用 `buildStep.inputId.package` 动态获取项目包名
- 生成的文件（router.g.dart、controllers、pages）都使用正确的项目包名

### 改进
- 修复了自定义导入的硬编码问题（`package:ugos/widgets/home_screen.dart` 等）
- 改进了对多个项目的支持
- 代码生成更加通用和可复用

### 修复
- 修正了控制器和页面生成中的包名引用

## [1.0.0] - 2026-02-02

### 初始版本

#### 新增功能
- **路由构建器**：从 `route_config.dart` 生成路由配置
  - 自动生成带有 GoRouter 设置的 `router.g.dart`
  - 创建 `RouteNames` 类以供类型安全的路由引用
  - 支持参数化和非参数化路由
  - 强制执行 Page 类命名约定

- **资源构建器**：从资源目录自动生成 R.dart 文件
  - 递归扫描资源
  - 为所有资源生成类型安全的常量
  - 将文件名转换为驼峰式变量名
  - 智能处理重复名称

- **配置系统**
  - `ds_builder_config.yaml` 用于自定义
  - 可配置的资源忽略目录
  - 快速设置的合理默认值
  - 每个构建器的配置支持

#### 特性
- 带有默认值的零配置模式
- 无缝 build_runner 集成
- 增量构建支持
- 清晰的错误消息和日志记录
- 基于 YAML 的配置

### 已知限制
- 路由必须在 `lib/route_config.dart` 中定义
- 资源目录必须在 `assets/`
- 生成的 R.dart 总是输出到 `lib/res/r.dart`

### 依赖项
- `build: ^2.4.0`
- `path: ^1.9.0`
- `yaml: ^3.1.2`
