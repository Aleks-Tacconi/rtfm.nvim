# local-docs.nvim

Generate and store local markdown docs for languages/frameworks via pluggable adapters.

## Setup

```lua
require("local-docs").setup({
	ensure_installed = { "python" },
})
```

`setup` also accepts a list directly:

```lua
require("local-docs").setup({ "python" })
```

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
		discover_sources = false,
		documentation_rules = {
			Rule.tag("section"),
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
- `seed_sources` (optional): list of full `https://...` source URLs
- `discover_sources` (optional, default `true`): discover sources from `url` using `source_rules`
- `source_rules` (optional): rule chain for extracting source URLs
- `documentation_rules` (optional): rule chain for extracting doc sections
- `name_rule` (optional): rule to derive output file names from sections

## Output Layout

Docs are written under `stdpath("data") .. "/local-docs/"`, typically:

```text
<data>/local-docs/
  python/
    builtin/
    stdlib/
    misc/
```
