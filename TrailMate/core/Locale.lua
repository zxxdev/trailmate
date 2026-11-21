-- Strings shown to the player. Keys are the English text; esES overrides.
-- Missing keys fall back to the key itself. Pure Lua 5.1.

local _, ns = ...

local esES = {
  ["Turn in: "] = "Entregar: ",
  ["Do: "] = "Hacer: ",
  ["Quest log"] = "Diario de misiones",
  ["Needs level %d"] = "Necesita nivel %d",
  ["Not available yet"] = "Aún no disponible",
  ["Tracking: you chose to skip it"] = "Rastreo: elegiste saltártelo",
  ["Not enough gold after your reserve"] = "No llega el oro sin tocar tu reserva",
  ["Useful now and affordable"] = "Útil ya y te lo puedes permitir",
  ["On your keep list"] = "Está en tu lista de guardar",
  ["Quest item"] = "Objeto de misión",
  ["Junk"] = "Basura",
  ["No vendor value"] = "No se puede vender",
  ["Consumable"] = "Consumible",
  ["Unbound green or better: usually worth more at the auction house"] =
    "Verde o mejor sin ligar: suele valer más en la subasta",
  ["Lower item level than what you wear (rough guide)"] = "Menor nivel de objeto que lo que llevas (orientativo)",
  ["Possible upgrade: check it"] = "Puede ser una mejora: míralo",
  ["Trade goods sell well at the auction house"] = "Los materiales se venden bien en la subasta",
  ["No rule for this item: your call"] = "Sin regla para este objeto: tú decides",
  ["Class %s, level %s"] = "Clase %s, nivel %s",
  ["XP %d%%"] = "Experiencia %d%%",
  ["Gold %s"] = "Oro %s",
  ["Map %d at %s, %s"] = "Mapa %d en %s, %s",
  ["Quests in log: %d"] = "Misiones en el diario: %d",
  ["Bag slots free: %d of %d"] = "Huecos libres: %d de %d",
  ["learn"] = "aprende",
  ["skip"] = "sáltalo",
  ["later"] = "más tarde",
  ["sell"] = "vende",
  ["keep"] = "guarda",
  ["auction"] = "subasta",
  ["Trainer advice"] = "Consejo del instructor",
  ["Total to learn now: %s"] = "Total por aprender ahora: %s",
  ["Nothing new to learn here."] = "Nada nuevo que aprender aquí.",
  ["Vendor advice"] = "Consejo para el vendedor",
  ["Sell for about %s: %s"] = "Vende por unos %s: %s",
  ["Nothing to sell."] = "Nada que vender.",
  ["Worth taking to the auction house: %s"] = "Para la subasta: %s",
  ["Bags almost full (%d free): time to go back to a vendor."] =
    "Bolsas casi llenas (%d libres): toca volver a vender.",
  ["Plan finished."] = "Plan terminado.",
  ["No plan loaded. Type /tm questlog to build one from your quest log."] =
    "No hay plan. Escribe /tm diario para crear uno con tu diario de misiones.",
  ["Your quest log is empty."] = "Tu diario de misiones está vacío.",
  ["Plan loaded: %s (%d steps)."] = "Plan cargado: %s (%d pasos).",
  ["Plan rejected: %s"] = "Plan rechazado: %s",
  ["Skipped: %s"] = "Saltado: %s",
  ["%s does not offer \"%s\" now: skipped (/tm undo brings it back)."] =
    "%s no ofrece «%s» ahora: lo salto (/tm deshaz lo recupera).",
  ["Left out, you can no longer pick them up: %s."] = "Fuera de la guía, porque ya no puedes cogerlas: %s.",
  ["Nothing left to do in this guide."] = "En esta guía ya no te queda nada por hacer.",
  ["Marked as done: %s"] = "Marcado como hecho: %s",
  ["Undone."] = "Deshecho.",
  ["Nothing to undo."] = "Nada que deshacer.",
  ["Undone: %s"] = "Deshecho: %s",
  ["Guide: %s"] = "Guía: %s",
  ["Route: %s"] = "Ruta: %s",
  ["%d of %d done"] = "%d de %d hechos",
  ["Step %d of %d"] = "Paso %d de %d",
  ["Arrow: %s"] = "Flecha: %s",
  ["no arrow available"] = "sin flecha disponible",
  ["Tracking spells: %s"] = "Rastreos: %s",
  ["Reserve set to %s."] = "Reserva fijada en %s.",
  ["Commands"] = "Órdenes",
  ["Pick up: "] = "Coger: ",
  ["Travel"] = "Viaje",
  ["Skip"] = "Saltar",
  ["%d talent point(s)"] = "%d punto(s) de talento",
  ["Level %d: new spells are usually waiting at your class trainer."] =
    "Nivel %d: seguramente te esperan hechizos nuevos en tu instructor.",
  ["Visit your trainer once and TrailMate will remember where it is."] =
    "Visita tu instructor una vez y TrailMate recordará dónde está.",
  ["You have %d unspent talent point(s)."] = "Tienes %d punto(s) de talento sin gastar.",
  ["Self-test"] = "Autotest",
  ["Self-test started (nothing is changed)."] = "Autotest en marcha (no cambia nada).",
  ["Self-test done: %d passed, %d failed. Copy the Log tab and send it."] =
    "Autotest terminado: %d bien, %d mal. Copia la pestaña Registro y envíala.",
  ["Back to the quests: /tm plan"] = "Volver a las misiones: /tm plan",
  ["Back to the guide"] = "Volver a la guía",
  ["Back to the route"] = "Volver a la ruta",
  ["Your marked quest"] = "Tu misión marcada",
  ["Next in the guide - %s"] = "Siguiente en la guía - %s",
  ["Guide paused"] = "Guía en pausa",
  ["Route paused"] = "Ruta en pausa",
  ["Arrow on the quest you marked: %s. The guide waits."] =
    "Flecha a la misión que has marcado: %s. La guía te espera.",
  ["Your marked quest is no longer in the log: back to the guide."] =
    "Tu misión marcada ya no está en el diario: vuelves a la guía.",
  ["Version %s"] = "Versión %s",
  ["Leveling coach: a route that decides, an arrow, trainer and vendor advice. Advises, never plays."] =
    "Entrenador para subir de nivel: una ruta que decide, una flecha y consejos de instructor y vendedor. "
    .. "Aconseja, nunca juega.",
  ["Open the TrailMate panel"] = "Abrir el panel de TrailMate",
  ["Show or hide the step window"] = "Mostrar u ocultar la ventana de pasos",
  ["Show or hide the minimap button"] = "Mostrar u ocultar el botón del minimapa",
  ["Commands in the chat (/tm help)"] = "Órdenes en el chat (/tm ayuda)",
  ["Tip: /tm opens the panel; click a quest in your tracker and the arrow follows it."] =
    "Consejo: /tm abre el panel; haz clic en una misión del rastreador y la flecha la sigue.",
  ["Find TrailMate in Esc > Options > AddOns."] = "TrailMate está en Esc > Opciones > AddOns.",
  ["TrailMate's page in Esc > Options > AddOns"] = "La página de TrailMate en Esc > Opciones > AddOns",
  ["Route to %s (about %s):"] = "Viaje a %s (unos %s):",
  ["Use your hearthstone (%s)."] = "Usa tu piedra de hogar (%s).",
  ["Fly from %s to %s."] = "Vuela de %s a %s.",
  ["(route not confirmed yet)"] = "(ruta aún sin confirmar)",
  ["(open any flight master once so TrailMate knows your flight points)"] =
    "(abre una vez cualquier maestro de vuelo para que TrailMate sepa tus vuelos)",
  ["%s is on another continent: take a zeppelin or a ship from a capital or port."] =
    "%s está en otro continente: coge un zepelín o un barco desde una capital o un puerto.",
  ["Nearest flight master you know: %s."] = "Maestro de vuelo conocido más cercano: %s.",
  ["Go to the flight master: %s."] = "Ve al maestro de vuelo: %s.",
  ["Walk to %s."] = "Ve andando a %s.",
  ["No quests of yours there yet: pick some up when you arrive."] =
    "Aún no tienes misiones allí: cógelas al llegar.",
  ["Route"] = "Ruta",
  ["Zones"] = "Zonas",
  ["Trainer"] = "Instructor",
  ["Bags"] = "Bolsas",
  ["Log"] = "Registro",
  ["New route"] = "Nueva ruta",
  ["Skip step"] = "Saltar paso",
  ["Done"] = "Hecho",
  ["Undo"] = "Deshacer",
  ["Back to plan"] = "Volver al plan",
  ["Clear route"] = "Quitar ruta",
  ["Zones that suit your level. Pick one, or let TrailMate choose."] =
    "Zonas para tu nivel. Elige una o deja que elija TrailMate.",
  ["Automatic"] = "Automático",
  ["Go here"] = "Ir aquí",
  ["Find my trainer"] = "Buscar instructor",
  ["Gold reserve"] = "Reserva de oro",
  ["Set"] = "Fijar",
  ["Learned"] = "Aprendido",
  ["Ignore"] = "Ignorar",
  ["Find vendor"] = "Buscar vendedor",
  ["Find repairs"] = "Buscar reparación",
  ["Find flight master"] = "Buscar vuelo",
  ["Character"] = "Personaje",
  ["Diagnostics"] = "Diagnóstico",
  ["Select all"] = "Seleccionar todo",
  ["Clear log"] = "Vaciar registro",
  ["Select all, then Ctrl+C to copy it and send it to the developer."] =
    "Selecciona todo y pulsa Ctrl+C para copiarlo y enviarlo.",
  ["Open your trainer to see the advice here."] = "Abre tu instructor para ver aquí el consejo.",
  ["Left click: panel"] = "Clic izquierdo: panel",
  ["Right click: show or hide the steps"] = "Clic derecho: mostrar u ocultar los pasos",
  ["Drag: move this button"] = "Arrastrar: mover este botón",
  ["%d quests in your log"] = "%d misiones en tu diario",
  ["easy"] = "fácil",
  ["normal"] = "normal",
  ["hard"] = "desafiante",
  ["Strategy for level %d:"] = "Estrategia para nivel %d:",
  ["This zone is too easy for you now: time to move on."] = "Esta zona ya se te queda corta: toca cambiar.",
  ["Coming up: %s"] = "Próximamente: %s",
  ["Want another zone? /tm zone <number>. Back to automatic: /tm zone auto."] =
    "¿Otra zona? /tm zona <número>. Volver a lo automático: /tm zona auto.",
  ["Zone levels are the classic ones, not yet confirmed in Forever."] =
    "Los niveles de zona son los de Classic, aún sin confirmar en Forever.",
  ["Zone choice back to automatic."] = "La zona vuelve a elegirse sola.",
  ["Type /tm strategy first, then /tm zone <number>."] = "Escribe antes /tm estrategia y luego /tm zona <número>.",
  ["Next zone: %s."] = "Siguiente zona: %s.",
  ["Travel to %s"] = "Viaja a %s",
  ["Almost level %d: your trainer will have %s."] = "Casi nivel %d: tu instructor tendrá %s.",
  ["Best zones for your level, with difficulty"] = "Mejores zonas para tu nivel, con su dificultad",
  ["Choose the zone to level in, or let TrailMate choose"] = "Elige la zona donde subir, o deja que elija TrailMate",
  ["TrailMate has not seen one yet. Visit one and it will remember it."] =
    "TrailMate aún no ha visto ninguno. Visita uno y lo recordará.",
  ["Trainer: %s"] = "Instructor: %s",
  ["Vendor: %s"] = "Vendedor: %s",
  ["Repairs: %s"] = "Reparaciones: %s",
  ["Flight master: %s"] = "Maestro de vuelo: %s",
  ["Type /tm find trainer and the arrow takes you there."] = "Escribe /tm buscar instructor y la flecha te lleva.",
  ["Nearest vendor you know: %s. Type /tm find vendor."] =
    "Vendedor conocido más cercano: %s. Escribe /tm buscar vendedor.",
  ["Arrow to the nearest one TrailMate has seen"] = "Flecha al más cercano que TrailMate haya visto",
  ["Arrow back to the plan"] = "La flecha vuelve al plan",
  ["Route: %s, %d steps."] = "Ruta: %s, %d pasos.",
  ["Not now: %s"] = "Ahora no: %s",
  ["Consider abandoning: %s"] = "Plantéate abandonar: %s",
  ["Later: %s"] = "Después: %s",
  ["Nothing worth doing in your quest log right now."] = "Ahora mismo no hay nada que merezca la pena en tu diario.",
  ["Unknown place"] = "Lugar desconocido",
  ["Too hard for now (level %s)"] = "Demasiado difícil por ahora (nivel %s)",
  ["Group or elite quest"] = "Misión de grupo o élite",
  ["Gives little XP now (level %s)"] = "Ya da poca experiencia (nivel %s)",
  ["Hard (level %s): be careful or bring help"] = "Difícil (nivel %s): con cuidado o con ayuda",
  ["You chose to ignore it"] = "Elegiste ignorarlo",
  ["In %s"] = "En %s",
  ["Position unknown here"] = "Aquí no se conoce la posición",
  ["You are there"] = "Has llegado",
  ["Not interested in one? /tm ignore <number>. Already learned? /tm learned <number>."] =
    "¿Alguno no te interesa? /tm ignorar <número>. ¿Ya lo tienes? /tm aprendido <número>.",
  ["Which one? Use the number from the trainer list or the spell name."] =
    "¿Cuál? Usa el número de la lista del instructor o el nombre del hechizo.",
  ["Ignored: %s. It will not be recommended again."] = "Ignorado: %s. No se volverá a recomendar.",
  ["%s will be recommended again."] = "%s se volverá a recomendar.",
  ["Not in your ignored list."] = "No está en tu lista de ignorados.",
  ["Marked as learned: %s"] = "Marcado como aprendido: %s",
  ["Level %d: your trainer now has %s."] = "Nivel %d: tu instructor ya tiene %s.",
  ["Never recommend that spell again (all ranks)"] = "No recomendar más ese hechizo (todos los rangos)",
  ["Stop reminding a spell you already have"] = "Dejar de recordar un hechizo que ya tienes",
  ["Recommend an ignored spell again"] = "Volver a recomendar un hechizo ignorado",
  ["List ignored spells"] = "Lista de hechizos ignorados",
  ["Show or hide the arrow"] = "Muestra u oculta la flecha",
  ["Bring the arrow back to the top or the middle of the screen"] =
    "Trae la flecha arriba en el centro o al centro de la pantalla",
  ["Arrow moved to the top of the screen."] = "Flecha colocada arriba en el centro de la pantalla.",
  ["Arrow moved to the middle of the screen."] = "Flecha colocada en el centro de la pantalla.",
  ["Arrow to the top of the screen"] = "Flecha arriba en el centro",
  ["Arrow to the middle of the screen"] = "Flecha al centro de la pantalla",
  ["Arrow to the top"] = "Flecha arriba",
  ["Arrow to the middle"] = "Flecha al centro",
  ["Rebuild the plan by itself when it ends"] = "Rehacer el plan solo cuando se acaba",
  ["Build a plan from your quest log"] = "Crea un plan con tu diario de misiones",
  ["Skip the current step"] = "Salta el paso actual",
  ["Mark the current step as done"] = "Marca el paso actual como hecho",
  ["Undo the last mark"] = "Deshace la última marca",
  ["Advice at the open trainer"] = "Consejo en el instructor abierto",
  ["What to sell, keep or auction"] = "Qué vender, guardar o subastar",
  ["Character summary"] = "Resumen del personaje",
  ["Skip hunter tracking spells"] = "Saltar los rastreos del cazador",
  ["Gold the trainer advice never spends"] = "Oro que el consejo del instructor nunca gasta",
  ["Show or hide the window"] = "Muestra u oculta la ventana",
  ["Remove the plan"] = "Quita el plan",
  ["What this client exposes (for bug reports)"] = "Qué ofrece este cliente (para informar de fallos)",
  -- Reminders under the window.
  ["Take me"] = "Llévame",
  ["Open"] = "Abrir",
  ["Level %d: new spells at your trainer"] = "Nivel %d: hechizos nuevos en tu instructor",
  ["Talent point: take %s"] = "Punto de talento: coge %s",
  ["%d talent point(s) to spend"] = "%d punto(s) de talento por gastar",
  ["Bags full (%d free): go and sell"] = "Bolsas llenas (%d libres): ve a vender",
  ["Open your talents with the N key (not in combat)."] = "Abre tus talentos con la tecla N (fuera de combate).",
  ["Next talent: %s (%s)."] = "Siguiente talento: %s (%s).",
  ["Open your talents and say the next one"] = "Abre tus talentos y dice cuál toca",
  ["Companion: %s."] = "Compañero: %s.",
  ["Map mark: %s"] = "Marca en el mapa: %s",
  ["Now: %s"] = "Ahora: %s",
  ["Place not known yet"] = "Sitio aún desconocido",
  ["Take the %s from %s to %s."] = "Coge el %s de %s a %s.",
  ["Go to %s."] = "Ve a %s.",
  ["Click the item to use it"] = "Pulsa el objeto para usarlo",
  ["Error"] = "Error",
  ["Walked trails cleared."] = "Rastros borrados.",
  ["Pick up the quests here first"] = "Primero coge las misiones de aquí",
  ["Quest %d"] = "Misión %d",
  ["From %s"] = "Te la da %s",
  ["To %s"] = "Se entrega a %s",
  ["Optional: elite or group quest"] = "Opcional: misión élite o de grupo",
  ["Guide: %s (%d steps). Other guides: /tm guide."] = "Guía: %s (%d pasos). Otras guías: /tm guia.",
  ["Guide finished. Next: %s."] = "Guía terminada. Siguiente: %s.",
  ["Guides off: the plan comes from your quest log."] = "Guías desactivadas: el plan sale de tu diario.",
  ["No guide for your faction yet."] = "Aún no hay guía para tu facción.",
  ["Guides (/tm guide <number>, next, auto, off):"] = "Guías (/tm guia <número>, siguiente, auto, off):",
  ["now"] = "ahora",
  ["Quest guides: list, choose one, or plan from your quest log"] =
    "Guías de misiones: ver, elegir una o planificar desde tu diario",
  ["%s - optional: elite or group quest"] = "%s - opcional: misión élite o de grupo",
  ["New area: talk to the quest givers marked ! around you before heading out. TrailMate remembers them for next "
    .. "time."] = "Zona nueva: habla con los que tienen ! a tu alrededor antes de salir. TrailMate los recordará "
    .. "para la próxima vez.",
  ["Set your hearthstone at %s"] = "Pon la piedra de hogar con %s",
  ["Set your hearthstone at the inn here"] = "Pon la piedra de hogar en la posada de aquí",
  ["You will level here and your hearthstone is in %s."] = "Vas a subir aquí y tu piedra está en %s.",
  ["The world map now shows every dot learned around you. Again to go back to the route."] =
    "El mapa del mundo enseña ahora todos los puntos aprendidos a tu alrededor. Repite la orden para volver a la ruta.",
  ["The world map shows the route again."] = "El mapa del mundo vuelve a enseñar la ruta.",
  ["%d dots around you exported to the Log tab (%d lines). Copy the Log tab and send it."] =
    "%d puntos a tu alrededor exportados a la pestaña Registro (%d líneas). Copia el registro y pásamelo.",
  ["Levelling build"] = "Build de subida",
  ["Beast Mastery up to Bestial Wrath, then Marksmanship up to Trueshot Aura, then Survival."] =
    "Bestias hasta Cólera de las bestias, luego Puntería hasta Aura de disparo certero, luego Supervivencia.",
  ["Points"] = "Puntos",
  ["Number: level the talent is taken at. Bottom: rank it ends at (green: you have it)."] =
    "Número: nivel al que se coge. Abajo: rango final (en verde: ya lo tienes).",
  ["A suggested order, not an official guide: %d of %d talents found in your trees."] =
    "Orden sugerido, no una guía oficial: %d de %d talentos están en tus árboles.",
  ["Trails: %s, %d dots and %d joins learned."] = "Rastros: %s, %d puntos y %d uniones aprendidos.",
  ["on"] = "activados",
  ["off"] = "desactivados",
  ["Learn the ways you walk and follow them (dots on the map)"] =
    "Aprende los caminos que recorres y los sigue (puntitos en el mapa)",
  ["The panel could not be built: type /tm test and send the log."] =
    "No se pudo crear el panel: escribe /tm test y pásame el registro.",
  ["zeppelin"] = "zepelín",
  ["ship"] = "barco",
  ["the zeppelin tower outside Orgrimmar (Durotar)"] = "la torre del zepelín junto a Orgrimmar (Durotar)",
  ["Grom'gol (Stranglethorn Vale)"] = "Grom'gol (Vega de Tuercespina)",
  ["the zeppelin tower outside Undercity (Tirisfal Glades)"] =
    "la torre del zepelín junto a Entrañas (Claros de Tirisfal)",
  ["Open a flight master there once: TrailMate will then use your flights on that continent."] =
    "Abre una vez un maestro de vuelo allí: TrailMate usará después tus vuelos de ese continente.",
  ["the docks of Booty Bay (Stranglethorn Vale)"] = "el muelle de Bahía del Botín (Vega de Tuercespina)",
  ["the docks of Ratchet (The Barrens)"] = "el muelle de Trinquete (Los Baldíos)",
  ["the docks of Menethil Harbor (Wetlands)"] = "el muelle de Puerto de Menethil (Los Humedales)",
  ["the docks of Theramore (Dustwallow Marsh)"] = "el muelle de Theramore (Marjal Revolcafango)",
  ["the docks of Auberdine (Darkshore)"] = "el muelle de Auberdine (Costa Oscura)",
  ["Rut'theran Village (Teldrassil)"] = "Aldea Rut'theran (Teldrassil)",
  ["none"] = "ninguno",
  ["Icon colour of your AI companion"] = "Color del icono según tu compañero de IA",
  ["Do step n of the list now"] = "Haz ahora el paso n de la lista",
  -- Dungeons.
  ["Go to the entrance of %s"] = "Ve a la entrada de %s",
  ["Enemies of level %d-%d: go with a group."] = "Enemigos de nivel %d-%d: ve en grupo.",
  ["Dungeons for your level (/tm dungeon <number> to go):"] =
    "Mazmorras para tu nivel (/tm mazmorra <número> para ir):",
  ["  [%d] %s, enemies %d-%d: %d quests to pick up first%s"] =
    "  [%d] %s, enemigos %d-%d: %d misiones para coger antes%s",
  [", %d start inside"] = ", %d empiezan dentro",
  [", %d later"] = ", %d más adelante",
  ["No dungeon suits your level right now."] = "Ahora mismo no hay mazmorra para tu nivel.",
  ["Next dungeon: %s from level %d."] = "Siguiente mazmorra: %s desde el nivel %d.",
  ["Dungeon: %s. %d quests to pick up before going in."] = "Mazmorra: %s. %d misiones para coger antes de entrar.",
  ["Dungeons by level: list, or plan one (quests first, then the entrance)"] =
    "Mazmorras por nivel: lista, o plan para una (misiones primero y luego la entrada)",
  ["Dungeon finished: back to your guide."] = "Mazmorra terminada: vuelves a tu guía.",
  -- Companion chat.
  ["Companion"] = "Compañero",
  ["The chat could not start: type /tm test and send the Log tab."] =
    "El chat no ha podido arrancar: escribe /tm test y mándame la pestaña Registro.",
  ["You: %s"] = "Tú: %s",
  ["Companion: %s"] = "Compañero: %s",
  ["Your companion answered."] = "Tu compañero te ha contestado.",
  ["That is too long: write less, please."] = "Es demasiado largo: escribe algo más corto, por favor.",
  ["New conversation."] = "Conversación nueva.",
  ["New conversation"] = "Conversación nueva",
  ["Write a question and press Enter."] = "Escribe una pregunta y pulsa Intro.",
  ["Sending to the bridge..."] = "Enviando al puente...",
  ["The bridge does not answer: is trailmate-bridge running on your PC?"] =
    "El puente no contesta: ¿está trailmate-bridge en marcha en tu PC?",
  ["Your companion is thinking..."] = "Tu compañero está pensando...",
  ["Your companion could not answer: %s"] = "Tu compañero no ha podido contestar: %s",
  ["No answer after three minutes. Try again."] = "Sin respuesta en tres minutos. Prueba otra vez.",
  ["In combat: the chat waits."] = "En combate: el chat espera.",
  ["All inboxes used: type /reload to go on."] = "Se han gastado todos los buzones: escribe /reload para seguir.",
  ["No inbox addons: run \"trailmate-bridge init\" and restart the game."] =
    "No hay buzones: ejecuta «trailmate-bridge init» y reinicia el juego.",
  ["The keys the chat uses are taken: type /tm chat diag and send it."] =
    "Las teclas que usa el chat no están libres: escribe /tm chat diag y mándamelo.",
  ["Your key bindings sync with Blizzard, so the game does not save them on this PC. " ..
    "Type /tm chat local to keep them here (back with /tm chat sync)."] =
    "Tus teclas se sincronizan con Blizzard, así que el juego no las guarda en este PC. " ..
    "Escribe /tm chat local para guardarlas aquí (lo deshaces con /tm chat sync).",
  ["Key bindings are kept on this PC now, so the chat can use them. Back to Blizzard's servers: /tm chat sync."] =
    "Ahora tus teclas se guardan en este PC y el chat puede usarlas. Para volver a Blizzard: /tm chat sync.",
  ["Key bindings sync with Blizzard again. The chat needs /tm chat local to work."] =
    "Tus teclas vuelven a sincronizarse con Blizzard. El chat necesita /tm chat local para funcionar.",
  ["Talk to your AI companion (needs trailmate-bridge on your PC)"] =
    "Habla con tu compañero de IA (necesita trailmate-bridge en tu PC)",
  ["Run the self-test and write it to the log"] = "Pasa el autotest y lo escribe en el registro",
  -- Talent plan.
  ["Talent plan"] = "Plan de talentos",
  ["Easiest to level: a strong pet takes the hits, little downtime."] =
    "Lo más fácil para subir: la mascota aguanta los golpes y casi no paras.",
  ["More damage from you, a weaker pet. Good for groups."] =
    "Más daño tuyo y una mascota más floja. Buena en grupo.",
  ["Traps and survival tricks; slower solo, needs more care."] =
    "Trampas y trucos de supervivencia; más lenta en solitario y pide más cuidado.",
  ["No template for this tree: it is filled row by row."] = "Sin plantilla para esta rama: se llena fila a fila.",
  ["Spend your point here (%d to spend)"] = "Gasta tu punto aquí (%d por gastar)",
  ["Your next point goes here"] = "Tu próximo punto irá aquí",
  ["%s - %s, row %d"] = "%s - %s, fila %d",
  ["rank %d/%d"] = "rango %d/%d",
  ["ranks %d-%d/%d"] = "rangos %d-%d/%d",
  ["Open the %s tab to see it lit up."] = "Abre la pestaña %s para verlo iluminado.",
  ["After that"] = "Después",
  ["This tree is complete."] = "Esta rama está completa.",
  ["This client shows no talent trees."] = "Este cliente no muestra árboles de talentos.",
  ["A guide from the classic trees, not checked in Forever: %d of %d names found in yours."] =
    "Guía hecha con los árboles clásicos, sin comprobar en Forever: %d de %d nombres están en el tuyo.",
}

local L = setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

--- Fills ns.L for the given locale ("esES", "enUS", ...).
function ns.setLocale(locale)
  for k in pairs(L) do
    L[k] = nil
  end
  if locale == "esES" or locale == "esMX" then
    for k, v in pairs(esES) do
      L[k] = v
    end
  end
end

ns.L = L

--- Formats copper as "1g 2s 3c".
function ns.formatMoney(copper)
  copper = math.floor(tonumber(copper) or 0)
  local g = math.floor(copper / 10000)
  local s = math.floor(copper / 100) % 100
  local c = copper % 100
  if g > 0 then
    return ("%dg %ds %dc"):format(g, s, c)
  elseif s > 0 then
    return ("%ds %dc"):format(s, c)
  end
  return ("%dc"):format(c)
end
