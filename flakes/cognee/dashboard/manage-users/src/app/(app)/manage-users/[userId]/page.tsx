"use client";

import { useParams } from "next/navigation";
import UserDetailView from "@/modules/admin-users/UserDetailView";

export default function ManageUserPage() {
  const { userId } = useParams<{ userId: string }>();
  return <UserDetailView userId={userId} />;
}
