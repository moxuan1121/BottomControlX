# ShortcutPanel

目标设备：iOS 15.6、Dopamine roothide、竖屏。

ShortcutPanel 在底部提供避开屏幕角落与中央 Home Indicator 的左、右两个全局区域，每个区域可独立添加系统与越狱动作、快捷指令及应用快捷方式，并调整顺序或移除。左右区域宽度和角落避让距离使用连续滑杆设置；每个区域选一项时直接运行，选择多项时面板随手指移动，往回滑可取消。横向滑动继续使用系统的应用切换手势；已配置触发区域内的上滑由插件独占。设置中可临时显示左右触发区域。快捷指令和应用快捷方式选择页支持搜索，应用页只显示实际读取到快捷方式的应用。所选动作可修改名称，或使用自选图片、SF Symbol；面板图标大小可连续调整。

## 构建

公开仓库的 Actions 会在 `panel-ios15-roothide` 分支提交后自动构建，也可以手动运行 `Build ShortcutPanel iOS 15 roothide package`。成功后，从该次运行的 Artifacts 下载 `.deb`。

在带有 iOS SDK、Theos 和 roothide 构建环境的 macOS 上，从项目根目录运行：

```sh
make clean package THEOS_PACKAGE_SCHEME=roothide
```

构建后分别验证设置页、快捷指令、应用图标快捷操作、面板手势和越狱动作。GitHub Actions 的构建成功只证明可编译和打包，不能代替 iOS 15.6 真机验证。

## 已知兼容边界

- 快捷指令列表以只读方式读取 iOS 15 的 `Shortcuts.sqlite`，运行时通过 iOS 15 的 `WFSpringBoardWorkflowRunnerClient` 按稳定 ID 从 SpringBoard 后台启动，不跳转快捷指令 App。需要显示界面或首次授权的指令仍可能需要用户交互；该私有接口需在目标设备上实测。
- 应用列表读取系统应用图标。图标快捷操作合并 `SBApplication` 的静态与动态项目、SpringBoard 快捷操作服务、图标视图、应用资料及系统长按菜单缓存，并通过 iOS 15 的 `SBIconView` 类方法激活；不同应用的动态快捷操作仍需逐项实测。
- 「关闭后台应用」向后台进程发送结束信号，系统任务切换器中的卡片可能保留。
- 「重启 SpringBoard」只结束 SpringBoard；「重启 SpringBoard 并释放后台」会先结束后台应用，再结束 SpringBoard。
- 用户空间重启按 Dopamine roothide 的方式临时取得 root 与非沙盒标签，并通过 `libjailbreak` 的 roothide 启动函数以挂起状态运行 `jbctl reboot_userspace`。刷新图标依赖 roothide 环境中的 `uicache`。
- 左右触发区避开屏幕角落，因此不会占用键盘左下角切换键盘和右下角听写按钮；中间区域保留系统 Home Indicator 手势。

本项目基于 [ichitaso/BottomControlX](https://github.com/ichitaso/BottomControlX)，遵循原项目许可证。
