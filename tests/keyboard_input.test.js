import { expect, test } from "bun:test";

const init = await Bun.file(new URL("../src/init.lua", import.meta.url)).text();

test("Mac event-tap key presses do not masquerade as external KeyStep notes", () => {
  expect(init).toContain("controls.handleKeyDown(code) end");
  expect(init).not.toContain("controls.handleKeyDown(code, flags)");
});
