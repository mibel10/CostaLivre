# Multiplayer

A tela tem duas abas: **Salas locais** e **Pela internet**.

## Mesmo Wi-Fi

1. Um jogador escolhe **Criar sala local**.
2. Os outros abrem **Salas locais** e tocam em **Procurar salas locais**.
3. Selecionam uma sala na lista e tocam em **Entrar na sala selecionada**. A lista mostra ocupacao ate 12 jogadores e remove salas expiradas.

## Internet / dispositivos em lugares diferentes

1. O anfitriao abre **Pela internet** e escolhe **Criar sala internet**.
2. Aguarda aparecer o codigo e toca em **Copiar meu codigo**.
3. Envia o codigo inteiro ao amigo. O amigo cola no campo **Cole aqui o codigo de internet** e toca em **Entrar com este codigo**.

O codigo de internet comeca com `CL1-` e tem tres grupos de sete letras/numeros, alem do prefixo. Ele inclui IPv4, porta e codigo curto da sala, com verificacao contra erros de digitacao. Letras minusculas tambem sao aceitas. O endereco nao precisa ser digitado separadamente. Os cinco caracteres antigos continuam identificando salas locais; um codigo curto isolado nao descobre salas pela internet.

Convites antigos `CL://IP:porta/CODIGO` ainda funcionam no campo de entrada. Em **Opcoes avancadas**, e possivel informar IP/porta e codigo curto manualmente. A preparacao UPnP continua em segundo plano.

A sala aceita o anfitriao e onze convidados. O anfitriao precisa manter o jogo aberto. A solicitacao UPnP tem duracao de uma hora, e e renovada enquanto a sala permanece aberta; o jogo tenta remove-la ao desconectar/sair.

Nao ha cadastro, servico de descoberta global nem retransmissao. O convite inclui o endereco porque um codigo isolado de cinco caracteres nao permite localizar o anfitriao pela internet sem uma agenda externa de salas. Conexao direta depende do firewall e do acesso publico ao anfitriao. CGNAT, duplo NAT e roteadores sem encaminhamento podem impedir a conexao; nesse caso e necessario outro anfitriao acessivel ou uma solucao de sinalizacao/retransmissao. Um retorno positivo do UPnP nao confirma que a porta e acessivel de outra rede.

Na rede local, **Criar sala local** continua permitindo entrada somente pelo codigo. Usa UDP 28961 para descoberta, sem enviar as salas para um servico externo.

Versao 1.3.0: PC e Android usam o mesmo protocolo; a autenticacao recusa versoes diferentes antes de liberar RPCs. O anfitriao controla inventarios, dinheiro, vida, danos, recompensas e atividades. Ha um contrato cooperativo por sala: qualquer jogador pode avancar e todos recebem a recompensa. Banco, hack, malotes, lojas, compra e pintura de carros sao compartilhados. O procurado e da equipe, com viaturas e policiais perseguindo jogadores proximos. A campanha sequencial e o salvamento de campanha continuam individuais.

Verificacoes no PC: formato dos convites, porta/codigo, deteccao de faixas privadas/CGNAT, descoberta UDP, entrada por convite direto entre duas instancias, avatares, posicoes e desconexao. Nao foram verificados doze aparelhos, UPnP no roteador real ou uma conexao entre duas redes externas. Nao foram realizados testes no celular.

Referencia: https://docs.godotengine.org/en/4.3/classes/class_upnp.html

# Gráficos e desempenho

Os presets continuam disponíveis. Texturas, sombras, antialiasing, distância e relevo podem ser escolhidos separadamente e são persistidos. Alterar uma opção muda o indicador para **Personalizado**. Texturas têm níveis original, 1024, 512 e 256 pixels, com mipmaps e cache das variantes.

Há 32 pedestres de rua, além dos nove contatos/funcionários. A quantidade simulada e desenhada perto do jogador é limitada conforme o preset; os demais ficam suspensos fora do alcance. Os modelos remotos também são ocultados à distância.

Foi corrigida a consulta de colisões contra arrays tipados, que gerava erros repetidos ao tocar o cenário. Não foi medida uma nova taxa de FPS com esta atualização.

## Nome, roupa e nametags

No inicio, use **Nome e roupa**; durante o jogo, abra **Pausa > Personagem**. Escolha um nome de ate vinte caracteres e uma das seis combinacoes, depois use **Salvar nome e roupa**. As escolhas ficam em `user://profile.cfg` por dispositivo. A troca preserva o rig, a animacao e a arma na mao.

Nomes e roupas sao enviados para a sala e atualizados nos outros jogadores. As nametags acompanham o personagem ou veiculo, respeitam paredes e distancia. A propria nametag fica oculta enquanto mira.

## Atualizacao 1.2.0

A delegacia em (105,21) substitui um predio fechado. Cinco viaturas saem do patio quando despachadas e retornam ao encerrar a busca. Movimento de plataformas foi desativado nos veiculos, e posicoes verticais anormais recuperam o ultimo ponto no chao. Veiculos compartilham IDs estaveis, inclusive compras e carros de missao.

Uma eliminacao PvP paga $1500 ao autor uma vez por vida da vitima. Renascimento automatico em cerca de tres segundos, distribuido entre doze pontos do mapa, com cinco segundos de protecao PvP. Vida, armas e carteira sao individuais. Pausar nao congela a sala.

Verificado no PC com duas instancias em mundos de fisica separados: recusa de versao, procurado e viaturas, estabilidade no chao, contrato interno cooperativo, recompensas, tiros e eliminacoes nos dois sentidos, renascimento, compra de carro, oficina e invasao completa do banco. Nao houve teste de carga com doze aparelhos, partida entre redes externas ou teste de gameplay no celular.

## Atualizacao 1.3.0

Protocolo 3: salas recusam clientes de versoes diferentes. Tres missoes cooperativas de infiltracao foram adicionadas na torre comercial de oito andares, com convites aceitos/recusados, minijogo de hack em tres circuitos, furtividade e cutscenes sincronizadas. Z agacha no PC; o Android tem botao movel/redimensionavel. Carros destruidos queimam cinco segundos e explodem com dano de area autoritativo do anfitriao. A policia agora acompanha jogadores remotos, atira a partir de nivel de busca 12 e pode abordar jogadores parados/a pe. Raycasts policiais sao atualizados a cada 0,2 s. Exportado para Windows e Android; sem benchmark de FPS nesta versao.
