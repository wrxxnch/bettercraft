# Mineclonia Trap API (Atualizada)

Esta API permite a criação de blocos de "trap" que usam automaticamente a textura superior de um bloco existente.

## Como usar

Agora você só precisa passar o nome do bloco base:

```lua
mcl_traps.register_trap(name, description, base_node)
```

### Parâmetros:
- `name`: Nome interno do node (ex: "fragile_dirt").
- `description`: Nome visível no jogo.
- `base_node`: O bloco original de onde a textura e o material de crafting serão extraídos (ex: "mcl_core:dirt").

### Crafting
A receita é gerada automaticamente usando o `base_node`:
- `xx` (Bloco Base)
- `ss` (Stick)

## Exemplos

```lua
-- Cria uma trap que parece terra e usa terra no craft
mcl_traps.register_trap("dirt_trap", "Armadilha de Terra", "mcl_core:dirt")

-- Cria uma trap que parece pedra
mcl_traps.register_trap("stone_trap", "Armadilha de Pedra", "mcl_core:stone")
```
