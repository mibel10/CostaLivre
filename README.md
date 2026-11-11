# Costa Livre

Costa Livre é um jogo de mundo aberto em versão antecipada, com exploração, direção, campanha, modo livre e multiplayer entre PC e Android. Desenvolvido por Mibel10, do Calado Studios.

## Preparar o projeto

1. Clone o repositório e entre na pasta do projeto:

   ```sh
   git clone https://github.com/mibel10/CostaLivre.git
   cd CostaLivre
   ```

2. Instale o **Godot 4.7.2 stable** e os export templates da mesma versão. O projeto usa o renderizador GL Compatibility. No editor, importe o `project.godot` e aguarde a importação dos recursos.
3. Instale os templates em **Editor > Manage Export Templates**. Os presets incluem caminhos para templates personalizados em `.build-tools/godot-4.7.2/`, pasta gerada que pode não existir em um clone. Em **Project > Export**, selecione cada preset e limpe os campos **Custom Template** de debug e release que apontarem para arquivos inexistentes; o Godot usará os templates instalados. Como alternativa, forneça nesses campos os templates corretos da mesma versão do editor.

Para executar no editor, pressione F6 para a cena atual ou F5 para iniciar o projeto.

## Exportar para Windows

No editor, abra **Project > Export**, selecione **Windows Desktop**, escolha **Export Project** e salve como `CostaLivre.exe`. A exportação gera um `CostaLivre.pck` separado: distribua os dois arquivos juntos, na mesma pasta. O preset é para Windows x86-64; não há presets Linux ou macOS configurados.

Pelo PowerShell, na pasta do projeto, com `godot_console.exe` no PATH:

```powershell
New-Item -ItemType Directory -Force build/windows | Out-Null
godot_console.exe --headless --path . --editor --quit
godot_console.exe --headless --path . --export-release "Windows Desktop" build/windows/CostaLivre.exe
```

A primeira execução importa os recursos; consulte a [documentação de exportação do Godot](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html) para outras plataformas e comandos.

## Exportar para Android

1. Instale **OpenJDK 17** e o Android SDK com as ferramentas e plataformas exigidas pela sua versão do Godot. No editor, configure **Editor > Editor Settings > Export > Android**: informe **Java SDK Path** e **Android SDK Path**. Veja os componentes e instruções atuais na [documentação oficial de Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html).
2. Configure a chave de debug no editor, caso ainda não exista. Em **Project > Export > Android**, confira os templates conforme a seção de preparação.
3. Para um APK de teste, selecione **Export Project**, mantenha **Export With Debug** marcado e salve como `costa-livre.apk`. O preset suporta dispositivos ARM de 32 e 64 bits.
4. Para distribuição de produção, configure uma keystore de release própria no preset, mantenha a chave e a senha privadas e desmarque **Export With Debug**. Guarde a chave: atualizações do aplicativo precisam ser assinadas com a mesma chave.

Para gerar um APK de debug pelo PowerShell, após configurar o editor e os templates:

```powershell
New-Item -ItemType Directory -Force build/android | Out-Null
godot_console.exe --headless --path . --editor --quit
godot_console.exe --headless --path . --export-debug "Android" build/android/costa-livre.apk
```

Para instalar num celular com depuração USB autorizada e Android Platform Tools no PATH:

```powershell
adb devices
adb install -r build/android/costa-livre.apk
```

Se já houver uma instalação com o mesmo nome de pacote assinada por outra chave, o Android pode recusar a atualização. Remover a instalação antiga permite instalar a nova, mas pode apagar os dados locais do jogo: faça backup antes.

## Multiplayer

PC e Android precisam usar builds com o mesmo protocolo multiplayer. A versão do projeto é `1.5.2`; o protocolo é definido em `scripts/build_version.gd`. Gere os dois builds a partir do mesmo commit para manter a compatibilidade.
