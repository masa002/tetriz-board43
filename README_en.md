# Tetriz

Falling-blocks puzzle for [Board43](https://github.com/smartbank-inc/Board43) — an RP2350A board with a WS2812 16×16 LED matrix. A single PicoRuby file.

[日本語 README](./README.md)

## Run it

Open the [Board43 Playground](https://smartbank-inc.github.io/Board43/), paste in `tetriz.rb`, hit "Run on device". For autoboot, drop it at `~/app.rb` (or compile to `~/app.mrb`).

You need the PicoRuby `r2p2` firmware with `picoruby-ws2812-plus`. Both ship with the official Board43 firmware.

## Controls

Menu:

- `SW3` / `SW5` / `SW6` — start the game
- `SW4` — toggle mute (the ♪ glyph shows when sound is on)

In-game:

- `SW3` — left
- `SW4` — rotate (with wall-kick when needed)
- `SW5` — soft drop
- `SW6` — right

## What's in it

- 10-wide playfield in the middle of the 16-column matrix; NEXT preview on the left two columns, level bar on the right two.
- BGM and SFX through the PWM buzzer. SW4 mutes.
- Line-clear flashes scale with how many lines you cleared: cyan for a single, green for a double, yellow for a triple, rainbow for a TETRIZ.
- The menu uses pixel-art `TETRIZ` lettering plus a music note. To keep the matrix from flickering, the menu doesn't `led.clear` each frame — it overwrites the same pixels in place, the same way the in-game renderer does.

## Implementation notes

- A single `tetriz.rb`, around 700 lines.
- Pixels are written straight into the WS2812 256-LED buffer. HSB is used for tetromino colors and flash effects; everything else uses RGB so the per-call cost stays small.
- `draw_next_preview` and `draw_level_bar` skip when the relevant state hasn't changed since the last frame; the cache is invalidated explicitly when returning from the menu.
- Fonts (the `TETRIZ` glyphs) and the note icon are stored as flat lists of lit cells rather than bitmaps — no conditional per pixel, so the inner loop is short.

## Credits

This project exists because I came across [Board43](https://github.com/smartbank-inc/Board43) at RubyKaigi 2026.
Thanks to SmartBank for the device and the PicoRuby [workshop materials](https://github.com/smartbank-inc/Board43/tree/main/workshop).

## License

MIT. See `LICENSE`.
