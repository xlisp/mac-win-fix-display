# MacBook Pro 2015（15 寸）Boot Camp Windows 黑屏修复

> 现象：Mac + Windows 双系统，Windows 总会自动更新显卡驱动，关掉自动更新也没用，过一段时间就会进 Windows 黑屏。

## 1. 原因（在 macOS 下读 `/Volumes/BOOTCAMP` 查到的）

| 项目 | 内容 |
|---|---|
| 机型 | MacBookPro11,4（只有一块集成显卡 Intel Iris Pro，硬件 ID `PCI\VEN_8086&DEV_0D26`） |
| Windows | Windows 10（内部版本 19041 系列） |
| ✅ 正常驱动 | Apple Boot Camp 自带 Intel `10.18.15.4240`（2015-06）→ `oem5.inf` |
| ❌ 黑屏驱动 | Windows Update 推送的 Intel `20.19.15.4531`（2016-09）→ `oem48.inf` |
| 安装时间 | 2026-09-24 13:46，日志记录为 `Install Windows Update driver` |

Windows 会自动选版本号更高的驱动，但 Intel 通用版驱动不支持 Mac 内置屏，所以一进系统就黑屏。

`C:\Windows\INF\setupapi.dev*.log` 里能看到这个坏驱动已经装过好几次（以前叫 `oem12.inf`、`oem73.inf`）。之前删掉后又被装回来，说明**只关自动更新不够**，必须同时：
1. 删掉坏驱动包；
2. 禁止 Windows Update 推送驱动；
3. 锁定显卡设备，任何程序都不能再改它的驱动。

> 为什么不直接在 macOS 里修？macOS 只能**只读**挂载 NTFS 分区，而且分区里有 `hiberfil.sys`（Windows 开了快速启动，处于休眠状态）。这时从 Mac 强行写入可能损坏 Windows 分区，所以修复操作要在 Windows 或 Windows 恢复环境里做。

---

## 2. 文件说明

| 文件 | 作用 |
|---|---|
| `fix_intel_gpu.cmd` | 启动入口，双击运行。会自动申请管理员权限，然后调用同目录的 `.ps1`。 |
| `fix_intel_gpu.ps1` | 修复逻辑本体（PowerShell）。 |
| `README.md` | 本说明。 |

**两个脚本文件必须放在同一个文件夹里。**

### `fix_intel_gpu.ps1` 做了什么

1. **删除坏驱动**：扫描 `C:\Windows\INF\oem*.inf`，把所有 Intel `igdlh64` 显卡驱动包里**不是** `10.18.15.4240` 的版本都用 `pnputil /delete-driver ... /uninstall /force` 删掉，保留 Apple 版。这里按驱动内容和版本号判断，不写死 `oem48`，下次编号变了也能识别。
2. **禁止 Windows Update 推送驱动**（写注册表，Windows 家庭版也有效）：
   - `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` → `ExcludeWUDriversInQualityUpdate = 1`
   - `...\DriverSearching` → `SearchOrderConfig = 0`（插新设备时不联网找驱动）
   - `...\Device Metadata` → `PreventDeviceMetadataFromNetwork = 1`
3. **关闭快速启动/休眠**：`powercfg /h off`。关掉后 Windows 每次都是完整关机，macOS 访问 BOOTCAMP 分区更安全，也能减少一些双系统切换的问题。
4. **锁定显卡（最关键的一步）**：
   - 如果当前生效的就是 Apple `10.18.15.4240`：把 `PCI\VEN_8086&DEV_0D26` 加入组策略“禁止安装的设备”（`DeviceInstall\Restrictions\DenyDeviceIDs`）。之后 Windows Update、Intel 驱动助手、驱动精灵之类的工具都换不了这块显卡的驱动。
   - 如果当前不是 Apple 驱动（比如刚删完坏驱动，显示的是“Microsoft 基本显示适配器”）：在正常模式下会自动执行 `pnputil /add-driver oem5.inf /install` 装回 Apple 驱动，然后提示你**重启后再运行一次**脚本来锁定。

### 参数

```
fix_intel_gpu.cmd          正常修复（可以重复运行，不会出问题）
fix_intel_gpu.cmd -Unlock  解除显卡锁定（以后想自己换驱动时用）
```

---

## 3. 准备工作（在 macOS 下）

1. 找一个 U 盘，用“磁盘工具”抹成 **ExFAT** 或 **MS-DOS (FAT)** 格式（不要用 APFS 或 Mac OS 扩展格式，Windows 读不了）。
2. 把 `fix_intel_gpu.cmd` 和 `fix_intel_gpu.ps1` 拷到 U 盘根目录。
3. 记好 Windows 的**登录密码**。安全模式里**不能用 PIN 码**；如果是微软账户，要用微软账户的密码。
4. 如果中途要求输入 **BitLocker 恢复密钥**，可以到 https://account.microsoft.com/devices/recoverykey 查（Boot Camp 一般没开）。

---

## 4. 修复步骤

### 关于 Option 键和安全模式

- **开机按住 Option（⌥）**：这是 Mac 自己的“启动管理器”，用来选从 macOS 还是 Windows 启动。双系统完全可以用，它只负责选系统，**不能直接进安全模式**。
- **F8 进安全模式**：在 Mac 上**不能用**（新版 Windows 默认就关了这个功能，Mac 的固件也不支持）。
- 所以要先让 Windows 进入**恢复环境（WinRE）**，再从那里进安全模式，见下面的方法 A。

> Mac 键盘提示：F1–F12 默认是亮度、音量等功能键，需要按 F 键时要同时按住 **fn**（例如 `fn + F4`）。在“启动设置”那一页直接按数字键 `4` 就行。

### 方法 A：强制关机进入恢复环境 → 安全模式 → 运行脚本（推荐）

1. 开机时**按住 Option**，选 **Windows**（或者在 macOS 的“系统设置 → 启动磁盘”里选 BOOTCAMP）。
2. 一看到 Windows 启动转圈，就**长按电源键约 5 秒强制关机**。
3. 重复第 1–2 步，**共 2～3 次**。下一次启动时会显示“**正在准备自动修复**”或“**自动修复**”。这个界面用的是基本显示驱动，**不会黑屏**。
4. 依次点：**高级选项 → 疑难解答 → 高级选项 → 启动设置 → 重启**。
5. 重启后会出现编号菜单，按 **4**（安全模式）或 **5**（带网络连接的安全模式）。
6. 用**密码**登录，插上 U 盘，**右键** `fix_intel_gpu.cmd` → **以管理员身份运行**（直接双击也行）。
   - 如果脚本还是不正常，可以绕开 `.cmd`，直接运行 `.ps1`：右键开始菜单 → **Windows PowerShell（管理员）**，输入下面这行（`E:` 换成 U 盘的盘符）：
     ```
     powershell -ExecutionPolicy Bypass -File E:\fix_intel_gpu.ps1
     ```
   - 红字 `Removing oemXX.inf (Intel 20.19...)` 表示坏驱动已删除；
   - 黄字 `Apple driver not active yet` 是正常的，因为安全模式下不加载显卡驱动。
7. **正常重启**进 Windows，屏幕应该能正常显示了。
8. **再双击运行一次** `fix_intel_gpu.cmd`，看到绿字 **`GPU driver LOCKED`** 就完成了。
   - 如果这次提示 `Installing Apple driver...`，就是在装回 Apple 驱动。装完重启，再运行第三次即可。

### 方法 B：不进安全模式，直接在恢复环境的命令行里删驱动

如果安全模式进不去或者登录不了，可以在 WinRE 里离线删除坏驱动：

1. 按方法 A 的第 1–3 步进入“自动修复”，然后点 **高级选项 → 疑难解答 → 高级选项 → 命令提示符**。
2. 先确认 Windows 装在哪个盘（WinRE 里不一定是 C:）：
   ```
   dir C:\Windows
   ```
   如果提示找不到，就依次试 `D:`、`E:`……，下面命令里的 `C:` 换成实际盘符。
3. 查看第三方驱动列表，找“原始文件名”为 `igdlh64.inf`、版本是 `20.19.15.4531` 的那一项，记下它的“发布名称”（目前是 `oem48.inf`）：
   ```
   dism /image:C:\ /get-drivers /format:table
   ```
4. 删除坏驱动：
   ```
   dism /image:C:\ /remove-driver /driver:oem48.inf
   ```
5. 离线写入“禁止 Windows Update 推送驱动”：
   ```
   reg load HKLM\OFF C:\Windows\System32\config\SOFTWARE
   reg add "HKLM\OFF\Policies\Microsoft\Windows\WindowsUpdate" /v ExcludeWUDriversInQualityUpdate /t REG_DWORD /d 1 /f
   reg add "HKLM\OFF\Microsoft\Windows\CurrentVersion\DriverSearching" /v SearchOrderConfig /t REG_DWORD /d 0 /f
   reg unload HKLM\OFF
   ```
6. 关掉命令提示符，点“**继续**”启动 Windows。Windows 会自动改用 Apple 驱动；如果暂时是“基本显示适配器”，也一样能显示，只是分辨率可能不对。
7. 进系统后运行两次 `fix_intel_gpu.cmd`（同方法 A 的第 7–8 步），完成锁定。

### 方法 C：外接显示器

有时只有**内置屏**黑，外接显示器（Thunderbolt 或 HDMI）还是有画面。可以先插上外接屏试试：有画面的话直接正常登录，运行两次脚本就行，不用进安全模式。

---

## 5. 验证是否修好

在 Windows 里按 `Win + X` → **设备管理器** → **显示适配器** → 双击 Intel Iris Pro → **驱动程序** 页：

- 驱动程序版本应该是 **10.18.15.4240**；
- “更新驱动程序”会被组策略阻止，这是正常的，说明锁定生效了。

也可以用管理员 PowerShell 查：

```powershell
Get-CimInstance Win32_PnPSignedDriver | ? DeviceID -like 'PCI\VEN_8086&DEV_0D26*' | select DeviceName,DriverVersion,InfName
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\DenyDeviceIDs'
```

---

## 6. 常见问题

**Q：双击 `fix_intel_gpu.cmd` 后终端窗口一直闪、关不掉，电脑也没法操作？**
这是旧版脚本的 bug，**已修复**。旧版用 `net session` 判断有没有管理员权限，但这个命令依赖的 Server 服务在安全模式下不启动，结果判断永远失败，脚本就不停地以管理员身份重新启动自己。
- 遇到这种情况，**长按电源键 5 秒强制关机**即可。修复脚本本体（`.ps1`）根本没跑起来，系统**没有被修改**。
- 新版改用 `fltmc` 判断权限（安全模式下也能用），而且最多只重新启动一次，不会再死循环。请把新版的 `fix_intel_gpu.cmd` 重新拷到 U 盘。

**Q：Apple 驱动（oem5.inf）也被删了怎么办？**
在 macOS 里打开“**启动转换助理**”，菜单栏选 **操作 → 下载 Windows 支持软件**，把下载的 `WindowsSupport` 文件夹拷到 U 盘。进 Windows 后运行里面的 `BootCamp\Setup.exe`，或者在设备管理器里把驱动路径指向这个文件夹。装好后再运行一次脚本锁定。

**Q：Windows 大版本升级（比如升到 Windows 11）之后又黑屏了？**
大版本升级相当于重装系统，有可能清掉锁定设置。升级后再运行一次脚本即可；黑屏的话按第 4 节重新操作。

**Q：想自己换别的显卡驱动？**
先运行 `fix_intel_gpu.cmd -Unlock` 解除锁定，装完驱动后再运行 `fix_intel_gpu.cmd` 重新锁定。

**Q：会影响 Windows 的安全更新吗？**
不会。这只禁止 Windows Update 推送**驱动**，系统补丁、安全更新照常安装。
