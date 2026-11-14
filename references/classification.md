# 磁盘分类参考表

用于步骤 2「分级」。按这四类给每个目录打标签，再生成清理计划。

## 四类定义

| 类别 | 判据 | 处理 |
|---|---|---|
| 🔴 不可迁 | 系统/驱动/引导/安装缓存/反作弊 | 不动，只做系统级瘦身（DISM、powercfg） |
| 🟡 应该迁 | 用户数据、可再生的开发缓存、支持改路径的应用 | 官方位置重定向或 junction |
| 🟢 可清理 | 纯缓存、旧版本残留、安装包、空壳 | 确认后删除 |
| ⚫ 只能缩小 | pagefile / hiberfil / WinSxS | 系统命令调整，绝不手删 |

## 🔴 不可迁（C 盘约 35–45 GB）

| 路径 | 典型体积 | 理由 |
|---|---|---|
| `C:\Windows`（WinSxS 含硬链接虚高） | 20–30 GB | 引导、内核、驱动、服务路径写死在注册表/BCD；软链接会导致更新失败、蓝屏 |
| `Program Files (x86)\Microsoft\Edge*`、`EdgeWebView` | 4–7 GB | 系统组件，大量软件依赖固定路径的 WebView2 |
| 驱动（NVIDIA/Intel/Realtek）、`.NET`、VC++ 运行库 | 1–3 GB | 内核驱动需在系统盘注册，与驱动回滚/签名绑定 |
| `ProgramData\Package Cache`、`Windows\Installer` | 0.3–2 GB | MSI 缓存，删了无法卸载/修复/升级 |
| `Windows\Boot`、`bootmgr`、`Recovery`、`System Volume Information` | — | 引导与还原点 |
| `pagefile.sys`、`hiberfil.sys`、`swapfile.sys` | 4–10 GB | 必须在系统卷；只能关闭或缩小 |
| Store/MSIX 应用（`AppData\Local\Packages\*`） | 0.5–3 GB | 绑定系统卷，只有少数支持「设置→应用→移动」 |
| `%USERPROFILE%` 下的 `NTUSER.DAT`、`AppData\Local\Microsoft\Windows` | <1 GB | 每用户系统状态（图标/字体缓存、Shell） |
| 游戏反作弊（`AntiCheatExpert`、`EasyAntiCheat`） | 少量 | 有完整性校验，路径一变判外挂 |

## 🟡 应该迁（按收益排序）

| 对象 | 典型体积 | 方法 | 备注 |
|---|---|---|---|
| 桌面 / 文档 / 下载 / 视频 / 图片 | 5–50 GB | 官方「属性→位置→移动」改注册表 | **桌面通常被 Explorer 锁住，无法改名**，只能走注册表 |
| `AppData\Local\Arduino15` | 2–9 GB | junction 到 `D:\arduino\data` | Arduino 无感，编译照常 |
| 剪映 `Local\JianyingPro`、`Roaming\kingsoft`、WPS | 2–5 GB | 优先卸载重装到 D；草稿目录可在设置里改 | 程序本体不推荐 junction |
| 浏览器（Chrome/Edge/夸克）用户数据 | 1–5 GB | 卸载重装到 D，或 `--user-data-dir` | 直接 junction 可能与更新器冲突 |
| 微信 / QQ 聊天记录 | 2–10 GB | 客户端「设置→文件管理→更改存储位置」 | 必须在退出客户端后迁 |
| npm / pip / conda / cargo 缓存 | 0.2–3 GB | 改 `npm config set cache`、`PIP_CACHE_DIR`、`CONDA_PKGS_DIRS`、`CARGO_HOME` | 比 junction 更稳 |
| `.cache`（puppeteer、huggingface、torch） | 0.5–10 GB | 环境变量（`HF_HOME`、`TORCH_HOME`、`PUPPETEER_CACHE_DIR`）或 junction | 纯缓存，删了也能重下 |
| 微信/QQ/Steam 等已装在 D 但数据在 C | 1–5 GB | 同上，按应用设置改 | 常见「程序搬了、数据没搬」 |

**判断「能不能 junction」的硬标准**：该目录的更新器是否会在升级时**删除并重建**整个目录。会删的（浏览器、WPS、剪映本体）用重装；不会删的（缓存、工具链、用户数据）用 junction。

## 🟢 可清理（按收益排序）

| 对象 | 典型体积 | 说明 |
|---|---|---|
| `AppData\Local\NVIDIA\DXCache` | 3–15 GB | 着色器缓存；删后首次进游戏重新编译。建议在 NVIDIA 面板把缓存上限设 1–5 GB |
| `ProgramData\NVIDIA Corporation\NVIDIA App\UpdateFramework` | 1–5 GB | 驱动 OTA 安装包残留 |
| 回收站 | 1–10 GB | `Clear-RecycleBin` |
| `%TEMP%` / `AppData\Local\Temp` | 1–10 GB | 排除正在使用的文件 |
| 厂商出厂安装包（`C:\SWSetup`、`C:\Drivers`） | 1–5 GB | HP/联想/Dell 出厂驱动包 |
| 旧版本目录（`WPS Office\<旧版本号>`、`Chrome\Application\<旧版本>`） | 0.5–3 GB | 当前版本号以外的都可删 |
| 工具链下载暂存（`Arduino15\staging`） | 0.5–3 GB | 已安装工具链的压缩包 |
| 升级日志（`Windows\Panther`） | 0.2–1 GB | 需管理员 |
| 下载目录里的安装包 | 1–10 GB | 按扩展名 + 大小筛，**逐个人工复核**，别误删证件/作业 |
| 应用更新包（`Doubao_update`、`*Updater\installer.exe`） | 0.5–3 GB | 更新完成后无用 |
| 音乐/视频缓存（`QQMusicCache`、`KuGou\Temp`） | 1–10 GB | 长期不写入就是历史缓存 |
| 驱动备份（`MyDrivers`、`DriverGenius`、`D:\驱动精灵`） | 1–6 GB | 驱动精灵/鲁大师类，装完驱动就该卸 |
| `Windows.old` | 5–30 GB | 升级后 10 天内可删，之后系统自动清理 |
| 睡眠/休眠文件 | 3–10 GB | 见「只能缩小」 |

## ⚫ 只能缩小

| 对象 | 命令 | 收益 | 代价 |
|---|---|---|---|
| 休眠文件 | `powercfg /h /type reduced`（管理员） | 省 50–60% | 保留快速启动，失去休眠 |
| | `powercfg /h off` | 全部 | 失去休眠 + 快速启动 |
| WinSxS | `DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase` | 2–4 GB | 无法卸载旧更新 |
| 系统还原点 | `vssadmin list shadowstorage` + 限制配额 | 不定 | 牺牲回滚能力 |
| 页面文件 | 系统属性→高级→性能→虚拟内存，移到其他盘 | 与 RAM 相当 | 该盘必须够快够稳 |

## 常见软件默认落点

| 软件 | 程序 | 数据 |
|---|---|---|
| 微信 4.x | `D:\微信\软件` 或 `Program Files` | `Documents\Tencent Files`、`AppData\Roaming\Tencent\xwechat` |
| QQ NT | `D:\QQ` | `Documents\Tencent Files\<QQ号>\nt_qq` |
| Steam | 自选库目录 | `steamapps\common`、`userdata` |
| 浏览器 | `Program Files\Google\Chrome` | `AppData\Local\Google\Chrome\User Data` |
| VS Code / Cursor | 程序目录 | `%USERPROFILE%\.vscode`、`AppData\Roaming\Code` |
| Arduino IDE 2 | 程序目录 | `AppData\Local\Arduino15`（board 包 2–9 GB） |
| 剪映 | `AppData\Local\JianyingPro\Apps` | 同目录 `User Data`（草稿） |
| WPS | `AppData\Local\Kingsoft\WPS Office\<版本>` | `AppData\Roaming\kingsoft` |
| Docker Desktop | `Program Files\Docker` | `AppData\Local\Docker\wsl`（可达数十 GB） |
| OneDrive | — | `%USERPROFILE%\OneDrive`（若开启「备份文件夹」则桌面/文档已重定向到这里，先确认再动） |
| 游戏（WeGame/Steam） | `WeGameApps\rail_apps`、`steamapps\common` | 存档多在 `Documents\My Games` 或 `AppData\Local\<游戏>` |

## 大文件 / 游戏判定

- 扫描后按体积排序，**单文件 > 1 GB 的一定要看一眼**：可能是 VHD/ISO/备份/游戏 pak。
- 游戏是否还玩，看**最近写入时间** + 是否有近期存档：
  `Get-ChildItem <游戏目录> -Recurse -File | Sort-Object LastWriteTime -Descending | Select -First 1`
- 卸载游戏必须用平台客户端（Steam/WeGame），手删目录会留下注册表、启动项、反作弊服务。

## 报告模板

```markdown
# X 盘空间体检与迁移方案
## 一、结论速览（容量/已用/可用 + 一句话判断）
## 二、占用结构（一级目录表 + 关键下钻）
## 三、分类：不能迁 / 应该迁 / 可以删 / 只能缩小
## 四、执行计划 P0（零风险，X GB）→ P1（用户数据）→ P2（应用数据）→ P3（需决策）
## 五、风险提示（同盘、junction、安装缓存、还原点）
```
