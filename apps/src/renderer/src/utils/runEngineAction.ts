export const UI_ERROR_EVENT = "cleartone:ui-error";

export async function runEngineAction(action: () => Promise<unknown>): Promise<boolean> {
  try {
    await action();
    return true;
  } catch (error) {
    const message = error instanceof Error ? error.message : "ClearTone could not complete the action.";
    window.dispatchEvent(new CustomEvent<string>(UI_ERROR_EVENT, { detail: message }));
    return false;
  }
}
