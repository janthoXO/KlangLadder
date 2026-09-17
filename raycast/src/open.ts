import { Clipboard, Toast, closeMainWindow, getApplications, open, showToast } from "@raycast/api";

const BUNDLE_ID = "dev.klangladder.KlangLadder";
const INSTALL_COMMAND =
  "brew tap janthoXO/klangladder https://github.com/janthoXO/KlangLadder && brew install --HEAD klangladder";

export default async function Command() {
  const applications = await getApplications();
  const isInstalled = applications.some((app) => app.bundleId === BUNDLE_ID);

  if (!isInstalled) {
    await showToast({
      style: Toast.Style.Failure,
      title: "KlangLadder is not installed",
      message: "Install it with Homebrew",
      primaryAction: {
        title: "Copy Install Command",
        onAction: async () => {
          await Clipboard.copy(INSTALL_COMMAND);
        },
      },
    });
    return;
  }

  await closeMainWindow();
  await open("klangladder://open");
}
