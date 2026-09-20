# BottomControlX 快捷面板改版

目标设备：iOS 15.6、Dopamine roothide、竖屏。

在 BottomControlX 设置中进入「快捷面板项目与图标尺寸」，可添加快捷指令、应用图标快捷操作及系统／越狱动作，调整顺序或移除项目，并选择小／中／大三档图标。设置页只保留一套全局左／中／右上滑手势，桌面和应用内共用。指定为插件动作或快捷面板的区域会接管系统上滑；锁屏和横屏保留系统手势。

## 构建

公开仓库的 Actions 会在 `panel-ios15-roothide` 分支提交后自动构建，也可以手动运行 `Build iOS 15 roothide package`。成功后，从该次运行的 Artifacts 下载 `.deb`。

在带有 iOS SDK、Theos 和 roothide 构建环境的 macOS 上，从项目根目录运行：

```sh
make clean package THEOS_PACKAGE_SCHEME=roothide
```

构建后先验证设置页打开与三档图标大小，再分别验证快捷指令、应用图标快捷操作、面板手势和越狱动作。GitHub Actions 的构建成功只证明可编译和打包，不能代替 iOS 15.6 真机验证。

## 已知兼容边界

- 快捷指令列表以只读方式读取 iOS 15 的 `Shortcuts.sqlite`，运行时使用选择时保存的名称通过系统 `shortcuts://run-shortcut` URL 执行。若后来重命名了指令，请重新选择。
- 应用图标快捷操作由 SpringBoard 查询并提供给设置页，静态菜单项也可从应用资料读取。运行时优先使用图标视图激活；图标视图不可用时尝试应用快捷操作启动接口。不同应用的动态快捷操作需逐项实测。
- 「关闭后台应用」向后台进程发送结束信号，系统任务切换器中的卡片可能保留。
- 重启 SpringBoard、重启用户空间、刷新图标依赖 roothide 环境中对应的 `sbreload`、`jbctl`、`uicache` 工具。

本项目基于 [ichitaso/BottomControlX](https://github.com/ichitaso/BottomControlX)，遵循原项目许可证。
