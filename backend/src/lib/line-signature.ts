import { createHmac, timingSafeEqual } from "node:crypto";

/**
 * Verifies the `X-Line-Signature` header sent by the LINE Messaging API.
 *
 * The signature is `base64(HMAC-SHA256(channelSecret, rawRequestBody))`.
 * The raw request body MUST be the exact bytes LINE sent (not a re-serialized object),
 * otherwise the digest will not match.
 *
 * @see https://developers.line.biz/en/reference/messaging-api/#signature-validation
 */
export function verifyLineSignature(
  rawBody: string,
  signature: string | null | undefined,
  channelSecret: string | null | undefined
): boolean {
  if (!channelSecret || !signature) {
    return false;
  }

  const expected = createHmac("sha256", channelSecret)
    .update(rawBody, "utf8")
    .digest("base64");

  const expectedBuffer = Buffer.from(expected, "utf8");
  const actualBuffer = Buffer.from(signature, "utf8");

  // timingSafeEqual throws when lengths differ, so guard first.
  if (expectedBuffer.length !== actualBuffer.length) {
    return false;
  }

  return timingSafeEqual(expectedBuffer, actualBuffer);
}
