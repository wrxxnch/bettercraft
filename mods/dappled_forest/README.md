# Dappled Forest para Mineclonia / MineClone

Este mod adiciona a **Dappled Forest (Floresta Salpicada)**, a madeira **Poplar (Álamo)** e uma **Hay Bed (cama de feno)**. O registro da madeira segue o contrato de `mcl_trees.register_wood` usado pelo exemplo de Cherry, enquanto o registro de geração fica separado em `lg_register.lua`.

## Instalação

Copie a pasta `dappled_forest` para o diretório `mods` do mundo ou do jogo Mineclonia/MineClone e habilite o mod no mundo. As dependências obrigatórias são `mcl_core`, `mcl_trees` e `mcl_beds`; `mcl_levelgen`, `mcl_flowerpots` e `mcl_shelves` são opcionais.

## Conteúdo

A madeira Poplar registra tronco, tronco descascado, tábuas, folhas, muda, estante, porta, alçapão, cerca, portão, placa suspensa e muda envasada. O bioma usa terra com grama, terra, clima temperado-frio e umidade de floresta, com o ID `dappled_forest`.

A Hay Bed é uma entidade colocável fina, com 0,2 nó de altura e base tocando o chão, aceita a receita de três blocos de feno sobre três blocos de madeira e usa `mcl_cozy.lay`, a lógica do Get Comfortable, para deitar o jogador. Ela não é um bloco nem define spawn. A textura visual e a textura do item são lidas diretamente de `mcl_farming:hay_block`, portanto resource packs continuam funcionando sem duplicar assets.

As texturas Poplar incluídas vêm dos assets oficiais 26.3 publicados no [MC Asset Cloud](https://mcasset.cloud/26.3/assets/minecraft/textures/block): `poplar_log`, `poplar_log_top`, `stripped_poplar_log`, `stripped_poplar_log_top`, `poplar_planks`, `poplar_sapling`, `poplar_shelf`, `poplar_door_bottom`, `poplar_door_top`, `poplar_trapdoor` e `orange_poplar_leaves`. A textura de tábuas também foi substituída pela imagem Poplar enviada pelo usuário. As texturas de feno `hay_block_side` e `hay_block_top` foram baixadas da mesma fonte; a cama reutiliza a definição de `mcl_farming:hay_block` para continuar compatível com resource packs.

Os inventários de `poplar_boat`, `poplar_door`, `poplar_sign`, `poplar_chest_boat` e `poplar_hanging_sign` foram adicionados em `textures/` a partir de `assets/minecraft/textures/item/` da versão 26.3. O registro Poplar usa explicitamente as imagens de barco, barco com baú, porta e placa; a imagem de placa suspensa fica disponível para o registrador de sinais da versão do jogo.

O diretório `schematics/` inclui `poplar_tree_orange.mts`, `poplar_tree_red.mts` e `poplar_tree_yellow.mts`, schematics MTS v4 conectados ao campo `tree_schems` do registro Poplar. Eles contêm tronco e copa com folhas sazonais correspondentes.

Também foram registradas as folhas sazonais `mcl_trees:leaves_poplar_red` e `mcl_trees:leaves_poplar_yellow`, usando respectivamente `dappled_forest_red_poplar_leaves.png` e `dappled_forest_yellow_poplar_leaves.png`. Os schematics `schematics/poplar_tree_red.mts` e `schematics/poplar_tree_yellow.mts` usam esses nós, e os três arquivos (`poplar_tree_orange.mts`, `poplar_tree_red.mts` e `poplar_tree_yellow.mts`) estão listados no `tree_schems` do Poplar.
