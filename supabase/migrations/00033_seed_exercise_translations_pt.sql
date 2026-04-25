-- Phase 15f Stage 3 — pt-BR seed for the 150 default exercises.
--
-- Inserts one `('pt', name, description, form_tips)` row into
-- `exercise_translations` per default exercise. Together with 00032 (EN
-- backfill), this guarantees every `is_default = true` exercise has both
-- `'en'` and `'pt'` translations before Stage 4 drops the monolingual
-- `name/description/form_tips` columns from `exercises`.
--
-- Sourcing rules (per `docs/superpowers/specs/phase15f-pt-glossary.md`,
-- APPROVED 2026-04-24):
--   * `name` — copied verbatim from `lib/l10n/app_pt.arb`
--     (`exerciseName_<slug>` keys, shipped in Phase 15c PRs #86–#91 and
--     refined by PR #109 for Core/Bands loanwords). Names are not
--     re-translated here — the ARB is the canonical source.
--   * `description` and `form_tips` — AI-drafted under glossary §5
--     (style guide), with §1 vocabulary discipline. Voice is `você` +
--     imperative; eponyms / coaching loanwords (Push Press, Arnold Press,
--     Romanian Deadlift, Hack Squat, etc.) stay English per §2.
--     Numbers use comma decimals (`2,5 kg`) and `kg` (never "quilos") per
--     §5.5.
--
-- Join key is `exercises.slug`, populated as a hardcoded literal map in
-- 00030 (byte-exact parity with `_exerciseNames` in
-- `lib/core/l10n/exercise_l10n.dart`). The slug literals below MUST stay
-- in lockstep with that map.
--
-- Quality gate: user reviews all 150 rows on staging during Stage 8
-- (~75 min focused skim, see glossary §5.7). Soft phrasing fixes can land
-- as a follow-up; factual / vocabulary errors are hard rejects.
--
-- Idempotency: this migration is intended to run exactly once. The
-- count-parity assert at the bottom prevents a partial seed; rerunning
-- after a successful run would violate the (exercise_id, locale) PK and
-- abort with a unique-violation, which is the correct behavior.
--
-- This migration runs as `postgres`, bypassing RLS.

BEGIN;

INSERT INTO exercise_translations (exercise_id, locale, name, description, form_tips)
SELECT e.id, 'pt', v.name, v.description, v.form_tips
FROM exercises e
JOIN (VALUES

  -- =========================================================================
  -- CHEST (18) — 9 from 00007 + 3 from 00014 + 6 from 00019
  -- =========================================================================

  ('barbell_bench_press',
    'Supino Reto com Barra',
    'O rei do empurrar de membros superiores. Trabalha peito, deltoide anterior e tríceps com a barra no banco reto.',
    E'Plante os pés no chão e contraia as escápulas.\nDesça a barra até o meio do peito com cotovelos a cerca de 45 graus.\nEmpurre para cima e levemente para trás até a extensão.\nMantenha os punhos alinhados sobre os cotovelos durante todo o movimento.'),

  ('incline_barbell_bench_press',
    'Supino Inclinado com Barra',
    'Supino com a barra em banco inclinado (30 a 45 graus) que desloca a ênfase para o peito superior e deltoide anterior.',
    E'Ajuste o banco entre 30 e 45 graus para ativar o peito superior.\nDesça a barra até a parte alta do peito, logo abaixo da clavícula.\nMantenha as escápulas contraídas e uma leve curvatura nas costas.\nEvite abrir os cotovelos além de 60 graus.'),

  ('decline_barbell_bench_press',
    'Supino Declinado com Barra',
    'Supino com a barra em banco declinado, que enfatiza as fibras inferiores do peito e permite cargas mais pesadas.',
    E'Trave os pés sob os apoios antes de tirar a barra do suporte.\nDesça a barra até a parte inferior do peito ou esterno.\nMantenha os cotovelos a cerca de 45 graus para proteger os ombros.\nUse um parceiro ou pinos de segurança em séries pesadas.'),

  ('dumbbell_bench_press',
    'Supino Reto com Halteres',
    'Supino reto com halteres que permite uma amplitude maior e trabalho independente de cada braço.',
    E'Comece com os halteres na altura do peito, palmas para frente.\nEmpurre para cima aproximando os halteres levemente no topo.\nDesça com controle até sentir o alongamento do peito.\nMantenha os pés no chão e uma leve curvatura na lombar.'),

  ('incline_dumbbell_press',
    'Supino Inclinado com Halteres',
    'Supino inclinado com halteres que trabalha o peito superior em amplitude completa, com ação independente dos braços.',
    E'Ajuste o banco entre 30 e 45 graus.\nComece com os halteres na altura dos ombros, palmas para frente.\nEmpurre juntando os halteres no topo sem batê-los.\nDesça devagar para sentir o alongamento no peito superior.'),

  ('dumbbell_fly',
    'Crucifixo com Halteres',
    'Movimento de isolamento para o peito com halteres em arco aberto. Excelente para alongar os peitorais sob carga.',
    E'Mantenha uma leve flexão dos cotovelos durante todo o movimento.\nDesça os halteres em arco amplo até sentir o alongamento do peito.\nContraia o peito para reaproximar os halteres.\nEvite cargas excessivas — é um exercício de alongar e contrair.'),

  ('cable_crossover',
    'Crossover no Cabo',
    'Exercício de isolamento no cabo que mantém tensão constante no peito durante todo o movimento de cruzamento.',
    E'Posicione as polias na altura dos ombros ou um pouco acima.\nDê um passo à frente em base escalonada para estabilizar.\nJunte as alças à frente do peito com leve flexão nos cotovelos.\nControle o retorno — não deixe o cabo voltar com tranco.'),

  ('machine_chest_press',
    'Supino na Máquina',
    'Supino guiado pela máquina, em trajetória fixa, ideal para iniciantes e seguro para levar à falha.',
    E'Ajuste o assento para que as alças fiquem alinhadas com o meio do peito.\nEmpurre para frente sem travar os cotovelos.\nMantenha as escápulas apoiadas no encosto.\nControle o retorno do peso — sem bater a pilha.'),

  ('push_up',
    'Flexão de Braços',
    'Empurrar com peso do corpo que constrói força de peito, ombros e tríceps em qualquer lugar, sem equipamento.',
    E'Mantenha o corpo em linha reta da cabeça aos calcanhares.\nDesça até quase encostar o peito no chão.\nMantenha os cotovelos a 45 graus, sem abrir até 90.\nEstenda os braços no topo sem hiperestender os cotovelos.'),

  ('pec_deck',
    'Pec Deck',
    'Crucifixo na máquina com almofadas que traçam um arco, isolando o peito sem demanda de estabilizadores do ombro.',
    E'Ajuste o assento para que as alças fiquem na altura do peito.\nContraia o peito para juntar as almofadas à frente.\nMantenha as escápulas apoiadas no encosto.\nControle o retorno para a pilha não bater.'),

  ('cable_chest_press',
    'Supino no Cabo',
    'Empurrar em pé ou ajoelhado no cabo, que leva o peito por adução horizontal com tensão constante.',
    E'Ajuste as polias na altura do peito com alças ou barra.\nApoie-se em base escalonada para mais estabilidade.\nEmpurre as alças à frente, juntando-as em um arco suave.\nResista ao cabo na volta para um bom alongamento do peitoral.'),

  ('wide_push_up',
    'Flexão Aberta',
    'Flexão com as mãos bem abertas além da largura dos ombros que desloca a carga para a porção externa do peito.',
    E'Posicione as mãos mais abertas que os ombros, dedos à frente.\nMantenha o corpo em uma linha reta da cabeça aos calcanhares.\nDesça até o peito quase tocar o chão.\nEmpurre sem deixar o quadril cair ou subir.'),

  ('incline_dumbbell_fly',
    'Crucifixo Inclinado com Halteres',
    'Crucifixo com halteres em banco inclinado que enfatiza as fibras do peito superior em arco amplo.',
    E'Ajuste o banco entre 30 e 45 graus e deite-se.\nComece com os halteres elevados, palmas voltadas uma para a outra.\nDesça em arco aberto com leve flexão dos cotovelos.\nContraia o peito superior para reaproximar os halteres.'),

  ('decline_dumbbell_press',
    'Supino Declinado com Halteres',
    'Supino com halteres em banco declinado, que desloca a carga para as fibras inferiores do peito.',
    E'Trave os pés sob os apoios antes de levantar os halteres.\nComece com os halteres na altura do peito inferior, palmas à frente.\nEmpurre para cima e levemente juntos sem bater no topo.\nDesça com controle até sentir um bom alongamento.'),

  ('landmine_press',
    'Landmine Press',
    'Empurrar unilateral com a barra encaixada no landmine, gerando um arco seguro para peito e deltoide anterior.',
    E'Fique em base escalonada com a ponta da barra no ombro.\nEmpurre a barra para cima e levemente cruzando o corpo.\nMantenha o core firme — não deixe o tronco rotacionar.\nDesça a barra com controle de volta ao ombro.'),

  ('diamond_push_up',
    'Flexão Diamante',
    'Flexão com as mãos juntas formando um diamante, que desloca a carga para o tríceps e a parte interna do peito.',
    E'Posicione as mãos sob o peito com polegares e indicadores se tocando.\nMantenha os cotovelos próximos das costelas na descida.\nDesça até o peito quase tocar as mãos.\nEmpurre para cima sem deixar o quadril cair ou subir.'),

  ('incline_push_up',
    'Flexão Inclinada',
    'Flexão com as mãos elevadas em um banco ou caixa, uma progressão acessível para a flexão padrão.',
    E'Apoie as mãos em um banco firme, dedos à frente.\nAfaste os pés até o corpo formar uma linha reta.\nDesça o peito até a borda do banco com cotovelos a 45 graus.\nEmpurre por completo sem travar os cotovelos com força.'),

  ('decline_push_up',
    'Flexão Declinada',
    'Flexão com os pés elevados em um banco, deslocando a ênfase para o peito superior e deltoide anterior.',
    E'Apoie os pés em um banco firme e as mãos no chão.\nMantenha o corpo em linha reta da cabeça aos calcanhares.\nDesça até o peito quase tocar o chão.\nEmpurre sem deixar o quadril cair ou subir.'),

  -- =========================================================================
  -- BACK (23) — 10 from 00007 + 4 from 00014 + 9 from 00019
  -- =========================================================================

  ('barbell_bent_over_row',
    'Remada Curvada com Barra',
    'Remada composta com barra que constrói costas grossas. Trabalha dorsais, romboides e deltoide posterior.',
    E'Incline o quadril a cerca de 45 graus com as costas retas.\nPuxe a barra até a parte baixa do peito ou abdômen superior.\nContraia as escápulas no topo do movimento.\nDesça com controle — sem bater a barra no chão.'),

  ('deadlift',
    'Levantamento Terra',
    'A puxada total definitiva. Constrói toda a cadeia posterior — costas, glúteos, posteriores e força de pegada.',
    E'Posicione a barra sobre o meio do pé, quadril entre joelhos e ombros.\nMantenha a barra colada ao corpo durante toda a subida.\nEmpurre o chão e estenda quadril e joelhos juntos.\nFinalize contraindo os glúteos — não hiperestenda a lombar.'),

  ('t_bar_row',
    'Remada Cavalinho',
    'Variação de remada com landmine ou barra T que permite cargas pesadas em pegada neutra.',
    E'Posicione-se sobre a barra com pés na largura dos ombros.\nMantenha o peito para cima e a coluna neutra.\nPuxe a carga em direção ao peito, contraindo no topo.\nEvite usar muito impulso de tronco — controle a carga.'),

  ('dumbbell_row',
    'Remada Unilateral com Halter',
    'Remada com um halter por vez que constrói espessura dos dorsais e corrige assimetrias entre os lados.',
    E'Apoie uma mão e um joelho no banco para suporte.\nPuxe o halter em direção ao quadril, não ao ombro.\nMantenha as costas retas sem rotacionar o tronco.\nDesça o halter por completo para alongar no fim.'),

  ('dumbbell_pullover',
    'Pullover com Halter',
    'Exercício com halter que trabalha os dorsais por um arco amplo acima da cabeça, deitado no banco.',
    E'Apoie apenas a parte superior das costas no banco, perpendicular a ele.\nSegure um halter acima da cabeça com leve flexão de cotovelos.\nDesça atrás da cabeça até sentir o alongamento dos dorsais.\nVolte usando os dorsais, não os braços.'),

  ('cable_row',
    'Remada no Cabo',
    'Remada sentada no cabo que trabalha a região central das costas com tensão constante em toda a amplitude.',
    E'Sente-se com leve inclinação à frente no início.\nPuxe a alça até a parte baixa do peito, contraindo as escápulas.\nNão se incline muito para trás — mantenha o tronco quase ereto.\nVolte devagar com os braços em extensão completa.'),

  ('lat_pulldown',
    'Puxada na Polia Alta',
    'Exercício no cabo em que se puxa uma barra ampla até o peito. Constrói largura dos dorsais e substitui a barra fixa.',
    E'Pegue a barra um pouco mais aberto que a largura dos ombros.\nIncline-se levemente para trás e puxe até o peito superior.\nLeve os cotovelos para baixo e para trás, contraindo os dorsais.\nControle a barra na subida — sem deixá-la puxar os braços.'),

  ('pull_up',
    'Barra Fixa',
    'Puxada vertical com peso do corpo que constrói largura dos dorsais, força de pegada e potência de tração.',
    E'Pegue a barra um pouco mais aberto que os ombros, palmas para frente.\nSuba até o queixo passar da barra.\nDesça com controle até a extensão total.\nEvite balançar o corpo — use forma estrita para os dorsais.'),

  ('chin_up',
    'Barra Fixa Supinada',
    'Barra fixa com pegada supinada que enfatiza os bíceps junto com os dorsais. Mais fácil que a versão pronada.',
    E'Pegue a barra na largura dos ombros, palmas voltadas para você.\nSuba até o queixo passar da barra.\nDesça com controle até a extensão total.\nMantenha os cotovelos apontados para frente, não para os lados.'),

  ('machine_row',
    'Remada na Máquina',
    'Remada na máquina com trajetória fixa e apoio de peito, fácil para isolar a região central das costas.',
    E'Ajuste a almofada do peito para os braços estenderem totalmente.\nPuxe as alças em direção ao tronco, contraindo as escápulas.\nMantenha o peito firme contra a almofada.\nVolte ao início devagar — sem bater a pilha.'),

  ('face_pull',
    'Face Pull',
    'Exercício no cabo para deltoide posterior e trapézio médio que reforça a mecânica saudável das escápulas.',
    E'Posicione uma corda na altura do rosto na polia.\nPuxe a corda em direção à testa, com cotovelos altos.\nGire externamente até os punhos apontarem para trás.\nVolte com controle sem perder a tensão.'),

  ('rack_pull',
    'Rack Pull',
    'Levantamento terra parcial com a barra em pinos na altura do joelho, que sobrecarrega o lockout e constrói costas grossas.',
    E'Ajuste os pinos na altura do joelho ou logo abaixo.\nContraia o core com força antes de puxar.\nLeve o quadril à frente para travar com os glúteos.\nDesça com controle — sem deixar a barra cair sobre os pinos.'),

  ('good_morning',
    'Good Morning',
    'Hip hinge com a barra apoiada no trapézio que treina posteriores, glúteos e eretores da espinha.',
    E'Apoie a barra no trapézio como em um agachamento de barra baixa.\nEmpurre o quadril para trás com leve flexão dos joelhos.\nPare quando o tronco estiver paralelo ao chão.\nLeve o quadril à frente para subir, contraindo os glúteos.'),

  ('pendlay_row',
    'Remada Pendlay',
    'Remada estrita com a barra partindo do chão a cada repetição, que elimina o impulso e reforça a tração explosiva.',
    E'Posicione-se com a barra sobre o meio do pé e o tronco quase paralelo.\nPuxe a barra até a parte baixa do peito em um movimento explosivo.\nDeixe a barra repousar no chão entre cada repetição.\nMantenha a coluna neutra — sem arredondar embaixo.'),

  ('hyperextension',
    'Hiperextensão',
    'Extensão de quadril com peso do corpo no banco a 45 graus que treina glúteos e eretores da espinha.',
    E'Ajuste a almofada para o quadril ficar livre na borda.\nCruze os braços no peito e desça flexionando o quadril.\nSuba o tronco até alinhar com as pernas.\nNão hiperestenda — pare na linha reta.'),

  ('back_extension',
    'Extensão de Costas',
    'Extensão de costas com carga na máquina ou banco que permite sobrecarga progressiva da cadeia posterior.',
    E'Segure uma anilha contra o peito para aumentar a resistência.\nDesça flexionando o quadril com a coluna longa e neutra.\nSuba o tronco até alinhar com as pernas.\nContraia os glúteos no topo — sem hiperestender.'),

  ('inverted_row',
    'Remada Invertida',
    'Remada horizontal com peso do corpo sob uma barra fixa, que constrói o meio das costas com dificuldade ajustável.',
    E'Posicione uma barra na altura do quadril em um rack ou em argolas.\nFique pendurado embaixo com o corpo em linha reta de prancha.\nPuxe o peito até a barra levando os cotovelos para trás.\nDesça com controle — sem balançar o quadril.'),

  ('chest_supported_row',
    'Remada com Apoio no Peito',
    'Remada com halteres e o peito apoiado no banco inclinado, que elimina o impulso e isola os dorsais.',
    E'Deite de bruços no banco inclinado com um halter em cada mão.\nDeixe os braços estendidos para baixo no início.\nRema os halteres levando os cotovelos em direção ao quadril.\nContraia as escápulas no topo antes de descer.'),

  ('seal_row',
    'Seal Row',
    'Remada com a barra deitado em um banco elevado para que a barra balance livre, forçando uma puxada estrita.',
    E'Deite de bruços em um banco alto o suficiente para a barra passar.\nSegure a barra com pegada na largura dos ombros, braços estendidos.\nPuxe a barra até o peito contraindo as escápulas.\nDesça com controle — sem soltar nem usar pausa morta.'),

  ('straight_arm_pulldown',
    'Puxada com Braços Estendidos',
    'Isolamento de dorsais no cabo com braços retos, levando o ombro pela adução para trabalho puro de costas.',
    E'Fique de frente para a polia alta com uma barra reta.\nIncline o quadril levemente com os braços estendidos à frente.\nPuxe a barra até as coxas em um arco amplo.\nMantenha os cotovelos travados — o movimento é só no ombro.'),

  ('close_grip_lat_pulldown',
    'Puxada Pegada Fechada',
    'Puxada na polia com pegada fechada que alonga os dorsais e enfatiza as fibras inferiores.',
    E'Use uma pegada estreita neutra ou supinada na barra.\nSente-se ereto com leve inclinação para trás.\nPuxe a barra até o peito superior, cotovelos para baixo e para trás.\nVolte a barra para cima com controle total.'),

  ('wide_grip_pull_up',
    'Barra Fixa Pegada Aberta',
    'Barra fixa com pegada bem aberta que enfatiza a parte superior dos dorsais e a largura geral das costas.',
    E'Pegue a barra bem mais aberto que os ombros, palmas para frente.\nSuba levando os cotovelos para baixo e para trás.\nUltrapasse o queixo da barra em cada repetição.\nDesça com controle até a extensão total antes do próximo rep.'),

  ('kettlebell_row',
    'Remada com Kettlebell',
    'Remada unilateral com Kettlebell que treina dorsais e meio das costas e desafia a anti-rotação.',
    E'Incline o quadril com uma mão apoiada em um banco ou rack.\nSegure o Kettlebell em pegada neutra com o braço estendido.\nRema o Kettlebell até o quadril, cotovelo próximo das costelas.\nDesça com controle sem rotacionar o tronco.'),

  -- =========================================================================
  -- LEGS (32) — 11 from 00007 + 7 from 00014 + 14 from 00019
  -- =========================================================================

  ('barbell_squat',
    'Agachamento com Barra',
    'O exercício fundamental para membros inferiores. Constrói quadríceps, glúteos e força geral de pernas.',
    E'Apoie a barra no trapézio superior, nunca no pescoço.\nFlexione quadril e joelhos juntos para descer.\nMantenha os joelhos alinhados com os pés — sem deixá-los cair.\nDesça pelo menos até paralelo e suba pelo pé inteiro.'),

  ('front_squat',
    'Agachamento Frontal',
    'Agachamento com a barra na posição frontal, que enfatiza o quadríceps e exige forte estabilidade do core.',
    E'Apoie a barra no deltoide anterior com cotovelos altos.\nMantenha o tronco o mais ereto possível.\nDesça pelo menos até paralelo.\nLeve os joelhos para frente sobre os pés — é normal no frontal.'),

  ('romanian_deadlift',
    'Levantamento Terra Romeno',
    'Hip hinge que enfatiza posteriores e glúteos. Feito com leve flexão dos joelhos, descendo a barra rente às pernas.',
    E'Mantenha a barra colada às pernas durante todo o movimento.\nFlexione o quadril, não a lombar.\nSinta o alongamento dos posteriores antes de subir.\nContraia os glúteos no topo para finalizar.'),

  ('hip_thrust',
    'Elevação de Quadril com Barra',
    'Exercício de glúteo com a barra, levantando o quadril com a parte superior das costas apoiada em um banco.',
    E'Apoie a parte superior das costas no banco com a barra sobre o quadril.\nEmpurre pelos calcanhares até o tronco ficar paralelo ao chão.\nContraia os glúteos com força no topo por um segundo.\nDesça com controle — sem soltar o quadril.'),

  ('dumbbell_lunges',
    'Afundo com Halteres',
    'Exercício unilateral em que se dá um passo à frente e desce em afundo com halteres nas mãos.',
    E'Dê um passo longo para o joelho da frente ficar sobre o tornozelo.\nDesça até os dois joelhos formarem cerca de 90 graus.\nMantenha o tronco ereto e o core firme.\nEmpurre pelo calcanhar da frente para voltar a ficar em pé.'),

  ('bulgarian_split_squat',
    'Agachamento Búlgaro',
    'Agachamento unilateral com o pé de trás elevado, que sobrecarrega quadríceps e glúteos e treina estabilidade.',
    E'Apoie o pé de trás no banco com o peito do pé para baixo.\nDesça até o joelho de trás quase tocar o chão.\nMantenha a maior parte da carga sobre a perna da frente.\nEmpurre pelo calcanhar da frente, com o tronco ereto.'),

  ('goblet_squat',
    'Agachamento Goblet',
    'Agachamento com halter à frente do peito. Ótimo para aprender a mecânica e construir quadríceps.',
    E'Segure um halter na vertical à altura do peito com as duas mãos.\nMantenha os cotovelos por dentro dos joelhos no fim da descida.\nSente entre as pernas, não atrás delas.\nMantenha o peito alto e o core firme.'),

  ('leg_press',
    'Leg Press',
    'Movimento composto na máquina que permite cargas pesadas em quadríceps e glúteos sem compressão da coluna.',
    E'Posicione os pés na largura dos ombros na plataforma.\nDesça o trenó até os joelhos formarem cerca de 90 graus.\nEmpurre pelo pé inteiro — sem deixar os calcanhares subirem.\nNão trave os joelhos por completo no topo.'),

  ('leg_extension',
    'Cadeira Extensora',
    'Exercício de isolamento na máquina que trabalha o quadríceps através da extensão do joelho.',
    E'Ajuste a almofada para apoiar logo acima do tornozelo.\nEstenda as pernas por completo, contraindo o quadríceps no topo.\nDesça devagar — a fase excêntrica é onde está o ganho.\nEvite usar impulso para subir a carga.'),

  ('leg_curl',
    'Mesa Flexora',
    'Exercício de isolamento na máquina que trabalha os posteriores através da flexão do joelho.',
    E'Ajuste a almofada para apoiar logo acima do calcanhar.\nFlexione contraindo os posteriores.\nSegure brevemente no topo para a contração máxima.\nDesça com controle — sem deixar a carga cair.'),

  ('calf_raise',
    'Elevação de Panturrilha',
    'Isolamento que trabalha as panturrilhas (gastrocnêmio e sóleo) pela flexão plantar do tornozelo.',
    E'Comece com alongamento total embaixo — calcanhares abaixo da plataforma.\nSuba na ponta dos pés o mais alto possível.\nSegure a contração no topo por um segundo.\nUse cadência lenta e controlada — sem balançar.'),

  ('hack_squat',
    'Hack Squat',
    'Agachamento na máquina com o tronco apoiado em encosto angulado, que sobrecarrega o quadríceps sem carga na coluna.',
    E'Ajuste as almofadas dos ombros para o quadril ficar fundo no assento.\nPosicione os pés na largura dos ombros, pontas levemente abertas.\nDesça até as coxas passarem do paralelo com a almofada.\nEmpurre pelo pé inteiro até quase a extensão total.'),

  ('sumo_deadlift',
    'Levantamento Terra Sumo',
    'Variação do terra com pegada por dentro dos joelhos e base aberta, que encurta a puxada e ativa a parte interna das coxas.',
    E'Abra a base para cerca do dobro da largura dos ombros, pontas dos pés abertas.\nSegure a barra por dentro dos joelhos com os braços retos.\nPeito alto, quadril baixo — empurre o chão para subir.\nFinalize contraindo os glúteos sem inclinar para trás.'),

  ('walking_lunges',
    'Afundo Caminhando',
    'Padrão de afundo em que cada passo avança à frente, treinando força unilateral e equilíbrio sob carga.',
    E'Segure um halter em cada mão ao lado do corpo.\nDê um passo longo para o joelho da frente ficar sobre o tornozelo.\nDesça até o joelho de trás quase encostar no chão.\nEmpurre pelo calcanhar da frente para o próximo passo.'),

  ('step_up',
    'Step-Up',
    'Exercício unilateral em que se sobe em uma caixa ou banco, construindo força de quadríceps e glúteos.',
    E'Use uma caixa que dê 90 graus no joelho quando você estiver em cima.\nSegure um halter em cada mão ao lado do corpo.\nApoie o pé inteiro na caixa e suba ereto.\nDesça com controle, descendo sempre com a mesma perna.'),

  ('seated_calf_raise',
    'Panturrilha Sentado',
    'Máquina de panturrilha sentada que isola o sóleo ao tirar o joelho do movimento pela flexão.',
    E'Ajuste a almofada das coxas firme logo acima dos joelhos.\nPosicione a sola dos pés na plataforma.\nDesça os calcanhares ao máximo para um bom alongamento.\nSuba alto e contraia brevemente antes da próxima rep.'),

  ('leg_abductor',
    'Abdutora',
    'Máquina que trabalha glúteo médio e abdutores do quadril, abrindo as coxas contra a almofada.',
    E'Sente-se ereto com a lombar firme contra o encosto.\nApoie a parte externa das coxas nas almofadas.\nAbra as almofadas em arco constante — sem balanço.\nVolte devagar para sentir os abdutores alongarem sob carga.'),

  ('leg_adductor',
    'Adutora',
    'Máquina que treina os adutores (parte interna da coxa), juntando as almofadas a partir da posição sentada.',
    E'Ajuste as almofadas com um leve alongamento inicial.\nSente-se ereto com a lombar contra o encosto.\nJunte as almofadas com controle.\nLibere devagar — sem deixar a carga puxar as pernas.'),

  ('glute_bridge',
    'Elevação de Quadril',
    'Levantamento de quadril com peso do corpo que fortalece glúteos e posteriores. Ótimo aquecimento ou para iniciantes.',
    E'Deite de costas com os joelhos flexionados e os pés no chão.\nEmpurre pelos calcanhares para subir o quadril.\nContraia os glúteos no topo com as costelas baixas.\nDesça o quadril devagar — sem soltar.'),

  ('single_leg_glute_bridge',
    'Elevação de Quadril Unilateral',
    'Elevação de quadril em uma perna por vez, que expõe assimetrias e sobrecarrega cada glúteo.',
    E'Deite de costas com um joelho flexionado e a outra perna estendida.\nEmpurre pelo calcanhar apoiado para subir o quadril.\nMantenha o quadril alinhado — sem deixar um lado cair.\nDesça devagar e repita antes de trocar de lado.'),

  ('box_jump',
    'Salto na Caixa',
    'Salto pliométrico em uma caixa elevada que desenvolve potência explosiva de pernas e coordenação.',
    E'Fique a cerca de um pé de distância de uma caixa firme em altura alcançável.\nFaça um agachamento curto com os braços para trás.\nBalance os braços e salte na caixa, aterrissando macio nos dois pés.\nDesça da caixa em vez de saltar para trás.'),

  ('nordic_curl',
    'Nordic Curl',
    'Exercício dominante de joelho para posteriores, em que se desce o corpo reto com os tornozelos travados.',
    E'Ajoelhe em uma almofada com os tornozelos firmes em um apoio seguro.\nMantenha o corpo em linha reta dos joelhos aos ombros.\nDesça à frente o mais devagar possível usando os posteriores.\nApoie-se nas mãos se precisar e empurre para voltar.'),

  ('wall_sit',
    'Agachamento na Parede',
    'Sustentação isométrica do agachamento contra a parede, que constrói resistência de quadríceps sem equipamento.',
    E'Apoie as costas em uma parede plana com os pés à frente.\nDeslize até joelhos e quadril formarem 90 graus.\nMantenha as costas e a cabeça firmes contra a parede.\nSegure pelo tempo definido — respire e não desabe.'),

  ('donkey_kick',
    'Coice de Burro',
    'Exercício de glúteo com peso do corpo em quatro apoios, chutando um pé para o teto para isolar a contração.',
    E'Fique em quatro apoios com mãos sob os ombros e joelhos sob o quadril.\nMantenha o joelho ativo flexionado a 90 graus.\nLeve o pé em direção ao teto contraindo o glúteo.\nDesça com controle — sem arquear a lombar.'),

  ('bodyweight_squat',
    'Agachamento Livre',
    'Agachamento básico com peso do corpo que constrói mobilidade, padrão e resistência de quadríceps e glúteos.',
    E'Fique com os pés na largura dos ombros, pontas levemente abertas.\nSente para baixo e para trás como em uma cadeira baixa.\nDesça pelo menos até paralelo com o peito alto.\nSuba pelo pé inteiro até a posição totalmente ereta.'),

  ('reverse_lunges',
    'Afundo Reverso',
    'Padrão de afundo em que cada passo vai para trás, aliviando o joelho da frente e enfatizando os glúteos.',
    E'Segure um halter em cada mão ao lado do corpo.\nDê um passo longo para trás em base de afundo.\nDesça até o joelho de trás quase encostar no chão.\nEmpurre pelo calcanhar da frente para voltar a ficar em pé.'),

  ('dumbbell_calf_raise',
    'Panturrilha com Halteres',
    'Panturrilha em pé com halteres ao lado do corpo, isolando o gastrocnêmio na flexão plantar.',
    E'Posicione a sola dos pés em uma anilha ou degrau baixo.\nSegure um halter em cada mão ao lado do corpo.\nSuba na ponta dos pés o mais alto possível.\nDesça os calcanhares abaixo do degrau para alongar.'),

  ('single_leg_leg_press',
    'Leg Press Unilateral',
    'Leg Press com uma perna por vez, que constrói força unilateral de quadríceps e expõe diferenças entre os lados.',
    E'Use uma carga moderada e centralize um pé na plataforma.\nDesça o trenó até o joelho da perna de trabalho ficar a 90 graus.\nEmpurre pelo pé inteiro até quase a extensão total.\nFaça todas as reps de uma perna antes de trocar.'),

  ('reverse_hyperextension',
    'Hiperextensão Reversa',
    'Máquina que sobrecarrega glúteos e posteriores via extensão de quadril, sem compressão da coluna.',
    E'Deite de bruços com o quadril na borda da máquina.\nSegure as alças e deixe as pernas pendurarem para baixo.\nLeve as pernas para trás e para cima até alinhar com o tronco.\nDesça as pernas devagar — sem balançar.'),

  ('cable_glute_kickback',
    'Glúteo no Cabo',
    'Exercício no cabo que isola o glúteo, chutando uma perna reta para trás contra a resistência.',
    E'Prenda uma caneleira na polia baixa e na perna de trabalho.\nFique de frente para a polia, apoiado no equipamento com as duas mãos.\nLeve a perna para trás contraindo o glúteo.\nVolte com controle — sem rotacionar o quadril.'),

  ('cable_pull_through',
    'Pull-Through no Cabo',
    'Hip hinge entre as pernas com corda na polia baixa, que carrega glúteos e posteriores como um Kettlebell Swing.',
    E'Fique de costas para a polia baixa com a corda entre as pernas.\nFlexione o quadril para trás com leve flexão dos joelhos.\nLeve o quadril à frente para subir, contraindo os glúteos.\nDeixe a corda puxar você de volta para o próximo rep.'),

  ('kettlebell_deadlift',
    'Levantamento Terra com Kettlebell',
    'Hip hinge com Kettlebell entre as pernas, ideal para aprender o padrão com cargas ajustáveis.',
    E'Posicione-se sobre o Kettlebell com os pés na largura dos ombros.\nFlexione o quadril e segure a alça com as duas mãos.\nEmpurre o chão para subir ereto com o Kettlebell.\nDesça empurrando o quadril para trás — sem arredondar a lombar.'),

  -- =========================================================================
  -- SHOULDERS (18) — 8 from 00007 + 3 from 00014 + 7 from 00019
  -- =========================================================================

  ('overhead_press',
    'Desenvolvimento com Barra',
    'O desenvolvimento de ombros principal com barra. Constrói deltoide anterior e lateral com participação de tríceps e peito superior.',
    E'Pegue a barra um pouco mais aberto que os ombros.\nEmpurre direto para cima, levando a cabeça levemente para trás.\nFinalize com a barra alinhada sobre o meio do pé.\nMantenha o core firme — sem inclinar muito para trás.'),

  ('push_press',
    'Push Press',
    'Variação do desenvolvimento que usa impulso de pernas para mover cargas pesadas, construindo força e potência.',
    E'Comece com a barra na posição frontal de rack.\nFlexione levemente os joelhos e exploda para cima.\nUse a inércia para empurrar a barra até a extensão total.\nDesça a barra com controle de volta ao rack frontal.'),

  ('dumbbell_shoulder_press',
    'Desenvolvimento com Halteres',
    'Desenvolvimento sentado ou em pé com halteres, permitindo arco natural e trabalho independente dos braços.',
    E'Comece com os halteres na altura dos ombros, palmas para frente.\nEmpurre para cima e levemente para dentro sem batê-los no topo.\nDesça até a altura das orelhas ou um pouco abaixo.\nMantenha o core firme para não arquear a lombar.'),

  ('arnold_press',
    'Arnold Press',
    'Desenvolvimento com halteres que parte com palmas voltadas para você e gira para a frente, trabalhando todas as cabeças do deltoide.',
    E'Comece com os halteres na altura do queixo, palmas para você.\nGire as palmas para frente conforme empurra para cima.\nInverta a rotação na descida.\nUse movimento suave e controlado — sem apressar a rotação.'),

  ('lateral_raise',
    'Elevação Lateral',
    'O isolamento clássico para ombros mais largos. Trabalha a cabeça lateral do deltoide.',
    E'Fique em pé com leve inclinação à frente no quadril.\nEleve os halteres pelos lados até os braços ficarem paralelos ao chão.\nLidere com os cotovelos, não com as mãos.\nDesça devagar — sem soltar a carga.'),

  ('front_raise',
    'Elevação Frontal',
    'Isolamento para o deltoide anterior. Útil para volume extra quando o trabalho de empurrar não basta.',
    E'Fique em pé segurando os halteres à frente das coxas.\nEleve um ou os dois braços até a altura dos ombros, com leve flexão de cotovelo.\nDesça com controle — sem balançar.\nAlterne os braços ou suba os dois ao mesmo tempo.'),

  ('rear_delt_fly',
    'Crucifixo Invertido',
    'Isolamento com halteres para o deltoide posterior. Essencial para ombros equilibrados e boa postura.',
    E'Incline o tronco à frente até quase paralelo ao chão.\nEleve os halteres pelos lados, liderando com os cotovelos.\nContraia as escápulas no topo do movimento.\nUse cargas leves com forma estrita — são músculos pequenos.'),

  ('cable_face_pull',
    'Face Pull no Cabo',
    'Exercício no cabo para deltoide posterior e rotadores externos. Excelente para saúde dos ombros e postura.',
    E'Posicione o cabo na altura do rosto com uma corda.\nPuxe a corda em direção ao rosto, com cotovelos altos e abertos.\nGire externamente até os punhos apontarem para o teto.\nContraia o deltoide posterior e segure brevemente antes de voltar.'),

  ('upright_row',
    'Remada Alta',
    'Puxada vertical com a barra rente ao tronco que trabalha deltoide lateral e trapézio superior em amplitude curta.',
    E'Pegue a barra na largura dos ombros com pegada pronada.\nPuxe a barra direto para cima, liderando com os cotovelos.\nPare quando os cotovelos chegarem na altura dos ombros — passar disso pode causar impacto no ombro.\nDesça a barra com controle até as coxas.'),

  ('machine_shoulder_press',
    'Desenvolvimento na Máquina',
    'Desenvolvimento na máquina, que trava você em uma trajetória fixa para empurrar cargas pesadas com segurança.',
    E'Ajuste o assento para as alças ficarem alinhadas com os ombros.\nSegure as alças e empurre acima da cabeça sem travar com força.\nMantenha as escápulas firmes contra o encosto.\nDesça as alças até o topo dos ombros.'),

  ('cable_lateral_raise',
    'Elevação Lateral no Cabo',
    'Elevação lateral no cabo que mantém tensão constante no deltoide lateral em toda a amplitude.',
    E'Fique de lado para a polia baixa segurando a alça com uma mão.\nEleve o braço pelo lado até a altura do ombro.\nLidere com o cotovelo, mantendo leve flexão.\nDesça com controle — resista ao cabo na volta.'),

  ('barbell_shrug',
    'Encolhimento com Barra',
    'Encolhimento com barra que carrega o trapézio superior pela elevação simples dos ombros.',
    E'Segure a barra à frente das coxas com pegada na largura dos ombros.\nEncolha os ombros direto para cima em direção às orelhas.\nSegure brevemente no topo para sentir a contração do trapézio.\nDesça com controle — sem deixar a barra cair.'),

  ('dumbbell_shrug',
    'Encolhimento com Halteres',
    'Encolhimento com halteres ao lado do corpo, permitindo um alongamento maior que o da barra.',
    E'Segure um halter em cada mão ao lado do corpo.\nEncolha os ombros direto para cima o mais alto possível.\nMantenha os braços relaxados — sem flexionar os cotovelos.\nDesça devagar até o alongamento total antes da próxima rep.'),

  ('cable_rear_delt_fly',
    'Crucifixo Invertido no Cabo',
    'Crucifixo invertido no cabo que mantém tensão constante no deltoide posterior pelo arco do movimento.',
    E'Ajuste duas polias na altura dos ombros e cruze os cabos.\nSegure a alça oposta em cada mão na linha do centro.\nAbra os braços em arco amplo até a altura do peito.\nContraia o deltoide posterior e volte devagar.'),

  ('cable_front_raise',
    'Elevação Frontal no Cabo',
    'Elevação frontal no cabo que isola o deltoide anterior com tensão constante em todo o arco.',
    E'Fique de costas para uma polia baixa segurando a alça.\nEleve o braço à frente até a altura do ombro.\nMantenha leve flexão no cotovelo — sem travar.\nDesça a alça devagar, resistindo ao cabo.'),

  ('reverse_pec_deck',
    'Pec Deck Invertido',
    'Crucifixo invertido na máquina que isola o deltoide posterior com apoio de peito e trajetória fixa.',
    E'Ajuste o assento para as alças ficarem na altura dos ombros.\nPressione o peito firme contra a almofada o tempo todo.\nLeve as alças para trás em arco amplo, liderando com os cotovelos.\nContraia as escápulas atrás e volte devagar.'),

  ('landmine_shoulder_press',
    'Desenvolvimento Landmine',
    'Desenvolvimento com a barra encaixada no landmine, que gera um arco seguro de empurrar para o deltoide anterior.',
    E'Fique em base escalonada com a ponta da barra no ombro.\nEmpurre a barra para cima e levemente cruzando a linha do centro.\nMantenha o core firme — não incline muito para trás.\nDesça a barra com controle até a posição inicial no ombro.'),

  ('kettlebell_press',
    'Desenvolvimento com Kettlebell',
    'Desenvolvimento com Kettlebell que desafia a estabilidade do ombro com a carga deslocada contra o antebraço.',
    E'Faça o clean do Kettlebell até o rack com o sino atrás do antebraço.\nEmpurre direto para cima até travar o braço acima da cabeça.\nMantenha o core firme — sem arquear a lombar.\nDesça o sino de volta ao rack com controle total.'),

  -- =========================================================================
  -- ARMS (25) — 10 from 00007 + 5 from 00014 + 10 from 00019
  -- =========================================================================

  ('barbell_curl',
    'Rosca Direta com Barra',
    'A rosca clássica para bíceps. Trabalha as duas cabeças do bíceps com cargas pesadas usando barra.',
    E'Fique com os pés na largura dos ombros, pegada na largura dos ombros.\nFlexione os cotovelos para subir a barra — sem balançar o corpo.\nContraia os bíceps no topo.\nDesça com controle até a extensão total dos braços.'),

  ('ez_bar_curl',
    'Rosca com Barra W',
    'Rosca com barra W (cambada) que reduz o estresse no punho e trabalha os bíceps com eficácia.',
    E'Pegue a barra nas curvaturas para uma posição natural do punho.\nMantenha os cotovelos colados ao tronco o tempo todo.\nSuba até a contração total e desça devagar.\nEvite inclinar para trás ou usar impulso.'),

  ('skull_crusher',
    'Tríceps Testa',
    'Isolamento de tríceps deitado no banco, descendo a barra em direção à testa e estendendo de volta.',
    E'Deite com os braços estendidos segurando a barra acima do peito.\nDesça a barra em direção à testa flexionando só os cotovelos.\nMantenha os úmeros perpendiculares ao chão.\nEstenda até a extensão total, contraindo o tríceps no topo.'),

  ('dumbbell_curl',
    'Rosca com Halteres',
    'Rosca clássica com halteres que permite supinação total para a contração máxima do bíceps.',
    E'Comece com os braços ao lado do corpo, palmas para frente.\nSuba os dois halteres mantendo os cotovelos parados.\nSupine (gire as palmas para cima) ao subir para a contração máxima.\nDesça com controle até a extensão total.'),

  ('hammer_curl',
    'Rosca Martelo',
    'Rosca com pegada neutra que trabalha o braquial e o braquiorradial para braços mais grossos.',
    E'Segure os halteres em pegada neutra, palmas voltadas uma para a outra.\nSuba sem rotacionar os punhos.\nMantenha os cotovelos colados ao tronco.\nDesça devagar — o braquial responde bem à fase excêntrica lenta.'),

  ('concentration_curl',
    'Rosca Concentrada',
    'Rosca unilateral sentada que isola o bíceps ao apoiar o cotovelo na parte interna da coxa.',
    E'Sente em um banco com o cotovelo apoiado na parte interna da coxa.\nSuba o halter contraindo o bíceps no topo.\nDesça devagar até quase a extensão total.\nNão se incline para trás nem use o ombro.'),

  ('dumbbell_tricep_extension',
    'Extensão de Tríceps com Halter',
    'Extensão de tríceps sobre a cabeça com halter, que trabalha a porção longa em alongamento total.',
    E'Segure um halter acima da cabeça com as duas mãos sob a anilha de cima.\nDesça atrás da cabeça flexionando só os cotovelos.\nMantenha os úmeros junto às orelhas e parados.\nEstenda até a extensão total, contraindo o tríceps no topo.'),

  ('tricep_pushdown',
    'Tríceps na Polia',
    'Isolamento de tríceps no cabo. Empurre a alça para baixo via extensão do cotovelo, com tensão constante.',
    E'Fique ereto com os cotovelos colados ao tronco.\nEmpurre a alça para baixo até estender por completo.\nContraia o tríceps embaixo.\nVolte devagar — sem deixar a pilha bater.'),

  ('cable_curl',
    'Rosca no Cabo',
    'Rosca no cabo que mantém tensão constante em toda a amplitude para isolar o bíceps.',
    E'Fique de frente para a polia baixa com barra reta ou W.\nFlexione os cotovelos para subir, mantendo os úmeros parados.\nContraia no topo e desça com controle.\nNão se incline para trás — mantenha o tronco ereto.'),

  ('dips',
    'Paralelas',
    'Exercício com peso do corpo que trabalha tríceps, peito inferior e deltoide anterior. Pode levar carga em cinto para progredir.',
    E'Segure as barras com os braços travados para se sustentar.\nIncline para frente para enfatizar o peito ou ereto para o tríceps.\nDesça até os úmeros ficarem paralelos ao chão.\nEmpurre para a extensão total sem balançar.'),

  ('preacher_curl',
    'Rosca Scott',
    'Rosca com barra no banco Scott que trava os úmeros e isola o bíceps.',
    E'Ajuste o banco para as axilas ficarem no topo da almofada.\nPegue a barra na largura dos ombros, palmas para cima.\nSuba a barra com controle — sem usar impulso de ombro.\nDesça devagar até quase a extensão total e inverta.'),

  ('incline_dumbbell_curl',
    'Rosca Inclinada com Halteres',
    'Rosca com halteres deitado em banco inclinado, colocando o bíceps em posição alongada.',
    E'Ajuste o banco entre 45 e 60 graus e deite-se.\nDeixe os braços estendidos para baixo com palmas para frente.\nSuba os halteres mantendo os cotovelos atrás do tronco.\nDesça até a extensão total para o alongamento.'),

  ('close_grip_bench_press',
    'Supino Pegada Fechada',
    'Supino com pegada fechada que desloca a carga para o tríceps, ainda trabalhando peito e deltoide anterior.',
    E'Pegue a barra próximo à largura dos ombros, sem fechar demais.\nEncoste os cotovelos no tronco ao descer.\nDesça a barra ao peito inferior e empurre até a extensão.\nMantenha os punhos alinhados sobre os cotovelos.'),

  ('overhead_tricep_extension',
    'Extensão de Tríceps Overhead no Cabo',
    'Extensão de tríceps no cabo sobre a cabeça com corda, que enfatiza a porção longa em alongamento profundo.',
    E'Fique de costas para a pilha com a corda segurada acima da cabeça.\nMantenha os cotovelos apontados para frente, junto às orelhas.\nEstenda os braços por completo só nos cotovelos.\nDesça atrás da cabeça até sentir o alongamento do tríceps.'),

  ('rope_pushdown',
    'Tríceps na Corda',
    'Tríceps no cabo com corda que permite separar as pontas embaixo para uma contração mais forte.',
    E'Pegue a corda com os polegares para cima, cotovelos colados ao tronco.\nEmpurre para baixo até as pontas passarem das coxas.\nContraia o tríceps brevemente na extensão total.\nVolte com controle — sem balançar.'),

  ('spider_curl',
    'Rosca Aranha',
    'Rosca estrita feita de bruços em banco inclinado, que trava os braços e elimina o impulso.',
    E'Deite de bruços em banco inclinado com um halter em cada mão.\nDeixe os braços pendurados retos com as palmas para frente.\nSuba os halteres sem balançar os ombros.\nDesça devagar até a extensão total para o alongamento.'),

  ('zottman_curl',
    'Rosca Zottman',
    'Rosca com halteres que gira de supinada para pronada no topo, treinando bíceps e braquiorradial.',
    E'Comece com os braços ao lado do corpo, palmas para frente.\nSuba os halteres até a altura do ombro com palmas para cima.\nNo topo, gire as palmas para baixo.\nDesça em pegada pronada e gire de volta embaixo.'),

  ('reverse_curl',
    'Rosca Inversa',
    'Rosca com pegada pronada na barra que treina braquiorradial e antebraço junto com o bíceps.',
    E'Pegue a barra na largura dos ombros, palmas para baixo.\nMantenha os cotovelos colados ao tronco o tempo todo.\nSuba a barra sem balançar o tronco.\nDesça devagar até a extensão total dos braços.'),

  ('wrist_curl',
    'Rosca de Punho',
    'Exercício de antebraço que treina os flexores do punho, rolando o halter com as palmas voltadas para cima.',
    E'Sente em um banco com os antebraços apoiados nas coxas, palmas para cima.\nDeixe os halteres rolarem até a ponta dos dedos.\nFlexione os punhos para subir o peso.\nMova só os punhos — antebraços fixos nas coxas.'),

  ('reverse_wrist_curl',
    'Rosca de Punho Inversa',
    'Exercício de antebraço que treina os extensores do punho, levantando o halter com as palmas para baixo.',
    E'Sente com os antebraços apoiados nas coxas, palmas para baixo.\nDeixe os halteres pendurarem na borda dos joelhos.\nLevante o peso estendendo só os punhos.\nDesça devagar com controle entre as repetições.'),

  ('farmer_s_walk',
    'Caminhada do Fazendeiro',
    'Caminhada com halteres pesados que constrói força de pegada, contração de core e condicionamento geral.',
    E'Levante um halter pesado em cada mão com pegada firme.\nFique ereto com os ombros para trás e o peito para cima.\nCaminhe em passos curtos e firmes mantendo a carga estável.\nApoie os halteres com controle ao final de cada série.'),

  ('cable_hammer_curl',
    'Rosca Martelo no Cabo',
    'Rosca com corda no cabo em pegada neutra que treina braquial e bíceps com tensão constante.',
    E'Prenda uma corda na polia baixa com palmas voltadas uma para a outra.\nMantenha os cotovelos colados ao tronco o tempo todo.\nSuba a corda sem rotacionar os punhos.\nDesça devagar — sem deixar a pilha bater.'),

  ('bench_dip',
    'Mergulho no Banco',
    'Tríceps em que se mergulha atrás de um banco com os pés no chão ou elevados para progredir.',
    E'Sente em um banco com as mãos na borda ao lado do quadril.\nAvance os pés para o quadril ficar à frente do banco.\nDesça flexionando os cotovelos até cerca de 90 graus.\nEmpurre para cima sem travar os cotovelos com força.'),

  ('close_grip_push_up',
    'Flexão Pegada Fechada',
    'Flexão com as mãos próximas, deslocando a carga para o tríceps e a parte interna do peito.',
    E'Posicione as mãos sob o peito na largura dos ombros ou mais fechadas.\nMantenha os cotovelos próximos das costelas na descida.\nDesça até o peito quase tocar as mãos.\nEmpurre para cima sem abrir os cotovelos.'),

  ('jm_press',
    'JM Press',
    'Híbrido de supino e extensão que carrega a porção longa do tríceps com cargas de barra.',
    E'Deite em banco reto com pegada fechada na barra.\nDesça a barra flexionando os cotovelos para dentro.\nDeixe a barra descer perto do pescoço como um Skull Crusher misturado.\nEstenda até o lockout, contraindo o tríceps.'),

  -- =========================================================================
  -- CORE (23) — 7 from 00007 + 4 from 00014 + 12 from 00019
  -- =========================================================================

  ('plank',
    'Prancha',
    'Exercício isométrico de core que constrói resistência em abdômen, oblíquos e estabilizadores profundos.',
    E'Apoie o corpo em antebraços e pontas dos pés em linha reta.\nContraia os glúteos e o core como se fosse levar um soco.\nNão deixe o quadril cair nem subir.\nRespire de forma constante — sem prender o ar.'),

  ('hanging_leg_raise',
    'Elevação de Pernas Suspenso',
    'Exercício avançado de core que trabalha o abdômen inferior elevando as pernas pendurado em uma barra.',
    E'Pendure-se na barra com pegada na largura dos ombros.\nSuba as pernas enrolando a pelve, não só levantando os joelhos.\nControle a descida — sem balançar.\nEvite usar impulso e faça uma pausa breve embaixo.'),

  ('crunches',
    'Abdominal',
    'Abdominal clássico que trabalha o abdômen superior pela flexão da coluna.',
    E'Deite de costas com os joelhos flexionados e os pés no chão.\nApoie as mãos atrás da cabeça — sem puxar o pescoço.\nEnrole a parte superior das costas contraindo o abdômen.\nDesça devagar e repita sem soltar os ombros por completo.'),

  ('ab_rollout',
    'Roda Abdominal',
    'Exercício anti-extensão de core com a roda ou barra que constrói força e estabilidade do abdômen.',
    E'Ajoelhe em uma almofada e segure a roda ou barra.\nRole para frente estendendo o quadril com os braços retos.\nVá até onde conseguir controlar sem soltar a lombar.\nVolte contraindo o abdômen, não os flexores do quadril.'),

  ('russian_twist',
    'Giro Russo',
    'Exercício de rotação para o core que trabalha os oblíquos. Feito sentado com um peso, girando o tronco lado a lado.',
    E'Sente com os joelhos flexionados e incline-se levemente para trás.\nSegure um peso na altura do peito e gire de um lado para o outro.\nGire pelo tronco, não só pelos braços.\nLevante os pés para mais dificuldade ou apoie no chão para facilitar.'),

  ('dead_bug',
    'Dead Bug',
    'Exercício anti-extensão deitado de costas. Treina o abdômen a resistir à extensão lombar sob carga.',
    E'Deite de costas com braços e pernas apontados para o teto.\nDesça devagar o braço e a perna opostos em direção ao chão.\nMantenha a lombar firme contra o chão.\nVolte ao início e alterne os lados com controle.'),

  ('cable_woodchop',
    'Woodchop no Cabo',
    'Exercício de rotação no cabo que trabalha os oblíquos e constrói força rotacional do core.',
    E'Posicione o cabo na altura do ombro e fique de lado para a polia.\nPuxe a alça em diagonal, cruzando o corpo como um machado.\nGire pelo tronco mantendo os braços relativamente retos.\nControle a volta — sem deixar o cabo voltar com tranco.'),

  ('bicycle_crunch',
    'Abdominal Bicicleta',
    'Variação de abdominal com torção, em que cada repetição treina o abdômen superior e os oblíquos.',
    E'Deite de costas com as mãos leves atrás das orelhas.\nLeve um joelho ao peito girando o cotovelo oposto em direção a ele.\nAlterne os lados em ritmo constante sem puxar o pescoço.\nMantenha a lombar firme contra o chão durante todo o movimento.'),

  ('cable_crunch',
    'Abdominal no Cabo',
    'Abdominal ajoelhado no cabo que carrega o abdômen pesado pela flexão da coluna com a corda.',
    E'Ajoelhe de frente para a pilha com a corda perto da testa.\nArredonde a coluna descendo os cotovelos em direção ao quadril.\nMantenha o quadril parado — o movimento é só na coluna.\nVolte devagar até o abdômen alongar de novo.'),

  ('pallof_press',
    'Pallof Press',
    'Exercício anti-rotação no cabo em que se resiste à torção, construindo estabilidade profunda do core.',
    E'Fique de lado para o cabo na altura do peito.\nEmpurre a alça em linha reta à frente do esterno.\nResista à puxada do cabo — sem deixar o tronco rotacionar.\nSegure por uma respiração e volte para repetir.'),

  ('side_plank',
    'Prancha Lateral',
    'Prancha de antebraço de lado que treina oblíquos e estabilizadores laterais do core de forma isométrica.',
    E'Apoie em um antebraço com o cotovelo sob o ombro.\nEmpilhe os pés e levante o quadril em linha reta.\nContraia glúteos e oblíquos para manter a linha firme.\nTroque de lado após a série para trabalho equilibrado.'),

  ('sit_up',
    'Abdominal Completo',
    'Abdominal de amplitude total subindo até a posição sentada, treinando abdômen e flexores do quadril em arco longo.',
    E'Deite de costas com os joelhos flexionados e os pés no chão.\nCruze os braços no peito ou mantenha as mãos leves atrás da cabeça.\nEnrole até a posição sentada contraindo o abdômen.\nDesça devagar — sem se jogar para trás.'),

  ('mountain_climber',
    'Escalador',
    'Prancha dinâmica em que os joelhos vêm alternadamente em direção ao peito, treinando o core e elevando a frequência cardíaca.',
    E'Comece em prancha alta com as mãos sob os ombros.\nLeve um joelho ao peito sem subir o quadril.\nAlterne as pernas rapidamente em ritmo constante de corrida.\nMantenha o corpo em linha reta da cabeça aos calcanhares.'),

  ('toe_touch',
    'Toque nos Pés',
    'Exercício deitado em que os braços alcançam os pés, treinando o abdômen superior por uma flexão curta da coluna.',
    E'Deite de costas com as pernas retas apontadas para o teto.\nEstique as duas mãos em direção aos dedos dos pés.\nEnrole os ombros do chão contraindo o abdômen.\nDesça com controle — sem puxar o pescoço.'),

  ('hollow_body_hold',
    'Hollow Body Hold',
    'Sustentação isométrica de core em formato de banana rasa, que treina contração profunda do abdômen.',
    E'Deite de costas com os braços estendidos acima da cabeça e pernas retas.\nFirme a lombar plana contra o chão.\nEleve os ombros e as pernas alguns centímetros do chão.\nSegure a posição estável — respire sem soltar a lombar.'),

  ('v_up',
    'V-Up',
    'Abdominal de corpo inteiro em que braços e pernas sobem para se encontrar no meio, atingindo toda a parede abdominal.',
    E'Deite de costas com braços estendidos acima da cabeça e pernas retas.\nLevante braços e pernas ao mesmo tempo até se encontrarem sobre o quadril.\nLeve as mãos em direção às canelas no topo.\nDesça com controle sem deixar os calcanhares baterem no chão.'),

  ('flutter_kick',
    'Flutter Kick',
    'Exercício deitado em que as pernas batem para cima e para baixo continuamente, construindo resistência do abdômen inferior.',
    E'Deite de costas com as mãos sob a lombar para apoio.\nEleve as duas pernas alguns centímetros do chão.\nAlterne uma perna para cima e outra para baixo em movimentos curtos.\nMantenha a lombar firme contra o chão durante todo o exercício.'),

  ('reverse_crunch',
    'Abdominal Reverso',
    'Variação de abdominal que enrola a pelve em direção às costelas, atingindo a parte inferior do abdômen.',
    E'Deite de costas com os joelhos flexionados e os pés elevados.\nEnrole o quadril do chão contraindo o abdômen inferior.\nLeve os joelhos em direção ao peito no topo de cada rep.\nDesça o quadril devagar — sem deixá-lo bater no chão.'),

  ('leg_raise',
    'Elevação de Pernas',
    'Exercício deitado em que as pernas retas sobem e descem, treinando abdômen inferior e flexores do quadril.',
    E'Deite de costas com as mãos sob a lombar.\nEleve as duas pernas retas em direção ao teto.\nDesça devagar até quase encostar no chão.\nMantenha a lombar firme contra o chão durante todo o movimento.'),

  ('windshield_wiper',
    'Limpador de Para-brisa',
    'Exercício rotacional em que as pernas varrem de um lado para o outro em arco controlado, treinando os oblíquos.',
    E'Deite de costas com os braços abertos e as pernas apontadas para cima.\nDesça as pernas juntas para um lado sem encostar no chão.\nInverta e desça para o lado oposto com controle.\nMantenha os ombros firmes no chão durante todo o movimento.'),

  ('plank_up_down',
    'Prancha Sobe e Desce',
    'Prancha dinâmica que alterna entre antebraços e mãos, treinando core e estabilizadores do ombro.',
    E'Comece em prancha de antebraço com o corpo em linha reta.\nSuba para uma mão e depois para a outra até a prancha alta.\nDesça de volta para os antebraços, um braço por vez.\nMantenha o quadril o mais parado possível durante o movimento.'),

  ('heel_touch',
    'Toque no Calcanhar',
    'Abdominal curto para oblíquos em que as mãos tocam os calcanhares a partir da posição de joelhos flexionados.',
    E'Deite de costas com os joelhos flexionados e os pés no chão.\nLevante levemente os ombros do chão.\nEstique a mão para tocar o calcanhar do mesmo lado.\nAlterne os lados em ritmo constante sem soltar os ombros.'),

  ('kettlebell_windmill',
    'Moinho com Kettlebell',
    'Hip hinge com rotação segurando um Kettlebell acima da cabeça, treinando estabilidade de ombro e força de oblíquo.',
    E'Empurre um Kettlebell acima da cabeça com um braço e trave o cotovelo.\nMantenha os olhos no Kettlebell durante todo o movimento.\nFlexione o quadril levando a mão livre em direção ao pé oposto.\nInverta o movimento até voltar a ficar ereto com o Kettlebell no alto.'),

  -- =========================================================================
  -- BANDS (3) — all from 00007
  -- =========================================================================

  ('band_pull_apart',
    'Band Pull-Apart',
    'Exercício com Bands para deltoide posterior e trapézio médio. Ótimo para aquecimento e saúde do ombro.',
    E'Segure a faixa na altura do peito com os braços estendidos à frente.\nAbra a faixa contraindo as escápulas.\nMantenha os braços retos ou com leve flexão de cotovelo.\nVolte devagar — sem deixar a faixa voltar com tranco.'),

  ('band_face_pull',
    'Face Pull com Faixa',
    'Versão com Bands do Face Pull que trabalha deltoide posterior e rotadores externos para saúde do ombro.',
    E'Ancore a faixa na altura do rosto.\nPuxe em direção ao rosto, com cotovelos altos e abertos.\nGire externamente na posição final.\nVolte com controle em cadência lenta.'),

  ('band_squat',
    'Agachamento com Faixa',
    'Agachamento com faixa elástica nas coxas ou sob os pés para tensão extra.',
    E'Pise sobre a faixa com os pés na largura dos ombros.\nSegure a faixa na altura do ombro ou passe nas coxas.\nAgache pelo menos até paralelo, empurrando os joelhos contra a faixa.\nSuba empurrando pelos calcanhares.'),

  -- =========================================================================
  -- KETTLEBELL (3) — all from 00007
  -- =========================================================================

  ('kettlebell_swing',
    'Kettlebell Swing',
    'Hip hinge balístico que constrói potência explosiva em glúteos, posteriores e core.',
    E'Flexione o quadril e balance o Kettlebell entre as pernas.\nLeve o quadril à frente para projetar o sino até a altura do peito.\nMantenha os braços relaxados — a potência vem do quadril, não dos ombros.\nContraia o core no topo de cada balanço.'),

  ('kettlebell_goblet_squat',
    'Agachamento Goblet com Kettlebell',
    'Variação de agachamento segurando o Kettlebell na altura do peito. Excelente para profundidade e força de quadríceps.',
    E'Segure o Kettlebell pelas alças laterais na altura do peito.\nSente entre as pernas com cotovelos por dentro dos joelhos.\nDesça em profundidade total mantendo o tronco ereto.\nSuba pelos calcanhares, contraindo os glúteos no topo.'),

  ('kettlebell_turkish_get_up',
    'Levantamento Turco com Kettlebell',
    'Movimento complexo de corpo inteiro com Kettlebell que desenvolve força total, coordenação e estabilidade.',
    E'Comece deitado de costas com o Kettlebell empurrado acima da cabeça.\nMantenha os olhos no Kettlebell durante todo o movimento.\nLevante-se passando por uma série de transições controladas.\nInverta os passos para voltar à posição inicial.'),

  -- =========================================================================
  -- CARDIO (5) — all from 00014
  -- =========================================================================

  ('treadmill',
    'Esteira',
    'Corrida ou caminhada em ritmo constante ou intervalado na esteira motorizada, que constrói base aeróbica e condicionamento.',
    E'Suba com a esteira parada e comece em ritmo de caminhada.\nOlhe para frente, não para os pés, para uma passada natural.\nPise com o meio do pé sob o quadril, não à frente.\nUse a presilha de emergência para parar a esteira em caso de queda.'),

  ('rowing_machine',
    'Remo Ergométrico',
    'Remo ergométrico sentado que treina toda a cadeia posterior e gera forte condicionamento cardiovascular.',
    E'Trave os pés nos apoios e segure a alça com as duas mãos.\nPuxe primeiro com as pernas, depois incline o tronco e por fim os braços.\nInverta a sequência na volta: braços, tronco e por fim pernas.\nMantenha as costas retas — sem arredondar ao se inclinar à frente.'),

  ('stationary_bike',
    'Bicicleta Ergométrica',
    'Bicicleta ergométrica sentada ou ereta que oferece cardio de baixo impacto com controle fácil de resistência.',
    E'Ajuste o assento para o joelho ficar levemente flexionado embaixo.\nMantenha as mãos relaxadas no guidão — sem levantar os ombros.\nPedale em círculos suaves em vez de socar para baixo.\nAumente a resistência para subidas ou intervalos quando precisar.'),

  ('jump_rope',
    'Pular Corda',
    'Treino com corda que constrói resistência de panturrilha, agilidade e eleva a frequência cardíaca rapidamente em pouco espaço.',
    E'Dimensione a corda para as alças chegarem nas axilas pisando nela.\nMantenha os cotovelos colados ao tronco e gire pelos punhos.\nPule só alguns centímetros do chão a cada passagem.\nFique na ponta dos pés — os calcanhares não tocam o chão.'),

  ('elliptical',
    'Elíptico',
    'Máquina em pé que move os pés em trajetória elíptica, oferecendo cardio de corpo inteiro com baixo impacto.',
    E'Suba com os dois pés firmes e segure as alças móveis.\nEmpurre com as pernas e puxe-empurre com os braços ao mesmo tempo.\nMantenha o tronco ereto — sem se debruçar sobre o painel.\nInverta o sentido de tempos em tempos para alternar os músculos.')

) AS v(slug, name, description, form_tips)
ON e.slug = v.slug
WHERE e.is_default = true;

-- Hard assert: every default exercise has a pt-BR translation row.
-- If the count diverges, a slug below is missing or misspelled vs.
-- 00030's literal map.
DO $$
DECLARE
  pt_count INT;
  default_count INT;
BEGIN
  SELECT COUNT(*) INTO pt_count
    FROM exercise_translations
    WHERE locale = 'pt';
  SELECT COUNT(*) INTO default_count
    FROM exercises
    WHERE is_default = true;
  IF pt_count <> default_count THEN
    RAISE EXCEPTION
      'pt seed incomplete: % rows in exercise_translations vs % defaults in exercises',
      pt_count, default_count;
  END IF;
END
$$;

COMMIT;
