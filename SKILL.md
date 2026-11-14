---
name: windows-disk-cleanup
description: "Use when a Windows PC is low on disk space (C drive full), when the user asks why a drive is full, which folders/files can be moved or deleted, or wants a cleanup or migration plan that does not break installed software or lose data"
description_zh: "当 Windows 电脑磁盘空间不足（C 盘爆满、只剩几 GB）、用户问某个盘为什么这么大、哪些能删哪些能迁、或需要在不影响软件正常使用的前提下做清理与迁移时使用。也适用于给电脑小白解释磁盘占用并代为执行清理。"
---

# Windows 磁盘空间清理

## 核心原则

1. **先只读，后动手。** 扫描和报告阶段绝不删除、移动、改名任何东西。
2. **删除前必须让用户看到清单并确认。** 「已批准清理」不等于「批准删除这 37 个目录」，每次给出一批具体路径 + 体积，再执行。
3. **三分类**：不能迁（系统/驱动/安装缓存）、应该迁（用户数据/开发缓存）、可以删（纯缓存/冗余）。
4. **迁移优先级**：官方机制（已知文件夹「位置」重定向）> junction > 重装软件。装到 D 盘的软件若只需搬数据，优先 junction，路径不变软件无感。
5. **每步可验证、可回滚**：复制→校验文件数与体积→删源→建链→失败即搬回。

## 流程

| 步骤 | 做什么 | 关键动作 |
|---|---|---|
| 0 环境 | 盘符/容量/剩余/是否管理员/几块物理盘 | `Get-CimInstance Win32_LogicalDisk`、`Get-PhysicalDisk`、`whoami /groups` |
| 1 扫描 | 全盘单遍聚合，输出 TSV | `scripts/scan-drive.ps1 -Root 'C:\' -OutFile ...` |
| 2 分级 | 按 `references/classification.md` 分四类 | 生成 Markdown 报告：结构表 + 分类表 + P0–P3 计划 |
| 3 确认 | 把将删路径逐条列出，等用户点头 | 敏感目录先问（见安全红线） |
| 4 执行 | P0 清理 → P1 用户数据 → P2 应用数据 | 清理用 PowerShell；迁移用 `scripts/migrate-folder.ps1` |
| 5 验证 | 前后可用空间、junction 列表、软件冒烟 | `Get-Item x -Force | Select LinkType,Target` |

## 两条迁移路线怎么选

```
目标目录能被改名/删除吗？
├─ 能（普通目录：Downloads、Videos、Arduino15、缓存目录）
│    → migrate-folder.ps1 -Source <旧路径> -Target <新路径>   （路径不变，软件零感知）
└─ 不能（Desktop 被 Explorer 独占、Documents 里有当前工作目录）
     → 官方「位置」重定向：改 HKCU\...\Explorer\User Shell Folders + Shell Folders
       然后重启 explorer.exe，用 SHGetKnownFolderPath 验证
```

`Documents` 里若有 agent 自己的工作目录，**不要整体删除**：只迁其余内容，保留 C 盘实体壳，或先确认工作目录已不在其中。

## 安全红线（绝对不做）

- 不删 `C:\Windows`、`Program Files`、`ProgramData\Package Cache`、`Windows\Installer`（删了无法卸载/修复软件）
- 不删 `pagefile.sys`、`hiberfil.sys`（只能 `powercfg /h off|reduced` 调整）
- 不删任何 **junction 的目标目录**（先 `Get-Item -Force` 看 `LinkType` 和 `Target`）
- 不删用户点名保护的目录（如 Claude、Codex 数据：`.codex`、`Local\OpenAI`、`codex-runtimes`、`Packages\Claude_*`）
- 用户数据优先**迁移归档**而不是删除；删不动的东西放 D 盘 `_archive`
- 不给小白一次性删几十项：分批，每批报告释放了多少

## 已知踩坑（都真实发生过）

| 坑 | 现象 | 正确做法 |
|---|---|---|
| 把各级目录体积直接相加 | 总量算出 998 GB（实际 136 GB） | 只取根节点那一行，或只加一级子目录 |
| PS 5.1 读 UTF-8 无 BOM 脚本 | 中文变乱码、脚本解析失败 | 脚本用纯 ASCII 注释，或写文件时加 BOM |
| `robocopy /MOVE` 迁移目录 | 空源目录被一并删除，后续建 junction 报「路径不存在」 | 用 `/E` 复制→校验→自己 `Remove-Item`→建链 |
| 删除当前工作目录的父目录 | 进程 cwd 在里面，删除失败或会话断链 | 先判断 cwd，排除或用 registry 重定向 |
| 对 Desktop 做 junction | 改名/删除被拒（Explorer 独占） | 桌面走官方位置重定向 |
| junction 链路被当垃圾删 | 删了 `D:\AppData`，C 盘软件全挂 | 删前先扫 `LinkType`，保护所有 junction target |
| 直接删游戏目录 | 注册表/启动项残留 | 用 Steam/WeGame 客户端卸载 |
| 把安装包当垃圾全删 | 误删个人 PDF/作业 | 只按扩展名+大小筛，人工复核文件名 |

## 汇报给小白的话术

- 说人话：不说「WinSxS 硬链接」，说「系统自带组件，删了会无法更新和修复」
- 给数字：`释放 28.3 GB（可用 14.95 → 43.83 GB）`，不说「优化完成」
- 给选择：`《XX》61 GB，6 周没玩了，要卸载吗？`，不要替用户决定游戏去留
- 留后路：说明「以后还能改回去」「数据还在，只是换了位置」

## 工具

- `scripts/scan-drive.ps1` — 单遍扫描，输出 `路径<TAB>字节<TAB>文件数`，30 万文件约 12 秒
- `scripts/migrate-folder.ps1` — 复制/校验/删源/建 junction，失败自动回滚

详细分类表与常见软件落点见 `references/classification.md`。
