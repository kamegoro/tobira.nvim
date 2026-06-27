return {
  guide = {
    hint = ':TobiraGuide  ガイドを閉じる',
    contexts = {
      default = {
        {
          title = '移動',
          items = {
            { keys = 'h j k l', desc = 'カーソル移動' },
            { keys = 'w / b', desc = '単語単位で移動' },
            { keys = '0 / $', desc = '行頭 / 行末' },
            { keys = 'gg / G', desc = 'ファイル先頭 / 末尾' },
            { keys = 'f{char}', desc = '文字へジャンプ' },
            { keys = '<C-o> / <C-i>', desc = '前/次の場所へジャンプ' },
          },
        },
        {
          title = '編集',
          items = {
            { keys = 'i', desc = 'インサートモード' },
            { keys = 'Esc', desc = 'ノーマルモードへ戻る' },
            { keys = 'x', desc = '1文字削除' },
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
            { keys = 'a', desc = 'ファイル / ディレクトリを作成' },
            { keys = 'd', desc = '削除' },
            { keys = 'r', desc = '名前変更' },
            { keys = 'y / x / p', desc = 'コピー / カット / ペースト' },
          },
        },
        {
          title = '表示',
          items = {
            { keys = 'H', desc = '隠しファイルを表示/非表示' },
            { keys = '/', desc = 'ファジー検索' },
            { keys = 'q', desc = 'ツリーを閉じる' },
          },
        },
      },
    },
  },
}
