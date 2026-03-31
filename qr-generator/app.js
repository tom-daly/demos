/* ============================================================
   QR Code Generator - Application Logic
   ============================================================ */

(function () {
  "use strict";

  /* ---- DOM refs ---- */
  const fileInput        = document.getElementById("fileInput");
  const dropZone         = document.getElementById("dropZone");
  const fileInfo         = document.getElementById("fileInfo");
  const urlTextarea      = document.getElementById("urlTextarea");
  const generateBtn      = document.getElementById("generateBtn");
  const clearBtn         = document.getElementById("clearBtn");
  const statusBar        = document.getElementById("statusBar");
  const resultsSection   = document.getElementById("resultsSection");
  const qrGrid           = document.getElementById("qrGrid");
  const countBadge       = document.getElementById("countBadge");
  const downloadAllBtn   = document.getElementById("downloadAllBtn");
  const clearResultsBtn  = document.getElementById("clearResultsBtn");

  /* ---- Tab switching ---- */
  document.querySelectorAll(".tab-btn").forEach(function (btn) {
    btn.addEventListener("click", function () {
      const target = btn.getAttribute("data-tab");
      document.querySelectorAll(".tab-btn").forEach(function (b) { b.classList.remove("active"); });
      document.querySelectorAll(".tab-content").forEach(function (c) { c.classList.remove("active"); });
      btn.classList.add("active");
      document.getElementById("tab-" + target).classList.add("active");
    });
  });

  /* ---- File drop zone ---- */
  dropZone.addEventListener("dragover", function (e) {
    e.preventDefault();
    dropZone.classList.add("drag-over");
  });

  dropZone.addEventListener("dragleave", function () {
    dropZone.classList.remove("drag-over");
  });

  dropZone.addEventListener("drop", function (e) {
    e.preventDefault();
    dropZone.classList.remove("drag-over");
    const file = e.dataTransfer.files[0];
    if (file) handleFile(file);
  });

  fileInput.addEventListener("change", function () {
    if (fileInput.files[0]) handleFile(fileInput.files[0]);
  });

  /* ---- Handle uploaded file ---- */
  function handleFile(file) {
    const allowedTypes = ["text/plain", "text/csv", "application/vnd.ms-excel"];
    const ext = file.name.split(".").pop().toLowerCase();
    if (!allowedTypes.includes(file.type) && ext !== "csv" && ext !== "txt") {
      showFileInfo("Please upload a .csv or .txt file.", true);
      return;
    }

    const reader = new FileReader();
    reader.onload = function (e) {
      const text = e.target.result;
      const urls = parseURLs(text);
      if (urls.length === 0) {
        showFileInfo("No valid URLs found in the file.", true);
        return;
      }
      urlTextarea.value = urls.join("\n");
      showFileInfo("✅ " + file.name + " loaded — " + urls.length + " URL(s) found.", false);
      // switch to paste tab so user can review
      document.querySelector("[data-tab='paste']").click();
    };
    reader.readAsText(file);
  }

  function showFileInfo(message, isError) {
    fileInfo.textContent = message;
    fileInfo.classList.remove("hidden", "error");
    if (isError) fileInfo.classList.add("error");
  }

  /* ---- Parse URLs from raw text ---- */
  function parseURLs(text) {
    // Split on newlines and commas, trim whitespace, filter blanks and non-URLs
    return text
      .split(/[\n\r,]+/)
      .map(function (s) { return s.trim(); })
      .filter(function (s) { return s.length > 0 && isValidURL(s); });
  }

  function isValidURL(str) {
    try {
      const url = new URL(str);
      return url.protocol === "http:" || url.protocol === "https:";
    } catch (_) {
      return false;
    }
  }

  /* ---- Return a safe URL string (only http/https) ---- */
  function getSafeURL(str) {
    try {
      const url = new URL(str);
      if (url.protocol === "http:" || url.protocol === "https:") {
        return url.href;
      }
    } catch (_) {
      // fall through
    }
    return null;
  }

  /* ---- Generate button ---- */
  generateBtn.addEventListener("click", generate);

  function generate() {
    const raw = urlTextarea.value;
    const urls = parseURLs(raw);

    if (urls.length === 0) {
      showStatus("⚠️ No valid URLs found. Please upload a file or paste URLs (one per line).", true);
      return;
    }

    hideStatus();
    clearGrid();

    urls.forEach(function (url) {
      addQRCard(url);
    });

    countBadge.textContent = urls.length;
    resultsSection.classList.remove("hidden");
    showStatus("✅ Generated " + urls.length + " QR code(s).", false);

    // Scroll to results
    resultsSection.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  /* ---- Build a single QR card ---- */
  function addQRCard(url) {
    const card = document.createElement("div");
    card.className = "qr-card";

    const wrapper = document.createElement("div");
    wrapper.className = "qr-canvas-wrapper";
    card.appendChild(wrapper);

    // Create canvas for the QR code (160x160)
    const canvas = document.createElement("canvas");
    wrapper.appendChild(canvas);

    window.QRCodeLib.toCanvas(canvas, url, { width: 160, margin: 2 }, function (err) {
      if (err) {
        canvas.remove();
        const errMsg = document.createElement("span");
        errMsg.textContent = "⚠️ Failed to generate";
        errMsg.style.color = "#d13438";
        wrapper.appendChild(errMsg);
      }
    });

    const urlDiv = document.createElement("div");
    urlDiv.className = "qr-url";
    const link = document.createElement("a");
    const safeURL = getSafeURL(url);
    if (safeURL) {
      link.href = safeURL;
    }
    link.target = "_blank";
    link.rel = "noopener noreferrer";
    link.textContent = url;
    urlDiv.appendChild(link);
    card.appendChild(urlDiv);

    const dlBtn = document.createElement("button");
    dlBtn.className = "btn btn-secondary";
    dlBtn.textContent = "⬇ Download PNG";
    dlBtn.addEventListener("click", function () {
      downloadCard(canvas, url);
    });
    card.appendChild(dlBtn);

    qrGrid.appendChild(card);
  }

  /* ---- Download a single QR code ---- */
  function downloadCard(canvas, url) {
    const filename = urlToFilename(url) + ".png";
    canvas.toBlob(function (blob) {
      window.saveAs(blob, filename);
    });
  }

  /* ---- Download all QR codes as ZIP ---- */
  downloadAllBtn.addEventListener("click", function () {
    const cards = qrGrid.querySelectorAll(".qr-card");
    if (cards.length === 0) return;

    const zip = new window.JSZip();
    const folder = zip.folder("qr-codes");
    const promises = [];

    cards.forEach(function (card) {
      const urlText = card.querySelector(".qr-url a").textContent;
      const filename = urlToFilename(urlText) + ".png";
      const canvas = card.querySelector("canvas");

      if (canvas) {
        const promise = new Promise(function (resolve) {
          canvas.toBlob(function (blob) {
            folder.file(filename, blob);
            resolve();
          });
        });
        promises.push(promise);
      }
    });

    Promise.all(promises).then(function () {
      zip.generateAsync({ type: "blob" }).then(function (content) {
        window.saveAs(content, "qr-codes.zip");
      });
    });
  });

  /* ---- Clear buttons ---- */
  clearBtn.addEventListener("click", function () {
    urlTextarea.value = "";
    fileInfo.classList.add("hidden");
    fileInput.value = "";
    hideStatus();
  });

  clearResultsBtn.addEventListener("click", function () {
    clearGrid();
    resultsSection.classList.add("hidden");
    hideStatus();
  });

  function clearGrid() {
    qrGrid.innerHTML = "";
  }

  /* ---- Status helpers ---- */
  function showStatus(message, isError) {
    statusBar.textContent = message;
    statusBar.classList.remove("hidden", "error");
    if (isError) statusBar.classList.add("error");
  }

  function hideStatus() {
    statusBar.classList.add("hidden");
  }

  /* ---- Utilities ---- */
  function urlToFilename(url) {
    return url
      .replace(/^https?:\/\//, "")
      .replace(/[^a-zA-Z0-9._-]/g, "_")
      .substring(0, 80);
  }
}());
