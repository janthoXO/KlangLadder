import { Toast, closeMainWindow, showToast } from "@raycast/api";
import { openKlangLadder } from "swift:../swift";

export default async function Command() {
  try {
    await openKlangLadder();
    await closeMainWindow();
  } catch (error) {
    await showToast({ style: Toast.Style.Failure, title: "Couldn't open KlangLadder", message: String(error) });
  }
}
