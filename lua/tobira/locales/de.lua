return {
  guide = {
    title = 'tobira Anleitung',
    hint = ':TobiraGuide  Anleitung umschalten',
    all_mastered = 'Alle Befehle dieser Stufe gemeistert!',
    pinned = 'Angepinnt',
    forgotten_suffix = ' (vergessen)',
  },
  progress = {
    title = 'tobira — deine vim-Reise',
    level_label = 'Stufe: ',
    levels = {
      novice = 'Anfänger',
      beginner = 'Einsteiger',
      intermediate = 'Fortgeschritten',
      advanced = 'Experte',
    },
    categories = {
      motion = 'Bewegung',
      edit = 'Bearbeiten',
      search = 'Suche',
      window = 'Fenster',
      fold = 'Faltung',
      mark = 'Marke',
      macro = 'Makro',
    },
    mastered_total = '%d / %d gemeistert',
    section_count = '%d / %d',
    footer = {
      suppress = 'ausblenden',
      pin = 'anpinnen',
      guide = 'Anleitung',
      stats = 'Statistik',
      close = 'schließen',
    },
    preview = {
      learning = 'in Arbeit',
      mastered = 'gemeistert',
      forgotten = 'vergessen',
      never_tried = 'nie benutzt',
      to_next = 'noch %d bis %s',
    },
  },
  notifications = {
    reset = 'tobira: Nutzungsprotokoll zurückgesetzt',
    no_suggestions = 'tobira: gerade keine neuen Vorschläge 🎉',
    invalid_config = 'tobira: ungültige Konfiguration — ',
  },
  stats = {
    title = 'tobira — Nutzungsstatistik',
    mastery = 'Beherrschung',
    mastery_dist = '  Nie %d  ·  ☆ %d  ·  ★ %d  ·  ★★+ %d',
    top_commands = 'Meistgenutzte Befehle',
    try_next = '⚡ Als Nächstes ausprobieren',
    footer = {
      guide = 'Anleitung',
      progress = 'Fortschritt',
      close = 'schließen',
    },
    footer_summary = 'Bisher %s Tastenanschläge · %s / %s Befehle entdeckt',
  },
  float = {
    example_prefix = 'z. B. ',
    close_hint = 'q/Esc schließen',
    suppress_hint = ':TobiraProgress  x zum Stummschalten',
    ambient_reason = 'Du benutzt %s häufig',
    celebrate = 'Gut gemacht — du hast %s benutzt',
    reasons = {
      f_repeat = 'Du hast dieselbe f/t-Suche in dieser Zeile wiederholt',
      r_run = 'Du hast 3 Zeichen einzeln nacheinander ersetzt',
      visual_textobj = 'Du hast vor dem Bearbeiten ein Textobjekt im visuellen Modus ausgewählt',
      indent_run = 'Du hast 3-mal hintereinander auf dieselbe Weise eingerückt',
      dedent_run = 'Du hast 3-mal hintereinander auf dieselbe Weise die Einrückung entfernt',
      c_dollar = 'Du hast vom Cursor bis zum Zeilenende geändert',
      d_dollar = 'Du hast vom Cursor bis zum Zeilenende gelöscht',
      dd_run = 'Du hast 3-mal hintereinander einzelne Zeilen gelöscht',
      yy_then_p = 'Du hast eine Zeile kopiert und direkt darunter eingefügt',
      dd_then_p = 'Du hast eine Zeile gelöscht und sie wieder eingefügt',
      dd_then_insert = 'Du hast eine Zeile gelöscht und eine neue eingetippt',
      zero_then_w = 'Du bist zu Spalte 0 gesprungen und dann ein Wort weiter',
      zero_then_insert = 'Du bist zum Zeilenanfang gesprungen und in den Einfügemodus gewechselt',
      dollar_then_append = 'Du bist zum Zeilenende gesprungen und in den Einfügemodus gewechselt',
      k_then_o = 'Du bist eine Zeile hoch und hast darunter eine neue geöffnet',
      x_then_insert = 'Du hast ein Zeichen gelöscht und bist in den Einfügemodus gewechselt',
      D_then_insert = 'Du hast bis zum Zeilenende gelöscht und angefangen zu tippen',
      dw_then_insert = 'Du hast ein Wort gelöscht und bist in den Einfügemodus gewechselt',
      x_repeat = 'Du hast 3-mal hintereinander einzelne Zeichen gelöscht',
      u_repeat = 'Du hast 3-mal hintereinander rückgängig gemacht',
      j_repeat = 'Du hast 5-mal hintereinander j gedrückt',
      j_many = 'Du hast 10-mal hintereinander j gedrückt',
      k_repeat = 'Du hast 5-mal hintereinander k gedrückt',
      k_many = 'Du hast 10-mal hintereinander k gedrückt',
      n_repeat = 'Du hast einen Suchtreffer 4-mal wiederholt',
      l_repeat = 'Du hast 5-mal hintereinander l gedrückt',
      h_repeat = 'Du hast 5-mal hintereinander h gedrückt',
      w_repeat = 'Du hast 5-mal hintereinander w gedrückt',
      b_repeat = 'Du hast 5-mal hintereinander b gedrückt',
      p_repeat = 'Du hast 3-mal hintereinander eingefügt',
      P_repeat = 'Du hast 3-mal hintereinander vor dem Cursor eingefügt',
      tilde_repeat = 'Du hast 3-mal hintereinander die Groß-/Kleinschreibung umgeschaltet',
      dot_repeat = 'Du hast die letzte Änderung 3-mal hintereinander wiederholt',
      J_repeat = 'Du hast 3-mal hintereinander Zeilen zusammengeführt',
    },
  },
  -- Suggestion display strings shown via float popup and :TobiraProgress.
  -- Keys match commands.registry keys exactly.
  suggestions = {
    [';'] = {
      title = '; — letzte f / t / F / T wiederholen',
      body = 'Nach jeder f-, t-, F- oder T-Suche springt ; zum nächsten Treffer in derselben Richtung\n, springt in die entgegengesetzte Richtung',
      example = 'fa ;; → nächstes a, dann das nächste',
    },
    [','] = {
      title = ', — f / t / F / T rückwärts wiederholen',
      body = 'Das Gegenteil von ; — wiederholt die letzte f/t/F/T-Suche in umgekehrter Richtung\nNützlich, wenn du mit ; zu weit gesprungen bist',
      example = 'fa ;;; , → einen Schritt zurückspringen',
    },
    ['cw'] = {
      title = 'cw — Wort löschen und einfügen',
      body = 'Ersetzt die Abfolge dw + i in einer Bewegung\nWechselt sofort nach dem Löschen in den Einfügemodus',
      example = 'cw → löscht vom Cursor bis zum Wortende → Einfügemodus',
    },
    ['ciw'] = {
      title = 'ciw — inneres Wort ändern',
      body = 'Funktioniert auch, wenn der Cursor mitten im Wort steht\ncw löscht nur ab dem Cursor vorwärts; ciw ersetzt das ganze Wort',
      example = 'hel|lo → ciw → world',
    },
    ['<C-r>'] = {
      title = '<C-r> — Wiederholen',
      body = 'Zu viel rückgängig gemacht? <C-r> stellt die letzte rückgängig gemachte Änderung wieder her\nKombiniere u / <C-r>, um durch den Änderungsverlauf zu navigieren',
      example = 'u u u <C-r> → 3-mal rückgängig, 1-mal wiederholt',
    },
    ['ddp'] = {
      title = 'ddp — aktuelle Zeile mit der nächsten tauschen',
      body = 'dd löscht die Zeile, p fügt sie darunter ein — ddp tauscht Zeilen in einem Schritt\nKein Wechseln zwischen den beiden Zeilen nötig',
      example = 'ddp → aktuelle Zeile rückt eine Position nach unten',
    },
    ['{n}j'] = {
      title = '{n}j — mehrere Zeilen auf einmal springen',
      body = 'Setze eine Zahl vor eine beliebige Bewegung, um sie zu wiederholen\n5j bewegt 5 Zeilen nach unten; funktioniert auch mit k, w, b usw.',
      example = '5j → 5 Zeilen nach unten',
    },
    ['^'] = {
      title = '^ — zum ersten Nicht-Leerzeichen springen',
      body = '0 springt zu Spalte 0; ^ springt zum ersten Zeichen, das kein Leerzeichen ist\nMeist ist ^ das, was du eigentlich willst',
      example = '    hello → ^ → Cursor landet auf h',
    },
    ['cgn'] = {
      title = 'cgn — nächsten Suchtreffer ändern',
      body = 'Benutze nach / cgn, um den nächsten Treffer zu ändern\nDrücke danach ., um bei jedem weiteren Treffer zu wiederholen',
      example = '/word → cgn → new → Esc → . . .',
    },
    ['.'] = {
      title = '. — letzte Änderung wiederholen',
      body = 'Wiederholt deine letzte Bearbeitung, ohne erneut in den Einfügemodus zu wechseln\nKombiniere mit n oder ;, um mehrere Vorkommen in einem Durchgang zu ändern',
      example = 'cw foo <Esc> n . → ändert auch den nächsten Treffer',
    },
    ['A'] = {
      title = 'A — am Zeilenende anfügen',
      body = '$a in einem Tastendruck — springt zum Zeilenende und wechselt in den Einfügemodus\nKombiniere mit I (am Zeilenanfang einfügen) für schnelles Bearbeiten von Zeilenanfang/-ende',
      example = 'A; → fügt ein Semikolon am Zeilenende hinzu',
    },
    ['O'] = {
      title = 'O — neue Zeile darüber öffnen',
      body = 'Wie o, öffnet aber die neue Zeile über dem Cursor\nKein vorheriges Hochgehen und dann o nötig',
      example = 'O → neue leere Zeile über dem Cursor → Einfügemodus',
    },
    ['D'] = {
      title = 'D — bis zum Zeilenende löschen',
      body = 'Löscht vom Cursor bis zum Zeilenende (entspricht d$)\nLässt dich den Rest neu eintippen, ohne vorher dorthin zu navigieren',
      example = 'D → neuen Zeilenrest eintippen',
    },
    ['C'] = {
      title = 'C — bis zum Zeilenende ändern',
      body = 'D + i in einer Bewegung — löscht bis zum Zeilenende und wechselt in den Einfügemodus\nWie cw, aber für den Rest der Zeile statt für ein Wort',
      example = 'C → ersetzt alles vom Cursor bis zum Ende',
    },
    ['gn'] = {
      title = 'gn — nächsten Suchtreffer auswählen',
      body = 'Nach * oder / wählt gn den nächsten Treffer im visuellen Modus aus\nWird mit c (cgn) und dann . verwendet, um jedes Vorkommen zu ersetzen',
      example = '* → cgn → neuer Text → Esc → . . .',
    },
    ['e'] = {
      title = 'e — zum Wortende springen',
      body = 'w springt zum Anfang des nächsten Wortes; e springt zu dessen Ende\nNützlich, wenn du am Ende eines Wortes etwas anfügen musst',
      example = 'ea → Text nach dem aktuellen Wort anfügen',
    },
    ['I'] = {
      title = 'I — am Zeilenanfang einfügen',
      body = 'Springt zum ersten Nicht-Leerzeichen und wechselt in den Einfügemodus\nKombiniere mit A (Zeilenende) für schnelles Bearbeiten der Zeilenränder',
      example = 'I// → aktuelle Zeile auskommentieren',
    },
    ['H'] = {
      title = 'H — zum oberen Bildschirmrand springen',
      body = 'Bewegt den Cursor zum oberen Rand des sichtbaren Fensters, ohne zu scrollen\nM springt zur Mitte, L nach unten',
      example = 'H → Cursor landet auf der ersten sichtbaren Zeile',
    },
    ['M'] = {
      title = 'M — zur Bildschirmmitte springen',
      body = 'Platziert den Cursor genau in der Mitte des sichtbaren Fensters\nNützlich, um sich nach einem großen Sprung schnell neu zu orientieren',
      example = 'M → Cursor bewegt sich zur mittleren Zeile',
    },
    ['L'] = {
      title = 'L — zum unteren Bildschirmrand springen',
      body = 'Bewegt den Cursor zur letzten sichtbaren Zeile, ohne zu scrollen\nKombiniere mit H und M für bildschirmrelative Navigation',
      example = 'L → Cursor landet auf der letzten sichtbaren Zeile',
    },
    ['{n}x'] = {
      title = '{n}x — mehrere Zeichen auf einmal löschen',
      body = 'Setze eine Zahl vor x, um so viele Zeichen auf einmal zu löschen\nFunktioniert auch mit anderen Bewegungen: 3dw, 2dd usw.',
      example = '5x → löscht 5 Zeichen am Cursor',
    },
    ['<C-d>'] = {
      title = '<C-d> — halbe Seite nach unten scrollen',
      body = 'Bewegt Ansicht und Cursor um die halbe Fensterhöhe nach unten\nViel schneller als j viele Male zu drücken',
      example = '<C-d><C-d> → scrollt eine ganze Seite nach unten',
    },
    ['<C-u>'] = {
      title = '<C-u> — halbe Seite nach oben scrollen',
      body = 'Die Gegenrichtung zu <C-d>\nKombiniere beide, um große Dateien effizient zu durchsuchen',
      example = '<C-d> dann <C-u> → nach unten scrollen und zurück',
    },
    ['{n}k'] = {
      title = '{n}k — mehrere Zeilen auf einmal nach oben springen',
      body = 'Setze eine Zahl vor k, um mehrere Zeilen auf einmal nach oben zu gehen\nFunktioniert mit jeder Bewegung: 5k, 3w, 2b usw.',
      example = '5k → 5 Zeilen nach oben',
    },
    ['*'] = {
      title = '* — Wort unter dem Cursor suchen',
      body = 'Legt das Wort unter dem Cursor ins Suchregister und springt zum nächsten Treffer\nSchneller als /word<Enter> einzutippen — keine Eingabe nötig',
      example = 'Cursor auf "foo" → * → springt zum nächsten "foo"',
    },
    ['<C-o>'] = {
      title = '<C-o> — zur vorherigen Position zurückspringen',
      body = 'Nach einem großen Sprung (* / G gg /) bringt dich <C-o> zur vorherigen Position zurück\n<C-i> geht in der Sprungliste wieder vorwärts',
      example = '* <C-o> → zum Treffer springen, dann zum Ausgangspunkt zurück',
    },
    ['P'] = {
      title = 'P — vor dem Cursor einfügen',
      body = 'p fügt nach dem Cursor ein; P fügt davor ein\nBei zeilenweisen Kopien: p fügt unter der Zeile ein, P darüber',
      example = 'yy P → aktuelle Zeile kopieren und darüber einfügen',
    },

    -- ── f → t stop-before-char chain ─────────────────────────────────────
    ['t'] = {
      title = 't — bis kurz vor ein Zeichen springen',
      body = 'Wie f, hält aber ein Zeichen vor dem Ziel an\nIdeal mit Operatoren: ct; ändert alles bis (ohne) das nächste Semikolon',
      example = 'ct; → ändert alles bis zum nächsten Semikolon',
    },
    ['T'] = {
      title = 'T — bis kurz nach ein Zeichen springen (rückwärts)',
      body = 'Sucht rückwärts wie F, hält aber kurz nach dem Zeichen an\nWird wie jede f/t-Suche mit ; und , wiederholt',
      example = 'T, → springt zurück bis kurz nach das vorherige Komma',
    },

    -- ── jumplist bidirectional ─────────────────────────────────────────────
    ['<C-i>'] = {
      title = '<C-i> — in der Sprungliste vorwärts gehen',
      body = 'Nachdem <C-o> dich zurückgebracht hat, bringt dich <C-i> wieder vorwärts\nNavigiere deinen Bearbeitungsverlauf in beide Richtungen',
      example = '<C-o> <C-o> <C-i> → zweimal zurück, dann einmal vor',
    },

    -- ── full-page scroll chain ─────────────────────────────────────────────
    ['<C-f>'] = {
      title = '<C-f> — eine ganze Seite nach unten scrollen',
      body = '<C-d> scrollt eine halbe Seite; <C-f> eine ganze Seite\nSchneller, um über große Abschnitte einer Datei zu springen',
      example = '<C-f> → scrollt um eine ganze Fensterhöhe nach unten',
    },
    ['<C-b>'] = {
      title = '<C-b> — eine ganze Seite nach oben scrollen',
      body = 'Die Gegenrichtung zu <C-f>\nKombiniere mit <C-f>, um eine große Datei schnell in beide Richtungen zu durchsuchen',
      example = '<C-f> <C-b> → eine ganze Seite nach unten scrollen und zurück',
    },

    -- ── paragraph motions ─────────────────────────────────────────────────
    ['}'] = {
      title = '} — zum Absatzende springen',
      body = 'Geht nach unten bis zur nächsten Leerzeile — überspringt ganze Blöcke auf einmal\nSchneller als j beim Wechseln zwischen Funktionen oder Textabschnitten',
      example = '} → Cursor springt zur Leerzeile nach dem aktuellen Block',
    },
    ['{'] = {
      title = '{ — zum Absatzanfang springen',
      body = 'Die Gegenrichtung zu } — geht nach oben zur Leerzeile darüber\nSchnelles Navigieren zwischen Codeblöcken oder Absätzen',
      example = '{ → Cursor springt zur Leerzeile vor dem aktuellen Block',
    },

    -- ── screen centering chain ─────────────────────────────────────────────
    ['zz'] = {
      title = 'zz — Bildschirm auf den Cursor zentrieren',
      body = 'Scrollt die Ansicht so, dass die Cursorzeile in der Mitte des Fensters liegt\nDer Cursor bewegt sich nicht — nur der sichtbare Bereich ändert sich',
      example = 'zz → aktuelle Zeile scrollt zur Mitte des Fensters',
    },
    ['zt'] = {
      title = 'zt — Cursorzeile zum oberen Bildschirmrand scrollen',
      body = 'Wie zz, platziert die Cursorzeile aber am oberen Fensterrand\nzt / zz / zb geben dir Kontrolle über oben / Mitte / unten',
      example = 'zt → aktuelle Zeile scrollt zum oberen Fensterrand',
    },
    ['zb'] = {
      title = 'zb — Cursorzeile zum unteren Bildschirmrand scrollen',
      body = 'Scrollt so, dass die Cursorzeile am unteren Fensterrand erscheint\nKombiniere mit zt und zz, um genau zu positionieren, was du siehst',
      example = 'zb → aktuelle Zeile scrollt zum unteren Fensterrand',
    },

    -- ── WORD motions ──────────────────────────────────────────────────────
    ['W'] = {
      title = 'W — um ein WORD vorwärts springen',
      body = 'Wie w, hält aber nur bei Leerzeichen an und ignoriert Satzzeichen\nNützlich, wenn w in Dingen wie "foo.bar(baz)" zu oft anhält',
      example = 'W auf "foo.bar.baz" → springt das ganze Token auf einmal über',
    },
    ['B'] = {
      title = 'B — um ein WORD rückwärts springen',
      body = 'Wie b, behandelt aber durch Satzzeichen verbundenen Text als ein WORD\nDie Gegenrichtung zu W',
      example = 'B auf "foo.bar.baz" → springt über das ganze Token zurück',
    },

    -- ── word-end backward ─────────────────────────────────────────────────
    ['ge'] = {
      title = 'ge — zum Ende des vorherigen Wortes springen',
      body = 'e springt vorwärts zum Wortende; ge springt rückwärts zum Ende des vorherigen Wortes\nNützlich, wenn du hinter dem Cursor an ein Wort etwas anfügen musst',
      example = 'gea → zum Ende des vorherigen Wortes springen und dann Text anfügen',
    },

    -- ── bracket matching ──────────────────────────────────────────────────
    ['%'] = {
      title = '% — zur passenden Klammer springen',
      body = 'Springt zwischen (, [, { und den zugehörigen schließenden Klammern\nFunktioniert auch mit /* */ und #if/#endif bei vielen Dateitypen',
      example = '% auf ( → Cursor springt zur passenden )',
    },

    -- ── single-char edit shortcuts ────────────────────────────────────────
    ['r'] = {
      title = 'r — einzelnes Zeichen ersetzen',
      body = 'Ersetzt das Zeichen unter dem Cursor, ohne in den Einfügemodus zu wechseln\nSchneller als x + i + Zeichen für Tippfehler an einem einzelnen Zeichen',
      example = 'ra → ersetzt das Zeichen unter dem Cursor durch a',
    },
    ['s'] = {
      title = 's — Zeichen ersetzen und einfügen',
      body = 'Löscht das Zeichen unter dem Cursor und wechselt sofort in den Einfügemodus\nEin Tastendruck statt x + i',
      example = 's → löscht aktuelles Zeichen → Einfügemodus beginnt',
    },
    ['cc'] = {
      title = 'cc — gesamte aktuelle Zeile ändern',
      body = 'Leert den Zeileninhalt und wechselt in einer Bewegung in den Einfügemodus\nSchneller als zum Zeilenanfang zu gehen, D zu drücken und dann in den Einfügemodus zu wechseln',
      example = 'cc → Zeile wird geleert → Einfügemodus',
    },

    -- ── join lines ───────────────────────────────────────────────────────
    ['J'] = {
      title = 'J — nächste Zeile an die aktuelle anhängen',
      body = 'Hängt die Zeile darunter mit einem einzelnen Leerzeichen an die aktuelle Zeile an\nKein Gang zum Zeilenende, Löschen des Zeilenumbruchs und Hinzufügen eines Leerzeichens nötig',
      example = 'J → "foo\\n  bar" wird zu "foo bar" (Einrückung entfernt)',
    },

    -- ── case toggle ───────────────────────────────────────────────────────
    ['~'] = {
      title = '~ — Groß-/Kleinschreibung des Zeichens unter dem Cursor umschalten',
      body = 'Wandelt Klein- in Großbuchstaben um und umgekehrt, rückt dann ein Zeichen vor\nMit Zahl davor: 3~ schaltet die nächsten 3 Zeichen auf einmal um',
      example = '~ auf "hello" → "Hello" → Cursor rückt vor',
    },

    -- ── number increment / decrement ──────────────────────────────────────
    ['<C-a>'] = {
      title = '<C-a> — Zahl unter dem Cursor erhöhen',
      body = 'Findet die nächste Zahl in der Zeile und addiert eins\nMit Zahl davor mehr addieren: 5<C-a> addiert 5',
      example = '<C-a> auf "padding: 8px" → "padding: 9px"',
    },
    ['<C-x>'] = {
      title = '<C-x> — Zahl unter dem Cursor verringern',
      body = 'Die Gegenrichtung zu <C-a> — subtrahiert eins von der nächsten Zahl\nNützlich, um Zahlenwerte anzupassen, ohne sie manuell neu einzutippen',
      example = '<C-x> auf "z-index: 10" → "z-index: 9"',
    },

    -- ── visual mode chain ─────────────────────────────────────────────────
    ['V'] = {
      title = 'V — zeilenweise visuelle Auswahl starten',
      body = 'Wählt ganze Zeilen statt einzelner Zeichen aus\nIdeal, um ganze Zeilen mit visuellem Feedback zu verschieben, zu kopieren oder zu löschen',
      example = 'Vjjd → wählt visuell 3 Zeilen aus und löscht sie',
    },
    ['<C-v>'] = {
      title = '<C-v> — blockweise (spaltenweise) visuelle Auswahl starten',
      body = 'Wählt einen rechteckigen Block über mehrere Zeilen aus\nMächtig zum Bearbeiten ausgerichteter Spalten — Text voranstellen, Werte massenhaft ändern',
      example = '<C-v>3jI// <Esc> → stellt 4 Zeilen auf einmal // voran',
    },

    -- ── yank text object ──────────────────────────────────────────────────
    ['yiw'] = {
      title = 'yiw — inneres Wort kopieren',
      body = 'Kopiert das ganze Wort unter dem Cursor, egal an welcher Position im Wort\nKombiniere mit ciw (ändern) und diw (löschen) für konsistentes Bearbeiten auf Wortebene',
      example = 'yiw, dann zum Zielwort bewegen und ciw p → Wort ersetzen',
    },

    -- ── macros ────────────────────────────────────────────────────────────
    ['q'] = {
      title = 'q — Makro aufnehmen',
      body = 'q{a} beginnt die Aufnahme in Register a; erneutes q stoppt sie\n@{a} spielt es ab; @@ wiederholt das letzte Makro — automatisiert repetitive Bearbeitungen',
      example = 'qaIhello<Esc>q, dann @a → fügt beim Abspielen "hello" am Zeilenanfang ein',
    },

    -- ── backward search pair ──────────────────────────────────────────────
    ['N'] = {
      title = 'N — zum vorherigen Suchtreffer springen',
      body = 'n springt vorwärts zum nächsten Treffer; N springt rückwärts zum vorherigen\nRichtung jederzeit wechseln, ohne das Suchmuster neu einzutippen',
      example = '/foo → nnn N → 3 Treffer vorwärts, dann einen zurück',
    },
    ['#'] = {
      title = '# — rückwärts nach dem Wort unter dem Cursor suchen',
      body = '* sucht vorwärts nach dem Wort unter dem Cursor; # sucht rückwärts\nFindet sofort alle Vorkommen, ohne den Suchbegriff einzutippen',
      example = 'Cursor auf "foo" → # → springt zum vorherigen Vorkommen von "foo"',
    },

    -- ── G → gg ───────────────────────────────────────────────────────────
    ['gg'] = {
      title = 'gg — zur ersten Zeile der Datei springen',
      body = 'G springt zum Dateiende; gg springt zum Anfang\nMit Zahl davor: 5gg springt direkt zu Zeile 5',
      example = 'gg → Cursor landet in Zeile 1',
    },

    -- ── wrapped-line movement ─────────────────────────────────────────────
    ['gj'] = {
      title = 'gj — eine visuelle (angezeigte) Zeile nach unten',
      body = 'Bei umgebrochenen Zeilen überspringt j die ganze umgebrochene Zeile; gj bewegt eine Anzeigezeile\nUnverzichtbar beim Bearbeiten langer Texte oder Markdown mit aktiviertem Umbruch',
      example = 'gj bei einem umgebrochenen Absatz → Cursor bewegt sich zur nächsten Bildschirmzeile',
    },
    ['gk'] = {
      title = 'gk — eine visuelle (angezeigte) Zeile nach oben',
      body = 'Die Gegenrichtung zu gj — bewegt eine Anzeigezeile nach oben bei umgebrochenen Zeilen\nKombiniere gj / gk für natürliche Bewegung durch umgebrochenen Text',
      example = 'gk bei einem umgebrochenen Absatz → Cursor bewegt sich zur vorherigen Bildschirmzeile',
    },

    -- ── line-by-line scrolling ────────────────────────────────────────────
    ['<C-e>'] = {
      title = '<C-e> — Fenster eine Zeile nach oben scrollen, ohne den Cursor zu bewegen',
      body = 'Verschiebt den sichtbaren Bereich eine Zeile nach oben; der Cursor bleibt in derselben Zeile\nKombiniere mit <C-y>, um die Ansicht anzupassen, ohne die Bearbeitungsposition zu verlieren',
      example = '<C-e><C-e> → Text scrollt 2 Zeilen nach oben; Cursor bleibt stehen',
    },
    ['<C-y>'] = {
      title = '<C-y> — Fenster eine Zeile nach unten scrollen, ohne den Cursor zu bewegen',
      body = 'Die Gegenrichtung zu <C-e> — zeigt eine weitere Zeile oben an\nPasst den sichtbaren Bereich an, ohne die Bearbeitungsposition zu verschieben',
      example = '<C-y> → eine weitere Zeile scrollt oben ins Bild',
    },

    -- ── change list navigation ────────────────────────────────────────────
    ['g;'] = {
      title = 'g; — zu einer älteren Position in der Änderungsliste springen',
      body = 'Jede Änderung wird der Änderungsliste hinzugefügt; g; geht sie rückwärts durch\nAnders als die Sprungliste — nur Positionen, an denen Text tatsächlich geändert wurde',
      example = 'g; g; → zu den letzten zwei bearbeiteten Stellen zurückspringen',
    },
    ['g,'] = {
      title = 'g, — zu einer neueren Position in der Änderungsliste springen',
      body = 'Nachdem g; dich in der Änderungsliste zurückgebracht hat, bringt dich g, wieder vorwärts\nNavigiere deinen Bearbeitungsverlauf in beide Richtungen',
      example = 'g; g, → zur letzten Änderung zurück, dann wieder vor',
    },

    -- ── return to last insert / alternate file / last jump ────────────────
    ['gi'] = {
      title = 'gi — zur letzten Einfügeposition springen und Einfügemodus starten',
      body = 'Bringt den Cursor dorthin zurück, wo du den Einfügemodus zuletzt verlassen hast, und wechselt sofort wieder hinein\nErspart das manuelle Zurücknavigieren nach dem Lesen eines anderen Dateiteils',
      example = 'gi → Cursor springt dorthin, wo du zuletzt aufgehört hast zu tippen → Einfügemodus',
    },
    ['<C-^>'] = {
      title = '<C-^> — zur alternativen (zuletzt bearbeiteten) Datei wechseln',
      body = 'Wechselt zwischen der aktuellen Datei und der zuletzt geöffneten\nDer schnellste Weg, zwischen zwei aktiv bearbeiteten Dateien zu wechseln',
      example = '<C-^> → letzte Datei öffnen → <C-^> → zurück zur ersten',
    },
    ["''"] = {
      title = "'' — zur Zeile des vorherigen Sprungs zurückspringen",
      body = "Eine schnelle Rückkehr zur Zeile, in der du vor der letzten großen Navigation warst\n'' verwendet Zeilengenauigkeit; `` (Backticks) stellt auch die genaue Spalte wieder her",
      example = "G '' → zum Dateiende springen, dann zur ursprünglichen Zeile zurückkehren",
    },

    -- ── definition / file under cursor ────────────────────────────────────
    ['gd'] = {
      title = 'gd — zur lokalen Definition springen',
      body = 'Durchsucht den aktuellen Funktionsbereich nach der ersten Deklaration des Wortes unter dem Cursor\nSchneller als Grepen — kein Verlassen der Datei oder Eintippen eines Suchmusters nötig',
      example = 'Cursor auf "myVar" → gd → springt dorthin, wo myVar zuerst deklariert wird',
    },
    ['gf'] = {
      title = 'gf — Datei bearbeiten, deren Name unter dem Cursor steht',
      body = 'Öffnet den Dateinamen unter dem Cursor als neuen Puffer im aktuellen Fenster\nFunktioniert mit relativen Pfaden, absoluten Pfaden und Dateinamen in Zeichenketten',
      example = 'Cursor auf "utils/helpers.lua" → gf → öffnet diese Datei',
    },

    -- ── reselect last visual ──────────────────────────────────────────────
    ['gv'] = {
      title = 'gv — letzte visuelle Auswahl wiederherstellen',
      body = 'Aktiviert genau dieselbe visuelle Auswahl wie beim letzten Gebrauch des visuellen Modus erneut\nSpart Zeit, wenn du eine zweite Operation auf denselben Bereich anwenden musst',
      example = 'vip y gv d → kopiert einen Absatz, wählt ihn dann erneut aus und löscht ihn',
    },

    -- ── WORD-end backward ─────────────────────────────────────────────────
    ['gE'] = {
      title = 'gE — zum Ende des vorherigen WORD springen',
      body = 'ge springt zum Ende des vorherigen Wortes; gE macht dasselbe, überspringt aber alle Satzzeichen\nDas WORD-Gegenstück zu ge — überspringt "foo.bar.baz" als ein einziges Token',
      example = 'gE auf foo.bar → springt zum Ende des vorherigen WORD',
    },

    -- ── fold commands ─────────────────────────────────────────────────────
    ['za'] = {
      title = 'za — Faltung am Cursor umschalten',
      body = 'Öffnet eine geschlossene Faltung oder schließt eine offene unter dem Cursor\nDer bequemste Faltungsbefehl — eine Taste, um einen Abschnitt anzusehen oder zu verbergen',
      example = 'za → faltet den zusammengeklappten Block auf; za erneut → faltet ihn wieder zu',
    },
    ['zo'] = {
      title = 'zo — Faltung am Cursor öffnen',
      body = 'Zeigt die in einer Faltung verborgenen Zeilen, ohne benachbarte offene Faltungen zu beeinflussen\nAnders als za öffnet zo nur — es schließt niemals versehentlich eine bereits offene Faltung',
      example = 'zo → verborgene Zeilen in der Faltung werden sichtbar',
    },
    ['zc'] = {
      title = 'zc — Faltung am Cursor schließen',
      body = 'Klappt eine offene Faltung zu einer einzigen Zusammenfassungszeile zusammen\nDas Gegenteil von zo — schließt nur, öffnet nie versehentlich',
      example = 'zc → der ausgeklappte Block klappt zu einer Zusammenfassungszeile zusammen',
    },
    ['zM'] = {
      title = 'zM — alle Faltungen im Puffer schließen',
      body = 'Klappt alle Faltungen der Datei auf einmal zusammen — bietet eine vollständige Gliederungsansicht\nNützlich, um eine große Datei nach Struktur zu durchsuchen, bevor man in einen Abschnitt eintaucht',
      example = 'zM → alle Funktionen klappen zusammen → nur die oberste Struktur bleibt sichtbar',
    },
    ['zR'] = {
      title = 'zR — alle Faltungen im Puffer öffnen',
      body = 'Klappt alle Faltungen der Datei auf — das Gegenteil von zM\nStellt die vollständig aufgeklappte Ansicht nach dem Erkunden mit Faltungsnavigation wieder her',
      example = 'zM zR → alle Faltungen zuklappen, dann alles wieder aufklappen',
    },

    -- ── delete before / replace mode / yank to EOL ────────────────────────
    ['X'] = {
      title = 'X — Zeichen vor dem Cursor löschen',
      body = 'Löscht ein Zeichen links vom Cursor, ohne in den Einfügemodus zu wechseln\nWie Rücktaste im Normalmodus zu drücken',
      example = 'X → das Zeichen direkt links vom Cursor wird entfernt',
    },
    ['R'] = {
      title = 'R — Ersetzungsmodus starten',
      body = 'Überschreibt vorhandenen Text Zeichen für Zeichen beim Tippen — ohne einzufügen oder zu verschieben\nIdeal, um einen Abschnitt fester Breite zu ersetzen, während der umgebende Text erhalten bleibt',
      example = 'Rhello → überschreibt die nächsten 5 Zeichen mit "hello"',
    },
    ['Y'] = {
      title = 'Y — vom Cursor bis Zeilenende kopieren',
      body = 'Kopiert den Text von der Cursorposition bis zum Zeilenende (entspricht y$)\nErgänzt D (bis Zeilenende löschen) und C (bis Zeilenende ändern) für konsistente Operationen am Zeilenende',
      example = 'Y p → kopiert den Rest der Zeile und fügt ihn darunter ein',
    },

    -- ── indent operators ──────────────────────────────────────────────────
    ['>>'] = {
      title = '>> — aktuelle Zeile einrücken',
      body = 'Verschiebt die aktuelle Zeile um eine Einrückungsebene nach rechts\nMit Zahl davor: 3>> rückt die nächsten 3 Zeilen auf einmal ein',
      example = '>> → aktuelle Zeile um eine Ebene eingerückt',
    },
    ['<<'] = {
      title = '<< — Einrückung der aktuellen Zeile entfernen',
      body = 'Verschiebt die aktuelle Zeile um eine Einrückungsebene nach links\nDas Gegenteil von >> — zum Korrigieren von übermäßig eingerücktem Code',
      example = '<< → aktuelle Zeile um eine Ebene zurückgerückt',
    },
    ['=='] = {
      title = '== — aktuelle Zeile automatisch einrücken',
      body = 'Führt den eingebauten Einrücker auf der aktuellen Zeile gemäß den Dateityp-Regeln aus\nSchneller als manuelles Korrigieren mit >> oder <<, wenn die Einrückung komplex ist',
      example = '== → Zeile rastet automatisch auf die richtige Einrückungsebene ein',
    },

    -- ── case operators ────────────────────────────────────────────────────
    ['gu'] = {
      title = 'gu{motion} — Bereich in Kleinbuchstaben umwandeln',
      body = 'Wendet Kleinschreibung auf den von der Bewegung erfassten Text an\nguiw → aktuelles Wort in Kleinbuchstaben; gu$ → Kleinbuchstaben bis Zeilenende',
      example = 'guiw → "Hello" wird zu "hello"',
    },
    ['gU'] = {
      title = 'gU{motion} — Bereich in Großbuchstaben umwandeln',
      body = 'Das Großbuchstaben-Gegenstück zu gu — wandelt den Text der Bewegung in GROSSBUCHSTABEN um\ngUiw → inneres Wort in Großbuchstaben',
      example = 'gUiw → "hello" wird zu "HELLO"',
    },
    ['g~'] = {
      title = 'g~{motion} — Groß-/Kleinschreibung eines Bereichs umschalten',
      body = 'Kehrt die Groß-/Kleinschreibung jedes Zeichens in der Bewegung um — Groß wird klein und umgekehrt\nWie ~ auf eine ganze Bewegung statt auf ein einzelnes Zeichen anzuwenden',
      example = 'g~iw → "Hello World" wird zu "hELLO wORLD"',
    },

    -- ── format text ───────────────────────────────────────────────────────
    ['gq'] = {
      title = 'gq{motion} — Text umfließen / an Zeilenbreite anpassen',
      body = 'Formatiert den von der Bewegung erfassten Text neu, um bei textwidth umzubrechen\ngqip formatiert den aktuellen Absatz; gqq formatiert die aktuelle Zeile',
      example = 'gqip → aktueller Absatz wird auf die eingestellte Zeilenbreite umformatiert',
    },

    -- ── join without space ────────────────────────────────────────────────
    ['gJ'] = {
      title = 'gJ — Zeilen zusammenführen ohne Leerzeichen einzufügen',
      body = 'Wie J, fügt aber kein Leerzeichen zwischen den zusammengeführten Zeilen ein\nNützlich beim Zusammenführen von Zeilen, wo ein zusätzliches Leerzeichen die Syntax brechen würde',
      example = 'gJ → "foo\\n  bar" wird zu "foobar" (kein Leerzeichen eingefügt)',
    },

    -- ── repeat last macro ─────────────────────────────────────────────────
    ['@@'] = {
      title = '@@ — zuletzt abgespieltes Makro wiederholen',
      body = 'Spielt das zuletzt mit @{reg} ausgeführte Makro erneut ab\nErspart erneutes Eintippen des Registernamens beim Wiederholen mit demselben Makro',
      example = '@a → Makro a ausführen; @@ → Makro a erneut ausführen, ohne "a" erneut anzugeben',
    },

    -- ── text object chain ─────────────────────────────────────────────────
    ['ci"'] = {
      title = 'ci" — inneren doppelten Anführungszeichen-String ändern',
      body = 'Löscht den Inhalt zwischen den nächstgelegenen doppelten Anführungszeichen und wechselt in den Einfügemodus\nDas Textobjekt i" funktioniert mit jedem Operator: c, d, y, v',
      example = 'bei "hello world" → ci" → Inhalt wird geleert → Ersatztext eintippen',
    },
    ["ci'"] = {
      title = "ci' — inneren einfachen Anführungszeichen-String ändern",
      body = 'Wie ci", zielt aber auf einfache statt doppelte Anführungszeichen\nFunktioniert überall, wo der Cursor innerhalb eines Paares einfacher Anführungszeichen steht',
      example = "bei 'hello' → ci' → Inhalt wird geleert → Ersatztext eintippen",
    },
    ['cib'] = {
      title = 'cib — inneren Klammerblock ändern',
      body = 'Löscht den Inhalt innerhalb der nächstgelegenen () und wechselt in den Einfügemodus\nib ist das „innerer Block"-Textobjekt — dasselbe wie i( — funktioniert innerhalb von Funktionsaufrufen',
      example = 'bei foo(bar, baz) → cib → löscht "bar, baz" → neue Argumente eintippen',
    },
    ['ciB'] = {
      title = 'ciB — inneren geschweiften Block ändern',
      body = 'Zielt auf den Inhalt innerhalb des nächstgelegenen {}-Blocks\nB ist das „großer Block"-Textobjekt; nützlich, um einen Funktionskörper zu leeren oder umzuschreiben',
      example = 'innerhalb eines Funktionskörpers → ciB → löscht den ganzen Körper → Einfügemodus',
    },
    ['cit'] = {
      title = 'cit — inneren HTML-/XML-Tag-Inhalt ändern',
      body = 'Löscht den Text zwischen den nächstgelegenen öffnenden und schließenden Tags und wechselt in den Einfügemodus\nit ist das „innerer Tag"-Textobjekt — funktioniert mit jedem Tag-Paar',
      example = 'bei <p>hello</p> → cit → löscht "hello" → neuen Inhalt eintippen',
    },
    ['cip'] = {
      title = 'cip — inneren Absatz ändern',
      body = 'Ersetzt den gesamten aktuellen Absatz (zusammenhängender Block nicht leerer Zeilen)\nip wählt bis zu, aber ohne die umgebenden Leerzeilen',
      example = 'cip → gesamter aktueller Absatz wird geleert → Einfügemodus',
    },

    -- ── partial word search ───────────────────────────────────────────────
    ['g*'] = {
      title = 'g* — vorwärts nach Teiltreffer des Wortes unter dem Cursor suchen',
      body = '* erfordert einen vollständigen Worttreffer; g* trifft das Wort auch als Teilzeichenfolge\nNützlich, wenn "foo" auch "foobar", "football" und "foo" gleichermaßen finden soll',
      example = 'g* auf "foo" → trifft "foo", "foobar", "fooResult"',
    },
    ['g#'] = {
      title = 'g# — rückwärts nach Teiltreffer des Wortes unter dem Cursor suchen',
      body = 'Das rückwärtsgerichtete Gegenstück zu g* — sucht die Teilzeichenfolge nach oben durch die Datei\nFindet alle Vorkommen einschließlich Teiltreffer wie g*, aber rückwärts',
      example = 'g# auf "foo" → springt zurück zum vorherigen "foo" oder "foobar"',
    },

    -- ── window management ─────────────────────────────────────────────────
    ['<C-w>s'] = {
      title = '<C-w>s — Fenster horizontal teilen',
      body = 'Öffnet eine horizontale Teilung, um zwei Teile einer Datei gleichzeitig zu sehen\n<C-w>v erstellt eine vertikale Teilung nebeneinander',
      example = '<C-w>s → zwei horizontale Fensterbereiche; navigiere unabhängig in jedem',
    },
    ['<C-w>v'] = {
      title = '<C-w>v — Fenster vertikal teilen',
      body = 'Öffnet eine vertikale Teilung — zwei Fensterbereiche nebeneinander im selben Tab\nKombiniere mit <C-w>h und <C-w>l, um zwischen ihnen zu wechseln',
      example = '<C-w>v → zwei vertikale Fensterbereiche; <C-w>l → zum rechten Bereich wechseln',
    },
    ['<C-w>w'] = {
      title = '<C-w>w — zum nächsten Fenster wechseln',
      body = 'Bewegt den Fokus zur nächsten Teilung im Layout, ohne eine Richtung anzugeben\nDer schnellste Weg, zwischen zwei Fensterbereichen zu springen',
      example = '<C-w>w → Fokus wechselt zur nächsten offenen Teilung',
    },
    ['<C-w>h'] = {
      title = '<C-w>h — Fokus zum linken Fenster bewegen',
      body = 'Richtungsbezogene Fensternavigation — bewegt den Fokus nach links, so wie h den Cursor nach links bewegt\nVerwende die Varianten h / j / k / l für präzise Teilungsnavigation',
      example = '<C-w>h → Cursor bewegt sich zur unmittelbar linken Teilung',
    },
    ['<C-w>j'] = {
      title = '<C-w>j — Fokus zum unteren Fenster bewegen',
      body = 'Bewegt den Fokus nach unten zur Teilung unterhalb der aktuellen\nFunktioniert sowohl bei horizontalen als auch gemischten Teilungslayouts',
      example = '<C-w>j → Cursor bewegt sich zur unteren Teilung',
    },
    ['<C-w>k'] = {
      title = '<C-w>k — Fokus zum oberen Fenster bewegen',
      body = 'Bewegt den Fokus nach oben zur Teilung oberhalb der aktuellen\nDie Gegenrichtung zu <C-w>j',
      example = '<C-w>k → Cursor bewegt sich zur oberen Teilung',
    },
    ['<C-w>l'] = {
      title = '<C-w>l — Fokus zum rechten Fenster bewegen',
      body = 'Bewegt den Fokus nach rechts zur rechten Teilung\nKombiniere mit <C-w>h, um zwischen linkem und rechtem Fensterbereich zu wechseln',
      example = '<C-w>l → Cursor bewegt sich zur rechten Teilung',
    },
    ['<C-w>q'] = {
      title = '<C-w>q — aktuelles Fenster schließen',
      body = 'Schließt die fokussierte Teilung; der Puffer selbst bleibt offen\nVerwende :bd, um zusätzlich den Puffer zu löschen; :qa, um alle Teilungen auf einmal zu schließen',
      example = '<C-w>q → fokussierter Bereich schließt; verbleibender Bereich dehnt sich aus, um den Platz zu füllen',
    },
    ['<C-w>='] = {
      title = '<C-w>= — Größe aller Fenster angleichen',
      body = 'Passt alle offenen Teilungen auf gleiche Breite und Höhe an\nEin schnelles Zurücksetzen, wenn Teilungen nach manueller Größenänderung unausgeglichen werden',
      example = '<C-w>= → alle Fensterbereiche kehren zu gleichen Abmessungen zurück',
    },
    ['$'] = {
      title = '$ — zum Zeilenende springen',
      body = 'Bewegt den Cursor zum letzten Zeichen der aktuellen Zeile\nKombiniere mit ^ (erstes Nicht-Leerzeichen) für schnelle Navigation der Zeilenränder',
      example = '^ → zum Anfang gehen; $ → zum Ende springen',
    },
    ['g_'] = {
      title = 'g_ — letztes Nicht-Leerzeichen der Zeile',
      body = '$ schließt nachfolgende Leerzeichen ein; g_ hält beim letzten Nicht-Leerzeichen an\nGenauer als $, wenn Zeilen nachfolgende Leerzeichen haben',
      example = '$ → landet vielleicht auf einem Leerzeichen; g_ → hält beim letzten echten Zeichen an',
    },
    ['F'] = {
      title = 'F — Zeichen rückwärts suchen',
      body = 'Wie f{Zeichen}, sucht aber in der aktuellen Zeile links statt rechts\n; und , wiederholen die Suche weiterhin',
      example = 'f, → vorwärts zum Komma; F, → rückwärts zum Komma',
    },
    ['('] = {
      title = '( — zum Satzanfang springen',
      body = 'Wie { für Absätze springt ( zum Anfang des aktuellen Satzes\nNützlich beim Navigieren von Fließtext, Kommentaren und Dokumentation',
      example = '{ → Absatzanfang; ( → Satzanfang',
    },
    [')'] = {
      title = ') — zum Anfang des nächsten Satzes springen',
      body = 'Bewegt den Cursor vorwärts zum Anfang des nächsten Satzes\nKombiniere mit ( für Sprünge zwischen Sätzen in beide Richtungen',
      example = '( dann ) → vorwärts und rückwärts durch Sätze springen',
    },
    ['[['] = {
      title = '[[ — vorherige Funktion / Abschnitt',
      body = 'Springt zur ersten Zeile der vorherigen Funktions- oder Abschnittsgrenze\nSchneller als gg + Suche beim Navigieren einer Datei mit vielen Funktionen',
      example = 'gg → Dateianfang; [[ → Anfang der vorherigen Funktion',
    },
    [']]'] = {
      title = ']] — nächste Funktion / Abschnitt',
      body = 'Springt zur ersten Zeile der nächsten Funktions- oder Abschnittsgrenze\nKombiniere mit [[, um zwischen Funktionen zu springen, ohne den Normalmodus zu verlassen',
      example = 'G → Dateiende; ]] → Anfang der nächsten Funktion',
    },
    ['[{'] = {
      title = '[{ — zur umschließenden { springen',
      body = 'Springt rückwärts zur nächstgelegenen ungepaarten öffnenden geschweiften Klammer\nUnverzichtbar, um schnell den Anfang eines Blocks, einer Funktion oder Struktur zu erreichen',
      example = '% → passende Klammer; [{ → Anfang des umschließenden Blocks',
    },
    [']}'] = {
      title = ']} — zur umschließenden } springen',
      body = 'Springt vorwärts zur nächstgelegenen ungepaarten schließenden geschweiften Klammer\nKombiniere mit [{, um in verschachtelte Blöcke hinein- und herauszunavigieren',
      example = '[{ → Blockanfang; ]} → Blockende',
    },
    ['[('] = {
      title = '[( — zur umschließenden ( springen',
      body = 'Springt rückwärts zur nächstgelegenen ungepaarten öffnenden Klammer\nNützlich bei langen Funktionsaufrufen, Bedingungen oder mehrzeiligen Ausdrücken',
      example = '[{ → Block; [( → umschließende Klammer',
    },
    ['])'] = {
      title = ']) — zur umschließenden ) springen',
      body = 'Springt vorwärts zur nächstgelegenen ungepaarten schließenden Klammer\nKombiniere mit [(, um in verschachtelte Klammern hinein- und herauszunavigieren',
      example = '[( → öffnende Klammer; ]) → schließende Klammer',
    },
    ['g0'] = {
      title = 'g0 — erstes Zeichen der Bildschirmzeile',
      body = 'Bei umgebrochenen Zeilen springt 0 zum echten Zeilenanfang; g0 zum Anfang der umgebrochenen Zeile\nNützlich beim Bearbeiten langer Zeilen mit aktiviertem Umbruch',
      example = 'gj → nächste visuelle Zeile; g0 → Anfang dieser visuellen Zeile',
    },
    ['gx'] = {
      title = 'gx — Datei oder URL unter dem Cursor öffnen',
      body = 'Öffnet den Dateipfad oder die URL unter dem Cursor mit der Standardanwendung des Systems\nFunktioniert mit http/https-URLs, lokalen Dateipfaden und mehr',
      example = 'gf → Datei in Vim bearbeiten; gx → im Browser oder Finder öffnen',
    },
    ['<C-]>'] = {
      title = '<C-]> — zur Tag-Definition springen',
      body = 'Folgt dem Tag (ctags-Definition) unter dem Cursor zu seiner Deklaration\nBenötigt eine tags-Datei; <C-t> oder <C-o> springt zurück',
      example = 'gd → lokale Definition; <C-]> → ctags-Definition',
    },
    ['K'] = {
      title = 'K — Stichwort unter dem Cursor nachschlagen',
      body = 'Führt das Programm aus keywordprg (Standard: man) auf dem Wort unter dem Cursor aus\nIn vielen LSP-Setups zeigt K stattdessen Dokumentation beim Hovern',
      example = 'gd → zur Definition gehen; K → Dokumentation anzeigen',
    },
    ['gp'] = {
      title = 'gp — einfügen und Cursor nach dem eingefügten Text lassen',
      body = 'Wie p, lässt den Cursor aber direkt nach dem eingefügten Text stehen\nPraktisch, wenn du sofort nach dem Einfügen weiterschreiben willst',
      example = 'p → Cursor bleibt vor dem Eingefügten; gp → Cursor bewegt sich danach',
    },
    ['gP'] = {
      title = 'gP — davor einfügen und Cursor danach lassen',
      body = 'Wie P (vor dem Cursor einfügen), bewegt den Cursor aber direkt nach den eingefügten Text\nDas Großbuchstaben-Gegenstück zu gp',
      example = 'P → fügt davor ein, Cursor davor; gP → fügt davor ein, Cursor danach',
    },
    ['@:'] = {
      title = '@: — letzten Befehlszeilenbefehl wiederholen',
      body = 'Wiederholt den zuletzt ausgeführten :-Befehl, ohne ihn neu einzutippen\nNach @: kannst du @@ verwenden, um ihn erneut zu wiederholen',
      example = ':s/foo/bar/ dann @: → wiederholt die Substitution',
    },
    ['zj'] = {
      title = 'zj — zum Anfang der nächsten Faltung springen',
      body = 'Bewegt den Cursor nach unten zum Anfang der nächsten geschlossenen oder offenen Faltung\nSchneller als über Faltungen hinwegzuscrollen bei stark gefalteten Dateien',
      example = 'za → Faltung umschalten; zj → zur nächsten Faltung springen',
    },
    ['zk'] = {
      title = 'zk — zum Ende der vorherigen Faltung springen',
      body = 'Bewegt den Cursor nach oben zum Ende der vorherigen Faltung\nKombiniere mit zj, um in beide Richtungen zwischen Faltungen zu springen',
      example = 'zj → nächste Faltung; zk → vorherige Faltung',
    },
    ['zd'] = {
      title = 'zd — Faltung am Cursor löschen',
      body = 'Entfernt die Faltungsdefinition unter dem Cursor, ohne den Text zu beeinflussen\nNützlich zum Aufräumen manueller Faltungen, die mit zf erstellt wurden',
      example = 'zc → Faltung schließen; zd → diese Faltungsdefinition löschen',
    },
    ['E'] = {
      title = 'E — vorwärts zum Ende des WORD springen',
      body = 'Wie e, springt aber zum Ende des nächsten WORD (beliebige Nicht-Leerzeichen-Folge)\nIgnoriert Satzzeichengrenzen, an denen e anhalten würde',
      example = 'e → Wortende; E → WORD-Ende (überspringt Satzzeichen)',
    },
    ['U'] = {
      title = 'U — alle Änderungen der aktuellen Zeile rückgängig machen',
      body = 'Stellt die aktuelle Zeile so wieder her, wie sie war, als du dich zu ihr bewegt hast\nAnders als u: U macht alle Bearbeitungen einer Zeile auf einmal rückgängig',
      example = 'u → letzte Änderung rückgängig machen; U → gesamte Zeile wiederherstellen',
    },
    ['ZZ'] = {
      title = 'ZZ — speichern und beenden',
      body = 'Speichert die Datei und schließt das Fenster mit einem Tastendruck\nEntspricht :wq, aber schneller zu tippen',
      example = ':wq  oder  ZZ — gleiches Ergebnis, ZZ spart zwei Tastendrücke',
    },
    ['ZQ'] = {
      title = 'ZQ — ohne Speichern beenden',
      body = 'Schließt das Fenster und verwirft Änderungen ohne Bestätigungsaufforderung\nEntspricht :q!, aber schneller zu tippen',
      example = 'ZZ → speichern und beenden; ZQ → beenden und Änderungen verwerfen',
    },
    ['q:'] = {
      title = 'q: — Befehlszeilenfenster öffnen',
      body = 'Öffnet einen Puffer mit deinem Ex-Befehlsverlauf\nDu kannst jeden vorherigen Befehl bearbeiten und mit Enter erneut ausführen',
      example = 'q → Makro aufnehmen; q: → Befehlsverlauf durchsuchen und bearbeiten',
    },
    ['|'] = {
      title = '| — zu Spalte N springen',
      body = 'Springt mit dem Cursor zu Spalte N in der aktuellen Zeile\nNützlich zum Ausrichten von Text oder Navigieren zu einer bekannten Spaltenposition',
      example = '0 → Spalte 1; 40| → Spalte 40',
    },
    ['_'] = {
      title = '_ — erstes Nicht-Leerzeichen der Zeile (relativ)',
      body = 'Bewegt sich zum ersten Nicht-Leerzeichen der aktuellen Zeile\nMit einer Zahl N geht es N-1 Zeilen nach unten und dann zum ersten Nicht-Leerzeichen',
      example = '^ → erstes Nicht-Leerzeichen; 3_ → erstes Nicht-Leerzeichen 2 Zeilen tiefer',
    },

    -- ── fold: additional commands ─────────────────────────────────────────
    ['zf'] = {
      title = 'zf — Faltung manuell erstellen',
      body = 'Erstellt eine Faltung über eine Bewegung oder visuelle Auswahl (erfordert foldmethod=manual)\nVerwende zd zum Löschen; zf{motion} faltet, was die Bewegung erfasst',
      example = 'zfip → faltet den aktuellen Absatz; zd → löscht diese Faltung',
    },

    -- ── macro: play specific register ────────────────────────────────────
    ['@q'] = {
      title = '@q — Makro aus Register q abspielen',
      body = 'Spielt die im Register q aufgezeichnete Tastenfolge erneut ab\nErsetze q durch einen beliebigen Buchstaben a-z, um aus einem anderen Register abzuspielen',
      example = 'qq → Aufnahme starten; q → stoppen; @q → abspielen',
    },

    -- ── marks ─────────────────────────────────────────────────────────────
    ["'."] = {
      title = "'. — zur letzten Änderungsposition springen",
      body = 'Bewegt den Cursor zur genauen Position der letzten Bearbeitung\nSchneller als wiederholtes Ctrl-O, wenn du zu deiner letzten Änderung zurückkehren musst',
      example = "G dann '. → zum Ende springen, zur letzten bearbeiteten Stelle zurückkehren",
    },
    ["'^"] = {
      title = "'^ — zur letzten Einfügeposition springen",
      body = "Bringt den Cursor zurück zu der Position, an der du zuletzt den Einfügemodus verlassen hast\nAnders als '. — merkt sich, wo du den Einfügemodus verlassen hast, nicht die letzte Textänderung",
      example = "A dann <Esc> dann '^ → zurück zum Einfügepunkt am Zeilenende",
    },
    ['ma'] = {
      title = 'ma — Marke a am Cursor setzen',
      body = "Setzt eine Marke namens 'a' an der aktuellen Position\nVerwende einen beliebigen Kleinbuchstaben a-z; rufe sie ab mit 'a (Zeile) oder `a (genaue Spalte)",
      example = "ma → hier markieren; G → woanders hingehen; 'a → zur markierten Zeile zurückspringen",
    },
    ["'a"] = {
      title = "'a — zur Marke a springen",
      body = "Bewegt den Cursor zur Zeile, in der die Marke 'a' gesetzt wurde\nVerwende den Backtick `a für spaltengenaue Sprünge; kombiniere mit ma als Navigationsanker",
      example = "ma → Marke setzen; dd → woanders bearbeiten; 'a → zur markierten Zeile zurückkehren",
    },

    -- ── l → w / h → b word motion (detected by l_repeat / h_repeat) ──────────
    ['w'] = {
      title = 'w — zum Anfang des nächsten Wortes springen',
      body = 'Springt vorwärts jeweils ein Wort statt ein Zeichen\nSchneller als wiederholtes l — verwende w für wortweise Bewegung, l zum Feinjustieren',
      example = 'w w w → drei Wörter vorwärts',
    },
    ['b'] = {
      title = 'b — zum Anfang des vorherigen Wortes springen',
      body = 'Springt rückwärts jeweils ein Wort — die Gegenrichtung zu w\nSchneller als wiederholtes h beim Bewegen um mehrere Wörter nach links',
      example = 'b b b → drei Wörter zurück',
    },

    -- ── count prefix variants ─────────────────────────────────────────────────
    ['{n}dd'] = {
      title = '{n}dd — mehrere Zeilen auf einmal löschen',
      body = 'Setze eine Zahl vor dd, um so viele Zeilen in einem Befehl zu löschen\n3dd löscht 3 Zeilen ab dem Cursor — kein wiederholtes dd nötig',
      example = '3dd → löscht 3 Zeilen auf einmal',
    },
    ['{n}p'] = {
      title = '{n}p — mehrfach auf einmal einfügen',
      body = 'Setze eine Zahl vor p, um denselben Inhalt N-mal hintereinander einzufügen\n3p fügt den kopierten Text 3-mal ein — schneller als wiederholtes p',
      example = '3p → fügt denselben Inhalt 3-mal ein',
    },
    ['{n}P'] = {
      title = '{n}P — mehrfach vor dem Cursor einfügen',
      body = 'P fügt vor dem Cursor ein; setze eine Zahl davor, um es zu wiederholen\n3P fügt den kopierten Text 3-mal über der aktuellen Zeile ein',
      example = '3P → fügt 3-mal vor dem Cursor ein',
    },
    ['{n}~'] = {
      title = '{n}~ — Groß-/Kleinschreibung mehrerer Zeichen umschalten',
      body = '~ schaltet ein Zeichen um und rückt vor; setze eine Zahl davor, um mehrere auf einmal umzuschalten\n3~ schaltet die nächsten 3 Zeichen um — erspart wiederholtes ~',
      example = '3~ auf "hello" → "HEllo"',
    },

    -- ── diw (detected by visual_textobj v i w d) ─────────────────────────────
    ['diw'] = {
      title = 'diw — inneres Wort löschen',
      body = 'Löscht das ganze Wort unter dem Cursor, egal an welcher Position im Wort er steht\nciw ändert das Wort; diw löscht es — kein vorheriges visuelles Auswählen nötig',
      example = 'he|llo → diw → Wort wird gelöscht, Cursor bleibt an Ort und Stelle',
    },

    -- ── yyp (detected by yy_then_p) ───────────────────────────────────────────
    ['yyp'] = {
      title = 'yyp — aktuelle Zeile duplizieren',
      body = 'Kopiert die ganze Zeile und fügt sie darunter ein — der idiomatische Weg, eine Zeile zu duplizieren\nyy und dann p sind dieselben Tastendrücke, aber es als yyp zu denken macht es zu einer einzigen Absicht',
      example = 'yyp bei "local x = 1" → dupliziert diese Zeile darunter',
    },

    -- ── {n}. (detected by dot_repeat × 3) ────────────────────────────────────
    ['{n}.'] = {
      title = '{n}. — letzte Änderung N-mal wiederholen',
      body = 'Setze eine Zahl vor ., um die letzte Änderung so oft auf einmal zu wiederholen\n3. wiederholt dreimal in einem Befehl, statt . dreimal einzeln zu drücken',
      example = '3. → wiederholt die letzte Änderung 3-mal',
    },

    -- ── {n}J (detected by J_repeat × 3) ──────────────────────────────────────
    ['{n}J'] = {
      title = '{n}J — mehrere Zeilen auf einmal zusammenführen',
      body = 'Setze eine Zahl vor J, um so viele Zeilen in einem Befehl zusammenzuführen\n3J führt die aktuelle Zeile mit den nächsten 2 Zeilen zusammen — kein wiederholtes J nötig',
      example = '3J → führt die aktuelle Zeile mit den nächsten 2 Zeilen zusammen',
    },

    -- ── {n}>> / {n}<< (detected by indent_run / dedent_run × 3) ─────────────
    ['{n}>>'] = {
      title = '{n}>> — mehrere Zeilen auf einmal einrücken',
      body = 'Setze eine Zahl vor >>, um so viele Zeilen in einem Befehl einzurücken\n3>> rückt 3 Zeilen ab dem Cursor ein — schneller als wiederholtes >>',
      example = '3>> → rückt 3 Zeilen auf einmal ein',
    },
    ['{n}<<'] = {
      title = '{n}<< — Einrückung mehrerer Zeilen auf einmal entfernen',
      body = 'Setze eine Zahl vor <<, um bei so vielen Zeilen in einem Befehl die Einrückung zu entfernen\n3<< entfernt eine Einrückungsebene von 3 Zeilen ab dem Cursor',
      example = '3<< → entfernt die Einrückung von 3 Zeilen auf einmal',
    },
  },
}
