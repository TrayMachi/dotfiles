import type { Plugin } from "@opencode-ai/plugin";
import { basename } from "path";
import { platform } from "os";
import { fileURLToPath } from "url";

type SessionContext = {
  projectName: string;
  worktreeName: string;
  branchName: string;
  directory: string;
};

export const NotificationPlugin: Plugin = async ({
  $,
  client,
  directory: workspaceDirectory,
}) => {
  const notificationSound = fileURLToPath(
    new URL("./notification.mp3", import.meta.url),
  );
  const notificationIcon = fileURLToPath(
    new URL("./notification.svg", import.meta.url),
  );
  const isMac = platform() === "darwin";

  const sessions = new Map<
    string,
    { id: string; parentID?: string; title: string; directory: string }
  >();
  const directoryContextCache = new Map<string, Promise<SessionContext>>();
  const sessionStates = new Map<string, string>();

  const compact = (value: string) => value.replace(/\s+/g, " ").trim();

  const leafName = (value: string) => {
    const trimmed = value.replace(/[\\/]+$/, "");
    const leaf = basename(trimmed);
    return leaf === "." || leaf === "" ? trimmed || value : leaf;
  };

  const shellText = async (command: ReturnType<typeof $>) => {
    const output = await command.nothrow();
    return output.exitCode === 0 ? output.text().trim() : null;
  };

  const getDirectoryContext = async (
    directory: string,
  ): Promise<SessionContext> => {
    const cached = directoryContextCache.get(directory);
    if (cached) {
      return cached;
    }

    const promise = (async () => {
      const [root, branch] = await Promise.all([
        shellText($`git -C ${directory} rev-parse --show-toplevel`),
        shellText($`git -C ${directory} branch --show-current`),
      ]);

      const projectRoot = root ?? directory;
      const projectName = leafName(projectRoot);
      const worktreeName = root ? leafName(directory) : projectName;

      return {
        projectName,
        worktreeName,
        branchName: branch || "detached",
        directory,
      };
    })();

    directoryContextCache.set(directory, promise);
    return promise;
  };

  const rememberSession = (session: {
    id: string;
    parentID?: string;
    title: string;
    directory: string;
  }) => {
    const previous = sessions.get(session.id);
    if (previous && previous.directory !== session.directory) {
      directoryContextCache.delete(previous.directory);
    }

    sessions.set(session.id, session);
  };

  const forgetSession = (sessionID: string) => {
    const session = sessions.get(sessionID);
    if (session) {
      directoryContextCache.delete(session.directory);
    }

    sessions.delete(sessionID);
    sessionStates.delete(sessionID);
  };

  const fetchSession = async (sessionID: string) => {
    const cached = sessions.get(sessionID);
    if (cached) {
      return cached;
    }

    const response = await client.session.get({
      path: { id: sessionID },
      query: { directory: workspaceDirectory },
    });

    const session = response.data;
    if (!session) {
      return null;
    }

    const local = {
      id: session.id,
      parentID: session.parentID,
      title: session.title,
      directory: session.directory,
    };

    sessions.set(sessionID, local);
    return local;
  };

  const sessionDetails = async (sessionID: string) => {
    const session = await fetchSession(sessionID);
    if (!session) {
      return null;
    }

    const context = await getDirectoryContext(session.directory);

    return {
      ...context,
      title: compact(session.title || "OpenCode session"),
      sessionID: session.id.slice(0, 8),
      isMain: !session.parentID,
    };
  };

  const playNotification = async (
    title: string,
    message: string,
    subtitle?: string,
  ) => {
    const cleanTitle = compact(title);
    const cleanMessage = compact(message);
    const cleanSubtitle = subtitle ? compact(subtitle) : "";

    if (isMac) {
      try {
        await $`terminal-notifier -title ${cleanTitle} -message ${cleanMessage} -subtitle ${cleanSubtitle} -appIcon ${notificationIcon} -sound default`;
        return;
      } catch {
        const script = cleanSubtitle
          ? `display notification "${cleanMessage.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}" with title "${cleanTitle.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}" subtitle "${cleanSubtitle.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`
          : `display notification "${cleanMessage.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}" with title "${cleanTitle.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;

        await $`osascript -e ${script}`;
      }

      await $`afplay ${notificationSound}`;
    } else {
      // Avoid AppImage/other LD_LIBRARY_PATH shadowing system libnotify (symbol mismatch).
      await $`env -u LD_LIBRARY_PATH -u LD_PRELOAD notify-send --icon ${notificationIcon} ${cleanTitle} ${cleanMessage}`;
      await $`paplay ${notificationSound}`.catch(
        () => $`aplay ${notificationSound}`,
      );
    }
  };

  const notifyIdle = async (sessionID: string) => {
    if (sessionStates.get(sessionID) === "idle") {
      return;
    }

    sessionStates.set(sessionID, "idle");

    const details = await sessionDetails(sessionID);
    if (!details || !details.isMain) {
      return;
    }

    const title = `OpenCode: Task done`;
    const message = `${details.title} · ${details.sessionID}`;
    const subtitle = `${details.projectName} · ${details.worktreeName} · ${details.branchName} · ${details.directory}`;

    await playNotification(title, message, subtitle);
  };

  const notifyQuestion = async (
    sessionID: string,
    request: { questions: Array<{ header: string; question: string }> },
  ) => {
    const details = await sessionDetails(sessionID);
    const question = request.questions[0];

    await playNotification(
      "OpenCode: Question waiting",
      question
        ? `${question.header || "Input needed"} · ${details?.sessionID || sessionID.slice(0, 8)}`
        : `Input needed · ${details?.sessionID || sessionID.slice(0, 8)}`,
      details
        ? `${details.projectName} · ${details.worktreeName} · ${details.branchName} · ${details.directory}`
        : undefined,
    );
  };

  const notifyPermission = async (
    sessionID: string,
    permission: string,
    patterns: Array<string> | string,
  ) => {
    const details = await sessionDetails(sessionID);
    const confPatterns = Array.isArray(patterns)
      ? patterns.join(", ")
      : patterns;

    await playNotification(
      "OpenCode: Permission required",
      `${permission} · ${confPatterns}`,
      details
        ? `${details.projectName} · ${details.worktreeName} · ${details.branchName} · ${details.directory}`
        : undefined,
    );
  };

  return {
    event: async ({ event }) => {
      if (event.type === "session.created") {
        rememberSession(event.properties.info);
      }

      if (event.type === "session.updated") {
        rememberSession(event.properties.info);
      }

      if (event.type === "session.deleted") {
        forgetSession(event.properties.info.id);
      }

      if (event.type === "session.idle") {
        await notifyIdle(event.properties.sessionID);
      }

      if (event.type === "session.status") {
        const { sessionID, status } = event.properties;
        sessionStates.set(sessionID, status.type);

        if (status.type === "idle") {
          await notifyIdle(sessionID);
        }
      }

      //if (event.type === "question.asked") {
      //  await notifyQuestion(event.properties.sessionID, event.properties);
      //}

      if (event.type === "permission.updated") {
        await notifyPermission(
          event.properties.sessionID,
          event.properties.title,
          event.properties.pattern ?? "",
        );
      }
    },
  };
};
