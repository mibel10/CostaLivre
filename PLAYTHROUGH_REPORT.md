# Revisão de percurso — 6 de novembro de 2026

## Como foi verificado

Percurso automatizado em janela real do Godot, com comandos de movimento, direção, frenagem e interação. Entre áreas, o roteiro reposiciona o personagem. Ele percorreu as entradas dos seis interiores, resolveu os três circuitos do banco, recolheu os malotes, saiu para receber o dinheiro e abriu o mapa durante a perseguição. As sequências do hack foram lidas pelo roteiro para verificar as regras de progressão.

Separadamente, `tests/campaign_complete.gd` verificou os **17 capítulos** pelas regras dos objetivos: entregas, roubo, carro encomendado, corrida, destruição dos alvos, banco, fuga, rotas e tarefas nos interiores, incluindo transições das cenas e encerramento. Esse teste usa posicionamento direto nos objetivos e avanço controlado da simulação; não representa uma campanha percorrida manualmente do começo ao fim.

O roteiro reproduzível está em `tools/playthrough.gd`. Capturas e dados da primeira rodada estão em `artifacts/playthrough/before_*.png` e `artifacts/playthrough/before.json`. A pasta tem `.gdignore` para que os registros não se tornem assets do jogo.

## Problemas encontrados e alterações

- **Mapa:** a lista de nomes tinha três entradas para seis interiores. Abrir o mapa produziu `Invalid access of index '3'` durante o percurso. Agora os seis nomes vêm da mesma lista usada pelas fachadas.
- **Câmera nos interiores:** no café, a parede acima da porta cobria a parte superior da tela. O enquadramento agora fica mais perto e mais baixo dentro dos ambientes. Uma esfera de colisão protege o volume da câmera, incluindo as cenas cinematográficas.
- **Entrada no veículo:** o personagem aparecia na porta e se deslocava de volta à sua posição anterior. Agora começa onde estava e vai para a porta mais próxima. A saída acompanha o lado disponível e a orientação do veículo.
- **Reparo:** recuperar os pontos de vida não removia a aparência cinza de veículo destruído. O reparo agora restaura os materiais anteriores, inclusive pintura e vidros.
- **Interiores incoerentes:** a oficina tinha mesas de café e o mercado tinha camas de clínica. Agora têm bancada, ferramentas e armário, ou balcão e prateleiras de produtos. Os pisos receberam cores próprias.
- **Controles:** sair da página de remapeamento cancela a captura de tecla pendente. Também foram corrigidos textos que apareciam com `?` no lugar de acentos.
- **Custo dos Fuscas:** as partes estáticas da carroceria foram agrupadas por material em cinco superfícies. As rodas continuam independentes para girar e esterçar. Os arcos dos para-lamas compartilham a mesma malha, e as rodas usam a sombra simplificada já existente no carro. A geometria visual foi mantida; o ganho de FPS após essa alteração ainda não foi medido.

## Medições anteriores às correções

Intel HD Graphics Family via ANGLE/D3D11, viewport **1028 × 720**, qualidade **Baixo**, V-Sync desligado e FPS sem limite. Cada ponto teve 2 segundos de aquecimento e aproximadamente 3 segundos de coleta. São amostras curtas de uma rodada, sujeitas a variações de tráfego, carregamento e temperatura.

| Área | FPS médio | Tempo de quadro p95 (ms) | Chamadas de desenho no fim da amostra |
| --- | ---: | ---: | ---: |
| Spawn | 40,8 | 31,9 | 172 |
| Café | 32,1 | 45,6 | 216 |
| Clínica | 48,9 | 27,6 | 150 |
| Apartamento | 37,6 | 33,4 | 220 |
| Oficina do porto | 46,6 | 28,8 | 119 |
| Mercado da praia | 49,5 | 32,4 | 81 |
| Estúdio | 49,9 | 27,8 | 130 |
| Banco | 49,1 | 29,1 | 131 |
| Avenida costeira | 67,9 | 23,7 | 31 |
| Avenida leste | 76,1 | 21,5 | 28 |
| Centro | 40,4 | 34,8 | 140 |
| Perseguição | 43,8 | 42,4 | 68 |

O café apresentou a menor média e o maior p95 nessa rodada. As áreas centrais e o apartamento também merecem atenção. Os valores não garantem 30 FPS constantes.

A primeira checagem curta de caminhada do roteiro ficou abaixo do deslocamento mínimo esperado. Os testes independentes de movimentação passaram. O roteiro foi ajustado para aquecer a cena e começar essa checagem numa faixa livre da rua; essa versão ainda não foi repetida em janela.

## Conferência após as alterações

Passaram, sem janela: `playthrough_regressions.gd`, `campaign_complete.gd`, `smoke.gd`, `character_polish.gd`, `vehicle_polish.gd`, `city_life.gd` e `bank_flow.gd`. A checagem final de regressões inclui rótulos do mapa, agrupamento da carroceria, restauração dos materiais, entrada/saída, enquadramento da câmera no interior e cancelamento da captura de teclas.

A nova execução em janela foi recusada nas permissões da sessão. Portanto, **não há capturas posteriores nem comparação de FPS antes/depois**. Os ajustes de câmera e decoração precisam dessa última conferência visual. Para repetir após autorizar a abertura do Godot:

```powershell
Godot_console.exe --path . --script res://tools/playthrough.gd -- --tag=after
```
