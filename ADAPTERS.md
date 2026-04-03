# Adapters

If the adapter you want is not built-in, you can register your own adapter module at runtime or create a new adapter for the project.

## Registering Adapters

Built-in adapters are defined in `lua/rtfm.lua`:

```lua
M.adapters = {
  go = "rtfm.adapters.go",
  python = "rtfm.adapters.python",
	...
}
```

You can register your own adapter module at runtime:

```lua
require("rtfm").register_adapter("my_lang", "my-plugin.adapters.my_lang")
```

If you build a generally useful adapter, feel free to open a merge request and contribute it upstream.

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


### Crawler Spec


| Field | Required | Description |
| --- | --- | --- |
| `url` | Yes | Root docs URL used for discovery. |
| `seed_sources` | No | Additional full `https://...` source URLs to include before discovery runs. |
| `source_rules` | No | Rule chain for extracting source URLs from `url`. If empty, discovery is skipped. |
| `source_filter` | No | Function that receives each resolved source URL and returns `true` to keep it or `false` to skip it. |
| `request_delay_ms` | No | Delay in milliseconds before fetching each source page. Useful for rate-limited doc sites. |
| `retry_failed_fetches` | No | When `true`, keeps retrying failed HTTP fetches until they succeed. |
| `retry_delay_ms` | No | Delay in milliseconds between fetch retries when `retry_failed_fetches` is enabled. |
| `documentation_rules` | Yes | Rule chain for extracting doc sections from each source page. |
| `name_rule` | Yes | Rule that extracts the section name from each documentation fragment. |


### Available Rule Helpers


| Helper | What it matches | Example |
| --- | --- | --- |
| `Rule.tag("section")` | Top-level HTML elements by tag name. | `Rule.tag("section")` |
| `Rule.deep_tag("section")` | HTML elements by tag name, including nested matches. | `Rule.deep_tag("section")` |
| `Rule.selector(".py")` | Full HTML elements by `.class` or `#id` selector. | `Rule.selector(".py")`, `Rule.selector("#module-string")` |
| `Rule.heading_level(2)` | Keeps only fragments whose first heading is `h2`. | `Rule.heading_level(2)` |
| `Rule.regex([[...]])` | All matches for a Vim regex expression. Use this for link extraction or custom name parsing. | `Rule.regex([[<a href="\zs[^"]\+\ze"]])` |


> `Rule.regex(...)` uses Vim regex syntax.
