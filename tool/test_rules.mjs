import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createReadStream, createWriteStream } from 'node:fs';
import { access, mkdir, rename } from 'node:fs/promises';
import { createConnection } from 'node:net';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';

// Version and SHA-256 published by firebase-tools 15.34.0's official
// lib/emulator/downloadableEmulatorInfo.json. Only this local runtime is needed.
const version = '1.22.0';
const checksum = '9b6498b7f62714d67f48f59b3818883cd682dbcd46b9f59511de81c97bb5166c';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const cache = process.env.FIREBASE_EMULATORS_PATH ?? join(homedir(), '.cache', 'firebase', 'emulators');
const jar = join(cache, `cloud-firestore-emulator-v${version}.jar`);

async function sha256(path) {
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(path)) hash.update(chunk);
  return hash.digest('hex');
}

async function listening() {
  return new Promise((resolve) => {
    const socket = createConnection({ host: '127.0.0.1', port: 8080 });
    socket.setTimeout(500);
    socket.once('connect', () => { socket.destroy(); resolve(true); });
    socket.once('error', () => { socket.destroy(); resolve(false); });
    socket.once('timeout', () => { socket.destroy(); resolve(false); });
  });
}

let emulator;
try {
  if (await listening()) throw new Error('Port 8080 is already in use. Stop the existing service before running isolated rules tests.');
  try { await access(jar); }
  catch {
    await mkdir(cache, { recursive: true });
    console.log(`Downloading Google's Firestore emulator ${version}…`);
    const response = await fetch(`https://storage.googleapis.com/firebase-preview-drop/emulator/cloud-firestore-emulator-v${version}.jar`);
    if (!response.ok || !response.body) throw new Error(`Emulator download failed: HTTP ${response.status}`);
    await pipeline(Readable.fromWeb(response.body), createWriteStream(`${jar}.part`));
    if (await sha256(`${jar}.part`) !== checksum) throw new Error('Emulator checksum verification failed.');
    await rename(`${jar}.part`, jar);
  }
  if (await sha256(jar) !== checksum) throw new Error('The cached emulator failed SHA-256 verification.');
  let output = '';
  let spawnError;
  emulator = spawn('java', ['-Duser.language=en', '-jar', jar, '--host', '127.0.0.1', '--port', '8080', '--project_id', 'demo-hyner-foundation', '--single_project_mode', 'true', '--rules', join(root, 'firestore.rules')], { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
  emulator.on('error', (error) => { spawnError = error; });
  for (const stream of [emulator.stdout, emulator.stderr]) stream.on('data', (chunk) => { output = (output + chunk.toString()).slice(-10000); });
  let ready = false;
  for (let attempt = 0; attempt < 150; attempt++) {
    if (spawnError) throw spawnError;
    if (emulator.exitCode !== null) throw new Error(`Emulator stopped before startup:\n${output}`);
    if (await listening()) { ready = true; break; }
    await delay(200);
  }
  if (!ready) throw new Error(`Emulator did not become ready:\n${output}`);
  console.log('Running security tests against the isolated local demo project.');
  const result = await new Promise((resolve, reject) => {
    const tests = spawn(process.execPath, ['--test', '--test-concurrency=1', 'rules_tests/firestore.test.mjs', 'functions/test/sales.test.mjs'], { cwd: root, stdio: 'inherit', env: { ...process.env, FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' } });
    tests.once('error', reject);
    tests.once('exit', (code) => resolve(code ?? 1));
  });
  process.exitCode = result;
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  if (emulator && emulator.exitCode === null) {
    const stopped = new Promise((resolve) => emulator.once('exit', resolve));
    emulator.kill('SIGTERM');
    await Promise.race([stopped, delay(3000)]);
    if (emulator.exitCode === null) emulator.kill('SIGKILL');
  }
}
