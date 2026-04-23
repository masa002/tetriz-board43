# Tetriz

[Board43](https://github.com/smartbank-inc/Board43) (RP2350A + WS2812 16×16 LED マトリクス) で動く落ちものパズル。PicoRuby のシングルファイル。

[English README](./README_en.md)

## 動かす

[Board43 Playground](https://smartbank-inc.github.io/Board43/) に `tetriz.rb` を貼って「デバイスで実行」。
自動起動させたいなら `~/app.rb` に置くか、`~/app.mrb` にコンパイルしておく。

必要なのは PicoRuby (`r2p2`) ファームウェアと `picoruby-ws2812-plus` gem。どちらも Board43 公式ファームウェアに入ってる。

## 操作

メニュー:

- `SW3` / `SW5` / `SW6` — ゲーム開始
- `SW4` — ミュート切替 (♪ マークの有無で表示)

ゲーム中:

- `SW3` — 左
- `SW4` — 回転 (壁ぎわでは自動でキックする)
- `SW5` — ソフトドロップ
- `SW6` — 右

## できること

- 16 列のうち中央 10 列がフィールド。左 2 列に NEXT ピース、右 2 列にレベルバー。
- 効果音と BGM は PWM ブザーから。SW4 で消音。
- ライン消しは消した本数で派手さが変わる。1: シアン、2: 緑、3: 黄、4 (TETRIZ!) は虹色フラッシュ。
- メインメニューは TETRIZ のドット絵 + 音符マーク。チラつき防止のため毎フレーム `led.clear` せず、ゲーム画面と同じく必要なピクセルだけを上書きしている。

## 設計メモ

- `tetriz.rb` 1 ファイル、約 700 行。
- 描画は WS2812 256 ピクセルへ直接書き込み。HSB 指定はテトリミノ色とフラッシュ用、それ以外は RGB で済ませて呼び出しコストを抑えている。
- `draw_next_preview` / `draw_level_bar` は前フレームから状態が変わってない時はスキップする小さなキャッシュ付き。メニュー復帰時に明示的に invalidate。
- フォント (TETRIZ) と音符アイコンは、ビットマップではなく「点灯セルだけのリスト」として持っている。条件分岐がいらない分速い。

## クレジット

RubyKaigi 2026 で [Board43](https://github.com/smartbank-inc/Board43) に出会えたから生まれたプロジェクト。
デバイスと PicoRuby の[ワークショップ教材](https://github.com/smartbank-inc/Board43/tree/main/workshop)を公開してくれている SmartBank さんに感謝。

## ライセンス

MIT。`LICENSE` を参照。
