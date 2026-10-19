# Idle Dungeon v0.6 — передача Codex / Claude

Канонический репозиторий `/workspace/Testapp`, GitHub `ar4ick0012-glitch/Testapp`, main. Работать только над игрой и её helper/output-папками, не трогать чужие проекты и не удалять сохранения. Старая `/workspace/projects/idle-dungeon` — v0.3, не рабочая копия. Изолированная среда уже есть, новый worktree не нужен. Пользователь разрешил публикацию в этот GitHub; рабочая доставка ZIP через GitHub, локальные artifact/sandbox ссылки у пользователя не скачиваются.

## Выполнено в v0.6

Пользователь после проверкиv0.5 попросил ещё одну версию со всеми накопленными замечаниями. План `docs/NEXT_BUILD.md` теперь реализован; его старые формулировки про будущую сборку не считать новым незавершённым поручением.

- Убран training/нулевой данж из данных, открытия и runtime. Старт сразуcrypt, пустой отряд, все1уровня, слабый надетый комплект. `starter_item`=обычная базаilvl1×0.4 дляimplicit; weapon/armour/helmet/gloves/boots+разрешённыйoffhandеслиоружиенеtwohand. Никакого автонадевания дальнейшей добычи.
- Новая отдельная кампания `user://save_v06.json`. Прежниеsave2/save_v05 не изменяются, автоимпорта нет. Настройки звука/стадии обучения/умения сохраняются.
- Первым в списке и в подсказке жрец. Принимает в отряд игрок; он остаётся первым по порядку добавления. Вар сам вперёд не встаёт. Три места до первой победы склепа, потом4. Толькоwarrior/priest/mage/hunter доступны.
- `DB.skill_options`, `DB.skill_selected`, `DB.skill`; `hero.skill_id`. По2базовыхумения каждойиз7играбельныхветок=14. Выбор с1уровня явный, отдельно отspec/талантов. Без validchoice участников `start_run` отклоняет поход. Старыйspec.skill остаётся fallbackтолькоpreview/будущихклассов. Calc offense/heal/sheet/skill.stats используют DB.skill. `game.set_skill`camp-only, валидируетclass/spec. Сменаspec сбрасываетskill_id; простое чтение описания не выбираетумение.
- Жрецsteady14heal/1speed/10mana и fleeting11heal/1.15speed/8mana. Последнийкоэффициент root уточнил после прогонов: при прежних10mana быстрыйвариант был ловушкой на стартовом комплекте; теперь обе тройки проходят с обоими вариантами. `_act` берёт skill.mana_cost либо HEAL_COST. Arms.less_taken32, остальное основное stat-соотношениеv0.5 сохранено.
- `game.tutorial_state()` возвращает {id,page,action,cls,text[,item,dungeon]}; wrappers tutorial_text/target/active сохранены. Шаги intro→healer→skillpriest→recruit→skills→ready, при фактическом вайпе сжрецомпервым formation, после победы loot→выборcatacombs→currency→craft. Подсказки короткие/разговорные, реальные цели подсвечены и одинразраскрываютсяпрокруткой. Не предсказываем любуюсмертьоднойпричиной. Игрок вправе исправить строй заранее и избежать вайпа.
- `formation_lesson` выставляется только при фактическойпотерепервым переднего priesthealer и wipe/retreat; `formation_corrected` после ручного переноса тяжёлого бойца вперёд. Порядок не меняется сам. При выборе данжа обучениеподсвечиваетсоответствующуюточкукарты, апослевыборакнопкупохода.
- Camp.FormationCard реализует Godot drag-data/drop-data с проверкой owner и camp-only; перенос кликами source→destination, marker, cancel/Escape. Перенос=insert, несортировка. Убрано «ПЕРЕДНИЙ» изкарточек/боя, позиции/роли остаются. Бойраньшекакпреждефронтсправаоколоврага, лагернаястрокаслевапервый.
- Gear tutorial: item→equip и weapon→currency→apply; безавтоподменыручноговыборагероя. Длинныеtooltipбольшенесбрасываютscrollкаждые0.2с. Предметы остаются вобщемbackendхранилищеcap60, фильтрпо DB.can_use иbulk только видимые. Формулыtypedarmor/mainstats/ilvlcapacityкакv0.5.
- `DungeonSound`: оригинальные синтезированныеPCM-сигналыstart/click/confirm/tutorial/error. Нетскачанныхаудио/саундтрека. Громкость35%плюс−6dB, mute/sliderвheader, settingsприменяютсяпередstart. Headlessскипаетнеслышимыйplayback, audio_testявновключаетреальныйDummy и ждёточисткисервера. _exit_treeчиститплееры; _quitсохраняет/глушит/даёт0.1сочистки. get_tree.auto_accept_quit=false (именноSceneTree, неWindow).
- Переходы0.45свместо1.2; фазыtravel/fight, шаги/коридор/39моделейсохранены. Не расширялипереходывущерббою.

## Баланс и проверки

Engine `/workspace/tools/godot-4.3/Godot_v4.3-stable_linux.x86_64`, не системный4.6.3. XDG_DATA_HOME=/workspace/changes/v06/test-data, CONFIG=/workspace/.config, CACHE=/workspace/.cache. Сначала --headless --editor --path . --import --quit. Все тестысейвыотдельныеuser://tests. В helper `/workspace/tools/setup-idle-dungeon.sh` канонический путьTestapp; SHA512проверкаофициальногоархива, совпадающийбинарникнеперезаписывается.

558assertions: onboarding71+skill65+audio58+gear24+formation30+item_card21+gear_filter34+tutorial_ui29+formation_ui22+sprite161+stat43. ТестdragвключаетнастоящийViewport.push_input press/motion/release, не толькопрямуюфункциюdrop.

460боевыхсценариев: balance160, formation160, progression140. Crypt tuning: front_share1, aoe_share.1, pack_hp3.8/pack_dmg4.3, rare_chance0. Стихийные/редкиеугрозывпоследующихданжахсохранены. Обычныемобысильнеечемv0.5, работающийхилнуженсразу.

Правильныйwarprot+priestlight+mage/hunter сdefaultумениями20/20wins0deaths; среднийminHP44.7%/57.2%, heal2300.8/2212.9,164.3/168.5с. НастоящийcosmeticRNGтоже20/20. Сfleetingskill8mana обе20/20безсмертей. Priestfrontвсе20/20первымпогибаетнаобычныхпачках: steadyвсреднем7ссмагом/17.2ссхантом, fleeting6/12.5с; затемвайп. Это не scripteddeath и не гарантия для произвольной экипировки.

Вcatacombsстартовыетройки20/20reachboss0wins; cult0wins. Noheal0/20. Armsнаполностьюпоношенномкомплекте3/20, послеподготовкиilvl8комплектов20/20безсмертей. Четверосгарантированнымиilvl8weapon/chestещё0/20cat; подготовленнаячетвёркаlvl1сilvl18life+coldresвещами20/20. Это достижимостьбилдов, не обещаниетемпафарма/экономики. Все8данжейнепрошлитщательныйбаланс.

РеальныеGL-снимки `tools/capture_v06.gd`, XDG_DATA_HOME=/workspace/changes/v06/capture-data, DISPLAY=:97 Xvfb. Сценарий реальные выборы→переднийжрецумирает→ручнойперенос→победа; screenshotметодявноrefreshUIпотомуgame.simulating=trueотключаетобычныйrefresh. Не подменять снимкамидоказательствоуниверсальногобаланса.

## Дальше

Кики/диспелы, новые классы/DLC, альтернативные материалы брони для билдов, шаман-боец с AP отINT, магические активки охотника, недельные аффиксы и экономика остаются будущим. Статыблок/уклонпокасредние, не отдельныеслучайныесобытия. Спрайтыгероевотражаютclass/spec, не каждуювещь. Пользовательскийдокумент `docs/DESIGN_DISCUSSION_2026-10-18.md` — контекст, не реализациявсегосразу.
