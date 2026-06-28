# CLAUDE.md — 「妙笔小说」AI小说创作PAD工具

## ⚠️ 新会话必读

**每次新会话启动后，必须先读取以下文件恢复上下文：**
1. `SESSION_LOG.md` — 最新状态、22项问题清单、6轮执行计划
2. `FINAL_ISSUE_LIST.md` — 详细问题描述（含文件位置和修复方向）
3. 本 `CLAUDE.md` — 项目约定和构建配置

**当前进度：** 质量审查完成，待从第一轮开始执行修复。
**核心原则：** 每次修改后必须启动APP实际验证（截图+实操），禁止仅凭代码审计判断"可用"。

## 项目概述

基于 Flutter 的 Android PAD 端 AI 辅助小说创作工具。以开源项目 [AI_NovelGenerator_flutter](https://github.com/ahhhhhhhman/AI_NovelGenerator_flutter) 为基础进行魔改，专为中文网文创作者设计。

**GitHub仓库：** https://github.com/alexk1540402997/novel.git
**项目路径：** `C:\Users\AlexK\Desktop\novel-app`（⚠️ 工作目录必须在此路径，非 `AI小说创作`）

## 技术栈

| 层级 | 技术 |
|------|------|
| 框架 | Flutter 3.x (Dart) |
| 状态管理 | Provider / Riverpod |
| UI | Material Design 3 + 自适应布局 |
| 本地数据库 | SQLite (sqflite) |
| AI API | Claude / DeepSeek / OpenAI (兼容) |
| 云同步 | WebDAV |
| 目标平台 | Android 10+ (PAD优化) |

## 核心功能模块

```
novel-app/
├── 项目管理 ← 多小说并行、仪表盘
├── 创作向导 ← 男频/女频 → 类型类目 → 模板生成 → 问题清单
├── 大纲系统 ← 总纲 → 分卷 → 章节大纲（四级）
├── 世界观库 ← 结构化设定、关联角色/章节
├── 角色库 ← 角色卡片、关系图谱、状态追踪
├── 伏笔库 ← 埋设/回收位置、关联角色/设定
├── AI写作引擎 ← 续写模式 + 章节模式 + 错字矫正
└── 导出 ← TXT / EPUB / Markdown
```

## 类型类目体系（0级→3级）

```
0级: 男频 / 女频
1级: 玄幻 / 都市 / 历史 / 科幻 / 悬疑 / 游戏 / 军事 / 武侠 / 轻小说...
2级: 东/西方玄幻、修真流、洪荒流...
3级: 风格标签（爽文/虐文/系统流/种田流/无限流...）
```

每级类目附带：大纲模板、世界观设定模板、创作方向问题清单。

## 关键约束

- **路径必须纯ASCII**：Gradle/Android不支持中文路径，源码放在 `C:\Users\AlexK\Desktop\novel-app`
- **PAD优先**：所有UI以PAD横屏为主设计目标，兼顾手机竖屏
- **API Key由用户配置**：APP不内置任何API Key
- **离线可用**：核心写作功能离线可用，AI功能需网络
- **中文界面**：所有UI文案使用简体中文

## 代码规范

- 注释使用中文
- 类名 PascalCase，变量/方法 camelCase
- 文件名 snake_case
- 常量/配置集中在 `lib/config/` 下
- AI模型接口统一抽象，方便切换

## 构建与运行

```bash
# 获取依赖
flutter pub get

# 编译Android APK (debug)
flutter build apk --debug

# 安装到模拟器
flutter install

# 直接运行
flutter run
```

### 启动模拟器
```bash
flutter emulators --launch Pixel_Tablet_API_35   # PAD
flutter emulators --launch Pixel_6_API_35         # 手机
```

### 启动APP并验证（标准流程）
```bash
# 1. 确认模拟器在线
flutter devices
# 2. 构建并安装
cd C:/Users/AlexK/Desktop/novel-app
flutter build apk --debug
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
# 3. 启动
adb -s emulator-5554 shell am start -n com.example.ai_novelgenerator_flutter/.MainActivity
# 4. 截图验证
adb -s emulator-5554 exec-out screencap -p > screen.png
```

## 验证原则

**严禁仅凭代码审计判断功能可用。** 每次修改后必须：
1. 构建APK
2. 安装到模拟器
3. 实际操作验证（截图+UI dump）
4. 确认修改生效后才能标记完成

**已验证可用的标准：** 用户能实际使用，不是"代码逻辑正确"。

## 辅助Skill

本项目的修改流程使用以下skill配合：
- `/verify` — 每次修改后验证
- `/run` — 启动APP
- `/code-review` — 修改前代码审查
- `/security-review` — 发布前安全审查
- `/pua-en` — 绩效管控，确保不糊弄

## 基础项目（魔改来源）

- 仓库：https://github.com/ahhhhhhhman/AI_NovelGenerator_flutter
- 已具备：结构化创作流程、角色追踪、多AI模型、WebDAV同步、中英i18n
- 需新增：类型类目模板系统、伏笔库、世界观库重构、错字矫正、PAD布局

---

# 🚨 本轮错误与教训（2026-06-29）

> **以下教训来源于用户PAD实测后发现的严重问题。每次新会话必须重读本章节。**

## 错误1：代码审查替代交互测试（大纲节点点击失效）

**发生了什么**：用户要求验证大纲每个节点能否点击编辑。我只看了代码（`InkWell(onTap: _selectNode)`存在）+ 模拟器UI dump（树结构显示），就判定"✅通过"。用户PAD实测发现**二级三级节点完全点不了**。

**根因**：代码存在 ≠ 功能正常。以下因素代码审查发现不了：
- `ListView` 与 `InkWell` 的手势竞争（ListView会延迟tap以区分滚动）
- 嵌套 `GestureDetector` 消耗手势
- `_findNode` 对深层路径返回null
- `setState` 调了但 `_buildEditor` 没重建

**铁律**：
- ❌ **严禁**用代码审查代替交互测试
- ✅ **必须**在模拟器上实际操作：点击每个节点、输入文字、看右侧编辑器是否响应
- ✅ 只有真正"点下去了、有反应了"，才能判通过

## 错误2：UI组件指代对象混淆（AI写作助手 vs AI章节生成）

**发生了什么**：用户说"AI写作助手悬浮化"，指 `home_page.dart` 右侧全局面板（5个按钮）。我理解成了 `chapter_writer_page.dart` 中的"AI章节生成"面板，只改了一处。

**根因**：项目中有多个"AI面板"——全局AI写作助手、章节写作的AI章节生成——我没确认具体指哪个就动手了。

**铁律**：
- ✅ 涉及UI组件的需求，用**具体代码位置**（文件名+行号+变量名）和用户确认
- ✅ "AI助手"这种模糊词必须追问："是说右侧全局那个有5个按钮的面板，还是章节写作页里大纲→正文那个？"
- ✅ 全局组件修改必须搜索所有引用，确保每处都改到位

## 错误3：做过≠做完（章节列表联动）

**发生了什么**：用户之前提过章节列表要"联动大纲分卷 + 页码选择"。我只做了章节号跳转输入框就标记完成。实际缺：下拉收起卷/章、真正的页码选择器。

**铁律**：
- ✅ 需求逐条打勾确认，**每一项**单独验证
- ✅ 不能做50%当100%
- ✅ "简化实现"需要明示用户，征得同意

## 错误4：测试环境不稳定时放弃交互验证

**发生了什么**：模拟器ANR+断连、adb无法输入Flutter文本后，我就放弃了交互测试，改用代码审查。

**铁律**：
- ✅ 模拟器不稳定时，至少保证能做的基础操作验证（重启模拟器、修改代码创建测试数据辅助验证）
- ✅ 用户PAD才是最终测试设备，模拟器验证不充分时必须说明

## 交互测试清单（每次修改后必须逐项执行）

1. ✅ 点击每个UI元素确认有响应
2. ✅ 输入文字确认能保存
3. ✅ 导航到每个页面确认正常渲染
4. ✅ 截图 + UI dump记录实际状态
5. ✅ 不确定的交互行为，先问用户确认理解，再动手
6. ✅ 涉及全局面板/多处引用时，逐一验证每个出现位置
