// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3917 -- a payment intent whose provider answer was uncertain keeps a
// provisional order id (`pending:...`) until the same request is retried. The
// provider's order carries the intent's own id (metadata, the webhook address
// or the purchase unit's custom id), so a notification that names an order
// the server does not know yet finds its intent by that id, and the order is
// attached once the notification is proven genuine. Settlement stays the
// notifications' own, exactly once (settle_online_payment).

/** The name under which an order carries its intent's id. */
export const INTENT_KEY = "deskilo_intent";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** [value] when it is an intent id, else null: anything else names no intent. */
export const intentIdOf = (value: unknown): string | null =>
  typeof value === "string" && UUID.test(value) ? value : null;

type Result<T> = { data: T | null; error: { message: string } | null };

/** The intent [intentId] of one of [providers] that is still waiting for its
 * order id, with [columns]; none when [intentId] is null or names no such
 * intent (another provider's, or one whose order is already known). */
export async function provisionalIntent<T>(
  // deno-lint-ignore no-explicit-any
  admin: any,
  providers: string[],
  intentId: string | null,
  columns: string,
): Promise<Result<T>> {
  if (!intentId) return { data: null, error: null };
  return await admin
    .from("payment_intents")
    .select(columns)
    .in("provider", providers)
    .eq("id", intentId)
    .like("order_id", "pending:%")
    .maybeSingle();
}

/** What attaching an order found: written now ("attached"), already the
 * intent's ("same": the order request's own late write came first), or the
 * intent holds another order ("other": this event is not its). */
export type AttachOutcome = "attached" | "same" | "other";

/** Records [orderId] as the order of intent [intentId], only while it still
 * waits for one, and says what it found. */
export async function attachOrder(
  // deno-lint-ignore no-explicit-any
  admin: any,
  intentId: string,
  orderId: string,
): Promise<
  { error: { message: string } | null; outcome: AttachOutcome | null }
> {
  const written = await admin
    .from("payment_intents")
    .update({ order_id: orderId })
    .eq("id", intentId)
    .like("order_id", "pending:%")
    .select("order_id");
  if (written.error) return { error: written.error, outcome: null };
  if (((written.data ?? []) as unknown[]).length > 0) {
    return { error: null, outcome: "attached" };
  }
  const held = await admin
    .from("payment_intents")
    .select("order_id")
    .eq("id", intentId)
    .maybeSingle();
  if (held.error) return { error: held.error, outcome: null };
  return {
    error: null,
    outcome: held.data?.order_id === orderId ? "same" : "other",
  };
}
