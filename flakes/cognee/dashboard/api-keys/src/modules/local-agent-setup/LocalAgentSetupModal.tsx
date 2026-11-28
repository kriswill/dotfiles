"use client";

import { useState, type ComponentProps, type ReactElement } from "react";
import { createLocalApiKey } from "@/modules/local-api-keys/localApiKeys";
import { AgentSetupModal, isAgentIntegrationKey, useCogniInstance } from "./upstream";
import type { SetupConnectorCfg } from "./upstream";

/**
 * Upstream's agent setup modal, for a self-hosted Cognee. Upstream fills the
 * setup instructions with the workspace's API key, which a local instance
 * does not have. For the agents that need one (Claude Code, Codex, Hermes)
 * this asks for a key on request and shows the instructions once it exists.
 *
 * It changes nothing inside upstream's modal: it hands it the same cards with
 * `buildSteps` wrapped, so the contract is that prop and the modal's own.
 */
export function LocalAgentSetupModal(props: ComponentProps<typeof AgentSetupModal>): ReactElement | null {
  const { cogniInstance, isInitializing } = useCogniInstance();
  const [localKeys, setLocalKeys] = useState<Partial<Record<string, string>>>({});
  const [creatingKey, setCreatingKey] = useState<string | null>(null);
  const [keyError, setKeyError] = useState<{ connector: string; message: string } | null>(null);

  async function prepareLocalKey(connector: SetupConnectorCfg) {
    setCreatingKey(connector.key);
    setKeyError(null);
    try {
      const result = await createLocalApiKey({ name: connector.name + " setup" });
      if (result.ok && result.key?.key) {
        const key = result.key.key;
        setLocalKeys((previous) => ({ ...previous, [connector.key]: key }));
      } else {
        const message = result.ok ? "The server did not return the key." : result.error;
        setKeyError({ connector: connector.key, message });
      }
    } finally {
      setCreatingKey(null);
    }
  }

  const isLocal = cogniInstance?.name === "LocalCognee";
  const cards = props.cards.map((card): SetupConnectorCfg => {
    if (!isLocal || !(isAgentIntegrationKey(card.key) || card.key === "hermes")) return card;
    return {
      ...card,
      // Upstream passes the workspace key and its own gate; a local setup
      // has neither until a key is created here.
      buildSteps: (baseUrl, _workspaceKey, _gated, os) => {
        const setupKey = localKeys[card.key];
        const steps = card.buildSteps(baseUrl, setupKey || "your-api-key", isInitializing || !setupKey, os);
        if (!setupKey) {
          steps[card.key === "hermes" ? 0 : 1] = {
            title: "Create an API key",
            description: "Create a Cognee API key to show the setup instructions.",
            content: (
              <>
                <button
                  type="button"
                  className="mt-3 border border-white/20 px-3 py-2 text-sm text-white"
                  disabled={isInitializing || creatingKey !== null}
                  onClick={(event) => {
                    event.stopPropagation();
                    void prepareLocalKey(card);
                  }}
                >
                  {creatingKey === card.key ? "Creating API key…" : "Create API key"}
                </button>
                {keyError?.connector === card.key && <p role="alert">{keyError.message}</p>}
              </>
            ),
          };
        }
        return steps;
      },
    };
  });

  return <AgentSetupModal {...props} cards={cards} />;
}
