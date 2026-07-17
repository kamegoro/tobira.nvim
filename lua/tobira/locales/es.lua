return {
  guide = {
    title = 'guía de tobira',
    hint = ':TobiraGuide  alternar guía',
    all_mastered = '¡Todos los comandos de este nivel dominados!',
    pinned = 'Fijado',
    forgotten_suffix = ' (olvidado)',
    more_suffix = '+%d más',
  },
  progress = {
    title = 'tobira — tu viaje en vim',
    level_label = 'Nivel: ',
    levels = {
      novice = 'novato',
      beginner = 'principiante',
      intermediate = 'intermedio',
      advanced = 'avanzado',
    },
    categories = {
      motion = 'Movimiento',
      edit = 'Edición',
      search = 'Búsqueda',
      window = 'Ventana',
      fold = 'Pliegue',
      mark = 'Marca',
      macro = 'Macro',
    },
    mastered_total = '%d / %d dominados',
    section_count = '%d / %d',
    footer = {
      suppress = 'ocultar',
      pin = 'fijar',
      guide = 'guía',
      stats = 'estadísticas',
      close = 'cerrar',
    },
    preview = {
      learning = 'aprendiendo',
      mastered = 'dominado',
      forgotten = 'olvidado',
      never_tried = 'nunca usado',
      to_next = '%d más para llegar a %s',
    },
  },
  notifications = {
    reset = 'tobira: registro de uso reiniciado',
    no_suggestions = 'tobira: no hay sugerencias nuevas por ahora 🎉',
    invalid_config = 'tobira: configuración inválida — ',
  },
  stats = {
    title = 'tobira — estadísticas de uso',
    mastery = 'Dominio',
    mastery_dist = '  Nunca %d  ·  ☆ %d  ·  ★ %d  ·  ★★+ %d',
    top_commands = 'Comandos principales',
    try_next = '⚡ Prueba esto a continuación',
    footer = {
      guide = 'guía',
      progress = 'progreso',
      close = 'cerrar',
    },
    footer_summary = '%s pulsaciones hasta ahora · %s / %s comandos descubiertos',
  },
  float = {
    example_prefix = 'ej. ',
    close_hint = 'q/Esc cerrar',
    suppress_hint = ':TobiraProgress  x para silenciar',
    ambient_reason = 'Usas %s con frecuencia',
    celebrate = 'Bien — usaste %s',
    reasons = {
      insert_bs_repeat = 'Borraste con retroceso 5 veces seguidas en modo inserción',
      insert_left_repeat = 'Pulsaste <Left> 5 veces seguidas en modo inserción',
      insert_right_repeat = 'Pulsaste <Right> 5 veces seguidas en modo inserción',
      insert_bounce = 'Entraste y saliste del modo inserción sin cambios, dos veces seguidas',
      f_repeat = 'Repetiste la misma búsqueda f/t en esta línea',
      r_run = 'Reemplazaste 3 caracteres uno por uno',
      visual_textobj = 'Seleccionaste un objeto de texto en modo visual antes de editar',
      indent_run = 'Sangraste de la misma forma 3 veces seguidas',
      dedent_run = 'Quitaste la sangría de la misma forma 3 veces seguidas',
      c_dollar = 'Cambiaste desde el cursor hasta el final de la línea',
      d_dollar = 'Borraste desde el cursor hasta el final de la línea',
      dd_run = 'Borraste líneas individuales 3 veces seguidas',
      yy_then_p = 'Copiaste una línea y la pegaste justo debajo',
      dd_then_p = 'Borraste una línea y la volviste a pegar debajo',
      dd_then_insert = 'Borraste una línea y empezaste a escribir una nueva',
      zero_then_w = 'Saltaste a la columna 0 y luego avanzaste una palabra',
      zero_then_insert = 'Saltaste al inicio de línea y entraste en modo inserción',
      dollar_then_append = 'Saltaste al final de línea y entraste en modo inserción',
      k_then_o = 'Subiste una línea y abriste una nueva debajo',
      x_then_insert = 'Borraste un carácter y entraste en modo inserción',
      D_then_insert = 'Borraste hasta el final de línea y empezaste a escribir',
      dw_then_insert = 'Borraste una palabra y entraste en modo inserción',
      x_repeat = 'Borraste caracteres uno por uno, 3 veces seguidas',
      u_repeat = 'Deshiciste 3 veces seguidas',
      j_repeat = 'Pulsaste j 5 veces seguidas',
      j_many = 'Pulsaste j 10 veces seguidas',
      k_repeat = 'Pulsaste k 5 veces seguidas',
      k_many = 'Pulsaste k 10 veces seguidas',
      n_repeat = 'Repetiste una coincidencia de búsqueda 4 veces',
      l_repeat = 'Pulsaste l 5 veces seguidas',
      h_repeat = 'Pulsaste h 5 veces seguidas',
      w_repeat = 'Pulsaste w 5 veces seguidas',
      b_repeat = 'Pulsaste b 5 veces seguidas',
      p_repeat = 'Pegaste 3 veces seguidas',
      P_repeat = 'Pegaste antes del cursor 3 veces seguidas',
      tilde_repeat = 'Alternaste mayúsculas/minúsculas 3 veces seguidas',
      dot_repeat = 'Repetiste el último cambio 3 veces seguidas',
      J_repeat = 'Uniste líneas 3 veces seguidas',
    },
  },
  -- Suggestion display strings shown via float popup and :TobiraProgress.
  -- Keys match commands.registry keys exactly.
  suggestions = {
    [';'] = {
      title = '; — repetir el último f / t / F / T',
      body = 'Después de cualquier búsqueda f, t, F o T, ; salta a la siguiente ocurrencia en la misma dirección\n, va en la dirección contraria',
      example = 'fa ;; → siguiente a, luego la siguiente',
    },
    [','] = {
      title = ', — repetir f / t / F / T en reversa',
      body = 'Lo opuesto de ; — repite la última búsqueda f/t/F/T en dirección contraria\nÚtil cuando te pasas con ;',
      example = 'fa ;;; , → retrocede uno',
    },
    ['cw'] = {
      title = 'cw — borrar palabra e insertar',
      body = 'Reemplaza la secuencia dw + i en un solo movimiento\nTe pone en modo inserción justo después de borrar',
      example = 'cw → borra desde el cursor hasta el final de la palabra → modo inserción',
    },
    ['ciw'] = {
      title = 'ciw — cambiar palabra interior',
      body = 'Funciona incluso con el cursor en medio de una palabra\ncw solo borra desde el cursor hacia adelante; ciw reemplaza toda la palabra',
      example = 'hel|lo → ciw → world',
    },
    ['<C-r>'] = {
      title = '<C-r> — rehacer',
      body = '¿Deshiciste de más? <C-r> rehace el último cambio deshecho\nCombina u / <C-r> para navegar el historial de cambios',
      example = 'u u u <C-r> → deshacer 3 veces, rehacer una',
    },
    ['ddp'] = {
      title = 'ddp — intercambiar la línea actual con la siguiente',
      body = 'dd borra la línea, p la pega debajo — ddp intercambia líneas en un solo paso\nNo hace falta navegar entre las dos líneas',
      example = 'ddp → la línea actual baja una posición',
    },
    ['{n}j'] = {
      title = '{n}j — saltar varias líneas a la vez',
      body = 'Antepone un número a cualquier movimiento para repetirlo\n5j baja 5 líneas; también funciona con k, w, b, etc.',
      example = '5j → baja 5 líneas',
    },
    ['^'] = {
      title = '^ — saltar al primer carácter no en blanco',
      body = '0 va a la columna 0; ^ va al primer carácter que no sea espacio en blanco\nNormalmente ^ es lo que realmente quieres',
      example = '    hello → ^ → el cursor cae en h',
    },
    ['cgn'] = {
      title = 'cgn — cambiar la siguiente coincidencia de búsqueda',
      body = 'Después de /, usa cgn para cambiar la siguiente coincidencia\nLuego pulsa . para repetir en cada coincidencia siguiente',
      example = '/word → cgn → new → Esc → . . .',
    },
    ['.'] = {
      title = '. — repetir el último cambio',
      body = 'Repite tu última edición sin volver a entrar en modo inserción\nCombina con n o ; para cambiar varias ocurrencias en una sola pasada',
      example = 'cw foo <Esc> n . → cambia también la siguiente coincidencia',
    },
    ['<C-w>'] = {
      title = '<C-w> — borrar la palabra antes del cursor',
      body = 'Funciona en modo inserción sin salir de él — una sola pulsación en vez de varios <BS>\nSe detiene al inicio de la palabra, así que nunca borra de más',
      example = 'foo bar<C-w> → foo ',
    },
    ['A'] = {
      title = 'A — añadir al final de línea',
      body = '$a en una sola pulsación — va al final de línea y entra en modo inserción\nCombina con I (insertar al inicio) para editar rápido el inicio/final de línea',
      example = 'A; → añade un punto y coma al final de línea',
    },
    ['O'] = {
      title = 'O — abrir una línea nueva arriba',
      body = 'Como o pero abre la línea nueva encima del cursor\nNo hace falta subir primero y luego pulsar o',
      example = 'O → línea nueva en blanco encima del cursor → modo inserción',
    },
    ['D'] = {
      title = 'D — borrar hasta el final de línea',
      body = 'Borra desde el cursor hasta el final de línea (igual que d$)\nTe permite reescribir el resto sin navegar antes hasta allí',
      example = 'D → escribe el nuevo final',
    },
    ['C'] = {
      title = 'C — cambiar hasta el final de línea',
      body = 'D + i en un solo movimiento — borra hasta el final de línea y entra en modo inserción\nComo cw pero para el resto de la línea en vez de una palabra',
      example = 'C → reemplaza todo desde el cursor hasta el final',
    },
    ['gn'] = {
      title = 'gn — seleccionar la siguiente coincidencia de búsqueda',
      body = 'Después de * o /, gn selecciona la siguiente coincidencia en modo visual\nSe usa con c (cgn) y luego . para reemplazar cada ocurrencia',
      example = '* → cgn → texto nuevo → Esc → . . .',
    },
    ['e'] = {
      title = 'e — moverse al final de la palabra',
      body = 'w salta al inicio de la siguiente palabra; e salta a su final\nÚtil cuando necesitas añadir algo al final de una palabra',
      example = 'ea → añade texto después de la palabra actual',
    },
    ['I'] = {
      title = 'I — insertar al inicio de línea',
      body = 'Va al primer carácter no en blanco y entra en modo inserción\nCombina con A (final de línea) para editar rápido los extremos de línea',
      example = 'I// → comenta la línea actual',
    },
    ['H'] = {
      title = 'H — saltar a la parte superior de la pantalla',
      body = 'Mueve el cursor a la parte superior de la ventana visible sin desplazar\nM va al medio, L va abajo',
      example = 'H → el cursor cae en la primera línea visible',
    },
    ['M'] = {
      title = 'M — saltar al medio de la pantalla',
      body = 'Coloca el cursor exactamente en el medio de la ventana visible\nÚtil para reorientarse rápido tras un salto grande',
      example = 'M → el cursor se mueve a la línea del medio',
    },
    ['L'] = {
      title = 'L — saltar a la parte inferior de la pantalla',
      body = 'Mueve el cursor a la última línea visible sin desplazar\nCombina con H y M para navegación relativa a la pantalla',
      example = 'L → el cursor cae en la última línea visible',
    },
    ['{n}x'] = {
      title = '{n}x — borrar varios caracteres a la vez',
      body = 'Antepone un número a x para borrar esa cantidad de caracteres de una vez\nTambién funciona con otros movimientos: 3dw, 2dd, etc.',
      example = '5x → borra 5 caracteres en el cursor',
    },
    ['<C-d>'] = {
      title = '<C-d> — desplazar media página hacia abajo',
      body = 'Mueve la vista y el cursor hacia abajo la mitad de la altura de ventana\nMucho más rápido que pulsar j muchas veces',
      example = '<C-d><C-d> → desplaza una página completa hacia abajo',
    },
    ['<C-u>'] = {
      title = '<C-u> — desplazar media página hacia arriba',
      body = 'El complemento hacia arriba de <C-d>\nCombínalos para navegar archivos grandes con eficiencia',
      example = '<C-d> luego <C-u> → desplaza abajo y vuelve arriba',
    },
    ['{n}k'] = {
      title = '{n}k — saltar varias líneas hacia arriba a la vez',
      body = 'Antepone un número a k para subir varias líneas de una vez\nFunciona con cualquier movimiento: 5k, 3w, 2b, etc.',
      example = '5k → sube 5 líneas',
    },
    ['*'] = {
      title = '* — buscar la palabra bajo el cursor',
      body = 'Coloca la palabra bajo el cursor en el registro de búsqueda y salta a la siguiente coincidencia\nMás rápido que escribir /word<Enter> — no hace falta escribir nada',
      example = 'cursor en "foo" → * → salta al siguiente "foo"',
    },
    ['<C-o>'] = {
      title = '<C-o> — saltar de vuelta a donde estabas',
      body = 'Tras un salto grande (* / G gg /) <C-o> te lleva de vuelta a la posición anterior\n<C-i> avanza de nuevo por la lista de saltos',
      example = '* <C-o> → salta a la coincidencia, luego vuelve al inicio',
    },
    ['P'] = {
      title = 'P — pegar antes del cursor',
      body = 'p pega después del cursor; P pega antes\nPara copias de línea completa: p pega debajo de la línea, P pega encima',
      example = 'yy P → copia la línea actual y pégala encima',
    },

    -- ── f → t stop-before-char chain ─────────────────────────────────────
    ['t'] = {
      title = 't — moverse justo antes de un carácter',
      body = 'Como f pero se detiene un carácter antes del objetivo\nIdeal con operadores: ct; cambia el texto hasta (sin incluir) el siguiente ;',
      example = 'ct; → cambia todo hasta el siguiente punto y coma',
    },
    ['T'] = {
      title = 'T — moverse justo después de un carácter (hacia atrás)',
      body = 'Busca hacia atrás como F pero se detiene justo después del carácter\nSe repite con ; y , como cualquier búsqueda f/t',
      example = 'T, → retrocede hasta justo después de la coma anterior',
    },

    -- ── jumplist bidirectional ─────────────────────────────────────────────
    ['<C-i>'] = {
      title = '<C-i> — avanzar en la lista de saltos',
      body = 'Después de que <C-o> te lleve atrás, <C-i> te lleva de nuevo adelante\nNavega tu historial de edición en ambas direcciones',
      example = '<C-o> <C-o> <C-i> → retrocede dos veces, luego avanza una',
    },

    -- ── full-page scroll chain ─────────────────────────────────────────────
    ['<C-f>'] = {
      title = '<C-f> — desplazar una página completa hacia abajo',
      body = '<C-d> desplaza media página; <C-f> desplaza una página completa\nMás rápido para saltar grandes secciones de un archivo',
      example = '<C-f> → desplaza hacia abajo una altura completa de ventana',
    },
    ['<C-b>'] = {
      title = '<C-b> — desplazar una página completa hacia arriba',
      body = 'El complemento hacia arriba de <C-f>\nCombínalo con <C-f> para recorrer un archivo grande en ambas direcciones',
      example = '<C-f> <C-b> → desplaza una página completa y vuelve',
    },

    -- ── paragraph motions ─────────────────────────────────────────────────
    ['}'] = {
      title = '} — saltar al final del párrafo',
      body = 'Baja hasta la siguiente línea en blanco — salta bloques enteros de una vez\nMás rápido que j al moverse entre funciones o secciones de texto',
      example = '} → el cursor salta a la línea en blanco después del bloque actual',
    },
    ['{'] = {
      title = '{ — saltar al inicio del párrafo',
      body = 'El complemento hacia arriba de } — sube hasta la línea en blanco de arriba\nNavega rápido entre bloques de código o párrafos',
      example = '{ → el cursor salta a la línea en blanco antes del bloque actual',
    },

    -- ── screen centering chain ─────────────────────────────────────────────
    ['zz'] = {
      title = 'zz — centrar la pantalla en el cursor',
      body = 'Desplaza la vista para que la línea del cursor quede en el medio de la ventana\nEl cursor no se mueve — solo cambia el área visible',
      example = 'zz → la línea actual se desplaza al centro de la ventana',
    },
    ['zt'] = {
      title = 'zt — desplazar la línea del cursor a la parte superior',
      body = 'Como zz pero coloca la línea del cursor en la parte superior de la ventana\nzt / zz / zb te dan control de arriba / centro / abajo',
      example = 'zt → la línea actual se desplaza a la parte superior de la ventana',
    },
    ['zb'] = {
      title = 'zb — desplazar la línea del cursor a la parte inferior',
      body = 'Desplaza para que la línea del cursor aparezca en la parte inferior de la ventana\nCombina con zt y zz para posicionar exactamente lo que ves',
      example = 'zb → la línea actual se desplaza a la parte inferior de la ventana',
    },

    -- ── WORD motions ──────────────────────────────────────────────────────
    ['W'] = {
      title = 'W — avanzar por WORD',
      body = 'Como w pero solo se detiene en espacios en blanco, ignorando la puntuación\nÚtil cuando w se detiene demasiado dentro de cosas como "foo.bar(baz)"',
      example = 'W en "foo.bar.baz" → salta sobre todo el token de una vez',
    },
    ['B'] = {
      title = 'B — retroceder por WORD',
      body = 'Como b pero trata el texto conectado por puntuación como un solo WORD\nEl complemento hacia atrás de W',
      example = 'B en "foo.bar.baz" → retrocede sobre todo el token',
    },

    -- ── word-end backward ─────────────────────────────────────────────────
    ['ge'] = {
      title = 'ge — moverse al final de la palabra anterior',
      body = 'e avanza al final de la palabra; ge retrocede al final de la palabra anterior\nÚtil cuando necesitas añadir algo a la palabra detrás del cursor',
      example = 'gea → va al final de la palabra anterior y luego añade texto',
    },

    -- ── bracket matching ──────────────────────────────────────────────────
    ['%'] = {
      title = '% — saltar al paréntesis correspondiente',
      body = 'Salta entre (, [, { y sus correspondientes cierres\nTambién funciona con /* */ y #if/#endif en muchos tipos de archivo',
      example = '% en ( → el cursor salta al ) correspondiente',
    },

    -- ── single-char edit shortcuts ────────────────────────────────────────
    ['r'] = {
      title = 'r — reemplazar un solo carácter',
      body = 'Reemplaza el carácter bajo el cursor sin entrar en modo inserción\nMás rápido que x + i + carácter para arreglar errores de un solo carácter',
      example = 'ra → reemplaza el carácter bajo el cursor por a',
    },
    ['s'] = {
      title = 's — sustituir carácter e insertar',
      body = 'Borra el carácter bajo el cursor y entra inmediatamente en modo inserción\nUna sola pulsación en vez de x + i',
      example = 's → borra el carácter actual → comienza el modo inserción',
    },
    ['cc'] = {
      title = 'cc — cambiar toda la línea actual',
      body = 'Vacía el contenido de la línea y entra en modo inserción en un solo movimiento\nMás rápido que ir al inicio de línea, pulsar D, y luego entrar en modo inserción',
      example = 'cc → la línea se vacía → modo inserción',
    },

    -- ── join lines ───────────────────────────────────────────────────────
    ['J'] = {
      title = 'J — unir la línea siguiente a la actual',
      body = 'Añade la línea de abajo a la línea actual con un solo espacio\nNo hace falta ir al final de línea, borrar el salto de línea y añadir un espacio',
      example = 'J → "foo\\n  bar" se convierte en "foo bar" (la sangría se elimina)',
    },

    -- ── case toggle ───────────────────────────────────────────────────────
    ['~'] = {
      title = '~ — alternar mayúscula/minúscula del carácter bajo el cursor',
      body = 'Convierte minúscula a mayúscula y viceversa, luego avanza un carácter\nAntepone un número: 3~ alterna los siguientes 3 caracteres de una vez',
      example = '~ en "hello" → "Hello" → el cursor avanza',
    },

    -- ── number increment / decrement ──────────────────────────────────────
    ['<C-a>'] = {
      title = '<C-a> — incrementar el número bajo el cursor',
      body = 'Busca el siguiente número en la línea y le suma uno\nAntepone un número para sumar más: 5<C-a> suma 5',
      example = '<C-a> en "padding: 8px" → "padding: 9px"',
    },
    ['<C-x>'] = {
      title = '<C-x> — decrementar el número bajo el cursor',
      body = 'El complemento hacia abajo de <C-a> — resta uno al siguiente número\nÚtil para ajustar valores numéricos sin volver a escribirlos a mano',
      example = '<C-x> en "z-index: 10" → "z-index: 9"',
    },

    -- ── visual mode chain ─────────────────────────────────────────────────
    ['V'] = {
      title = 'V — iniciar selección visual por líneas',
      body = 'Selecciona líneas completas en vez de caracteres individuales\nIdeal para mover, copiar o borrar líneas completas con retroalimentación visual',
      example = 'Vjjd → selecciona 3 líneas visualmente y luego bórralas',
    },
    ['<C-v>'] = {
      title = '<C-v> — iniciar selección visual en bloque (columna)',
      body = 'Selecciona un bloque rectangular a través de varias líneas\nPoderoso para editar columnas alineadas — anteponer texto, cambiar valores en masa',
      example = '<C-v>3jI// <Esc> → antepone // a 4 líneas de una vez',
    },

    -- ── yank text object ──────────────────────────────────────────────────
    ['yiw'] = {
      title = 'yiw — copiar la palabra interior',
      body = 'Copia la palabra completa bajo el cursor sin importar la posición dentro de ella\nCombina con ciw (cambiar) y diw (borrar) para una edición consistente a nivel de palabra',
      example = 'yiw luego muévete a la palabra objetivo y ciw p → reemplaza la palabra',
    },

    -- ── macros ────────────────────────────────────────────────────────────
    ['q'] = {
      title = 'q — grabar una macro',
      body = 'q{a} empieza a grabar en el registro a; pulsa q de nuevo para detener\n@{a} la reproduce; @@ repite la última macro — automatiza ediciones repetitivas',
      example = 'qaIhello<Esc>q luego @a → inserta "hello" al inicio de línea al reproducir',
    },

    -- ── backward search pair ──────────────────────────────────────────────
    ['N'] = {
      title = 'N — saltar a la coincidencia de búsqueda anterior',
      body = 'n salta adelante a la siguiente coincidencia; N salta atrás a la anterior\nCambia de dirección en cualquier momento sin reescribir el patrón de búsqueda',
      example = '/foo → nnn N → adelante 3 coincidencias y luego una atrás',
    },
    ['#'] = {
      title = '# — buscar hacia atrás la palabra bajo el cursor',
      body = '* busca hacia adelante la palabra bajo el cursor; # busca hacia atrás\nLocaliza al instante todas las ocurrencias sin escribir el término de búsqueda',
      example = 'cursor en "foo" → # → salta a la ocurrencia anterior de "foo"',
    },

    -- ── G → gg ───────────────────────────────────────────────────────────
    ['gg'] = {
      title = 'gg — saltar a la primera línea del archivo',
      body = 'G salta al final del archivo; gg salta al inicio\nAntepone un número: 5gg salta directamente a la línea 5',
      example = 'gg → el cursor cae en la línea 1',
    },

    -- ── wrapped-line movement ─────────────────────────────────────────────
    ['gj'] = {
      title = 'gj — bajar una línea visual (de pantalla)',
      body = 'Cuando las líneas se ajustan, j salta toda la línea ajustada; gj se mueve una línea de pantalla\nEsencial para editar prosa larga o markdown con ajuste de línea activado',
      example = 'gj en un párrafo ajustado → el cursor se mueve a la siguiente fila de pantalla',
    },
    ['gk'] = {
      title = 'gk — subir una línea visual (de pantalla)',
      body = 'El complemento hacia arriba de gj — sube una línea de pantalla cuando las líneas se ajustan\nCombina gj / gk para un movimiento natural por texto ajustado',
      example = 'gk en un párrafo ajustado → el cursor se mueve a la fila de pantalla anterior',
    },

    -- ── line-by-line scrolling ────────────────────────────────────────────
    ['<C-e>'] = {
      title = '<C-e> — desplazar la ventana una línea hacia arriba sin mover el cursor',
      body = 'Desplaza el área visible una línea hacia arriba; el cursor permanece en la misma línea\nCombina con <C-y> para ajustar la vista sin perder tu posición de edición',
      example = '<C-e><C-e> → el texto se desplaza 2 líneas hacia arriba; el cursor no se mueve',
    },
    ['<C-y>'] = {
      title = '<C-y> — desplazar la ventana una línea hacia abajo sin mover el cursor',
      body = 'El complemento hacia abajo de <C-e> — revela una línea más arriba\nAjusta el área visible sin mover tu posición de edición',
      example = '<C-y> → una línea más se desplaza a la vista en la parte superior',
    },

    -- ── change list navigation ────────────────────────────────────────────
    ['g;'] = {
      title = 'g; — saltar a una posición anterior en la lista de cambios',
      body = 'Cada edición que haces se añade a la lista de cambios; g; recorre hacia atrás por ella\nDistinto de la lista de saltos — solo posiciones donde realmente se cambió texto',
      example = 'g; g; → retrocede a los dos últimos lugares que editaste',
    },
    ['g,'] = {
      title = 'g, — saltar a una posición más reciente en la lista de cambios',
      body = 'Después de que g; te lleve atrás en la lista de cambios, g, te lleva de nuevo adelante\nNavega tu historial de edición en ambas direcciones sin salir del archivo',
      example = 'g; g, → retrocede a la última edición, luego avanza de nuevo',
    },

    -- ── return to last insert / alternate file / last jump ────────────────
    ['gi'] = {
      title = 'gi — ir a la última posición de inserción y entrar en modo inserción',
      body = 'Devuelve el cursor a donde dejaste el modo inserción por última vez y vuelve a entrar de inmediato\nEvita navegar manualmente de vuelta tras leer otra parte del archivo',
      example = 'gi → el cursor salta a donde dejaste de escribir → modo inserción',
    },
    ['<C-^>'] = {
      title = '<C-^> — cambiar al archivo alterno (editado previamente)',
      body = 'Alterna entre el archivo actual y el último que tenías abierto\nLa forma más rápida de alternar entre dos archivos en los que trabajas activamente',
      example = '<C-^> → abre el último archivo → <C-^> → vuelve al primero',
    },
    ["''"] = {
      title = "'' — saltar de vuelta a la línea del salto anterior",
      body = "Un regreso rápido a la línea en la que estabas antes de la última navegación grande\n'' usa precisión de línea; `` (comillas invertidas) también restaura la columna exacta",
      example = "G '' → salta al final del archivo, luego vuelve a la línea original",
    },

    -- ── definition / file under cursor ────────────────────────────────────
    ['gd'] = {
      title = 'gd — ir a la definición local',
      body = 'Busca en el ámbito de la función actual la primera declaración de la palabra bajo el cursor\nMás rápido que hacer grep — no hace falta salir del archivo ni escribir un patrón de búsqueda',
      example = 'cursor en "myVar" → gd → salta a donde se declara myVar por primera vez',
    },
    ['gf'] = {
      title = 'gf — editar el archivo cuyo nombre está bajo el cursor',
      body = 'Abre el nombre de archivo bajo el cursor como un nuevo búfer en la ventana actual\nFunciona con rutas relativas, absolutas y nombres de archivo dentro de cadenas',
      example = 'cursor en "utils/helpers.lua" → gf → abre ese archivo',
    },

    -- ── reselect last visual ──────────────────────────────────────────────
    ['gv'] = {
      title = 'gv — reseleccionar la selección visual anterior',
      body = 'Reactiva exactamente la misma selección visual de la última vez que se usó el modo visual\nAhorra tiempo cuando necesitas aplicar una segunda operación a la misma región',
      example = 'vip y gv d → copia un párrafo, luego reselecciónalo y bórralo',
    },

    -- ── WORD-end backward ─────────────────────────────────────────────────
    ['gE'] = {
      title = 'gE — moverse al final del WORD anterior',
      body = 'ge se mueve al final de la palabra anterior; gE hace lo mismo pero salta toda la puntuación\nEl complemento a nivel WORD de ge — salta "foo.bar.baz" como un solo token',
      example = 'gE en foo.bar → salta al final del WORD anterior',
    },

    -- ── fold commands ─────────────────────────────────────────────────────
    ['za'] = {
      title = 'za — alternar el pliegue en el cursor',
      body = 'Abre un pliegue cerrado o cierra uno abierto bajo el cursor\nEl comando de pliegue más conveniente — una tecla para ver u ocultar una sección',
      example = 'za → despliega el bloque colapsado; za de nuevo → lo vuelve a plegar',
    },
    ['zo'] = {
      title = 'zo — abrir el pliegue en el cursor',
      body = 'Revela las líneas ocultas dentro de un pliegue sin afectar pliegues abiertos cercanos\nA diferencia de za, zo solo abre — nunca cierra accidentalmente un pliegue ya abierto',
      example = 'zo → las líneas ocultas dentro del pliegue se vuelven visibles',
    },
    ['zc'] = {
      title = 'zc — cerrar el pliegue en el cursor',
      body = 'Colapsa un pliegue abierto en una sola línea de resumen\nLo inverso de zo — solo cierra, nunca abre accidentalmente',
      example = 'zc → el bloque expandido colapsa a una línea de resumen',
    },
    ['zM'] = {
      title = 'zM — cerrar todos los pliegues del búfer',
      body = 'Colapsa todos los pliegues del archivo de una vez — ofrece una vista de esquema completa\nÚtil para navegar un archivo grande por estructura antes de entrar en una sección',
      example = 'zM → todas las funciones colapsan → solo se ve la estructura de alto nivel',
    },
    ['zR'] = {
      title = 'zR — abrir todos los pliegues del búfer',
      body = 'Expande todos los pliegues del archivo — lo inverso de zM\nRestaura la vista totalmente desplegada tras explorar con navegación de pliegues',
      example = 'zM zR → colapsa todos los pliegues, luego expande todo de nuevo',
    },

    -- ── delete before / replace mode / yank to EOL ────────────────────────
    ['X'] = {
      title = 'X — borrar el carácter antes del cursor',
      body = 'Borra un carácter a la izquierda del cursor sin entrar en modo inserción\nComo pulsar Retroceso mientras se permanece en modo normal',
      example = 'X → se elimina el carácter inmediatamente a la izquierda del cursor',
    },
    ['R'] = {
      title = 'R — entrar en modo reemplazo',
      body = 'Sobrescribe el texto existente carácter por carácter mientras escribes — sin insertar ni desplazar\nIdeal para reemplazar una sección de ancho fijo manteniendo intacto el texto circundante',
      example = 'Rhello → sobrescribe los siguientes 5 caracteres con "hello"',
    },
    ['Y'] = {
      title = 'Y — copiar desde el cursor hasta el final de línea',
      body = 'Copia el texto desde la posición del cursor hasta el final de línea (igual que y$)\nComplementa D (borrar hasta el final) y C (cambiar hasta el final) para operaciones consistentes de fin de línea',
      example = 'Y p → copia el resto de la línea y luego pégalo debajo',
    },

    -- ── indent operators ──────────────────────────────────────────────────
    ['>>'] = {
      title = '>> — sangrar la línea actual',
      body = 'Desplaza la línea actual un nivel de sangría a la derecha\nAntepone un número: 3>> sangra las siguientes 3 líneas a la vez',
      example = '>> → la línea actual se sangra un nivel',
    },
    ['<<'] = {
      title = '<< — quitar sangría a la línea actual',
      body = 'Desplaza la línea actual un nivel de sangría a la izquierda\nLo inverso de >> — úsalo para corregir código con exceso de sangría',
      example = '<< → la línea actual pierde un nivel de sangría',
    },
    ['=='] = {
      title = '== — autoindentar la línea actual',
      body = 'Ejecuta el indentador incorporado en la línea actual según las reglas del tipo de archivo\nMás rápido que corregir manualmente con >> o << cuando la sangría es compleja',
      example = '== → la línea encaja automáticamente en el nivel de sangría correcto',
    },

    -- ── case operators ────────────────────────────────────────────────────
    ['gu'] = {
      title = 'gu{motion} — poner en minúsculas una región',
      body = 'Aplica minúsculas al texto cubierto por el movimiento\nguiw → pone en minúsculas la palabra actual; gu$ → minúsculas hasta el final de línea',
      example = 'guiw → "Hello" se convierte en "hello"',
    },
    ['gU'] = {
      title = 'gU{motion} — poner en mayúsculas una región',
      body = 'El complemento en mayúsculas de gu — convierte el texto del movimiento en MAYÚSCULAS\ngUiw → pone en mayúsculas la palabra interior',
      example = 'gUiw → "hello" se convierte en "HELLO"',
    },
    ['g~'] = {
      title = 'g~{motion} — invertir mayúsculas/minúsculas de una región',
      body = 'Invierte las mayúsculas/minúsculas de cada carácter en el movimiento — mayúsculas a minúsculas y viceversa\nComo aplicar ~ a todo un movimiento en vez de a un solo carácter',
      example = 'g~iw → "Hello World" se convierte en "hELLO wORLD"',
    },

    -- ── format text ───────────────────────────────────────────────────────
    ['gq'] = {
      title = 'gq{motion} — reformatear texto para ajustarse al ancho de línea',
      body = 'Reformatea el texto cubierto por el movimiento para ajustarse a textwidth\ngqip formatea el párrafo actual; gqq formatea la línea actual',
      example = 'gqip → el párrafo actual se reajusta al ancho de línea configurado',
    },

    -- ── join without space ────────────────────────────────────────────────
    ['gJ'] = {
      title = 'gJ — unir líneas sin insertar espacio',
      body = 'Como J pero sin añadir un espacio entre las líneas unidas\nÚtil para unir líneas donde un espacio extra rompería la sintaxis',
      example = 'gJ → "foo\\n  bar" se convierte en "foobar" (sin espacio insertado)',
    },

    -- ── repeat last macro ─────────────────────────────────────────────────
    ['@@'] = {
      title = '@@ — repetir la última macro reproducida',
      body = 'Reproduce de nuevo la macro que se ejecutó más recientemente con @{reg}\nAhorra escribir el nombre del registro de nuevo al iterar con la misma macro',
      example = '@a → ejecuta la macro a; @@ → ejecuta la macro a de nuevo sin especificar "a"',
    },

    -- ── text object chain ─────────────────────────────────────────────────
    ['ci"'] = {
      title = 'ci" — cambiar cadena entre comillas dobles interior',
      body = 'Borra el contenido entre las comillas dobles más cercanas y entra en modo inserción\nEl objeto de texto i" funciona con cualquier operador: c, d, y, v',
      example = 'en "hello world" → ci" → el contenido se borra → escribe el reemplazo',
    },
    ["ci'"] = {
      title = "ci' — cambiar cadena entre comillas simples interior",
      body = 'Como ci" pero apunta a comillas simples en vez de dobles\nFunciona donde sea que el cursor esté dentro de un par de comillas simples',
      example = "en 'hello' → ci' → el contenido se borra → escribe el reemplazo",
    },
    ['cib'] = {
      title = 'cib — cambiar bloque de paréntesis interior',
      body = 'Borra el contenido dentro de los () más cercanos y entra en modo inserción\nib es el objeto de texto de "bloque interior" — igual que i( — funciona dentro de llamadas a función',
      example = 'en foo(bar, baz) → cib → borra "bar, baz" → escribe nuevos argumentos',
    },
    ['ciB'] = {
      title = 'ciB — cambiar bloque de llaves interior',
      body = 'Apunta al contenido dentro del bloque {} más cercano\nB es el objeto de texto de "bloque grande"; útil para vaciar o reescribir el cuerpo de una función',
      example = 'dentro del cuerpo de una función → ciB → borra todo el cuerpo → modo inserción',
    },
    ['cit'] = {
      title = 'cit — cambiar contenido de etiqueta HTML / XML interior',
      body = 'Borra el texto entre la etiqueta de apertura y cierre más cercanas y entra en modo inserción\nit es el objeto de texto de "etiqueta interior" — funciona con cualquier par de etiquetas',
      example = 'en <p>hello</p> → cit → borra "hello" → escribe contenido nuevo',
    },
    ['cip'] = {
      title = 'cip — cambiar párrafo interior',
      body = 'Reemplaza todo el párrafo actual (bloque contiguo de líneas no vacías)\nip selecciona hasta pero sin incluir las líneas en blanco circundantes',
      example = 'cip → todo el párrafo actual se borra → modo inserción',
    },

    -- ── partial word search ───────────────────────────────────────────────
    ['g*'] = {
      title = 'g* — buscar hacia adelante coincidencia parcial de la palabra bajo el cursor',
      body = '* requiere coincidencia de palabra completa; g* también coincide con la palabra como subcadena\nÚtil cuando quieres que "foo" encuentre "foobar", "football" y "foo" por igual',
      example = 'g* en "foo" → coincide con "foo", "foobar", "fooResult"',
    },
    ['g#'] = {
      title = 'g# — buscar hacia atrás coincidencia parcial de la palabra bajo el cursor',
      body = 'El compañero hacia atrás de g* — busca la subcadena subiendo por el archivo\nEncuentra todas las ocurrencias incluyendo coincidencias parciales como g* pero en reversa',
      example = 'g# en "foo" → salta atrás al "foo" o "foobar" anterior',
    },

    -- ── window management ─────────────────────────────────────────────────
    ['<C-w>s'] = {
      title = '<C-w>s — dividir la ventana horizontalmente',
      body = 'Abre una división horizontal para ver dos partes de un archivo simultáneamente\n<C-w>v crea una división vertical lado a lado',
      example = '<C-w>s → dos paneles horizontales; navega en cada uno de forma independiente',
    },
    ['<C-w>v'] = {
      title = '<C-w>v — dividir la ventana verticalmente',
      body = 'Abre una división vertical — dos paneles lado a lado en la misma pestaña\nCombina con <C-w>h y <C-w>l para moverte entre ellos',
      example = '<C-w>v → dos paneles verticales; <C-w>l → mueve al panel derecho',
    },
    ['<C-w>w'] = {
      title = '<C-w>w — pasar a la siguiente ventana',
      body = 'Mueve el foco a la siguiente división del diseño sin especificar dirección\nLa forma más rápida de saltar entre dos paneles',
      example = '<C-w>w → el foco cambia a la siguiente división abierta',
    },
    ['<C-w>h'] = {
      title = '<C-w>h — mover el foco a la ventana de la izquierda',
      body = 'Navegación direccional de ventanas — mueve el foco a la izquierda, como h mueve el cursor a la izquierda\nUsa las variantes h / j / k / l para navegación precisa entre divisiones',
      example = '<C-w>h → el cursor se mueve a la división inmediatamente a la izquierda',
    },
    ['<C-w>j'] = {
      title = '<C-w>j — mover el foco a la ventana de abajo',
      body = 'Mueve el foco hacia abajo a la división debajo de la actual\nFunciona en diseños de división tanto horizontales como mixtos',
      example = '<C-w>j → el cursor se mueve a la división de abajo',
    },
    ['<C-w>k'] = {
      title = '<C-w>k — mover el foco a la ventana de arriba',
      body = 'Mueve el foco hacia arriba a la división encima de la actual\nEl complemento hacia arriba de <C-w>j',
      example = '<C-w>k → el cursor se mueve a la división de arriba',
    },
    ['<C-w>l'] = {
      title = '<C-w>l — mover el foco a la ventana de la derecha',
      body = 'Mueve el foco a la derecha, a la división de la derecha\nCombina con <C-w>h para alternar entre paneles izquierdo y derecho',
      example = '<C-w>l → el cursor se mueve a la división de la derecha',
    },
    ['<C-w>q'] = {
      title = '<C-w>q — cerrar la ventana actual',
      body = 'Cierra la división enfocada; el búfer en sí permanece abierto\nUsa :bd para además borrar el búfer; :qa para cerrar todas las divisiones a la vez',
      example = '<C-w>q → el panel enfocado se cierra; el panel restante se expande para llenar el espacio',
    },
    ['<C-w>='] = {
      title = '<C-w>= — igualar el tamaño de todas las ventanas',
      body = 'Redimensiona todas las divisiones abiertas a ancho y alto iguales\nUn reinicio rápido cuando las divisiones se desequilibran tras un redimensionado manual',
      example = '<C-w>= → todos los paneles vuelven a dimensiones iguales',
    },
    ['$'] = {
      title = '$ — saltar al final de línea',
      body = 'Mueve el cursor al último carácter de la línea actual\nCombina con ^ (primer carácter no en blanco) para navegar rápido los extremos de línea',
      example = '^ → ir al inicio; $ → saltar al final',
    },
    ['g_'] = {
      title = 'g_ — último carácter no en blanco de la línea',
      body = '$ incluye espacios finales; g_ se detiene en el último carácter no en blanco\nMás preciso que $ cuando las líneas tienen espacios finales',
      example = '$ → puede caer en un espacio; g_ → se detiene en el último carácter real',
    },
    ['F'] = {
      title = 'F — buscar carácter hacia atrás',
      body = 'Como f{char} pero busca a la izquierda en vez de a la derecha en la línea actual\n; y , siguen repitiendo la búsqueda',
      example = 'f, → adelante hasta la coma; F, → atrás hasta la coma',
    },
    ['('] = {
      title = '( — saltar al inicio de la oración',
      body = 'Como { para párrafos, ( salta al inicio de la oración actual\nÚtil para navegar prosa, comentarios y documentación',
      example = '{ → inicio de párrafo; ( → inicio de oración',
    },
    [')'] = {
      title = ') — saltar al inicio de la siguiente oración',
      body = 'Mueve el cursor hacia adelante al inicio de la siguiente oración\nCombina con ( para saltar entre oraciones en ambas direcciones',
      example = '( luego ) → avanza y retrocede entre oraciones',
    },
    ['[['] = {
      title = '[[ — función / sección anterior',
      body = 'Salta a la primera línea de la función o límite de sección anterior\nMás rápido que gg + búsqueda al navegar un archivo con muchas funciones',
      example = 'gg → inicio del archivo; [[ → inicio de la función anterior',
    },
    [']]'] = {
      title = ']] — función / sección siguiente',
      body = 'Salta a la primera línea de la función o límite de sección siguiente\nCombina con [[ para saltar entre funciones sin salir del modo normal',
      example = 'G → final del archivo; ]] → inicio de la siguiente función',
    },
    ['[{'] = {
      title = '[{ — saltar a la { que encierra',
      body = 'Salta hacia atrás a la llave de apertura sin emparejar más cercana\nEsencial para llegar rápido al inicio de un bloque, función o estructura',
      example = '% → paréntesis correspondiente; [{ → inicio del bloque envolvente',
    },
    [']}'] = {
      title = ']} — saltar a la } que encierra',
      body = 'Salta hacia adelante a la llave de cierre sin emparejar más cercana\nCombina con [{ para navegar dentro y fuera de bloques anidados',
      example = '[{ → inicio de bloque; ]} → fin de bloque',
    },
    ['[('] = {
      title = '[( — saltar al ( que encierra',
      body = 'Salta hacia atrás al paréntesis de apertura sin emparejar más cercano\nÚtil dentro de llamadas a función largas, condiciones o expresiones multilínea',
      example = '[{ → bloque; [( → paréntesis envolvente',
    },
    ['])'] = {
      title = ']) — saltar al ) que encierra',
      body = 'Salta hacia adelante al paréntesis de cierre sin emparejar más cercano\nCombina con [( para navegar dentro y fuera de paréntesis anidados',
      example = '[( → paréntesis de apertura; ]) → paréntesis de cierre',
    },
    ['g0'] = {
      title = 'g0 — primer carácter de la línea de pantalla',
      body = 'Cuando las líneas se ajustan, 0 va al inicio real de línea; g0 va al inicio de la línea ajustada\nÚtil al editar líneas largas con ajuste activado',
      example = 'gj → siguiente línea visual; g0 → inicio de esa línea visual',
    },
    ['gx'] = {
      title = 'gx — abrir el archivo o URL bajo el cursor',
      body = 'Abre la ruta de archivo o URL bajo el cursor con la aplicación predeterminada del sistema\nFunciona con URLs http/https, rutas de archivo locales y más',
      example = 'gf → edita el archivo en Vim; gx → ábrelo en el navegador o el Finder',
    },
    ['<C-]>'] = {
      title = '<C-]> — saltar a la definición del tag',
      body = 'Sigue el tag (definición de ctags) bajo el cursor hasta su declaración\nRequiere un archivo tags; <C-t> o <C-o> vuelve atrás',
      example = 'gd → definición local; <C-]> → definición de ctags',
    },
    ['K'] = {
      title = 'K — consultar la palabra clave bajo el cursor',
      body = 'Ejecuta el programa de keywordprg (por defecto: man) sobre la palabra bajo el cursor\nEn muchas configuraciones de LSP, K muestra documentación al pasar el cursor',
      example = 'gd → ir a la definición; K → mostrar documentación',
    },
    ['gp'] = {
      title = 'gp — pegar y dejar el cursor después del texto pegado',
      body = 'Como p pero deja el cursor justo después del texto pegado\nÚtil cuando quieres seguir escribiendo justo después de pegar',
      example = 'p → el cursor queda antes del pegado; gp → el cursor se mueve después',
    },
    ['gP'] = {
      title = 'gP — pegar antes y dejar el cursor después',
      body = 'Como P (pegar antes del cursor) pero mueve el cursor justo después del texto pegado\nEl complemento en mayúsculas de gp',
      example = 'P → pega antes, cursor antes; gP → pega antes, cursor después',
    },
    ['@:'] = {
      title = '@: — repetir el último comando de línea de comandos',
      body = 'Repite el comando : ejecutado más recientemente sin volver a escribirlo\nDespués de @: puedes usar @@ para repetirlo de nuevo',
      example = ':s/foo/bar/ luego @: → repite la sustitución',
    },
    ['zj'] = {
      title = 'zj — moverse al inicio del siguiente pliegue',
      body = 'Mueve el cursor hacia abajo al inicio del siguiente pliegue cerrado o abierto\nMás rápido que desplazarse pasando pliegues al navegar un archivo muy plegado',
      example = 'za → alternar pliegue; zj → saltar al siguiente pliegue',
    },
    ['zk'] = {
      title = 'zk — moverse al final del pliegue anterior',
      body = 'Mueve el cursor hacia arriba al final del pliegue anterior\nCombina con zj para saltar entre pliegues en cualquier dirección',
      example = 'zj → siguiente pliegue; zk → pliegue anterior',
    },
    ['zd'] = {
      title = 'zd — borrar el pliegue en el cursor',
      body = 'Elimina la definición del pliegue bajo el cursor sin afectar el texto\nÚtil para limpiar pliegues manuales creados con zf',
      example = 'zc → cerrar pliegue; zd → borrar esa definición de pliegue',
    },
    ['E'] = {
      title = 'E — avanzar al final del WORD',
      body = 'Como e pero salta al final del siguiente WORD (cualquier secuencia sin espacios)\nIgnora los límites de puntuación en los que e se detendría',
      example = 'e → final de palabra; E → final de WORD (salta puntuación)',
    },
    ['U'] = {
      title = 'U — deshacer todos los cambios de la línea actual',
      body = 'Restaura la línea actual a como estaba cuando entraste en ella\nDistinto de u: U deshace todas las ediciones de una línea de una sola vez',
      example = 'u → deshace el último cambio; U → restaura toda la línea',
    },
    ['ZZ'] = {
      title = 'ZZ — guardar y salir',
      body = 'Guarda el archivo y cierra la ventana en una sola pulsación\nEquivalente a :wq pero más rápido de escribir',
      example = ':wq  o  ZZ — mismo resultado, ZZ ahorra dos pulsaciones',
    },
    ['ZQ'] = {
      title = 'ZQ — salir sin guardar',
      body = 'Cierra la ventana y descarta los cambios sin pedir confirmación\nEquivalente a :q! pero más rápido de escribir',
      example = 'ZZ → guarda y sal; ZQ → sal y descarta los cambios',
    },
    ['q:'] = {
      title = 'q: — abrir la ventana de línea de comandos',
      body = 'Abre un búfer con tu historial de comandos Ex\nPuedes editar y volver a ejecutar cualquier comando anterior con Enter',
      example = 'q → grabar macro; q: → explorar y editar el historial de comandos',
    },
    ['|'] = {
      title = '| — moverse a la columna N',
      body = 'Salta el cursor a la columna N en la línea actual\nÚtil para alinear texto o navegar a una posición de columna conocida',
      example = '0 → columna 1; 40| → columna 40',
    },
    ['_'] = {
      title = '_ — primer carácter no en blanco de línea (relativo)',
      body = 'Se mueve al primer carácter no en blanco de la línea actual\nCon un número N, baja N-1 líneas y luego va al primer carácter no en blanco',
      example = '^ → primer no en blanco; 3_ → primer no en blanco 2 líneas abajo',
    },

    -- ── fold: additional commands ─────────────────────────────────────────
    ['zf'] = {
      title = 'zf — crear un pliegue manualmente',
      body = 'Crea un pliegue sobre un movimiento o selección visual (requiere foldmethod=manual)\nUsa zd para borrarlo; zf{motion} pliega lo que cubra el movimiento',
      example = 'zfip → pliega el párrafo actual; zd → borra ese pliegue',
    },

    -- ── macro: play specific register ────────────────────────────────────
    ['@q'] = {
      title = '@q — reproducir macro del registro q',
      body = 'Reproduce la secuencia de pulsaciones grabada en el registro q\nCambia q por cualquier letra a-z para reproducir desde otro registro',
      example = 'qq → empieza a grabar; q → detiene; @q → reproduce',
    },

    -- ── marks ─────────────────────────────────────────────────────────────
    ["'."] = {
      title = "'. — saltar a la última posición de cambio",
      body = 'Mueve el cursor a la posición exacta de la edición más reciente\nMás rápido que usar Ctrl-O repetidamente cuando necesitas volver a tu último cambio',
      example = "G luego '. → salta al final, vuelve a donde editaste por última vez",
    },
    ["'^"] = {
      title = "'^ — saltar a la última posición de inserción",
      body = "Devuelve el cursor a la posición donde dejaste el modo inserción por última vez\nDistinto de '. — rastrea dónde saliste de inserción, no el último cambio de texto",
      example = "A luego <Esc> luego '^ → salta de vuelta al punto de inserción al final de línea",
    },
    ['ma'] = {
      title = 'ma — establecer la marca a en el cursor',
      body = "Establece una marca llamada 'a' en la posición actual\nUsa cualquier letra minúscula a-z; recupérala con 'a (línea) o `a (columna exacta)",
      example = "ma → marca aquí; G → ve a otro lado; 'a → vuelve a la línea marcada",
    },
    ["'a"] = {
      title = "'a — saltar a la marca a",
      body = "Mueve el cursor a la línea donde se estableció la marca 'a'\nUsa el acento grave `a para saltos precisos de columna; combina con ma como ancla de navegación",
      example = "ma → marca; dd → edita en otro lado; 'a → vuelve a la línea marcada",
    },

    -- ── l → w / h → b word motion (detected by l_repeat / h_repeat) ──────────
    ['w'] = {
      title = 'w — moverse al inicio de la siguiente palabra',
      body = 'Salta hacia adelante una palabra a la vez en vez de un carácter a la vez\nMás rápido que pulsar l repetidamente — usa w para moverte por palabra, l para ajustar la posición',
      example = 'w w w → avanza tres palabras',
    },
    ['b'] = {
      title = 'b — moverse al inicio de la palabra anterior',
      body = 'Salta hacia atrás una palabra a la vez — el complemento de w\nMás rápido que pulsar h repetidamente al moverse varias palabras a la izquierda',
      example = 'b b b → retrocede tres palabras',
    },

    -- ── count prefix variants ─────────────────────────────────────────────────
    ['{n}dd'] = {
      title = '{n}dd — borrar varias líneas a la vez',
      body = 'Antepone un número a dd para borrar esa cantidad de líneas en un solo comando\n3dd borra 3 líneas desde el cursor — no hace falta repetir dd',
      example = '3dd → borra 3 líneas de una vez',
    },
    ['{n}p'] = {
      title = '{n}p — pegar varias veces a la vez',
      body = 'Antepone un número a p para pegar el mismo contenido N veces seguidas\n3p pega el texto copiado 3 veces — más rápido que pulsar p repetidamente',
      example = '3p → pega el mismo contenido 3 veces',
    },
    ['{n}P'] = {
      title = '{n}P — pegar antes del cursor varias veces',
      body = 'P pega antes del cursor; antepone un número para repetirlo\n3P pega el texto copiado 3 veces encima de la línea actual',
      example = '3P → pega 3 veces antes del cursor',
    },
    ['{n}~'] = {
      title = '{n}~ — alternar mayúsculas/minúsculas de varios caracteres',
      body = '~ alterna un carácter y avanza; antepone un número para alternar varios a la vez\n3~ alterna los siguientes 3 caracteres — ahorra repetir ~ varias veces',
      example = '3~ en "hello" → "HEllo"',
    },

    -- ── diw (detected by visual_textobj v i w d) ─────────────────────────────
    ['diw'] = {
      title = 'diw — borrar palabra interior',
      body = 'Borra la palabra completa bajo el cursor sin importar dónde esté el cursor dentro de ella\nciw cambia la palabra; diw la borra — no hace falta seleccionar visualmente primero',
      example = 'he|llo → diw → la palabra se borra, el cursor permanece en su lugar',
    },

    -- ── yyp (detected by yy_then_p) ───────────────────────────────────────────
    ['yyp'] = {
      title = 'yyp — duplicar la línea actual',
      body = 'Copia toda la línea y la pega debajo — la forma idiomática de duplicar una línea\nHacer yy y luego p son las mismas pulsaciones, pero pensarlo como yyp lo convierte en una sola intención',
      example = 'yyp en "local x = 1" → duplica esa línea debajo',
    },

    -- ── {n}. (detected by dot_repeat × 3) ────────────────────────────────────
    ['{n}.'] = {
      title = '{n}. — repetir el último cambio N veces',
      body = 'Antepone un número a . para repetir el último cambio esa cantidad de veces de una vez\n3. repite tres veces en un solo comando en vez de pulsar . tres veces por separado',
      example = '3. → repite el último cambio 3 veces',
    },

    -- ── {n}J (detected by J_repeat × 3) ──────────────────────────────────────
    ['{n}J'] = {
      title = '{n}J — unir varias líneas a la vez',
      body = 'Antepone un número a J para unir esa cantidad de líneas en un solo comando\n3J une la línea actual con las dos líneas siguientes — no hace falta pulsar J repetidamente',
      example = '3J → une la línea actual con las 2 líneas siguientes',
    },

    -- ── {n}>> / {n}<< (detected by indent_run / dedent_run × 3) ─────────────
    ['{n}>>'] = {
      title = '{n}>> — sangrar varias líneas a la vez',
      body = 'Antepone un número a >> para sangrar esa cantidad de líneas en un solo comando\n3>> sangra 3 líneas desde el cursor — más rápido que pulsar >> repetidamente',
      example = '3>> → sangra 3 líneas a la vez',
    },
    ['{n}<<'] = {
      title = '{n}<< — quitar sangría a varias líneas a la vez',
      body = 'Antepone un número a << para quitar la sangría a esa cantidad de líneas en un solo comando\n3<< quita un nivel de sangría de 3 líneas desde el cursor',
      example = '3<< → quita la sangría de 3 líneas a la vez',
    },
  },
}
