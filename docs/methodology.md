### Scope
Independent portfolio prototype, not affiliated with Translink. One record is treated as one transaction; linked journeys and transfers are not reconstructed. Users must confirm covered Translink services. Airtrain and dedicated school buses are outside scope; airport stop text is conservatively excluded. Historical zone fares are not implemented.

### Screening
From 5 August 2024, covered journey records use a $0.50 baseline. Above-baseline charges prompt review; differences are not guaranteed refunds. The current standard default fare is $2.50, but historical reasons cannot be established from amounts alone. Below-baseline charges may reflect transfers or free travel. Missing data, future dates, duplicates and unconfirmed coverage remain unassessed. Positive fare plus positive credit requires investigation. Negative fares are adjustments, not positive travel charges.

### Metrics and quality
Totals exclude all copies of possible duplicates and records with invalid or future dates. Credits and negative-fare adjustments are separate from journey spend. Counts represent transaction records, not reconstructed journeys. Quality reports cover the full file; date and route filters apply to overview, history and review export. Missing timestamps are excluded from the balance chart. Records are retained for inspection, without automatic deduplication.

Budget = days/week × charged journeys/day × fare × 52/12. This independent scenario assumes regular travel; it does not model holidays or free travel. The original fixed-per-trip emissions estimate is replaced by the explicit scenario model below.

### Sources
Rules checked 31 October 2026; no automatic policy refresh.

- [Translink 50-cent fares](https://translink.com.au/tickets-and-fares/50-cent-fares): covered services, exclusions and free-travel exceptions.
- [Queensland Government launch announcement, 5 August 2024](https://statements.qld.gov.au/statements/101016): baseline start date.
- [Translink default fares](https://translink.com.au/tickets-and-fares/fares-and-zones/fixed-fare): current amounts, dated 27 April 2026, and adjustment process. No historical default-fare table is implemented.

### Privacy
Files are read from Shiny's temporary upload location into session memory. The app does not deliberately save uploads or send records to external APIs. Hosting providers control infrastructure logs and temporary-file lifecycle. CSV export neutralizes formula-like text.

### Project provenance
The original BSAN4204 Group 10 project was jointly developed by Fengyu Du (fare-checking and carbon-footprint algorithms) and Sean Ngiam Hong Zhe (UI and design). The current portfolio redevelopment revises the screening methodology and interface with AI assistance. The original emissions estimator is preserved in the local course archive but is not active in this version.

### Carbon and cost scenarios
Each scenario describes one traveller over 52/12 weeks per month, independently of uploaded records and sidebar filters. Monthly one-way journeys = days/week × journeys/day × 52/12. Public transport kg CO2e = journeys × public transport km × g CO2e/passenger-km ÷ 1000. Driving share kg CO2e = journeys × driving km × g CO2e/vehicle-km ÷ occupancy ÷ 1000. Public transport factors already include average occupancy. Separate distances allow road and public transport paths to differ.

The signed difference is driving minus public transport, so a negative number is retained when public transport is higher. Sensitivity uses user-selected ±v on both factors: lower difference = driving × (1−v) − public transport × (1+v); upper difference = driving × (1+v) − public transport × (1−v). This is a deterministic sensitivity envelope, not a confidence interval, and does not quantify distance or occupancy uncertainty.

Public transport monthly cost = journeys × fare. Driving share = journeys × driving km × running cost/vehicle-km ÷ occupancy. All occupants are assumed to share costs equally; fixed costs, parking and tolls are excluded. The default $0.30/km is illustrative.

Frozen demonstration presets: UK DESNZ 2025 methodology, Table 25, average local bus 103.85 and coach 27.76 g CO2e/passenger-km. These are UK operating-emissions proxies, not Queensland fleet estimates or the latest factors. Rail 50 g/passenger-km and car 180 g/vehicle-km are explicitly illustrative, editable assumptions. Custom values require checking consistent units and emissions boundaries. Manufacturing, infrastructure and fuel supply chains are outside the model; electricity-related boundaries depend on the selected factor. The model does not claim avoided marginal emissions or lifecycle accuracy.

Source: [UK DESNZ 2025 methodology, Table 25](https://assets.publishing.service.gov.uk/media/6846b0870392ed9b784c0187/2025-GHG-CF-methodology-paper.pdf), checked 31 October 2026. Contains public-sector information licensed under the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).
