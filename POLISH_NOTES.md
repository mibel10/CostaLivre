# Revisão dos carros e polimento

## Problemas corrigidos

- **Carroceria aparentemente oca:** o modelo original usa painéis de duas faces. A conversão de materiais estava descartando `cull_mode`, escondendo o verso dos painéis. A configuração original foi preservada, e piso, bancos, painel e estrutura interna foram mantidos no modelo próximo.
- **Rodas deformadas e oscilando:** a escala não uniforme alongava os pneus; as rodas também herdavam a direção e a rotação usadas na apresentação do modelo de origem. Agora a escala é uniforme, os cubos começam alinhados e o giro fica num nó separado do esterçamento. O eixo não inclina enquanto gira. A rotação acompanha o deslocamento real, em vez da velocidade desejada contra uma parede.
- **Acabamento dos materiais:** mapas de metal/roughness e transformações UV preservados; aros menos estourados e mais geometria na carroceria próxima para conservar as curvas. O modelo distante continua agrupado em duas superfícies.
- **Pose ao entrar no carro:** entrar durante a rolagem limpa a rotação e o deslocamento visual do personagem.
- **Roda de armas:** seleção coincide com os setores desenhados, tem zona neutra central e centraliza o cursor ao abrir. Voltar de outra janela restaura a captura do mouse quando o jogo está ativo.
- **Áudio:** passos e sirenes usam canais separados dos efeitos, evitando cortar recompensas e socos. Passos só tocam no chão, fora da rolagem, e as sirenes próximas têm volume pela distância. Os canais pausam com o jogo.
- **Veículos destruídos:** continuam sujeitos à gravidade, em vez de congelar no ar.
- **Menu de contratos:** ignorados eventos de repetição automática das setas ao trocar páginas.

## Otimizações

Animações dos pedestres distantes e do personagem oculto no carro são suspensas. Transformações das rodas só são atualizadas perto da câmera; a física e o ângulo acumulado continuam ativos, sem afetar direção ou colisões. Os ajustes visuais foram gerados novamente nos assets locais.

## Medição no PC

Teste com o mesmo script e cenas do benchmark anterior, apenas **Baixo**, sem limite e sem V-Sync, viewport **1028×720**, Intel Core i5-4210U / Intel HD Graphics Family.

| Cena | Antes | Após esta revisão |
| --- | ---: | ---: |
| Rua | 38,0 FPS | 41,3 FPS |
| Banco | 52,2 FPS | 64,3 FPS |
| Perseguição | 32,2 FPS | 43,5 FPS |
| Média geral | 40,8 FPS | 49,7 FPS |
| 1% low geral | 21,0 FPS | 25,7 FPS |

Amostras curtas de aproximadamente seis segundos por cena, após aquecimento. A comparação inclui variação normal entre rodadas e não garante o mesmo ganho em toda situação nem mínimo absoluto de 30 FPS. Dados novos em `benchmark_polish.json`; os dados anteriores foram preservados em `benchmark_all_presets.json`.

## Verificação

`tests/vehicle_polish.gd` verifica materiais de duas faces, escala uniforme, eixos de giro e direção, entrada após rolagem, independência dos canais de áudio e suspensão de animações distantes. As imagens `preview_car_front.png`, `preview_car_rear.png` e `preview_car_side.png` permitem conferir o modelo de perto. Os testes de direção, contratos, rolagem e interiores também foram executados.

Para repetir somente a medição no Baixo:

```powershell
& 'caminho/para/Godot_console.exe' --path . --script res://tools/benchmark_all_presets.gd -- --low-only
```
