# Benchmark dos cinco presets

Medicao local da versao atual, com modo sandbox, cidade ampliada, seis interiores, nuvens, trafego variado e pedestres. Godot 4.7.2, renderizador Compatibility, janela real (nao headless), V-Sync e limite de FPS desativados.

- CPU: Intel Core i5-4210U @ 1,70 GHz. GPU: Intel HD Graphics Family via ANGLE / Direct3D 11.
- Viewport: 1028 x 720. Cada preset usa cena nova e mede rua, banco e perseguicao. Cada cena aquece por pelo menos 5 s e 60 quadros; coleta cerca de 6 s.
- O 1% low e calculado pelo tempo medio dos 1% quadros mais lentos. Amostras curtas variam com carga e temperatura.

| Qualidade | Media geral | 1% low | Rua | Banco | Perseguicao |
| --- | ---: | ---: | ---: | ---: | ---: |
| Batata | 43,3 | 21,8 | 38,4 | 51,9 | 39,7 |
| Baixo | 38,2 | 9,7 | 34,1 | 46,9 | 33,5 |
| Medio | 18,6 | 14,6 | 17,2 | 21,1 | 17,5 |
| Alto | 16,6 | 12,8 | 15,5 | 18,7 | 15,5 |
| Ultra | 16,0 | 12,4 | 14,8 | 18,7 | 14,5 |

FPS em todas as celulas. Neste computador, Batata teve a maior media; nenhum preset manteve 30 FPS em todos os quadros. Baixo ficou acima de 30 FPS em media nos tres cenarios, mas seu 1% low mostra quedas. Medio ou superior ficou abaixo de 30 FPS de media.

A primeira rodada teve uma pausa de carregamento atipica na amostra de rua em Medio. A tabela usa a repeticao completa, com aquecimento ampliado; a pausa nao se repetiu. Os dados brutos da repeticao estao em [benchmark_all_presets.json](benchmark_all_presets.json).

Reproduza com: `Godot_console.exe --path . --script res://tools/benchmark_all_presets.gd` (sem `--headless`). O script inicia sandbox, seleciona cada preset e nao modifica as preferencias salvas.
