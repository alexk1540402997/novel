# SESSION_LOG.md — 「妙笔小说」

## 最新APK
```
C:\Users\AlexK\Desktop\novel-app\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```
18.1MB | flutter clean后构建 | 0 errors

## 安装到手机前必须：先卸载旧版APP！

## 当前状态 (2026-06-29)

### ✅ 已修复
1. **大纲页面全量重写** — 路径系统修正(空串=根)，LayoutBuilder布局，ListTile点击
2. **灵感全面优化** — 共享InspirationService：加载指示器+本地缓存+刷新按钮+格式清理
3. **大模型选择器** — 设置页可选择文字/图片模型
4. **AI写作助手移除** — 全局面板已删除，功能分散到各模块
5. **章节写作2栏布局** — 左列表+右编辑+底AI栏
6. **写作记忆备注** — ChapterMemory.userNotes字段
7. **设置页控件** — 字体Slider+保存间隔Dropdown+导出格式Dropdown
8. **章节列表分卷** — 从大纲读取卷结构，可折叠
9. **灵感覆盖5模块** — 大纲/章节/世界观/角色/伏笔

### ⚠️ 待完成
- 章节列表：下一分卷按钮+章节命名弹窗+大纲双向同步
- 灵感：单个条目(非整个模块)的灵感按钮
- 底部AI栏：展开时空间利用+AI总结章节名
- 错字检查按钮独立化
- 手机窄屏布局验证

## 大模型配置 (Agnes)
- Base URL: https://apihub.agnes-ai.com/v1
- 文字模型: agnes-2.0-flash
- 图片模型: agnes-image-2.1-flash
- API Key: sk-OOFCX59YdR27YohHhfs6T4fPcgnTdbdug1cjrQTbolalfwF8

## 构建命令
```bash
export MSYS2_ARG_CONV_EXCL="*"
cd "C:/Users/AlexK/Desktop/novel-app"
/d/src/flutter/bin/flutter clean
/d/src/flutter/bin/flutter build apk --release --split-per-abi
```

## 关键教训
- IntrinsicHeight在Row中会导致布局异常
- 大纲路径空串=根，"0"=第1子（之前路径偏移导致节点错位）
- 模拟器能跑不代表真机能跑，需要格外注意窄屏布局
