// The upstream contract: every import the Manage Users overlay takes from the
// Cognee dashboard's own source goes through this file. A rename or removal
// upstream breaks the build here, in one place.

export { getLocalApiUrl } from "@/modules/users/getLocalApiUrl";

export { ACCESS_LEVELS, levelFor, permissionsFor } from "@/modules/permissions/accessLevels";
export type { AccessLevel } from "@/modules/permissions/accessLevels";

export { default as ModalShell } from "@/ui/elements/ModalShell";
export { fieldErrorStyle, modalHintStyle, modalTitleStyle } from "@/ui/elements/modalStyles";
export {
  BORDER,
  BORDER_SOFT,
  ROW_BORDER,
  TEXT,
  TEXT_FAINT,
  TEXT_MUTED,
  cardStyle,
  inputStyle,
  pageTitleStyle,
  selectStyle,
} from "@/ui/elements/panelTokens";

export { useNavbar } from "@/ui/layout/NavbarContext";
export { default as NavbarNavItem } from "@/ui/layout/Navbar/NavbarNavItem";
export { default as NavbarSectionLabel } from "@/ui/layout/Navbar/NavbarSectionLabel";
