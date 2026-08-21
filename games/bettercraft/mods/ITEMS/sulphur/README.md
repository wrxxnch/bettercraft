# Sulphur Update

Mod para **BetterCraft**, o jogo baseado em Mineclonia para Luanti. Ele adiciona uma camada vulcânica e química ao subsolo, com enxofre, cinábrio, gêiseres, fumaça sulfurosa e um slime cujo comportamento muda conforme o bloco colocado dentro dele.

## Instalação

Copie a pasta `sulphur_update` para `games/bettercraft/mods/` dentro da instalação do BetterCraft. Como este mod usa as APIs de `mcl_core`, `mcl_mobs` e `mcl_potions`, ele deve ser ativado em um mundo BetterCraft, não em um mundo criado com o Minetest Game padrão.

## Conteúdo

Esta versão usa como referência os sprites de [Sulfur](https://minecraft.wiki/w/Sulfur), [Cinnabar](https://minecraft.wiki/w/Cinnabar), [Sulfur Cube](https://minecraft.wiki/w/Sulfur_Cube), [Bucket of Sulfur Cube](https://minecraft.wiki/w/Bucket_of_Sulfur_Cube) e [Music Disc Bounce](https://minecraft.wiki/w/Music_Disc_Bounce). Os arquivos de textura dos assets solicitados foram incluídos no pacote. **Slabs, stairs e walls foram deliberadamente ignorados nesta etapa e serão adicionados depois.**

## Modelos OBJ/MTL do Sulfur Spike

Os nós usam os nomes exatos dos modelos fornecidos. Coloque os pares OBJ/MTL na pasta `models/` do mod, sem renomear os arquivos. Os modelos registrados são `sulfur_spike.obj`/`.mtl`, `sulfur_spike_down_base.obj`/`.mtl`, `sulfur_spike_down_frustum.obj`/`.mtl`, `sulfur_spike_down_middle.obj`/`.mtl`, `sulfur_spike_down_tip_merge.obj`/`.mtl`, `sulfur_spike_down_tip.obj`/`.mtl`, `sulfur_spike_up_base.obj`/`.mtl`, `sulfur_spike_up_frustum.obj`/`.mtl`, `sulfur_spike_up_middle.obj`/`.mtl`, `sulfur_spike_up_tip_merge.obj`/`.mtl` e `sulfur_spike_up_tip.obj`/`.mtl`. Cada arquivo OBJ deve manter sua referência `mtllib` para o MTL correspondente.

| Conteúdo | Comportamento |
|---|---|
| Bloco de enxofre | Bloco amarelo, material de construção e ingrediente para tijolos. |
| Minério de enxofre | Geração subterrânea em pedra e deepslate; dropa pó de enxofre. |
| Estalactite de enxofre | Nó decorativo não caminhável, apropriado para cavernas. |
| Cinábrio | Bloco vermelho de construção, com textura baseada na wiki. |
| Cinábrio talhado | Variante talhada do cinábrio. |
| Cinábrio polido | Variante polida do cinábrio. |
| Tijolos de cinábrio | Variante decorativa do cinábrio. |
| Enxofre potente | Variante concentrada do enxofre. |
| Enxofre | Bloco amarelo de construção, com textura baseada na wiki. |
| Enxofre talhado | Variante talhada do enxofre. |
| Enxofre polido | Variante polida do enxofre. |
| Tijolos de enxofre | Variante decorativa do enxofre. |
| Espinho de enxofre | Nó decorativo pontiagudo. |
| Gêiser de enxofre | Emite partículas quentes, luz fraca e pulsos sonoros periodicamente. |
| Fumaça de enxofre na água | Deve ficar sobre uma fonte de água; a área causa náusea periodicamente. |
| Cubo de enxofre | Pode ser invocado pelo Spawn Egg, receber blocos com clique direito e ser coletado em um bucket. |
| Bucket of Sulfur Cube | Guarda e reposiciona um cubo de enxofre grande. |
| Music Disc Bounce | Disco integrado à jukebox; usa o registro sonoro disponível na base quando o áudio original não está presente. |
| Sulfur Cube Spawn Egg | Ovo de spawn com sprite da wiki. |

## Slime mutável

Segure um bloco e clique com o botão direito no **Slime de enxofre**. O bloco é consumido, exceto no modo criativo, e o slime passa a exibir o nome do material armazenado.

| Material inserido | Efeito aplicado |
|---|---|
| Madeira | Menor velocidade, menor gravidade e saltos mais elásticos, como uma bola de plástico. |
| Rocha ou bloco com grupo de picareta | Maior gravidade, menor velocidade e salto reduzido; o slime fica pesado. |
| Gelo ou bloco com grupo `ice` | Velocidade muito maior e movimento escorregadio/rápido. |
| Enxofre | Comportamento padrão, mantendo o perfil equilibrado. |

A classificação usa grupos de nós, então madeiras, rochas e gelos compatíveis com Mineclonia também funcionam, não apenas os blocos adicionados por este mod.

## Teste rápido

Depois de ativar o mod, use o inventário criativo ou os comandos de concessão da base para obter os itens. Para testar o slime, obtenha o ovo de spawn `sulphur_update:sulphur_slime_spawn_egg`, coloque um gêiser e observe os pulsos de partículas. Para testar a fumaça, coloque `sulphur_update:sulphur_smoke` diretamente acima de uma fonte de água e permaneça próximo por alguns segundos.

## Compatibilidade

A implementação foi escrita para a árvore `wrxxnch/luanti-bettercraft` e usa a nomenclatura de nós e as APIs de Mineclonia presentes nessa base. A sintaxe Lua foi validada antes do empacotamento; a validação dentro do jogo deve ser feita em uma cópia de teste do mundo.

## Licença

O código novo deste mod é distribuído sob MIT. A base BetterCraft/Mineclonia e seus assets continuam sujeitos às licenças próprias dos respectivos projetos.
