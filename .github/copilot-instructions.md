# tobira.nvim — Copilot Instructions

## プロジェクト概要

**tobira.nvim** は「あなたが今使っているvimコマンドから、まだ知らない隣のコマンドを提案する」Neovimプラグインです。

3つの核となる部品:
1. **Logger** — `vim.on_key()` でキーストロークを記録。`~/.local/share/nvim/tobira/usage.json` に保存
2. **Graph** — vimコマンドの「関係性」を定義した隣接グラフ
3. **Suggest** — ログ × グラフ → 「よく使うが、隣を知らなそうなコマンド」を検出・提案

---

## コードスタイル（厳守）

- **フォーマッター:** stylua（`indent_type = "Spaces"`, `indent_width = 2`, `quote_style = "AutoPreferSingle"`, `column_width = 120`）
- **リンター:** selene
- シングルクォート、2スペースインデント、120カラム制限

---

## アーキテクチャ・設計原則

### モジュール構造の鉄則

```lua
local M = {}
-- 状態はモジュールローカルに。グローバル変数は使わない
local _state = {}

function M.setup(opts) end

return M
```

### 依存関係ルール（循環依存禁止）

```
init.lua          — wiring層。モジュール同士を繋ぐ唯一の場所
core/config.lua   — 設定の唯一の真実。他モジュールは require して読む
core/logger.lua   — suggest を require しない。on_pattern コールバックで通知
core/suggest.lua  — logger / graph / config を require してOK
core/graph.lua    — 純粋Lua。vim.* 不使用
ui/float.lua      — 表示のみ。ロジックを持たない
```

### plugin/ と lua/ の役割分担

- `plugin/tobira.lua`: コマンド・autocmd の登録のみ。`require()` はコールバック内で行う（ファイル先頭でrequireしない）
- `lua/tobira/`: 実際のロジック

### 必須パターン

```lua
-- ガード（plugin/ ファイルに必須）
if vim.g.loaded_tobira then return end
vim.g.loaded_tobira = true

-- config 検証
local ok, err = pcall(vim.validate, {
  idle_delay = { config.idle_delay, 'number' },
})

-- augroup（clear = true で重複登録防止）
vim.api.nvim_create_autocmd('ModeChanged', {
  group = vim.api.nvim_create_augroup('tobira_mode', { clear = true }),
  callback = ...,
})
```

### vim.on_key() のパフォーマンス（重要）

`vim.on_key()` は**全キーストロークで発火する**。コールバックは極力軽くする。

- コールバック内でのI/O禁止
- 重い計算禁止
- モードキャッシュは `ModeChanged` autocmd で管理（`vim.fn.mode()` をホットパスで呼ばない）
- `suggest.queue()` は `vim.defer_fn(fn, 1500)` でデバウンス

---

## ロケールルール（厳守）

**ユーザーに表示される文字列を UI コードにハードコードしてはいけない。**

すべての表示文字列は `lua/tobira/locales/en.lua` と `lua/tobira/locales/ja.lua` で定義し、描画コードはロケール変数を通して参照する。

```lua
-- ✅ 良い
local function load_strings()
  local lang = require('tobira.core.config').values.lang
  local ok, loc = pcall(require, 'tobira.locales.' .. lang)
  if not ok then loc = require('tobira.locales.en') end
  return loc
end

-- ❌ 悪い: 文字列を描画コードに直書き
push('Next: ' .. cmd_name)
local label = l == 'ja' and '閉じる' or 'close'  -- インライン分岐も禁止
```

新しい UI 要素を追加するときは必ず **en.lua と ja.lua の両方** に対応するキーを追加する。

---

## TDD ルール（厳守）

**実装コードより先にテストを書く。例外なし。**

### サイクル

1. **Red** — `tests/spec/` に失敗するテストを書く（失敗を確認してから次へ）
2. **Green** — テストを通す最小限のコードを書く（全テスト通過を確認してから次へ）
3. **Refactor** — テストがグリーンのまま整理する

### テスト構成

```
tests/spec/unit/        → vim.* を使わない純粋ロジック (graph.lua など)
tests/spec/integration/ → Neovim内で動く統合テスト (logger, suggest など)
```

### クリーンなテストの基準

```lua
-- ✅ 良い: 振る舞いを描写する
describe('when the user has already adopted a suggestion', function()
  it('never shows it again', function() ... end)
end)

-- ❌ 悪い: 実装を描写する
describe('logger.mark_adopted', function()
  it('sets adopted to true', function() ... end)
end)
```

### モック・スパイのルール

```lua
-- ✅ 良い: pcall で必ず後始末する
local function with_float_spy(fn)
  local called = false
  package.loaded['tobira.ui.float'] = { show = function() called = true end }
  local ok, err = pcall(fn)
  package.loaded['tobira.ui.float'] = nil
  assert.is_true(ok, err)
  return called
end
```

### テストにI/Oを持ち込まない

```lua
-- ✅ 良い: reset() は状態だけ戻す
logger.reset()  -- I/Oなし

-- ❌ 悪い: テストのたびにディスク書き込みが走る
function M.reset()
  usage = {}
  save()  -- ← before_each のたびに実行される
end
```

### プロダクションコードにテストフックを書かない

```lua
-- ❌ 悪い: 本番ユーザーには不要なAPI
function M.simulate_keys(keys) ... end
```

### コミット前チェックリスト

- [ ] `describe` / `it` の文言が「振る舞い」を英語で説明しているか
- [ ] `before_each` はすべて `describe` ブロックの中にあるか（トップレベル禁止）
- [ ] モック・パッチが `pcall` か `after_each` で必ず復元されるか
- [ ] `reset()` 等のヘルパーがI/Oを引き起こしていないか
- [ ] プロダクションコードにテスト専用関数・フラグがないか
- [ ] 1つの `it()` に1つの概念しかないか

---

## 開発フロー

- **コミット規約:** Conventional Commits
- **ブランチ:** `feat/`, `fix/`, `chore/` プレフィックス
- **Issue/PR:** 機能単位で細かく分割

---

## 設計上の注意事項

- コマンドグラフ（`graph.lua`）はこのプロジェクトの核心。丁寧に設計する
- UIは非侵襲的であること。ユーザーの作業を邪魔しない
- 提案頻度は保守的に。1セッション1提案がデフォルト
- ログファイルはローカルのみ、外部送信なし
- 採用判定はユーザーに聞かない。実際の行動で判定する
