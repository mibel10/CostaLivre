# Costa Livre

Protótipo original de ação e direção em mundo aberto para **Godot 4.3+**, com renderizador Compatibility. Abra `project.godot` e pressione **F5**.

## Controles

| Tecla | Ação |
| --- | --- |
| WASD / mouse | Mover, dirigir / olhar |
| E | Entrar no carro / saltar para fora mesmo em movimento |
| Q (segurar) | Roda de armas: mova o mouse e solte Q para equipar |
| V / mouse esquerdo sem arma | Soco com animação procedural e dano a curta distância |
| Shift / espaço | Correr ou turbo / pular ou frear |
| Mouse esquerdo / direito | Atirar / mirar com câmera no ombro |
| 1 / 2 / 3 | Pistola / fuzil comprado / guardar arma |
| R | Recarregar usando a munição de reserva |
| F | Abrir loja/oficina ou interagir com painéis e malotes no banco |
| Segurar F | Assaltar mercado (5 s), a pé e armado |
| M | Escolher contratos; setas trocam as três páginas e 1–7 escolhem |
| Ctrl + direção | Rolar; sem direção, rola para a frente da câmera |
| Tab | Abrir / fechar mapa ampliável |
| C | Créditos dos modelos e texturas |
| T | Reposicionar na rua se ficar preso |
| Esc | Pausar / voltar à página inicial da pausa / continuar |
| Enter | Reiniciar depois da derrota |

## Modos de jogo

Ao abrir, escolha **Jogo Livre (sandbox)** para explorar e aceitar qualquer um dos 17 contratos quando quiser, ou **Campanha** para concluir os 17 capitulos na ordem. A campanha salva o proximo capitulo em `user://campaign.cfg`, repete a missao se voce falhar e termina numa tela de encerramento. Cada contrato tem uma cena de abertura e outra de conclusao; qualquer tecla ou clique pula a cena. No sandbox, os contratos continuam opcionais e rejogaveis.

## Atividades

Você começa com $900, uma pistola e munição. O carro laranja está logo à frente. A tela mostra apenas objetivo, dinheiro, radar, vida e a informação de arma ou carro. Os demais controles ficam na pausa; lojas e contratos abrem em menus separados que pausam o jogo.

## Pausa, mapa e gráficos

Pressione **Esc** e use os botões **Continuar**, **Mapa**, **Gráficos e FPS**, **Controles** e **Créditos**. Tudo funciona com mouse e navegação por teclado. Esc volta de uma página à página inicial; na página inicial, continua o jogo.

O mapa tem zoom de **1x a 6x** pela roda do mouse, botões **+ / −** ou teclas **+ / −**. Arraste com o botão esquerdo ou use **WASD / setas** para navegar. **Centralizar / Home** localiza o personagem. O zoom pela roda mantém o ponto sob o cursor. O mapa é recortado ao painel para não cobrir os botões.

As alterações gráficas são aplicadas na hora e salvas em `user://settings.cfg`, incluindo o limite de FPS. O padrão inicial é **Baixo + 30 FPS**. O V-Sync é desativado para que o limite escolhido seja respeitado; selecionar 360 ou sem limite não garante que o computador consiga produzir essa quantidade de quadros.

| Qualidade | Ajustes principais |
| --- | --- |
| Ultra | MSAA 4x, sombras mais distantes, normal maps e detalhes de carros até 85 m |
| Alto | MSAA 2x, sombras e detalhes até 65 m |
| Médio | Sem MSAA, sombras próximas e detalhes até 45 m |
| Baixo | Sem sombras dinâmicas e normal maps, carros simplificados além de 18 m |
| Batata | Iluminação simplificada, sem sombras e normal maps, distância de visão menor e carros simplificados além de 12 m |

Limites disponíveis: **30, 60, 120, 144, 180, 240, 360 FPS e sem limite**. As missões, trânsito, polícia e colisões continuam ativos em todas as qualidades; os ajustes afetam a apresentação visual.

Em **Esc → Gráficos e FPS → Contador de FPS**, escolha **Superior esquerdo**, **Superior direito**, **Inferior esquerdo**, **Inferior direito** ou **Desligado**. A posição é aplicada imediatamente e salva junto das configurações. O contador também aparece nos menus e na tela de derrota.

Para comparar as cinco qualidades no computador, execute `Godot_console.exe --path . --script res://tools/benchmark_all_presets.gd`, sem `--headless`. O script desativa V-Sync e limite de FPS temporariamente, mede rua, banco e perseguição em cada qualidade e grava `benchmark_all_presets.json`. As preferências salvas do jogador não são alteradas.

O resultado da medição atual neste PC está em [BENCHMARK_ALL.md](BENCHMARK_ALL.md).

O polimento e as atualizacoes de conteudo estao em [POLISH_NOTES.md](POLISH_NOTES.md). Os benchmarks atuais dos cinco presets estao em [BENCHMARK_ALL.md](BENCHMARK_ALL.md).

Os dezessete contratos são rejogáveis, divididos em três páginas. Escolher um novo substitui o atual; terminar um contrato permite continuar explorando.

1. **Correio da costa:** pare por 1,5 s nos três destinos; $2400.
2. **Caixa rápido:** assalte o mercado marcado e despiste a polícia; $800 de bônus, além do caixa.
3. **Encomenda de luxo:** roube o Tempestade marcado e entregue na garagem; $3200.
4. **Volta da ilha:** passe por cinco pontos em até 95 s; $2200.
5. **Acerto de contas:** destrua os dois carros marcados e fuja; $2800.
6. **Golpe no banco:** assalte o banco marcado e despiste a polícia; $2000 de bônus, além dos $4000 do cofre.
7. **Procurado:** escape de uma busca alta; $1800.
8. **Tour expresso:** três destinos de carro, incluindo o distrito leste; $1800.
9. **Correio a pé:** três entregas a pé em até 160 segundos; $2200.
10. **Sprint leste:** rota cronometrada de carro pela nova avenida; $2600.
11. **Rota noturna:** três pontos no lado oeste; $3000.
12. **Carga urgente:** atravessar a cidade de carro em até 100 segundos; $3400.
13. **Circuito costeiro:** percurso de carro entre as duas extremidades da cidade; $3800.
14. **Plantão médico:** buscar uma encomenda dentro do café e entregá-la na clínica; $2300.
15. **Reunião marcada:** visitar o café e depois o apartamento para interagir com os contatos; $1700.
16. **Apartamento seguro:** inspecionar três pontos dentro do apartamento; $2600.
17. **Turno do café:** recolher o pedido e servir duas mesas; $1900.

Os quatro contratos novos exigem entrar a pé e usar **F** junto do marcador, não apenas passar de carro. O café fica em (-63,21), a clínica em (63,21) e o apartamento em (-63,63), com entrada pela fachada voltada ao sul (+Z). Aparecem no mapa da pausa e como pontos verdes no radar.

Há oito pedestres andando em trajetos pelas calçadas e três atendentes no banco. Pedestres próximos aceleram quando há uma busca alta; podem receber dano. Os distantes ficam ocultos e suspendem o movimento para poupar processamento. **Ctrl** faz uma rolagem procedural de 0,65 s, com deslocamento e intervalo entre usos; não concede invulnerabilidade nem permite atirar durante a animação.

O banco foi mobiliado com guichês numerados, balcão de madeira, atendentes, cadeiras, colunas, painelamento, monitores na sala de segurança, piso de pedra e gavetas individuais no cofre. A porta possui volante metálico. Os cubos usados como bancos e prateleiras na primeira versão foram removidos. Os interiores continuam construídos com geometria procedural; são ambientes estilizados, com o mesmo hack e assalto jogáveis.

A cidade ganhou duas colunas de quarteirões e avenidas em x = ±168: aproximadamente 29% mais área. O radar mostra quarteirões, lojas, mercados, objetivo e uma linha de direção até ele (não é uma rota calculada pelas ruas).

Além de motor e disparos, há efeitos sintetizados de passos, soco, sirene próxima, recompensa e derrota. Segurar Q desacelera o jogo enquanto escolhe entre punhos, pistola e fuzil comprado. Soltar equipa a escolha. Ao perder, a cena fica em câmera lenta, recebe filtro dessaturado e vinheta, e mostra **VOCÊ FOI CALADO.** Enter reinicia com o tempo normal restaurado.

Mercados e banco também podem ser assaltados fora dos contratos. Cada caixa fica indisponível por 100 segundos depois do roubo. Roubar um carro gera uma estrela: há seis segundos de atraso na resposta, apenas uma viatura lenta e nenhum tiro. Pequenas batidas geram pouco alerta. A busca chega a cinco estrelas, com uma viatura por estrela e até três agentes a pé nos níveis altos. Agentes só atiram acima de três estrelas. A prisão exige nove segundos parado a menos de 4,5 m de um agente que consiga ver você. Afaste-se ou use paredes para quebrar a visão: a busca cai, e as unidades extras se retiram.

## Assalto ao Banco Costa

Escolha **M → 6** para marcar o banco, ou vá até o símbolo `$` ao norte do centro. Há um prédio acessível pela porta da frente; não é mais possível roubá-lo segurando F na rua.

1. Entre a pé e encontre o painel **SEGURANÇA** à esquerda. Pressione **F** para desligá-lo.
2. Vá ao **TERMINAL** à direita e pressione **F**. Memorize a sequência mostrada e repita com as teclas **1–4** quando ela desaparecer. São três circuitos de 3, 4 e 5 dígitos. Cada rodada dá 14 segundos para responder. **Esc** cancela e volta ao jogo; o tempo não é pausado durante o hack.
3. Três erros disparam um alerta e bloqueiam o terminal por 15 segundos. Depois você pode tentar novamente.
4. Com o hack concluído, vá ao painel ao lado do **COFRE** e pressione **F**. A porta se abre fisicamente; o alarme gera três estrelas.
5. Entre no cofre e pressione **F** perto de cada um dos três malotes. Saia pela porta da frente para receber **$4000**. No contrato, despiste a polícia para ganhar mais **$2000**.

O banco se recupera após 100 segundos. O dinheiro só entra na carteira ao sair com os três malotes. A sinalização e o marcador indicam a próxima etapa dentro do prédio.

## Lojas

No mapa, **A** é o Arsenal, **C** é a concessionária APEX e **+** é a oficina. Aproxime-se do ponto físico e pressione **F**. Escolha pelo número.

- **Arsenal:** pistola e munição ($400), fuzil com munição ($1800), reposição de munição ($150).
- **APEX:** Vento GT ($2200), Tempestade ($4800) e Aurora X ($8500), com carroceria baixa, aerofólio e velocidades diferentes. Os carros comprados aparecem na saída da concessionária; libere a vaga antes de comprar outro. Entrar em um carro comprado não aumenta a busca.
- **Oficina:** recupera vida e repara o carro atual por $250.

Há também três supercarros estacionados na avenida norte, que podem ser roubados. Disparos gastam munição e danificam carros ou policiais. Veículos destruídos param de funcionar. Armas só podem ser usadas a pé.

O visual usa modelos 3D detalhados de carros e personagens com animação, texturas fotográficas de asfalto e concreto, normal maps, materiais metálicos e vidro refletivo, céu HDR, neblina de distância e água animada. Os coqueiros têm troncos cilíndricos e folhas curvas. Fachadas têm textura, molduras e divisões de vidro. O renderizador continua Compatibility, com reflexos do céu em baixa resolução e carros otimizados para reduzir o custo na GPU integrada. Não há ray tracing.

Os personagens usam o modelo Cesium Man (traje e capacete), e os veículos compartilham a base Car Concept com cores e proporções adaptadas. São modelos de referência licenciados, não personagens ou veículos de GTA. Créditos completos em `assets/CREDITS.md` e no menu **C** do jogo.

Banco, café, clínica e apartamento possuem interiores acessíveis; os demais prédios são fachadas. A IA dos carros usa ruas em grade; pedestres seguem trajetos nas calçadas. Não há salvamento da campanha; reiniciar começa uma nova sessão.

Os assets já estão incluídos: jogar não exige internet nem executar os scripts da pasta `tools`. Para atualizar os arquivos de origem, use `python tools/fetch_visual_assets.py`, importe pelo editor e rode `Godot_console.exe --headless --path . --script res://tools/bake_visuals.gd`, seguido de `Godot_console.exe --headless --path . --script res://tools/bake_far_car.gd`. O bake reduz a geometria e agrupa materiais uma única vez; o jogo carrega as malhas prontas. Os carros distantes usam uma malha de duas superfícies em vez de todos os materiais do modelo próximo.

O visual é uma base com modelos de referência e materiais mais realistas. Após a otimização, nesta GPU Intel integrada e janela de 1028×720, o preset Baixo mediu **41–65 FPS médios sem limite**, conforme o cenário. Com limite de 30, rua e perseguição mediram **30 FPS médios**, com pequenas variações no tempo de quadro. Isso não é garantia de mínimo absoluto de 30 em toda situação, resolução ou qualidade. Medições e tempos percentis estão em [PERFORMANCE.md](PERFORMANCE.md) e `benchmark_results.json`.

## Verificação

```powershell
& 'caminho/para/Godot_console.exe' --headless --path . --editor --quit
& 'caminho/para/Godot_console.exe' --headless --path . --script res://tests/smoke.gd
& 'caminho/para/Godot_console.exe' --headless --path . --script res://tests/bank_flow.gd
& 'caminho/para/Godot_console.exe' --headless --path . --script res://tests/settings_menu.gd
& 'caminho/para/Godot_console.exe' --path . --script res://tests/preview.gd
& 'caminho/para/Godot_console.exe' --path . --script res://tests/pause_preview.gd
& 'caminho/para/Godot_console.exe' --path . --script res://tools/benchmark_game.gd
```

Os testes cobrem os contratos, banco, polícia e combate, além de navegação da pausa, zoom/pan, cinco qualidades, oito limites, persistência e validação das configurações, restauração de materiais e qualidade aplicada a carros novos. As prévias incluem o mapa ampliado e as configurações. O benchmark precisa de renderização real: não use `--headless` para medir desempenho gráfico.

Suporte Android e controles de toque: veja [ANDROID.md](ANDROID.md).


Nova frota: tres supercarros, dois carros comuns e a moto FalCAO 600; catalogo, controles de compra e medicao recente em [VEHICLES_UPDATE.md](VEHICLES_UPDATE.md).

