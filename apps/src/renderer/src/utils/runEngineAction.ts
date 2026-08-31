export const UI_ERROR_EVENT = "cleartone:ui-error";

export function normalizeActionError(error: unknown): string {
  const fallback = "ClearTone could not complete the action.";
  const message = error instanceof Error ? error.message : typeof error === "string" ? error : fallback;
  return message
    .replace(/^Error invoking remote method '[^']+': Error:\s*/i, "")
    .replace(/^Error:\s*/i, "")
    .trim() || fallback;
}

export async function runEngineAction(action: () => Promise<unknown>): Promise<boolean> {
  try {
    await action();
    return true;
  } catch (error) {
    const message = normalizeActionError(error);
    window.dispatchEvent(new CustomEvent<string>(UI_ERROR_EVENT, { detail: message }));
    return false;
  }
}
