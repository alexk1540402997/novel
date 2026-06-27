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
