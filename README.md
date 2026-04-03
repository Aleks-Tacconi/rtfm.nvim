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
- `Nerd Font` (optional, for viewer icons)
- `telescope.nvim` (required for `:RtfmBrowse`)

## Setup

```lua
require("rtfm").setup({
	ensure_installed = { "python", "go" },
	viewer = {
		keymaps = {
			prev = "[d",
			next = "]d",
		},
	},
})
```

If `ensure_installed` is omitted, nothing is downloaded until you install an adapter from `:RtfmManage`.

Manager-driven installs and removals run inside a modal progress window. Startup installs triggered by `ensure_installed` still run in the background.

The viewer applies buffer-local navigation mappings from `setup().viewer.keymaps`. Set either side to `false` or `""` to disable it.

You can still bind the browse command in your own config:

```lua
vim.keymap.set("n", "<leader>rb", "<cmd>RtfmBrowse<cr>")
```

## User Commands

- `:RtfmManage`
- `:RtfmBrowse`
- `:RtfmDocNext`
- `:RtfmDocPrev`

`:RtfmManage` opens a floating adapter manager with two sections: installed and not installed. Use `j/k` to move, `<CR>` to install or remove the selected adapter, and `q` to close the window.

If an install for the same adapter scope is already running, a second install request is rejected instead of overlapping.

If source discovery or extraction returns no docs, the install now fails instead of replacing the scope with an empty result.

`:RtfmBrowse` uses Telescope to traverse adapter -> scope -> source -> doc. Scope ordering is read from the generated `_index.md`, and the selected doc opens in a dedicated viewer buffer with a bottom status bar showing previous/current/next docs.

If a scope has no `_index.md`, browsing that scope fails with a message telling you to install it from `:RtfmManage` first.

## Registering Adapters

Built-in adapters are defined in `lua/rtfm.lua`:

```lua
	M.adapters = {
	go = "rtfm.adapters.go",
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


| Field | Required | Description |
| --- | --- | --- |
| `doc` | Yes | Output directory name, for example `python`. |
| `builtins` / `stdlib` / `misc` | No | Optional crawler specs for each scope. |


### Crawler spec


| Field | Required | Description |
| --- | --- | --- |
| `url` | Yes | Root docs URL used for discovery. |
| `seed_sources` | No | Additional full `https://...` source URLs to include before discovery runs. |
| `source_rules` | No | Rule chain for extracting source URLs from `url`. If empty, discovery is skipped. |
| `documentation_rules` | Yes | Rule chain for extracting doc sections from each source page. |
| `name_rule` | Yes | Rule that extracts the section name from each documentation fragment. |


### Available rule helpers


| Helper | What it matches | Example |
| --- | --- | --- |
| `Rule.tag("section")` | Top-level HTML elements by tag name. | `Rule.tag("section")` |
| `Rule.deep_tag("section")` | HTML elements by tag name, including nested matches. | `Rule.deep_tag("section")` |
| `Rule.selector(".py")` | Full HTML elements by `.class` or `#id` selector. | `Rule.selector(".py")`, `Rule.selector("#module-string")` |
| `Rule.heading_level(2)` | Keeps only fragments whose first heading is `h2`. | `Rule.heading_level(2)` |
| `Rule.regex([[...]])` | All matches for a Vim regex expression. Use this for link extraction or custom name parsing. | `Rule.regex([[<a href="\zs[^"]\+\ze"]])` |


> `Rule.regex(...)` uses Vim regex syntax.

## Output Layout

Docs are written under `stdpath("data") .. "/rtfm/"`, typically:

```text
<data>/rtfm/
  go/
	  builtin/
		builtin/pkg-overview.md
		builtin/pkg-functions.md
		_index.md
	  stdlib/
		net/http/pkg-overview.md
		fmt/pkg-functions.md
		_index.md
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
