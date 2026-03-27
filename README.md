# Pkg Panel

一个面向 Windows 桌面端的 Flutter 包管理面板，用来集中查看和管理多种全局包管理器中的已安装包。

目前支持：`winget`、`choco`、`scoop`、`npm`、`pnpm`、`bun`、`pip`、`uv`、`cargo`。

## 功能

- 在一个界面里汇总不同包管理器的全局包列表
- 支持搜索、筛选、右键操作、批量更新
- 支持检查单个包或指定管理器下全部包的最新版本
- 首次启动时自动检测本机已存在的包管理器，并默认展示这些项
- 提供设置界面，允许手动控制哪些包管理器显示在首页
- 缓存最近一次检查到的最新版本信息，减少重复查询成本

## 适用平台

- 主要面向 Windows 桌面端
- 项目包含 `web/`、`linux/`、`macos/` 等 Flutter runner，但当前产品目标是 Windows-first
- 非 Windows 平台下命令执行能力不会正常工作

## 项目结构

- `lib/main.dart`：应用入口，初始化控制器与本地持久化
- `lib/src/app.dart`：主界面、筛选栏、列表、设置弹窗
- `lib/src/models/package_models.dart`：领域模型与视图状态模型
- `lib/src/services/package_panel_controller.dart`：核心状态管理与业务编排
- `lib/src/services/package_adapters.dart`：各包管理器适配器与输出解析逻辑
- `lib/src/services/shell_executor.dart`：统一命令执行入口
- `lib/src/services/package_latest_info_store.dart`：最新版本缓存持久化
- `lib/src/services/package_manager_settings_store.dart`：包管理器显示设置持久化
- `test/widget_test.dart`：基础界面与解析测试

## 本地开发

1. 安装 Flutter 3 和 Dart 3.11+
2. 在 Windows 环境准备你需要接入的包管理器
3. 拉取项目后执行：

```bash
flutter pub get
```

4. 启动桌面应用：

```bash
flutter run -d windows
```

如需快速查看界面，也可以运行：

```bash
flutter run -d chrome
```

但包管理器检测与命令执行逻辑以 Windows 桌面环境为准。

## 常用命令

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d windows
```

## 工作方式

### 1. 包管理器检测

应用首次初始化时，会检测各包管理器对应的可执行文件是否存在。

- 检测到：默认显示在首页，并参与刷新
- 未检测到：默认不显示，但用户仍可在设置中手动开启

检测结果和手动开关状态会写入本地配置，后续启动会优先使用用户设置。

### 2. 首页展示

首页只展示当前已启用的包管理器：

- 顶部筛选栏只显示已启用项
- 刷新时只加载已启用项
- 关闭某个管理器后，它会从首页筛选和包列表中移除

### 3. 设置界面

通过首页顶部的 `设置` 按钮进入设置面板，可以查看每个包管理器：

- 是否已被系统检测到
- 是否显示在首页
- 对应的用途说明

## 本地数据存储

应用会在本机用户目录下保存两类数据：

- `latest_versions.json`：最近一次检查到的最新版本缓存
- `manager_settings.json`：包管理器显示设置

默认位于：

```text
%LOCALAPPDATA%\pkg_panel\
```

如果 `LOCALAPPDATA` 不可用，则会回退到 `APPDATA`，再回退到系统临时目录。

## 测试建议

- 为解析逻辑补充针对真实命令输出的单元测试
- 为设置页、首次初始化检测、空状态等场景补充 widget test
- 测试中优先使用 fake `ShellExecutor`，避免直接调用真实包管理器

## 已知限制

- 当前仍以 Windows PowerShell 执行命令为核心路径
- 不同语言环境下的命令输出格式可能有差异，解析逻辑需要持续补强
- 部分包管理器的“最新版本查询”依赖外部命令，本身可能较慢或失败

## 后续可扩展方向

- 设置页支持全选、全不选、恢复默认检测结果
- 增加安装来源、更新时间、错误详情等更完整的信息面板
- 为不同包管理器增加更稳健的解析和批处理能力
