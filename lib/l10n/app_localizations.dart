import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'包管理面板'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In zh, this message translates to:
  /// **'一个管理各种包管理器的面板。'**
  String get appTagline;

  /// No description provided for @tabLocal.
  ///
  /// In zh, this message translates to:
  /// **'本地'**
  String get tabLocal;

  /// No description provided for @tabInstall.
  ///
  /// In zh, this message translates to:
  /// **'安装'**
  String get tabInstall;

  /// No description provided for @tabSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get tabSettings;

  /// No description provided for @settingsTabGeneral.
  ///
  /// In zh, this message translates to:
  /// **'常规'**
  String get settingsTabGeneral;

  /// No description provided for @settingsTabManagers.
  ///
  /// In zh, this message translates to:
  /// **'包管理器'**
  String get settingsTabManagers;

  /// No description provided for @settingsTabAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsTabAppearance;

  /// No description provided for @settingsTabAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsTabAbout;

  /// No description provided for @languageTitle.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get languageTitle;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @themeModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get themeModeTitle;

  /// No description provided for @themeModeSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeModeDark;

  /// No description provided for @autoCheckUpdatesTitle.
  ///
  /// In zh, this message translates to:
  /// **'自动检查更新'**
  String get autoCheckUpdatesTitle;

  /// No description provided for @autoCheckUpdatesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后，每次启动应用时都会检查 GitHub Release。'**
  String get autoCheckUpdatesSubtitle;

  /// No description provided for @githubMirrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 镜像下载'**
  String get githubMirrorTitle;

  /// No description provided for @githubMirrorSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'开启后，更新弹窗中的下载按钮会优先使用镜像。'**
  String get githubMirrorSubtitle;

  /// No description provided for @githubMirrorBaseUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'镜像地址'**
  String get githubMirrorBaseUrlLabel;

  /// No description provided for @editGithubMirrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置 GitHub 镜像地址'**
  String get editGithubMirrorTitle;

  /// No description provided for @githubMirrorHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 https://ghproxy.net/'**
  String get githubMirrorHint;

  /// No description provided for @githubMirrorUpdated.
  ///
  /// In zh, this message translates to:
  /// **'镜像地址已更新。'**
  String get githubMirrorUpdated;

  /// No description provided for @fontStackTitle.
  ///
  /// In zh, this message translates to:
  /// **'字体栈'**
  String get fontStackTitle;

  /// No description provided for @fontStackDescription.
  ///
  /// In zh, this message translates to:
  /// **'第一个字体是主字体，其余字体会按顺序作为 fallback。'**
  String get fontStackDescription;

  /// No description provided for @fontPreview.
  ///
  /// In zh, this message translates to:
  /// **'字体预览：The quick brown fox jumps over the lazy dog. 敏捷的棕狐跳过了懒狗。'**
  String get fontPreview;

  /// No description provided for @editFontStackTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置字体'**
  String get editFontStackTitle;

  /// No description provided for @commaSeparatedHint.
  ///
  /// In zh, this message translates to:
  /// **'用英文逗号分隔。'**
  String get commaSeparatedHint;

  /// No description provided for @fontStackInputHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 Cascadia Code, 汉仪有圆, Microsoft YaHei UI'**
  String get fontStackInputHint;

  /// No description provided for @buttonSetFont.
  ///
  /// In zh, this message translates to:
  /// **'设置字体'**
  String get buttonSetFont;

  /// No description provided for @buttonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get buttonCancel;

  /// No description provided for @buttonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get buttonSave;

  /// No description provided for @buttonRestoreDefault.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get buttonRestoreDefault;

  /// No description provided for @buttonClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get buttonClose;

  /// No description provided for @buttonCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get buttonCopy;

  /// No description provided for @buttonRun.
  ///
  /// In zh, this message translates to:
  /// **'执行'**
  String get buttonRun;

  /// No description provided for @buttonInstall.
  ///
  /// In zh, this message translates to:
  /// **'安装'**
  String get buttonInstall;

  /// No description provided for @buttonSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get buttonSearch;

  /// No description provided for @buttonRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get buttonRefresh;

  /// No description provided for @buttonRefreshStatus.
  ///
  /// In zh, this message translates to:
  /// **'刷新状态'**
  String get buttonRefreshStatus;

  /// No description provided for @buttonAddGroup.
  ///
  /// In zh, this message translates to:
  /// **'添加组'**
  String get buttonAddGroup;

  /// No description provided for @buttonEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get buttonEdit;

  /// No description provided for @buttonOpenSettings.
  ///
  /// In zh, this message translates to:
  /// **'打开设置'**
  String get buttonOpenSettings;

  /// No description provided for @buttonCheckUpdates.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get buttonCheckUpdates;

  /// No description provided for @buttonBatchUpdate.
  ///
  /// In zh, this message translates to:
  /// **'批量更新'**
  String get buttonBatchUpdate;

  /// No description provided for @buttonGitHubRepo.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 仓库'**
  String get buttonGitHubRepo;

  /// No description provided for @buttonOpenReleasePage.
  ///
  /// In zh, this message translates to:
  /// **'打开 Release 页面'**
  String get buttonOpenReleasePage;

  /// No description provided for @buttonDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get buttonDownload;

  /// No description provided for @buttonDownloadAndInstall.
  ///
  /// In zh, this message translates to:
  /// **'下载并安装'**
  String get buttonDownloadAndInstall;

  /// No description provided for @buttonRemoveIcon.
  ///
  /// In zh, this message translates to:
  /// **'移除图标'**
  String get buttonRemoveIcon;

  /// No description provided for @buttonResetDefaultIcon.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认图标'**
  String get buttonResetDefaultIcon;

  /// No description provided for @buttonSelectIcon.
  ///
  /// In zh, this message translates to:
  /// **'选择图标'**
  String get buttonSelectIcon;

  /// No description provided for @buttonChangeIcon.
  ///
  /// In zh, this message translates to:
  /// **'更换图标'**
  String get buttonChangeIcon;

  /// No description provided for @buttonDeleteGroup.
  ///
  /// In zh, this message translates to:
  /// **'删除组'**
  String get buttonDeleteGroup;

  /// No description provided for @buttonConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get buttonConfirm;

  /// No description provided for @buttonInstallInputVersion.
  ///
  /// In zh, this message translates to:
  /// **'安装输入版本'**
  String get buttonInstallInputVersion;

  /// No description provided for @searchLocalHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索本地包'**
  String get searchLocalHint;

  /// No description provided for @searchInstallHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索可安装的包'**
  String get searchInstallHint;

  /// No description provided for @clearTooltip.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clearTooltip;

  /// No description provided for @viewLoadErrorsButton.
  ///
  /// In zh, this message translates to:
  /// **'查看加载错误 ({count})'**
  String viewLoadErrorsButton(int count);

  /// No description provided for @visiblePackageCount.
  ///
  /// In zh, this message translates to:
  /// **'当前 {count} 个包'**
  String visiblePackageCount(int count);

  /// No description provided for @managerLoadFailedSuffix.
  ///
  /// In zh, this message translates to:
  /// **'{managerName} (加载失败)'**
  String managerLoadFailedSuffix(String managerName);

  /// No description provided for @packageListHeader.
  ///
  /// In zh, this message translates to:
  /// **'包列表'**
  String get packageListHeader;

  /// No description provided for @countLabel.
  ///
  /// In zh, this message translates to:
  /// **'{count} 项'**
  String countLabel(int count);

  /// No description provided for @countSelectedLabel.
  ///
  /// In zh, this message translates to:
  /// **'{count} 项 · 已选 {selectedCount}'**
  String countSelectedLabel(int count, int selectedCount);

  /// No description provided for @packageNameColumn.
  ///
  /// In zh, this message translates to:
  /// **'包名'**
  String get packageNameColumn;

  /// No description provided for @currentVersionColumn.
  ///
  /// In zh, this message translates to:
  /// **'当前版本'**
  String get currentVersionColumn;

  /// No description provided for @latestVersionColumn.
  ///
  /// In zh, this message translates to:
  /// **'最新版本'**
  String get latestVersionColumn;

  /// No description provided for @extraInfoColumn.
  ///
  /// In zh, this message translates to:
  /// **'附加信息'**
  String get extraInfoColumn;

  /// No description provided for @versionColumn.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get versionColumn;

  /// No description provided for @sourceColumn.
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get sourceColumn;

  /// No description provided for @packageManagerColumn.
  ///
  /// In zh, this message translates to:
  /// **'包管理器'**
  String get packageManagerColumn;

  /// No description provided for @searchResultsHeader.
  ///
  /// In zh, this message translates to:
  /// **'搜索结果'**
  String get searchResultsHeader;

  /// No description provided for @viewDetailsAction.
  ///
  /// In zh, this message translates to:
  /// **'查看详情'**
  String get viewDetailsAction;

  /// No description provided for @checkUpdatesAction.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkUpdatesAction;

  /// No description provided for @updateAction.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get updateAction;

  /// No description provided for @upgradeAction.
  ///
  /// In zh, this message translates to:
  /// **'升级'**
  String get upgradeAction;

  /// No description provided for @removeAction.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get removeAction;

  /// No description provided for @installSpecificVersionAction.
  ///
  /// In zh, this message translates to:
  /// **'安装特定版本'**
  String get installSpecificVersionAction;

  /// No description provided for @loadingDetails.
  ///
  /// In zh, this message translates to:
  /// **'正在加载详情...'**
  String get loadingDetails;

  /// No description provided for @detailsUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'详情加载失败或没有返回内容。'**
  String get detailsUnavailable;

  /// No description provided for @confirmRunCommandTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认执行命令'**
  String get confirmRunCommandTitle;

  /// No description provided for @confirmRunCommandBody.
  ///
  /// In zh, this message translates to:
  /// **'将执行下面的命令：'**
  String get confirmRunCommandBody;

  /// No description provided for @copyToClipboardSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板。'**
  String get copyToClipboardSuccess;

  /// No description provided for @noErrorOutput.
  ///
  /// In zh, this message translates to:
  /// **'没有返回错误输出。'**
  String get noErrorOutput;

  /// No description provided for @loadErrorsTitle.
  ///
  /// In zh, this message translates to:
  /// **'加载错误详情'**
  String get loadErrorsTitle;

  /// No description provided for @commandFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'命令执行失败'**
  String get commandFailedTitle;

  /// No description provided for @noOutput.
  ///
  /// In zh, this message translates to:
  /// **'没有输出内容。'**
  String get noOutput;

  /// No description provided for @batchPrerequisitePrompt.
  ///
  /// In zh, this message translates to:
  /// **'批量检查更新前需要先安装依赖命令，是否现在安装？'**
  String get batchPrerequisitePrompt;

  /// No description provided for @batchPrerequisiteTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要先安装依赖'**
  String get batchPrerequisiteTitle;

  /// No description provided for @cancelRequested.
  ///
  /// In zh, this message translates to:
  /// **'已发送取消请求。'**
  String get cancelRequested;

  /// No description provided for @commandCannotCancel.
  ///
  /// In zh, this message translates to:
  /// **'当前命令无法取消。'**
  String get commandCannotCancel;

  /// No description provided for @commandCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消：{command}'**
  String commandCancelled(String command);

  /// No description provided for @runningCommandsTitle.
  ///
  /// In zh, this message translates to:
  /// **'正在执行命令 ({count})'**
  String runningCommandsTitle(int count);

  /// No description provided for @commandQueueTitle.
  ///
  /// In zh, this message translates to:
  /// **'命令队列 ({runningCount} 运行中，{queuedCount} 排队中)'**
  String commandQueueTitle(int runningCount, int queuedCount);

  /// No description provided for @commandStatusQueued.
  ///
  /// In zh, this message translates to:
  /// **'排队中'**
  String get commandStatusQueued;

  /// No description provided for @commandCancelTooltip.
  ///
  /// In zh, this message translates to:
  /// **'取消此命令'**
  String get commandCancelTooltip;

  /// No description provided for @commandCancelling.
  ///
  /// In zh, this message translates to:
  /// **'正在取消...'**
  String get commandCancelling;

  /// No description provided for @commandNotCancelable.
  ///
  /// In zh, this message translates to:
  /// **'不可取消'**
  String get commandNotCancelable;

  /// No description provided for @emptyLoadingManagers.
  ///
  /// In zh, this message translates to:
  /// **'正在刷新包管理器...'**
  String get emptyLoadingManagers;

  /// No description provided for @emptyNoMatchingPackages.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的包'**
  String get emptyNoMatchingPackages;

  /// No description provided for @emptyNoEnabledManagers.
  ///
  /// In zh, this message translates to:
  /// **'暂未启用包管理器'**
  String get emptyNoEnabledManagers;

  /// No description provided for @emptyNoEnabledManagersDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前没有启用任何包管理器，请先到设置中选择要展示的项。'**
  String get emptyNoEnabledManagersDescription;

  /// No description provided for @emptyManagersLoadErrorDescription.
  ///
  /// In zh, this message translates to:
  /// **'有 {count} 个包管理器加载失败，可以打开错误详情查看完整输出。'**
  String emptyManagersLoadErrorDescription(int count);

  /// No description provided for @emptyClickRefresh.
  ///
  /// In zh, this message translates to:
  /// **'可以先点击“刷新”。'**
  String get emptyClickRefresh;

  /// No description provided for @emptyNoSearchResult.
  ///
  /// In zh, this message translates to:
  /// **'没有找到“{query}”的结果。'**
  String emptyNoSearchResult(String query);

  /// No description provided for @homeFilterGroupAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get homeFilterGroupAll;

  /// No description provided for @homeFilterGroupUpdates.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get homeFilterGroupUpdates;

  /// No description provided for @homeFilterSummaryAll.
  ///
  /// In zh, this message translates to:
  /// **'显示全部本地包'**
  String get homeFilterSummaryAll;

  /// No description provided for @homeFilterSummaryUpdates.
  ///
  /// In zh, this message translates to:
  /// **'仅显示有更新的本地包'**
  String get homeFilterSummaryUpdates;

  /// No description provided for @homeFilterSummaryManagers.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个包管理器'**
  String homeFilterSummaryManagers(int count);

  /// No description provided for @homeFilterSummaryPackages.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个单包'**
  String homeFilterSummaryPackages(int count);

  /// No description provided for @homeFilterSummaryUnconfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置成员'**
  String get homeFilterSummaryUnconfigured;

  /// No description provided for @managerOriginalName.
  ///
  /// In zh, this message translates to:
  /// **'原名: {name}'**
  String managerOriginalName(String name);

  /// No description provided for @managerCustomIconSet.
  ///
  /// In zh, this message translates to:
  /// **'已设置自定义图标'**
  String get managerCustomIconSet;

  /// No description provided for @managerUpdatedMessage.
  ///
  /// In zh, this message translates to:
  /// **'{name} 已更新{parts}。'**
  String managerUpdatedMessage(String name, String parts);

  /// No description provided for @groupAddedMessage.
  ///
  /// In zh, this message translates to:
  /// **'{name} 已添加。'**
  String groupAddedMessage(String name);

  /// No description provided for @groupDeletedMessage.
  ///
  /// In zh, this message translates to:
  /// **'{name} 已删除。'**
  String groupDeletedMessage(String name);

  /// No description provided for @groupUpdatedMessage.
  ///
  /// In zh, this message translates to:
  /// **'{name} 已更新。'**
  String groupUpdatedMessage(String name);

  /// No description provided for @settingsManagersDescription.
  ///
  /// In zh, this message translates to:
  /// **'可以自定义主页筛选组；刷新后未安装的包管理器会被禁用'**
  String get settingsManagersDescription;

  /// No description provided for @groupColumn.
  ///
  /// In zh, this message translates to:
  /// **'筛选组'**
  String get groupColumn;

  /// No description provided for @descriptionColumn.
  ///
  /// In zh, this message translates to:
  /// **'说明'**
  String get descriptionColumn;

  /// No description provided for @enabledColumn.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get enabledColumn;

  /// No description provided for @statusColumn.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get statusColumn;

  /// No description provided for @customGroupType.
  ///
  /// In zh, this message translates to:
  /// **'自定义组'**
  String get customGroupType;

  /// No description provided for @builtinGroupType.
  ///
  /// In zh, this message translates to:
  /// **'内置组'**
  String get builtinGroupType;

  /// No description provided for @groupVisibleOnHome.
  ///
  /// In zh, this message translates to:
  /// **'主页显示中'**
  String get groupVisibleOnHome;

  /// No description provided for @groupHiddenOnHome.
  ///
  /// In zh, this message translates to:
  /// **'主页已隐藏'**
  String get groupHiddenOnHome;

  /// No description provided for @managerDetected.
  ///
  /// In zh, this message translates to:
  /// **'已检测到'**
  String get managerDetected;

  /// No description provided for @managerNotDetected.
  ///
  /// In zh, this message translates to:
  /// **'未检测到'**
  String get managerNotDetected;

  /// No description provided for @changedDisplayName.
  ///
  /// In zh, this message translates to:
  /// **'显示名称'**
  String get changedDisplayName;

  /// No description provided for @changedIcon.
  ///
  /// In zh, this message translates to:
  /// **'图标'**
  String get changedIcon;

  /// No description provided for @dialogAddGroupTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加筛选组'**
  String get dialogAddGroupTitle;

  /// No description provided for @dialogEditGroupTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑 {name}'**
  String dialogEditGroupTitle(String name);

  /// No description provided for @groupNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'组名称'**
  String get groupNameLabel;

  /// No description provided for @groupNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 开发工具 / CLI / 常用'**
  String get groupNameHint;

  /// No description provided for @iconLabel.
  ///
  /// In zh, this message translates to:
  /// **'图标'**
  String get iconLabel;

  /// No description provided for @iconNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置图标'**
  String get iconNotSet;

  /// No description provided for @defaultIconLabel.
  ///
  /// In zh, this message translates to:
  /// **'使用默认图标'**
  String get defaultIconLabel;

  /// No description provided for @iconFormatsHint.
  ///
  /// In zh, this message translates to:
  /// **'支持 svg、png、jpg、jpeg、webp、ico。'**
  String get iconFormatsHint;

  /// No description provided for @includedManagersLabel.
  ///
  /// In zh, this message translates to:
  /// **'包含的包管理器'**
  String get includedManagersLabel;

  /// No description provided for @includedPackagesLabel.
  ///
  /// In zh, this message translates to:
  /// **'包含的单个本地包'**
  String get includedPackagesLabel;

  /// No description provided for @noLocalPackages.
  ///
  /// In zh, this message translates to:
  /// **'暂无本地包'**
  String get noLocalPackages;

  /// No description provided for @builtinAllGroupHint.
  ///
  /// In zh, this message translates to:
  /// **'这是内置“全部”筛选组，会显示所有本地包。'**
  String get builtinAllGroupHint;

  /// No description provided for @builtinUpdatesGroupHint.
  ///
  /// In zh, this message translates to:
  /// **'这是内置“更新”筛选组，会显示有更新的本地包。'**
  String get builtinUpdatesGroupHint;

  /// No description provided for @displayNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'显示名称'**
  String get displayNameLabel;

  /// No description provided for @displayNameHint.
  ///
  /// In zh, this message translates to:
  /// **'输入新的显示名称'**
  String get displayNameHint;

  /// No description provided for @editManagerTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑 {name}'**
  String editManagerTitle(String name);

  /// No description provided for @saveInProgress.
  ///
  /// In zh, this message translates to:
  /// **'保存中...'**
  String get saveInProgress;

  /// No description provided for @aboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutTitle;

  /// No description provided for @versionLoading.
  ///
  /// In zh, this message translates to:
  /// **'读取中...'**
  String get versionLoading;

  /// No description provided for @checkingUpdates.
  ///
  /// In zh, this message translates to:
  /// **'检查中...'**
  String get checkingUpdates;

  /// No description provided for @openLinkFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接：{url}'**
  String openLinkFailed(String url);

  /// No description provided for @checkUpdatesFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败：{message}'**
  String checkUpdatesFailed(String message);

  /// No description provided for @alreadyLatestVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前已是最新版本：{version}'**
  String alreadyLatestVersion(String version);

  /// No description provided for @packageAlreadyLatest.
  ///
  /// In zh, this message translates to:
  /// **'{name} 已经是最新版本。'**
  String packageAlreadyLatest(String name);

  /// No description provided for @packageNewVersionFound.
  ///
  /// In zh, this message translates to:
  /// **'{name} 有新版本：{version}'**
  String packageNewVersionFound(String name, String version);

  /// No description provided for @packageCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查 {name} 失败：{message}'**
  String packageCheckFailed(String name, String message);

  /// No description provided for @packageCheckFailedFallback.
  ///
  /// In zh, this message translates to:
  /// **'检查 {name} 失败，请查看活动日志。'**
  String packageCheckFailedFallback(String name);

  /// No description provided for @releaseAssetInstaller.
  ///
  /// In zh, this message translates to:
  /// **'安装包'**
  String get releaseAssetInstaller;

  /// No description provided for @releaseAssetPortable.
  ///
  /// In zh, this message translates to:
  /// **'绿色版'**
  String get releaseAssetPortable;

  /// No description provided for @releaseAssetOther.
  ///
  /// In zh, this message translates to:
  /// **'发行文件'**
  String get releaseAssetOther;

  /// No description provided for @unknownSize.
  ///
  /// In zh, this message translates to:
  /// **'大小未知'**
  String get unknownSize;

  /// No description provided for @downloadPreparing.
  ///
  /// In zh, this message translates to:
  /// **'准备下载...'**
  String get downloadPreparing;

  /// No description provided for @downloadedBytes.
  ///
  /// In zh, this message translates to:
  /// **'已下载 {received}'**
  String downloadedBytes(String received);

  /// No description provided for @downloadedProgress.
  ///
  /// In zh, this message translates to:
  /// **'已下载 {received} / {total} · {percent}%'**
  String downloadedProgress(String received, String total, String percent);

  /// No description provided for @autoCheckDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭自动检查更新。'**
  String get autoCheckDisabled;

  /// No description provided for @disableAutoCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'关闭失败：{message}'**
  String disableAutoCheckFailed(String message);

  /// No description provided for @installerStarted.
  ///
  /// In zh, this message translates to:
  /// **'安装包已启动。'**
  String get installerStarted;

  /// No description provided for @installerDownloadedNotStarted.
  ///
  /// In zh, this message translates to:
  /// **'安装包已下载，但未能自动启动。'**
  String get installerDownloadedNotStarted;

  /// No description provided for @downloadedAndOpenedFolder.
  ///
  /// In zh, this message translates to:
  /// **'已下载并打开所在目录。'**
  String get downloadedAndOpenedFolder;

  /// No description provided for @downloadCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已下载完成。'**
  String get downloadCompleted;

  /// No description provided for @downloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载失败：{message}'**
  String downloadFailed(String message);

  /// No description provided for @updateAvailableTitle.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get updateAvailableTitle;

  /// No description provided for @versionTransition.
  ///
  /// In zh, this message translates to:
  /// **'当前 {current}  ->  最新 {latest}'**
  String versionTransition(String current, String latest);

  /// No description provided for @releaseNotesTitle.
  ///
  /// In zh, this message translates to:
  /// **'更新说明'**
  String get releaseNotesTitle;

  /// No description provided for @releaseNotesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'该 Release 暂未提供更新说明。'**
  String get releaseNotesEmpty;

  /// No description provided for @releaseAssetsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'未读取到发行文件，可前往 Release 页面查看。'**
  String get releaseAssetsEmpty;

  /// No description provided for @releaseAssetsTitle.
  ///
  /// In zh, this message translates to:
  /// **'可用发行文件'**
  String get releaseAssetsTitle;

  /// No description provided for @processing.
  ///
  /// In zh, this message translates to:
  /// **'处理中...'**
  String get processing;

  /// No description provided for @disableAutoCheckButton.
  ///
  /// In zh, this message translates to:
  /// **'取消自动检查更新'**
  String get disableAutoCheckButton;

  /// No description provided for @installPageEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词后搜索可安装的包。'**
  String get installPageEmptyHint;

  /// No description provided for @searching.
  ///
  /// In zh, this message translates to:
  /// **'正在搜索...'**
  String get searching;

  /// No description provided for @allLabel.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get allLabel;

  /// No description provided for @packageAlreadyInstalled.
  ///
  /// In zh, this message translates to:
  /// **'{manager} · 已安装'**
  String packageAlreadyInstalled(String manager);

  /// No description provided for @installWithManager.
  ///
  /// In zh, this message translates to:
  /// **'使用 {manager} 安装'**
  String installWithManager(String manager);

  /// No description provided for @installSpecificVersionWithManager.
  ///
  /// In zh, this message translates to:
  /// **'使用 {manager} 安装特定版本'**
  String installSpecificVersionWithManager(String manager);

  /// No description provided for @managerInstalling.
  ///
  /// In zh, this message translates to:
  /// **'{manager} 安装中'**
  String managerInstalling(String manager);

  /// No description provided for @managerInstalled.
  ///
  /// In zh, this message translates to:
  /// **'{manager} 已安装'**
  String managerInstalled(String manager);

  /// No description provided for @installDialogVersionSelected.
  ///
  /// In zh, this message translates to:
  /// **'当前将安装版本 {version}。'**
  String installDialogVersionSelected(String version);

  /// No description provided for @installDialogLatestSelected.
  ///
  /// In zh, this message translates to:
  /// **'当前将显式安装 @latest。'**
  String get installDialogLatestSelected;

  /// No description provided for @installDialogDefaultSelected.
  ///
  /// In zh, this message translates to:
  /// **'当前将执行默认安装命令。'**
  String get installDialogDefaultSelected;

  /// No description provided for @installLatestTitle.
  ///
  /// In zh, this message translates to:
  /// **'安装最新'**
  String get installLatestTitle;

  /// No description provided for @installLatestSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'使用 @latest 形式安装'**
  String get installLatestSubtitle;

  /// No description provided for @versionSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'输入版本号快速筛选，例如 1.2.3'**
  String get versionSearchHint;

  /// No description provided for @pendingCommandLabel.
  ///
  /// In zh, this message translates to:
  /// **'将要执行的命令'**
  String get pendingCommandLabel;

  /// No description provided for @loadVersionListFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取版本列表失败：{message}'**
  String loadVersionListFailed(String message);

  /// No description provided for @noAvailableVersionList.
  ///
  /// In zh, this message translates to:
  /// **'当前命令没有返回可用版本列表。'**
  String get noAvailableVersionList;

  /// No description provided for @availableVersionListCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 个可选版本'**
  String availableVersionListCount(int count);

  /// No description provided for @availableVersionListTruncated.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 个可选版本，仅显示最新 {max} 个，请输入版本号缩小范围。'**
  String availableVersionListTruncated(int count, int max);

  /// No description provided for @availableVersionListTruncatedFiltered.
  ///
  /// In zh, this message translates to:
  /// **'匹配 {count} 个版本，仅显示前 {max} 个，请继续输入缩小范围。'**
  String availableVersionListTruncatedFiltered(int count, int max);

  /// No description provided for @noDisplayableVersions.
  ///
  /// In zh, this message translates to:
  /// **'没有可显示的版本。'**
  String get noDisplayableVersions;

  /// No description provided for @noMatchedVersionsUseTypedValue.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的版本，确定时会直接使用输入框里的版本号。'**
  String get noMatchedVersionsUseTypedValue;

  /// No description provided for @specificVersionDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'安装特定版本'**
  String get specificVersionDialogTitle;

  /// No description provided for @specificVersionDialogDescription.
  ///
  /// In zh, this message translates to:
  /// **'选择一个可用版本，或直接输入版本号执行安装。'**
  String get specificVersionDialogDescription;

  /// No description provided for @noMatchedVersionsCanInstallTyped.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的版本，可以直接使用下方按钮安装输入值。'**
  String get noMatchedVersionsCanInstallTyped;

  /// No description provided for @currentVersionValue.
  ///
  /// In zh, this message translates to:
  /// **'当前 {version}'**
  String currentVersionValue(String version);

  /// No description provided for @latestVersionValue.
  ///
  /// In zh, this message translates to:
  /// **'最新 {version}'**
  String latestVersionValue(String version);

  /// No description provided for @versionValue.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version}'**
  String versionValue(String version);

  /// No description provided for @multiManagerCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个包管理器'**
  String multiManagerCount(int count);

  /// No description provided for @identifierValue.
  ///
  /// In zh, this message translates to:
  /// **'标识: {identifier}'**
  String identifierValue(String identifier);

  /// No description provided for @installedManagersValue.
  ///
  /// In zh, this message translates to:
  /// **'已安装: {managers}'**
  String installedManagersValue(String managers);

  /// No description provided for @lastCheckedAtValue.
  ///
  /// In zh, this message translates to:
  /// **'上次检查 {value}'**
  String lastCheckedAtValue(String value);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
