// The upstream contract of the /api/releases route handler, which runs on the
// server: kept apart from upstream.ts so the route does not pull the
// dashboard's client components into its bundle.

export { getServerBackendUrl } from "@/modules/config/serverRuntimeConfig";
