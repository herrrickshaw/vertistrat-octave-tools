# Methods, assumptions and limits

Everything here is a screening tool. It turns assumptions into numbers consistently and shows which assumptions matter. It does not replace vendor quotes, an engineer's yield data, a lender's term sheet or a tax adviser. **Every default for cost, price, yield and permanence is a placeholder.** None of it is data about any company.

Tested in GNU Octave 11.3 only. The code avoids Octave-only features and is intended to run in MATLAB, but that has not been checked.

## 1. Conventions

- Year 0 is the first construction year. Cash flows are yearly, end of year, with no mid-year convention.
- Currency is whatever you put in. The biochar and plantation defaults are written in USD.
- Real or nominal: the models do not inflate anything unless you set an escalation input. If prices and costs are real, use a real discount rate.
- Discounting: `NPV = sum( CF_t / (1+r)^t )` with `t = 0` for the first year.
- IRR (`irr_calc`): scans from -95% to 300% in 0.5% steps for the first sign change in NPV, then refines with `fzero`. It returns NaN if cash flows never change sign. With several sign changes there can be several IRRs; the lowest crossing in the scan is returned.
- Payback (`payback_years`): first year cumulative cash is non-negative, interpolated within that year. Undiscounted.

## 2. `project_model`

**Inputs and timeline.** `capex` can be a vector (one value per construction year, starting at year 0). Operations start the year after the last capex entry and run for `numel(revenue)` years.

**EBITDA** = revenue - opex.

**Depreciation (tax).** On total capex, starting in the first operating year.
- `wdv`: dep_t = opening book value x rate. India's general plant and machinery rate is 15%, and some asset classes get 40%. The rate must be set for the asset class actually claimed.
- `slm`: capex / life per year for `life` years.

**Debt.** Drawn pro rata to capex (`debt_share x capex` each year). No interest during construction is capitalised.
- `equal`: principal = D / (tenor - moratorium) a year after the moratorium; interest on the opening balance.
- `annuity`: constant payment `D x i / (1 - (1+i)^-m)` over `m = tenor - moratorium` years, so principal = payment - interest.
- During a moratorium only interest is paid.
- Balances below 1e-9 x D are treated as repaid. (An earlier version let rounding residue count as debt service, which made the average DSCR 8e15; a regression test now covers it.)

**Tax.** Taxable income = EBITDA - depreciation (- interest for the levered case). Losses go into a pool, carried forward without expiry, and are used against later profits. Tax is never negative (no refunds). Real Indian business losses expire after 8 years while unabsorbed depreciation does not, so a long loss run could understate tax slightly.
- Unlevered tax drives the project IRR; levered tax drives CFADS and equity cash flow.

**Working capital.** Held at `wc_share x revenue`; changes are cash flows; the full balance is released in the last year.

**Salvage** is added in the last year (negative for decommissioning cost). It is not taxed.

**Cash flows reported.**
- `cf_pre` = -capex + EBITDA + working-capital cash flow + salvage
- `cf_post` = `cf_pre` - unlevered tax
- CFADS = EBITDA - levered tax + working-capital cash flow
- `cf_equity` = -(capex - drawdown) + CFADS - debt service + salvage

**Coverage ratios.**
- DSCR_t = CFADS_t / (interest_t + principal_t), in years with debt service. It can be negative when CFADS is negative, which means the project cannot pay its debt from operations in that year.
- LLCR = PV of CFADS over the loan tenor, discounted at the loan interest rate, divided by the initial debt. This is a simplification: the usual definition divides by the outstanding balance at the test date.

**Not modelled:** GST/VAT, upfront and commitment fees, debt service reserve, tax on salvage, state or central subsidies and grants, interest during construction, inflation, carbon credit forward sales or streaming, foreign exchange.

## 3. `biochar_model`

Per operating year `y`:

- Wet feed = feed_tpd_wet x days x utilisation_y. Dry feed = wet x (1 - moisture).
- Biochar = dry feed x yield_dry.
- Removal per tonne of biochar = carbon_fraction x permanence x 44/12 x (1 - project_emissions) x (1 - buffer), in t CO2e. 44/12 is the CO2-to-carbon mass ratio.
- Credits_y = biochar_y x that factor.
- Credit price_y = credit_price x (1 + price_escalation)^(y-1). Cash arrives in year `y + lag`; credits that would arrive after the last year are received in the last year (an optimistic simplification).
- Revenue adds biochar sales, heat or syngas revenue, and wood vinegar.
- Opex = (wet feed x feed_cost + electricity x (1 - self_generation) x price + labour + other fixed + capex x (maintenance + insurance share) + credits x MRV cost per credit) x (1 + cost_escalation)^(y-1).
- Decommissioning = decommission_share x capex, as negative salvage in the last year.
- The cash flows go into `project_model`, so tax, debt, DSCR and equity returns come from section 2.
- `breakeven_credit_price` is the price at which after-tax project NPV is zero (found with `fzero`).

**Which numbers matter most.** In the worked example the credit price, feed cost, capex and yield drive NPV most; see the tornado chart. The permanence factor and the project-emissions share are set by the registry methodology and the plant's life-cycle assessment. They should come from the chosen standard (for example Puro.earth, Isometric or Verra), not from this file.

**Not modelled:** certification and registration fees beyond the per-credit MRV cost, biochar quality failures, feedstock seasonality, plant downtime beyond the ramp, carbon accounting of the heat used, delivery risk on forward credit contracts.

## 4. `gas_projection`

- Each driver (stations, volume per station, PNG connections, volume per connection, commercial and industrial demand) moves from its start-year value to its target-year value along a smooth S-curve: with `u = (year - start)/(target - start)` clipped to [0, 1], the path uses `u^2 (3 - 2u)` ("smoothstep"). `shape = 'linear'` uses `u` directly.
- CNG = stations x scmd per station / 1e6 (mmscmd). PNG = connections x scm per connection per day / 1e6.
- After the target year each segment's demand (CNG, PNG, commercial and industrial) grows at `post_growth` a year. The growth is applied once to the segment total, not to each factor. A test guards this.
- Anchor loads are constant from their start year. In the default case the low case uses the plant's rated capacity (2.4 mmscmd) and base and high use 112% utilisation (2.7), so the low and base cases already differ in 2026.
- Terminal loading = total demand x share the terminal could serve x ramp, divided by terminal capacity. The share (default 50%) and ramp (3 years) are assumptions, not data.
- At the target year, with default inputs, the result reproduces `gas_demand_scenario` and the West Bengal table in the Haldia email: 3.1 / 4.6 / 6.8 mmscmd.

**Not modelled:** competing supply (pipeline, other terminals), price elasticity, seasonality, demand outside the region, power or refinery loads.

## 5. `plantation_model`

- Hectares = demand / oil yield at maturity. Land is planted in `plant_years` equal blocks.
- A block of age `a` gives `yield x ramp(a)` tonnes of oil per hectare. Default ramp: nothing for three years, then 25%, 50%, 75% and 100% from year 7.
- Costs: establishment per hectare spread over `est_years`, then upkeep per hectare per year; lease per hectare per year from planting; harvest cost per tonne of seed (oil / extraction); crushing cost per tonne of oil.
- Revenue = oil x oil price + meal x meal price. **Meal price defaults to zero** because feed safety and a buyer are unproven.
- Levelised cost of oil = PV of costs / PV of oil, net of meal revenue when `meal_credit` is true.
- `breakeven_oil_yield` and `breakeven_oil_price` are found with `fzero` (NPV = 0).
- With zero meal price, break-even oil price equals the levelised cost, which a test checks.

**Oil yield per hectare is the weakest input.** The 3.5-5 t/ha used in public company material is the company's own modelling. Field data for the specific site and variety should replace it. The example table shows how land need and peak funding change if yield is much lower.

**Not modelled:** land purchase, irrigation capex beyond the establishment cost, tax, working capital, replanting, yield risk from weather or disease, carbon income from the trees themselves.

## 6. `monte_carlo` and `tornado`

- Triangular draws use the inverse CDF. A range `[min mode max]` is triangular; `[lo hi]` is uniform. Draws are independent and the seed is fixed so runs repeat.
- Independence is a real limitation. Price, yield and cost move together in practice, which widens the true spread. Treat the output as a first screen.
- `tornado` changes one input at a time between its low and high value and records the output swing. It ignores interactions between inputs.

## 7. `unit_convert`

- 1 MMTPA of LNG = 3.6 mmscmd at the default 1,314 scm per tonne. That is the factor used in the Haldia email workings. Practice ranges from about 1,310 to 1,390 scm per tonne, which moves 1 MMTPA between about 3.6 and 3.8 mmscmd. Pass `'scm_per_t_lng'` to change it, and state the factor you used.
- Energy conversion uses 0.0353 MMBtu per scm (1,000 Btu per scf); Indian pipeline gas is closer to 0.0377. Both are approximations.
- Carbon to CO2 uses 44/12.

## 8. What has been checked

- `test_tools.m` compares each calculation with hand-worked numbers: IRR and payback, tax and loss carry-forward, loan schedules (equal, annuity, moratorium), DSCR and LLCR, working capital, unit factors, triangular sampling and CSV round trips.
- The detailed biochar model collapses to the first-cut model exactly (same NPV, credits and break-even price) when all its extras are switched off.
- The gas projection reproduces the earlier gas table at the target year.
- **Not checked:** the models against an independent third-party model, any real plant's data, or MATLAB itself. No default has been calibrated to a real project.

## 9. Extending

- Keep a model as a function taking one struct of overrides and returning a struct. Then `tornado` and `monte_carlo` work on it unchanged.
- Put break-even or other slow searches behind a switch (see `compute_breakeven`) so simulations stay fast.
- Add a hand-worked test for each new calculation, and a regression test for each bug.
