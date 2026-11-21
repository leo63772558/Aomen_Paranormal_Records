import base64
import msvcrt
from pathlib import Path


OUTPUT = Path("assets/tilesets/ch3_archive_room_open_032.generated.png")

print("READY", flush=True)
characters: list[str] = []
while True:
	character = msvcrt.getwch()
	if character in ("\r", "\n"):
		break
	characters.append(character)

OUTPUT.write_bytes(base64.b64decode("".join(characters)))
print("SAVED", len(characters), flush=True)
