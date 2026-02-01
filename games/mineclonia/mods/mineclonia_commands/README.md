# Mineclonia Commands Mod

Este mod adiciona comandos avançados ao Mineclonia/Minetest, inspirados no Minecraft, com suporte a coordenadas relativas e autocomplete.

## Funcionalidades

### 1. Coordenadas Relativas e Locais
- `~~~`: Refere-se à coordenada atual (X, Y, Z).
- `23 ~ 23`: Define X=23, Y=atual, Z=23.
- `^^^6`: Refere-se a 6 blocos à frente da direção que o jogador está olhando.

### 2. Comandos Adicionados

#### `/execute <x> <y> <z> <comando> [args]`
Executa um comando em uma posição específica.
Exemplo: `/execute ~ ~1 ~ say Olá do alto!`

#### `/particle <nome> <x> <y> <z>`
Gera uma partícula na posição especificada.
Exemplo: `/particle heart ~ ~2 ~`

#### `/testfor <jogador>`
Verifica se um jogador está online. Útil para sistemas de automação.

#### `/testforblock <x> <y> <z> <bloco>`
Verifica se o bloco na posição especificada é do tipo informado.
Exemplo: `/testforblock ~ ~-1 ~ mcl_core:stone`

### 3. Autocomplete
Ao digitar o início de um comando (ex: `/exe`), o mod sugerirá os comandos disponíveis no chat caso não sejam completados.

## Instalação
1. Copie a pasta `mineclonia_commands` para o diretório `mods/` do seu mundo ou da pasta do jogo.
2. Ative o mod nas configurações do mundo.
3. Certifique-se de ter o privilégio `server` para usar os comandos.
