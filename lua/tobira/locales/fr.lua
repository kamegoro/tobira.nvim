return {
  guide = {
    title = 'guide tobira',
    hint = ':TobiraGuide  afficher/masquer le guide',
    all_mastered = 'Toutes les commandes de ce niveau sont maîtrisées !',
    pinned = 'Épinglé',
  },
  progress = {
    title = 'tobira — votre parcours Vim',
    level_label = 'Niveau : ',
    levels = {
      novice = 'novice',
      beginner = 'débutant',
      intermediate = 'intermédiaire',
      advanced = 'avancé',
    },
    next = 'Suivant : ',
    hint = '[x] masquer · [p] épingler · [q / Esc] fermer',
    categories = {
      motion = 'Déplacement',
      edit = 'Édition',
      search = 'Recherche',
      window = 'Fenêtre',
      fold = 'Pliage',
      mark = 'Marque',
      macro = 'Macro',
    },
  },
  notifications = {
    reset = 'tobira : journal d’utilisation réinitialisé',
    no_suggestions = 'tobira : aucune nouvelle suggestion pour le moment 🎉',
    invalid_config = 'tobira : configuration invalide — ',
  },
  stats = {
    title = "tobira — statistiques d'utilisation",
    total_keystrokes = 'Nombre total de frappes',
    discovered = 'Découvertes',
    mastery = 'Maîtrise',
    mastery_dist = '  Jamais %d  ·  ☆ %d  ·  ★ %d  ·  ★★+ %d',
    top_commands = 'Commandes les plus utilisées',
    try_next = '⚡ Essayez ensuite',
    hint = '[q / Esc]  fermer',
  },
  float = {
    example_prefix = 'p. ex. ',
    close_hint = 'q/Esc fermer',
  },
  -- Chaînes affichées dans la fenêtre flottante et :TobiraProgress.
  -- Les clés correspondent exactement aux clés de commands.registry.
  suggestions = {
    [';'] = {
      title = '; — répéter le dernier f / t / F / T',
      body = "Après une recherche avec f, t, F ou T, ; saute à l'occurrence suivante dans la même direction\n, revient dans la direction opposée",
      example = 'fa ;; → prochain a, puis le suivant',
    },
    [','] = {
      title = ', — répéter f / t / F / T en sens inverse',
      body = "L'opposé de ; — répète la dernière recherche f/t/F/T dans la direction inverse\nUtile lorsque vous allez trop loin avec ;",
      example = 'fa ;;; , → revenir d’une occurrence',
    },
    ['cw'] = {
      title = 'cw — supprimer un mot et passer en mode insertion',
      body = 'Remplace la séquence dw + i en une seule commande\nPasse immédiatement en mode insertion après la suppression',
      example = 'cw → supprime du curseur à la fin du mot → mode insertion',
    },
    ['ciw'] = {
      title = 'ciw — modifier le mot sous le curseur',
      body = "Fonctionne même si le curseur est au milieu d'un mot\ncw ne supprime que depuis le curseur ; ciw remplace le mot entier",
      example = 'hel|lo → ciw → world',
    },
    ['<C-r>'] = {
      title = '<C-r> — rétablir',
      body = "Vous avez annulé une modification de trop ? <C-r> rétablit la dernière modification annulée\nAssociez-le à u / <C-r> pour parcourir l'historique des modifications",
      example = 'u u u <C-r> → annule 3 fois, rétablit une fois',
    },
    ['ddp'] = {
      title = 'ddp — échanger la ligne courante avec la suivante',
      body = 'dd supprime la ligne, p la colle en dessous — ddp échange les deux lignes en une seule commande\nPas besoin de naviguer entre les deux lignes',
      example = 'ddp → la ligne courante descend d’une ligne',
    },
    ['{n}j'] = {
      title = '{n}j — sauter plusieurs lignes à la fois',
      body = 'Préfixez un mouvement avec un nombre pour le répéter\n5j descend de 5 lignes ; fonctionne aussi avec k, w, b, etc.',
      example = '5j → descend de 5 lignes',
    },
    ['^'] = {
      title = '^ — aller au premier caractère non vide',
      body = '0 va à la colonne 0 ; ^ va au premier caractère non blanc\nDans la plupart des cas, ^ est ce que vous recherchez',
      example = '    hello → ^ → le curseur se place sur h',
    },
    ['cgn'] = {
      title = 'cgn — modifier la prochaine occurrence trouvée',
      body = 'Après une recherche avec /, utilisez cgn pour modifier la prochaine occurrence\nAppuyez ensuite sur . pour répéter sur chaque occurrence suivante',
      example = '/word → cgn → new → Esc → . . .',
    },
    ['.'] = {
      title = '. — répéter la dernière modification',
      body = 'Répète votre dernière modification sans repasser en mode insertion\nCombinez-le avec n ou ; pour modifier plusieurs occurrences en une seule fois',
      example = 'cw foo <Esc> n . → modifie également l’occurrence suivante',
    },
    ['A'] = {
      title = 'A — ajouter à la fin de la ligne',
      body = "$a en une seule touche — se déplace à la fin de la ligne et passe en mode insertion\nÀ utiliser avec I (insertion au début de la ligne) pour modifier rapidement le début ou la fin d'une ligne",
      example = 'A; → ajoute un point-virgule à la fin de la ligne',
    },
    ['O'] = {
      title = 'O — ouvrir une nouvelle ligne au-dessus',
      body = "Comme o, mais ouvre une nouvelle ligne au-dessus du curseur\nPas besoin de remonter avant d'appuyer sur o",
      example = 'O → nouvelle ligne vide au-dessus du curseur → mode insertion',
    },
    ['D'] = {
      title = 'D — supprimer jusqu’à la fin de la ligne',
      body = "Supprime du curseur jusqu'à la fin de la ligne (équivalent à d$)\nPermet de retaper la fin de la ligne sans devoir s'y déplacer",
      example = 'D → saisir la nouvelle fin',
    },
    ['C'] = {
      title = 'C — modifier jusqu’à la fin de la ligne',
      body = "D + i en une seule commande — supprime jusqu'à la fin de la ligne et passe en mode insertion\nComme cw, mais pour le reste de la ligne au lieu d'un seul mot",
      example = "C → remplace tout depuis le curseur jusqu'à la fin",
    },
    ['gn'] = {
      title = 'gn — sélectionner la prochaine occurrence trouvée',
      body = 'Après * ou /, gn sélectionne la prochaine occurrence en mode visuel\nUtilisez-le avec c (cgn), puis . pour remplacer chaque occurrence',
      example = '* → cgn → new text → Esc → . . .',
    },
    ['e'] = {
      title = 'e — aller à la fin du mot',
      body = "w va au début du mot suivant ; e va à sa fin\nUtile lorsque vous souhaitez ajouter du texte à la fin d'un mot",
      example = 'ea → ajoute du texte après le mot courant',
    },
    ['I'] = {
      title = 'I — insérer au début de la ligne',
      body = "Déplace le curseur sur le premier caractère non vide et passe en mode insertion\nÀ utiliser avec A (fin de ligne) pour modifier rapidement le début ou la fin d'une ligne",
      example = 'I// → commente la ligne courante',
    },
    ['H'] = {
      title = "H — aller en haut de l'écran",
      body = 'Déplace le curseur en haut de la fenêtre visible sans faire défiler le contenu\nM va au milieu, L va en bas',
      example = 'H → le curseur se place sur la première ligne visible',
    },
    ['M'] = {
      title = "M — aller au milieu de l'écran",
      body = 'Place le curseur exactement au milieu de la fenêtre visible\nUtile pour se réorienter rapidement après un grand déplacement',
      example = 'M → le curseur se place sur la ligne centrale',
    },
    ['L'] = {
      title = "L — aller en bas de l'écran",
      body = "Déplace le curseur sur la dernière ligne visible sans faire défiler le contenu\nÀ utiliser avec H et M pour naviguer par rapport à l'écran",
      example = 'L → le curseur se place sur la dernière ligne visible',
    },
    ['{n}x'] = {
      title = '{n}x — supprimer plusieurs caractères à la fois',
      body = "Préfixez x avec un nombre pour supprimer plusieurs caractères en une seule commande\nFonctionne aussi avec d'autres mouvements : 3dw, 2dd, etc.",
      example = '5x → supprime 5 caractères sous le curseur',
    },
    ['<C-d>'] = {
      title = '<C-d> — faire défiler d’une demi-page vers le bas',
      body = "Déplace l'affichage et le curseur vers le bas de la moitié de la hauteur de la fenêtre\nBeaucoup plus rapide que d'appuyer plusieurs fois sur j",
      example = '<C-d><C-d> → fait défiler une page entière vers le bas',
    },
    ['<C-u>'] = {
      title = '<C-u> — faire défiler d’une demi-page vers le haut',
      body = "L'équivalent vers le haut de <C-d>\nUtilisez-les ensemble pour naviguer efficacement dans les grands fichiers",
      example = '<C-d> puis <C-u> → descendre puis remonter',
    },
    ['{n}k'] = {
      title = '{n}k — remonter plusieurs lignes à la fois',
      body = 'Préfixez k avec un nombre pour remonter plusieurs lignes en une seule commande\nFonctionne avec tous les mouvements : 5k, 3w, 2b, etc.',
      example = '5k → remonte de 5 lignes',
    },
    ['*'] = {
      title = '* — rechercher le mot sous le curseur',
      body = "Place le mot sous le curseur dans le registre de recherche et passe à l'occurrence suivante\nPlus rapide que de taper /word<Enter> — inutile de saisir le mot",
      example = 'curseur sur "foo" → * → passe à l’occurrence suivante de "foo"',
    },
    ['<C-o>'] = {
      title = '<C-o> — revenir à la position précédente',
      body = 'Après un grand déplacement (* / G gg /), <C-o> vous ramène à votre position précédente\n<C-i> vous fait avancer de nouveau dans la liste des déplacements',
      example = '* <C-o> → aller à l’occurrence, puis revenir au point de départ',
    },
    ['P'] = {
      title = 'P — coller avant le curseur',
      body = 'p colle après le curseur ; P colle avant\nPour les copies de lignes entières : p colle sous la ligne, P la colle au-dessus',
      example = 'yy P → copie la ligne courante et la colle au-dessus',
    },

    -- ── Chaîne de déplacements f → t (arrêt avant le caractère) ───────────
    ['t'] = {
      title = 't — se déplacer juste avant un caractère',
      body = "Comme f, mais s'arrête un caractère avant la cible\nIdéal avec les opérateurs : ct; modifie le texte jusqu'au prochain ; (sans l'inclure)",
      example = 'ct; → modifie tout jusqu’au prochain point-virgule',
    },
    ['T'] = {
      title = 'T — se déplacer juste après un caractère (vers l’arrière)',
      body = "Recherche vers l'arrière comme F, mais s'arrête juste après le caractère\nSe répète avec ; et , comme toutes les recherches f/t",
      example = 'T, → revenir juste après la virgule précédente',
    },

    -- ── Navigation bidirectionnelle dans la liste des déplacements ─────────
    ['<C-i>'] = {
      title = '<C-i> — avancer dans la liste des déplacements',
      body = 'Après être revenu avec <C-o>, <C-i> vous fait avancer à nouveau\nNaviguez dans votre historique de déplacements dans les deux sens',
      example = '<C-o> <C-o> <C-i> → revenir deux fois, puis avancer une fois',
    },

    -- ── Défilement d’une page entière ──────────────────────────────────────
    ['<C-f>'] = {
      title = '<C-f> — faire défiler une page entière vers le bas',
      body = "<C-d> fait défiler une demi-page ; <C-f> fait défiler une page entière\nPlus rapide pour parcourir de grandes sections d'un fichier",
      example = '<C-f> → fait défiler d’une hauteur de fenêtre complète',
    },
    ['<C-b>'] = {
      title = '<C-b> — faire défiler une page entière vers le haut',
      body = "L'équivalent vers le haut de <C-f>\nÀ utiliser avec <C-f> pour parcourir rapidement un grand fichier dans les deux sens",
      example = '<C-f> <C-b> → descendre d’une page entière puis remonter',
    },

    -- ── Déplacements entre paragraphes ─────────────────────────────────────
    ['}'] = {
      title = '} — aller à la fin du paragraphe',
      body = "Descend jusqu'à la prochaine ligne vide et saute des blocs entiers\nPlus rapide que j pour naviguer entre des fonctions ou des sections de texte",
      example = '} → le curseur atteint la ligne vide après le bloc courant',
    },
    ['{'] = {
      title = '{ — aller au début du paragraphe',
      body = "L'équivalent vers le haut de } — remonte jusqu'à la ligne vide précédente\nPermet de naviguer rapidement entre les blocs de code ou les paragraphes",
      example = '{ → le curseur atteint la ligne vide avant le bloc courant',
    },

    -- ── Positionnement de l’écran ───────────────────────────────────────────
    ['zz'] = {
      title = 'zz — centrer l’écran sur le curseur',
      body = "Fait défiler l'affichage afin que la ligne du curseur soit au milieu de la fenêtre\nLe curseur ne bouge pas ; seule la zone visible est déplacée",
      example = 'zz → la ligne courante est centrée dans la fenêtre',
    },
    ['zt'] = {
      title = "zt — placer la ligne du curseur en haut de l'écran",
      body = 'Comme zz, mais place la ligne du curseur en haut de la fenêtre\nzt / zz / zb permettent de la positionner en haut / au centre / en bas',
      example = 'zt → la ligne courante est placée en haut de la fenêtre',
    },
    ['zb'] = {
      title = "zb — placer la ligne du curseur en bas de l'écran",
      body = "Fait défiler l'affichage afin que la ligne du curseur apparaisse en bas de la fenêtre\nÀ utiliser avec zt et zz pour contrôler précisément la position de l'affichage",
      example = 'zb → la ligne courante est placée en bas de la fenêtre',
    },

    -- ── Déplacements par WORD ─────────────────────────────────────────────
    ['W'] = {
      title = 'W — avancer d’un WORD',
      body = "Comme w, mais ne s'arrête qu'aux espaces en ignorant la ponctuation\nUtile lorsque w s'arrête trop souvent dans des expressions comme « foo.bar(baz) »",
      example = 'W sur "foo.bar.baz" → saute le jeton entier en une seule fois',
    },
    ['B'] = {
      title = 'B — reculer d’un WORD',
      body = "Comme b, mais considère le texte relié par la ponctuation comme un seul WORD\nL'équivalent vers l'arrière de W",
      example = 'B sur "foo.bar.baz" → recule sur le jeton entier',
    },

    -- ── Fin du mot précédent ──────────────────────────────────────────────
    ['ge'] = {
      title = 'ge — aller à la fin du mot précédent',
      body = "e avance jusqu'à la fin d'un mot ; ge recule jusqu'à la fin du mot précédent\nUtile lorsque vous souhaitez ajouter du texte à la fin du mot situé avant le curseur",
      example = 'gea → aller à la fin du mot précédent puis ajouter du texte',
    },

    -- ── Correspondance des parenthèses ────────────────────────────────────
    ['%'] = {
      title = '% — aller à la parenthèse correspondante',
      body = "Navigue entre les parenthèses (), crochets [] et accolades {} correspondants\nFonctionne également avec /* */, #if/#endif et d'autres paires selon le type de fichier",
      example = '% sur ( → le curseur va sur le ) correspondant',
    },

    -- ── Raccourcis d’édition d’un seul caractère ──────────────────────────
    ['r'] = {
      title = 'r — remplacer un seul caractère',
      body = 'Remplace le caractère sous le curseur sans passer en mode insertion\nPlus rapide que x + i + caractère pour corriger une faute sur un seul caractère',
      example = 'ra → remplace le caractère sous le curseur par a',
    },
    ['s'] = {
      title = 's — remplacer un caractère et passer en mode insertion',
      body = 'Supprime le caractère sous le curseur et passe immédiatement en mode insertion\nUne seule touche au lieu de x + i',
      example = 's → supprime le caractère courant → mode insertion',
    },
    ['cc'] = {
      title = 'cc — modifier toute la ligne courante',
      body = "Efface le contenu de la ligne et passe en mode insertion en une seule commande\nPlus rapide que d'aller au début de la ligne, d'appuyer sur D puis de passer en mode insertion",
      example = 'cc → la ligne est vidée → mode insertion',
    },

    -- ── Fusion des lignes ─────────────────────────────────────────────────
    ['J'] = {
      title = 'J — fusionner la ligne suivante avec la ligne courante',
      body = "Ajoute la ligne suivante à la ligne courante en insérant un espace\nInutile d'aller en fin de ligne, de supprimer le retour à la ligne puis d'ajouter un espace",
      example = 'J → "foo\\n  bar" devient "foo bar" (indentation supprimée)',
    },

    -- ── Changement de casse ───────────────────────────────────────────────
    ['~'] = {
      title = '~ — inverser la casse du caractère sous le curseur',
      body = "Transforme une minuscule en majuscule et inversement, puis avance d'un caractère\nPréfixez avec un nombre : 3~ inverse la casse des 3 caractères suivants",
      example = '~ sur "hello" → "Hello" → le curseur avance',
    },

    -- ── Incrémentation / décrémentation de nombres ────────────────────────
    ['<C-a>'] = {
      title = '<C-a> — incrémenter le nombre sous le curseur',
      body = 'Trouve le prochain nombre sur la ligne et lui ajoute 1\nPréfixez avec un nombre pour augmenter davantage : 5<C-a> ajoute 5',
      example = '<C-a> sur "padding: 8px" → "padding: 9px"',
    },
    ['<C-x>'] = {
      title = '<C-x> — décrémenter le nombre sous le curseur',
      body = "L'équivalent vers le bas de <C-a> — soustrait 1 au prochain nombre\nPratique pour ajuster des valeurs numériques sans les retaper manuellement",
      example = '<C-x> sur "z-index: 10" → "z-index: 9"',
    },

    -- ── Mode visuel ───────────────────────────────────────────────────────
    ['V'] = {
      title = 'V — démarrer une sélection visuelle par ligne',
      body = 'Sélectionne des lignes entières plutôt que des caractères individuels\nIdéal pour déplacer, copier ou supprimer des lignes entières avec un retour visuel',
      example = 'Vjjd → sélectionne visuellement 3 lignes puis les supprime',
    },
    ['<C-v>'] = {
      title = '<C-v> — démarrer une sélection visuelle en bloc (colonne)',
      body = 'Sélectionne un bloc rectangulaire sur plusieurs lignes\nTrès pratique pour modifier des colonnes alignées : préfixer du texte, modifier plusieurs valeurs à la fois',
      example = '<C-v>3jI// <Esc> → ajoute // au début de 4 lignes en une seule fois',
    },

    -- ── Extraction d’un objet texte ───────────────────────────────────────
    ['yiw'] = {
      title = 'yiw — copier le mot sous le curseur',
      body = 'Copie le mot entier sous le curseur, quelle que soit la position du curseur dans celui-ci\nÀ utiliser avec ciw (modifier) et diw (supprimer) pour une édition cohérente au niveau du mot',
      example = 'yiw puis aller sur le mot cible puis ciw p → remplacer le mot',
    },

    -- ── Macros ────────────────────────────────────────────────────────────
    ['q'] = {
      title = 'q — enregistrer une macro',
      body = "q{a} commence l'enregistrement dans le registre a ; appuyez de nouveau sur q pour arrêter\n@{a} rejoue la macro ; @@ répète la dernière macro — automatisez les modifications répétitives",
      example = 'qaIhello<Esc>q puis @a → insère "hello" au début de la ligne lors de la lecture',
    },

    -- ── Recherche vers l’arrière ──────────────────────────────────────────
    ['N'] = {
      title = 'N — aller à l’occurrence précédente',
      body = "n va à l'occurrence suivante ; N revient à l'occurrence précédente\nChangez de direction à tout moment sans ressaisir le motif de recherche",
      example = '/foo → nnn N → avancer de 3 occurrences puis revenir d’une',
    },
    ['#'] = {
      title = '# — rechercher vers l’arrière le mot sous le curseur',
      body = "* recherche vers l'avant le mot sous le curseur ; # recherche vers l'arrière\nRetrouvez instantanément toutes les occurrences sans saisir le terme de recherche",
      example = 'curseur sur "foo" → # → va à l’occurrence précédente de "foo"',
    },

    -- ── G → gg ────────────────────────────────────────────────────────────
    ['gg'] = {
      title = 'gg — aller à la première ligne du fichier',
      body = 'G va à la fin du fichier ; gg va au début\nPréfixez avec un nombre : 5gg va directement à la ligne 5',
      example = 'gg → le curseur se place sur la ligne 1',
    },

    -- ── Déplacement sur les lignes visuelles ──────────────────────────────
    ['gj'] = {
      title = 'gj — descendre d’une ligne visuelle (affichée)',
      body = "Lorsque les lignes sont renvoyées à la ligne automatiquement, j saute toute la ligne logique ; gj descend d'une ligne affichée\nIndispensable pour modifier du texte long ou du Markdown avec retour à la ligne",
      example = 'gj sur un paragraphe renvoyé à la ligne → le curseur descend à la ligne affichée suivante',
    },
    ['gk'] = {
      title = 'gk — remonter d’une ligne visuelle (affichée)',
      body = "L'équivalent vers le haut de gj — remonte d'une ligne affichée lorsque les lignes sont renvoyées à la ligne\nUtilisez gj et gk pour naviguer naturellement dans le texte renvoyé à la ligne",
      example = 'gk sur un paragraphe renvoyé à la ligne → le curseur remonte à la ligne affichée précédente',
    },

    -- ── Défilement ligne par ligne ────────────────────────────────────────
    ['<C-e>'] = {
      title = '<C-e> — faire défiler la fenêtre d’une ligne vers le bas sans déplacer le curseur',
      body = "Décale la zone visible d'une ligne ; le curseur reste sur la même ligne\nÀ utiliser avec <C-y> pour ajuster précisément l'affichage sans perdre votre position",
      example = '<C-e><C-e> → le texte défile de 2 lignes ; le curseur reste en place',
    },
    ['<C-y>'] = {
      title = '<C-y> — faire défiler la fenêtre d’une ligne vers le haut sans déplacer le curseur',
      body = "L'équivalent inverse de <C-e> — affiche une ligne supplémentaire en haut de la fenêtre\nAjustez la zone visible sans modifier votre position d'édition",
      example = '<C-y> → une ligne supplémentaire apparaît en haut de la fenêtre',
    },

    -- ── Navigation dans la liste des modifications ────────────────────────
    ['g;'] = {
      title = 'g; — revenir à une ancienne position dans la liste des modifications',
      body = 'Chaque modification est ajoutée à la liste des modifications ; g; permet de revenir en arrière\nContrairement à la liste des déplacements, seules les positions où le texte a été modifié sont enregistrées',
      example = 'g; g; → revient aux deux derniers emplacements modifiés',
    },
    ['g,'] = {
      title = 'g, — avancer vers une position plus récente dans la liste des modifications',
      body = "Après être revenu avec g;, g, vous fait avancer de nouveau\nNaviguez dans l'historique de vos modifications dans les deux sens sans quitter le fichier",
      example = 'g; g, → revenir à la dernière modification, puis avancer de nouveau',
    },

    -- ── retour au dernier mode insertion / fichier précédent / dernier saut ────────────────
    ['gi'] = {
      title = 'gi — revenir à la dernière position d’insertion et entrer en mode insertion',
      body = "Replace le curseur à l'endroit où vous avez quitté pour la dernière fois le mode insertion et y revient immédiatement\nÉvite de devoir revenir manuellement après avoir consulté une autre partie du fichier",
      example = 'gi → le curseur revient au dernier endroit où vous avez saisi du texte → mode insertion',
    },
    ['<C-^>'] = {
      title = '<C-^> — basculer vers le fichier précédent',
      body = "Bascule entre le fichier actuel et le dernier fichier ouvert\nLe moyen le plus rapide d'alterner entre deux fichiers sur lesquels vous travaillez",
      example = '<C-^> → ouvre le dernier fichier → <C-^> → revient au premier',
    },
    ["''"] = {
      title = "'' — revenir à la ligne du saut précédent",
      body = "Revient rapidement à la ligne où vous vous trouviez avant le dernier grand déplacement\n'' revient à la ligne ; `` (accents graves) restaure également la colonne exacte",
      example = "G '' → aller à la fin du fichier puis revenir à la ligne d'origine",
    },

    -- ── définition / fichier sous le curseur ────────────────────────────────────
    ['gd'] = {
      title = 'gd — aller à la définition locale',
      body = "Recherche dans la portée de la fonction actuelle la première déclaration du mot sous le curseur\nPlus rapide qu'une recherche globale — inutile de quitter le fichier ou de saisir un motif",
      example = 'curseur sur "myVar" → gd → va à la première déclaration de myVar',
    },
    ['gf'] = {
      title = 'gf — ouvrir le fichier dont le nom est sous le curseur',
      body = 'Ouvre le fichier dont le nom est sous le curseur dans un nouveau tampon de la fenêtre actuelle\nFonctionne avec les chemins relatifs, absolus et les noms de fichiers dans les chaînes de caractères',
      example = 'curseur sur "utils/helpers.lua" → gf → ouvre ce fichier',
    },

    -- ── resélection de la dernière sélection visuelle ──────────────────────────────
    ['gv'] = {
      title = 'gv — restaurer la dernière sélection visuelle',
      body = 'Réactive exactement la même sélection visuelle que la dernière fois où le mode visuel a été utilisé\nPratique lorsque vous souhaitez appliquer une seconde opération à la même zone',
      example = 'vip y gv d → copier un paragraphe, puis le resélectionner et le supprimer',
    },

    -- ── fin du WORD précédent ─────────────────────────────────────────────────
    ['gE'] = {
      title = 'gE — aller à la fin du WORD précédent',
      body = "ge va à la fin du mot précédent ; gE fait la même chose mais ignore toute la ponctuation\nL'équivalent de ge au niveau WORD — considère « foo.bar.baz » comme un seul élément",
      example = 'gE sur foo.bar → va à la fin du WORD précédent',
    },

    -- ── commandes de pliage ─────────────────────────────────────────────────────
    ['za'] = {
      title = 'za — ouvrir ou fermer le pli sous le curseur',
      body = 'Ouvre un pli fermé ou ferme un pli ouvert sous le curseur\nLa commande de pliage la plus pratique — une seule touche pour afficher ou masquer une section',
      example = 'za → ouvre le bloc replié ; za de nouveau → le replie',
    },
    ['zo'] = {
      title = 'zo — ouvrir le pli sous le curseur',
      body = 'Affiche les lignes masquées dans un pli sans affecter les autres plis ouverts\nContrairement à za, zo ouvre uniquement — il ne referme jamais un pli déjà ouvert',
      example = 'zo → les lignes masquées du pli deviennent visibles',
    },
    ['zc'] = {
      title = 'zc — fermer le pli sous le curseur',
      body = "Replie un bloc ouvert en une seule ligne de résumé\nL'inverse de zo — ferme uniquement, sans jamais ouvrir un pli par erreur",
      example = 'zc → le bloc développé est replié en une ligne de résumé',
    },
    ['zM'] = {
      title = 'zM — fermer tous les plis du tampon',
      body = "Replie tous les plis du fichier en une seule fois — offre une vue d'ensemble de la structure\nUtile pour parcourir un gros fichier avant d'explorer une section en détail",
      example = 'zM → toutes les fonctions sont repliées → seule la structure principale est visible',
    },
    ['zR'] = {
      title = 'zR — ouvrir tous les plis du tampon',
      body = "Déplie tous les plis du fichier — l'inverse de zM\nRestaure l'affichage complet après avoir exploré le fichier avec les commandes de pliage",
      example = 'zM zR → replie tous les plis puis les rouvre tous',
    },

    -- ── suppression avant le curseur / mode remplacement / copier jusqu'à la fin de ligne ────────────────────────
    ['X'] = {
      title = 'X — supprimer le caractère avant le curseur',
      body = 'Supprime le caractère situé immédiatement à gauche du curseur sans entrer en mode insertion\nComme si vous appuyiez sur Retour arrière tout en restant en mode Normal',
      example = 'X → le caractère immédiatement à gauche du curseur est supprimé',
    },
    ['R'] = {
      title = 'R — entrer en mode remplacement',
      body = 'Remplace le texte existant caractère par caractère pendant la saisie, sans insérer ni décaler le texte\nIdéal pour remplacer une section de largeur fixe tout en conservant le reste du texte intact',
      example = 'Rhello → remplace les 5 caractères suivants par "hello"',
    },
    ['Y'] = {
      title = "Y — copier du curseur jusqu'à la fin de la ligne",
      body = "Copie le texte depuis la position du curseur jusqu'à la fin de la ligne (équivalent à y$)\nComplète D (supprimer jusqu'à la fin de ligne) et C (modifier jusqu'à la fin de ligne) pour des opérations cohérentes sur la fin de ligne",
      example = 'Y p → copie le reste de la ligne puis le colle en dessous',
    },

    -- ── opérateurs d'indentation ──────────────────────────────────────────────────
    ['>>'] = {
      title = '>> — indenter la ligne actuelle',
      body = "Décale la ligne actuelle vers la droite d'un niveau d'indentation\nPréfixez avec un nombre : 3>> indente les 3 lignes suivantes d'un seul coup",
      example = ">> → la ligne actuelle est indentée d'un niveau",
    },
    ['<<'] = {
      title = '<< — désindenter la ligne actuelle',
      body = "Décale la ligne actuelle vers la gauche d'un niveau d'indentation\nL'inverse de >> — utile pour corriger un code trop indenté",
      example = "<< → la ligne actuelle est désindentée d'un niveau",
    },
    ['=='] = {
      title = '== — indenter automatiquement la ligne actuelle',
      body = "Applique l'indentation automatique selon les règles du type de fichier\nPlus rapide que de corriger manuellement avec >> ou << lorsque l'indentation est complexe",
      example = '== → la ligne est automatiquement réalignée avec la bonne indentation',
    },

    -- ── opérateurs de casse ────────────────────────────────────────────────────
    ['gu'] = {
      title = 'gu{motion} — convertir une zone en minuscules',
      body = "Met en minuscules le texte couvert par le mouvement\nguiw → met le mot actuel en minuscules ; gu$ → met en minuscules jusqu'à la fin de la ligne",
      example = 'guiw → "Hello" devient "hello"',
    },
    ['gU'] = {
      title = 'gU{motion} — convertir une zone en majuscules',
      body = "L'équivalent de gu pour les majuscules — convertit le texte sélectionné en MAJUSCULES\ngUiw → met le mot courant en majuscules",
      example = 'gUiw → "hello" devient "HELLO"',
    },
    ['g~'] = {
      title = 'g~{motion} — inverser la casse d’une zone',
      body = "Inverse la casse de chaque caractère couvert par le mouvement : les majuscules deviennent minuscules et inversement\nComme appliquer ~ à tout un mouvement au lieu d'un seul caractère",
      example = 'g~iw → "Hello World" devient "hELLO wORLD"',
    },

    -- ── mise en forme du texte ───────────────────────────────────────────────────────
    ['gq'] = {
      title = 'gq{motion} — reformater le texte selon la largeur des lignes',
      body = 'Reformate le texte couvert par le mouvement afin de respecter textwidth\ngqip reformate le paragraphe courant ; gqq reformate la ligne actuelle',
      example = 'gqip → le paragraphe actuel est reformaté selon la largeur configurée',
    },

    -- ── joindre sans espace ────────────────────────────────────────────────
    ['gJ'] = {
      title = "gJ — joindre des lignes sans insérer d'espace",
      body = "Comme J mais sans ajouter d'espace entre les lignes fusionnées\nUtile lorsque l'ajout d'un espace casserait la syntaxe",
      example = 'gJ → "foo\\n  bar" devient "foobar" (sans espace)',
    },

    -- ── répéter la dernière macro ─────────────────────────────────────────────────
    ['@@'] = {
      title = '@@ — répéter la dernière macro exécutée',
      body = 'Relance la dernière macro exécutée avec @{registre}\nÉvite de retaper le nom du registre lors de répétitions',
      example = '@a → exécute la macro a ; @@ → exécute à nouveau la macro a sans préciser "a"',
    },

    -- ── chaîne des objets de texte ─────────────────────────────────────────────────
    ['ci"'] = {
      title = 'ci" — modifier le contenu entre guillemets doubles',
      body = "Supprime le contenu entre les guillemets doubles les plus proches puis entre en mode insertion\nL'objet de texte i\" fonctionne avec n'importe quel opérateur : c, d, y, v",
      example = 'sur "hello world" → ci" → contenu supprimé → saisir le nouveau texte',
    },
    ["ci'"] = {
      title = "ci' — modifier le contenu entre apostrophes",
      body = 'Comme ci" mais cible les apostrophes au lieu des guillemets doubles\nFonctionne tant que le curseur se trouve entre une paire d\'apostrophes',
      example = "sur 'hello' → ci' → contenu supprimé → saisir le nouveau texte",
    },
    ['cib'] = {
      title = 'cib — modifier le contenu entre parenthèses',
      body = "Supprime le contenu entre les parenthèses () les plus proches puis entre en mode insertion\nib est l'objet de texte « bloc interne », équivalent à i( ; pratique dans les appels de fonction",
      example = 'sur foo(bar, baz) → cib → supprime "bar, baz" → saisir les nouveaux arguments',
    },
    ['ciB'] = {
      title = 'ciB — modifier le contenu entre accolades',
      body = "Cible le contenu du bloc {} le plus proche\nB représente le « grand bloc » ; pratique pour vider ou réécrire le corps d'une fonction",
      example = "dans le corps d'une fonction → ciB → supprime tout le contenu → mode insertion",
    },
    ['cit'] = {
      title = 'cit — modifier le contenu d’une balise HTML/XML',
      body = "Supprime le texte situé entre la balise ouvrante et la balise fermante correspondantes puis entre en mode insertion\nit est l'objet de texte « balise interne » et fonctionne avec toute paire de balises",
      example = 'sur <p>hello</p> → cit → supprime "hello" → saisir le nouveau contenu',
    },
    ['cip'] = {
      title = 'cip — modifier le paragraphe courant',
      body = "Remplace entièrement le paragraphe actuel (bloc continu de lignes non vides)\nip sélectionne le paragraphe sans inclure les lignes vides qui l'entourent",
      example = 'cip → tout le paragraphe est supprimé → mode insertion',
    },

    -- ── recherche de mot partiel ───────────────────────────────────────────────
    ['g*'] = {
      title = 'g* — rechercher vers l’avant une partie du mot sous le curseur',
      body = '* exige une correspondance sur un mot entier ; g* trouve également le mot comme sous-chaîne\nUtile lorsque vous voulez que « foo » trouve aussi « foobar », « football » et « foo »',
      example = 'g* sur "foo" → trouve "foo", "foobar", "fooResult"',
    },
    ['g#'] = {
      title = 'g# — rechercher vers l’arrière une partie du mot sous le curseur',
      body = "L'équivalent inverse de g* — recherche la sous-chaîne en remontant dans le fichier\nTrouve toutes les occurrences, y compris les correspondances partielles comme g*, mais en sens inverse",
      example = 'g# sur "foo" → revient au précédent "foo" ou "foobar"',
    },

    -- ── gestion des fenêtres ─────────────────────────────────────────────────
    ['<C-w>s'] = {
      title = '<C-w>s — scinder la fenêtre horizontalement',
      body = "Ouvre une division horizontale afin d'afficher deux parties d'un fichier simultanément\n<C-w>v crée une division verticale côte à côte",
      example = '<C-w>s → deux volets horizontaux ; naviguez indépendamment dans chacun',
    },
    ['<C-w>v'] = {
      title = '<C-w>v — scinder la fenêtre verticalement',
      body = "Ouvre une division verticale — deux volets côte à côte dans le même onglet\nAssociez-la à <C-w>h et <C-w>l pour passer de l'un à l'autre",
      example = '<C-w>v → deux volets verticaux ; <C-w>l → aller au volet de droite',
    },
    ['<C-w>w'] = {
      title = '<C-w>w — passer à la fenêtre suivante',
      body = 'Déplace le focus vers la division suivante sans préciser de direction\nLe moyen le plus rapide de basculer entre deux volets',
      example = '<C-w>w → le focus passe à la division suivante',
    },
    ['<C-w>h'] = {
      title = '<C-w>h — déplacer le focus vers la fenêtre de gauche',
      body = 'Navigation directionnelle entre les fenêtres — déplace le focus vers la gauche, comme h déplace le curseur\nUtilisez les variantes h / j / k / l pour naviguer précisément entre les divisions',
      example = '<C-w>h → le curseur passe au volet immédiatement à gauche',
    },
    ['<C-w>j'] = {
      title = '<C-w>j — déplacer le focus vers la fenêtre du dessous',
      body = 'Déplace le focus vers la division située en dessous de la fenêtre actuelle\nFonctionne avec les divisions horizontales comme mixtes',
      example = '<C-w>j → le curseur passe au volet inférieur',
    },
    ['<C-w>k'] = {
      title = '<C-w>k — déplacer le focus vers la fenêtre du dessus',
      body = "Déplace le focus vers la division située au-dessus de la fenêtre actuelle\nL'équivalent inverse de <C-w>j",
      example = '<C-w>k → le curseur passe au volet supérieur',
    },
    ['<C-w>l'] = {
      title = '<C-w>l — déplacer le focus vers la fenêtre de droite',
      body = 'Déplace le focus vers la division située à droite\nÀ utiliser avec <C-w>h pour naviguer rapidement entre deux volets',
      example = '<C-w>l → le curseur passe au volet de droite',
    },
    ['<C-w>q'] = {
      title = '<C-w>q — fermer la fenêtre actuelle',
      body = 'Ferme la division active ; le tampon reste ouvert\nUtilisez :bd pour supprimer également le tampon, ou :qa pour fermer toutes les divisions',
      example = '<C-w>q → le volet actif est fermé ; le volet restant occupe tout l’espace',
    },
    ['<C-w>='] = {
      title = '<C-w>= — équilibrer la taille de toutes les fenêtres',
      body = "Redimensionne toutes les divisions afin qu'elles aient la même largeur et la même hauteur\nPratique pour rétablir une disposition équilibrée après des redimensionnements manuels",
      example = '<C-w>= → tous les volets retrouvent la même taille',
    },

    ['$'] = {
      title = '$ — aller à la fin de la ligne',
      body = 'Déplace le curseur sur le dernier caractère de la ligne actuelle\nAssociez-le à ^ (premier caractère non vide) pour naviguer rapidement entre les extrémités de la ligne',
      example = '^ → aller au début ; $ → aller à la fin',
    },
    ['g_'] = {
      title = 'g_ — dernier caractère non vide de la ligne',
      body = "Avec $, le curseur peut s'arrêter sur les espaces de fin de ligne ; g_ s'arrête sur le dernier caractère non vide\nPlus précis que $ lorsque des espaces terminent la ligne",
      example = '$ → peut s’arrêter sur un espace ; g_ → dernier vrai caractère',
    },
    ['F'] = {
      title = 'F — rechercher un caractère vers l’arrière',
      body = 'Comme f{caractère}, mais recherche vers la gauche sur la ligne actuelle\n; et , permettent toujours de répéter la recherche dans les deux sens',
      example = 'f, → aller à la virgule suivante ; F, → revenir à la précédente',
    },
    ['('] = {
      title = '( — aller au début de la phrase',
      body = 'Comme { pour les paragraphes, ( va au début de la phrase actuelle\nTrès utile pour naviguer dans du texte, des commentaires ou de la documentation',
      example = '{ → début du paragraphe ; ( → début de la phrase',
    },
    [')'] = {
      title = ') — aller au début de la phrase suivante',
      body = 'Déplace le curseur vers le début de la phrase suivante\nAssociez-le à ( pour naviguer dans les deux sens',
      example = '( puis ) → reculer et avancer entre les phrases',
    },

    ['[['] = {
      title = '[[ — fonction ou section précédente',
      body = "Va à la première ligne de la fonction ou de la section précédente\nPlus rapide que gg suivi d'une recherche dans les fichiers contenant beaucoup de fonctions",
      example = 'gg → début du fichier ; [[ → début de la fonction précédente',
    },
    [']]'] = {
      title = ']] — fonction ou section suivante',
      body = 'Va à la première ligne de la fonction ou de la section suivante\nAssociez-le à [[ pour naviguer rapidement entre les fonctions',
      example = 'G → fin du fichier ; ]] → début de la fonction suivante',
    },

    ['[{'] = {
      title = '[{ — aller à l’accolade ouvrante englobante',
      body = "Remonte jusqu'à l'accolade ouvrante non appariée la plus proche\nTrès utile pour revenir rapidement au début d'un bloc, d'une fonction ou d'une structure",
      example = '% → accolade correspondante ; [{ → début du bloc',
    },
    [']}'] = {
      title = ']} — aller à l’accolade fermante englobante',
      body = "Avance jusqu'à l'accolade fermante non appariée la plus proche\nÀ utiliser avec [{ pour naviguer dans les blocs imbriqués",
      example = '[{ → début du bloc ; ]} → fin du bloc',
    },
    ['[('] = {
      title = '[( — aller à la parenthèse ouvrante englobante',
      body = "Remonte jusqu'à la parenthèse ouvrante non appariée la plus proche\nTrès pratique dans les longs appels de fonctions ou expressions",
      example = '[{ → bloc ; [( → parenthèse englobante',
    },
    ['])'] = {
      title = ']) — aller à la parenthèse fermante englobante',
      body = "Avance jusqu'à la parenthèse fermante non appariée la plus proche\nAssociez-la à [( pour naviguer dans les parenthèses imbriquées",
      example = '[( → parenthèse ouvrante ; ]) → parenthèse fermante',
    },

    ['g0'] = {
      title = 'g0 — premier caractère de la ligne affichée',
      body = 'Lorsque les lignes sont repliées visuellement, 0 va au vrai début de la ligne ; g0 va au début de la ligne affichée\nTrès utile avec les longues lignes et le retour à la ligne activé',
      example = 'gj → ligne visuelle suivante ; g0 → début de cette ligne visuelle',
    },
    ['gx'] = {
      title = 'gx — ouvrir le fichier ou l’URL sous le curseur',
      body = "Ouvre le chemin de fichier ou l'URL sous le curseur avec l'application par défaut du système\nFonctionne avec les URL http/https, les chemins locaux et bien plus",
      example = 'gf → ouvrir le fichier dans Vim ; gx → ouvrir dans le navigateur ou le gestionnaire de fichiers',
    },
    ['<C-]>'] = {
      title = '<C-]> — aller à la définition du tag',
      body = "Suit le tag (définition ctags) situé sous le curseur jusqu'à sa déclaration\nNécessite un fichier tags ; <C-t> ou <C-o> permet de revenir",
      example = 'gd → définition locale ; <C-]> → définition ctags',
    },
    ['K'] = {
      title = 'K — afficher l’aide sur le mot sous le curseur',
      body = 'Exécute le programme défini dans keywordprg (par défaut : man) sur le mot sous le curseur\nAvec de nombreuses configurations LSP, K affiche la documentation contextuelle',
      example = 'gd → aller à la définition ; K → afficher la documentation',
    },

    ['gp'] = {
      title = 'gp — coller et placer le curseur après le texte collé',
      body = 'Comme p, mais le curseur est placé juste après le texte collé\nPratique pour continuer à taper immédiatement après le collage',
      example = 'p → le curseur reste avant le collage ; gp → le curseur est placé après',
    },
    ['gP'] = {
      title = 'gP — coller avant le curseur et placer le curseur après le texte collé',
      body = "Comme P (coller avant le curseur), mais place ensuite le curseur juste après le texte collé\nL'équivalent en majuscule de gp",
      example = 'P → colle avant, curseur avant ; gP → colle avant, curseur après',
    },

    ['@:'] = {
      title = '@: — répéter la dernière commande de la ligne de commande',
      body = 'Répète la dernière commande : exécutée sans avoir à la ressaisir\nAprès @:, vous pouvez utiliser @@ pour la répéter encore',
      example = ':s/foo/bar/ puis @: → répète la substitution',
    },

    ['zj'] = {
      title = 'zj — aller au début du pli suivant',
      body = "Déplace le curseur vers le début du pli suivant, qu'il soit ouvert ou fermé\nPlus rapide que de faire défiler un fichier contenant de nombreux plis",
      example = 'za → ouvrir/fermer un pli ; zj → aller au pli suivant',
    },
    ['zk'] = {
      title = 'zk — aller à la fin du pli précédent',
      body = 'Déplace le curseur vers le haut jusqu’à la fin du pli précédent\nAssociez-le à zj pour naviguer entre les plis dans les deux sens',
      example = 'zj → pli suivant ; zk → pli précédent',
    },
    ['zd'] = {
      title = 'zd — supprimer le pli sous le curseur',
      body = 'Supprime la définition du pli sous le curseur sans modifier le texte\nUtile pour supprimer les plis manuels créés avec zf',
      example = 'zc → fermer le pli ; zd → supprimer cette définition de pli',
    },
    ['E'] = {
      title = 'E — avancer jusqu’à la fin du WORD',
      body = 'Comme e, mais saute jusqu’à la fin du WORD suivant (toute séquence sans espace)\nIgnore les limites de ponctuation où e s’arrêterait',
      example = 'e → fin du mot ; E → fin du WORD (ignore la ponctuation)',
    },
    ['U'] = {
      title = 'U — annuler toutes les modifications de la ligne courante',
      body = 'Restaure la ligne courante dans l’état où elle était lorsque vous y êtes arrivé\nContrairement à u, U annule toutes les modifications de cette ligne en une seule fois',
      example = 'u → annuler la dernière modification ; U → restaurer toute la ligne',
    },
    ['ZZ'] = {
      title = 'ZZ — enregistrer et quitter',
      body = 'Enregistre le fichier et ferme la fenêtre en une seule frappe\nÉquivalent à :wq, mais plus rapide à saisir',
      example = ':wq ou ZZ → même résultat, ZZ économise quelques frappes',
    },
    ['ZQ'] = {
      title = 'ZQ — quitter sans enregistrer',
      body = 'Ferme la fenêtre et abandonne les modifications sans demander de confirmation\nÉquivalent à :q!, mais plus rapide à saisir',
      example = 'ZZ → enregistrer et quitter ; ZQ → quitter sans enregistrer les modifications',
    },
    ['q:'] = {
      title = 'q: — ouvrir la fenêtre de commande',
      body = 'Ouvre un tampon contenant l’historique des commandes Ex\nVous pouvez modifier et réexécuter n’importe quelle commande précédente avec Entrée',
      example = 'q → enregistrer une macro ; q: → parcourir et modifier l’historique des commandes',
    },
    ['|'] = {
      title = '| — aller à la colonne N',
      body = 'Déplace le curseur jusqu’à la colonne N de la ligne courante\nUtile pour aligner du texte ou atteindre rapidement une colonne précise',
      example = '0 → colonne 1 ; 40| → colonne 40',
    },
    ['_'] = {
      title = '_ — premier caractère non vide de la ligne (relatif)',
      body = 'Déplace le curseur vers le premier caractère non vide de la ligne courante\nAvec un nombre N, descend de N-1 lignes puis va au premier caractère non vide',
      example = '^ → premier caractère non vide ; 3_ → premier caractère non vide deux lignes plus bas',
    },

    -- ── commandes supplémentaires de pli ──────────────────────────────────
    ['zf'] = {
      title = 'zf — créer un pli manuellement',
      body = 'Crée un pli sur un déplacement ou une sélection visuelle (nécessite foldmethod=manual)\nUtilisez zd pour le supprimer ; zf{motion} crée un pli couvrant le déplacement',
      example = 'zfip → plier le paragraphe courant ; zd → supprimer ce pli',
    },

    -- ── macro : exécuter une macro depuis un registre ─────────────────────
    ['@q'] = {
      title = '@q — exécuter la macro du registre q',
      body = 'Rejoue la séquence de frappes enregistrée dans le registre q\nRemplacez q par n’importe quelle lettre de a à z pour utiliser un autre registre',
      example = 'qq → démarrer l’enregistrement ; q → arrêter ; @q → rejouer',
    },

    -- ── marques ───────────────────────────────────────────────────────────
    ["'."] = {
      title = "'. — aller à la position de la dernière modification",
      body = 'Déplace le curseur à l’emplacement exact de la modification la plus récente\nPlus rapide que d’utiliser Ctrl-O à plusieurs reprises lorsque vous souhaitez revenir à votre dernière modification',
      example = "G puis '. → aller à la fin, puis revenir à votre dernière modification",
    },
    ["'^"] = {
      title = "'^ — aller à la dernière position d’insertion",
      body = "Ramène le curseur à l’endroit où vous avez quitté le mode insertion pour la dernière fois\nContrairement à '., cette marque mémorise la sortie du mode insertion et non la dernière modification du texte",
      example = "A puis <Esc> puis '^ → revenir au dernier point d’insertion en fin de ligne",
    },
    ['ma'] = {
      title = 'ma — placer la marque a sous le curseur',
      body = "Place une marque nommée 'a à la position actuelle\nVous pouvez utiliser n’importe quelle lettre de a à z ; retrouvez-la avec 'a (ligne) ou `a (colonne exacte)",
      example = "ma → placer une marque ; G → aller ailleurs ; 'a → revenir à la ligne marquée",
    },
    ["'a"] = {
      title = "'a — aller à la marque a",
      body = "Déplace le curseur vers la ligne où la marque 'a a été placée\nUtilisez `a pour un retour précis à la colonne ; combinez-le avec ma pour créer des points de repère",
      example = "ma → placer une marque ; dd → modifier ailleurs ; 'a → revenir à la ligne marquée",
    },

    -- ── déplacements par mot ──────────────────────────────────────────────
    ['w'] = {
      title = 'w — aller au début du mot suivant',
      body = 'Avance d’un mot à la fois plutôt que caractère par caractère\nBien plus rapide que de répéter l ; utilisez w pour les déplacements rapides et l pour les ajustements précis',
      example = 'w w w → avancer de trois mots',
    },
    ['b'] = {
      title = 'b — aller au début du mot précédent',
      body = 'Recule d’un mot à la fois — le complément de w\nPlus rapide que de répéter h lorsque vous devez revenir de plusieurs mots',
      example = 'b b b → reculer de trois mots',
    },

    -- ── variantes avec compteur ───────────────────────────────────────────
    ['{n}dd'] = {
      title = '{n}dd — supprimer plusieurs lignes à la fois',
      body = 'Ajoutez un compteur avant dd pour supprimer plusieurs lignes en une seule commande\n3dd supprime les trois lignes à partir du curseur sans avoir à répéter dd',
      example = '3dd → supprime 3 lignes en une seule fois',
    },
    ['{n}p'] = {
      title = '{n}p — coller plusieurs fois',
      body = 'Ajoutez un compteur avant p pour coller le même contenu plusieurs fois de suite\n3p colle le texte copié trois fois sans répéter p',
      example = '3p → colle le même contenu trois fois',
    },
    ['{n}P'] = {
      title = '{n}P — coller avant le curseur plusieurs fois',
      body = 'P colle avant le curseur ; ajoutez un compteur pour répéter l’opération\n3P colle le texte copié trois fois au-dessus de la ligne courante',
      example = '3P → colle trois fois avant le curseur',
    },
    ['{n}~'] = {
      title = '{n}~ — inverser la casse de plusieurs caractères',
      body = '~ inverse la casse d’un caractère puis avance ; avec un compteur, plusieurs caractères sont modifiés\n3~ inverse la casse des trois caractères suivants',
      example = '3~ sur "hello" → "HEllo"',
    },

    -- ── diw ───────────────────────────────────────────────────────────────
    ['diw'] = {
      title = 'diw — supprimer le mot courant',
      body = 'Supprime entièrement le mot sous le curseur, quelle que soit sa position dans ce mot\nciw modifie le mot ; diw le supprime sans passer par une sélection visuelle',
      example = 'he|llo → diw → le mot est supprimé, le curseur reste en place',
    },

    -- ── yyp ───────────────────────────────────────────────────────────────
    ['yyp'] = {
      title = 'yyp — dupliquer la ligne courante',
      body = 'Copie toute la ligne puis la colle en dessous — la méthode classique pour dupliquer une ligne\nFaire yy puis p produit le même résultat, mais considérer cela comme yyp représente une seule action',
      example = 'yyp sur "local x = 1" → la ligne est dupliquée en dessous',
    },

    -- ── {n}. ──────────────────────────────────────────────────────────────
    ['{n}.'] = {
      title = '{n}. — répéter la dernière modification N fois',
      body = 'Ajoutez un compteur avant . pour répéter la dernière modification plusieurs fois en une seule commande\n3. répète trois fois au lieu d’appuyer trois fois sur .',
      example = '3. → répète la dernière modification trois fois',
    },

    -- ── {n}J ──────────────────────────────────────────────────────────────
    ['{n}J'] = {
      title = '{n}J — fusionner plusieurs lignes à la fois',
      body = 'Ajoutez un compteur avant J pour fusionner plusieurs lignes en une seule commande\n3J fusionne la ligne courante avec les deux lignes suivantes, sans avoir à appuyer plusieurs fois sur J',
      example = '3J → fusionne la ligne courante avec les 2 lignes suivantes',
    },

    -- ── {n}>> / {n}<< ─────────────────────────────────────────────────────
    ['{n}>>'] = {
      title = '{n}>> — indenter plusieurs lignes à la fois',
      body = 'Ajoutez un compteur avant >> pour indenter plusieurs lignes en une seule commande\n3>> indente 3 lignes à partir du curseur, plus rapidement que de répéter >>',
      example = '3>> → indente 3 lignes en une seule fois',
    },
    ['{n}<<'] = {
      title = '{n}<< — désindenter plusieurs lignes à la fois',
      body = 'Ajoutez un compteur avant << pour désindenter plusieurs lignes en une seule commande\n3<< supprime un niveau d’indentation sur les 3 lignes à partir du curseur',
      example = '3<< → désindente 3 lignes en une seule fois',
    },
  },
}
