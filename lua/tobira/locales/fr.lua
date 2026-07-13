return {
  guide = {
    title = 'guide tobira',
    hint = ':TobiraGuide  afficher/masquer le guide',
    all_mastered = 'Toutes les commandes de ce niveau sont maîtrisées !',
    pinned = 'Épinglé',
    focus_hint = '<C-w>w focus · [q] fermer · [r] actualiser',
    forgotten_suffix = ' (oublié)',
  },
  progress = {
    title = 'tobira — votre parcours vim',
    level_label = 'Niveau : ',
    levels = {
      novice = 'novice',
      beginner = 'débutant',
      intermediate = 'intermédiaire',
      advanced = 'avancé',
    },
    categories = {
      motion = 'Déplacement',
      edit = 'Édition',
      search = 'Recherche',
      window = 'Fenêtre',
      fold = 'Pliage',
      mark = 'Marque',
      macro = 'Macro',
    },
    mastered_total = '%d / %d maîtrisées',
    section_count = '%d / %d',
    nav_hint = '[x] masquer   [p] épingler   [g] guide   [s] stats   [q] fermer',
    keybind_help = 'tobira : raccourcis\n  x  basculer masquer\n  p  basculer épingler\n  g  guide\n  s  stats\n  q  fermer',
    preview = {
      learning = 'en cours',
      mastered = 'maîtrisé',
      forgotten = 'oublié',
      never_tried = 'jamais essayé',
      to_next = 'encore %d pour atteindre %s',
    },
  },
  notifications = {
    reset = "tobira : journal d'utilisation réinitialisé",
    no_suggestions = 'tobira : aucune nouvelle suggestion pour le moment 🎉',
    invalid_config = 'tobira : configuration invalide — ',
  },
  stats = {
    title = "tobira — statistiques d'utilisation",
    mastery = 'Maîtrise',
    mastery_dist = '  Jamais %d  ·  ☆ %d  ·  ★ %d  ·  ★★+ %d',
    top_commands = 'Commandes principales',
    try_next = '⚡ À essayer ensuite',
    nav_hint = '[g] guide   [p] progression   [q] fermer',
    footer_summary = "%s frappes jusqu'à présent · %s / %s commandes découvertes",
  },
  float = {
    example_prefix = 'ex. ',
    close_hint = 'q/Esc fermer',
    suppress_hint = ':TobiraProgress  x pour masquer',
    ambient_reason = 'Vous utilisez souvent %s',
    celebrate = 'Bien joué — vous avez utilisé %s',
    reasons = {
      f_repeat = 'Vous avez répété la même recherche f/t sur cette ligne',
      r_run = 'Vous avez remplacé 3 caractères un par un',
      visual_textobj = "Vous avez sélectionné un objet texte en mode visuel avant d'éditer",
      indent_run = 'Vous avez indenté de la même façon 3 fois de suite',
      dedent_run = 'Vous avez désindenté de la même façon 3 fois de suite',
      c_dollar = "Vous avez modifié du curseur jusqu'à la fin de la ligne",
      d_dollar = "Vous avez supprimé du curseur jusqu'à la fin de la ligne",
      dd_run = 'Vous avez supprimé des lignes seules 3 fois de suite',
      yy_then_p = 'Vous avez copié une ligne puis collée juste en dessous',
      dd_then_p = "Vous avez supprimé une ligne puis l'avez recollée en dessous",
      dd_then_insert = 'Vous avez supprimé une ligne puis commencé à en taper une nouvelle',
      zero_then_w = "Vous avez sauté à la colonne 0 puis avancé d'un mot",
      zero_then_insert = 'Vous avez sauté au début de ligne puis êtes entré en mode insertion',
      dollar_then_append = 'Vous avez sauté à la fin de ligne puis êtes entré en mode insertion',
      k_then_o = "Vous êtes monté d'une ligne puis en avez ouvert une nouvelle en dessous",
      x_then_insert = 'Vous avez supprimé un caractère puis êtes entré en mode insertion',
      D_then_insert = "Vous avez supprimé jusqu'à la fin de ligne puis commencé à taper",
      dw_then_insert = 'Vous avez supprimé un mot puis êtes entré en mode insertion',
      x_repeat = 'Vous avez supprimé des caractères un par un, 3 fois de suite',
      u_repeat = 'Vous avez annulé 3 fois de suite',
      j_repeat = 'Vous avez appuyé sur j 5 fois de suite',
      j_many = 'Vous avez appuyé sur j 10 fois de suite',
      k_repeat = 'Vous avez appuyé sur k 5 fois de suite',
      k_many = 'Vous avez appuyé sur k 10 fois de suite',
      n_repeat = 'Vous avez répété une correspondance de recherche 4 fois',
      l_repeat = 'Vous avez appuyé sur l 5 fois de suite',
      h_repeat = 'Vous avez appuyé sur h 5 fois de suite',
      w_repeat = 'Vous avez appuyé sur w 5 fois de suite',
      b_repeat = 'Vous avez appuyé sur b 5 fois de suite',
      p_repeat = 'Vous avez collé 3 fois de suite',
      P_repeat = 'Vous avez collé avant le curseur 3 fois de suite',
      tilde_repeat = 'Vous avez basculé la casse 3 fois de suite',
      dot_repeat = 'Vous avez répété la dernière modification 3 fois de suite',
      J_repeat = 'Vous avez fusionné des lignes 3 fois de suite',
    },
  },
  -- Suggestion display strings shown via float popup and :TobiraProgress.
  -- Keys match commands.registry keys exactly.
  suggestions = {
    [';'] = {
      title = '; — répéter la dernière recherche f / t / F / T',
      body = "Après une recherche f, t, F ou T, ; saute à l'occurrence suivante dans la même direction\n, va dans la direction inverse",
      example = 'fa ;; → prochain a, puis le suivant',
    },
    [','] = {
      title = ', — répéter f / t / F / T en sens inverse',
      body = "L'inverse de ; — répète la dernière recherche f/t/F/T dans la direction opposée\nUtile quand vous êtes allé trop loin avec ;",
      example = "fa ;;; , → revenir en arrière d'un cran",
    },
    ['cw'] = {
      title = 'cw — supprimer le mot et insérer',
      body = 'Remplace la séquence dw + i en un seul mouvement\nBascule immédiatement en mode insertion après la suppression',
      example = 'cw → supprime du curseur à la fin du mot → mode insertion',
    },
    ['ciw'] = {
      title = 'ciw — modifier le mot intérieur',
      body = "Fonctionne même si le curseur est au milieu d'un mot\ncw ne supprime qu'à partir du curseur ; ciw remplace le mot entier",
      example = 'hel|lo → ciw → world',
    },
    ['<C-r>'] = {
      title = '<C-r> — rétablir',
      body = "Trop annulé ? <C-r> rétablit la dernière modification annulée\nCombinez u / <C-r> pour naviguer dans l'historique des modifications",
      example = 'u u u <C-r> → annuler 3 fois, rétablir une fois',
    },
    ['ddp'] = {
      title = 'ddp — échanger la ligne actuelle avec la suivante',
      body = 'dd supprime la ligne, p la colle en dessous — ddp échange les lignes en une seule fois\nPas besoin de naviguer entre les deux lignes',
      example = "ddp → la ligne actuelle descend d'un cran",
    },
    ['{n}j'] = {
      title = "{n}j — sauter plusieurs lignes d'un coup",
      body = "Ajoutez un nombre devant n'importe quel mouvement pour le répéter\n5j descend de 5 lignes ; fonctionne aussi avec k, w, b, etc.",
      example = '5j → descend de 5 lignes',
    },
    ['^'] = {
      title = '^ — sauter au premier caractère non blanc',
      body = '0 va à la colonne 0 ; ^ va au premier caractère non blanc\nEn général, ^ est ce que vous voulez vraiment',
      example = '    hello → ^ → le curseur se pose sur h',
    },
    ['cgn'] = {
      title = 'cgn — modifier la prochaine correspondance de recherche',
      body = 'Après /, utilisez cgn pour modifier la prochaine correspondance\nAppuyez ensuite sur . pour répéter sur chaque correspondance suivante',
      example = '/word → cgn → new → Esc → . . .',
    },
    ['.'] = {
      title = '. — répéter la dernière modification',
      body = 'Répète votre dernière édition sans revenir en mode insertion\nCombinez avec n ou ; pour modifier plusieurs occurrences en une seule passe',
      example = 'cw foo <Esc> n . → modifie aussi la correspondance suivante',
    },
    ['A'] = {
      title = 'A — ajouter en fin de ligne',
      body = '$a en une seule touche — va en fin de ligne et entre en mode insertion\nCombinez avec I (insérer en début de ligne) pour éditer rapidement les extrémités de ligne',
      example = 'A; → ajoute un point-virgule en fin de ligne',
    },
    ['O'] = {
      title = 'O — ouvrir une nouvelle ligne au-dessus',
      body = "Comme o mais ouvre la nouvelle ligne au-dessus du curseur\nPas besoin de monter d'abord puis d'appuyer sur o",
      example = 'O → nouvelle ligne vide au-dessus du curseur → mode insertion',
    },
    ['D'] = {
      title = "D — supprimer jusqu'à la fin de ligne",
      body = "Supprime du curseur jusqu'à la fin de ligne (identique à d$)\nPermet de retaper le reste sans y naviguer d'abord",
      example = 'D → tapez la nouvelle fin',
    },
    ['C'] = {
      title = "C — modifier jusqu'à la fin de ligne",
      body = "D + i en un seul mouvement — supprime jusqu'à la fin de ligne et entre en mode insertion\nComme cw mais pour le reste de la ligne au lieu d'un mot",
      example = 'C → remplace tout du curseur à la fin',
    },
    ['gn'] = {
      title = 'gn — sélectionner la prochaine correspondance de recherche',
      body = 'Après * ou /, gn sélectionne la prochaine correspondance en mode visuel\nUtilisé avec c (cgn) puis . pour remplacer chaque occurrence',
      example = '* → cgn → nouveau texte → Esc → . . .',
    },
    ['e'] = {
      title = 'e — aller à la fin du mot',
      body = "w saute au début du mot suivant ; e saute à sa fin\nUtile quand vous devez ajouter du texte à la fin d'un mot",
      example = 'ea → ajouter du texte après le mot actuel',
    },
    ['I'] = {
      title = 'I — insérer en début de ligne',
      body = 'Va au premier caractère non blanc et entre en mode insertion\nCombinez avec A (fin de ligne) pour éditer rapidement les extrémités de ligne',
      example = 'I// → commenter la ligne actuelle',
    },
    ['H'] = {
      title = "H — sauter en haut de l'écran",
      body = 'Déplace le curseur en haut de la fenêtre visible sans défiler\nM va au milieu, L va en bas',
      example = 'H → le curseur se pose sur la première ligne visible',
    },
    ['M'] = {
      title = "M — sauter au milieu de l'écran",
      body = 'Place le curseur exactement au milieu de la fenêtre visible\nUtile pour se réorienter rapidement après un grand saut',
      example = 'M → le curseur se déplace vers la ligne du milieu',
    },
    ['L'] = {
      title = "L — sauter en bas de l'écran",
      body = "Déplace le curseur vers la dernière ligne visible sans défiler\nCombinez avec H et M pour une navigation relative à l'écran",
      example = 'L → le curseur se pose sur la dernière ligne visible',
    },
    ['{n}x'] = {
      title = "{n}x — supprimer plusieurs caractères d'un coup",
      body = "Ajoutez un nombre devant x pour supprimer autant de caractères en une fois\nFonctionne aussi avec d'autres mouvements : 3dw, 2dd, etc.",
      example = '5x → supprime 5 caractères au curseur',
    },
    ['<C-d>'] = {
      title = "<C-d> — défiler d'une demi-page vers le bas",
      body = "Déplace la vue et le curseur vers le bas de la moitié de la hauteur de la fenêtre\nBeaucoup plus rapide que d'appuyer sur j plusieurs fois",
      example = "<C-d><C-d> → défile d'une page complète vers le bas",
    },
    ['<C-u>'] = {
      title = "<C-u> — défiler d'une demi-page vers le haut",
      body = 'Le complément vers le haut de <C-d>\nCombinez-les pour naviguer efficacement dans de gros fichiers',
      example = '<C-d> puis <C-u> → défile vers le bas puis remonte',
    },
    ['{n}k'] = {
      title = "{n}k — sauter plusieurs lignes vers le haut d'un coup",
      body = "Ajoutez un nombre devant k pour monter de plusieurs lignes en une fois\nFonctionne avec n'importe quel mouvement : 5k, 3w, 2b, etc.",
      example = '5k → monte de 5 lignes',
    },
    ['*'] = {
      title = '* — rechercher le mot sous le curseur',
      body = 'Place le mot sous le curseur dans le registre de recherche et saute à la prochaine correspondance\nPlus rapide que taper /word<Enter> — rien à taper',
      example = 'curseur sur "foo" → * → saute au prochain "foo"',
    },
    ['<C-o>'] = {
      title = "<C-o> — revenir à l'endroit précédent",
      body = 'Après un grand saut (* / G gg /) <C-o> vous ramène à la position précédente\n<C-i> vous ramène en avant dans la liste des sauts',
      example = '* <C-o> → saute à la correspondance, puis revient au point de départ',
    },
    ['P'] = {
      title = 'P — coller avant le curseur',
      body = 'p colle après le curseur ; P colle avant\nPour les copies de ligne entière : p colle en dessous de la ligne, P colle au-dessus',
      example = 'yy P → copie la ligne actuelle et la colle au-dessus',
    },

    -- ── f → t stop-before-char chain ─────────────────────────────────────
    ['t'] = {
      title = 't — se déplacer juste avant un caractère',
      body = "Comme f mais s'arrête un caractère avant la cible\nIdéal avec les opérateurs : ct; modifie jusqu'au prochain point-virgule (non inclus)",
      example = "ct; → modifie jusqu'au prochain point-virgule",
    },
    ['T'] = {
      title = 'T — se déplacer juste après un caractère (en arrière)',
      body = "Cherche en arrière comme F mais s'arrête juste après le caractère\nSe répète avec ; et , comme toute recherche f/t",
      example = 'T, → revient juste après la virgule précédente',
    },

    -- ── jumplist bidirectional ─────────────────────────────────────────────
    ['<C-i>'] = {
      title = '<C-i> — avancer dans la liste des sauts',
      body = "Après que <C-o> vous ramène en arrière, <C-i> vous ramène en avant\nNaviguez votre historique d'édition dans les deux sens",
      example = '<C-o> <C-o> <C-i> → recule deux fois, puis avance une fois',
    },

    -- ── full-page scroll chain ─────────────────────────────────────────────
    ['<C-f>'] = {
      title = "<C-f> — défiler d'une page complète vers le bas",
      body = "<C-d> défile d'une demi-page ; <C-f> défile d'une page complète\nPlus rapide pour sauter par-dessus de grandes sections d'un fichier",
      example = "<C-f> → défile vers le bas d'une hauteur de fenêtre complète",
    },
    ['<C-b>'] = {
      title = "<C-b> — défiler d'une page complète vers le haut",
      body = 'Le complément vers le haut de <C-f>\nCombinez avec <C-f> pour parcourir un gros fichier rapidement dans les deux sens',
      example = '<C-f> <C-b> → défile une page complète puis revient',
    },

    -- ── paragraph motions ─────────────────────────────────────────────────
    ['}'] = {
      title = '} — sauter à la fin du paragraphe',
      body = "Descend jusqu'à la prochaine ligne vide — saute des blocs entiers d'un coup\nPlus rapide que j pour se déplacer entre fonctions ou sections de texte",
      example = '} → le curseur saute à la ligne vide après le bloc actuel',
    },
    ['{'] = {
      title = '{ — sauter au début du paragraphe',
      body = "Le complément vers le haut de } — monte jusqu'à la ligne vide au-dessus\nNaviguez rapidement entre blocs de code ou paragraphes",
      example = '{ → le curseur saute à la ligne vide avant le bloc actuel',
    },

    -- ── screen centering chain ─────────────────────────────────────────────
    ['zz'] = {
      title = "zz — centrer l'écran sur le curseur",
      body = 'Fait défiler la vue pour que la ligne du curseur soit au milieu de la fenêtre\nLe curseur ne bouge pas — seule la zone visible change',
      example = 'zz → la ligne actuelle défile vers le centre de la fenêtre',
    },
    ['zt'] = {
      title = "zt — défiler la ligne du curseur en haut de l'écran",
      body = 'Comme zz mais place la ligne du curseur en haut de la fenêtre\nzt / zz / zb donnent un contrôle haut / centre / bas',
      example = 'zt → la ligne actuelle défile vers le haut de la fenêtre',
    },
    ['zb'] = {
      title = "zb — défiler la ligne du curseur en bas de l'écran",
      body = 'Fait défiler pour que la ligne du curseur apparaisse en bas de la fenêtre\nCombinez avec zt et zz pour positionner exactement ce que vous voyez',
      example = 'zb → la ligne actuelle défile vers le bas de la fenêtre',
    },

    -- ── WORD motions ──────────────────────────────────────────────────────
    ['W'] = {
      title = "W — avancer d'un WORD",
      body = 'Comme w mais s\'arrête seulement aux espaces, en ignorant la ponctuation\nUtile quand w s\'arrête trop souvent dans des choses comme "foo.bar(baz)"',
      example = 'W sur "foo.bar.baz" → saute par-dessus tout le jeton d\'un coup',
    },
    ['B'] = {
      title = "B — reculer d'un WORD",
      body = 'Comme b mais traite le texte connecté par la ponctuation comme un seul WORD\nLe complément en arrière de W',
      example = 'B sur "foo.bar.baz" → recule par-dessus tout le jeton',
    },

    -- ── word-end backward ─────────────────────────────────────────────────
    ['ge'] = {
      title = 'ge — aller à la fin du mot précédent',
      body = 'e avance à la fin du mot ; ge recule à la fin du mot précédent\nUtile quand vous devez ajouter du texte au mot derrière le curseur',
      example = 'gea → va à la fin du mot précédent puis ajoute du texte',
    },

    -- ── bracket matching ──────────────────────────────────────────────────
    ['%'] = {
      title = '% — sauter à la parenthèse correspondante',
      body = 'Saute entre (, [, { et leurs fermetures correspondantes\nFonctionne aussi avec /* */ et #if/#endif dans de nombreux types de fichiers',
      example = '% sur ( → le curseur saute au ) correspondant',
    },

    -- ── single-char edit shortcuts ────────────────────────────────────────
    ['r'] = {
      title = 'r — remplacer un seul caractère',
      body = 'Remplace le caractère sous le curseur sans entrer en mode insertion\nPlus rapide que x + i + caractère pour corriger une faute de frappe',
      example = 'ra → remplace le caractère sous le curseur par a',
    },
    ['s'] = {
      title = 's — substituer un caractère et insérer',
      body = 'Supprime le caractère sous le curseur et entre immédiatement en mode insertion\nUne seule touche au lieu de x + i',
      example = 's → supprime le caractère actuel → mode insertion',
    },
    ['cc'] = {
      title = 'cc — modifier toute la ligne actuelle',
      body = "Vide le contenu de la ligne et entre en mode insertion en un seul mouvement\nPlus rapide qu'aller au début de ligne, appuyer sur D, puis entrer en mode insertion",
      example = 'cc → la ligne est vidée → mode insertion',
    },

    -- ── join lines ───────────────────────────────────────────────────────
    ['J'] = {
      title = "J — fusionner la ligne suivante avec l'actuelle",
      body = "Ajoute la ligne du dessous à la ligne actuelle avec un seul espace\nPas besoin d'aller en fin de ligne, supprimer le saut de ligne et ajouter un espace",
      example = 'J → "foo\\n  bar" devient "foo bar" (l\'indentation est supprimée)',
    },

    -- ── case toggle ───────────────────────────────────────────────────────
    ['~'] = {
      title = '~ — basculer la casse du caractère sous le curseur',
      body = "Passe de minuscule à majuscule et vice versa, puis avance d'un caractère\nPréfixez avec un nombre : 3~ bascule les 3 prochains caractères d'un coup",
      example = '~ sur "hello" → "Hello" → le curseur avance',
    },

    -- ── number increment / decrement ──────────────────────────────────────
    ['<C-a>'] = {
      title = '<C-a> — incrémenter le nombre sous le curseur',
      body = 'Trouve le prochain nombre sur la ligne et lui ajoute un\nPréfixez avec un nombre pour ajouter plus : 5<C-a> ajoute 5',
      example = '<C-a> sur "padding: 8px" → "padding: 9px"',
    },
    ['<C-x>'] = {
      title = '<C-x> — décrémenter le nombre sous le curseur',
      body = 'Le complément vers le bas de <C-a> — soustrait un au prochain nombre\nUtile pour ajuster des valeurs numériques sans les retaper manuellement',
      example = '<C-x> sur "z-index: 10" → "z-index: 9"',
    },

    -- ── visual mode chain ─────────────────────────────────────────────────
    ['V'] = {
      title = 'V — démarrer la sélection visuelle par ligne',
      body = 'Sélectionne des lignes entières plutôt que des caractères individuels\nIdéal pour déplacer, copier ou supprimer des lignes entières avec retour visuel',
      example = 'Vjjd → sélectionne visuellement 3 lignes puis les supprime',
    },
    ['<C-v>'] = {
      title = '<C-v> — démarrer la sélection visuelle en bloc (colonne)',
      body = 'Sélectionne un bloc rectangulaire sur plusieurs lignes\nPuissant pour éditer des colonnes alignées — préfixer du texte, modifier des valeurs en masse',
      example = "<C-v>3jI// <Esc> → préfixe // à 4 lignes d'un coup",
    },

    -- ── yank text object ──────────────────────────────────────────────────
    ['yiw'] = {
      title = 'yiw — copier le mot intérieur',
      body = 'Copie le mot entier sous le curseur quelle que soit sa position dans le mot\nCombinez avec ciw (modifier) et diw (supprimer) pour une édition cohérente au niveau du mot',
      example = 'yiw puis déplacez-vous vers le mot cible puis ciw p → remplace le mot',
    },

    -- ── macros ────────────────────────────────────────────────────────────
    ['q'] = {
      title = 'q — enregistrer une macro',
      body = "q{a} démarre l'enregistrement dans le registre a ; appuyez à nouveau sur q pour arrêter\n@{a} la rejoue ; @@ répète la dernière macro — automatise les modifications répétitives",
      example = 'qaIhello<Esc>q puis @a → insère "hello" en début de ligne lors de la relecture',
    },

    -- ── backward search pair ──────────────────────────────────────────────
    ['N'] = {
      title = 'N — sauter à la correspondance de recherche précédente',
      body = 'n saute en avant à la correspondance suivante ; N saute en arrière à la précédente\nChangez de direction à tout moment sans retaper le motif de recherche',
      example = "/foo → nnn N → avance de 3 correspondances puis recule d'une",
    },
    ['#'] = {
      title = '# — rechercher en arrière le mot sous le curseur',
      body = '* recherche en avant le mot sous le curseur ; # recherche en arrière\nLocalisez instantanément toutes les occurrences sans taper le terme de recherche',
      example = 'curseur sur "foo" → # → saute à l\'occurrence précédente de "foo"',
    },

    -- ── G → gg ───────────────────────────────────────────────────────────
    ['gg'] = {
      title = 'gg — sauter à la première ligne du fichier',
      body = 'G saute à la fin du fichier ; gg saute au début\nPréfixez avec un nombre : 5gg saute directement à la ligne 5',
      example = 'gg → le curseur se pose sur la ligne 1',
    },

    -- ── wrapped-line movement ─────────────────────────────────────────────
    ['gj'] = {
      title = "gj — descendre d'une ligne visuelle (affichée)",
      body = "Quand les lignes sont enroulées, j saute toute la ligne enroulée ; gj se déplace d'une ligne affichée\nEssentiel pour éditer de la prose longue ou du markdown avec le retour à la ligne activé",
      example = "gj sur un paragraphe enroulé → le curseur se déplace vers la ligne d'écran suivante",
    },
    ['gk'] = {
      title = "gk — monter d'une ligne visuelle (affichée)",
      body = "Le complément vers le haut de gj — monte d'une ligne affichée quand les lignes sont enroulées\nCombinez gj / gk pour un déplacement naturel dans du texte enroulé",
      example = "gk sur un paragraphe enroulé → le curseur se déplace vers la ligne d'écran précédente",
    },

    -- ── line-by-line scrolling ────────────────────────────────────────────
    ['<C-e>'] = {
      title = "<C-e> — défiler la fenêtre d'une ligne vers le haut sans déplacer le curseur",
      body = "Déplace la zone visible d'une ligne vers le haut ; le curseur reste sur la même ligne\nCombinez avec <C-y> pour ajuster la vue sans perdre votre position d'édition",
      example = '<C-e><C-e> → le texte défile de 2 lignes vers le haut ; le curseur ne bouge pas',
    },
    ['<C-y>'] = {
      title = "<C-y> — défiler la fenêtre d'une ligne vers le bas sans déplacer le curseur",
      body = "Le complément vers le bas de <C-e> — révèle une ligne de plus en haut\nAjustez la zone visible sans déplacer votre position d'édition",
      example = '<C-y> → une ligne de plus défile en vue en haut de la fenêtre',
    },

    -- ── change list navigation ────────────────────────────────────────────
    ['g;'] = {
      title = 'g; — sauter à une position plus ancienne de la liste des modifications',
      body = 'Chaque modification que vous faites est ajoutée à la liste des modifications ; g; la parcourt en arrière\nDifférent de la liste des sauts — seulement les positions où le texte a réellement changé',
      example = 'g; g; → revenir aux deux derniers endroits édités',
    },
    ['g,'] = {
      title = 'g, — sauter à une position plus récente de la liste des modifications',
      body = "Après que g; vous ramène en arrière dans la liste des modifications, g, vous ramène en avant\nNaviguez votre historique d'édition dans les deux sens sans quitter le fichier",
      example = 'g; g, → recule vers la dernière édition, puis avance à nouveau',
    },

    -- ── return to last insert / alternate file / last jump ────────────────
    ['gi'] = {
      title = "gi — aller à la dernière position d'insertion et entrer en mode insertion",
      body = 'Ramène le curseur là où vous avez quitté le mode insertion la dernière fois et y entre immédiatement\nÉvite de naviguer manuellement après avoir lu une autre partie du fichier',
      example = 'gi → le curseur saute où vous avez arrêté de taper → mode insertion',
    },
    ['<C-^>'] = {
      title = '<C-^> — basculer vers le fichier alternatif (précédemment édité)',
      body = "Bascule entre le fichier actuel et le dernier que vous aviez ouvert\nLe moyen le plus rapide de basculer entre deux fichiers activement en cours d'édition",
      example = '<C-^> → ouvre le dernier fichier → <C-^> → retour au premier',
    },
    ["''"] = {
      title = "'' — revenir à la ligne du saut précédent",
      body = "Un retour rapide à la ligne où vous étiez avant la dernière grande navigation\n'' utilise une précision de ligne ; `` (accents graves) restaure aussi la colonne exacte",
      example = "G '' → saute à la fin du fichier, puis revient à la ligne d'origine",
    },

    -- ── definition / file under cursor ────────────────────────────────────
    ['gd'] = {
      title = 'gd — aller à la définition locale',
      body = 'Recherche dans la portée de la fonction actuelle la première déclaration du mot sous le curseur\nPlus rapide que grep — pas besoin de quitter le fichier ni de taper un motif de recherche',
      example = 'curseur sur "myVar" → gd → saute là où myVar est déclarée pour la première fois',
    },
    ['gf'] = {
      title = 'gf — éditer le fichier dont le nom est sous le curseur',
      body = 'Ouvre le nom de fichier sous le curseur comme un nouveau buffer dans la fenêtre actuelle\nFonctionne avec les chemins relatifs, absolus et les noms de fichiers dans des chaînes',
      example = 'curseur sur "utils/helpers.lua" → gf → ouvre ce fichier',
    },

    -- ── reselect last visual ──────────────────────────────────────────────
    ['gv'] = {
      title = 'gv — resélectionner la dernière sélection visuelle',
      body = 'Réactive exactement la même sélection visuelle que la dernière fois que le mode visuel a été utilisé\nFait gagner du temps quand vous devez appliquer une deuxième opération à la même région',
      example = 'vip y gv d → copie un paragraphe, puis le resélectionne et le supprime',
    },

    -- ── WORD-end backward ─────────────────────────────────────────────────
    ['gE'] = {
      title = 'gE — aller à la fin du WORD précédent',
      body = 'ge va à la fin du mot précédent ; gE fait de même mais saute toute la ponctuation\nLe complément au niveau WORD de ge — saute "foo.bar.baz" comme un seul jeton',
      example = 'gE sur foo.bar → saute à la fin du WORD précédent',
    },

    -- ── fold commands ─────────────────────────────────────────────────────
    ['za'] = {
      title = 'za — basculer le pliage au curseur',
      body = 'Ouvre un pliage fermé ou ferme un pliage ouvert sous le curseur\nLa commande de pliage la plus pratique — une touche pour révéler ou masquer une section',
      example = 'za → déplie le bloc replié ; za à nouveau → le replie',
    },
    ['zo'] = {
      title = 'zo — ouvrir le pliage au curseur',
      body = "Révèle les lignes cachées dans un pliage sans affecter les pliages ouverts à proximité\nContrairement à za, zo ne fait qu'ouvrir — il ne referme jamais accidentellement un pliage déjà ouvert",
      example = 'zo → les lignes cachées dans le pliage deviennent visibles',
    },
    ['zc'] = {
      title = 'zc — fermer le pliage au curseur',
      body = "Replie un pliage ouvert en une seule ligne de résumé\nL'inverse de zo — ne fait que fermer, n'ouvre jamais accidentellement",
      example = 'zc → le bloc développé se replie en une ligne de résumé',
    },
    ['zM'] = {
      title = 'zM — fermer tous les pliages du buffer',
      body = "Replie tous les pliages du fichier d'un coup — donne une vue d'ensemble complète\nUtile pour naviguer dans un gros fichier par structure avant de creuser une section",
      example = 'zM → toutes les fonctions se replient → seule la structure de haut niveau reste visible',
    },
    ['zR'] = {
      title = 'zR — ouvrir tous les pliages du buffer',
      body = "Déplie tous les pliages du fichier — l'inverse de zM\nRestaure la vue entièrement dépliée après avoir exploré avec la navigation par pliages",
      example = 'zM zR → replie tous les pliages, puis développe tout à nouveau',
    },

    -- ── delete before / replace mode / yank to EOL ────────────────────────
    ['X'] = {
      title = 'X — supprimer le caractère avant le curseur',
      body = 'Supprime un caractère à gauche du curseur sans entrer en mode insertion\nComme appuyer sur Retour arrière en restant en mode normal',
      example = 'X → le caractère immédiatement à gauche du curseur est supprimé',
    },
    ['R'] = {
      title = 'R — entrer en mode remplacement',
      body = 'Écrase le texte existant caractère par caractère au fur et à mesure que vous tapez — sans insérer ni décaler\nIdéal pour remplacer une section de largeur fixe tout en gardant le texte environnant intact',
      example = 'Rhello → écrase les 5 prochains caractères par "hello"',
    },
    ['Y'] = {
      title = 'Y — copier du curseur à la fin de ligne',
      body = "Copie le texte de la position du curseur à la fin de la ligne (identique à y$)\nComplète D (supprimer jusqu'à la fin) et C (modifier jusqu'à la fin) pour des opérations cohérentes en fin de ligne",
      example = 'Y p → copie le reste de la ligne puis le colle en dessous',
    },

    -- ── indent operators ──────────────────────────────────────────────────
    ['>>'] = {
      title = '>> — indenter la ligne actuelle',
      body = "Décale la ligne actuelle d'un niveau d'indentation vers la droite\nPréfixez avec un nombre : 3>> indente les 3 prochaines lignes d'un coup",
      example = ">> → la ligne actuelle est indentée d'un niveau",
    },
    ['<<'] = {
      title = '<< — désindenter la ligne actuelle',
      body = "Décale la ligne actuelle d'un niveau d'indentation vers la gauche\nL'inverse de >> — utilisez-le pour corriger du code trop indenté",
      example = "<< → la ligne actuelle perd un niveau d'indentation",
    },
    ['=='] = {
      title = '== — auto-indenter la ligne actuelle',
      body = "Exécute l'indenteur intégré sur la ligne actuelle selon les règles du type de fichier\nPlus rapide que de corriger manuellement avec >> ou << quand l'indentation est complexe",
      example = "== → la ligne se cale automatiquement au bon niveau d'indentation",
    },

    -- ── case operators ────────────────────────────────────────────────────
    ['gu'] = {
      title = 'gu{motion} — mettre une région en minuscules',
      body = "Applique les minuscules au texte couvert par le mouvement\nguiw → met le mot actuel en minuscules ; gu$ → minuscules jusqu'à la fin de ligne",
      example = 'guiw → "Hello" devient "hello"',
    },
    ['gU'] = {
      title = 'gU{motion} — mettre une région en majuscules',
      body = 'Le complément en majuscules de gu — convertit le texte du mouvement en MAJUSCULES\ngUiw → met le mot intérieur en majuscules',
      example = 'gUiw → "hello" devient "HELLO"',
    },
    ['g~'] = {
      title = "g~{motion} — inverser la casse d'une région",
      body = "Inverse la casse de chaque caractère du mouvement — majuscule devient minuscule et vice versa\nComme appliquer ~ à tout un mouvement au lieu d'un seul caractère",
      example = 'g~iw → "Hello World" devient "hELLO wORLD"',
    },

    -- ── format text ───────────────────────────────────────────────────────
    ['gq'] = {
      title = 'gq{motion} — reformater le texte pour tenir dans la largeur de ligne',
      body = 'Reformate le texte couvert par le mouvement pour passer à la ligne à textwidth\ngqip formate le paragraphe actuel ; gqq formate la ligne actuelle',
      example = 'gqip → le paragraphe actuel est reformaté pour tenir dans la largeur configurée',
    },

    -- ── join without space ────────────────────────────────────────────────
    ['gJ'] = {
      title = "gJ — fusionner les lignes sans insérer d'espace",
      body = "Comme J mais n'ajoute pas d'espace entre les lignes fusionnées\nUtile pour fusionner des lignes où un espace supplémentaire casserait la syntaxe",
      example = 'gJ → "foo\\n  bar" devient "foobar" (aucun espace inséré)',
    },

    -- ── repeat last macro ─────────────────────────────────────────────────
    ['@@'] = {
      title = '@@ — répéter la dernière macro jouée',
      body = "Rejoue la macro exécutée le plus récemment avec @{reg}\nÉvite de retaper le nom du registre lors d'itérations avec la même macro",
      example = '@a → exécute la macro a ; @@ → exécute la macro a à nouveau sans repréciser "a"',
    },

    -- ── text object chain ─────────────────────────────────────────────────
    ['ci"'] = {
      title = 'ci" — modifier la chaîne entre guillemets doubles intérieure',
      body = "Supprime le contenu entre les guillemets doubles les plus proches et entre en mode insertion\nL'objet texte i\" fonctionne avec n'importe quel opérateur : c, d, y, v",
      example = 'sur "hello world" → ci" → le contenu est effacé → tapez le remplacement',
    },
    ["ci'"] = {
      title = "ci' — modifier la chaîne entre apostrophes intérieure",
      body = 'Comme ci" mais cible les apostrophes au lieu des guillemets doubles\nFonctionne partout où le curseur est entre une paire d\'apostrophes',
      example = "sur 'hello' → ci' → le contenu est effacé → tapez le remplacement",
    },
    ['cib'] = {
      title = 'cib — modifier le bloc de parenthèses intérieur',
      body = "Supprime le contenu à l'intérieur des () les plus proches et entre en mode insertion\nib est l'objet texte « bloc intérieur » — identique à i( — fonctionne dans les appels de fonction",
      example = 'sur foo(bar, baz) → cib → efface "bar, baz" → tapez les nouveaux arguments',
    },
    ['ciB'] = {
      title = "ciB — modifier le bloc d'accolades intérieur",
      body = "Cible le contenu à l'intérieur du bloc {} le plus proche\nB est l'objet texte « grand bloc » ; utile pour vider ou réécrire le corps d'une fonction",
      example = 'dans un corps de fonction → ciB → efface tout le corps → mode insertion',
    },
    ['cit'] = {
      title = "cit — modifier le contenu d'une balise HTML / XML intérieure",
      body = "Supprime le texte entre les balises d'ouverture et de fermeture les plus proches et entre en mode insertion\nit est l'objet texte « balise intérieure » — fonctionne avec n'importe quelle paire de balises",
      example = 'sur <p>hello</p> → cit → efface "hello" → tapez le nouveau contenu',
    },
    ['cip'] = {
      title = 'cip — modifier le paragraphe intérieur',
      body = "Remplace tout le paragraphe actuel (bloc contigu de lignes non vides)\nip sélectionne jusqu'aux lignes vides environnantes sans les inclure",
      example = 'cip → tout le paragraphe actuel est effacé → mode insertion',
    },

    -- ── partial word search ───────────────────────────────────────────────
    ['g*'] = {
      title = 'g* — rechercher en avant une correspondance partielle du mot sous le curseur',
      body = '* exige une correspondance de mot entier ; g* correspond aussi au mot comme sous-chaîne\nUtile quand vous voulez que "foo" trouve "foobar", "football" et "foo" pareillement',
      example = 'g* sur "foo" → correspond à "foo", "foobar", "fooResult"',
    },
    ['g#'] = {
      title = 'g# — rechercher en arrière une correspondance partielle du mot sous le curseur',
      body = 'Le compagnon en arrière de g* — recherche la sous-chaîne en remontant dans le fichier\nTrouve toutes les occurrences y compris les correspondances partielles comme g* mais en sens inverse',
      example = 'g# sur "foo" → revient au "foo" ou "foobar" précédent',
    },

    -- ── window management ─────────────────────────────────────────────────
    ['<C-w>s'] = {
      title = '<C-w>s — diviser la fenêtre horizontalement',
      body = "Ouvre une division horizontale pour voir deux parties d'un fichier simultanément\n<C-w>v crée une division verticale côte à côte",
      example = '<C-w>s → deux volets horizontaux ; naviguez indépendamment dans chacun',
    },
    ['<C-w>v'] = {
      title = '<C-w>v — diviser la fenêtre verticalement',
      body = 'Ouvre une division verticale — deux volets côte à côte dans le même onglet\nCombinez avec <C-w>h et <C-w>l pour vous déplacer entre eux',
      example = '<C-w>v → deux volets verticaux ; <C-w>l → passe au volet de droite',
    },
    ['<C-w>w'] = {
      title = '<C-w>w — passer à la fenêtre suivante',
      body = 'Déplace le focus vers la division suivante de la mise en page sans préciser de direction\nLe moyen le plus rapide de basculer entre deux volets',
      example = '<C-w>w → le focus passe à la prochaine division ouverte',
    },
    ['<C-w>h'] = {
      title = '<C-w>h — déplacer le focus vers la fenêtre de gauche',
      body = 'Navigation directionnelle entre fenêtres — déplace le focus à gauche, comme h déplace le curseur à gauche\nUtilisez les variantes h / j / k / l pour une navigation précise entre divisions',
      example = '<C-w>h → le curseur se déplace vers la division immédiatement à gauche',
    },
    ['<C-w>j'] = {
      title = '<C-w>j — déplacer le focus vers la fenêtre du dessous',
      body = "Déplace le focus vers le bas, vers la division sous l'actuelle\nFonctionne dans les mises en page horizontales et mixtes",
      example = '<C-w>j → le curseur se déplace vers la division du dessous',
    },
    ['<C-w>k'] = {
      title = '<C-w>k — déplacer le focus vers la fenêtre du dessus',
      body = "Déplace le focus vers le haut, vers la division au-dessus de l'actuelle\nLe complément vers le haut de <C-w>j",
      example = '<C-w>k → le curseur se déplace vers la division du dessus',
    },
    ['<C-w>l'] = {
      title = '<C-w>l — déplacer le focus vers la fenêtre de droite',
      body = 'Déplace le focus à droite, vers la division de droite\nCombinez avec <C-w>h pour basculer entre volets gauche et droit',
      example = '<C-w>l → le curseur se déplace vers la division de droite',
    },
    ['<C-w>q'] = {
      title = '<C-w>q — fermer la fenêtre actuelle',
      body = "Ferme la division focalisée ; le buffer lui-même reste ouvert\nUtilisez :bd pour aussi supprimer le buffer ; :qa pour fermer toutes les divisions d'un coup",
      example = "<C-w>q → le volet focalisé se ferme ; le volet restant s'agrandit pour remplir l'espace",
    },
    ['<C-w>='] = {
      title = '<C-w>= — égaliser la taille de toutes les fenêtres',
      body = 'Redimensionne toutes les divisions ouvertes à largeur et hauteur égales\nUne remise à zéro rapide quand les divisions deviennent déséquilibrées après un redimensionnement manuel',
      example = '<C-w>= → tous les volets reviennent à des dimensions égales',
    },
    ['$'] = {
      title = '$ — sauter à la fin de ligne',
      body = 'Déplace le curseur au dernier caractère de la ligne actuelle\nCombinez avec ^ (premier non blanc) pour naviguer rapidement les extrémités de ligne',
      example = '^ → aller au début ; $ → sauter à la fin',
    },
    ['g_'] = {
      title = 'g_ — dernier caractère non blanc de la ligne',
      body = "$ inclut les espaces de fin ; g_ s'arrête au dernier caractère non blanc\nPlus précis que $ quand les lignes ont des espaces de fin",
      example = "$ → peut se poser sur un espace ; g_ → s'arrête au dernier caractère réel",
    },
    ['F'] = {
      title = 'F — rechercher un caractère en arrière',
      body = 'Comme f{car} mais recherche à gauche au lieu de la droite sur la ligne actuelle\n; et , répètent toujours la recherche',
      example = "f, → avant jusqu'à la virgule ; F, → arrière jusqu'à la virgule",
    },
    ['('] = {
      title = '( — sauter au début de la phrase',
      body = 'Comme { pour les paragraphes, ( saute au début de la phrase actuelle\nUtile pour naviguer dans la prose, les commentaires et la documentation',
      example = '{ → début de paragraphe ; ( → début de phrase',
    },
    [')'] = {
      title = ') — sauter au début de la phrase suivante',
      body = 'Déplace le curseur en avant vers le début de la phrase suivante\nCombinez avec ( pour sauter entre phrases dans les deux sens',
      example = '( puis ) → avance et recule entre les phrases',
    },
    ['[['] = {
      title = '[[ — fonction / section précédente',
      body = 'Saute à la première ligne de la fonction ou limite de section précédente\nPlus rapide que gg + recherche pour naviguer dans un fichier avec beaucoup de fonctions',
      example = 'gg → début du fichier ; [[ → début de la fonction précédente',
    },
    [']]'] = {
      title = ']] — fonction / section suivante',
      body = 'Saute à la première ligne de la fonction ou limite de section suivante\nCombinez avec [[ pour sauter entre fonctions sans quitter le mode normal',
      example = 'G → fin du fichier ; ]] → début de la fonction suivante',
    },
    ['[{'] = {
      title = '[{ — sauter à la { englobante',
      body = "Saute en arrière vers l'accolade ouvrante non appariée la plus proche\nEssentiel pour atteindre rapidement le début d'un bloc, d'une fonction ou d'une structure",
      example = '% → parenthèse correspondante ; [{ → début du bloc englobant',
    },
    [']}'] = {
      title = ']} — sauter à la } englobante',
      body = "Saute en avant vers l'accolade fermante non appariée la plus proche\nCombinez avec [{ pour naviguer dans et hors des blocs imbriqués",
      example = '[{ → début de bloc ; ]} → fin de bloc',
    },
    ['[('] = {
      title = '[( — sauter à la ( englobante',
      body = 'Saute en arrière vers la parenthèse ouvrante non appariée la plus proche\nUtile dans les appels de fonction longs, conditions ou expressions multilignes',
      example = '[{ → bloc ; [( → parenthèse englobante',
    },
    ['])'] = {
      title = ']) — sauter à la ) englobante',
      body = 'Saute en avant vers la parenthèse fermante non appariée la plus proche\nCombinez avec [( pour naviguer dans et hors des parenthèses imbriquées',
      example = '[( → parenthèse ouvrante ; ]) → parenthèse fermante',
    },
    ['g0'] = {
      title = "g0 — premier caractère de la ligne d'écran",
      body = 'Quand les lignes sont enroulées, 0 va au vrai début de ligne ; g0 va au début de la ligne enroulée\nUtile pour éditer de longues lignes avec le retour à la ligne activé',
      example = 'gj → ligne visuelle suivante ; g0 → début de cette ligne visuelle',
    },
    ['gx'] = {
      title = "gx — ouvrir le fichier ou l'URL sous le curseur",
      body = "Ouvre le chemin de fichier ou l'URL sous le curseur avec l'application par défaut du système\nFonctionne avec les URL http/https, les chemins de fichiers locaux, et plus",
      example = 'gf → édite le fichier dans Vim ; gx → ouvre dans le navigateur ou le Finder',
    },
    ['<C-]>'] = {
      title = '<C-]> — sauter à la définition du tag',
      body = "Suit le tag (définition ctags) sous le curseur jusqu'à sa déclaration\nNécessite un fichier tags ; <C-t> ou <C-o> revient en arrière",
      example = 'gd → définition locale ; <C-]> → définition ctags',
    },
    ['K'] = {
      title = 'K — consulter le mot-clé sous le curseur',
      body = 'Exécute le programme de keywordprg (par défaut : man) sur le mot sous le curseur\nDans de nombreuses configurations LSP, K affiche la documentation au survol',
      example = 'gd → aller à la définition ; K → afficher la documentation',
    },
    ['gp'] = {
      title = 'gp — coller et laisser le curseur après le texte collé',
      body = 'Comme p mais laisse le curseur positionné juste après le texte collé\nPratique pour continuer à taper immédiatement après avoir collé',
      example = 'p → le curseur reste avant le collage ; gp → le curseur se déplace après',
    },
    ['gP'] = {
      title = 'gP — coller avant et laisser le curseur après',
      body = 'Comme P (coller avant le curseur) mais déplace le curseur juste après le texte collé\nLe complément en majuscule de gp',
      example = 'P → colle avant, curseur avant ; gP → colle avant, curseur après',
    },
    ['@:'] = {
      title = '@: — répéter la dernière commande de ligne de commande',
      body = 'Répète la commande : exécutée le plus récemment sans la retaper\nAprès @: vous pouvez utiliser @@ pour la répéter à nouveau',
      example = ':s/foo/bar/ puis @: → répète la substitution',
    },
    ['zj'] = {
      title = 'zj — se déplacer au début du prochain pliage',
      body = "Déplace le curseur vers le bas jusqu'au début du prochain pliage fermé ou ouvert\nPlus rapide que de défiler au-delà des pliages en naviguant dans un fichier très plié",
      example = 'za → bascule le pliage ; zj → saute au prochain pliage',
    },
    ['zk'] = {
      title = 'zk — se déplacer à la fin du pliage précédent',
      body = "Déplace le curseur vers le haut jusqu'à la fin du pliage précédent\nCombinez avec zj pour sauter entre pliages dans les deux sens",
      example = 'zj → prochain pliage ; zk → pliage précédent',
    },
    ['zd'] = {
      title = 'zd — supprimer le pliage au curseur',
      body = 'Supprime la définition du pliage sous le curseur sans affecter le texte\nUtile pour nettoyer les pliages manuels créés avec zf',
      example = 'zc → ferme le pliage ; zd → supprime cette définition de pliage',
    },
    ['E'] = {
      title = "E — avancer jusqu'à la fin du WORD",
      body = "Comme e mais saute à la fin du prochain WORD (toute séquence non blanche)\nIgnore les limites de ponctuation où e s'arrêterait",
      example = 'e → fin de mot ; E → fin de WORD (saute la ponctuation)',
    },
    ['U'] = {
      title = 'U — annuler toutes les modifications de la ligne actuelle',
      body = "Restaure la ligne actuelle telle qu'elle était quand vous vous y êtes déplacé\nDifférent de u : U annule toutes les modifications d'une ligne en une seule fois",
      example = 'u → annule la dernière modification ; U → restaure toute la ligne',
    },
    ['ZZ'] = {
      title = 'ZZ — enregistrer et quitter',
      body = 'Enregistre le fichier et ferme la fenêtre en une seule touche\nÉquivalent à :wq mais plus rapide à taper',
      example = ':wq  ou  ZZ — même résultat, ZZ économise deux touches',
    },
    ['ZQ'] = {
      title = 'ZQ — quitter sans enregistrer',
      body = 'Ferme la fenêtre et abandonne les modifications sans invite de confirmation\nÉquivalent à :q! mais plus rapide à taper',
      example = 'ZZ → enregistre et quitte ; ZQ → quitte et abandonne les modifications',
    },
    ['q:'] = {
      title = 'q: — ouvrir la fenêtre de ligne de commande',
      body = "Ouvre un buffer contenant votre historique de commandes Ex\nVous pouvez éditer et réexécuter n'importe quelle commande précédente avec Entrée",
      example = "q → enregistrer une macro ; q: → parcourir et éditer l'historique des commandes",
    },
    ['|'] = {
      title = '| — se déplacer à la colonne N',
      body = 'Saute le curseur à la colonne N sur la ligne actuelle\nUtile pour aligner du texte ou naviguer vers une position de colonne connue',
      example = '0 → colonne 1 ; 40| → colonne 40',
    },
    ['_'] = {
      title = '_ — premier caractère non blanc de la ligne (relatif)',
      body = 'Se déplace au premier caractère non blanc de la ligne actuelle\nAvec un nombre N, descend de N-1 lignes puis va au premier non blanc',
      example = '^ → premier non blanc ; 3_ → premier non blanc 2 lignes plus bas',
    },

    -- ── fold: additional commands ─────────────────────────────────────────
    ['zf'] = {
      title = 'zf — créer un pliage manuellement',
      body = 'Crée un pliage sur un mouvement ou une sélection visuelle (nécessite foldmethod=manual)\nUtilisez zd pour le supprimer ; zf{motion} plie ce que le mouvement couvre',
      example = 'zfip → plie le paragraphe actuel ; zd → supprime ce pliage',
    },

    -- ── macro: play specific register ────────────────────────────────────
    ['@q'] = {
      title = '@q — jouer la macro du registre q',
      body = "Rejoue la séquence de touches enregistrée dans le registre q\nRemplacez q par n'importe quelle lettre a-z pour jouer depuis un autre registre",
      example = "qq → démarre l'enregistrement ; q → arrête ; @q → rejoue",
    },

    -- ── marks ─────────────────────────────────────────────────────────────
    ["'."] = {
      title = "'. — sauter à la dernière position de modification",
      body = "Déplace le curseur à la position exacte de la modification la plus récente\nPlus rapide que d'utiliser Ctrl-O plusieurs fois quand vous devez revenir à votre dernière modification",
      example = "G puis '. → saute à la fin, revient là où vous avez modifié en dernier",
    },
    ["'^"] = {
      title = "'^ — sauter à la dernière position d'insertion",
      body = "Ramène le curseur à la position où vous avez quitté le mode insertion la dernière fois\nDifférent de '. — suit où vous avez quitté l'insertion, pas la dernière modification de texte",
      example = "A puis <Esc> puis '^ → revient au point d'insertion en fin de ligne",
    },
    ['ma'] = {
      title = 'ma — définir la marque a au curseur',
      body = "Définit une marque nommée 'a' à la position actuelle\nUtilisez n'importe quelle lettre minuscule a-z ; récupérez-la avec 'a (ligne) ou `a (colonne exacte)",
      example = "ma → marque ici ; G → va ailleurs ; 'a → revient à la ligne marquée",
    },
    ["'a"] = {
      title = "'a — sauter à la marque a",
      body = "Déplace le curseur à la ligne où la marque 'a' a été définie\nUtilisez l'accent grave `a pour des sauts précis de colonne ; combinez avec ma comme ancre de navigation",
      example = "ma → marque ; dd → édite ailleurs ; 'a → revient à la ligne marquée",
    },

    -- ── l → w / h → b word motion (detected by l_repeat / h_repeat) ──────────
    ['w'] = {
      title = 'w — se déplacer au début du mot suivant',
      body = "Saute en avant un mot à la fois plutôt qu'un caractère à la fois\nPlus rapide que d'appuyer sur l plusieurs fois — utilisez w pour vous déplacer par mot, l pour ajuster la position",
      example = 'w w w → avance de trois mots',
    },
    ['b'] = {
      title = 'b — se déplacer au début du mot précédent',
      body = "Saute en arrière un mot à la fois — le complément de w\nPlus rapide que d'appuyer sur h plusieurs fois pour se déplacer de plusieurs mots à gauche",
      example = 'b b b → recule de trois mots',
    },

    -- ── count prefix variants ─────────────────────────────────────────────────
    ['{n}dd'] = {
      title = "{n}dd — supprimer plusieurs lignes d'un coup",
      body = 'Préfixez dd avec un nombre pour supprimer autant de lignes en une seule commande\n3dd supprime 3 lignes à partir du curseur — pas besoin de répéter dd',
      example = "3dd → supprime 3 lignes d'un coup",
    },
    ['{n}p'] = {
      title = "{n}p — coller plusieurs fois d'un coup",
      body = "Préfixez p avec un nombre pour coller le même contenu N fois de suite\n3p colle le texte copié 3 fois — plus rapide que d'appuyer sur p plusieurs fois",
      example = '3p → colle le même contenu 3 fois',
    },
    ['{n}P'] = {
      title = '{n}P — coller avant le curseur plusieurs fois',
      body = 'P colle avant le curseur ; préfixez avec un nombre pour le répéter\n3P colle le texte copié 3 fois au-dessus de la ligne actuelle',
      example = '3P → colle 3 fois avant le curseur',
    },
    ['{n}~'] = {
      title = '{n}~ — basculer la casse de plusieurs caractères',
      body = "~ bascule un caractère et avance ; préfixez avec un nombre pour en basculer plusieurs d'un coup\n3~ bascule les 3 prochains caractères — évite de répéter ~ plusieurs fois",
      example = '3~ sur "hello" → "HEllo"',
    },

    -- ── diw (detected by visual_textobj v i w d) ─────────────────────────────
    ['diw'] = {
      title = 'diw — supprimer le mot intérieur',
      body = "Supprime le mot entier sous le curseur quelle que soit la position du curseur à l'intérieur\nciw modifie le mot ; diw le supprime — pas besoin de sélectionner visuellement d'abord",
      example = 'he|llo → diw → le mot est supprimé, le curseur reste en place',
    },

    -- ── yyp (detected by yy_then_p) ───────────────────────────────────────────
    ['yyp'] = {
      title = 'yyp — dupliquer la ligne actuelle',
      body = 'Copie toute la ligne et la colle en dessous — la manière idiomatique de dupliquer une ligne\nFaire yy puis p correspond aux mêmes touches, mais y penser comme yyp en fait une seule intention',
      example = 'yyp sur "local x = 1" → duplique cette ligne en dessous',
    },

    -- ── {n}. (detected by dot_repeat × 3) ────────────────────────────────────
    ['{n}.'] = {
      title = '{n}. — répéter la dernière modification N fois',
      body = "Préfixez . avec un nombre pour répéter la dernière modification autant de fois d'un coup\n3. répète trois fois en une seule commande au lieu d'appuyer sur . trois fois séparément",
      example = '3. → répète la dernière modification 3 fois',
    },

    -- ── {n}J (detected by J_repeat × 3) ──────────────────────────────────────
    ['{n}J'] = {
      title = "{n}J — fusionner plusieurs lignes d'un coup",
      body = "Préfixez J avec un nombre pour fusionner autant de lignes en une seule commande\n3J fusionne la ligne actuelle avec les 2 lignes suivantes — pas besoin d'appuyer sur J plusieurs fois",
      example = '3J → fusionne la ligne actuelle avec les 2 lignes suivantes',
    },

    -- ── {n}>> / {n}<< (detected by indent_run / dedent_run × 3) ─────────────
    ['{n}>>'] = {
      title = "{n}>> — indenter plusieurs lignes d'un coup",
      body = "Préfixez >> avec un nombre pour indenter autant de lignes en une seule commande\n3>> indente 3 lignes à partir du curseur — plus rapide que d'appuyer sur >> plusieurs fois",
      example = "3>> → indente 3 lignes d'un coup",
    },
    ['{n}<<'] = {
      title = "{n}<< — désindenter plusieurs lignes d'un coup",
      body = "Préfixez << avec un nombre pour désindenter autant de lignes en une seule commande\n3<< retire un niveau d'indentation à 3 lignes à partir du curseur",
      example = "3<< → désindente 3 lignes d'un coup",
    },
  },
}
