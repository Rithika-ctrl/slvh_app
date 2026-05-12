/**
 * analytics_aggregator.ts
 *
 * Firebase Cloud Functions that maintain a pre-aggregated analytics collection
 * so the Flutter app never has to scan all orders on every load.
 *
 * Firestore layout written by these functions:
 *
 *   analytics/{YYYY-MM-DD}          ← one doc per calendar day (UTC+5:30 IST)
 *     revenue:        number         total completed-order revenue for that day
 *     orderCount:     number         number of completed orders
 *     avgOrderValue:  number         revenue / orderCount  (0 when no orders)
 *     bestSellers:    array          top-10 products sorted by unitsSold desc
 *       [ { productId, productName, unitsSold, revenue } ]
 *     categoryRevenue: map           { categoryId → revenue }
 *     updatedAt:      Timestamp
 *
 *   analytics/_meta/monthly/{YYYY-MM}   ← rolled-up monthly aggregate
 *     revenue, orderCount, avgOrderValue, bestSellers, categoryRevenue
 *     updatedAt
 *
 * Triggers:
 *   onOrderCompleted   – Firestore onCreate/onUpdate on orders/{orderId}
 *                        Fires whenever an order reaches status=="completed".
 *                        Increments the day doc atomically (transaction).
 *
 *   rebuildDayAggregate – Scheduled function (runs at 02:00 IST daily).
 *                         Rebuilds yesterday's analytics doc from scratch by
 *                         scanning only that day's orders — cheap because the
 *                         scan is always bounded to 24 h of data.
 *
 *   rebuildMonthAggregate – Scheduled function (runs at 02:15 IST on the 1st).
 *                           Sums the daily docs for the previous month into the
 *                           monthly aggregate.
 *
 * Deployment:
 *   firebase deploy --only functions:onOrderCompleted,functions:rebuildDayAggregate,functions:rebuildMonthAggregate
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Only call initializeApp once even if this module is hot-reloaded.
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// ── Constants ─────────────────────────────────────────────────────────────────

/** India Standard Time offset from UTC in minutes. */
const IST_OFFSET_MINUTES = 330;

/** Number of top products to keep in bestSellers array. */
const TOP_N = 10;

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Convert a UTC Date to an IST "YYYY-MM-DD" string. */
function toIstDateKey(date: Date): string {
  const istMs = date.getTime() + IST_OFFSET_MINUTES * 60 * 1000;
  const ist = new Date(istMs);
  const yyyy = ist.getUTCFullYear();
  const mm = String(ist.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(ist.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

/** Return the "YYYY-MM" portion of a date key. */
function toMonthKey(dateKey: string): string {
  return dateKey.substring(0, 7);
}

/**
 * Fetch all completed orders for a given IST calendar day.
 * Uses a [startOfDayUTC, endOfDayUTC) window that maps to midnight–midnight IST.
 */
async function fetchDayOrders(istDateKey: string): Promise<admin.firestore.QuerySnapshot> {
  // Parse the IST date key back to a UTC window.
  const [year, month, day] = istDateKey.split("-").map(Number);

  // IST midnight = UTC midnight minus 5:30
  const startIstMs =
    Date.UTC(year, month - 1, day, 0, 0, 0) - IST_OFFSET_MINUTES * 60 * 1000;
  const endIstMs = startIstMs + 24 * 60 * 60 * 1000;

  const startTs = admin.firestore.Timestamp.fromMillis(startIstMs);
  const endTs = admin.firestore.Timestamp.fromMillis(endIstMs);

  return db
    .collection("orders")
    .where("status", "==", "completed")
    .where("createdAt", ">=", startTs)
    .where("createdAt", "<", endTs)
    .get();
}

/**
 * Build the full aggregate payload from a set of completed orders.
 * Also enriches products with their categoryId from Firestore in batches.
 */
async function buildDayPayload(
  snap: admin.firestore.QuerySnapshot
): Promise<Record<string, unknown>> {
  let revenue = 0;
  const orderCount = snap.size;

  // Product → { unitsSold, revenue }
  const productAgg: Record<string, { productName: string; unitsSold: number; revenue: number }> = {};
  // ProductId → categoryId  (filled by batch lookup below)
  const productToCategory: Record<string, string> = {};

  // Aggregate from order items
  for (const doc of snap.docs) {
    const data = doc.data();
    revenue += (data.total as number) ?? 0;

    const items: Array<{
      productId: string;
      productName: string;
      quantity: number;
      totalPrice: number;
    }> = data.items ?? [];

    for (const item of items) {
      const pid = item.productId;
      if (!productAgg[pid]) {
        productAgg[pid] = { productName: item.productName, unitsSold: 0, revenue: 0 };
      }
      productAgg[pid].unitsSold += item.quantity;
      productAgg[pid].revenue += item.totalPrice;
    }
  }

  // Batch-fetch categoryId for each product (30 per whereIn call)
  const productIds = Object.keys(productAgg);
  const CHUNK = 30;
  for (let i = 0; i < productIds.length; i += CHUNK) {
    const slice = productIds.slice(i, i + CHUNK);
    const pSnap = await db
      .collection("products")
      .where(admin.firestore.FieldPath.documentId(), "in", slice)
      .get();
    for (const pDoc of pSnap.docs) {
      productToCategory[pDoc.id] = (pDoc.data().categoryId as string) ?? "other";
    }
  }

  // Best sellers — top N by units sold
  const bestSellers = Object.entries(productAgg)
    .map(([productId, agg]) => ({
      productId,
      productName: agg.productName,
      unitsSold: agg.unitsSold,
      revenue: agg.revenue,
    }))
    .sort((a, b) => b.unitsSold - a.unitsSold)
    .slice(0, TOP_N);

  // Category revenue map
  const categoryRevenue: Record<string, number> = {};
  for (const [pid, agg] of Object.entries(productAgg)) {
    const catId = productToCategory[pid] ?? "other";
    categoryRevenue[catId] = (categoryRevenue[catId] ?? 0) + agg.revenue;
  }

  return {
    revenue,
    orderCount,
    avgOrderValue: orderCount > 0 ? revenue / orderCount : 0,
    bestSellers,
    categoryRevenue,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

// ── Trigger: onOrderCompleted ─────────────────────────────────────────────────

/**
 * Fires on every write to an orders document.
 * When status transitions TO "completed", atomically increments the day doc.
 * Uses a transaction so concurrent completions don't race.
 *
 * Note: This handles the *increment* path only. The nightly rebuildDayAggregate
 * corrects any drift (e.g. refunds or admin overrides) by full recomputation.
 */
export const onOrderCompleted = functions
  .region("asia-south1")
  .firestore.document("orders/{orderId}")
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;

    if (!after) return; // Deleted — ignore.

    const wasCompleted = before?.status === "completed";
    const isCompleted = after.status === "completed";

    // Only react to the transition → completed.
    if (wasCompleted || !isCompleted) return;

    const createdAt: admin.firestore.Timestamp = after.createdAt;
    if (!createdAt) return;

    const dateKey = toIstDateKey(createdAt.toDate());
    const dayRef = db.collection("analytics").doc(dateKey);

    const items: Array<{ productId: string; productName: string; quantity: number; totalPrice: number }> =
      after.items ?? [];
    const orderTotal: number = after.total ?? 0;

    await db.runTransaction(async (tx) => {
      const dayDoc = await tx.get(dayRef);

      if (!dayDoc.exists) {
        // First order of the day — create the doc.
        const productAgg: Record<string, { productName: string; unitsSold: number; revenue: number }> = {};
        for (const item of items) {
          if (!productAgg[item.productId]) {
            productAgg[item.productId] = { productName: item.productName, unitsSold: 0, revenue: 0 };
          }
          productAgg[item.productId].unitsSold += item.quantity;
          productAgg[item.productId].revenue += item.totalPrice;
        }

        const bestSellers = Object.entries(productAgg)
          .map(([productId, agg]) => ({ productId, ...agg }))
          .sort((a, b) => b.unitsSold - a.unitsSold)
          .slice(0, TOP_N);

        const categoryRevenue: Record<string, number> = {};
        // categoryId unknown at trigger time — nightly rebuild will correct this.

        tx.set(dayRef, {
          revenue: orderTotal,
          orderCount: 1,
          avgOrderValue: orderTotal,
          bestSellers,
          categoryRevenue,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      // Increment existing day doc.
      const data = dayDoc.data()!;
      const newRevenue = (data.revenue as number) + orderTotal;
      const newCount = (data.orderCount as number) + 1;

      // Merge item counts into existing bestSellers array.
      const existing: Array<{ productId: string; productName: string; unitsSold: number; revenue: number }> =
        data.bestSellers ?? [];
      const byProduct: Record<string, (typeof existing)[0]> = {};
      for (const bs of existing) byProduct[bs.productId] = { ...bs };

      for (const item of items) {
        if (!byProduct[item.productId]) {
          byProduct[item.productId] = {
            productId: item.productId,
            productName: item.productName,
            unitsSold: 0,
            revenue: 0,
          };
        }
        byProduct[item.productId].unitsSold += item.quantity;
        byProduct[item.productId].revenue += item.totalPrice;
      }

      const bestSellers = Object.values(byProduct)
        .sort((a, b) => b.unitsSold - a.unitsSold)
        .slice(0, TOP_N);

      tx.update(dayRef, {
        revenue: newRevenue,
        orderCount: newCount,
        avgOrderValue: newRevenue / newCount,
        bestSellers,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  });

// ── Scheduled: rebuildDayAggregate ───────────────────────────────────────────

/**
 * Runs at 02:00 IST every day.
 * Scans yesterday's completed orders and overwrites the analytics day doc.
 * This corrects any drift introduced by the real-time trigger (e.g. cancelled
 * orders that were briefly completed, admin overrides, or missed triggers).
 */
export const rebuildDayAggregate = functions
  .region("asia-south1")
  .pubsub.schedule("30 20 * * *") // 20:30 UTC = 02:00 IST
  .timeZone("UTC")
  .onRun(async () => {
    // Yesterday in IST
    const nowIstMs = Date.now() + IST_OFFSET_MINUTES * 60 * 1000;
    const yesterdayIst = new Date(nowIstMs - 24 * 60 * 60 * 1000);
    const yyyy = yesterdayIst.getUTCFullYear();
    const mm = String(yesterdayIst.getUTCMonth() + 1).padStart(2, "0");
    const dd = String(yesterdayIst.getUTCDate()).padStart(2, "0");
    const dateKey = `${yyyy}-${mm}-${dd}`;

    functions.logger.info(`Rebuilding analytics for ${dateKey}`);

    const snap = await fetchDayOrders(dateKey);
    const payload = await buildDayPayload(snap);

    await db.collection("analytics").doc(dateKey).set(payload);
    functions.logger.info(`analytics/${dateKey} written — ${snap.size} orders, revenue=${payload.revenue}`);
  });

// ── Scheduled: rebuildMonthAggregate ─────────────────────────────────────────

/**
 * Runs at 02:15 IST on the 1st of every month.
 * Reads all daily docs for the previous month and sums them into
 * analytics/_meta/monthly/{YYYY-MM}.
 */
export const rebuildMonthAggregate = functions
  .region("asia-south1")
  .pubsub.schedule("45 20 1 * *") // 20:45 UTC on 1st = 02:15 IST
  .timeZone("UTC")
  .onRun(async () => {
    const nowIstMs = Date.now() + IST_OFFSET_MINUTES * 60 * 1000;
    // Go back to last month
    const lastMonthEnd = new Date(nowIstMs - 24 * 60 * 60 * 1000);
    const prevYear = lastMonthEnd.getUTCFullYear();
    const prevMonth = lastMonthEnd.getUTCMonth() + 1; // 1-based
    const monthKey = `${prevYear}-${String(prevMonth).padStart(2, "0")}`;

    functions.logger.info(`Rebuilding monthly aggregate for ${monthKey}`);

    // Fetch all daily docs for the month (format: YYYY-MM-DD → startsWith YYYY-MM)
    const start = `${monthKey}-01`;
    const end = `${monthKey}-32`; // beyond any real date — Firestore lex compare works

    const dailySnap = await db
      .collection("analytics")
      .where(admin.firestore.FieldPath.documentId(), ">=", start)
      .where(admin.firestore.FieldPath.documentId(), "<=", end)
      .get();

    let revenue = 0;
    let orderCount = 0;
    const productAgg: Record<string, { productName: string; unitsSold: number; revenue: number }> = {};
    const categoryRevenue: Record<string, number> = {};

    for (const doc of dailySnap.docs) {
      const d = doc.data();
      revenue += (d.revenue as number) ?? 0;
      orderCount += (d.orderCount as number) ?? 0;

      for (const bs of (d.bestSellers as Array<{ productId: string; productName: string; unitsSold: number; revenue: number }>) ?? []) {
        if (!productAgg[bs.productId]) {
          productAgg[bs.productId] = { productName: bs.productName, unitsSold: 0, revenue: 0 };
        }
        productAgg[bs.productId].unitsSold += bs.unitsSold;
        productAgg[bs.productId].revenue += bs.revenue;
      }

      for (const [catId, catRev] of Object.entries((d.categoryRevenue as Record<string, number>) ?? {})) {
        categoryRevenue[catId] = (categoryRevenue[catId] ?? 0) + catRev;
      }
    }

    const bestSellers = Object.entries(productAgg)
      .map(([productId, agg]) => ({ productId, ...agg }))
      .sort((a, b) => b.unitsSold - a.unitsSold)
      .slice(0, TOP_N);

    const payload = {
      revenue,
      orderCount,
      avgOrderValue: orderCount > 0 ? revenue / orderCount : 0,
      bestSellers,
      categoryRevenue,
      dailyDocsScanned: dailySnap.size,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db
      .collection("analytics")
      .doc("_meta")
      .collection("monthly")
      .doc(monthKey)
      .set(payload);

    functions.logger.info(`analytics/_meta/monthly/${monthKey} written — ${orderCount} orders, revenue=${revenue}`);
  });

// ── HTTP helper: backfillRange (admin-only, call once to seed history) ────────

/**
 * HTTP function to backfill analytics for a date range.
 * Call with: POST /backfillRange  { "from": "2025-01-01", "to": "2025-04-30" }
 *
 * This is intentionally NOT deployed by default. Uncomment the export and
 * deploy manually when you need to seed historical data, then redeploy without
 * it to avoid leaving an open HTTP endpoint.
 */
/*
export const backfillRange = functions
  .region("asia-south1")
  .https.onRequest(async (req, res) => {
    if (req.method !== "POST") { res.status(405).send("POST only"); return; }

    const { from, to } = req.body as { from: string; to: string };
    if (!from || !to) { res.status(400).send("from and to required (YYYY-MM-DD)"); return; }

    const results: string[] = [];
    let cursor = new Date(from + "T00:00:00Z");
    const endDate = new Date(to + "T00:00:00Z");

    while (cursor <= endDate) {
      const yyyy = cursor.getUTCFullYear();
      const mm = String(cursor.getUTCMonth() + 1).padStart(2, "0");
      const dd = String(cursor.getUTCDate()).padStart(2, "0");
      const dateKey = `${yyyy}-${mm}-${dd}`;

      const snap = await fetchDayOrders(dateKey);
      if (snap.size > 0) {
        const payload = await buildDayPayload(snap);
        await db.collection("analytics").doc(dateKey).set(payload);
        results.push(`${dateKey}: ${snap.size} orders`);
      }

      cursor = new Date(cursor.getTime() + 24 * 60 * 60 * 1000);
    }

    res.json({ backfilled: results });
  });
*/
