// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '包管理面板';

  @override
  String get appTagline => '一个管理各种包管理器的面板。';

  @override
  String get tabLocal => '本地';

  @override
  String get tabInstall => '安装';

  @override
  String get tabSettings => '设置';

  @override
  String get settingsTabGeneral => '常规';

  @override
  String get settingsTabManagers => '包管理器';

  @override
  String get settingsTabAppearance => '外观';

  @override
  String get settingsTabAbout => '关于';

  @override
  String get languageTitle => '语言';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeModeTitle => '主题模式';

  @override
  String get themeModeSystem => '系统';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色';

  @override
  String get autoCheckUpdatesTitle => '自动检查更新';

  @override
  String get autoCheckUpdatesSubtitle => '开启后，每次启动应用时都会检查 GitHub Release。';

  @override
  String get githubMirrorTitle => 'GitHub 镜像下载';

  @override
  String get githubMirrorSubtitle => '开启后，更新弹窗中的下载按钮会优先使用镜像。';

  @override
  String get githubMirrorBaseUrlLabel => '镜像地址';

  @override
  String get editGithubMirrorTitle => '设置 GitHub 镜像地址';

  @override
  String get githubMirrorHint => '例如 https://ghproxy.net/';

  @override
  String get githubMirrorUpdated => '镜像地址已更新。';

  @override
  String get fontStackTitle => '字体栈';

  @override
  String get fontStackDescription => '第一个字体是主字体，其余字体会按顺序作为 fallback。';

  @override
  String get fontPreview =>
      '字体预览：The quick brown fox jumps over the lazy dog. 敏捷的棕狐跳过了懒狗。';

  @override
  String get editFontStackTitle => '设置字体';

  @override
  String get commaSeparatedHint => '用英文逗号分隔。';

  @override
  String get fontStackInputHint => '例如 Cascadia Code, 汉仪有圆, Microsoft YaHei UI';

  @override
  String get buttonSetFont => '设置字体';

  @override
  String get buttonCancel => '取消';

  @override
  String get buttonSave => '保存';

  @override
  String get buttonRestoreDefault => '恢复默认';

  @override
  String get buttonClose => '关闭';

  @override
  String get buttonCopy => '复制';

  @override
  String get buttonRun => '执行';

  @override
  String get buttonInstall => '安装';

  @override
  String get buttonSearch => '搜索';

  @override
  String get buttonRefresh => '刷新';

  @override
  String get buttonRefreshStatus => '刷新状态';

  @override
  String get buttonAddGroup => '添加组';

  @override
  String get buttonEdit => '编辑';

  @override
  String get buttonOpenSettings => '打开设置';

  @override
  String get buttonCheckUpdates => '检查更新';

  @override
  String get buttonBatchUpdate => '批量更新';

  @override
  String get buttonGitHubRepo => 'GitHub 仓库';

  @override
  String get buttonOpenReleasePage => '打开 Release 页面';

  @override
  String get buttonDownload => '下载';

  @override
  String get buttonDownloadAndInstall => '下载并安装';

  @override
  String get buttonRemoveIcon => '移除图标';

  @override
  String get buttonResetDefaultIcon => '恢复默认图标';

  @override
  String get buttonSelectIcon => '选择图标';

  @override
  String get buttonChangeIcon => '更换图标';

  @override
  String get buttonDeleteGroup => '删除组';

  @override
  String get buttonConfirm => '确定';

  @override
  String get buttonInstallInputVersion => '安装输入版本';

  @override
  String get searchLocalHint => '搜索本地包';

  @override
  String get searchInstallHint => '搜索可安装的包';

  @override
  String get clearTooltip => '清空';

  @override
  String viewLoadErrorsButton(int count) {
    return '查看加载错误 ($count)';
  }

  @override
  String visiblePackageCount(int count) {
    return '当前 $count 个包';
  }

  @override
  String managerLoadFailedSuffix(String managerName) {
    return '$managerName (加载失败)';
  }

  @override
  String get packageListHeader => '包列表';

  @override
  String countLabel(int count) {
    return '$count 项';
  }

  @override
  String countSelectedLabel(int count, int selectedCount) {
    return '$count 项 · 已选 $selectedCount';
  }

  @override
  String get packageNameColumn => '包名';

  @override
  String get currentVersionColumn => '当前版本';

  @override
  String get latestVersionColumn => '最新版本';

  @override
  String get extraInfoColumn => '附加信息';

  @override
  String get versionColumn => '版本';

  @override
  String get sourceColumn => '来源';

  @override
  String get packageManagerColumn => '包管理器';

  @override
  String get searchResultsHeader => '搜索结果';

  @override
  String get viewDetailsAction => '查看详情';

  @override
  String get checkUpdatesAction => '检查更新';

  @override
  String get updateAction => '更新';

  @override
  String get upgradeAction => '升级';

  @override
  String get removeAction => '删除';

  @override
  String get installSpecificVersionAction => '安装特定版本';

  @override
  String get loadingDetails => '正在加载详情...';

  @override
  String get detailsUnavailable => '详情加载失败或没有返回内容。';

  @override
  String get confirmRunCommandTitle => '确认执行命令';

  @override
  String get confirmRunCommandBody => '将执行下面的命令：';

  @override
  String get copyToClipboardSuccess => '已复制到剪贴板。';

  @override
  String get noErrorOutput => '没有返回错误输出。';

  @override
  String get loadErrorsTitle => '加载错误详情';

  @override
  String get commandFailedTitle => '命令执行失败';

  @override
  String get noOutput => '没有输出内容。';

  @override
  String get batchPrerequisitePrompt => '批量检查更新前需要先安装依赖命令，是否现在安装？';

  @override
  String get batchPrerequisiteTitle => '需要先安装依赖';

  @override
  String get cancelRequested => '已发送取消请求。';

  @override
  String get commandCannotCancel => '当前命令无法取消。';

  @override
  String commandCancelled(String command) {
    return '已取消：$command';
  }

  @override
  String runningCommandsTitle(int count) {
    return '正在执行命令 ($count)';
  }

  @override
  String commandQueueTitle(int runningCount, int queuedCount) {
    return '命令队列 ($runningCount 运行中，$queuedCount 排队中)';
  }

  @override
  String get commandStatusQueued => '排队中';

  @override
  String get commandCancelTooltip => '取消此命令';

  @override
  String get commandCancelling => '正在取消...';

  @override
  String get commandNotCancelable => '不可取消';

  @override
  String get emptyLoadingManagers => '正在刷新包管理器...';

  @override
  String get emptyNoMatchingPackages => '没有匹配的包';

  @override
  String get emptyNoEnabledManagers => '暂未启用包管理器';

  @override
  String get emptyNoEnabledManagersDescription => '当前没有启用任何包管理器，请先到设置中选择要展示的项。';

  @override
  String emptyManagersLoadErrorDescription(int count) {
    return '有 $count 个包管理器加载失败，可以打开错误详情查看完整输出。';
  }

  @override
  String get emptyClickRefresh => '可以先点击“刷新”。';

  @override
  String emptyNoSearchResult(String query) {
    return '没有找到“$query”的结果。';
  }

  @override
  String get homeFilterGroupAll => '全部';

  @override
  String get homeFilterGroupUpdates => '更新';

  @override
  String get homeFilterSummaryAll => '显示全部本地包';

  @override
  String get homeFilterSummaryUpdates => '仅显示有更新的本地包';

  @override
  String homeFilterSummaryManagers(int count) {
    return '$count 个包管理器';
  }

  @override
  String homeFilterSummaryPackages(int count) {
    return '$count 个单包';
  }

  @override
  String get homeFilterSummaryUnconfigured => '未配置成员';

  @override
  String managerOriginalName(String name) {
    return '原名: $name';
  }

  @override
  String get managerCustomIconSet => '已设置自定义图标';

  @override
  String managerUpdatedMessage(String name, String parts) {
    return '$name 已更新$parts。';
  }

  @override
  String groupAddedMessage(String name) {
    return '$name 已添加。';
  }

  @override
  String groupDeletedMessage(String name) {
    return '$name 已删除。';
  }

  @override
  String groupUpdatedMessage(String name) {
    return '$name 已更新。';
  }

  @override
  String get settingsManagersDescription => '可以自定义主页筛选组；刷新后未安装的包管理器会被禁用';

  @override
  String get groupColumn => '筛选组';

  @override
  String get descriptionColumn => '说明';

  @override
  String get enabledColumn => '启用';

  @override
  String get statusColumn => '状态';

  @override
  String get customGroupType => '自定义组';

  @override
  String get builtinGroupType => '内置组';

  @override
  String get groupVisibleOnHome => '主页显示中';

  @override
  String get groupHiddenOnHome => '主页已隐藏';

  @override
  String get managerDetected => '已检测到';

  @override
  String get managerNotDetected => '未检测到';

  @override
  String get changedDisplayName => '显示名称';

  @override
  String get changedIcon => '图标';

  @override
  String get dialogAddGroupTitle => '添加筛选组';

  @override
  String dialogEditGroupTitle(String name) {
    return '编辑 $name';
  }

  @override
  String get groupNameLabel => '组名称';

  @override
  String get groupNameHint => '例如 开发工具 / CLI / 常用';

  @override
  String get iconLabel => '图标';

  @override
  String get iconNotSet => '未设置图标';

  @override
  String get defaultIconLabel => '使用默认图标';

  @override
  String get iconFormatsHint => '支持 svg、png、jpg、jpeg、webp、ico。';

  @override
  String get includedManagersLabel => '包含的包管理器';

  @override
  String get includedPackagesLabel => '包含的单个本地包';

  @override
  String get noLocalPackages => '暂无本地包';

  @override
  String get builtinAllGroupHint => '这是内置“全部”筛选组，会显示所有本地包。';

  @override
  String get builtinUpdatesGroupHint => '这是内置“更新”筛选组，会显示有更新的本地包。';

  @override
  String get displayNameLabel => '显示名称';

  @override
  String get displayNameHint => '输入新的显示名称';

  @override
  String editManagerTitle(String name) {
    return '编辑 $name';
  }

  @override
  String get saveInProgress => '保存中...';

  @override
  String get aboutTitle => '关于';

  @override
  String get versionLoading => '读取中...';

  @override
  String get checkingUpdates => '检查中...';

  @override
  String openLinkFailed(String url) {
    return '无法打开链接：$url';
  }

  @override
  String checkUpdatesFailed(String message) {
    return '检查更新失败：$message';
  }

  @override
  String alreadyLatestVersion(String version) {
    return '当前已是最新版本：$version';
  }

  @override
  String packageAlreadyLatest(String name) {
    return '$name 已经是最新版本。';
  }

  @override
  String packageNewVersionFound(String name, String version) {
    return '$name 有新版本：$version';
  }

  @override
  String packageCheckFailed(String name, String message) {
    return '检查 $name 失败：$message';
  }

  @override
  String packageCheckFailedFallback(String name) {
    return '检查 $name 失败，请查看活动日志。';
  }

  @override
  String get releaseAssetInstaller => '安装包';

  @override
  String get releaseAssetPortable => '绿色版';

  @override
  String get releaseAssetOther => '发行文件';

  @override
  String get unknownSize => '大小未知';

  @override
  String get downloadPreparing => '准备下载...';

  @override
  String downloadedBytes(String received) {
    return '已下载 $received';
  }

  @override
  String downloadedProgress(String received, String total, String percent) {
    return '已下载 $received / $total · $percent%';
  }

  @override
  String get autoCheckDisabled => '已关闭自动检查更新。';

  @override
  String disableAutoCheckFailed(String message) {
    return '关闭失败：$message';
  }

  @override
  String get installerStarted => '安装包已启动。';

  @override
  String get installerDownloadedNotStarted => '安装包已下载，但未能自动启动。';

  @override
  String get downloadedAndOpenedFolder => '已下载并打开所在目录。';

  @override
  String get downloadCompleted => '已下载完成。';

  @override
  String downloadFailed(String message) {
    return '下载失败：$message';
  }

  @override
  String get updateAvailableTitle => '发现新版本';

  @override
  String versionTransition(String current, String latest) {
    return '当前 $current  ->  最新 $latest';
  }

  @override
  String get releaseNotesTitle => '更新说明';

  @override
  String get releaseNotesEmpty => '该 Release 暂未提供更新说明。';

  @override
  String get releaseAssetsEmpty => '未读取到发行文件，可前往 Release 页面查看。';

  @override
  String get releaseAssetsTitle => '可用发行文件';

  @override
  String get processing => '处理中...';

  @override
  String get disableAutoCheckButton => '取消自动检查更新';

  @override
  String get installPageEmptyHint => '输入关键词后搜索可安装的包。';

  @override
  String get searching => '正在搜索...';

  @override
  String get allLabel => '全部';

  @override
  String packageAlreadyInstalled(String manager) {
    return '$manager · 已安装';
  }

  @override
  String installWithManager(String manager) {
    return '使用 $manager 安装';
  }

  @override
  String installSpecificVersionWithManager(String manager) {
    return '使用 $manager 安装特定版本';
  }

  @override
  String managerInstalling(String manager) {
    return '$manager 安装中';
  }

  @override
  String managerInstalled(String manager) {
    return '$manager 已安装';
  }

  @override
  String installDialogVersionSelected(String version) {
    return '当前将安装版本 $version。';
  }

  @override
  String get installDialogLatestSelected => '当前将显式安装 @latest。';

  @override
  String get installDialogDefaultSelected => '当前将执行默认安装命令。';

  @override
  String get installLatestTitle => '安装最新';

  @override
  String get installLatestSubtitle => '使用 @latest 形式安装';

  @override
  String get versionSearchHint => '输入版本号快速筛选，例如 1.2.3';

  @override
  String get pendingCommandLabel => '将要执行的命令';

  @override
  String loadVersionListFailed(String message) {
    return '读取版本列表失败：$message';
  }

  @override
  String get noAvailableVersionList => '当前命令没有返回可用版本列表。';

  @override
  String availableVersionListCount(int count) {
    return '共 $count 个可选版本';
  }

  @override
  String availableVersionListTruncated(int count, int max) {
    return '共 $count 个可选版本，仅显示最新 $max 个，请输入版本号缩小范围。';
  }

  @override
  String availableVersionListTruncatedFiltered(int count, int max) {
    return '匹配 $count 个版本，仅显示前 $max 个，请继续输入缩小范围。';
  }

  @override
  String get noDisplayableVersions => '没有可显示的版本。';

  @override
  String get noMatchedVersionsUseTypedValue => '没有匹配的版本，确定时会直接使用输入框里的版本号。';

  @override
  String get specificVersionDialogTitle => '安装特定版本';

  @override
  String get specificVersionDialogDescription => '选择一个可用版本，或直接输入版本号执行安装。';

  @override
  String get noMatchedVersionsCanInstallTyped => '没有匹配的版本，可以直接使用下方按钮安装输入值。';

  @override
  String currentVersionValue(String version) {
    return '当前 $version';
  }

  @override
  String latestVersionValue(String version) {
    return '最新 $version';
  }

  @override
  String versionValue(String version) {
    return '版本 $version';
  }

  @override
  String multiManagerCount(int count) {
    return '$count 个包管理器';
  }

  @override
  String identifierValue(String identifier) {
    return '标识: $identifier';
  }

  @override
  String installedManagersValue(String managers) {
    return '已安装: $managers';
  }

  @override
  String lastCheckedAtValue(String value) {
    return '上次检查 $value';
  }
}
