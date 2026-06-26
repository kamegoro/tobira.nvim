local M = {}

-- 各コマンドの提案定義
-- cmd: 提案するコマンド
-- trigger: このコマンドをよく使っている人に提案する
-- pattern: どのパターンで検出するか
M.suggestions = {
  [";"] = {
    cmd = ";",
    trigger = "f",
    pattern = "f_repeat",
    title = "; — f を繰り返す",
    body = "f{文字} の後に ; で同じ文字をもう一度探せます\n逆方向は , です",
    example = "fa ;; → 次の a, その次の a へ",
  },
  ["cw"] = {
    cmd = "cw",
    trigger = "dw",
    pattern = "dw_then_insert",
    title = "cw — 削除してそのまま入力",
    body = "dw + i の代わりに cw 1つで済みます\n削除と同時に INSERT モードに入ります",
    example = "cw → 単語削除 → すぐ入力できる",
  },
  ["ciw"] = {
    cmd = "ciw",
    trigger = "dw",
    pattern = "dw_then_insert",
    title = "ciw — 単語を丸ごと置換",
    body = "カーソルが単語の途中でも単語全体を置換できます\ncw との違い: 単語の先頭にいなくてもOK",
    example = "hel|lo → ciw → world",
  },
  ["gn"] = {
    cmd = "gn",
    trigger = "/",
    pattern = nil,
    title = "gn — 次の検索結果を選択",
    body = "/ で検索後、gn で次のマッチをビジュアル選択\ncgn でそのまま置換できます (. で繰り返し可能)",
    example = "/word → cgn → newword → . . .",
  },
}

-- コマンドの隣接関係 (手動提案 :Tobira 用)
M.adjacency = {
  ["f"]  = { ";", "," },
  ["F"]  = { ";", "," },
  ["dw"] = { "cw", "ciw" },
  ["dd"] = { "dip", "cc", "S" },
  ["x"]  = { "s", "r", "cl" },
  ["/"]  = { "*", "#", "gn", "cgn" },
  ["p"]  = { "P", "\"0p" },
  ["u"]  = { "U", "<C-r>" },
}

-- ログを元にベストな提案を1つ選ぶ
function M.find_best(usage)
  local best_cmd = nil
  local best_score = -1

  for cmd, sug in pairs(M.suggestions) do
    local data = usage[cmd] or { count = 0, shown = 0, adopted = false }

    -- 習得済み or 3回以上見せた → スキップ
    if not data.adopted and data.shown < 3 then
      local trigger_count = (usage[sug.trigger] and usage[sug.trigger].count) or 0
      local cmd_count = data.count

      -- トリガーコマンドを使っていて、提案コマンドをほぼ使っていない
      if trigger_count > 0 then
        local score = trigger_count - cmd_count
        if score > best_score then
          best_score = score
          best_cmd = cmd
        end
      end
    end
  end

  return best_cmd
end

return M
