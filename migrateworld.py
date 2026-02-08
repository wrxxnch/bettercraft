import os
import sys

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
GAMES_DIR = os.path.join(BASE_DIR, "games")
WORLDS_DIR = os.path.join(BASE_DIR, "worlds")


def abort(msg):
    print("ERROR:", msg)
    input("Press ENTER to exit...")
    sys.exit(1)


if not os.path.isdir(GAMES_DIR):
    abort('Folder "games" not found')

if not os.path.isdir(WORLDS_DIR):
    abort('Folder "worlds" not found')


games = sorted(
    d for d in os.listdir(GAMES_DIR)
    if os.path.isdir(os.path.join(GAMES_DIR, d))
)

if not games:
    abort("No games found")

print("==============================")
print(" MIGRATE WORLDS - GAMEID")
print("==============================")
print()

for i, game in enumerate(games, 1):
    print(f"{i} - {game}")

print()
try:
    choice = int(input("Choose game number: "))
    GAMEID = games[choice - 1]
except:
    abort("Invalid option")

print("\nSelected game:", GAMEID)
print()


count = 0

for world in sorted(os.listdir(WORLDS_DIR)):
    world_path = os.path.join(WORLDS_DIR, world)
    world_mt = os.path.join(world_path, "world.mt")

    if not os.path.isfile(world_mt):
        continue

    print("Updating:", world)

    lines = []
    found = False

    with open(world_mt, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if line.strip().startswith("gameid"):
                lines.append(f"gameid = {GAMEID}\n")
                found = True
            else:
                lines.append(line)

    if not found:
        lines.append("\ngameid = " + GAMEID + "\n")

    with open(world_mt, "w", encoding="utf-8") as f:
        f.writelines(lines)

    count += 1

print("\nDone.")
print(count, "worlds updated.")
input("\nPress ENTER to exit...")
