# BottomControlX 快捷面板改版

目标设备：iOS 15.6、Dopamine roothide、竖屏。

BottomControlX 将底部划分为左、中、右三个全局区域，每个区域可独立添加系统与越狱动作、快捷指令及应用快捷方式，并调整顺序或移除。左右区域宽度可设置；每个区域选一项时直接运行，选两项或更多时面板跟随手指拉出。所选动作可修改名称，或使用自选图片、SF Symbol；面板图标大小可连续调整。没有动作、锁屏或横屏时保留系统手势。

## 构建

公开仓库的 Actions 会在 `panel-ios15-roothide` 分支提交后自动构建，也可以手动运行 `Build iOS 15 roothide package`。成功后，从该次运行的 Artifacts 下载 `.deb`。

在带有 iOS SDK、Theos 和 roothide 构建环境的 macOS 上，从项目根目录运行：

```sh
make clean package THEOS_PACKAGE_SCHEME=roothide
```

构建后先验证设置页打开与三档图标大小，再分别验证快捷指令、应用图标快捷操作、面板手势和越狱动作。GitHub Actions 的构建成功只证明可编译和打包，不能代替 iOS 15.6 真机验证。

## 已知兼容边界

- 快捷指令列表以只读方式读取 iOS 15 的 `Shortcuts.sqlite`，运行时通过 iOS 15 的 `WFSpringBoardWorkflowRunnerClient` 按稳定 ID 从 SpringBoard 后台启动，不跳转快捷指令 App。需要显示界面或首次授权的指令仍可能需要用户交互；该私有接口需在目标设备上实测。
- 应用列表读取系统应用图标。图标快捷操作由 SpringBoard 的快捷操作服务及 iOS 15 图标视图接口查询，静态菜单项也会从应用资料读取。运行时优先使用图标视图激活；不同应用的动态快捷操作仍需逐项实测。
- 「关闭后台应用」向后台进程发送结束信号，系统任务切换器中的卡片可能保留。
- 重启 SpringBoard、重启用户空间、刷新图标依赖 roothide 环境中对应的 `sbreload`、`jbctl`、`uicache` 工具。

本项目基于 [ichitaso/BottomControlX](https://github.com/ichitaso/BottomControlX)，遵循原项目许可证。
