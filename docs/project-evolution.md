# From coursework to portfolio

Original context: BSAN4204 Group 10, The University of Queensland. Fengyu Du developed the fare-checking and carbon-footprint algorithms; Sean Ngiam Hong Zhe developed the UI and design. The current interface and revised analytical implementation belong to the later, AI-assisted portfolio redevelopment phase.

| Area | Original coursework implementation | Portfolio redevelopment |
| --- | --- | --- |
| Structure | Single R Markdown / flexdashboard app | Shiny interface plus independent analytical functions |
| Fare checks | Amount lists and hardcoded refund differences | Date- and scope-aware review suggestions with a rule ID and explanation |
| Import quality | Limited validation; sign-stripping amount conversion | Required columns, signed amounts, duplicate flags and quality reporting |
| Financial metrics | Balance and broad transaction counts | Separate journey charges, credits and adjustments; monthly and route spending |
| Carbon estimates | Fixed 1.8 kg per transaction | Distance × factor scenarios, separate mode distances, car occupancy and signed comparison |
| Decision support | Historical records and review export | Commuting budget comparison and monthly carbon/cost scenarios |
| Verification | Course demonstration | 39 synthetic logic checks, server rendering/filter checks, browser interaction checks and user-reported acceptance on a prior Translink export |

## Validation boundaries

On 31 October 2026, Fengyu Du reported that a previous personal Translink export worked correctly. The redevelopment process did not inspect or publish that private dataset. This acceptance result does not measure classification precision/recall, establish refund entitlement, or validate carbon factors for the Queensland fleet.

The app does not infer route distances or transport modes from uploaded transactions. Carbon scenarios are independent user-entered assumptions. UK 2025 bus/coach factors are frozen illustrative overseas proxies; rail, car and running-cost defaults are explicitly hypothetical. Local factor calibration and broader export-format coverage remain future work.

## Next improvements

- Add appropriately sourced Queensland mode-specific emissions factors with matched boundaries.
- Validate multiple anonymized export schemas and linked-journey/transfer semantics.
- Add supported historical fare tables with documented exceptions.
- Provide a hosted demo once a hosting account and configuration are selected.
