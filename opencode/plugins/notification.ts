import { Plugin } from "@opencode-ai/plugin";
import { platform } from "os";

export const NotificationPlugin: Plugin = async ({ $ }) => {
    const notificationSound = "~/.config/opencode/plugins/notification.mp3";
    const isMac = platform() === "darwin";

    const mainSessions = new Set<string>();

    const playNotification = async (
        message: string,
        title: string = "OpenCode"
    ) => {
        if (isMac) {
            await $`osascript -e 'display notification "${message}" with title "${title}"'`;
            await $`afplay ${notificationSound}`;
        } else {
            // Avoid AppImage/other LD_LIBRARY_PATH shadowing system libnotify (symbol mismatch).
            await $`env -u LD_LIBRARY_PATH -u LD_PRELOAD notify-send "${title}" "${message}"`;
            await $`paplay ${notificationSound}`.catch(() =>
                $`aplay ${notificationSound}`
            );
        }
    };

    return {
        event: async ({ event }) => {
            // Track main sessions (sessions without a parent)
            if (event.type === "session.created") {
                const session = event.properties.info;
                if (!session.parentID) {
                    mainSessions.add(session.id);
                }
            }

            // Clean up tracked sessions when deleted
            if (event.type === "session.deleted") {
                mainSessions.delete(event.properties.info.id);
            }

            // Notify when main session becomes idle (not subagents)
            if (event.type === "session.status") {
                const { sessionID, status } = event.properties;
                if (status.type === "idle" && mainSessions.has(sessionID)) {
                    await playNotification("Task completed!", "OpenCode");
                }
            }

            // Notify when a question is asked
            if (event.type === "question.asked") {
                await playNotification(
                    "Question waiting for your input",
                    "OpenCode"
                );
            }

            // Notify when permission is requested
            if (event.type === "permission.asked") {
                await playNotification("Permission required", "OpenCode");
            }
        }
    };
};
