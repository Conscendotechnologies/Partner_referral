# Purchase Order → Payment demo

Document-generation demo built in **salesOrgSDO** (`salesdemo@conscendo.io.demo`,
org *Global Feeder Shipping LLC*). Everything below is deployed and verified.

Scope is deliberately demo-grade: hard-coded company letterhead, sample line-item
fallback, no integrations. It exists to produce screenshots of how documents and
data are captured in Salesforce.

---

## The chain

```
Account ─► Opportunity ─► Quote ──(Accepted)──► Purchase Order ─► Invoice
                                                                    ├─► Payment Receipt
                                                                    └─► Credit/Debit Note
Account ─► Credit Agreement
```

Every one of those six records has a **Download PDF** button.

---

## What was built

| Item | API name | Notes |
|---|---|---|
| Purchase Order | `Order` (standard) | Renamed via object translation, not `<label>` — see *Renames* below |
| Credit Agreement | `Contract` (standard) | Same rename mechanism |
| Invoice | `Invoice__c` | New. `INV-{00000}`. Standard `Invoice` exists in this org but is **not createable** |
| Payment Receipt | `Payment_Receipt__c` | New. `REC-{00000}` |
| Credit/Debit Note | `Credit_Debit_Note__c` | New. `CDN-{00000}`, single object with a `Type__c` picklist |
| Template config | `Document_Template__mdt` | 6 records — one per document type |
| PDF engine | `DocumentTemplateService`, `DocumentPdfController`, `DocumentPdf.page` | One VF page serves every object |
| UI | `documentGenerator` LWC | One component, on all six record pages |
| Access | `Document_Demo_Access` permission set | Objects, fields, tabs, Apex, VF |

Invoice stages: **Draft → Send to Maxis → Approved in Maxis**
Payment Receipt stages: **Payment Pending → Payment Received**

---

## The reusable component

`documentGenerator` never names an object. It reads its own `recordId`, and
`DocumentTemplateService` looks up the `Document_Template__mdt` row whose
`Object_API_Name__c` matches. That row supplies:

- `Document_Title__c` — the heading printed on the PDF
- `Accent_Color__c` — drives the rule, table headers and totals colour
- `Detail_Fields__c` — comma-separated field API names to print
- `Show_Line_Items__c` — whether the items table and totals block render
- `Account_Path__c` — how to reach the Account (`AccountId`, `Account__c`, or a
  two-hop path like `Invoice__r.Account__c`)

**To add a seventh document type, add a custom metadata record. No code changes.**

### Verified render output

| Document | Details | Line items | PDF |
|---|---|---|---|
| Purchase Order | 5 | 1 | 2,650 bytes |
| Invoice | 9 | 1 | 2,910 bytes |
| Payment Receipt | 6 | – | 2,224 bytes |
| Credit/Debit Note | 6 | – | 2,285 bytes |
| Credit Agreement | 5 | – | 2,120 bytes |
| Quote | 5 | 1 | 2,620 bytes |

---

## Demo records

Base URL `https://co1778135180529.my.salesforce.com/lightning/r/`

### Recording chain — Falcon Lines LLC (use this one)

Everything below is the same account, so the screen recording never jumps context.

| Record | Path |
|---|---|
| Account — Falcon Lines LLC | `Account/001g700000HcKSFAA3/view` |
| Opportunity — OPP-Falcon-VOY3387 | `Opportunity/006g700000Ay8Y1AAJ/view` |
| **Quote — Round 3 — 40HC Revision** (Draft, 4,200) | `Quote/0Q0g7000000ikVOCAY/view` |
| Credit Agreement 00000102 | `Contract/800g700001kAxljAAC/view` |

**Round 3 is deliberately left in Draft.** It is the live take — accepting it on
camera fires the cascade and creates the Purchase Order in front of the viewer.

### Backup chain — already complete (Falcon Lines, from Quote Round 2)

If the live creation goes wrong mid-recording, cut to these:

| Record | Path |
|---|---|
| Purchase Order 00000298 | `Order/801g700000g6XM6AAM/view` |
| Invoice INV-00008 | `Invoice__c/a0Bg700000GpVqCEAV/view` |
| Receipt REC-00005 · Note CDN-00005 | via the Invoice related lists |

### Rich chain — Hapag-Lloyd (best for static screenshots, not for the quote flow)

Larger numbers and every stage represented, but **not quote-originated** — do not
use it if the recording starts at a Quote.

| Record | Path |
|---|---|
| Purchase Order 00000266 | `Order/801g700000LHiSMAA1/view` |
| Invoice INV-00003 (245,700, balance 145,700) | `Invoice__c/a0Bg700000GRnGiEAL/view` |
| Receipt — Payment Received | `Payment_Receipt__c/a0Cg700000gWJeKEAW/view` |
| Receipt — Payment Pending | `Payment_Receipt__c/a0Cg700000gWJeLEAW/view` |
| Credit Note · Debit Note | `Credit_Debit_Note__c/a0Ag7000005fA8bEAE/view` · `.../a0Ag7000005fA8cEAE/view` |

---

## Screen recording script

Log in as **`salesdemo@conscendo.io.demo`** — the only user holding
`Document_Demo_Access`.

| # | Scene | Action | Watch for |
|---|---|---|---|
| 1 | Account | Open Falcon Lines LLC, scroll the related lists | Sets the context |
| 2 | Opportunity | Open OPP-Falcon-VOY3387 → Quotes related list | Shows the sales path |
| 3 | Quote | Open *Round 3 — 40HC Revision*, click **Download PDF** | QUOTATION renders, 40HC line item, 4,200 |
| 4 | **The cascade** | Set Status to **Accepted** → Save → refresh | Purchase Order appears in the related list, with line items |
| 5 | Purchase Order | Open it, click **Download PDF** | PURCHASE ORDER, navy accent |
| 6 | Invoice | From the PO's **Invoices** related list → New. Account, PO, dates, Status *Send to Maxis*, amounts | Balance Due computes on save |
| 7 | Invoice PDF | **Download PDF**, then **Save to Record** | TAX INVOICE, maroon accent; file lands under *Saved documents* |
| 8 | Receipt | Invoice → **Payment Receipts** → New, Status *Payment Received* | PAYMENT RECEIPT, green accent |
| 9 | Note | Invoice → **Credit/Debit Notes** → New, Type *Credit Note* | CREDIT / DEBIT NOTE, amber accent |
| 10 | Credit Agreement | Account → Credit Agreements → 00000102 → **Download PDF** | Closes the loop on the Account |

### Do not do these on camera

- **Do not set the Quote to `Approved`.** It bounces straight to `Presented` and no
  Order is created — that is `QuoteCascadeHandler`, not a bug. **Accepted** is the trigger.
- **Do not re-accept an already-Accepted quote** expecting a second Order. The handler
  only fires on the transition in.
- **Refresh after saving the quote.** The Order is created server-side; the related
  list will not repaint on its own.

---

## Two things that differ from the original requirement

### 1. Quote → Order fires on **Accepted**, not **Approved**

This org already had `QuoteCascadeHandler` before this work started, and it owns
the Quote lifecycle:

- `Approved` → emails the quote to the customer, then **immediately sets the
  status to `Presented`**. Nothing can rest at Approved.
- `Accepted` → creates the Order *and* per-container OrderItems *and* a handover Task.

So the requirement "after quote approved, create the order" was already
implemented — just on a different status. A competing flow was built, tested,
found redundant, and **deactivated** (`Quote_Approved_Create_Purchase_Order`,
active version cleared). Do not reactivate it; it would double-create orders.

**Demo the cascade by setting a Quote to `Accepted`.** Verified: quote QUO-Hist-3
produced Order 00000292 with line items.

### 2. Standard `Invoice` exists but cannot be used

`Invoice`, `InvoiceLine` and `CreditMemo` are present in this org's schema but all
report `createable=false` — they are Revenue Cloud objects that are visible but not
provisioned, so records can only come from the billing engine. Hence `Invoice__c`.

---

## Renames — how they actually work

Deploying `<label>Purchase Order</label>` on a standard object **silently does
nothing**. The deploy reports `Changed` and succeeds, and the label never moves.
The rename is carried by `objectTranslations/Order-en_US` and
`objectTranslations/Contract-en_US` instead (English needs `<startsWith>` and
must *not* have `<caseType>`).

**Blast radius:** the rename is org-wide. `Order` in this org also hosts a freight
booking demo (`Voyage__c`, `TEU_Booked__c`, `Load_Factor__c`, validation rule
`Prepaid_Booking_Needs_Payment`), and it now reads "Purchase Order" there too.

**To roll back**, set the values in both `objectTranslations` files back to
`Order`/`Orders` and `Contract`/`Contracts` and redeploy.

---

## Gotchas worth remembering

- **Custom metadata records need `xmlns:xsd` declared.** Without it, `xsi:type="xsd:string"`
  fails with an opaque `UNKNOWN_EXCEPTION` and zero component failures. XML parsers
  don't catch it because the undeclared prefix is in an attribute *value*.
- **FlexiPage API names cannot contain `__`** — it is parsed as a namespace separator.
- **The VF PDF renderer is Flying Saucer (CSS 2.1).** `DocumentPdf.page` is table-based
  on purpose. Flexbox and grid render as garbage, silently.
- **PDFs are snapshotted, not regenerated.** *Save to Record* stores a `ContentVersion`
  against the record so an issued document stops changing when the data does.

---

## Commands

```bash
sf project deploy start -d force-app -o salesOrgSDO   # deploy everything
sf apex run test -n DocumentGeneratorTest -o salesOrgSDO -y   # 8 tests, all passing
```
