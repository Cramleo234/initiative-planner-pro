import { describe, expect, it } from "vitest";
import packageMetadata from "../package.json";

const releaseMetadata = packageMetadata as typeof packageMetadata & {
  build: typeof packageMetadata.build & { buildVersion?: string };
};

describe("Windows release metadata", () => {
  it("uses the beta product version and a numeric Windows file version", () => {
    expect(releaseMetadata.version).toBe("0.9.1-beta.1");
    expect(releaseMetadata.build.buildVersion).toBe("0.9.1.0");
    expect(releaseMetadata.build.win.artifactName).toBe("InitiativePlannerPro-${version}-Windows-x64.${ext}");
    expect(releaseMetadata.build.nsis.artifactName).toBe("InitiativePlannerPro-${version}-Windows-x64-Setup.${ext}");
  });

  it("packages only built application code and package metadata", () => {
    expect(releaseMetadata.build.files).toEqual([
      "dist/**/*",
      "dist-electron/**/*",
      "package.json",
    ]);
  });
});