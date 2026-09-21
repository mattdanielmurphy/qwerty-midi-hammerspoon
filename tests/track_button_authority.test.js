import { expect, test } from "bun:test";

const hud = await Bun.file("src/hud.lua").text();
const web = await Bun.file("src/web/index.html").text();

test("only the authoritative HUD render updates track-button selection state", () => {
  const fastUpdate = hud.match(/local function fastUpdateArp\(\)([\s\S]*?)\nend\n\nreturn \{/);

  expect(fastUpdate).not.toBeNull();
  expect(fastUpdate[1]).not.toContain("trkStates");
  expect(fastUpdate[1]).toContain("window.updateArpPitches(%s, %s)");
  expect(web).not.toContain("window.updateArpPitches = function(activeCodes, heldCodes, trkAudioStates)");
});

test("track-button presses do not apply the generic pressed visual state", () => {
  expect(web).toContain("const isTrackButton = code >= 18 && code <= 21;");
  expect(web).toContain("if (isTrackButton) return;");
});
