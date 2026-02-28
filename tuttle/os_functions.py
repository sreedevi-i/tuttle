"""OS-level function"""
from typing import Optional, List
from pathlib import Path
import base64
import subprocess
import platform
import os

import pymupdf


def open_application(app_name):
    """Open an application by name."""
    if platform.system() == "Darwin":
        subprocess.call(["open", "-a", app_name])
    elif platform.system() == "Windows":
        subprocess.call(["start", app_name], shell=True)
    elif platform.system() == "Linux":
        subprocess.call(["xdg-open", app_name])


def preview_pdf(file_path):
    """Preview a PDF file."""
    try:
        if not Path(file_path).exists():
            raise FileNotFoundError(f"File not found: {file_path}")
        if platform.system() == "Darwin":
            subprocess.check_call(["qlmanage", "-p", file_path])
        elif platform.system() == "Windows":
            os.startfile(file_path)
        elif platform.system() == "Linux":
            subprocess.check_call(["xdg-open", file_path])
        else:
            raise RuntimeError("Sorry, your platform is not supported.")
    except subprocess.CalledProcessError as err:
        raise RuntimeError(
            f"Error occurred while opening the PDF file. Return code: {err.returncode}. Error: {err.output}"
        )


def render_pdf_pages(file_path, dpi: int = 150) -> List[str]:
    """Render each page of a PDF to a base64-encoded PNG string.

    Returns a list with one base64 string per page.
    Raises FileNotFoundError when the path does not exist.
    """
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"File not found: {file_path}")

    zoom = dpi / 72  # 72 is the PDF base resolution
    matrix = pymupdf.Matrix(zoom, zoom)
    pages: List[str] = []
    with pymupdf.open(str(path)) as doc:
        for page in doc:
            pix = page.get_pixmap(matrix=matrix)
            pages.append(base64.b64encode(pix.tobytes("png")).decode("ascii"))
    return pages


def open_folder(folder_path):
    """Open a folder."""
    if platform.system() == "Darwin":
        subprocess.call(["open", folder_path])
    elif platform.system() == "Windows":
        subprocess.call(["start", folder_path], shell=True)
    elif platform.system() == "Linux":
        subprocess.call(["xdg-open", folder_path])
    else:
        print("Sorry, your platform is not supported.")
