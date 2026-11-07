# VertiStrat Octave tools

Free modelling tools for advisory work, written for GNU Octave (free, no licence). Tested in Octave 11.3. The code avoids Octave-only features and is intended to run in MATLAB too, but that has not been checked.

**Every default for cost, price, yield and permanence is a placeholder, not data about any company.** Replace them with quotes, field data and the rules of your certification standard before showing results to anyone. Read `docs/METHODS.md` for every equation, assumption and limit.

## Tools

| Tool | What it does |
|---|---|
| `project_model.m` | Yearly project finance: depreciation, tax with loss carry-forward, debt (equal, annuity, moratorium), working capital, project and equity IRR, NPV, payback, DSCR, LLCR, annual table |
| `biochar_model.m` | Detailed biochar carbon removal plant: moisture, power, co-products, credit lag and escalation, decommissioning, break-even credit price, run through `project_model` |
| `gas_projection.m` | Year-by-year regional gas demand (low/base/high) and import-terminal loading |
| `plantation_model.m` | Plantation feedstock: land, planting blocks, yield ramp, costs, peak funding, levelised cost of oil, break-even yield and price |
| `monte_carlo.m` | Risk simulation on any model, with P10/P50/P90 and probability of a positive result |
| `tornado.m` | One-at-a-time sensitivity chart for any model |
| `unit_convert.m` | MMTPA, mmscmd, MMBtu, carbon to CO2 and biochar to CO2 |
| `export_csv.m` | Write annual tables to CSV |
| `project_finance.m`, `biochar_plant_economics.m`, `gas_demand_scenario.m`, `feedstock_land.m` | First-cut versions, kept because the detailed tools are checked against them |
| `irr_calc.m`, `payback_years.m`, `save_figure.m` | Helpers |

## Run

```bash
cd ~/Downloads/vertistrat_octave_tools
octave-cli test_tools.m      # checks against hand calculations
octave-cli run_examples.m    # writes out/examples.txt, charts and an annual table CSV
```

In Octave a window flashes briefly while each chart saves (the only plotting toolkit available there needs one).

## Change inputs

Pass a struct with only the fields you want to change:

```matlab
r = biochar_model(struct('feed_tpd_wet', 50, 'credit_price', 180, 'debt_share', 0.6, 'tenor', 8));
r.npv, r.model.min_dscr, r.breakeven_credit_price

g = gas_projection(struct('terminal_mmtpa', 3, 'terminal_share', [0.4 0.5 0.6]));
p = plantation_model(struct('oil_yield', 1.5, 'oil_price', 1100));

% risk: triangular ranges [min mode max]
base = biochar_model().inputs; base.compute_breakeven = false;
R = monte_carlo(@biochar_model, base, struct('credit_price', [90 150 220], 'yield_dry', [0.22 0.30 0.35]), 'npv', 2000, 1);
```

## What has been checked

Hand-worked tests cover tax, loan schedules, coverage ratios, unit factors, sampling and the model-to-model consistency checks listed in `docs/METHODS.md` section 8. Not checked: any independent third-party model, any real plant's data, MATLAB.
