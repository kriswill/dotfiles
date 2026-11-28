// The upstream contract: every import the local API-key calls take from the
// Cognee dashboard's own source goes through this file. The three upstream
// stubs in src/modules/apiKeys keep their types and signatures and call into
// localApiKeys.ts.

export { default as localFetch } from "@/modules/instances/localFetch";
export { HttpError } from "@/services/http/errors";

export type { CreateApiKeyResult } from "@/modules/apiKeys/createAPIKey";
export type { ApiKey } from "@/modules/apiKeys/getApiKeys";
