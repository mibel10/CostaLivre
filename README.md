# CostaLivre

CostaLivre é um jogo de mundo aberto com exploração, direção e missões.
Inclui campanha, sandbox e multiplayer, com crossplay entre PC e Android.

## Requisitos
- O projeto declara a funcionalidade Godot 4.3; os templates configurados estão em `.build-tools/godot-4.7.2/`.
- Versão exata do editor Godot: A confirmar.
- Android SDK, NDK e JDK e suas versões: A confirmar.

## Compilar para Windows
1. Abra o projeto no Godot Editor.
2. Em **Project > Export**, selecione **Windows Desktop** e exporte o projeto.
3. O preset define `build/windows/CostaLivre.exe`. `binary_format/embed_pck=false`, então mantenha também o arquivo `.pck` gerado junto ao executável.

Não há presets de exportação Linux ou macOS configurados.

## Compilar e instalar no Android
1. No Godot Editor, em **Project > Export**, selecione **Android** e exporte o projeto.
2. O preset define o APK em `build/android/costa-livre.apk`.
3. Com o celular conectado e a depuração USB ativada, instale pelo Android Platform Tools: `adb install -r build/android/costa-livre.apk`.
4. O preset marca o pacote como assinado; keystore e credenciais de assinatura: A confirmar.

## Créditos
Programador e Designer: Mibel10

Estúdio: Calado Studios
