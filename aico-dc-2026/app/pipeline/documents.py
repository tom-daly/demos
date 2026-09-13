"""Turn a file into something the model can read: text when the file has it, page images when it doesn't.
The whole document goes to the model in one call; nothing is split.

PDFs with a text layer -> text per page (with page markers so evidence can cite a page).
Scanned PDFs (no text layer)  -> first N pages rendered to PNG and sent as images.
Photos (jpg/png/webp)         -> sent as one image.
Plain text / markdown         -> text.
"""
from __future__ import annotations

import base64
import io
from dataclasses import dataclass, field

from .config import settings

IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
TEXT_TYPES = {"text/plain", "text/markdown", "text/csv"}
MIN_CHARS_PER_PAGE = 80     # below this the PDF is treated as a scan


class Unsupported(Exception):
    pass


@dataclass
class Document:
    name: str
    content_type: str
    text: str = ""
    images: list[str] = field(default_factory=list)   # data URLs
    pages: int = 0
    scanned: bool = False



def guess_type(name: str, declared: str | None) -> str:
    if declared and declared != "application/octet-stream":
        return declared.split(";")[0].strip().lower()
    ext = name.lower().rsplit(".", 1)[-1] if "." in name else ""
    return {
        "pdf": "application/pdf", "jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
        "webp": "image/webp", "txt": "text/plain", "md": "text/markdown", "csv": "text/csv",
    }.get(ext, "application/octet-stream")


def _data_url(png: bytes, mime: str = "image/png") -> str:
    return f"data:{mime};base64,{base64.b64encode(png).decode('ascii')}"


def read(name: str, data: bytes, content_type: str | None = None) -> Document:
    ctype = guess_type(name, content_type)
    doc = Document(name=name, content_type=ctype)

    if ctype in IMAGE_TYPES:
        doc.images = [_data_url(data, ctype)]
        doc.pages = 1
        doc.scanned = True
        return doc

    if ctype in TEXT_TYPES:
        doc.text = data.decode("utf-8", errors="replace")
        doc.pages = 1
        return doc

    if ctype == "application/pdf":
        from pypdf import PdfReader
        reader = PdfReader(io.BytesIO(data))
        doc.pages = len(reader.pages)
        page_texts = [(p.extract_text() or "").strip() for p in reader.pages]
        total = sum(len(t) for t in page_texts)
        if doc.pages and total / doc.pages >= MIN_CHARS_PER_PAGE:
            doc.text = "\n\n".join(f"[page {i + 1}]\n{t}" for i, t in enumerate(page_texts))
            return doc
        # No usable text layer: render pages and let the model read the pictures.
        doc.scanned = True
        doc.images = render_pdf_pages(data, settings().max_image_pages)
        return doc

    raise Unsupported(f"{name}: {ctype} is not a type this pipeline reads")


def render_pdf_pages(data: bytes, max_pages: int, dpi: int = 110) -> list[str]:
    import pymupdf
    urls = []
    with pymupdf.open(stream=data, filetype="pdf") as pdf:
        for i in range(min(len(pdf), max_pages)):
            pix = pdf[i].get_pixmap(dpi=dpi)
            urls.append(_data_url(pix.tobytes("png")))
    return urls
