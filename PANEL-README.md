# ShortcutPanel

目标设备：iOS 15.6、Dopamine roothide、竖屏。

ShortcutPanel 在屏幕左右侧提供常驻的圆角手柄。某侧配置动作后才显示对应手柄；按住手柄向屏幕内拖动时，窄侧边面板跟随手指展开，往回拖可取消。松手完成呼出后，点击动作立即执行，点击面板外部关闭。左右手柄继续使用原有的两组动作配置，支持系统与越狱动作、快捷指令及应用快捷方式，并可排序、移除、自定义名称和图标。

设置页可连续调节手柄高度和垂直位置；白色指示条占手柄高度的 90%。侧边面板会根据当前动作中最长的名称调整宽度，并限制在 104–220 点。它不接管底部 Home Indicator 手势，也不提供面板内添加按钮。

## 构建

公开仓库的 Actions 会在 `panel-ios15-roothide` 分支提交后自动构建，也可以手动运行 `Build ShortcutPanel iOS 15 roothide package`。成功后，从该次运行的 Artifacts 下载 `.deb`。

在带有 iOS SDK、Theos 和 roothide 构建环境的 macOS 上，从项目根目录运行：

```sh
make clean package THEOS_PACKAGE_SCHEME=roothide
```

GitHub Actions 构建成功只证明可编译和打包。侧边窗口触摸穿透、横屏隐藏与各动作仍需在 iOS 15.6 真机验证。

## 已知兼容边界

- 快捷指令列表以只读方式读取 iOS 15 的 `Shortcuts.sqlite`，运行时通过 iOS 15 的 `WFSpringBoardWorkflowRunnerClient` 按稳定 ID 从 SpringBoard 后台启动。需要显示界面或首次授权的指令仍可能需要用户交互。
- 应用图标快捷操作合并 SpringBoard 可读取的静态、动态项目及长按菜单缓存，并通过 iOS 15 的 `SBIconView` 接口激活；不同应用的动态快捷操作仍需逐项实测。
- 「重启 SpringBoard」只结束 SpringBoard；「关闭后台并重启 SB」会先结束后台应用，再结束 SpringBoard。
- 用户空间重启直接启动 Dopamine roothide 自带且已签名授权的 `/basebin/jbctl reboot_userspace`。刷新图标依赖 roothide 环境中的 `uicache`。

本项目基于 [ichitaso/BottomControlX](https://github.com/ichitaso/BottomControlX)，遵循原项目许可证。
