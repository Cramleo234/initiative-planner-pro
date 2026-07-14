import { copyFile, mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join, parse } from "node:path";
import {
  createDefaultState,
  decodePlannerState,
  encodePlannerState,
  normalizePlannerState,
  type PlannerState,
} from "../src/domain/models.js";

export interface RecoveryInfo {
  backupPath: string;
  message: string;
}

export interface LoadStateResult {
  state: PlannerState;
  recovery: RecoveryInfo | null;
}

export interface PersistenceDependencies {
  now?: () => Date;
}

function backupTimestamp(date: Date): string {
  return date.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
}

export async function loadStateFile(
  filePath: string,
  dependencies: PersistenceDependencies = {},
): Promise<LoadStateResult> {
  let text: string;
  try {
    text = await readFile(filePath, "utf8");
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") {
      return { state: createDefaultState(), recovery: null };
    }
    throw error;
  }

  try {
    return { state: normalizePlannerState(decodePlannerState(text)), recovery: null };
  } catch (error) {
    const date = dependencies.now?.() ?? new Date();
    const parsed = parse(filePath);
    const backupPath = join(parsed.dir, `${parsed.name}.incompatible-${backupTimestamp(date)}${parsed.ext}`);
    await copyFile(filePath, backupPath);
    return {
      state: createDefaultState(),
      recovery: {
        backupPath,
        message: error instanceof Error ? error.message : String(error),
      },
    };
  }
}

export async function saveStateFileAtomic(filePath: string, state: PlannerState): Promise<void> {
  await mkdir(dirname(filePath), { recursive: true });
  const temporaryPath = `${filePath}.${process.pid}.${crypto.randomUUID()}.tmp`;
  await writeFile(temporaryPath, encodePlannerState(state), { encoding: "utf8", mode: 0o600 });
  await rename(temporaryPath, filePath);
}
