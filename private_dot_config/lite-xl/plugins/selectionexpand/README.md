# Selection Expand

Selection expansion known from other editors for Lite XL.

The plugin grows the current selection through increasingly larger syntax-like ranges: subwords, words, strings, brackets, lines, indentation blocks, keyword blocks, and finally the whole document. It also keeps a per-document expansion history so the previous selection can be restored.

## Features

- Expand with `ctrl+w`.
- Shrink with `ctrl+shift+w`.
- Supports camelCase and PascalCase subwords.
- Supports snake_case and kebab-case segments.
- Supports string contents and quoted strings.
- Supports single-line and multiline brackets.
- Supports current line, indentation blocks, keyword-like blocks, and whole document selection.
- Uses a weak-key per-document cache for document analysis and invalidates it when the document changes.

## Installation

Clone or download this repository, then copy it into your Lite XL plugins directory as `selectionexpand`:

```sh
git clone https://github.com/sp0rk/lite-xl-selectionexpand.git
cp -R lite-xl-selectionexpand ~/.config/lite-xl/plugins/selectionexpand
```

Restart Lite XL after copying the plugin.

## Keybindings

| Key | Command |
| --- | --- |
| `ctrl+w` | `selectionexpand:expand` |
| `ctrl+shift+w` | `selectionexpand:shrink` |

## Settings

The plugin exposes one setting:

```lua
config.plugins.selectionexpand.separate_camel_case_words = true
```

When enabled, camelCase and PascalCase identifiers expand by subword first. Set it to `false` to expand directly to the full identifier segment.

## Limitations

The plugin uses lightweight text heuristics rather than language parsers. Bracket matching skips quoted strings, and keyword block detection is intentionally broad so it can work across common languages, but it may not match every language-specific nesting rule.

## Manual Tests

- Expand and shrink repeatedly with `ctrl+w` and `ctrl+shift+w`.
- Toggle `config.plugins.selectionexpand.separate_camel_case_words` on and off.
- Expand camelCase and PascalCase identifiers.
- Expand snake_case and kebab-case identifiers.
- Expand string contents and quoted strings.
- Expand single-line and multiline bracket ranges.
- Expand a current line, indentation block, keyword block, and whole document.
- Edit after expansion, then confirm shrink does not restore stale selections.

## License

MIT
