from typing import Optional

import sys
from pathlib import Path
import typer
from loguru import logger
import subprocess

from importlib.util import find_spec

import tuttle

app_path = "app.py"
app_name = "Tuttle"


def get_icon_path():
    if sys.platform.startswith("darwin"):
        icon_path = "tuttle/app/assets/icon/macos/AppIcon.icns"
    else:
        icon_path = "tuttle/app/assets/icon/web/icon-512-maskable.png"
    return icon_path


# files to be added to the app bundle
added_files = [
    ("templates", "./templates"),
    ("tuttle_tests/data", "./tuttle_tests/data"),
    ("tuttle/migrations", "./tuttle/migrations"),
    ("tuttle/tax_data", "./tuttle/tax_data"),
]

# options to be passed to flet pack
pack_options = [
    ("--name", app_name),
    ("--icon", get_icon_path()),
    ("--product-name", app_name),
    ("--product-version", tuttle.__version__),
    (
        "--copyright",
        "(c) 2021-2026 Tuttle developers. Licensed under the GNU GPL v3.0.",
    ),
]


def get_delimiter():
    if sys.platform.startswith("win"):
        delimiter = ";"
    else:
        delimiter = ":"
    return delimiter


added_data_options = []
for src, dst in added_files:
    added_data_options += ["--add-data", f"{src}{get_delimiter()}{dst}"]
pack_options_unpacked = [item for pair in pack_options for item in pair]

# packages with non-Python data files that PyInstaller/flet-pack misses
_packages_with_data = ["rfc3987_syntax"]
for _pkg in _packages_with_data:
    spec = find_spec(_pkg)
    if spec and spec.submodule_search_locations:
        pkg_dir = spec.submodule_search_locations[0]
        added_data_options += ["--add-data", f"{pkg_dir}{get_delimiter()}{_pkg}"]


def main(
    install_dir: Optional[Path] = typer.Option(
        None, "--install-dir", "-i", help="Where to install the app"
    ),
):
    if install_dir:
        logger.info(f"removing app from {install_dir}")
        subprocess.call(["rm", "-rf", f"{install_dir}/Tuttle.app"], shell=False)

    logger.info("building app")
    pack_command = (
        ["flet", "pack", app_path] + added_data_options + pack_options_unpacked
    )
    logger.info(f"calling flet with command: {' '.join(pack_command)}")
    print(pack_command)
    subprocess.call(
        pack_command,
        shell=False,
    )


if __name__ == "__main__":
    typer.run(main)
