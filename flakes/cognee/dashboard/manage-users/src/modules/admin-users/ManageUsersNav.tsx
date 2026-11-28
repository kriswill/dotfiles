"use client";

import type { ReactElement } from "react";
import { usePathname } from "next/navigation";
import { NavbarNavItem, NavbarSectionLabel, useNavbar } from "./upstream";
import { useSuperuser } from "./useSuperuser";

export const MANAGE_USERS_PATH = "/manage-users";

function UsersIcon({ active }: { active: boolean }): ReactElement {
  return (
    <svg aria-hidden="true" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={active ? "#BC9BFF" : "rgba(255,255,255,0.5)"} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2m20 0v-2a4 4 0 0 0-3-3.9M16 3.1a4 4 0 0 1 0 7.8" />
      <circle cx="9" cy="7" r="4" />
    </svg>
  );
}

const ITEM = { text: "Manage Users", link: MANAGE_USERS_PATH, icon: UsersIcon };

/** The sidebar's Administration section. Renders nothing for other users. */
export default function ManageUsersNav(): ReactElement | null {
  const pathname = usePathname();
  const { collapsed, isOpen } = useNavbar();
  const isSuperuser = useSuperuser();
  if (!isSuperuser) return null;

  // Same rule as the sidebar itself: the mobile drawer always shows labels.
  const railed = collapsed && !isOpen;
  return (
    <div className="mb-4">
      <NavbarSectionLabel label="Administration" railed={railed} />
      <NavbarNavItem item={ITEM} pathname={pathname ?? ""} railed={railed} isLocked={() => false} />
    </div>
  );
}
