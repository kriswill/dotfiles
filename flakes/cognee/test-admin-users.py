"""Run against the packaged Cognee app with scratch HOME and database paths."""

import asyncio
import os
from uuid import UUID, uuid4

from fastapi.testclient import TestClient
from sqlalchemy import select

from cognee.api.admin_users import LAST_ADMIN, lock_reason
from cognee.api.client import app
from cognee.infrastructure.databases.relational import get_relational_engine
from cognee.infrastructure.databases.relational.create_db_and_tables import create_db_and_tables
from cognee.modules.data.models.Dataset import Dataset
from cognee.modules.users.methods.create_user import create_user
from cognee.modules.users.models import ACL, Role, Tenant, User, UserRole, UserTenant
from cognee.modules.users.models.UserApiKey import UserApiKey
from cognee.modules.users.tenants.methods.create_tenant import create_tenant

USERS = "/api/v1/admin/users"
ADMIN = "operator@example.com"
MEMBER = "reader@example.com"
SECOND = "second@example.com"
PASSWORD = "fixture-only-inventory-password!"
NEW_PASSWORD = "fixture-only-replacement-password!"
INTENT = {"X-Cognee-Admin": "1"}
SUMMARY = {
    "id", "email", "isSuperuser", "isActive", "isVerified", "hasPassword", "isSelf",
    "isDefault", "isAgent", "createdAt", "apiKeyCount", "datasetsOwned",
}  # fmt: skip
SECRETS = ("hashed_password", "hashedPassword", "$argon2", "$2b$", "pbkdf2_sha256")
ids = {}


async def seed():
    await create_db_and_tables()
    admin = await create_user(ADMIN, PASSWORD, is_superuser=True)
    reader = await create_user(MEMBER, PASSWORD)
    # A superuser nobody can sign in as must not count as the last administrator.
    await create_user("keyonly@example.com", None, is_superuser=True)
    tenant_id = await create_tenant("fixture tenant", admin.id, set_as_active_tenant=False)
    async with get_relational_engine().get_async_session() as session:
        owned = Dataset(name="inventory-fixture", owner_id=reader.id)
        shared = Dataset(name="shared-fixture", owner_id=admin.id)
        elsewhere = Dataset(name="tenant-fixture", owner_id=admin.id, tenant_id=tenant_id)
        role = Role(name="fixture role", tenant_id=tenant_id)
        session.add_all([owned, shared, elsewhere, role])
        await session.commit()
        ids.update(
            admin=str(admin.id), reader=str(reader.id), tenant=str(tenant_id), role=str(role.id),
            owned=str(owned.id), shared=str(shared.id), elsewhere=str(elsewhere.id),
        )  # fmt: skip


async def last_administrator_lock(target_id):
    async with get_relational_engine().get_async_session() as session:
        actor = (await session.execute(select(User).filter_by(email="keyonly@example.com"))).scalar_one()
        target = (await session.execute(select(User).filter_by(id=UUID(target_id)))).scalar_one()
        return await lock_reason(session, actor, target, "demote")


async def rows(model, **filters):
    async with get_relational_engine().get_async_session() as session:
        return (await session.execute(select(model).filter_by(**filters))).scalars().all()


def count(model, **filters):
    return len(asyncio.run(rows(model, **filters)))


def login(client, email, password=PASSWORD, expect=200):
    client.cookies.clear()
    response = client.post("/api/v1/auth/login", data={"username": email, "password": password})
    assert response.status_code == expect, (email, response.status_code)
    if expect != 200:
        return None
    assert client.get("/api/v1/users/me").json()["email"] == email
    return response.json()["access_token"]


def mutations(target):
    """Every state-changing route, for the authorization sweep."""
    user = f"{USERS}/{target}"
    return [
        ("post", USERS, {"email": "sweep@example.com", "password": PASSWORD}),
        ("put", f"{user}/account", {"isActive": False}),
        ("put", f"{user}/password", {"password": NEW_PASSWORD}),
        ("delete", user, None),
        ("post", f"{user}/api-keys", {"name": "sweep"}),
        ("delete", f"{user}/api-keys/{uuid4()}", None),
        ("put", f"{user}/datasets/{ids['shared']}/permissions", {"permissions": ["read"]}),
        ("post", f"{user}/tenants/{ids['tenant']}", None),
        ("delete", f"{user}/tenants/{ids['tenant']}", None),
        ("post", f"{user}/roles/{ids['role']}", None),
        ("delete", f"{user}/roles/{ids['role']}", None),
    ]


def sweep(client, target, expected, headers, why):
    for method, path, body in mutations(target):
        response = client.request(method, path, json=body, headers=headers)
        assert response.status_code == expected, (why, method, path, response.status_code)
        # The collection and the user itself are the only paths GET may read.
        if path not in (USERS, f"{USERS}/{target}"):
            assert client.get(path, headers=headers).status_code in (401, 403, 405), path


def check(response, status=204, invalid=False):
    assert response.status_code == status, (response.status_code, response.text)
    # Cognee's own handler answers a malformed body before the route runs.
    assert invalid or response.headers["cache-control"] == "no-store"
    assert not any(secret in response.text for secret in SECRETS), response.text
    return response.json() if response.content else None


def main():
    assert os.environ["REQUIRE_AUTHENTICATION"] == "false"
    assert os.environ["PYTHON_DOTENV_DISABLED"] == "1"
    asyncio.run(seed())
    reader = f"{USERS}/{ids['reader']}"
    # Exercise the real routes and database without starting the unrelated
    # embedder, graph migrations or pipeline recovery services.
    # Entering TestClient itself would run the application lifespan.
    client = TestClient(app, base_url="https://testserver")
    try:
        # --- who may call ---
        assert client.get(USERS).status_code == 401, "must require an authenticated identity"
        assert client.get(reader).status_code == 401
        sweep(client, ids["reader"], 401, INTENT, "anonymous")

        login(client, MEMBER)
        denied = client.get(USERS)
        assert denied.status_code == 403
        assert ADMIN not in denied.text
        assert client.get(reader).status_code == 403
        sweep(client, ids["admin"], 403, INTENT, "standard user")
        created_key = client.post("/api/v1/auth/api-keys", json={"name": "inventory fixture"})
        assert created_key.status_code == 200, created_key.status_code

        admin_token = login(client, ADMIN)
        admin_key = client.post("/api/v1/auth/api-keys", json={"name": "superuser fixture"})
        assert admin_key.status_code == 200
        client.cookies.clear()
        for headers in (
            {"X-Api-Key": admin_key.json()["key"]},
            {"Authorization": f"Bearer {admin_token}"},
        ):
            assert client.get("/api/v1/users/me", headers=headers).json()["email"] == ADMIN
            assert client.get(USERS, headers=headers).status_code == 401, (
                "must require a dashboard session, not a programmatic credential"
            )
            sweep(client, ids["reader"], 401, {**headers, **INTENT}, "programmatic credential")

        assert client.get("/api/v1/auth/api-keys").status_code == 401
        assert client.post("/api/v1/auth/api-keys", json={"name": "auth fixture"}).status_code == 401
        key_id = admin_key.json()["id"]
        key_path = f"/api/v1/auth/api-keys/{key_id}"
        assert client.delete(key_path).status_code == 401
        admin_headers = {"X-Api-Key": admin_key.json()["key"]}
        keys = client.get("/api/v1/auth/api-keys", headers=admin_headers)
        assert keys.status_code == 200 and {row["id"] for row in keys.json()} == {key_id}
        assert client.delete(key_path, headers=admin_headers).status_code == 200

        # --- a superuser session without the dashboard's intent header ---
        login(client, ADMIN)
        sweep(client, ids["reader"], 400, {}, "missing intent header")
        sweep(client, ids["reader"], 403, {**INTENT, "Sec-Fetch-Site": "cross-site"}, "cross-site")
        assert count(User, email=MEMBER, is_active=True) == 1, "refused requests changed nothing"
        client.headers.update(INTENT)

        # --- inventory ---
        listing = check(client.get(USERS), 200)
        assert all(set(row) == SUMMARY and UUID(row["id"]) for row in listing)
        accounts = {row["email"]: row for row in listing}
        assert len(accounts) == len(listing) == 3
        assert accounts[ADMIN]["isSuperuser"] and accounts[ADMIN]["isSelf"]
        assert not accounts[MEMBER]["isSuperuser"] and not accounts[MEMBER]["isSelf"]
        assert accounts[MEMBER]["apiKeyCount"] == 1 and accounts[MEMBER]["datasetsOwned"] == 1
        assert accounts["keyonly@example.com"]["hasPassword"] is False
        assert created_key.json()["key"] not in client.get(USERS).text

        # --- detail ---
        detail = check(client.get(reader), 200)
        assert [d["name"] for d in detail["ownedDatasets"]] == ["inventory-fixture"]
        assert [set(key) for key in detail["apiKeys"]] == [
            {"id", "name", "label", "createdAt", "lastUsedAt"}
        ]
        assert created_key.json()["key"] not in client.get(reader).text
        assert detail["locks"] == {"demote": None, "deactivate": None, "delete": None}
        assert {d["name"] for d in detail["grantableDatasets"]} == {"shared-fixture"}
        assert check(client.get(f"{USERS}/{uuid4()}"), 404)["detail"] == "User not found."

        # --- self and last-superuser guardrails ---
        me = f"{USERS}/{ids['admin']}"
        own = check(client.get(me), 200)["locks"]
        assert all(own.values()), own
        assert "own" in check(client.put(f"{me}/account", json={"isSuperuser": False}), 409)["detail"]
        assert "own" in check(client.put(f"{me}/account", json={"isActive": False}), 409)["detail"]
        assert "own" in check(client.delete(me), 409)["detail"]
        assert count(User, email=ADMIN, is_superuser=True, is_active=True) == 1

        second = check(client.post(USERS, json={"email": SECOND, "password": PASSWORD, "isSuperuser": True}), 201)
        assert second["isSuperuser"] and second["hasPassword"] and second["isVerified"]
        check(client.post(USERS, json={"email": SECOND, "password": PASSWORD}), 409)
        check(client.post(USERS, json={"email": "short@example.com", "password": "short"}), 400, True)
        check(client.post(USERS, json={"email": "not an address", "password": PASSWORD}), 400, True)
        check(client.post(USERS, json={"email": "nopass@example.com", "isSuperuser": True}), 400)
        agent = check(client.post(USERS, json={"email": "agent@example.com"}), 201)
        assert agent["hasPassword"] is False
        login(client, "agent@example.com", PASSWORD, expect=400)

        # The second superuser deactivates the first, and is then the last one
        # who can sign in: nobody is left who could remove them.
        login(client, SECOND)
        check(client.put(f"{me}/account", json={"isActive": False}))
        login(client, ADMIN, expect=400)
        login(client, SECOND)
        sole = f"{USERS}/{second['id']}"
        assert all(check(client.get(sole), 200)["locks"].values())
        check(client.put(f"{sole}/account", json={"isSuperuser": False}), 409)
        check(client.delete(sole), 409)
        # The guard does not depend on who asks: seen by an account that cannot
        # sign in, the only superuser who can is still protected.
        assert asyncio.run(last_administrator_lock(second["id"])) == LAST_ADMIN
        # Reactivated, the first can be demoted, but only while another remains.
        check(client.put(f"{me}/account", json={"isActive": True}))
        check(client.put(f"{me}/account", json={"isSuperuser": False}))
        assert check(client.get(USERS), 200) and count(User, email=ADMIN, is_superuser=True) == 0
        check(client.put(f"{me}/account", json={"isSuperuser": True}))
        login(client, ADMIN)

        # --- account flags ---
        check(client.put(f"{reader}/account", json={"isVerified": False}))
        check(client.put(f"{reader}/account", json={"isActive": False}))
        login(client, MEMBER, expect=400)
        member_key = {"X-Api-Key": created_key.json()["key"]}
        assert client.get("/api/v1/users/me", headers=member_key).status_code == 401
        login(client, ADMIN)
        check(client.put(f"{reader}/account", json={"isActive": True, "isVerified": True}))

        # --- password reset ends existing sessions ---
        member = TestClient(app, base_url="https://testserver")
        login(member, MEMBER)
        check(client.put(f"{reader}/password", json={"password": "short"}), 400, True)
        assert member.get("/api/v1/users/me").status_code == 200
        assert check(client.put(f"{reader}/password", json={"password": NEW_PASSWORD}), 200) == {
            "revokedApiKeys": 0
        }
        assert member.get("/api/v1/users/me").status_code == 401, "old session must stop working"
        member.close()
        assert client.get("/api/v1/users/me", headers=member_key).status_code == 200
        login(client, MEMBER, expect=400)
        login(client, MEMBER, NEW_PASSWORD)
        login(client, ADMIN)
        revoked = client.put(
            f"{reader}/password", json={"password": PASSWORD, "revokeApiKeys": True}
        )
        assert check(revoked, 200) == {"revokedApiKeys": 1}
        client.cookies.clear()
        assert client.get("/api/v1/users/me", headers=member_key).status_code == 401
        login(client, ADMIN)

        # --- API keys on a user's behalf ---
        check(client.post(f"{reader}/api-keys", json={"name": "  "}), 400)
        check(client.post(f"{reader}/api-keys", json={"name": ""}), 400, True)
        issued = check(client.post(f"{reader}/api-keys", json={"name": "issued"}), 201)
        assert set(issued) == {"id", "name", "label", "key"} and len(issued["key"]) == 64
        stored = asyncio.run(rows(UserApiKey, user_id=UUID(ids["reader"])))
        assert [key.api_key for key in stored] != [issued["key"]], "keys are stored hashed"
        after = client.get(reader)
        assert issued["key"] not in after.text and stored[0].api_key not in after.text
        assert [key["name"] for key in after.json()["apiKeys"]] == ["issued"]
        client.cookies.clear()
        issued_headers = {"X-Api-Key": issued["key"]}
        assert client.get("/api/v1/users/me", headers=issued_headers).json()["email"] == MEMBER
        login(client, ADMIN)
        # A key can only be revoked through the user who holds it.
        check(client.delete(f"{me}/api-keys/{issued['id']}"), 404)
        check(client.delete(f"{reader}/api-keys/{issued['id']}"))
        check(client.delete(f"{reader}/api-keys/{issued['id']}"), 404)
        client.cookies.clear()
        assert client.get("/api/v1/users/me", headers=issued_headers).status_code == 401
        login(client, ADMIN)

        # --- dataset permissions ---
        grant = f"{reader}/datasets/{ids['shared']}/permissions"
        check(client.put(grant, json={"permissions": ["read", "write"]}))
        access = check(client.get(reader), 200)["datasetAccess"]
        assert [(a["name"], a["permissions"], a["source"], a["effective"]) for a in access] == [
            ("shared-fixture", ["read", "write"], "direct", True)
        ]
        check(client.put(grant, json={"permissions": ["read"]}))
        assert check(client.get(reader), 200)["datasetAccess"][0]["permissions"] == ["read"]
        check(client.put(grant, json={"permissions": ["owner"]}), 400, True)
        check(client.put(f"{reader}/datasets/{ids['owned']}/permissions", json={"permissions": []}), 409)
        check(client.put(f"{reader}/datasets/{ids['elsewhere']}/permissions", json={"permissions": ["read"]}), 409)
        check(client.put(f"{reader}/datasets/{uuid4()}/permissions", json={"permissions": ["read"]}), 404)
        check(client.put(grant, json={"permissions": []}))
        assert check(client.get(reader), 200)["datasetAccess"] == []
        check(client.put(grant, json={"permissions": ["read"]}))

        # --- tenants and roles ---
        membership = f"{reader}/tenants/{ids['tenant']}"
        role = f"{reader}/roles/{ids['role']}"
        check(client.post(role), 404)  # not a member of the role's tenant yet
        check(client.post(membership))
        check(client.post(membership), 409)
        check(client.post(role))
        tenants = check(client.get(reader), 200)["tenants"]
        assert [(t["name"], t["isOwner"], [r["name"] for r in t["roles"]]) for t in tenants] == [
            ("fixture tenant", False, ["fixture role"])
        ]
        check(client.delete(role))
        assert check(client.get(reader), 200)["tenants"][0]["roles"] == []
        check(client.post(role))
        check(client.delete(membership))
        assert check(client.get(reader), 200)["tenants"] == []
        assert count(UserRole, user_id=UUID(ids["reader"])) == 0
        check(client.delete(f"{me}/tenants/{ids['tenant']}"), 400)  # the tenant's owner
        check(client.post(f"{reader}/tenants/{uuid4()}"), 404)
        check(client.post(f"{reader}/roles/{uuid4()}"), 404)
        check(client.post(membership))
        check(client.post(role))

        # --- delete ---
        check(client.post(f"{reader}/api-keys", json={"name": "doomed"}), 201)
        check(client.delete(reader))
        check(client.get(reader), 404)
        check(client.delete(reader), 404)
        gone = UUID(ids["reader"])
        assert count(User, email=MEMBER) == 0
        assert count(UserApiKey, user_id=gone) == count(ACL, principal_id=gone) == 0
        assert count(UserRole, user_id=gone) == count(UserTenant, user_id=gone) == 0
        assert count(Dataset, owner_id=gone) == 1, "owned datasets are kept"
        assert count(Tenant, id=UUID(ids["tenant"])) == 1
    finally:
        client.close()
    print("PASS: user administration requires a superuser dashboard session and keeps a superuser")


if __name__ == "__main__":
    main()
