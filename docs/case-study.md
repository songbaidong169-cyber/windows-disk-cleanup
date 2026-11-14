# 案例复盘：C 盘 134 GB → 65.6 GB

一次真实的 Windows 10 家庭版机器（149 GB C 盘，512 GB 单盘双分区）的完整处理过程。所有数字来自实际扫描，可作为技能输出的参考样本。

## 起点

| 项 | 值 |
|---|---|
| C: | 148.99 GB 总，133.99 GB 已用，**14.95 GB 可用** |
| D: | 326.52 GB 总，254.90 GB 已用，71.62 GB 可用 |
| 物理盘 | 单块 Samsung NVMe SSD 476.9 GB（C、D 同盘） |
| 内存 / 页面文件 | 16 GB / 页面文件已在 D 盘 8.5 GB |

同盘意味着：迁移只是「换分区」，不增加总容量。报告里必须点明这一点，否则用户会误以为搬完就多了 20 GB 总空间。

## 一、扫描发现的结构

| 位置 | 占用 | 关键下钻 |
|---|---:|---|
| `C:\Users` | 78.70 GB | `AppData` 48.62（Local 41.64）、桌面 15.78、文档 4.72、下载 4.37 |
| `C:\Windows` | 27.72 GB | WinSxS 11.62（含硬链接虚高）、System32 10.88 |
| `Program Files (x86)` | 8.72 GB | Edge 全家桶 6.6 |
| `hiberfil.sys` | 6.31 GB | 休眠镜像 |
| `ProgramData` | 5.77 GB | NVIDIA 4.36、Razer 1.01 |
| `$RECYCLE.BIN` | 2.42 GB | 没清空过 |
| `SWSetup` | 1.82 GB | 惠普出厂驱动包 |

`AppData\Local` 里最刺眼的三个：

- `NVIDIA\DXCache` **10.54 GB**，其中**单个 `.nvph` 文件 4 GB**
- `Arduino15` 8.63 GB（ESP32 工具链 6.61 + 下载暂存 1.97）
- `Kingsoft\WPS Office` 2.78 GB，里面装了**两个版本**（旧版 1.44 GB 白占）

另有隐藏的重复：桌面 `t` 文件夹里两个 zip（3.59 + 2.39 GB）和已解压的同名目录同时存在。

## 二、执行

### P0 零风险清理（+28.85 GB → 43.83 GB）

| 目标 | 释放 |
|---|---:|
| 回收站 | 2.42 GB |
| `%TEMP%` | 1.98 GB |
| 桌面 2 个已解压的 zip | 5.98 GB |
| NVIDIA 驱动 OTA 包 | 3.96 GB |
| NVIDIA `DXCache` | 10.54 GB |
| Arduino staging | 1.97 GB |
| WPS 旧版本 | 1.44 GB |

> 实测 `Clear-RecycleBin` 会返回 "The system cannot find the path specified"，但空间确实释放了——这是它的已知怪癖，需要按结果而非退出码判断。

### P1 用户数据（+19.49 GB → 63.32 GB）

| 目录 | 体积 | 方式 |
|---|---:|---|
| 桌面 | 9.80 GB | 注册表重定向（无法改名，见 design.md §4） |
| 文档 | 4.38 GB | 注册表重定向 |
| 下载 | 4.37 GB | junction |
| 视频 / 图片 | 0.77 GB | junction |

文档目录里有一个 agent 自己的工作目录，处理方式是：只迁其余内容，保留 C 盘实体壳，注册表 `Personal` 指向 D 盘。这样既腾出空间，又不断开正在运行的会话。

### P2 应用数据（+20.05 GB → 83.37 GB）

| 目录 | 体积 | 方式 |
|---|---:|---|
| `Arduino15` | 6.67 GB | junction → `D:\arduino\data` |
| `ShadowBot` | 1.03 GB | junction |
| `.cache\puppeteer` | 0.70 GB | junction |
| `.workbuddy-ai` | 0.65 GB | junction |
| `npm-cache` | 0.42 GB | junction |
| `.vscode` | 0.33 GB | junction |
| `pip` 缓存 | 0.17 GB | junction |

用户在此期间自行卸载了剪映、WPS、夸克，卸载程序释放约 9 GB，残余空壳由技能补清。

## 三、过程中的四个坑（已写进 SKILL.md）

1. **总量算成 998 GB** —— 把 TSV 里每一行体积相加，等于把每层父目录重复计入。正确做法：只取根节点行。
2. **PS 5.1 解析失败** —— 脚本写成无 BOM 的 UTF-8，中文注释导致 `ParserError`，一行都没执行（所幸未造成破坏）。之后改为纯 ASCII。
3. **`robocopy /MOVE` 删掉了空源目录** —— 迁移视频目录后源目录消失，`New-Item -ItemType Junction` 报「路径不存在」；脚本走了回滚。之后统一改为 `/E` 复制 + 校验 + 自己删源。
4. **桌面无法改名** —— 计划用 junction 处理桌面时 `Rename-Item` 被拒，改为官方位置重定向。

## 四、结果

| 阶段 | C 可用 | C 已用 |
|---|---:|---:|
| 开始 | 14.95 GB | 133.99 GB |
| P0 后 | 43.83 GB | 105.16 GB |
| P1 后 | 63.32 GB | 85.67 GB |
| P2 后 | **83.37 GB** | **65.62 GB** |

整个过程：**没有重装系统、没有重装任何软件、没有删除聊天记录与个人文档**。用户点名保护的 Claude / Codex 目录（合计 4.25 GB）字节级未变。

## 五、未处理项（留给用户决定）

- `C:\SWSetup` 1.82 GB、`Windows\Panther` 0.47 GB、Razer Cortex 1.35 GB —— 需要管理员权限，脚本单独提供
- `hiberfil.sys` 6.31 GB —— 可 `powercfg /h /type reduced` 省约 3 GB，但会牺牲休眠
- 顺带的建议：`DXCache` 会重新长回 10 GB，应在 NVIDIA 控制面板把着色器缓存上限设为 1–5 GB
