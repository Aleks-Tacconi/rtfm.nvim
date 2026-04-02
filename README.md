# local-docs.nvim

Generate and store local markdown docs for languages/frameworks via pluggable adapters.

## Requirements

- `curl`
- `pandoc` (required for HTML -> Markdown conversion)

## Setup

```lua
require("local-docs").setup({
	ensure_installed = { "python" },
})
```

If `ensure_installed` is omitted, nothing is downloaded until `:LocalDocsInstall` is run.

## User Commands

- `:LocalDocsInstall <adapter>`
- `:LocalDocsUninstall <adapter>`

The command argument is completed from registered adapters.

## Registering Adapters

Built-in adapters are defined in `lua/local-docs.lua`:

```lua
M.adapters = {
	python = "local-docs.adapters.python",
}
```

You can register your own adapter module at runtime:

```lua
require("local-docs").register_adapter("my_lang", "my-plugin.adapters.my_lang")
```

## Creating a New Adapter

Create a file like `lua/local-docs/adapters/my_lang.lua` and return `Adapter.define(...)`.

```lua
local Adapter = require("local-docs.abc-adapter.adapter")
local Rule = require("local-docs.abc-adapter.rule")

return Adapter.define({
	doc = "my_lang",
	builtins = {
		url = "https://example.com/docs/index.html",
		seed_sources = {
			"https://example.com/docs/intro.html",
			"https://example.com/docs/functions.html",
		},
		documentation_rules = {
			Rule.tag("section"),
		},
		path_mapper = function(ctx)
			return ctx.source_name .. "/" .. ctx.section_id
		end,
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
- `path_mapper` (required): function receiving `ctx` and returning a relative output path without `.md`

`path_mapper(ctx)` receives:

- `ctx.source_url`: source page URL
- `ctx.source_path`: source page path, such as `/docs/functions.html`
- `ctx.source_name`: source page basename without `.html`
- `ctx.section_html`: raw HTML for the extracted section
- `ctx.section_index`: 1-based section index within the page
- `ctx.section_id`: first `id="..."` found in the extracted section
- `ctx.heading_text`: first heading text found in the extracted section

`path_mapper` is the only output naming mechanism. It must return a non-empty relative path like `os/system`.

Generated markdown is wrapped for terminal readability, and each output directory also gets a numbered `_index.md` file that preserves extraction order.

## Output Layout

Docs are written under `stdpath("data") .. "/local-docs/"`, typically:

```text
<data>/local-docs/
  python/
	  builtin/
		introduction/introduction.md
		introduction/_index.md
		compound_stmts/if.md
	  stdlib/
		os/system.md
		os/_index.md
	  misc/
```
