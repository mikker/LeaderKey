<img src="https://s3.brnbw.com/icon_1024-akc2Ij3q9JOyhQ6Y7Lz6AFkX6nQQFhrQaRPqbV4vor0A62EA0vq4xOGrXpg6PVKi3aUJxOAyItkyktblPtZD4K4oYZ1bJVdh96VE.png" width="256" height="256" alt="Leader Key.app" />

**The \*faster than your launcher\* launcher**

A riff on [Raycast](https://www.raycast.com), [@mxstbr's multi-key Karabiner setup](https://www.youtube.com/watch?v=m5MDv9qwhU8&t=540s), and Vim's `<leader>` key.

Watch the intro video on YouTube:

<div>
<a href="https://www.youtube.com/watch?v=EQYakLsYSAQ"><img src="https://img.youtube.com/vi/EQYakLsYSAQ/maxresdefault.jpg" width=480></a>
<a href="https://www.youtube.com/watch?v=hzzQl5FOL-k"><img src="https://img.youtube.com/vi/hzzQl5FOL-k/maxresdefault.jpg" width=480></a>
</div>

*Yes, I only have that one thumbnail face.*

📦 [Download latest version](https://github.com/mikker/LeaderKey.app/releases)

```sh
$ brew install leader-key
```

## Why Leader Key?

### Problems with traditional launchers:

1. Typing the name of the thing can be slow and give unpredictable results.
2. Global shortcuts have limited combinations.
3. Leader Key offers predictable, nested shortcuts -- like combos in a fighting game.

### Example Shortcuts:

- <kbd>leader</kbd><kbd>o</kbd><kbd>m</kbd> → Launch Messages (`open messages`)
- <kbd>leader</kbd><kbd>m</kbd><kbd>m</kbd> → Mute audio (`media mute`)
- <kbd>leader</kbd><kbd>w</kbd><kbd>m</kbd> → Maximize current window (`window maximize`)

## FAQ

#### What do I set as my Leader Key?

Any key can be your leader key, but **only modifiers will not work**.

**Examples:**

- <kbd>F12</kbd>
- <kbd>⌘ + space</kbd>
- <kbd>⌘⌥ + space</kbd>
- <kbd>⌘⌥⌃⇧ + L</kbd> (hyper key)

**Advanced examples:**

Using [Karabiner](https://karabiner-elements.pqrs.org/) you can do more fancy things like:

- <kbd>right ⌘ + left ⌘</kbd> at once (bound to <kbd>F12</kbd>) my personal favorite
- <kbd>caps lock</kbd> (bound to <kbd>hyper</kbd> when held, <kbd>F12</kbd> when pressed)

See [@mikker's config](https://github.com/mikker/LeaderKey.app/wiki/@mikker's-config) in the wiki for akimbo cmds example.

#### I disabled the menubar item, how can I get Leader Key back?

Activate Leader Key, then <kbd>cmd + ,</kbd>.

#### Command action is failing with "Command not found"

You need to make sure your shell environment is correctly set up for non-interactive mode, and exports the `PATH` variable.

**For zsh** make sure you have your `PATH` variable exported in `~/.zshenv`

**For bash** make sure you have your `PATH` variable exported in `~/.bash_profile`


## License

MIT
