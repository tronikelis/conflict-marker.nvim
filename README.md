# conflict-marker.nvim


The simple git conflict resolver for neovim


![image](https://github.com/user-attachments/assets/5d4861a4-fabe-4569-a2e3-a3bfb2c9bc53)

<details>
  <summary>quick demo</summary>


https://github.com/user-attachments/assets/bb4c5abd-9475-4aaa-84e2-5cb5cbfdfd8e



</details>


You can customize these colors, I just picked something at random :P


<!--toc:start-->
- [conflict-marker.nvim](#conflict-markernvim)
  - [Philosophy](#philosophy)
  - [Features](#features)
  - [User commands](#user-commands)
  - [Highlighting](#highlighting)
    - [Groups](#groups)
  - [Config](#config)
  - [Recipes](#recipes)
    - [Jump to markers](#jump-to-markers)
    - [extra keymaps (co, ct, etc...)](#extra-keymaps-co-ct-etc)
<!--toc:end-->


## Philosophy

- it has to be simple (in fact whole plugin is ~400 lua loc)
- performance-first (finding conflicts does not load whole buf into extra memory)


## Features
- [x] highlights
- [x] resolving conflicts
- [x] diff3 style

## User commands

- `Conflict ours`: resolves the conflict under the cursor with our changes
- `Conflict theirs`: resolves the conflict under the cursor with their changes
- `Conflict both`: resolves the conflict under the cursor with both changes (removes markers)
- `Conflict none`: resolves the conflict the best way possible, just removing it xd

## Highlighting

Highlighting is enabled by default but can be disabled by setting `highlights = false` in config

Note for `nvimdiff` users !!!: if highlighting is enabled, the `Diff*` hl groups are disabled in buffers which have a
conflict, because those groups interfere heavily with `conflict-marker.nvim` highlighting

### Groups

- `ConflictOursMarker`
- `ConflictOurs`
- `ConflictTheirs`
- `ConflictTheirsMarker`
- `ConflictMid`
- `ConflictBaseMarker`
- `ConflictBase`

## Config

```lua
require("conflict-marker").setup({
  highlights = true,
  on_attach = function(conflict) end,
})
```

## Recipes

### Jump to markers

```lua
require("conflict-marker").setup({
  on_attach = function(conflict)
    local MID = "^=======$"

    vim.keymap.set("n", "[x", function()
      vim.cmd("?" .. MID)
    end, { buffer = conflict.bufnr })

    vim.keymap.set("n", "]x", function()
      vim.cmd("/" .. MID)
    end, { buffer = conflict.bufnr })
  end,
})

```

### extra keymaps (co, ct, etc...)


```lua
require("conflict-marker").setup({
  on_attach = function(conflict)
    local map = function(key, fn)
      vim.keymap.set("n", key, fn, { buffer = conflict.bufnr })
    end

    -- or you can map these to <cmd>ChooseOurs<cr>

    map("co", function()
      conflict:choose_ours()
    end)
    map("ct", function()
      conflict:choose_theirs()
    end)
    map("cb", function()
      conflict:choose_both()
    end)
    map("cn", function()
      conflict:choose_none()
    end)
  end,
})

```
