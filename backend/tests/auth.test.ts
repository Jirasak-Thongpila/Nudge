import { describe, expect, it, beforeEach } from "bun:test";
import { createApp } from "../src/app";
import { UserService } from "../src/services/user.service";
import type { User } from "../src/db/schema";

class MockUserService extends UserService {
  private store: User[] = [];
  private nextId = 1;

  override async getOrCreateUser(deviceUuid: string): Promise<User> {
    if (!deviceUuid || deviceUuid.trim() === "") {
      throw new Error("Device UUID cannot be empty");
    }
    const trimmed = deviceUuid.trim();
    let existing = this.store.find((u) => u.deviceUuid === trimmed);
    if (!existing) {
      existing = {
        id: this.nextId++,
        deviceUuid: trimmed,
        lineUserId: null,
        createdAt: new Date(),
      };
      this.store.push(existing);
    }
    return existing;
  }

  override async findByDeviceUuid(deviceUuid: string): Promise<User | null> {
    return this.store.find((u) => u.deviceUuid === deviceUuid.trim()) ?? null;
  }
}

describe("Walking Skeleton & ADR-0001 Auth", () => {
  let mockService: MockUserService;
  let app: ReturnType<typeof createApp>;

  beforeEach(() => {
    mockService = new MockUserService();
    app = createApp({ userService: mockService });
  });

  describe("Health Check", () => {
    it("should return 200 OK and service info", async () => {
      const response = await app.handle(new Request("http://localhost/health"));
      expect(response.status).toBe(200);

      const body = (await response.json()) as { status: string; service: string; timestamp: string };
      expect(body.status).toBe("ok");
      expect(body.service).toBe("nudge-backend");
      expect(body.timestamp).toBeDefined();
    });
  });

  describe("Anonymous Device UUID Authentication (ADR-0001)", () => {
    it("should reject request to /users/me when x-device-uuid header is missing", async () => {
      const response = await app.handle(new Request("http://localhost/users/me"));
      expect(response.status).toBe(401);

      const body = (await response.json()) as { success: boolean; error: string };
      expect(body.success).toBe(false);
      expect(body.error).toContain("x-device-uuid");
    });

    it("should reject request when x-device-uuid is blank", async () => {
      const response = await app.handle(
        new Request("http://localhost/users/me", {
          headers: {
            "x-device-uuid": "   ",
          },
        })
      );
      expect(response.status).toBe(401);
    });

    it("should automatically register and return new user when x-device-uuid is provided", async () => {
      const testUuid = "device-uuid-abc-123";
      const response = await app.handle(
        new Request("http://localhost/users/me", {
          headers: {
            "x-device-uuid": testUuid,
          },
        })
      );

      expect(response.status).toBe(200);
      const body = (await response.json()) as {
        success: boolean;
        data: { id: number; deviceUuid: string; lineUserId: string | null; createdAt: string };
      };
      expect(body.success).toBe(true);
      expect(body.data.id).toBe(1);
      expect(body.data.deviceUuid).toBe(testUuid);
      expect(body.data.lineUserId).toBeNull();
      expect(body.data.createdAt).toBeDefined();
    });

    it("should return existing user without duplicating on subsequent requests with same device UUID", async () => {
      const testUuid = "device-uuid-persistent-789";

      // First call: registers user
      const res1 = await app.handle(
        new Request("http://localhost/users/me", {
          headers: { "x-device-uuid": testUuid },
        })
      );
      const data1 = (await res1.json()) as {
        data: { id: number; deviceUuid: string };
      };
      expect(data1.data.id).toBe(1);

      // Second call: retrieves same user
      const res2 = await app.handle(
        new Request("http://localhost/users/me", {
          headers: { "x-device-uuid": testUuid },
        })
      );
      const data2 = (await res2.json()) as {
        data: { id: number; deviceUuid: string };
      };
      expect(data2.data.id).toBe(1);
      expect(data2.data.deviceUuid).toBe(testUuid);
    });
  });
});
