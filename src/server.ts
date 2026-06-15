import AdmZip from "adm-zip";
import Busboy from "busboy";
import fs from "fs";
import http from "http";
import * as pty from "node-pty";
import crypto from "node:crypto";
import os from "os";
import path from "path";
import { WebSocketServer } from "ws";
import { Message } from "./protocol";

const extractArchives = (dir: string) => {
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    if (!entry.isFile() || !entry.name.toLowerCase().endsWith(".zip")) continue;

    const fullPath = path.join(dir, entry.name);
    const extractDir = path.join(dir, path.basename(entry.name, ".zip"));

    fs.mkdirSync(extractDir, { recursive: true });

    const zip = new AdmZip(fullPath);
    zip.extractAllTo(extractDir, true);

    fs.unlinkSync(fullPath);
  }
};

const handleUpload = (req: http.IncomingMessage, res: http.ServerResponse) => {
  const jobId = crypto.randomUUID();
  const importDir = path.join(os.tmpdir(), "beet-imports", jobId);
  fs.mkdirSync(importDir, { recursive: true });

  const busboy = Busboy({ headers: req.headers });
  const pending: Promise<unknown>[] = [];

  busboy.on("file", (_, fileStream, info) => {
    const { filename } = info;

    const destPath = path.normalize(path.join(importDir, filename));
    if (!destPath.startsWith(importDir + path.sep) && destPath !== importDir) {
      fileStream.resume();
      return;
    }

    fs.mkdirSync(path.dirname(destPath), { recursive: true });

    const writeStream = fs.createWriteStream(destPath);
    fileStream.pipe(writeStream);

    pending.push(
      new Promise((resolve, reject) => {
        writeStream.on("finish", resolve);
        writeStream.on("error", reject);
        fileStream.on("error", reject);
      }),
    );
  });

  busboy.on("finish", async () => {
    try {
      await Promise.all(pending);
      extractArchives(importDir);

      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ jobId, importDir }));
    } catch (err) {
      fs.rmSync(importDir, { recursive: true, force: true });
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: err.message }));
    }
  });

  req.pipe(busboy);
};

const BEETS_FRONTEND_PORT = 5173;
const HOST = "0.0.0.0";

const MIME = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".css": "text/css",
};

const httpServer = http.createServer((req, res) => {
  if (req.method === "POST" && req.url === "/upload") {
    handleUpload(req, res);
    return;
  }

  const reqPath = !req.url || req.url === "/" ? "/index.html" : req.url;
  const filePath = path.normalize(path.join(__dirname, reqPath));

  if (!filePath.startsWith(__dirname + path.sep)) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end("Not found");
      return;
    }
    const ext = path.extname(filePath);
    const contentType =
      MIME[ext as keyof typeof MIME] ?? "application/octet-stream";
    res.writeHead(200, {
      "Content-Type": contentType,
    });
    res.end(data);
  });
});

const wss = new WebSocketServer({ server: httpServer });

wss.on("connection", (ws) => {
  let shell: pty.IPty | undefined;
  let cols = 80;
  let rows = 24;
  let hasInput = false;

  const spawnScript = (name: string, args: string[] = []) => {
    shell?.kill();
    const scriptPath = path.join(__dirname, "scripts", name);
    const next = pty.spawn(scriptPath, args, {
      name: "xterm-color",
      cols,
      rows,
      env: process.env,
    });
    shell = next;

    next.onData((data) => ws.send(data));
    next.onExit(({ exitCode }) => {
      if (shell !== next) return;
      ws.send(`\r\n\x1b[33m[process exited with code ${exitCode}]\x1b[0m\r\n`);
      ws.close();
    });
  };

  spawnScript("menu.sh");

  ws.on("message", (msg) => {
    let parsed;
    try {
      parsed = JSON.parse(msg.toString()) as Message;
    } catch {
      return;
    }

    switch (parsed.type) {
      case "resize":
        cols = parsed.cols;
        rows = parsed.rows;
        shell?.resize(cols, rows);
        return;
      case "input":
        hasInput = true;
        shell?.write(parsed.data);
        return;
      case "upload":
        if (hasInput) {
          ws.send(
            "\r\n\x1b[33m[session in progress; refresh to upload]\x1b[0m\r\n",
          );
          return;
        }
        spawnScript("upload.sh", [parsed.jobId]);
        return;
    }
  });

  ws.on("close", () => shell?.kill());
});

httpServer.listen(BEETS_FRONTEND_PORT, HOST, () => {
  console.log(`server running at ${HOST}:${BEETS_FRONTEND_PORT}`);
});
