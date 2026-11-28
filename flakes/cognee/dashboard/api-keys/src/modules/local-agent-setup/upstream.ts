// The upstream contract: every import the local agent-setup modal takes from
// the Cognee dashboard's own source goes through this file.

export { AgentSetupModal } from "@/ui/elements/AgentSetupModal";
export { useCogniInstance } from "@/modules/tenant/TenantProvider";
export { isAgentIntegrationKey } from "@/modules/agents/getAgentConnections";

export type { SetupConnectorCfg } from "@/modules/integrations/types";
