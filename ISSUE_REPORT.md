# 「妙笔小说」APP 问题汇总报告

> 分析日期: 2026-06-27
> 分析方式: 完整源代码审计 + 运行时实测 (PAD 2560x1600)

---

## 一、总览

| 模块 | 基本可用 | 存在缺陷 | 完全不可用 |
|------|:--:|:--:|:--:|
| 创作向导（6步） | ✅ | ⚠️ 步骤5按钮需要滚动才能看到 | - |
| 大纲系统 | ✅ | ⚠️ 手机端布局问题 | - |
| 章节写作 | ⚠️ | 🔴 AI生成结果未保存到文件 | - |
| 世界观库 | ✅ | - | - |
| 角色库 | ⚠️ | 🔴 模板解析失败导致空库 | - |
| 伏笔库 | ✅ | - | - |
| 写作记忆 | ✅ | - | - |
| AI续写 | - | 🔴 仅弹SnackBar提示 | 🔴 |
| AI润色 | - | 🔴 仅弹SnackBar提示 | 🔴 |
| 灵感建议 | - | 🔴 仅弹SnackBar提示 | 🔴 |
| 错字矫正 | ✅ | ⚠️ | - |
| 大模型设置 | ✅ | ⚠️ 配置路径问题 | - |
| 导出功能 | - | - | 🔴 完全不存在 |
| PAD自适应 | ✅ | ⚠️ | - |
| 手机端布局 | ⚠️ | 🔴 多个页面手机端严重降级 | - |
| 深色模式 | ✅ | - | - |
| AI面板信息显示 | - | 🔴 显示"-"不更新 | 🔴 |
| WebDAV同步 | ⚠️ | - | - |

---

## 二、严重问题 🔴

### 🔴 #1: AI面板三大功能仅有UI壳，无实际功能
**位置**: `lib/presentation/pages/home_page.dart` 第276-310行
**现象**: AI续写、AI润色、灵感建议三个按钮点击后只弹出SnackBar提示，无任何实际AI调用：
```dart
// AI续写: 跳到世界书页 + SnackBar
// AI润色: 跳到章节写作 + SnackBar("请在章节写作页选中文本后使用润色功能")
// 灵感建议: 跳到世界书 + SnackBar("灵感建议将在后续版本中接入AI")
```
**影响**: PAD大屏右侧AI面板的核心功能完全不可用，仅是占位UI。

### 🔴 #2: AI面板「当前小说」信息永远显示"-"
**位置**: `lib/presentation/pages/home_page.dart` 第312-317行
**现象**: 频道、类型、总章节三个字段硬编码为"-"和"0"，选择小说后不更新：
```dart
_infoRow('频道', '-'),
_infoRow('类型', '-'),
_infoRow('总章节', '0'),
```
**影响**: 用户在PAD布局下看不到任何小说元信息。

### 🔴 #3: 角色模板解析失败，角色库为空
**位置**: `lib/domain/services/novel_creation_service.dart` 第97-138行
**分析**: `_initCharacters` 方法用 `### ` 前缀解析角色模板，但实际模板数据中的角色格式可能不匹配。运行时测试显示创建小说后角色库页面完全为空（0个角色），而世界观库有12条数据。说明模板解析逻辑与模板数据格式不一致。

### 🔴 #4: 章节生成后不保存文件
**位置**: `lib/presentation/pages/main_features_page.dart` 第552-566行（及第386-401行）
**现象**: 
- 第388行: 第一章生成后仅弹SnackBar `first_chapter_prompt_edited`
- 第556行: 后续章节同样仅弹 `next_chapter_prompt_edited`
- `_showEditResultDialog` 中的保存逻辑（第903-977行）存在，但两个回调入口都只是弹SnackBar，没有实际调用 `_showEditResultDialog`
```dart
onPromptEdited: (editedPrompt) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已编辑提示词')),  // <-- 仅提示
    );
}
```
**影响**: 核心AI写作功能只能编辑提示词，不会实际生成+保存章节内容。

### 🔴 #5: 导出功能完全缺失
**位置**: 整个项目
**现象**: CLAUDE.md声称支持"TXT / EPUB / Markdown"导出，但代码中不存在任何导出功能。Screenshots目录也是空的。
**影响**: 用户无法从APP中导出任何小说内容。

---

## 三、中等问题 ⚠️

### ⚠️ #6: 创作向导步骤5/6按钮在屏幕外，需手动滚动
**位置**: 运行时实测
**现象**: 在PAD横屏下，步骤5的"继续"按钮和步骤6的"完成创建"按钮在模板内容较长时需要向下滚动才能看到。`mainAxisAlignment: MainAxisAlignment.center` 在内容超出一屏时按钮被推出视口。
**建议**: 按钮应固定在底部，或使用 `SafeArea` + `bottomNavigationBar` 模式。

### ⚠️ #7: 章节写作手机端严重降级
**位置**: `lib/presentation/pages/chapter_writer_page.dart` 第426-442行
**现象**: 手机端布局缺少AI协作面板、错字检查按钮、大纲输入框，只有章节选择+编辑器+保存。
**影响**: 手机用户体验严重不足。

### ⚠️ #8: 大纲系统手机端布局问题
**位置**: `lib/presentation/pages/outline_page.dart` 第116-121行
**现象**: 手机端树形面板限制高度200px，导致大纲树浏览体验极差。且手机端没有使用Tab切换树/编辑器，而是上下排列。

### ⚠️ #9: 手机端主页NavigationRail不存在
**位置**: `lib/presentation/pages/home_page.dart`
**现象**: 手机端(compact layout)使用Drawer+全屏内容，但Drawer需要点击汉堡菜单才能打开，导航效率远低于PAD的Rail。没有底部导航栏（BottomNavigationBar）作为手机适配方案。

### ⚠️ #10: 小说命名输入不支持中文
**位置**: 运行时实测
**现象**: 通过 `adb shell input text` 无法输入中文，用户只能在手机键盘上手打。但 `adb shell input text` 对中文支持本身有局限性。然而TextField本身应支持中文，需要实际手机键盘验证。

### ⚠️ #11: 错字矫正词库有误
**位置**: `lib/presentation/pages/chapter_writer_page.dart` 第153-212行
**现象**:
- 第211行: `'的': '地'` — 无条件替换会破坏大量正确用法
- 多处词条如 `'如罪': '认罪'`、`'买责': '埋折'` 属于罕见错误
- 词库中的 `'救剂': '救济'` 等条目有待商榷
- 缺少常见的「在/再」「做/作」混淆

### ⚠️ #12: 大模型配置路径复杂
**位置**: README.md vs 代码
**现象**: README提到配置在 `C:\Users\{用户名}\Documents\novel_generator_flutter\config.json`，但实际代码中 `ConfigService` 将配置保存在应用沙箱内（`getApplicationDocumentsDirectory()`），用户实际无法直接在文件系统中编辑。

### ⚠️ #13: MainFeaturesPage 存在但未在导航中暴露
**位置**: `lib/presentation/pages/main_features_page.dart`
**现象**: 这是一个完整的生成章节对话框页面（包含所有生成逻辑），但HomePage的导航列表中没有它。`_showGenerateChapterDialog` 只在 `MainFeaturesPage.build()` 的按钮中触发，但该页面本身无法从导航中直接访问。
**影响**: 高级章节生成功能被隐藏。

### ⚠️ #14: NovelArchitecturePage 存在但未在导航中暴露
**位置**: `lib/presentation/pages/novel_architecture_page.dart`
**现象**: 该文件包含了 `SelectedNovelProvider`（核心状态管理类）和一个小说架构管理页面，但页面本身没有被加入HomePage的导航列表。只有 `SelectedNovelProvider` 被其他页面引用。

---

## 四、轻微问题 🟡

### 🟡 #15: 错误的'覆'和'复'区分
**位置**: `chapter_writer_page.dart` 第166行
`'复盖': '覆盖'` — 这本身是对的，但"覆盖"本身就正确，这个替换是冗余的。

### 🟡 #16: 模板生成的小说名乱码
**位置**: 创建时输入 "TestXuanhuan" 后下拉显示 "TestXuanhuan by y by by then yygb"
**原因**: `adb input text` 遗留的键盘状态干扰

### 🟡 #17: SESSION_LOG 声称14/14完成但多项实际不可用
**位置**: `SESSION_LOG.md`
**现象**: 标记为"✅ 完成"的AI续写、导出等功能实际不可用或不存在。开发进度记录与实际情况严重脱节。

### 🟡 #18: 缺少底部导航栏(手机端)
**位置**: `home_page.dart` compact layout
**现象**: 手机端只有Drawer导航，不符合移动端用户习惯。应添加BottomNavigationBar。

### 🟡 #19: 应用图标未替换
**位置**: `SESSION_LOG.md` 待办事项
**现象**: 仍使用默认Flutter图标。

### 🟡 #20: 55个类目模板未补齐
**位置**: `SESSION_LOG.md` 待办事项
**现象**: 写作模板中仅有部分类目有模板数据。

---

## 五、代码质量问题

1. **路由系统不完整**: `routes.dart` 只定义3条路由，10+页面无法通过命名路由访问
2. **注释掉的代码未清理**: `main_features_page.dart` 第667-674行、第823-831行有多处注释掉的按钮
3. **未使用的导入和方法**: `_showEditPromptDialogWithLLMSelection` 带有 `@visibleForTesting` 标记
4. **硬编码字符串**: AI面板的"AI 写作助手"等文案硬编码，未走i18n

---

## 六、已验证可用的功能 ✅

- ✅ 创作向导6步流程（频道→类型→子类→标签→模板→命名）
- ✅ 类型类目体系加载（genres.json → GenreCategory 树）
- ✅ 模板注入世界书（12条世界观条目生成成功）
- ✅ 大纲树(OutlinePage) 增删改功能
- ✅ 世界观库(WorldbookPage) CRUD + 分类筛选
- ✅ 伏笔库(ForeshadowingPage) CRUD + 状态追踪
- ✅ 写作记忆(MemoryOverviewPage) 章节记忆管理
- ✅ PAD三栏布局（Rail + 内容 + AI面板）
- ✅ 深色模式切换
- ✅ 多小说文件隔离
- ✅ 错字检查(本地词库200+条)

---

## 七、需立即修复的TOP 5

| 优先级 | 问题 | 影响 |
|:--:|------|------|
| P0 | AI面板3个按钮空壳 | PAD核心卖点完全不可用 |
| P0 | 章节AI生成后不保存 | 核心写作流程断裂 |
| P0 | AI面板小说信息不更新 | 信息面板形同虚设 |
| P1 | 角色模板解析失败 | 模板初始化不完整 |
| P1 | 导出功能缺失 | 用户无法获取成品 |

---

*报告生成于 2026-06-27 | 基于完整代码审计 + PAD实测*
