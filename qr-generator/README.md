# QR Code Generator

A lightweight, browser-based QR code generator that lets you upload a list of URLs and generate QR codes in bulk — no server required.

## Features

- **File Upload** – Upload a `.csv` or `.txt` file containing URLs (one per line or comma-separated)
- **Paste URLs** – Paste URLs directly into the text area for quick use
- **Bulk Generation** – Generate QR codes for every URL in one click
- **Download Individual** – Download any single QR code as a PNG
- **Download All** – Download all generated QR codes in a single ZIP file
- **Drag & Drop** – Drag a file directly onto the upload zone

## Usage

1. Open `index.html` in any modern browser (Chrome, Edge, Firefox, Safari)
2. Choose either **Upload File** or **Paste URLs**
   - **Upload File**: Select or drag a `.csv` / `.txt` file where each URL is on its own line
   - **Paste URLs**: Type or paste URLs, one per line
3. Click **Generate QR Codes**
4. QR codes appear in the grid below
   - Click **⬇ Download PNG** on any card to save that QR code
   - Click **⬇ Download All (ZIP)** to download all codes as a ZIP archive

## File Format

Plain text or CSV with one URL per line:

```
https://example.com
https://microsoft.com
https://github.com/tom-daly/demos
```

Or comma-separated on one line:

```
https://example.com,https://microsoft.com,https://github.com
```

## Dependencies (CDN – no install required)

| Library | Purpose |
|---------|---------|
| [qrcodejs](https://github.com/davidshimjs/qrcodejs) | QR code generation |
| [JSZip](https://stuk.github.io/jszip/) | ZIP file creation |
| [FileSaver.js](https://github.com/eligrey/FileSaver.js) | Browser file download |
