import { describe, test, expect } from "bun:test";
import { readdirSync } from "node:fs";
import { join } from "node:path";

const LUA_DIR = join(import.meta.dir, "lua");
const luaTestFiles = readdirSync(LUA_DIR)
  .filter(f => f.startsWith("test_") && f.endsWith(".lua"))
  .sort();

describe("Headless Pure-Lua Verification Suite (via hs_mock)", () => {
  for (const file of luaTestFiles) {
    test(`Lua suite: ${file}`, () => {
      const filePath = join(LUA_DIR, file);
      const proc = Bun.spawnSync(["lua", filePath], {
        cwd: process.cwd(),
        env: {
          ...process.env,
          LUA_PATH: "./?.lua;./src/?.lua;./packages/?.lua;;"
        }
      });

      const stdout = proc.stdout.toString().trim();
      const stderr = proc.stderr.toString().trim();

      if (proc.exitCode !== 0) {
        console.error(`\n❌ Lua test suite ${file} failed:\nSTDOUT:\n${stdout}\nSTDERR:\n${stderr}`);
      }

      expect(proc.exitCode).toBe(0);
      expect(stderr).not.toContain("error");
      expect(stdout).toContain("PASSED");
    });
  }
});
