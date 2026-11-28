// The upstream contract: every import the document reader takes from the
// Cognee dashboard's own source goes through this file. A rename or removal
// upstream breaks the build here, in one place.

export { useCogniInstance } from "@/modules/tenant/TenantProvider";
export type { CogneeInstance } from "@/modules/instances/types";

export { needsContentRead } from "@/modules/datasets/describeTextBlob";
export { default as readTextPrefix } from "@/utils/readTextPrefix";
export { default as ModalShell } from "@/ui/elements/ModalShell";
