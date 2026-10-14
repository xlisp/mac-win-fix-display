
### ❯ Mac 15寸本电脑，2015款，装了windows双系统，但是总是windows自动更新，关掉更新也没用，过段时间就更新驱动，就导致打开windows就黑屏了，怎么彻底解决？ /Volumes/BOOTCAMP/ 这个盘就是。

```
我在 Mac 上读了 BOOTCAMP 分区，找到原因了，修复脚本也写好了，但还没在 Windows 里跑过，需要你进 Windows 操作。

原因

你这台是 MacBookPro11,4，只有一块 Intel Iris Pro 集成显卡。
- 能用的驱动：Apple Boot Camp 自带的 10.18.15.4240（oem5.inf）
- 导致黑屏的驱动：2026-09-24 Windows Update 自动装的 Intel 20.19.15.4531（oem48.inf）。这个版本不兼容 Mac 内置屏，所以一进系统就黑屏。

日志里能看到这个坏驱动已经被装过好几次（以前是 oem12、oem73）。所以光关自动更新不够，它还会回来。

修复脚本（就在本目录）

fix_intel_gpu.cmd 和 fix_intel_gpu.ps1 是一套，必须放在同一个文件夹里。脚本会做这几件事：
1. 删除除 Apple 版本以外的所有 Intel 显卡驱动包。
2. 用组策略的注册表项禁止 Windows Update 推送驱动（ExcludeWUDriversInQualityUpdate），并关掉自动搜索驱动。
3. 确认当前用的是 Apple 驱动后，把这块显卡加入“禁止安装设备”列表，以后任何程序都不能替换它的驱动。这一步最关键。
4. 关闭快速启动/休眠（powercfg /h off），这样 Mac 这边访问 BOOTCAMP 分区更安全。

macOS 现在只能只读挂载这个分区，而且 Windows 还处于休眠状态，从 Mac 强行写入可能损坏分区。所以脚本没有直接放进去，需要你用 U 盘（exFAT 或 FAT32 格式）拷过去。


我在 Mac 上读了 BOOTCAMP 分区，找到原因了，修复脚本也写好了，但还没在 Windows 里跑过，需要你进 Windows 操作。

原因

你这台是 MacBookPro11,4，只有一块 Intel Iris Pro 集成显卡。
- 能用的驱动：Apple Boot Camp 自带的 10.18.15.4240（oem5.inf）
- 导致黑屏的驱动：2026-09-24 Windows Update 自动装的 Inte）。这个版本不兼容 Mac 内置屏，所以一进系统就黑屏。

日志里能看到这个坏驱动已经被装过好几次（以前是 oem12、oem73）。所以光关自动更新不够，它还会回来。

修复脚本（就在本目录）

fix_intel_gpu.cmd 和 fix_intel_gpu.ps1 是一套，必须放在同一个文件夹里。脚本会做这几件事：
1. 删除除 Apple 版本以外的所有 Intel 显卡驱动包。
2. 用组策略的注册表项禁止 Windows Update 推送驱动（ExcludeWUDriversInQualityUpdate），并关掉自动搜索驱动。
3. 确认当前用的是 Apple 驱动后，把这块显卡加入“禁止安装设备”列表，以后任何程序都不能替换它的驱动。这一步最关键。
4. 关闭快速启动/休眠（powercfg /h off），这样 Mac 这边访

macOS 现在只能只读挂载这个分区，而且 Windows 还处于休眠状态，从 Mac 强行写入可能损坏分区。所以脚本没有直接放进去，需要你用 U 盘（exFAT 或
FAT32 格式）拷过去。

操作步骤

1. 进安全模式：开机时按住 Option，选 Windows。一出现 Windows 转圈就长按电源键强制关机，重复 2–3 次，会进入“自动修复”。然后依次点：高级选项 →
   疑难解答 → 高级选项 → 启动设置 → 重启，再按 4 进入安全
2. 在安全模式里运行 U 盘上的 fix_intel_gpu.cmd。它会删掉坏驱动并屏蔽 Windows Update 驱动推送，最后提示你重启。
3. 正常重启，这时应该能显示了。然后再运行一次 fix_intel_gver LOCKED 就表示锁定完成。

以后如果想自己升级显卡驱动，先运行 fix_intel_gpu.cmd -Unl

另外：如果只是内置屏黑、外接显示器有画面，可以直接在外接 式。

```
