import { FitAddon } from "@xterm/addon-fit";
import { ITheme, Terminal } from "@xterm/xterm";
import { Message } from "./protocol";

// @ts-ignore
import "@xterm/xterm/css/xterm.css";

interface CollectedFile {
  file: File;
  relativePath: string;
}

const isFileEntry = (e: FileSystemEntry): e is FileSystemFileEntry => e.isFile;
const isDirectoryEntry = (e: FileSystemEntry): e is FileSystemDirectoryEntry =>
  e.isDirectory;

const lightTheme: ITheme = {
  foreground: "#1f2328",
  background: "#ffffff",
  cursor: "#0969da",
  cursorAccent: "#ffffff",
  selectionBackground: "#0969da40",
  black: "#24292f",
  red: "#cf222e",
  green: "#116329",
  yellow: "#4d2d00",
  blue: "#0969da",
  magenta: "#8250df",
  cyan: "#1b7c83",
  white: "#6e7781",
  brightBlack: "#57606a",
  brightRed: "#a40e26",
  brightGreen: "#1a7f37",
  brightYellow: "#633c01",
  brightBlue: "#218bff",
  brightMagenta: "#a475f9",
  brightCyan: "#3192aa",
  brightWhite: "#8c959f",
};

const darkTheme: ITheme = {
  foreground: "#f0f6fc",
  background: "#0d1117",
  cursor: "#58a6ff",
  cursorAccent: "#0d1117",
  selectionBackground: "#58a6ff40",
  black: "#484f58",
  red: "#ff7b72",
  green: "#3fb950",
  yellow: "#d29922",
  blue: "#58a6ff",
  magenta: "#bc8cff",
  cyan: "#39c5cf",
  white: "#b1bac4",
  brightBlack: "#6e7681",
  brightRed: "#ffa198",
  brightGreen: "#56d364",
  brightYellow: "#e3b341",
  brightBlue: "#79c0ff",
  brightMagenta: "#d2a8ff",
  brightCyan: "#56d4dd",
  brightWhite: "#f0f6fc",
};

(() => {
  const terminalElement = document.getElementById("terminal");
  if (!terminalElement) return;

  const colorScheme = window.matchMedia("(prefers-color-scheme: dark)");
  const term = new Terminal({
    theme: colorScheme.matches ? darkTheme : lightTheme,
  });
  const fitAddon = new FitAddon();
  term.loadAddon(fitAddon);
  term.open(terminalElement);
  fitAddon.fit();

  colorScheme.addEventListener("change", ({ matches }) => {
    term.options.theme = matches ? darkTheme : lightTheme;
  });

  const wsProtocol = location.protocol === "https:" ? "wss:" : "ws:";
  let ws: WebSocket;
  let closed = false;
  let hasInput = false;
  const wsSend = (message: Message) => ws.send(JSON.stringify(message));

  function connect() {
    ws = new WebSocket(`${wsProtocol}//${location.host}`);
    closed = false;
    hasInput = false;
    ws.onopen = () => sendResize();
    ws.onmessage = (e) => term.write(e.data);
    ws.onclose = () => {
      closed = true;
      term.write(
        "\r\n\x1b[2m(session closed; press Enter to start a new one)\x1b[0m\r\n",
      );
    };
  }
  connect();

  function sendResize() {
    fitAddon.fit();
    if (ws.readyState !== WebSocket.OPEN) return;
    wsSend({ type: "resize", cols: term.cols, rows: term.rows });
  }
  window.addEventListener("resize", sendResize);

  term.onData((data) => {
    if (closed) {
      if (data === "\r") {
        term.reset();
        connect();
      }
      return;
    }
    hasInput = true;
    wsSend({ type: "input", data });
  });

  document.addEventListener("dragover", (e) => e.preventDefault());
  document.addEventListener("drop", async (e) => {
    e.preventDefault();
    if (closed || hasInput) return;

    const items = e.dataTransfer?.items;
    if (!items) return;

    const files: CollectedFile[] = [];
    for (const item of items) {
      const entry = item.webkitGetAsEntry();
      if (entry) await collectFiles(entry, "", files);
    }
    if (files.length === 0) return;

    term.reset();
    term.write(`\x1b[2mUploading ${files.length} file(s)...\x1b[0m\r\n`);

    const formData = new FormData();
    for (const { file, relativePath } of files) {
      formData.append("files", file, relativePath);
    }

    try {
      const res = await fetch("/upload", { method: "POST", body: formData });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error(body.error || `Upload failed: ${res.status}`);
      }
      const { jobId } = await res.json();
      wsSend({ type: "upload", jobId });
    } catch (err) {
      term.write(`\r\n\x1b[31mUpload error: ${err}\x1b[0m\r\n`);
    }
  });

  async function collectFiles(
    entry: FileSystemEntry,
    prefix: string,
    out: CollectedFile[],
  ) {
    if (isFileEntry(entry)) {
      const file = await new Promise<File>((resolve, reject) =>
        entry.file(resolve, reject),
      );
      out.push({ file, relativePath: prefix + entry.name });
    } else if (isDirectoryEntry(entry)) {
      const reader = entry.createReader();
      const entries = await readAllEntries(reader);
      for (const child of entries) {
        await collectFiles(child, prefix + entry.name + "/", out);
      }
    }
  }

  async function readAllEntries(reader: FileSystemDirectoryReader) {
    let all: FileSystemEntry[] = [];
    let batch: FileSystemEntry[];
    do {
      batch = await new Promise((resolve, reject) =>
        reader.readEntries(resolve, reject),
      );
      all = all.concat(batch);
    } while (batch.length > 0);
    return all;
  }
})();
