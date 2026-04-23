# Board43: Tetriz
#
# メインメニュー:
#   SW4:          ミュート切替
#   SW3/SW5/SW6:  ゲーム開始
#
# ゲーム中:
#   SW3: 左移動
#   SW4: 回転
#   SW5: ソフトドロップ（高速落下）
#   SW6: 右移動
#
# 左マージン: NEXT ピースプレビュー
# 右マージン: レベル表示バー
#
# Features: Switches (GPIO) + WS2812 16x16 matrix + Buzzer (PWM) + BGM

require 'ws2812-plus'
require 'pwm'

led    = WS2812.new(pin: Board43::GPIO_LEDOUT, num: 256)
buzzer = PWM.new(Board43::GPIO_BUZZER, frequency: 0, duty: 50)

sw3 = GPIO.new(Board43::GPIO_SW3, GPIO::IN | GPIO::PULL_UP)  # 左
sw4 = GPIO.new(Board43::GPIO_SW4, GPIO::IN | GPIO::PULL_UP)  # 回転 / ミュート
sw5 = GPIO.new(Board43::GPIO_SW5, GPIO::IN | GPIO::PULL_UP)  # 落下
sw6 = GPIO.new(Board43::GPIO_SW6, GPIO::IN | GPIO::PULL_UP)  # 右

COLS = 10
ROWS = 16
OX   = 3  # 16列の中央に10列フィールドを配置するオフセット

# テトリミノ: [piece][rot][cell] = [dr, dc]
# I
P0R0 = [[0,0],[0,1],[0,2],[0,3]]
P0R1 = [[0,2],[1,2],[2,2],[3,2]]
P0R2 = [[2,0],[2,1],[2,2],[2,3]]
P0R3 = [[0,1],[1,1],[2,1],[3,1]]
# O
P1R0 = [[0,0],[0,1],[1,0],[1,1]]
P1R1 = [[0,0],[0,1],[1,0],[1,1]]
P1R2 = [[0,0],[0,1],[1,0],[1,1]]
P1R3 = [[0,0],[0,1],[1,0],[1,1]]
# T
P2R0 = [[0,1],[1,0],[1,1],[1,2]]
P2R1 = [[0,1],[1,1],[1,2],[2,1]]
P2R2 = [[1,0],[1,1],[1,2],[2,1]]
P2R3 = [[0,1],[1,0],[1,1],[2,1]]
# S
P3R0 = [[0,1],[0,2],[1,0],[1,1]]
P3R1 = [[0,1],[1,1],[1,2],[2,2]]
P3R2 = [[1,1],[1,2],[2,0],[2,1]]
P3R3 = [[0,0],[1,0],[1,1],[2,1]]
# Z
P4R0 = [[0,0],[0,1],[1,1],[1,2]]
P4R1 = [[0,2],[1,1],[1,2],[2,1]]
P4R2 = [[1,0],[1,1],[2,1],[2,2]]
P4R3 = [[0,1],[1,0],[1,1],[2,0]]
# J
P5R0 = [[0,0],[1,0],[1,1],[1,2]]
P5R1 = [[0,1],[0,2],[1,1],[2,1]]
P5R2 = [[1,0],[1,1],[1,2],[2,2]]
P5R3 = [[0,1],[1,1],[2,0],[2,1]]
# L
P6R0 = [[0,2],[1,0],[1,1],[1,2]]
P6R1 = [[0,1],[1,1],[2,1],[2,2]]
P6R2 = [[1,0],[1,1],[1,2],[2,0]]
P6R3 = [[0,0],[0,1],[1,1],[2,1]]

SHAPES = [
  [P0R0, P0R1, P0R2, P0R3],
  [P1R0, P1R1, P1R2, P1R3],
  [P2R0, P2R1, P2R2, P2R3],
  [P3R0, P3R1, P3R2, P3R3],
  [P4R0, P4R1, P4R2, P4R3],
  [P5R0, P5R1, P5R2, P5R3],
  [P6R0, P6R1, P6R2, P6R3],
]

# ピース色 [H, S, B]
PC = [
  [180, 100, 60],  # I シアン
  [ 55, 100, 60],  # O 黄
  [280, 100, 60],  # T 紫
  [120, 100, 60],  # S 緑
  [  0, 100, 60],  # Z 赤
  [220, 100, 60],  # J 青
  [ 28, 100, 60],  # L オレンジ
]

# NEXT プレビュー用の形状（左マージン 2 列幅に収まるよう正規化）
PREVIEW = [
  [[0,0],[1,0],[2,0],[3,0]],   # I: 縦 4 連
  [[0,0],[0,1],[1,0],[1,1]],   # O: 2x2
  [[0,0],[1,0],[1,1],[2,0]],   # T (右向き)
  [[0,0],[1,0],[1,1],[2,1]],   # S
  [[0,1],[1,0],[1,1],[2,0]],   # Z
  [[0,0],[0,1],[1,0],[2,0]],   # J
  [[0,0],[1,0],[2,0],[2,1]],   # L
]

# BGM: コロブチカ風メロディ（簡略化）。各要素 [freq_Hz, duration_ms]。0 Hz = 休符
BGM = [
  # 1小節目
  [659, 400], [494, 200], [523, 200], [587, 400], [523, 200], [494, 200],
  # 2小節目
  [440, 400], [440, 200], [523, 200], [659, 400], [587, 200], [523, 200],
  # 3小節目
  [494, 600], [523, 200], [587, 400], [659, 400],
  # 4小節目
  [523, 400], [440, 400], [440, 400], [0, 400],
  # 5小節目
  [587, 400], [698, 200], [880, 400], [784, 200], [698, 200],
  # 6小節目
  [659, 600], [523, 200], [659, 400], [587, 200], [523, 200],
  # 7小節目
  [494, 400], [494, 200], [523, 200], [587, 400], [659, 400],
  # 8小節目
  [523, 400], [440, 400], [440, 400], [0, 400],
]

class SimpleRand
  def initialize(seed = 7)
    @seed = seed
  end
  def rand(max)
    @seed = (@seed * 1103515245 + 12345) & 0x7fffffff
    @seed % max
  end
end

# ========== 盤面操作 ==========

def make_board
  Array.new(ROWS * COLS, -1)
end

def get_cells(pid, rot, pr, pc)
  shape = SHAPES[pid][rot]
  cells = Array.new(4, nil)
  i = 0
  while i < 4
    cells[i] = [pr + shape[i][0], pc + shape[i][1]]
    i += 1
  end
  cells
end

def valid_pos(cells, board)
  i = 0
  while i < 4
    r = cells[i][0]
    c = cells[i][1]
    if c < 0 || c >= COLS || r >= ROWS
      return false
    end
    if r >= 0 && board[r * COLS + c] >= 0
      return false
    end
    i += 1
  end
  true
end

def lock(cells, pid, board)
  i = 0
  while i < 4
    r = cells[i][0]
    c = cells[i][1]
    if r >= 0
      board[r * COLS + c] = pid
    end
    i += 1
  end
end

def clear_lines(board)
  cleared = 0
  r = ROWS - 1
  while r >= 0
    full = true
    c = 0
    while c < COLS
      if board[r * COLS + c] < 0
        full = false
        break
      end
      c += 1
    end
    if full
      rr = r
      while rr > 0
        c = 0
        while c < COLS
          board[rr * COLS + c] = board[(rr - 1) * COLS + c]
          c += 1
        end
        rr -= 1
      end
      c = 0
      while c < COLS
        board[c] = -1
        c += 1
      end
      cleared += 1
    else
      r -= 1
    end
  end
  cleared
end

# ========== サウンド（BGM + 非ブロッキングSFX） ==========

def buzz(buzzer, freq, muted)
  if muted
    buzzer.frequency(0)
  else
    buzzer.frequency(freq)
  end
end

def tick_sound(buzzer, frame_ms, state, muted)
  if state[:sfx_remaining] > 0
    # SFX 再生中: 終わったら BGM の現在音を再開
    state[:sfx_remaining] -= frame_ms
    if state[:sfx_remaining] <= 0
      state[:sfx_remaining] = 0
      state[:bgm_elapsed] = 0
      note = BGM[state[:bgm_idx]]
      buzz(buzzer, note[0], muted)
    end
  else
    state[:bgm_elapsed] += frame_ms
    note = BGM[state[:bgm_idx]]
    if state[:bgm_elapsed] >= note[1]
      state[:bgm_elapsed] -= note[1]
      state[:bgm_idx] = (state[:bgm_idx] + 1) % BGM.length
      new_note = BGM[state[:bgm_idx]]
      buzz(buzzer, new_note[0], muted)
    end
  end
end

def play_sfx(buzzer, state, freq, duration_ms, muted)
  state[:sfx_remaining] = duration_ms
  buzz(buzzer, freq, muted)
end

# ========== 描画 ==========

# 描画キャッシュ。前フレームと同じなら再描画スキップ。menu_loop 復帰時に reset。
DRAW_CACHE = { next_pid: -2, level: -2 }

def reset_draw_cache
  DRAW_CACHE[:next_pid] = -2
  DRAW_CACHE[:level]    = -2
end

def draw_next_preview(led, pid)
  # 左マージン cols 0-1 に NEXT ピースの実際の形を表示
  return if DRAW_CACHE[:next_pid] == pid
  DRAW_CACHE[:next_pid] = pid

  color = PC[pid]
  shape = PREVIEW[pid]

  # 左マージン全体を一旦黒でクリア
  r = 0
  while r < 16
    led.set_rgb(r * 16,     0, 0, 0)
    led.set_rgb(r * 16 + 1, 0, 0, 0)
    r += 1
  end

  # プレビュー領域 (rows 1-4, cols 0-1) を暗い背景で初期化
  r = 1
  while r <= 4
    c = 0
    while c < 2
      led.set_rgb(r * 16 + c, 2, 2, 4)
      c += 1
    end
    r += 1
  end

  # ピース形状描画
  i = 0
  while i < 4
    dr = shape[i][0]
    dc = shape[i][1]
    led.set_hsb((1 + dr) * 16 + dc, color[0], color[1], color[2])
    i += 1
  end
end

def draw_level_bar(led, level)
  # 右マージン cols 14-15: レベル表示（下から積み上がる）
  return if DRAW_CACHE[:level] == level
  DRAW_CACHE[:level] = level

  bar_height = level
  if bar_height > 14
    bar_height = 14
  end
  hue = 120 - level * 8
  if hue < 0
    hue = 0
  end

  r = 0
  while r < 16
    c = 14
    while c < 16
      idx = r * 16 + c
      if r == 0
        led.set_rgb(idx, 12, 12, 12)
      elsif r >= 16 - bar_height
        led.set_hsb(idx, hue, 100, 50)
      else
        led.set_rgb(idx, 2, 2, 4)
      end
      c += 1
    end
    r += 1
  end
end

def draw_board(led, board, cells, pid, next_pid, level)
  # フィールド背景
  r = 0
  while r < ROWS
    c = 0
    while c < COLS
      idx = r * 16 + (c + OX)
      v = board[r * COLS + c]
      if v >= 0
        led.set_hsb(idx, PC[v][0], PC[v][1], PC[v][2])
      else
        led.set_rgb(idx, 4, 4, 8)
      end
      c += 1
    end
    r += 1
  end

  # 壁 (プレイフィールドの左右境界を明示)
  r = 0
  while r < ROWS
    led.set_rgb(r * 16 + OX - 1,    80, 80, 100)
    led.set_rgb(r * 16 + OX + COLS, 80, 80, 100)
    r += 1
  end

  # サイドパネル (余白を情報表示として使う)
  draw_next_preview(led, next_pid)
  draw_level_bar(led, level)

  # 落下中ピース（明るめ）
  color = PC[pid]
  i = 0
  while i < 4
    r = cells[i][0]
    c = cells[i][1]
    if r >= 0 && r < ROWS && c >= 0 && c < COLS
      idx = r * 16 + (c + OX)
      b = color[2] + 25
      if b > 100
        b = 100
      end
      led.set_hsb(idx, color[0], color[1], b)
    end
    i += 1
  end

  led.show
end

# ====== メニュー描画 ======
# glyph は点灯セル [dr, dc] のリスト

# 3x5 フォント
F_T_LIT = [[0,0],[0,1],[0,2],[1,1],[2,1],[3,1],[4,1]]
F_E_LIT = [[0,0],[0,1],[0,2],[1,0],[2,0],[2,1],[3,0],[4,0],[4,1],[4,2]]
F_R_LIT = [[0,0],[0,1],[1,0],[1,2],[2,0],[2,1],[3,0],[3,2],[4,0],[4,2]]
F_I_LIT = [[0,0],[0,1],[0,2],[1,1],[2,1],[3,1],[4,0],[4,1],[4,2]]
F_Z_LIT = [[0,0],[0,1],[0,2],[1,2],[2,1],[3,0],[4,0],[4,1],[4,2]]

TITLE_LITS     = [F_T_LIT, F_E_LIT, F_T_LIT, F_R_LIT, F_I_LIT, F_Z_LIT]
TITLE_HUES     = [180, 55, 280, 120, 0, 28]   # I, O, T, S, Z, L
TITLE_STARTS_C = [3, 7, 11]

# 音符 ♪ (4x4)
NOTE_LIT = [[0,2],[0,3],[1,2],[2,0],[2,1],[2,2],[3,0],[3,1]]

def draw_menu(led, muted)
  # led.clear は即時 LED 反映で点滅するので使わない（初期 clear は menu_loop 側）

  # タイトル
  i = 0
  while i < 6
    lit = TITLE_LITS[i]
    hue = TITLE_HUES[i]
    if i < 3
      base_r = 1
      base_c = TITLE_STARTS_C[i]
    else
      base_r = 7
      base_c = TITLE_STARTS_C[i - 3]
    end
    j = 0
    n = lit.length
    while j < n
      cell = lit[j]
      led.set_hsb((base_r + cell[0]) * 16 + (base_c + cell[1]), hue, 100, 65)
      j += 1
    end
    i += 1
  end

  # 音符（ミュート時は黒で上書きして消す）
  if muted
    nr = 0
    ng = 0
    nb = 0
  else
    nr = 0
    ng = 70
    nb = 10
  end
  i = 0
  n = NOTE_LIT.length
  while i < n
    cell = NOTE_LIT[i]
    led.set_rgb((12 + cell[0]) * 16 + (6 + cell[1]), nr, ng, nb)
    i += 1
  end

  led.show
end

def menu_loop(led, buzzer, sw3, sw4, sw5, sw6, muted)
  sw4_prev = true

  # 入場時のみ clear（ゲーム残骸を消す）
  led.clear
  draw_menu(led, muted)

  # 直前の操作が残っていたら全ボタンリリース待ち
  while sw3.low? || sw4.low? || sw5.low? || sw6.low?
    sleep_ms 50
  end

  loop do
    sleep_ms 50

    sw4_now = sw4.low?
    if sw4_now && !sw4_prev
      muted = !muted
      draw_menu(led, muted)
      # 解除した瞬間だけ確認音
      if !muted
        buzzer.frequency(880)
        sleep_ms 60
        buzzer.frequency(0)
      end
    end
    sw4_prev = sw4_now

    if sw3.low? || sw5.low? || sw6.low?
      while sw3.low? || sw5.low? || sw6.low?
        sleep_ms 30
      end
      sleep_ms 100
      reset_draw_cache
      return muted
    end
  end
end

def line_clear_effect(led, cleared)
  # 1: シアン x2,  2: 緑 x3,  3: 黄 x4,  4 (TETRIZ!): 虹色 x4
  if cleared >= 4
    flashes = 4
    rainbow = true
    base_hue = 0
  else
    flashes = cleared + 1
    rainbow = false
    if cleared == 1
      base_hue = 180
    elsif cleared == 2
      base_hue = 120
    else
      base_hue = 50
    end
  end

  i = 0
  while i < flashes
    if rainbow
      hue = (i * 90) % 360
    else
      hue = base_hue
    end

    r = 0
    while r < ROWS
      c = 0
      while c < COLS
        led.set_hsb(r * 16 + (c + OX), hue, 100, 90)
        c += 1
      end
      r += 1
    end
    led.show
    sleep_ms 55

    # 背景色に戻す
    r = 0
    while r < ROWS
      c = 0
      while c < COLS
        led.set_rgb(r * 16 + (c + OX), 4, 4, 8)
        c += 1
      end
      r += 1
    end
    led.show
    sleep_ms 35

    i += 1
  end
end

def game_over_anim(led, buzzer, muted)
  t = 0
  while t < 3
    led.fill(180, 0, 0)
    led.show
    sleep_ms 120
    led.clear
    led.show
    sleep_ms 120
    t += 1
  end
  buzz(buzzer, 300, muted)
  sleep_ms 150
  buzz(buzzer, 200, muted)
  sleep_ms 300
  buzzer.frequency(0)
end

# ========== メインループ ==========

rng   = SimpleRand.new
muted = false

loop do
  muted = menu_loop(led, buzzer, sw3, sw4, sw5, sw6, muted)

  board   = make_board
  score   = 0
  level   = 1
  fall_ms = 600

  pid      = rng.rand(7)
  next_pid = rng.rand(7)
  rot      = 0
  pr       = -1
  pc       = COLS / 2 - 2

  sound_state = { bgm_idx: 0, bgm_elapsed: 0, sfx_remaining: 0 }
  first_note  = BGM[0]
  buzz(buzzer, first_note[0], muted)

  running  = true
  sw4_prev = true
  elapsed  = 0

  while running
    cells = get_cells(pid, rot, pr, pc)

    # ゲームオーバー判定
    if !valid_pos(cells, board) && pr <= 0
      running = false
      next
    end

    draw_board(led, board, cells, pid, next_pid, level)

    # --- 入力を1フレーム(30ms)だけ読む ---
    sleep_ms 30
    elapsed += 30
    tick_sound(buzzer, 30, sound_state, muted)

    # 左移動
    if sw3.low?
      nc = get_cells(pid, rot, pr, pc - 1)
      if valid_pos(nc, board)
        pc -= 1
      end
      sleep_ms 100
      elapsed += 100
      tick_sound(buzzer, 100, sound_state, muted)
    end

    # 右移動
    if sw6.low?
      nc = get_cells(pid, rot, pr, pc + 1)
      if valid_pos(nc, board)
        pc += 1
      end
      sleep_ms 100
      elapsed += 100
      tick_sound(buzzer, 100, sound_state, muted)
    end

    # 回転（エッジ検出）
    sw4_now = sw4.low?
    if sw4_now && !sw4_prev
      nr  = (rot + 1) % 4
      nc0 = get_cells(pid, nr, pr, pc)
      nc1 = get_cells(pid, nr, pr, pc + 1)
      nc2 = get_cells(pid, nr, pr, pc - 1)
      if valid_pos(nc0, board)
        rot = nr
      elsif valid_pos(nc1, board)
        pc += 1
        rot = nr
      elsif valid_pos(nc2, board)
        pc -= 1
        rot = nr
      end
    end
    sw4_prev = sw4_now

    # ソフトドロップ中は落下間隔を短縮
    drop_interval = sw5.low? ? 60 : fall_ms

    # 落下タイミング
    if elapsed >= drop_interval
      elapsed = 0
      nc = get_cells(pid, rot, pr + 1, pc)
      if valid_pos(nc, board)
        pr += 1
      else
        # 着地: 移動/回転後の最新位置でロックする
        cells = get_cells(pid, rot, pr, pc)
        lock(cells, pid, board)
        cleared = clear_lines(board)

        if cleared > 0
          score += cleared * cleared * 100
          level = 1 + score / 1000
          fall_ms = 600 - level * 50
          if fall_ms < 100
            fall_ms = 100
          end
          freq = cleared >= 4 ? 1200 : 880
          play_sfx(buzzer, sound_state, freq, 140, muted)
          line_clear_effect(led, cleared)
        end

        pid      = next_pid
        next_pid = rng.rand(7)
        rot      = 0
        pr       = -1
        pc       = COLS / 2 - 2
      end
    end
  end

  buzzer.frequency(0)
  game_over_anim(led, buzzer, muted)
  sleep_ms 2000
end
