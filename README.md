<br/>
<br/>

<div align="center">
  <img src="assets/logo.png" alt="rtfm.nvim" width="480"/>
</div>

<br/>

<div align="center">

<strong>Read The Friendly Manual ● Download and search through official documentation ● Standardized documentation format for every framework</strong>

</div>

<div align="center">

<img src="https://img.shields.io/badge/Lua-2C2D72?style=for-the-badge&logo=lua&logoColor=white" alt="Lua" />
&nbsp;
<img src="https://img.shields.io/badge/Neovim-57A143?style=for-the-badge&logo=neovim&logoColor=white" alt="Neovim" />
&nbsp;
<img src="https://img.shields.io/badge/Markdown-2F333A?style=for-the-badge&logo=markdown&logoColor=white" alt="Markdown" />
&nbsp;
<img src="https://img.shields.io/badge/Offline-3A4A3F?style=for-the-badge&logo=bookstack&logoColor=white" alt="Offline" />
&nbsp;
<img src="https://img.shields.io/badge/Adapters-3F7A32?style=for-the-badge&logo=socketdotio&logoColor=white" alt="Adapters" />

</div>

<br/>
<br/>

## About

Generate and store local markdown docs for languages/frameworks via pluggable adapters.
...

## Requirements

- `curl`
- `pandoc` (required for HTML -> Markdown conversion)
- `telescope.nvim` (required for `:RtfmBrowse`)

## Setup

```lua
require("rtfm").setup({
	ensure_installed = { "python" },
})
```

If `ensure_installed` is omitted, nothing is downloaded until `:RtfmInstall` is run.

Adapter installs run in the background. Startup is not blocked, so docs may finish appearing shortly after Neovim loads.

Background installs keep a live notification spinner active while docs are downloading and converting.

You can bind the browse and viewer commands in your own config:

```lua
vim.keymap.set("n", "<leader>rb", "<cmd>RtfmBrowse<cr>")
vim.keymap.set("n", "]d", "<cmd>RtfmDocNext<cr>")
vim.keymap.set("n", "[d", "<cmd>RtfmDocPrev<cr>")
```

## User Commands

- `:RtfmInstall <adapter>`
- `:RtfmUninstall <adapter>`
- `:RtfmBrowse`
- `:RtfmDocNext`
- `:RtfmDocPrev`

The command argument is completed from registered adapters.

If an install for the same adapter scope is already running, a second install request is rejected instead of overlapping.

`:RtfmBrowse` uses Telescope to traverse adapter -> scope -> source -> doc. Scope ordering is read from the generated `_index.md`, and the selected doc opens in a dedicated viewer buffer with a floating previous/current/next overlay.

If a scope has no `_index.md`, browsing that scope fails with a message telling you to run `:RtfmInstall <adapter>` first.

## Registering Adapters

Built-in adapters are defined in `lua/rtfm.lua`:

```lua
	M.adapters = {
	python = "rtfm.adapters.python",
}
```

You can register your own adapter module at runtime:

```lua
require("rtfm").register_adapter("my_lang", "my-plugin.adapters.my_lang")
```

## Creating a New Adapter

Create a file like `lua/rtfm/adapters/my_lang.lua` and return `Adapter.define(...)`.

```lua
local Adapter = require("rtfm.abc-adapter.adapter")
local Rule = require("rtfm.abc-adapter.rule")

return Adapter.define({
	doc = "my_lang",
	builtins = {
		url = "https://example.com/docs/index.html",
		seed_sources = {
			"https://example.com/docs/intro.html",
			"https://example.com/docs/functions.html",
		},
		documentation_rules = {
			Rule.deep_tag("section"),
			Rule.heading_level(2),
		},
		name_rule = Rule.regex([[<section id="\zs[^"]\+\ze"]]),
	},
})
```

### Adapter Spec Fields

- `doc`: output directory name (for example `python`)
- `builtins` / `stdlib` / `misc`: optional crawler specs

Crawler spec:

- `url` (required): root docs URL
- `seed_sources` (optional): additional full `https://...` source URLs to include
- `source_rules` (optional): rule chain for extracting source URLs from `url` (if empty, discovery is skipped)
- `documentation_rules` (required): rule chain for extracting doc sections
- `name_rule` (required): rule that extracts the section name from each documentation fragment

Useful rule helpers:

- `Rule.tag("section")`: top-level matching tags
- `Rule.deep_tag("section")`: nested matching tags as well
- `Rule.heading_level(2)`: keep only fragments whose first heading is `h2`

Docs are always written as:

`<scope>/<source_name>/<normalized_name>.md`

Normalization is fixed in core:

- if the extracted name starts with `<source_name>.`, that prefix is removed
- `._...` becomes `__`
- remaining `.` become `__`

Examples:

- `os.system` -> `os/system.md`
- `os.PathLike.__fspath__` -> `os/PathLike__fspath__.md`
- `os.stat_result.st_mode` -> `os/stat_result__st_mode.md`

Generated markdown is wrapped for terminal readability, and each scope root gets a numbered `_index.md` file that preserves extraction order.

## Output Layout

Docs are written under `stdpath("data") .. "/rtfm/"`, typically:

```text
<data>/rtfm/
  python/
	  builtin/
		introduction/introduction.md
		compound_stmts/if.md
		_index.md
	  stdlib/
		os/system.md
		_index.md
	  misc/
```
