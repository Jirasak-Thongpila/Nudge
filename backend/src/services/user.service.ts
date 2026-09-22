import { eq } from "drizzle-orm";
import { users, type User } from "../db/schema";
import { db as defaultDb, type Database } from "../db";

export class UserService {
  constructor(private db: Database = defaultDb) {}

  async getOrCreateUser(deviceUuid: string): Promise<User> {
    if (!deviceUuid || deviceUuid.trim() === "") {
      throw new Error("Device UUID cannot be empty");
    }

    const trimmedUuid = deviceUuid.trim();

    // Check if user already exists
    const existing = await this.db
      .select()
      .from(users)
      .where(eq(users.deviceUuid, trimmedUuid))
      .limit(1);

    if (existing.length > 0) {
      return existing[0];
    }

    // Otherwise, create a new user (ADR-0001: Anonymous Device UUID Auth)
    const [newUser] = await this.db
      .insert(users)
      .values({
        deviceUuid: trimmedUuid,
      })
      .returning();

    return newUser;
  }

  async findByDeviceUuid(deviceUuid: string): Promise<User | null> {
    const rows = await this.db
      .select()
      .from(users)
      .where(eq(users.deviceUuid, deviceUuid.trim()))
      .limit(1);

    return rows[0] ?? null;
  }

  async findById(userId: number): Promise<User | null> {
    const rows = await this.db
      .select()
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);

    return rows[0] ?? null;
  }

  async getOrCreateUserByLineUserId(lineUserId: string, fallbackDeviceUuid?: string): Promise<User> {
    if (!lineUserId || lineUserId.trim() === "") {
      throw new Error("LINE User ID cannot be empty");
    }
    const trimmedLineId = lineUserId.trim();

    // 1. Check if user with this lineUserId already exists
    const existing = await this.db
      .select()
      .from(users)
      .where(eq(users.lineUserId, trimmedLineId))
      .limit(1);

    if (existing.length > 0) {
      return existing[0];
    }

    // 2. If fallbackDeviceUuid is provided, check if that device exists and link it
    if (fallbackDeviceUuid && fallbackDeviceUuid.trim() !== "") {
      const deviceUser = await this.findByDeviceUuid(fallbackDeviceUuid);
      if (deviceUser) {
        const linked = await this.linkLineUserId(deviceUser.id, trimmedLineId);
        if (linked) return linked;
      }
    }

    // 3. Otherwise, create a new user with this lineUserId
    const [newUser] = await this.db
      .insert(users)
      .values({
        deviceUuid: fallbackDeviceUuid?.trim() || `line-${trimmedLineId}`,
        lineUserId: trimmedLineId,
      })
      .returning();

    return newUser;
  }

  async linkLineUserId(userId: number, lineUserId: string): Promise<User | null> {
    const [updated] = await this.db
      .update(users)
      .set({ lineUserId })
      .where(eq(users.id, userId))
      .returning();

    return updated ?? null;
  }
}

export const userService = new UserService();
