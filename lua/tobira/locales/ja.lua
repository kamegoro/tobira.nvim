return {
  guide = {
    title = 'tobira ガイド',
    hint = ':TobiraGuide  ガイドを閉じる',
    contexts = {
      default = {
        {
          title = '移動',
          items = {
            {
              keys = 'h j k l',
              desc = 'カーソル移動',
              track = { 'h', 'j', 'k', 'l' },
              threshold = 100,
              upgrade = { keys = '<C-d> / <C-u>', desc = '半ページスクロール' },
            },
            {
              keys = 'w / b',
              desc = '単語単位で移動',
              track = { 'w', 'b' },
              threshold = 40,
              upgrade = { keys = 'e / ge', desc = '単語末尾へ' },
            },
            { keys = '0 / $', desc = '行頭 / 行末' },
            { keys = 'gg / G', desc = 'ファイル先頭 / 末尾' },
            {
              keys = 'f{char}',
              desc = '文字へジャンプ',
              track = { 'f' },
              threshold = 15,
              upgrade = { keys = ';', desc = 'f を繰り返す' },
            },
            { keys = '<C-o> / <C-i>', desc = '前/次の場所へジャンプ' },
          },
        },
        {
          title = '編集',
          items = {
            {
              keys = 'i',
              desc = 'インサートモード',
              track = { 'i' },
              threshold = 40,
              upgrade = { keys = 'a / o / O', desc = '追記 / 新規行' },
            },
            { keys = 'Esc', desc = 'ノーマルモードへ戻る' },
            {
              keys = 'x',
              desc = '1文字削除',
              track = { 'x' },
              threshold = 20,
              upgrade = { keys = 'r{char}', desc = '1文字置換（モード変更なし）' },
            },
            { keys = 'dd', desc = '行を削除' },
            { keys = 'yy / p', desc = 'コピー / 貼り付け' },
            { keys = 'u / <C-r>', desc = 'undo / redo' },
          },
        },
        {
          title = 'ファイル',
          items = {
            { keys = ':w', desc = '保存' },
            { keys = ':q', desc = '終了' },
            { keys = ':wq', desc = '保存して終了' },
            { keys = '<C-^>', desc = '前のファイルに戻る' },
          },
        },
        {
          title = '検索',
          items = {
            { keys = '/{text}', desc = '検索' },
            { keys = 'n / N', desc = '次 / 前の結果' },
          },
        },
      },

      neo_tree = {
        {
          title = '移動',
          items = {
            { keys = 'j / k', desc = 'カーソル移動' },
            { keys = 'l / Enter', desc = '開く / 展開' },
            { keys = 'h', desc = '折りたたむ' },
            { keys = '<BS>', desc = '親ディレクトリへ' },
          },
        },
        {
          title = '操作',
          items = {
            { keys = 'a', desc = '新規作成' },
            { keys = 'd', desc = '削除' },
            { keys = 'r', desc = '名前変更' },
            { keys = 'y / x / p', desc = 'コピー / カット / ペースト' },
          },
        },
        {
          title = '表示',
          items = {
            { keys = 'H', desc = '隠しファイル切替' },
            { keys = '/', desc = 'ファジー検索' },
            { keys = 'q', desc = 'ツリーを閉じる' },
          },
        },
      },
    },
  },
  progress = {
    title = 'tobira — vim の旅',
    level_label = 'レベル: ',
    levels = {
      novice = '初心者以前',
      beginner = '入門',
      intermediate = '中級者',
      advanced = '上級者',
    },
    next = '次のおすすめ: ',
    hint = '[q / Esc]  閉じる',
    categories = {
      motion = '移動',
      edit = '編集',
      search = '検索',
    },
  },
  notifications = {
    reset = 'tobira: 使用ログをリセットしました',
    no_suggestions = 'tobira: 新しい提案はありません 🎉',
  },
  stats = {
    title = 'tobira — 使用統計',
    times = '回',
  },
  float = {
    example_prefix = '例: ',
  },
  -- 提案フロートと :TobiraProgress に表示する文字列。
  -- キーは commands.registry のキーと完全一致させること。
  suggestions = {
    [';'] = {
      title = '; — f の繰り返し',
      body = 'f{文字} の後で ; を押すと次の出現箇所にジャンプ\n, は逆方向に進む',
      example = 'fa ;; → 次の a、さらに次の a へ',
    },
    [','] = {
      title = ', — f を逆方向に繰り返す',
      body = '; の逆方向版 — 直前の f マッチに戻る\n; で行き過ぎたときに使える',
      example = 'fa ;;; , → 一つ戻る',
    },
    ['cw'] = {
      title = 'cw — 単語を削除してインサートモードへ',
      body = 'dw + i を1つのモーションで行う\n削除直後にインサートモードへ移行',
      example = 'cw → カーソルから単語末尾まで削除 → インサートモード',
    },
    ['ciw'] = {
      title = 'ciw — 単語全体を変更',
      body = 'カーソルが単語の途中にあっても動作する\ncw はカーソルより後ろを削除するが ciw は単語全体を置換',
      example = 'hel|lo → ciw → world',
    },
    ['<C-r>'] = {
      title = '<C-r> — redo',
      body = '元に戻しすぎた？<C-r> でやり直し\nu / <C-r> を組み合わせて変更履歴をナビゲート',
      example = 'u u u <C-r> → 3回 undo、1回 redo',
    },
    ['ddp'] = {
      title = 'ddp — 現在行と次の行を入れ替え',
      body = 'dd で行を削除し p で下に貼り付け — ddp で行を入れ替え\n2行間をナビゲートする必要なし',
      example = 'ddp → 現在行が1行下に移動',
    },
    ['{n}j'] = {
      title = '{n}j — 複数行を一度にジャンプ',
      body = 'モーションの前に数字を付けると繰り返し\n5j で5行下へ。k, w, b などにも使える',
      example = '5j → 5行下へ移動',
    },
    ['^'] = {
      title = '^ — 行頭の最初の非空白文字へ',
      body = '0 は列0へ移動、^ は最初の非空白文字へ\n多くの場合 ^ の方が使いたい動作',
      example = '    hello → ^ → h にカーソル',
    },
    ['cgn'] = {
      title = 'cgn — 次の検索マッチを変更',
      body = '/ で検索後、cgn で次のマッチを変更\n. で次のマッチにも同じ変更を繰り返せる',
      example = '/word → cgn → new → Esc → . . .',
    },
    ['.'] = {
      title = '. — 最後の変更を繰り返す',
      body = 'インサートモードに入り直さずに最後の編集を繰り返す\nn や ; と組み合わせると複数箇所を素早く変更できる',
      example = 'cw foo <Esc> n . → 次のマッチも変更',
    },
    ['A'] = {
      title = 'A — 行末に追記',
      body = '$a を1つのキーで — 行末に移動してインサートモードへ\nI（行頭からインサート）と組み合わせると行の両端を編集できる',
      example = 'A; → 行末にセミコロンを追加',
    },
    ['O'] = {
      title = 'O — 上に新しい行を開く',
      body = 'o と同じだがカーソルの上に新しい行を開く\n上に移動して o を押す必要がなくなる',
      example = 'O → カーソルの上に空白行 → インサートモード',
    },
    ['D'] = {
      title = 'D — 行末まで削除',
      body = 'カーソルから行末まで削除（d$ と同じ）\nそこまで移動せずに行末以降を書き直せる',
      example = 'D → 新しい行末テキストを入力',
    },
    ['C'] = {
      title = 'C — 行末まで変更',
      body = 'D + i を1つのモーションで — 行末まで削除してインサートモードへ\ncw の行末バージョン',
      example = 'C → カーソルから行末まで置換',
    },
    ['gn'] = {
      title = 'gn — 次の検索マッチを選択',
      body = '* や / の後、gn でビジュアルモードで次のマッチを選択\nc（cgn）と組み合わせて変更、. で全出現箇所に繰り返す',
      example = '* → cgn → 新テキスト → Esc → . . .',
    },
    ['e'] = {
      title = 'e — 単語の末尾へ移動',
      body = 'w は次の単語の先頭へ、e は現在の単語の末尾へジャンプ\n単語の末尾に追記したいときに便利',
      example = 'ea → 現在の単語の末尾にテキストを追記',
    },
    ['I'] = {
      title = 'I — 行頭からインサートモード',
      body = '行の最初の非空白文字に移動してインサートモードへ\nA（行末）と組み合わせると行の両端を素早く編集できる',
      example = 'I// → 現在行をコメントアウト',
    },
    ['H'] = {
      title = 'H — 画面の一番上へ移動',
      body = 'スクロールせずにカーソルを画面の先頭行へ移動\nM は中央、L は末尾へ',
      example = 'H → カーソルが最初の表示行へ移動',
    },
    ['M'] = {
      title = 'M — 画面の中央へ移動',
      body = 'カーソルをウィンドウのちょうど中央行へ移動\n大きなジャンプの後に位置を把握し直すのに便利',
      example = 'M → カーソルが中央行へ移動',
    },
    ['L'] = {
      title = 'L — 画面の一番下へ移動',
      body = 'スクロールせずにカーソルを画面の最終行へ移動\nH、M と組み合わせて画面相対ナビゲーション',
      example = 'L → カーソルが最後の表示行へ移動',
    },
    ['{n}x'] = {
      title = '{n}x — 複数文字を一度に削除',
      body = 'x の前に数字を付けると一度にその文字数を削除\n他のモーションにも使える: 3dw, 2dd など',
      example = '5x → カーソル位置から5文字削除',
    },
    ['<C-d>'] = {
      title = '<C-d> — 半ページ下へスクロール',
      body = 'ウィンドウの半分の高さだけ表示とカーソルを下へ移動\nj を何度も押すよりはるかに速い',
      example = '<C-d><C-d> → 1ページ分スクロールダウン',
    },
    ['<C-u>'] = {
      title = '<C-u> — 半ページ上へスクロール',
      body = '<C-d> の上方向版\nペアで使うと大きなファイルを効率よくナビゲートできる',
      example = '<C-d> してから <C-u> → 下へ移動して戻る',
    },
    ['{n}k'] = {
      title = '{n}k — 複数行を一度に上へジャンプ',
      body = 'k の前に数字を付けると一度にその行数分上へ移動\n他のモーションにも使える: 5k, 3w, 2b など',
      example = '5k → 5行上へ移動',
    },
    ['*'] = {
      title = '* — カーソル下の単語を検索',
      body = 'カーソル下の単語を検索レジスタに入れて次の出現箇所にジャンプ\n/word<Enter> と入力するより速い — 何も入力不要',
      example = '"foo" の上で * → 次の "foo" へジャンプ',
    },
    ['<C-o>'] = {
      title = '<C-o> — 直前の場所に戻る',
      body = '大きなジャンプ（* / G gg /）の後 <C-o> で元の位置に戻る\n<C-i> でまた前に進める（ジャンプリスト）',
      example = '* <C-o> → マッチへジャンプして開始地点に戻る',
    },
    ['P'] = {
      title = 'P — カーソル行の上に貼り付け',
      body = 'p は行の下に貼り付け、P は上に貼り付け\nコピーしたテキストを現在行の前に挿入したいときに便利',
      example = 'yy P → 現在行をコピーして上に貼り付け',
    },
  },
}
