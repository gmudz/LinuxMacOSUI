import os
import subprocess
import time
from typing import List
from kitty.boss import Boss

def main(args: List[str]) -> str:
    try:
        types_res = subprocess.run(
            ["wl-paste", "--list-types"],
            capture_output=True,
            text=True,
            timeout=1
        )
        types_out = types_res.stdout.strip().split("\n") if types_res.returncode == 0 else []

        image_type = None
        for t in types_out:
            t = t.strip()
            if "image/png" in t:
                image_type = "image/png"
                break
            elif "image/jpeg" in t or "image/jpg" in t:
                image_type = "image/jpeg"
                break
            elif t.startswith("image/"):
                image_type = t
                break

        if image_type:
            cache_dir = os.path.expanduser("~/.cache/kitty_clipboard_images")
            os.makedirs(cache_dir, exist_ok=True)
            filename = f"clipboard_{int(time.time() * 1000)}.png"
            filepath = os.path.join(cache_dir, filename)

            with open(filepath, "wb") as f:
                subprocess.run(
                    ["wl-paste", "--type", image_type],
                    stdout=f,
                    timeout=2
                )

            if os.path.exists(filepath) and os.path.getsize(filepath) > 0:
                return f"IMAGE:{filepath}"

        text_res = subprocess.run(
            ["wl-paste", "--no-newline"],
            capture_output=True,
            text=True,
            timeout=1
        )
        if text_res.returncode == 0 and text_res.stdout:
            return f"TEXT:{text_res.stdout}"

        return "PASS_THROUGH"
    except Exception:
        return "PASS_THROUGH"

def handle_result(args: List[str], answer: str, target_window_id: int, boss: Boss) -> None:
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return

    if answer.startswith("IMAGE:"):
        path = answer[6:]
        w.paste_text(path + " ")
    elif answer.startswith("TEXT:"):
        text = answer[5:]
        w.paste_text(text)
    else:
        w.paste_from_clipboard()
