import { readFile, readdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const apiRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  ".."
);
const repoRoot = path.resolve(apiRoot, "..", "..");
const failures = [];

function fail(message) {
  failures.push(message);
}

async function migrationPolicy() {
  const dir = path.join(apiRoot, "db", "migrations");
  const files = (await readdir(dir))
    .filter((name) => name.endsWith(".sql"))
    .sort();

  if (files.length === 0) {
    fail("No SQL migrations found");
    return;
  }

  const destructive =
    /\b(DROP\s+TABLE|DROP\s+COLUMN|TRUNCATE\b|DELETE\s+FROM)\b/i;

  for (let index = 0; index < files.length; index += 1) {
    const file = files[index];
    const match = /^(\d{4})_[a-z0-9_]+\.sql$/.exec(file);
    if (!match) {
      fail(`Invalid migration filename: ${file}`);
      continue;
    }

    const expected = index + 1;
    if (Number(match[1]) !== expected) {
      fail(
        `Migration sequence gap/order error: expected ${String(expected).padStart(4, "0")}, found ${match[1]}`
      );
    }

    const sql = await readFile(path.join(dir, file), "utf8");
    if (!/\bBEGIN\s*;/i.test(sql) || !/\bCOMMIT\s*;/i.test(sql)) {
      fail(`${file} must be transaction-wrapped with BEGIN/COMMIT`);
    }

    if (
      destructive.test(sql) &&
      !sql.includes("-- policy: destructive-reviewed")
    ) {
      fail(
        `${file} contains destructive SQL without the explicit destructive-review marker`
      );
    }
  }
}

async function dependencyPolicy() {
  const packageJson = JSON.parse(
    await readFile(path.join(apiRoot, "package.json"), "utf8")
  );

  const dependencySets = [
    ["dependencies", packageJson.dependencies ?? {}],
    ["devDependencies", packageJson.devDependencies ?? {}]
  ];

  const unsafeSource = /^(?:latest|\*|git\+|git:|https?:|file:|github:)/i;
  for (const [section, dependencies] of dependencySets) {
    for (const [name, version] of Object.entries(dependencies)) {
      if (typeof version !== "string" || !version.trim()) {
        fail(`${section} dependency ${name} has no version constraint`);
        continue;
      }
      if (unsafeSource.test(version.trim())) {
        fail(
          `${section} dependency ${name} uses an unpinned/remote source: ${version}`
        );
      }
    }
  }

  const runtimeDependencies = Object.keys(packageJson.dependencies ?? {});
  if (
    runtimeDependencies.length > 0 &&
    !existsSync(path.join(apiRoot, "package-lock.json"))
  ) {
    fail(
      "API runtime dependencies require a committed package-lock.json before merge"
    );
  }

  const pubspec = await readFile(
    path.join(repoRoot, "apps", "pos_mobile", "pubspec.yaml"),
    "utf8"
  );
  if (/^\s{4,}(?:git|path):\s*/m.test(pubspec)) {
    fail("Flutter dependencies must not use git/path sources in release code");
  }
  if (/^\s{2,}[a-zA-Z0-9_]+:\s*any\s*$/m.test(pubspec)) {
    fail("Flutter dependencies must not use the unconstrained 'any' version");
  }
}

async function sourceSecretPolicy() {
  const roots = [
    path.join(apiRoot, "src"),
    path.join(apiRoot, "db")
  ];

  const secretPatterns = [
    ["private key", /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/],
    [
      "credential-bearing database URL",
      /postgres(?:ql)?:\/\/[^:\s]+:[^@\s]+@/i
    ],
    [
      "hard-coded secret assignment",
      /\b(?:api[_-]?key|client[_-]?secret|password)\s*[:=]\s*["'][^"']{8,}["']/i
    ],
    [
      "OpenAI-style secret token",
      /\bsk-[A-Za-z0-9_-]{20,}\b/
    ]
  ];

  async function walk(dir) {
    for (const entry of await readdir(dir, { withFileTypes: true })) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        await walk(fullPath);
        continue;
      }
      if (!/\.(?:ts|sql|json|md)$/i.test(entry.name)) continue;

      const content = await readFile(fullPath, "utf8");
      for (const [label, pattern] of secretPatterns) {
        if (pattern.test(content)) {
          fail(
            `${path.relative(repoRoot, fullPath)} contains a possible ${label}`
          );
        }
      }
    }
  }

  for (const root of roots) {
    await walk(root);
  }

  const prohibitedNames = [
    ".env",
    ".env.production",
    "credentials.json",
    "service-account.json"
  ];
  for (const name of prohibitedNames) {
    if (existsSync(path.join(repoRoot, name))) {
      fail(`Prohibited secret/config file is committed at repository root: ${name}`);
    }
  }
}

await migrationPolicy();
await dependencyPolicy();
await sourceSecretPolicy();

if (failures.length > 0) {
  console.error("Repository policy failed:");
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log(
  "Repository policy passed: migration ordering/safety, dependency sources and secret hygiene."
);
