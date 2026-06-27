return {
  guide = {
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
}
