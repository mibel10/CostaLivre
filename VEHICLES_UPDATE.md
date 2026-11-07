# Veículos e correções

Os novos modelos são originais, procedurais e estilizados. Estão estacionados na cidade e nas páginas 2 e 3 da concessionária APEX. Na APEX, use F para abrir, setas para trocar de página e 1–3 para comprar; no Android existem botões de página na tela.

| Modelo | Categoria | Preço | Velocidade com turbo, sem melhoria |
| --- | --- | ---: | ---: |
| Cometa R | Supercarro com frente em cunha e faixa | $9500 | 252 km/h |
| Eclipse V12 | Supercarro comprido com entradas laterais | $12000 | 281 km/h |
| Raio RS | Supercarro largo com aerofólio | $15000 | 299 km/h |
| Bairro Compact | Hatch comum | $1200 | 122 km/h |
| Litoral LX | Sedã comum | $1800 | 151 km/h |
| Falcão 600 | Moto | $3200 | 209 km/h |

A moto usa condução arcade: duas rodas, esterçamento dianteiro, inclinação visual nas curvas e piloto procedural sentado enquanto dirige. O colisor permanece vertical para manter a moto estável. Usa os mesmos comandos de entrada, saída e oficina dos carros; a marcha a ré é limitada a 5 m/s.

## Correções e custo

- Os nomes, limites de velocidade, aceleração e colisores vêm de um catálogo comum. Novos índices de modelo não aumentam a velocidade sem limite.
- A concessionária tem três páginas, mantém os três carros anteriores e compra o modelo correto em cada opção. A navegação também está disponível no toque.
- Recolorir conserva quantidade de rodas, direção, colisor e tipo de veículo; veículos destruídos precisam ser reparados antes de receber pintura ou motor.
- A carroceria é agrupada por material, preservando rodas independentes. Corrigido o agrupamento de malhas procedurais sem índices e com atributos diferentes, que ocultava painéis.
- Pneus e aros usam materiais distintos, sem comparação direta entre números de precisão diferente.
- Veículos estacionados mantêm suas colisões, mas deixam de repetir consultas ao chão a cada quadro de física. Rodas usam sombras simplificadas, e as carrocerias novas têm poucas superfícies.

## Verificação

Capturas dos seis modelos foram inspecionadas em janela real em `artifacts/fleet/model_4.png` até `model_9.png`. Os testes cobrem os seis modelos, rodas, aceleração, piloto e saída da moto, pintura e compra por página. Também foram executadas verificações de garagem, jogo livre, direção e os 17 objetivos da campanha.

Benchmark no Intel HD Graphics Family / ANGLE, viewport 1028 × 720, preset Baixo, sem limite e sem V-Sync: aquecimento mínimo de 5 segundos/60 quadros e aproximadamente 6 segundos de coleta por cenário.

| Cenário | FPS médio |
| --- | ---: |
| Rua | 42,4 |
| Banco | 49,5 |
| Perseguição | 39,2 |
| Geral | 43,7 |
| 1% low geral | 26,1 |

Dados completos: `benchmark_fleet.json`. São amostras curtas da versão com a nova frota, não uma comparação controlada que isole cada otimização. Ainda há quedas abaixo de 30 FPS. A pequena revisão posterior dos materiais de pintura/vidro preserva sua iluminação ao mudar de preset; ela passou pelos testes de lógica, mas não teve outra rodada de benchmark.

Para repetir: `Godot_console.exe --path . --script res://tools/benchmark_all_presets.gd -- --low-only --fleet`.
