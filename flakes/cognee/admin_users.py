"""Instance user administration for the self-hosted dashboard.

Every route needs an active superuser signed in through the dashboard session
cookie. API keys, bearer tokens and the optional default user are not accepted.
Changes go through Cognee's own user manager, key, permission, tenant and role
functions; this module adds the instance-wide view and the guardrails those
functions do not have.
"""

from contextlib import asynccontextmanager, contextmanager
from datetime import datetime
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from fastapi_users import exceptions as user_errors
from fastapi_users.authentication import Authenticator
from fastapi_users.db import SQLAlchemyUserDatabase
from pydantic import EmailStr, Field
from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError

from cognee.api.DTO import InDTO, OutDTO
from cognee.base_config import get_base_config
from cognee.exceptions import CogneeApiError
from cognee.infrastructure.databases.relational import get_relational_engine
from cognee.modules.data.models.Dataset import Dataset
from cognee.modules.users.api_key.create_api_key import apiKeySettings, create_api_key
from cognee.modules.users.api_key.delete_api_key import delete_api_key
from cognee.modules.users.api_key.exceptions import (
    ApiKeyCreationError,
    ApiKeyDeletionError,
    ApiKeyNotFoundError,
)
from cognee.modules.users.authentication.get_client_auth_backend import get_client_auth_backend
from cognee.modules.users.get_user_manager import UserManager, get_user_manager
from cognee.modules.users.methods.create_default_user import DEFAULT_USER_EMAIL
from cognee.modules.users.methods.create_user import NO_PASSWORD_SENTINEL, create_user
from cognee.modules.users.methods.get_agent_user_ids import get_agent_user_ids
from cognee.modules.users.models import ACL, Permission, Role, Tenant, User, UserRole, UserTenant
from cognee.modules.users.models.User import UserUpdate
from cognee.modules.users.models.UserApiKey import UserApiKey
from cognee.modules.users.permissions.methods import (
    get_tenant,
    give_permission_on_dataset,
)
from cognee.modules.users.permissions.methods.revoke_permission_on_dataset import (
    revoke_permission_on_dataset,
)
from cognee.modules.users.permissions.permission_types import PERMISSION_TYPES
from cognee.modules.users.roles.methods.add_user_to_role import add_user_to_role
from cognee.modules.users.roles.methods.remove_user_from_role import remove_user_from_role
from cognee.modules.users.tenants.methods.add_user_to_tenant import add_user_to_tenant
from cognee.modules.users.tenants.methods.remove_user_from_tenant import remove_user_from_tenant

NO_STORE = {"Cache-Control": "no-store"}
# Sent by the dashboard on every change. A cross-site page cannot add a custom
# header without a CORS preflight, which only configured origins pass.
INTENT_HEADER = "x-cognee-admin"
READ_METHODS = {"GET", "HEAD", "OPTIONS"}

DatasetPermission = Literal["read", "write", "delete", "share"]
Password = Field(min_length=8, max_length=128)


def refuse(status_code: int, detail: str) -> HTTPException:
    return HTTPException(status_code=status_code, detail=detail, headers=NO_STORE)


# Use the signed-in dashboard session, not API keys or the optional default user.
session_auth = Authenticator([get_client_auth_backend()], get_user_manager)
require_superuser = session_auth.current_user(active=True, superuser=True)


async def guard_request(request: Request, response: Response):
    response.headers.update(NO_STORE)
    if request.method in READ_METHODS:
        return
    if request.headers.get("sec-fetch-site", "same-origin") not in ("same-origin", "same-site"):
        raise refuse(403, "Cross-site requests cannot change accounts.")
    if request.headers.get(INTENT_HEADER) != "1":
        raise refuse(400, "Account changes must come from the dashboard.")


# Authentication runs first so an anonymous caller always gets 401.
router = APIRouter(
    prefix="/api/v1/admin",
    tags=["admin"],
    dependencies=[Depends(require_superuser), Depends(guard_request)],
)


class UserSummary(OutDTO):
    id: UUID
    email: str
    is_superuser: bool
    is_active: bool
    is_verified: bool
    has_password: bool
    is_self: bool
    is_default: bool
    is_agent: bool
    created_at: datetime | None
    api_key_count: int
    datasets_owned: int


class ApiKeyInfo(OutDTO):
    id: UUID
    name: str | None
    label: str | None
    created_at: datetime | None
    last_used_at: datetime | None


class NewApiKey(OutDTO):
    id: UUID
    name: str | None
    label: str | None
    key: str


class OwnedDataset(OutDTO):
    id: UUID
    name: str | None
    created_at: datetime | None


class DatasetAccess(OutDTO):
    dataset_id: UUID
    name: str | None
    owner_email: str | None
    permissions: list[str]
    # "direct" grants are editable here; the others follow a tenant or role.
    source: Literal["direct", "tenant", "role"]
    source_name: str | None
    # Cognee only honours a grant on a dataset in the user's current tenant.
    effective: bool


class DatasetOption(OutDTO):
    id: UUID
    name: str | None
    owner_email: str | None


class RoleRef(OutDTO):
    id: UUID
    name: str


class Membership(OutDTO):
    id: UUID
    name: str
    is_owner: bool
    is_current: bool
    roles: list[RoleRef]


class TenantOption(OutDTO):
    id: UUID
    name: str
    roles: list[RoleRef]


class Locks(OutDTO):
    """Why a change is refused, or None when it is allowed."""

    demote: str | None
    deactivate: str | None
    delete: str | None


class UserDetail(UserSummary):
    parent_email: str | None
    locks: Locks
    api_keys: list[ApiKeyInfo]
    max_api_keys: int
    owned_datasets: list[OwnedDataset]
    dataset_access: list[DatasetAccess]
    grantable_datasets: list[DatasetOption]
    tenants: list[Membership]
    available_tenants: list[TenantOption]


class CreateUser(InDTO):
    email: EmailStr
    # None creates an account that can only use API keys.
    password: str | None = Field(default=None, min_length=8, max_length=128)
    is_superuser: bool = False


class AccountChange(InDTO):
    is_superuser: bool | None = None
    is_active: bool | None = None
    is_verified: bool | None = None


class SetPassword(InDTO):
    password: str = Password
    revoke_api_keys: bool = False


class PasswordResult(OutDTO):
    revoked_api_keys: int


class CreateKey(InDTO):
    name: str = Field(min_length=1, max_length=80)


class SetPermissions(InDTO):
    permissions: list[DatasetPermission]


def default_email() -> str:
    return (get_base_config().default_user_email or DEFAULT_USER_EMAIL).lower()


def can_administer(user: User) -> bool:
    """A superuser who can sign in to the dashboard and act."""
    return bool(
        user.is_superuser and user.is_active and user.hashed_password != NO_PASSWORD_SENTINEL
    )


async def other_administrators(session, user_id: UUID) -> int:
    # Locked in id order so two superusers removing each other cannot both pass.
    rows = await session.execute(
        select(User.id)
        .where(
            User.is_superuser.is_(True),
            User.is_active.is_(True),
            User.hashed_password != NO_PASSWORD_SENTINEL,
            User.id != user_id,
        )
        .order_by(User.id)
        .with_for_update()
    )
    return len(rows.all())


SELF_LOCKS = {
    "demote": "You cannot remove your own superuser access.",
    "deactivate": "You cannot deactivate your own account.",
    "delete": "You cannot delete your own account.",
}
LAST_ADMIN = "This is the only superuser who can sign in."
DEFAULT_ACCOUNT = "Cognee recreates the built-in account, so it cannot be deleted."


async def lock_reason(session, admin: User, target: User, action: str) -> str | None:
    if target.id == admin.id:
        return SELF_LOCKS[action]
    if action == "delete" and target.email.lower() == default_email():
        return DEFAULT_ACCOUNT
    if can_administer(target) and await other_administrators(session, target.id) == 0:
        return LAST_ADMIN
    return None


@asynccontextmanager
async def user_manager():
    async with get_relational_engine().get_async_session() as session:
        yield session, UserManager(SQLAlchemyUserDatabase(session, User))


async def get_or_404(users: UserManager, user_id: UUID) -> User:
    try:
        return await users.get(user_id)
    except user_errors.UserNotExists:
        raise refuse(404, "User not found.") from None


async def find_user(user_id: UUID) -> User:
    """A detached user, for Cognee functions that open their own session."""
    async with user_manager() as (session, users):
        user = await get_or_404(users, user_id)
        session.expunge(user)
        return user


@contextmanager
def cognee_errors():
    """Report a refusal from Cognee as a conflict, never as a missing login."""
    try:
        yield
    except CogneeApiError as error:
        status_code = error.status_code if error.status_code in (400, 404, 409) else 409
        raise refuse(status_code, error.message) from error


def summary_query(admin_id: UUID):
    key_count = select(func.count()).select_from(UserApiKey).where(UserApiKey.user_id == User.id)
    datasets_owned = select(func.count()).select_from(Dataset).where(Dataset.owner_id == User.id)
    return select(
        User.id,
        User.email,
        User.is_superuser,
        User.is_active,
        User.is_verified,
        (User.hashed_password != NO_PASSWORD_SENTINEL).label("has_password"),
        (User.id == admin_id).label("is_self"),
        (func.lower(User.email) == default_email()).label("is_default"),
        User.parent_user_id.is_not(None).label("is_agent"),
        User.created_at,
        key_count.scalar_subquery().label("api_key_count"),
        datasets_owned.scalar_subquery().label("datasets_owned"),
    )


@router.get("/users", response_model=list[UserSummary])
async def list_users(admin: User = Depends(require_superuser)):
    query = summary_query(admin.id).order_by(
        User.is_superuser.desc(), func.lower(User.email), User.id
    )
    async with get_relational_engine().get_async_session() as session:
        return (await session.execute(query)).mappings().all()


@router.post("/users", response_model=UserSummary, status_code=201)
async def create_account(payload: CreateUser, admin: User = Depends(require_superuser)):
    if payload.is_superuser and payload.password is None:
        raise refuse(400, "A superuser needs a password to sign in.")
    try:
        created = await create_user(
            str(payload.email),
            payload.password,
            is_superuser=payload.is_superuser,
            is_active=True,
            is_verified=True,
        )
    except user_errors.UserAlreadyExists:
        raise refuse(409, "A user with this email already exists.") from None
    except user_errors.InvalidPasswordException as error:
        raise refuse(400, str(error.reason)) from None
    async with get_relational_engine().get_async_session() as session:
        query = summary_query(admin.id).where(User.id == created.id)
        return (await session.execute(query)).mappings().one()


@router.get("/users/{user_id}", response_model=UserDetail)
async def get_user_detail(user_id: UUID, admin: User = Depends(require_superuser)):
    async with get_relational_engine().get_async_session() as session:
        summary = (
            (await session.execute(summary_query(admin.id).where(User.id == user_id)))
            .mappings()
            .first()
        )
        if summary is None:
            raise refuse(404, "User not found.")
        target = (await session.execute(select(User).where(User.id == user_id))).scalar_one()

        # Named columns only: the stored key or its hash is never selected.
        api_keys = (
            await session.execute(
                select(
                    UserApiKey.id,
                    UserApiKey.name,
                    UserApiKey.label,
                    UserApiKey.created_at,
                    UserApiKey.last_used_at,
                )
                .where(UserApiKey.user_id == user_id)
                .order_by(UserApiKey.created_at, UserApiKey.id)
            )
        ).mappings().all()

        emails = dict((await session.execute(select(User.id, User.email))).all())
        datasets = (
            await session.execute(
                select(
                    Dataset.id, Dataset.name, Dataset.owner_id, Dataset.tenant_id, Dataset.created_at
                ).order_by(func.lower(Dataset.name), Dataset.id)
            )
        ).all()
        tenants = (
            await session.execute(
                select(Tenant.id, Tenant.name, Tenant.owner_id).order_by(func.lower(Tenant.name))
            )
        ).all()
        roles = (
            await session.execute(
                select(Role.id, Role.name, Role.tenant_id).order_by(func.lower(Role.name))
            )
        ).all()
        member_of = set(
            (
                await session.execute(
                    select(UserTenant.tenant_id).where(UserTenant.user_id == user_id)
                )
            ).scalars()
        )
        held_roles = set(
            (
                await session.execute(select(UserRole.role_id).where(UserRole.user_id == user_id))
            ).scalars()
        )

        sources = {user_id: ("direct", None)}
        sources.update({t.id: ("tenant", t.name) for t in tenants if t.id in member_of})
        sources.update({r.id: ("role", r.name) for r in roles if r.id in held_roles})
        grants: dict[tuple[UUID, UUID], set[str]] = {}
        for principal_id, dataset_id, permission in await session.execute(
            select(ACL.principal_id, ACL.dataset_id, Permission.name)
            .join(Permission, Permission.id == ACL.permission_id)
            .where(ACL.principal_id.in_(sources))
        ):
            grants.setdefault((dataset_id, principal_id), set()).add(permission)

        locks = Locks(
            demote=await lock_reason(session, admin, target, "demote"),
            deactivate=await lock_reason(session, admin, target, "deactivate"),
            delete=await lock_reason(session, admin, target, "delete"),
        )

    def roles_of(tenant_id: UUID, held_only: bool) -> list[RoleRef]:
        return [
            RoleRef(id=role.id, name=role.name)
            for role in roles
            if role.tenant_id == tenant_id and (role.id in held_roles or not held_only)
        ]

    dataset_access = []
    for dataset in datasets:
        if dataset.owner_id == user_id:
            continue
        for principal_id, (source, source_name) in sources.items():
            held = grants.get((dataset.id, principal_id))
            if held:
                dataset_access.append(
                    DatasetAccess(
                        dataset_id=dataset.id,
                        name=dataset.name,
                        owner_email=emails.get(dataset.owner_id),
                        permissions=[name for name in PERMISSION_TYPES if name in held],
                        source=source,
                        source_name=source_name,
                        effective=dataset.tenant_id == target.tenant_id,
                    )
                )

    return UserDetail(
        **summary,
        parent_email=emails.get(target.parent_user_id),
        locks=locks,
        api_keys=[ApiKeyInfo(**key) for key in api_keys],
        max_api_keys=apiKeySettings.max_user_api_keys,
        owned_datasets=[
            OwnedDataset(id=d.id, name=d.name, created_at=d.created_at)
            for d in datasets
            if d.owner_id == user_id
        ],
        dataset_access=dataset_access,
        grantable_datasets=[
            DatasetOption(id=d.id, name=d.name, owner_email=emails.get(d.owner_id))
            for d in datasets
            if d.owner_id != user_id and d.tenant_id == target.tenant_id
        ],
        tenants=[
            Membership(
                id=t.id,
                name=t.name,
                is_owner=t.owner_id == user_id,
                is_current=t.id == target.tenant_id,
                roles=roles_of(t.id, held_only=True),
            )
            for t in tenants
            if t.id in member_of
        ],
        available_tenants=[
            TenantOption(id=t.id, name=t.name, roles=roles_of(t.id, held_only=False))
            for t in tenants
        ],
    )


@router.put("/users/{user_id}/account", status_code=204)
async def change_account(
    user_id: UUID, payload: AccountChange, admin: User = Depends(require_superuser)
):
    changes = payload.model_dump(exclude_none=True)
    async with user_manager() as (session, users):
        target = await get_or_404(users, user_id)
        for field, action in (("is_superuser", "demote"), ("is_active", "deactivate")):
            if changes.get(field) is False and getattr(target, field):
                reason = await lock_reason(session, admin, target, action)
                if reason:
                    raise refuse(409, reason)
        if changes:
            await users.update(UserUpdate(**changes), target, safe=False)


@router.put("/users/{user_id}/password", response_model=PasswordResult)
async def set_password(user_id: UUID, payload: SetPassword):
    """Set a new password. Cognee binds every session token to the password
    hash, so this signs the user out everywhere; API keys stay unless revoked."""
    async with user_manager() as (session, users):
        target = await get_or_404(users, user_id)
        try:
            await users.update(UserUpdate(password=payload.password), target, safe=False)
        except user_errors.InvalidPasswordException as error:
            raise refuse(400, str(error.reason)) from None
        revoked = 0
        if payload.revoke_api_keys:
            result = await session.execute(delete(UserApiKey).where(UserApiKey.user_id == user_id))
            await session.commit()
            revoked = result.rowcount
    return PasswordResult(revoked_api_keys=revoked)


@router.delete("/users/{user_id}", status_code=204)
async def delete_account(user_id: UUID, admin: User = Depends(require_superuser)):
    """Delete the account, its keys, grants, memberships and agents. Datasets
    it owns are kept; Cognee leaves them stored under the deleted owner id."""
    async with user_manager() as (session, users):
        target = await get_or_404(users, user_id)
        reason = await lock_reason(session, admin, target, "delete")
        if reason:
            raise refuse(409, reason)
        try:
            # Cognee's own delete relies on cascades that SQLite does not
            # enforce and on memberships Postgres refuses to orphan.
            doomed = [user_id, *await get_agent_user_ids(session, user_id)]
            await session.execute(delete(UserRole).where(UserRole.user_id.in_(doomed)))
            await session.execute(delete(UserTenant).where(UserTenant.user_id.in_(doomed)))
            await session.execute(delete(UserApiKey).where(UserApiKey.user_id == user_id))
            await users.delete(target)
        except IntegrityError:
            await session.rollback()
            raise refuse(409, "Other records still refer to this user.") from None


@router.post("/users/{user_id}/api-keys", response_model=NewApiKey, status_code=201)
async def create_user_api_key(user_id: UUID, payload: CreateKey):
    name = payload.name.strip()
    if not name:
        raise refuse(400, "Give the key a name.")
    target = await find_user(user_id)
    try:
        created = await create_api_key(target, name=name)
    except ApiKeyCreationError as error:
        raise refuse(409, error.message) from None
    # The only response that ever carries a key value.
    return NewApiKey(id=created.id, name=created.name, label=created.label, key=created.api_key)


@router.delete("/users/{user_id}/api-keys/{api_key_id}", status_code=204)
async def revoke_user_api_key(user_id: UUID, api_key_id: UUID):
    target = await find_user(user_id)
    try:
        await delete_api_key(target, api_key_id)
    except ApiKeyNotFoundError:
        raise refuse(404, "API key not found.") from None
    except ApiKeyDeletionError as error:
        raise refuse(500, error.message) from None


@router.put("/users/{user_id}/datasets/{dataset_id}/permissions", status_code=204)
async def set_dataset_permissions(user_id: UUID, dataset_id: UUID, payload: SetPermissions):
    """Make the user's direct permissions on a dataset exactly this set."""
    target = await find_user(user_id)
    async with get_relational_engine().get_async_session() as session:
        dataset = (
            await session.execute(
                select(Dataset.owner_id, Dataset.tenant_id).where(Dataset.id == dataset_id)
            )
        ).first()
    if dataset is None:
        raise refuse(404, "Dataset not found.")
    if dataset.owner_id == user_id:
        raise refuse(409, "The owner's access to their own dataset cannot be changed here.")
    wanted = set(payload.permissions)
    if wanted and dataset.tenant_id != target.tenant_id:
        raise refuse(409, "This dataset is outside the user's current tenant.")
    with cognee_errors():
        for permission in PERMISSION_TYPES:
            if permission in wanted:
                await give_permission_on_dataset(target, dataset_id, permission)
            else:
                await revoke_permission_on_dataset(target, dataset_id, permission)


async def tenant_owner(tenant_id: UUID) -> UUID:
    """Cognee authorizes membership changes against a tenant; its owner always may."""
    tenant = await get_tenant(tenant_id)
    if tenant.owner_id is None:
        raise refuse(409, "This tenant has no owner to act for.")
    return tenant.owner_id


async def role_tenant(role_id: UUID) -> UUID:
    async with get_relational_engine().get_async_session() as session:
        tenant_id = (
            await session.execute(select(Role.tenant_id).where(Role.id == role_id))
        ).scalar()
    if tenant_id is None:
        raise refuse(404, "Role not found.")
    return tenant_id


@router.post("/users/{user_id}/tenants/{tenant_id}", status_code=204)
async def add_to_tenant(user_id: UUID, tenant_id: UUID):
    await find_user(user_id)
    with cognee_errors():
        await add_user_to_tenant(user_id, tenant_id, owner_id=await tenant_owner(tenant_id))


@router.delete("/users/{user_id}/tenants/{tenant_id}", status_code=204)
async def remove_from_tenant(user_id: UUID, tenant_id: UUID):
    await find_user(user_id)
    with cognee_errors():
        await remove_user_from_tenant(user_id, tenant_id, owner_id=await tenant_owner(tenant_id))


@router.post("/users/{user_id}/roles/{role_id}", status_code=204)
async def add_role(user_id: UUID, role_id: UUID):
    await find_user(user_id)
    with cognee_errors():
        owner_id = await tenant_owner(await role_tenant(role_id))
        await add_user_to_role(user_id, role_id, owner_id=owner_id)


@router.delete("/users/{user_id}/roles/{role_id}", status_code=204)
async def remove_role(user_id: UUID, role_id: UUID):
    await find_user(user_id)
    with cognee_errors():
        owner_id = await tenant_owner(await role_tenant(role_id))
        await remove_user_from_role(user_id, role_id, owner_id=owner_id)
