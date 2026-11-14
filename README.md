# windows-disk-cleanup

> 一个给 AI Agent 用的 **Windows 磁盘空间分析与迁移技能**（DSH / Claude Skill 格式）。
> 它不会「一键清理」，而是先搞清楚每个 GB 是什么，再分四类处理：**不能迁的绝不动，能迁的搬走，该删的删掉，删不掉的只缩小**。

给电脑小白用：你说「C 盘满了」，Agent 扫完给你一张表——哪些是系统不能碰、哪些是你的照片可以搬走、哪些是纯粹的垃圾——你点头它才动手。

---

## 为什么需要它

网上的「C 盘瘦身教程」和「一键清理」工具，最常见的三种翻车：

1. **删了不该删的** —— `Windows\Installer`、`Package Cache` 一删，以后卸载/修复 Office、WPS 全部失败。
2. **搬了不该搬的** —— 直接把 `Program Files` 拷到 D 盘再做个软链接，Windows 更新和驱动签名校验直接崩。
3. **查了个寂寞** —— 用资源管理器看文件夹大小，遇到 `WinSxS` 的硬链接会重复计算，遇到权限不足直接显示 0。

这个技能的做法相反：**全盘单遍扫描（跳过链接，避免重复计数）→ 按性质分四类 → 出带体积的报告 → 你确认 → 才执行**。

## 真实效果

本机（149 GB 的 C 盘、单块 512 GB NVMe）用这套流程走完：

| 阶段 | C 盘可用 | 做了什么 |
|---|---:|---|
| 开始 | 14.95 GB | 系统盘濒临爆满 |
| P0 清理 | 43.83 GB | 回收站、Temp、着色器缓存 10.5 GB、驱动 OTA 包、NVIDIA DXCache、桌面重复 zip |
| P1 用户数据 | 63.32 GB | 桌面/文档/下载/视频迁到 D 盘 |
| P2 应用数据 | **83.37 GB** | Arduino 工具链、npm/pip/puppeteer 缓存等 7 个目录 junction 到 D 盘 |

累计释放 **68.4 GB**，全程没有重装系统，没有软件重装，Claude/Codex 数据一个字节没动。完整数据见 [docs/case-study.md](docs/case-study.md)。

## 核心设计

### 一、四分类，而不是「能删/不能删」

| 类别 | 判据 | 处理 |
|---|---|---|
| 🔴 不能迁 | 系统、驱动、引导、安装缓存、反作弊 | 只做系统级瘦身（DISM / powercfg） |
| 🟡 应该迁 | 用户数据、可再生的开发缓存 | 官方位置重定向 / junction |
| 🟢 可清理 | 纯缓存、旧版本、安装包 | 确认后删 |
| ⚫ 只能缩小 | pagefile / hiberfil / WinSxS | 系统命令，绝不手删 |

### 二、迁移优先级：官方 > junction > 重装

```
目标目录能被改名/删除吗？
├─ 能 → migrate-folder.ps1 建 junction，路径不变，软件零感知
└─ 不能（桌面被 Explorer 独占）→ 改注册表 User Shell Folders + 重启 explorer
```

junction 只用于**不会被更新器整体删除重建**的目录（缓存、工具链、用户数据）。浏览器、WPS 这类升级时会删目录重装的，必须卸载重装到目标盘。

### 三、每一步都可回滚

`migrate-folder.ps1` 的流程是 **复制 → 校验文件数与字节数 → 删源 → 建链接 → 失败就搬回**，任何一步不达标就停在原地，不会出现「一半在 C 一半在 D」的中间态。

## 安装

技能遵循 Agent Skills 规范（`SKILL.md` + 可选 `scripts/`、`references/`）。

```powershell
# DSH（DeepSeek Harness）
git clone https://github.com/songbaidong169-cyber/windows-disk-cleanup.git "$env:USERPROFILE\.dsh\skills\windows-disk-cleanup"

# Claude Code / 兼容 Agent Skills 的客户端
git clone https://github.com/songbaidong169-cyber/windows-disk-cleanup.git "$env:USERPROFILE\.claude\skills\windows-disk-cleanup"
```

也可以只把 `SKILL.md` 和 `references/classification.md` 丢进你现有的技能目录。

## 使用

装好后直接说人话，不需要记命令：

> 「C 盘只剩 5 GB 了，帮我看看」
> 「D 盘为什么这么大，哪些能删」
> 「把这个软件的数据搬到 D 盘，别影响使用」

Agent 会按五步走：

| 步骤 | 动作 | 产出 |
|---|---|---|
| 0 环境 | 盘符、容量、是否管理员、几块物理盘 | 一句话现状 |
| 1 扫描 | `scripts/scan-drive.ps1` 单遍聚合 | TSV 明细 + 一级目录排名 |
| 2 分级 | 按分类表打标签 | Markdown 报告：结构表 + 分类表 + P0–P3 计划 |
| 3 确认 | 逐条列出将删路径与体积 | 等你点头 |
| 4 执行 | 清理 + 迁移 | 每批报告释放了多少 |
| 5 验证 | 前后可用空间、junction 列表、软件冒烟 | 结果对比表 |

## 报告长什么样

```markdown
# C 盘空间体检与迁移方案
## 一、结论速览      （容量 / 已用 / 可用 + 一句话判断）
## 二、占用结构      （一级目录表 + AppData 下钻）
## 三、分类          （不能迁 / 应该迁 / 可以删 / 只能缩小）
## 四、执行计划      P0 零风险 → P1 用户数据 → P2 应用数据 → P3 需决策
## 五、风险提示      （同盘、junction、安装缓存、还原点）
```

## 安全边界

技能里写死了这些红线，Agent 不会越过：

- 不删 `C:\Windows`、`Program Files`、`ProgramData\Package Cache`、`Windows\Installer`
- 不删 `pagefile.sys` / `hiberfil.sys`（只能 `powercfg /h off|reduced`）
- 不删任何 **junction 的目标目录**（先看 `LinkType` 和 `Target`）
- 不删用户点名保护的目录（内置 Claude/Codex 白名单）
- 用户数据优先迁移归档，而不是删除
- 不给小白一次性删几十项，分批确认

## 目录结构

```
windows-disk-cleanup/
├── SKILL.md                      # 主流程、安全红线、8 条真实踩坑
├── references/
│   └── classification.md         # 四类判据、常见软件落点、报告模板
├── scripts/
│   ├── scan-drive.ps1            # 单遍扫描聚合（30 万文件 ~12 秒）
│   └── migrate-folder.ps1        # 复制/校验/删源/建 junction，失败回滚
└── docs/
    ├── design.md                 # 为什么这么设计（取舍）
    └── case-study.md             # 一次真实 134 GB → 65.6 GB 的复盘
```

## 兼容性

- Windows 10 / 11，Windows PowerShell 5.1 与 PowerShell 7 均可
- 脚本注释为纯 ASCII，规避 PowerShell 5.1 读取 UTF-8 无 BOM 文件的乱码/解析问题
- 部分操作（`DISM`、`powercfg`、删 `C:\SWSetup`）需要管理员权限，技能会单独给出提权脚本而不是硬执行

## 已知限制

- 不含「按文件类型找重复文件」的功能（用 WizTree / dupeGuru 更合适）
- 不做分区调整（C/D 空间再平衡需要第三方分区工具）
- 游戏是否该卸载由用户决定，技能只给「最近活跃时间」做参考

## License

MIT，见 [LICENSE](LICENSE)。
