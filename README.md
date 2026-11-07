# VertiStrat Octave tools

Free modelling tools for advisory work. They run in GNU Octave (free, no licence; installed via Homebrew) and in MATLAB without changes.

| Tool | What it does |
|---|---|
| `biochar_plant_economics.m` | Biochar output, carbon removal credits, NPV, IRR, payback and break-even credit price for a pyrolysis plant |
| `project_finance.m` | NPV, IRR, payback, and debt service with DSCR for any yearly cash flow |
| `gas_demand_scenario.m` | Bottom-up gas demand (CNG, PNG, commercial and industrial, anchor loads) in mmscmd, low/base/high; defaults reproduce the West Bengal FY2030 view |
| `feedstock_land.m` | Hectares needed for a plantation feedstock and the supply ramp as trees mature |
| `tornado.m` | One-at-a-time sensitivity of any model output, with a PNG chart |

## Run

```bash
cd ~/Downloads/vertistrat_octave_tools
octave-cli test_tools.m      # checks against hand calculations
octave-cli run_examples.m    # writes out/examples.txt and charts
```

In Octave, a window flashes briefly while each chart saves (the only plotting toolkit available here needs one).

## Change inputs

Pass a struct with only the fields you want to change:

```matlab
r = biochar_plant_economics(struct('feed_tpd', 50, 'capex', 2.5e6, 'credit_price', 180));
g = gas_demand_scenario(struct('cng_stations', [300 400 500]));
L = feedstock_land(60000, [2 4]);
```

## Caution

The biochar defaults (capex, opex, feed cost, credit price, yield, permanence) are placeholders. They are not data about Pyrogreen or any other company. Replace them with vendor quotes and the rules of the certification standard you use before showing results to anyone.
