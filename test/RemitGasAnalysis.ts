/**
 * Gas analysis for ClockTowerSubscribe.remit()
 *
 * Measures gas across realistic shapes:
 *  - few subscriptions × many subscribers
 *  - many subscriptions × few subscribers
 *  - balanced mixes
 *  - success path (feeBalance path) vs feefill path vs failure path
 *
 * Prints per-tx and per-remittance (per successful subscriber payment) gas.
 */
import { expect } from "chai";
import hre from "hardhat";
import { Wallet } from "ethers";

const { ethers, networkHelpers } = await hre.network.getOrCreate();
const { loadFixture, time } = networkHelpers;

describe("Remit Gas Analysis", function () {
  // 2028-01-01 06:00 UTC — same as main suite (day-of-month = 1)
  const currentTime = 1830319200;
  const eth = ethers.parseEther("1.0");
  const fundAmount = ethers.parseEther("1000.0");
  const infiniteApproval = 2n ** 255n;
  const ClockDecimals = 6n;
  const subAmount = ethers.parseEther("5"); // $5-style amount (18-dec internal units)

  const details = {
    domain: "domain",
    url: "URL",
    email: "Email",
    phone: "phone",
    description: "description",
  };

  const convert = (amount: bigint) => amount / 10n ** (18n - ClockDecimals);

  /** Hardhat forbids evm_setNextBlockTimestamp in the past (e.g. after Clocktower.ts). */
  async function warpForwardTo(timestamp: number) {
    const latest = await time.latest();
    if (latest < timestamp) {
      await time.increaseTo(timestamp);
    }
  }

  type GasRow = {
    scenario: string;
    path: string;
    numSubs: number;
    subscribersPerSub: number;
    remittances: number; // successful subscriber payments counted
    gasUsed: bigint;
    gasPerRemit: number;
    baseOverheadEstimate?: number;
  };

  const results: GasRow[] = [];

  async function deployFixture() {
    await warpForwardTo(currentTime);

    const ClockLibrary = await ethers.getContractFactory("ClockTowerTimeLibrary");
    const lib = await ClockLibrary.deploy();
    await lib.waitForDeployment();
    const libAddr = await lib.getAddress();

    const ClockToken = await ethers.getContractFactory("CLOCKToken");
    const ClockSubscribeFactory = await ethers.getContractFactory("ClockTowerSubscribe", {
      libraries: { ClockTowerTimeLibrary: libAddr },
    });

    const signers = await ethers.getSigners();
    const [owner, admin, provider, caller, ...rest] = signers;

    // High maxRemits so one call can clear large batches (up to block gas limit)
    // callerFee 10200 = 2%
    const clock = await ClockSubscribeFactory.deploy(
      10200n,
      11000n,
      500n, // maxRemits
      50n,
      false,
      owner.address,
      admin.address
    );
    const token = await ClockToken.deploy(ethers.parseEther("100000000"));
    await clock.waitForDeployment();
    await token.waitForDeployment();

    await clock.addERC20Contract(await token.getAddress(), ethers.parseEther("0.01"), ClockDecimals);

    // Fund base signers
    for (const s of [admin, provider, caller, ...rest.slice(0, 10)]) {
      await token.transfer(s.address, convert(fundAmount));
      await token.connect(s).approve(await clock.getAddress(), infiniteApproval);
    }
    await token.approve(await clock.getAddress(), infiniteApproval);

    return { owner, admin, provider, caller, rest, token, clock, signers };
  }

  /** Build N wallet subscribers funded + approved */
  async function makeSubscribers(
    owner: any,
    token: any,
    clock: any,
    count: number,
    existing: any[]
  ) {
    const clockAddr = await clock.getAddress();
    const wallets: Wallet[] = [];

    // Prefer hardhat signers first, then ephemeral wallets
    const need = count;
    for (let i = 0; i < need; i++) {
      if (i < existing.length) {
        const s = existing[i];
        // ensure funded
        const bal = await token.balanceOf(s.address);
        if (bal < convert(ethers.parseEther("50"))) {
          await token.transfer(s.address, convert(fundAmount));
        }
        await token.connect(s).approve(clockAddr, infiniteApproval);
        wallets.push(s as any);
      } else {
        const w = Wallet.createRandom().connect(ethers.provider);
        // fund eth for gas (local hardhat doesn't need much for contract calls via impersonation...
        // We send via owner using hardhat_setBalance + token transfer, then connect via sendTransaction
        // Simpler: use hardhat_impersonateAccount after funding
        await owner.sendTransaction({ to: w.address, value: ethers.parseEther("1") });
        await token.transfer(w.address, convert(fundAmount));
        await token.connect(w).approve(clockAddr, infiniteApproval);
        wallets.push(w);
      }
    }
    return wallets;
  }

  function toSubObject(s: any) {
    return {
      id: s.subscription[0],
      amount: s.subscription[1],
      provider: s.subscription[2],
      token: s.subscription[3],
      cancelled: s.subscription[4],
      frequency: s.subscription[5],
      dueDay: s.subscription[6],
    };
  }

  /**
   * Setup subscriptions all due on monthly day 1 (matches currentTime calendar day).
   * frequency: 1 = MONTHLY
   */
  async function setupScenario(opts: {
    numSubs: number;
    subscribersPerSub: number;
    path: "success" | "feefill" | "fail";
    /** If true, burn fee balance so first remit hits feefill (harder without storage manip) */
  }) {
    const { owner, provider, caller, rest, token, clock, signers } = await loadFixture(deployFixture);
    const totalSubscribersNeeded = Math.min(
      opts.numSubs * opts.subscribersPerSub,
      // Unique wallets: if same person on many subs, still one wallet can subscribe to many
      Math.max(opts.subscribersPerSub, opts.numSubs * opts.subscribersPerSub)
    );

    // Strategy: reuse a pool of unique wallets of size max(subscribersPerSub, ...)
    // For "many subs, few subscribers": same small set of people subscribe to many products
    // For "few subs, many subscribers": large pool all join the few products
    const poolSize =
      opts.numSubs === 1
        ? opts.subscribersPerSub
        : opts.subscribersPerSub <= 5
          ? Math.max(opts.subscribersPerSub, 20) // enough unique for few-per-sub across many subs
          : opts.subscribersPerSub;

    // Available signers after owner/admin/provider/caller
    const available = signers.slice(4);
    const subscribers = await makeSubscribers(owner, token, clock, poolSize, available);

    const tokenAddr = await token.getAddress();
    const dueDay = 1; // Jan 1
    const frequency = 1; // monthly

    // Create subscriptions
    for (let i = 0; i < opts.numSubs; i++) {
      await clock.connect(provider).createSubscription(subAmount, tokenAddr, details, frequency, dueDay);
    }

    const all = await clock.connect(provider).getAccountSubscriptions(false, provider.address);
    const subObjs = all.map(toSubObject);

    // Subscribe: for each sub, first `subscribersPerSub` from pool
    for (let s = 0; s < opts.numSubs; s++) {
      for (let u = 0; u < opts.subscribersPerSub; u++) {
        const subWallet = subscribers[u % subscribers.length];
        // If same wallet already on this sub, need unique — use offset
        const wallet = subscribers[(u + s * 0) % subscribers.length];
        // Ensure uniqueness per sub: pick distinct indices
        const idx = u % subscribers.length;
        // For many-subs case with few per sub, rotate starting index
        const finalIdx = (s * opts.subscribersPerSub + u) % subscribers.length;
        const w = subscribers[opts.subscribersPerSub === 1 ? finalIdx : (opts.numSubs > 1 && opts.subscribersPerSub <= 3 ? finalIdx : idx)];
        try {
          await clock.connect(w).subscribe(subObjs[s]);
        } catch (e: any) {
          // already subscribed — use another wallet
          const alt = subscribers[(finalIdx + 1 + u) % subscribers.length];
          await clock.connect(alt).subscribe(subObjs[s]);
        }
      }
    }

    if (opts.path === "fail") {
      // Drain token balance of all subscribers so allowance ok but balance fails
      // Actually check is allowance AND balance — drain balance below converted amount
      for (const w of subscribers) {
        const bal = await token.balanceOf(w.address);
        if (bal > 0n) {
          await token.connect(w).transfer(owner.address, bal);
        }
        // keep approval
      }
    }

    if (opts.path === "feefill") {
      // Zero out fee balances by draining via multiple remits is hard without time travel.
      // Instead: subscribe far enough that fee is only caller fee (tooLow), then force
      // feeBalance <= subFee. On subscribe with tooLow, feeBalance = callerAmount = subFee.
      // Condition for feeBalance path is feeBalance > subFee (strict).
      // So feeBalance == subFee already takes FEEFILL path on first remit.
      // Prorate on day-of-due before remit often sets tooLow → feeBalance = subFee.
      // With dueDay=1 and current day Jan 1, prorate may set fee == amount && isBeforeRemit → tooLow.
      // So first remit is often already FEEFILL. We'll measure that as feefill path.
      // To force pure feeBalance path (success), we need feeBalance > subFee after subscribe.
      // That happens when prorate gives more than subFee (not tooLow).
    }

    // Advance time slightly so remit can run (nextUncheckedDay is day-2)
    // We need currentDay >= nextUncheckedDay (already true).
    // Process: call remit until day completes. For due day matching, first non-empty day processes.
    await time.increase(3600);

    // For pure success path with fee balance: ensure feeBalance > subFee.
    // If already feeBalance == subFee (tooLow path), first hit is feefill which refills.
    // Measure first remit as "cold/feefill-ish" and optional second month for warm path.

    return { owner, provider, caller, token, clock, subObjs, remittancesExpected: opts.numSubs * opts.subscribersPerSub };
  }

  async function measureRemit(
    scenario: string,
    path: string,
    numSubs: number,
    subscribersPerSub: number,
    pathKind: "success" | "feefill" | "fail"
  ) {
    const { caller, clock, remittancesExpected } = await setupScenario({
      numSubs,
      subscribersPerSub,
      path: pathKind,
    });

    // May need multiple pages if remittances > maxRemits (500)
    let totalGas = 0n;
    let pages = 0;
    let finished = false;
    const maxPages = 20;

    while (!finished && pages < maxPages) {
      const tx = await clock.connect(caller).remit();
      const rc = await tx.wait();
      totalGas += rc!.gasUsed;
      pages++;

      // Check CallerLog isFinished
      const logs = rc!.logs;
      // Parse via contract interface
      for (const log of logs) {
        try {
          const parsed = clock.interface.parseLog({ topics: log.topics as string[], data: log.data });
          if (parsed?.name === "CallerLog") {
            finished = parsed.args.isFinished === true;
          }
        } catch {
          /* ignore */
        }
      }
      // Safety: if no more work, day advances
      if (pages > 1 && !finished) {
        // continue
      }
    }

    const remittances = remittancesExpected; // we set up exactly this many due
    const gasPerRemit = Number(totalGas) / remittances;

    results.push({
      scenario,
      path,
      numSubs,
      subscribersPerSub,
      remittances,
      gasUsed: totalGas,
      gasPerRemit,
    });

    console.log(
      `\n[GAS] ${scenario} | path=${path} | subs=${numSubs} x subbers=${subscribersPerSub} | remits=${remittances} | pages=${pages}`
    );
    console.log(`      totalGas=${totalGas.toString()} | gas/remit=${gasPerRemit.toFixed(0)}`);

    return { totalGas, gasPerRemit, remittances, pages };
  }

  // ---------- Scenarios ----------

  it("1 sub × 1 subscriber (baseline / near best-case overhead heavy)", async function () {
    await measureRemit("1x1 baseline", "mixed-first", 1, 1, "success");
  });

  it("1 sub × 5 subscribers", async function () {
    await measureRemit("1x5 few-subs many-subbers", "mixed-first", 1, 5, "success");
  });

  it("1 sub × 20 subscribers", async function () {
    await measureRemit("1x20 few-subs many-subbers", "mixed-first", 1, 20, "success");
  });

  it("1 sub × 50 subscribers", async function () {
    this.timeout(120000);
    await measureRemit("1x50 few-subs many-subbers", "mixed-first", 1, 50, "success");
  });

  it("5 subs × 1 subscriber each", async function () {
    await measureRemit("5x1 many-subs few-subbers", "mixed-first", 5, 1, "success");
  });

  it("10 subs × 1 subscriber each", async function () {
    this.timeout(120000);
    await measureRemit("10x1 many-subs few-subbers", "mixed-first", 10, 1, "success");
  });

  it("10 subs × 3 subscribers each", async function () {
    this.timeout(180000);
    await measureRemit("10x3 balanced", "mixed-first", 10, 3, "success");
  });

  it("20 subs × 2 subscribers each", async function () {
    this.timeout(180000);
    await measureRemit("20x2 many-subs few-subbers", "mixed-first", 20, 2, "success");
  });

  it("5 subs × 10 subscribers each", async function () {
    this.timeout(180000);
    await measureRemit("5x10 balanced-large", "mixed-first", 5, 10, "success");
  });

  it("Failure path: 1 sub × 10 subscribers (insufficient balance)", async function () {
    this.timeout(120000);
    await measureRemit("1x10 failure", "fail", 1, 10, "fail");
  });

  it("Warm path vs first-cycle: feeBalance success after feefill (1x10 and 1x25)", async function () {
    this.timeout(300000);

    async function measureWarm(nScribers: number) {
      const { owner, caller, clock } = await setupScenario({
        numSubs: 1,
        subscribersPerSub: nScribers,
        path: "success",
      });

      // First remit — typically FEEFILL path when subscribed on due day
      let tx = await clock.connect(caller).remit();
      let rc = await tx.wait();
      const gasFirst = rc!.gasUsed;

      // Jump to next month day-1: Feb 1 2028 12:00 UTC
      // Jan 1 2028 06:00 was currentTime; + 31 days ≈ Feb 1
      await time.increase(31 * 86400);
      // Admin-skip empty days so we don't recurse 30 empty days in one tx
      const day = await clock.nextUncheckedDay();
      // set to day-of Feb 1 (or just before due)
      // unix for approx: currentTime + 31d
      const ts = currentTime + 31 * 86400 + 3600;
      const targetDay = BigInt(Math.floor(ts / 86400));
      await clock.connect(owner).setNextUncheckedDay(targetDay);

      tx = await clock.connect(caller).remit();
      rc = await tx.wait();
      const gasWarm = rc!.gasUsed;

      console.log(
        `\n[GAS] first-cycle (feefill-ish) 1x${nScribers}: total=${gasFirst} per=${(Number(gasFirst) / nScribers).toFixed(0)}`
      );
      console.log(
        `[GAS] warm feeBalance path     1x${nScribers}: total=${gasWarm} per=${(Number(gasWarm) / nScribers).toFixed(0)}`
      );
      return { gasFirst, gasWarm };
    }

    await measureWarm(10);
    await measureWarm(25);
  });

  it("SUMMARY table + economics", async function () {
    // This runs after others only if sequential; mocha order is declaration order within describe.
    // We'll recompute a clean matrix in this test alone for reliability.
    this.timeout(600000);

    type M = { label: string; nSub: number; nScriber: number; path: "success" | "fail"; gas: bigint; per: number };
    const matrix: M[] = [];

    async function run(label: string, nSub: number, nScriber: number, path: "success" | "fail" = "success") {
      const { caller, clock, remittancesExpected } = await setupScenario({
        numSubs: nSub,
        subscribersPerSub: nScriber,
        path,
      });

      let totalGas = 0n;
      let pages = 0;
      let finished = false;
      while (!finished && pages < 30) {
        const tx = await clock.connect(caller).remit();
        const rc = await tx.wait();
        totalGas += rc!.gasUsed;
        pages++;
        for (const log of rc!.logs) {
          try {
            const parsed = clock.interface.parseLog({ topics: log.topics as string[], data: log.data });
            if (parsed?.name === "CallerLog") finished = parsed.args.isFinished === true;
          } catch {
            /* */
          }
        }
      }
      const per = Number(totalGas) / remittancesExpected;
      matrix.push({ label, nSub, nScriber, path, gas: totalGas, per });
      console.log(`  ${label.padEnd(36)} total=${totalGas.toString().padStart(9)}  per-remit=${per.toFixed(0).padStart(7)}  pages=${pages}`);
      return per;
    }

    console.log("\n========== REMIT GAS MATRIX ==========");
    await run("1×1", 1, 1);
    await run("1×5", 1, 5);
    await run("1×10", 1, 10);
    await run("1×25", 1, 25);
    await run("1×50", 1, 50);
    await run("5×1", 5, 1);
    await run("10×1", 10, 1);
    await run("20×1", 20, 1);
    await run("5×5", 5, 5);
    await run("10×5", 10, 5);
    await run("20×5", 20, 5);
    await run("5×20", 5, 20);
    await run("1×10 FAIL", 1, 10, "fail");

    // Marginal cost: (1x50 - 1x25) / 25 ≈ gas per extra subscriber on same sub
    const g1 = matrix.find((m) => m.label === "1×1")!;
    const g10 = matrix.find((m) => m.label === "1×10")!;
    const g25 = matrix.find((m) => m.label === "1×25")!;
    const g50 = matrix.find((m) => m.label === "1×50")!;
    const g5x1 = matrix.find((m) => m.label === "5×1")!;
    const g20x1 = matrix.find((m) => m.label === "20×1")!;
    const g10x5 = matrix.find((m) => m.label === "10×5")!;
    const g5x20 = matrix.find((m) => m.label === "5×20")!;
    const gFail = matrix.find((m) => m.label === "1×10 FAIL")!;

    const marginalSameSub = (Number(g50.gas) - Number(g25.gas)) / 25;
    const marginalNewSub = (Number(g20x1.gas) - Number(g5x1.gas)) / 15; // 15 extra subs with 1 subber each
    const avgPerRemitBalanced = (g10x5.per + g5x20.per) / 2;
    const bestPerRemit = Math.min(...matrix.filter((m) => m.path === "success" && m.nScriber * m.nSub >= 10).map((m) => m.per));
    const worstPerRemit = Math.max(...matrix.filter((m) => m.path === "success").map((m) => m.per));
    // realistic average: weight toward few-subs-many-subbers (SaaS) and multi-merchant
    const realisticAvg =
      (g50.per * 0.25 + g25.per * 0.15 + g10x5.per * 0.2 + g5x20.per * 0.15 + g20x1.per * 0.1 + g10.per * 0.15);

    console.log("\n---------- DERIVED ----------");
    console.log(`  Marginal gas / extra subscriber (same sub): ${marginalSameSub.toFixed(0)}`);
    console.log(`  Marginal gas / extra subscription (1 subber): ${marginalNewSub.toFixed(0)}`);
    console.log(`  Best-case gas/remit (large batch amortized): ${bestPerRemit.toFixed(0)}`);
    console.log(`  Worst-case gas/remit (small batch / high overhead): ${worstPerRemit.toFixed(0)}`);
    console.log(`  Balanced avg (10x5 & 5x20): ${avgPerRemitBalanced.toFixed(0)}`);
    console.log(`  Realistic weighted avg gas/remit: ${realisticAvg.toFixed(0)}`);
    console.log(`  Failure path gas/remit (1x10): ${gFail.per.toFixed(0)}`);
    console.log(`  1x1 absolute (overhead-heavy): ${g1.per.toFixed(0)}`);

    // Economics for $5 min subscription on mainnet
    // Fee formula: callerFee where 10000=0%, 10100=1% → fee% = (callerFee-10000)/100
    // Revenue per remit to caller = $5 * feePct
    // Need revenue >= gasCost * safetyMargin

    const ethPrices = [1500, 2500, 3500, 5000]; // USD
    const gasGwei = [5, 10, 20, 30, 50]; // gwei scenarios (post-EIP-1559 typical ranges)
    const gasUnits = Math.round(realisticAvg);
    const safety = 1.5; // 50% buffer so callers still profit

    console.log("\n========== MAINNET ECONOMICS ($5 subscription) ==========");
    console.log(`  Using realistic avg gas/remit = ${gasUnits}`);
    console.log(`  Safety margin = ${safety}x (caller needs fee revenue >= ${safety}x gas cost)`);
    console.log("");

    for (const ethUsd of ethPrices) {
      console.log(`  --- ETH = $${ethUsd} ---`);
      for (const gwei of gasGwei) {
        const gasCostEth = (gasUnits * gwei * 1e-9);
        const gasCostUsd = gasCostEth * ethUsd;
        const minFeeUsd = gasCostUsd * safety;
        const minFeePct = (minFeeUsd / 5) * 100; // percent of $5
        // Also max fee is 8.33% per contract
        const viable = minFeePct <= 8.33;
        console.log(
          `    gas ${String(gwei).padStart(2)} gwei | gas cost $${gasCostUsd.toFixed(4).padStart(8)} | min fee% ${minFeePct.toFixed(3).padStart(7)}% ${viable ? "OK" : "TOO HIGH"} | fee on $5 = $${minFeeUsd.toFixed(4)}`
        );
      }
      console.log("");
    }

    // Best / worst gas units for range
    console.log("  Using BEST-case amortized gas/remit:");
    {
      const gu = Math.round(bestPerRemit);
      for (const [ethUsd, gwei] of [
        [2500, 10],
        [2500, 20],
        [3500, 15],
      ] as const) {
        const gasCostUsd = gu * gwei * 1e-9 * ethUsd;
        const minFeePct = ((gasCostUsd * safety) / 5) * 100;
        console.log(`    ETH$${ethUsd} @ ${gwei} gwei, ${gu} gas → min fee ${minFeePct.toFixed(3)}% ($${((5 * minFeePct) / 100).toFixed(4)} on $5)`);
      }
    }
    console.log("  Using WORST-case gas/remit (1x1-like):");
    {
      const gu = Math.round(worstPerRemit);
      for (const [ethUsd, gwei] of [
        [2500, 10],
        [2500, 20],
        [3500, 15],
      ] as const) {
        const gasCostUsd = gu * gwei * 1e-9 * ethUsd;
        const minFeePct = ((gasCostUsd * safety) / 5) * 100;
        console.log(`    ETH$${ethUsd} @ ${gwei} gwei, ${gu} gas → min fee ${minFeePct.toFixed(3)}% ($${((5 * minFeePct) / 100).toFixed(4)} on $5)`);
      }
    }

    // Recommended numbers
    const recommendEth = 2500;
    const recommendGwei = 15; // conservative average mainnet
    const recGasCost = gasUnits * recommendGwei * 1e-9 * recommendEth;
    const recMinFeePct = ((recGasCost * safety) / 5) * 100;
    const recSafeFeePct = Math.ceil(recMinFeePct * 100) / 100; // round up to 0.01%
    // Also show for busy mainnet 30 gwei
    const busyCost = gasUnits * 30 * 1e-9 * recommendEth;
    const busyFee = ((busyCost * safety) / 5) * 100;

    console.log("\n========== RECOMMENDATION ==========");
    console.log(`  Realistic avg gas per remittance: ~${gasUnits.toLocaleString()} gas`);
    console.log(`  Best amortized: ~${Math.round(bestPerRemit).toLocaleString()} gas`);
    console.log(`  Worst (tiny batch): ~${Math.round(worstPerRemit).toLocaleString()} gas`);
    console.log(`  At ETH=$${recommendEth}, ${recommendGwei} gwei, ${safety}x safety:`);
    console.log(`    Gas cost/remit ≈ $${recGasCost.toFixed(4)}`);
    console.log(`    Min safe caller fee ≈ ${recSafeFeePct.toFixed(2)}% on $5 subs`);
    console.log(`  At busy mainnet 30 gwei: min safe fee ≈ ${busyFee.toFixed(2)}%`);
    console.log(`  Contract max caller fee: 8.33%`);
    console.log(`  Note: lower fees only work if batches are large OR gas is low (L2).`);
    console.log("====================================\n");

    // Sanity assert we measured something in a realistic band
    expect(gasUnits).to.be.greaterThan(30_000);
    expect(gasUnits).to.be.lessThan(150_000);
  });
});
