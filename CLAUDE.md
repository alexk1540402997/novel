# CLAUDE.md — AI小说创作PAD工具

## 项目概述

基于 Flutter 的 Android PAD 端 AI 辅助小说创作工具。以开源项目 [AI_NovelGenerator_flutter](https://github.com/ahhhhhhhman/AI_NovelGenerator_flutter) 为基础进行魔改，专为中文网文创作者设计。

**GitHub仓库：** https://github.com/alexk1540402997/novel.git
**项目路径：** `C:\Users\AlexK\Desktop\novel-app`

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

## 基础项目（魔改来源）

- 仓库：https://github.com/ahhhhhhhman/AI_NovelGenerator_flutter
- 已具备：结构化创作流程、角色追踪、多AI模型、WebDAV同步、中英i18n
- 需新增：类型类目模板系统、伏笔库、世界观库重构、错字矫正、PAD布局
