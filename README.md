# visual-multi.nvim

<p align="center">
  <strong>English</strong> · <a href="./README.zh-CN.md">简体中文</a>
</p>

A small, native Lua multi-cursor plugin for **Neovim 0.12+**.

> [!IMPORTANT]
> This project evolved from the original
> [`mg979/vim-visual-multi`](https://github.com/mg979/vim-visual-multi)
> repository. The current Lua rewrite was implemented entirely by AI under user
> direction. It targets current Neovim only and does not preserve Vim or legacy
> `vim-visual-multi` compatibility.

The implementation uses Extmarks and granular buffer update events.

## Motivation

1. **Keep only the core workflow.** Remove legacy compatibility layers and
   advanced features that are not essential to selecting, navigating, and
   editing with multiple cursors.
2. **Improve performance substantially.** Use native Lua, Extmarks, batched
   selection creation, binary-search cursor lookup, and serialized Insert
   updates without per-keystroke full redraws.

### Approximate performance comparison

The following is a single headless run on the same machine with Neovim 0.12.4.
Each line contained one `foo`, and the benchmark selected every occurrence.
The numbers are indicative rather than a rigorous cross-machine benchmark.

| Matches | Original repository | Lua rewrite | Approx. speedup |
| ---: | ---: | ---: | ---: |
| 200 | 62.1 ms | 8.3 ms | 7.5× |
| 500 | 111.5 ms | 16.4 ms | 6.8× |
| 1,000 | 166.4 ms | 30.4 ms | 5.5× |
| 2,000 | 357.3 ms | 55.8 ms | 6.4× |

Large synchronized Insert sessions also avoid full highlight reconstruction on
every keypress and process rapid input through a serialized event queue.

## Features

- select the word under the cursor and its next/previous occurrences
- use an existing Extend selection as the pattern for next/all occurrence selection
- batch-create all literal occurrences without per-selection redraw or cursor movement
- add cursors vertically or at the current position
- navigate, skip, and remove cursors
- Normal, Insert, and Extend modes
- `<Tab>` switching between Normal and Extend modes
- soft light-gray background with gray-black text for the default statusline style
- statusline mode and current/total index follow the region under the real cursor
- synchronized `i`, `a`, `I`, and `A` insertion
- `<C-v>` pastes the per-cursor or unnamed register during synchronized Insert
- Insert updates use batched extmark reads, a serialized input queue, and no per-keystroke full redraw
- Insert cursor highlights track the next character without covering its text
- from Extend, `i` inserts at selection starts and `a` inserts after selections without deleting text
- yanking in Extend returns to Normal mode
- synchronized movement, selection, yank, delete, change, paste, and undo
- UTF-8-aware cursor highlighting
- buffer-local sessions with one undo block per multi-edit

## Installation

With `lazy.nvim`:

```lua
{
  "yaocccc/visual-multi.nvim",
  opts = {},
}
```

The plugin also loads with its defaults when `setup()` is not called explicitly.

## Default mappings

### Start a session

| Mapping | Action |
| --- | --- |
| `<C-n>` | Select word / next occurrence |
| `<C-Down>` | Add cursor below |
| `<C-Up>` | Add cursor above |
| `<leader>mc` | Add cursor at current position |
| `<leader>ma` | Select all occurrences |

### During a session

| Mapping | Action |
| --- | --- |
| `n` / `N` | Next / previous occurrence |
| `q` / `Q` | Skip / remove current region |
| `]` / `[` | Focus next / previous region |
| `<Tab>` | Toggle Normal / Extend mode |
| `h j k l w b e 0 ^ $ gg G` | Move cursors or extend selections |
| `i a I A` | Enter synchronized Insert mode |
| `<C-v>` | Paste at every cursor in Insert mode |
| `c d x y p u` | Edit all regions |
| `<Esc>` | End the session |

## Configuration

```lua
require("visual-multi").setup({
  wrap = true,
  case_sensitive = true,
  statusline = function(info)
    local text = info.text or info.pattern or ""
    local bar = ("%%#VisualMultiStatusMode# %s %%#VisualMultiStatusSep#│ "
      .. "%%#VisualMultiStatusCount#%d/%d"):format(info.mode, info.current, info.total)
    if text ~= "" then
      bar = bar .. " %#VisualMultiStatusSep#│ %#VisualMultiStatusText#" .. text
    end
    return bar .. " %#VisualMultiStatus#%="
  end,
  mappings = {
    find_next = "<C-n>",
    add_cursor_down = "<C-Down>",
    add_cursor_up = "<C-Up>",
    add_cursor = "<leader>mc",
    select_all = "<leader>ma",
    toggle_extend = "<Tab>",
    insert_paste = "<C-v>",
    clear = "<Esc>",
  },
})
```

Set a mapping to `false` to disable it. Set `statusline = false` to disable the
statusline replacement. The formatter receives `mode`, `current`, `total`,
`pattern`, and current selection `text` fields.

## Commands

- `:VisualMultiNext`
- `:VisualMultiAll`
- `:VisualMultiAdd`
- `:VisualMultiClear`
- `:VisualMultiInfo`

## License

MIT
