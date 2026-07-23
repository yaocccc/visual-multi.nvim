# visual-multi.nvim

<p align="center">
  <a href="./README.md">English</a> · <strong>简体中文</strong>
</p>

一个小巧、原生 Lua 实现的 **Neovim 0.12+** 多光标插件。

> [!IMPORTANT]
> 本项目由原仓库
> [`mg979/vim-visual-multi`](https://github.com/mg979/vim-visual-multi)
> 演变而来。当前 Lua 重写版本在用户需求驱动下完全由 AI 实现，仅适配最新版
> Neovim，不兼容 Vim，也不以兼容旧版 `vim-visual-multi` 为目标。

当前实现使用 Extmark 和细粒度 Buffer 更新事件。

## 开发动机

1. **仅保留核心功能。** 移除旧兼容层和非必要高级功能，专注于多光标的选择、
   导航与同步编辑流程。
2. **大幅优化性能。** 使用原生 Lua、Extmark、批量创建选区、二分查找当前
   光标，以及无需逐次全量重绘的串行 Insert 更新。

### 大致性能对比

以下数据来自同一台机器、Neovim 0.12.4 的单次 Headless 测试。每行包含一个
`foo`，测试操作为选择全部匹配项。该数据用于展示大致差异，并非严谨的跨设备
基准测试。

| 匹配数量 | 原仓库 | Lua 重写版 | 大致提升 |
| ---: | ---: | ---: | ---: |
| 200 | 62.1 ms | 8.3 ms | 7.5 倍 |
| 500 | 111.5 ms | 16.4 ms | 6.8 倍 |
| 1,000 | 166.4 ms | 30.4 ms | 5.5 倍 |
| 2,000 | 357.3 ms | 55.8 ms | 6.4 倍 |
| 10,000 | 1,669.4 ms | 246.7 ms | 6.8 倍 |

大量光标同步 Insert 时也不会在每次按键后重建全部高亮，并通过串行事件队列
处理快速输入。

## 演示

![从原生 Visual 选区进入同步 Insert](./demo/demo.gif)

演示包含四个流程：

1. 使用 Neovim 原生字符级 Visual 模式选择 `Color`，按 `<C-d>` 选择全部匹配项，
   再同步追加 `Token`。
2. 连续按 `<C-n>` 添加 `userName` 匹配项，再在所有选区前插入 `active_`。
3. 使用 `<C-Down>` 创建垂直光标，并同时修改相邻三行。
4. 重复按 `v`，从字符逐级扩展到单词、引号和完整调用参数，然后同步替换。

安装 [VHS](https://github.com/charmbracelet/vhs)、`ttyd` 和 `ffmpeg` 后可重新录制：

```sh
./demo/record-demo.sh
```

## 功能

- 支持 Normal、Insert、Extend 三种模式及同步多光标编辑。
- 可从当前单词、原生 Visual 选区、垂直位置或全部文本匹配项创建选区。
- 同步移动、插入、复制、删除、修改、粘贴、撤销，以及 `D`、`o`、`O`。
- 会话内使用 `v` / `V` 进行语义选区扩展和回退一级。
- 基于 Lua 与 Extmark，批量创建选区，并通过队列处理 Insert 更新。
- 紧凑状态栏会跟随 Neovim 真实光标所在选区。
- 支持 UTF-8、Buffer 独立会话，以及自定义快捷键和高亮。

## 安装

使用 `lazy.nvim`：

```lua
{
  "yaocccc/visual-multi.nvim",
  opts = {},
}
```

即使没有显式调用 `setup()`，插件也会使用默认配置加载。

## 默认快捷键

### 启动会话

| 快捷键 | 操作 |
| --- | --- |
| `<C-n>` | 选择单词 / 下一个匹配项 |
| `<C-d>` | 选择所有匹配项 |
| 原生 Visual + `<C-n>` | 使用当前选区并添加下一个匹配项 |
| 原生 Visual + `<C-d>` | 使用当前选区并选择全部匹配项 |
| `<C-Left>` / `<C-Right>` | 开始或扩展选区 |
| `<C-Up>` / `<C-Down>` | 向上 / 向下添加光标 |
| `<C-x>` | 在当前位置添加光标 |
| `<C-w>` | 添加当前位置的单词 |

### 会话期间

| 快捷键 | 操作 |
| --- | --- |
| `n` / `N` | 下一个 / 上一个匹配项 |
| `q` | 移除真实光标所在的选区 |
| `]` / `[` | 聚焦下一个 / 上一个光标 |
| `v` / `V` | 进入或扩大 Extend 选区 / 回退一级 |
| `h j k l w b e 0 ^ $` | 移动所有光标或扩展所有选区 |
| `i a I A` | 进入同步 Insert 模式 |
| `<C-v>` | 在 Insert 模式下向所有光标粘贴 |
| `o` / `O` | 在每个光标下方 / 上方新建一行并进入 Insert 模式 |
| `D` | 从每个光标处删除到对应行尾并进入 Insert 模式 |
| `c d x y p u` | 编辑所有选区 |
| `<Esc>` | Extend 恢复原 Normal 光标位置；Normal 下结束会话 |

原生 Visual 初始化目前支持单行字符级选区；`<C-Left>` 和 `<C-Right>` 仍可用于
插件自身管理的选区扩展。会话中重复按 `v` 会按照“字符 → 单词 → 引号/括号 →
整行”扩大选区，`V` 回退到上一级。`h`、`l`、`w`、`b`、`e` 不会跨出各光标当前所在行；
多光标会话不会覆盖 `gg` 和 `G`。

## 配置

```lua
require("visual-multi").setup({
  wrap = true,
  case_sensitive = true,
  mappings = {
    find_next = "<C-n>",
    select_all = "<C-d>",
    select_left = "<C-Left>",
    select_right = "<C-Right>",
    add_cursor_up = "<C-Up>",
    add_cursor_down = "<C-Down>",
    add_cursor = "<C-x>",
    add_cursor_word = "<C-w>",
    skip_region = false,
    remove_region = "q",
    insert_paste = "<C-v>",
    undo = "u",
    redo = "<C-r>",
  },
})
```

### 高亮

未传入 `highlights` 时使用内置配色。每个位置都可以传入已有高亮组名或颜色表；
颜色表配置会在 `ColorScheme` 后自动恢复：

```lua
highlights = {
  cursor = "MyCursorGroup",
  cursor_active = { bg = "#dfdf87", fg = "#4e4e4e", bold = true },
  insert = { bg = "#4c4e50" },
  insert_active = { bg = "#4c4e50" },
  selection = { bg = "#005faf" },
  selection_active = { bg = "#87afff", fg = "#4e4e4e" },
}
```

### 状态栏

默认 Bar 为紧凑扁平样式，背景仅覆盖实际内容，不会填满整行，也不依赖特殊字体。
如需覆盖默认样式，可传入格式化函数：

```lua
statusline = function(info)
  return ("%%#MyVisualMultiBar# %s %d/%d %%*")
    :format(info.mode, info.current, info.total)
end
```

将快捷键设为 `false` 即可禁用。设置 `statusline = false` 可禁用状态栏替换。
状态栏格式化函数会接收 `mode`、`current`、`total`、`pattern` 和当前选区
`text` 字段。

## 命令

- `:VisualMultiNext`
- `:VisualMultiAll`
- `:VisualMultiAdd`
- `:VisualMultiClear`
- `:VisualMultiInfo`

## 许可证

MIT
