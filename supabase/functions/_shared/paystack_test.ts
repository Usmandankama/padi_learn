// Run: deno test supabase/functions/_shared/paystack_test.ts
import { assertEquals } from "jsr:@std/assert@1";
import { customerTotalNaira, splitFor } from "./paystack.ts";

Deno.test("a NGN 5,000 course: teacher gets 85% of the list price", () => {
  const s = splitFor(5000, 0, 15);
  assertEquals(s.chargeKobo, Math.round(customerTotalNaira(5000) * 100));
  assertEquals(s.teacherShareKobo, 425000);
  assertEquals(s.recoverKobo, 0);
  assertEquals(s.subaccountKobo, 425000);
  // PadiLearn keeps the rest and pays Paystack's fee out of it.
  assertEquals(s.transactionChargeKobo, s.chargeKobo - 425000);
});

Deno.test("the main account's part always covers the card fee", () => {
  for (const price of [100, 500, 2463, 2500, 5000, 20000, 150000]) {
    const s = splitFor(price, 0, 15);
    const cardFeeKobo = s.chargeKobo - Math.round(price * 100);
    assertEquals(s.transactionChargeKobo >= cardFeeKobo, true, `price ${price}`);
    assertEquals(s.subaccountKobo + s.transactionChargeKobo, s.chargeKobo);
  }
});

Deno.test("debt is kept back from the share, never more than all of it", () => {
  const part = splitFor(5000, 100000, 15);
  assertEquals(part.recoverKobo, 100000);
  assertEquals(part.subaccountKobo, 325000);
  assertEquals(part.transactionChargeKobo, part.chargeKobo - 325000);

  const all = splitFor(5000, 9_000_000, 15);
  assertEquals(all.recoverKobo, 425000);
  assertEquals(all.subaccountKobo, 0);
  assertEquals(all.transactionChargeKobo, all.chargeKobo);
});

Deno.test("odd prices round the commission, not the teacher's share away", () => {
  const s = splitFor(333, 0, 15);
  // 15% of 33,300 kobo is 4,995 exactly.
  assertEquals(s.teacherShareKobo, 33300 - 4995);
  const t = splitFor(1001, 0, 15);
  // 15% of 100,100 kobo is 15,015.
  assertEquals(t.teacherShareKobo, 100100 - 15015);
});

Deno.test("negative or missing debt counts as none", () => {
  assertEquals(splitFor(5000, -500, 15).recoverKobo, 0);
  assertEquals(splitFor(5000, Number.NaN, 15).recoverKobo, 0);
});
