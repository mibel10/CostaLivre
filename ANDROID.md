# Android

## APK pronto

Arquivo: `build/android/costa-livre.apk`. Pacote: `com.costalivre.game`, versao 1.0.1 (codigo 2). APK de teste assinado com a chave de debug local. Compativel com Android 7/API 24 ou posterior, ARM de 32 ou 64 bits e OpenGL ES 3.0. A interface de toque so e criada no Android.

## Instalar no celular pelo USB

1. No celular, abra Configuracoes > Sobre o telefone e toque sete vezes em Numero da versao (em alguns aparelhos fica em Informacoes de software).
2. Abra Opcoes do desenvolvedor e ative Depuracao USB.
3. Conecte ao PC com cabo de dados, desbloqueie a tela e aceite Permitir depuracao USB.
4. No PC, execute o ADB do SDK:

```powershell
& "$env:LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" devices -l
& "$env:LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" install -r build/android/costa-livre.apk
```

O aparelho deve aparecer como `device`. Se aparecer `unauthorized`, aceite a autorizacao na tela do telefone. Se nao aparecer, confira o cabo, a porta USB e o modo Transferencia de arquivos. O comando `install -r` atualiza a instalacao existente; nenhuma desinstalacao automatica e executada. Se houver conflito de assinatura, preserve os dados antes de decidir remover uma versao antiga.

Tambem e possivel copiar o APK para Downloads no celular e abri-lo no gerenciador de arquivos, autorizando a instalacao por essa fonte quando o Android pedir.

## Recompilar

Os templates oficiais Godot 4.7.2 estao configurados como templates personalizados em `.build-tools/godot-4.7.2/`, sem exigir a instalacao na pasta global do editor. Para baixar novamente: `python tools/fetch_android_templates.py`. A origem e os hashes locais estao em `.build-tools/godot-4.7.2/manifest.json`.

Exportacao:

```powershell
Godot_console.exe --headless --path . --export-debug Android build/android/costa-livre.apk
```

O projeto usa Compatibility, tela horizontal e importacao de texturas ETC2/ASTC. Java e SDK Android ja foram encontrados nas configuracoes locais do Godot. A exportacao e a verificacao da assinatura foram concluidas neste PC. O APK foi instalado via ADB e aberto no celular conectado; o processo permaneceu ativo e em primeiro plano, sem erros de script na consulta inicial ao log do app. Ainda nao foi realizado um playthrough nem benchmark no aparelho. Detalhes do arquivo e hash SHA-256 estao em `build/android/build-info.json`. Para publicacao, use uma chave de release propria, guardada com seguranca, em vez da chave de debug.

Controles: analogico esquerdo move/dirige, arrasto livre olha, botoes executam as acoes. Menus nativos aceitam toque; contratos, lojas e hack possuem botoes numericos. Voltar fecha menus/cancela o hack ou abre a pausa. Alternar de aplicativo pausa a partida e libera comandos mantidos. Windows e Linux continuam com teclado e mouse.

Guia oficial: https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html

## Posicao dos controles de toque

Na pausa, abra **Controles > Mudar posicao dos controles**. Arraste os botoes redondos ou o analogico; toque em **SALVAR** para manter o arranjo. **RESTAURAR** mostra as posicoes padrao e **CANCELAR** desfaz a edicao atual. O jogo permanece pausado no editor e as posicoes ficam em `user://touch_layout.cfg`. Os icones sao SVGs locais, sem depender de emojis ou fontes do telefone. A escala e uniforme para manter os botoes redondos em telas largas.
