% RUN_EXAMPLES  Worked examples for each tool. Run in Octave:  octave-cli run_examples.m
warning('off', 'all');   % hides Octave's fltk-toolkit notice
here = fileparts(mfilename('fullpath')); addpath(here); od = fullfile(here, 'out');
if ~exist(od, 'dir'), mkdir(od); end
fid = fopen(fullfile(od, 'examples.txt'), 'w'); P = @(varargin) fprintf(fid, varargin{:});

% 1. Biochar plant (placeholder inputs)
b = biochar_plant_economics();
P('BIOCHAR PLANT (placeholder inputs - replace with vendor quotes)\n');
P('  Feed %.0f tpd -> biochar %.0f t/yr, credits %.0f t CO2e/yr at full rate (%.2f credits per t feed)\n', ...
  b.inputs.feed_tpd, b.biochar_t(end), b.credits_t(end), b.credits_per_t_feed);
P('  NPV @%.0f%%: USD %.0f   IRR: %.1f%%   payback: %.1f yrs   break-even credit price: USD %.0f/t\n\n', ...
  100*b.inputs.discount_rate, b.npv, 100*b.irr, b.payback_years, b.breakeven_credit_price);
rg = struct('credit_price', [100 200], 'yield', [0.25 0.35], 'capex', [0.9e6 1.6e6], ...
            'feed_cost', [15 40], 'permanence', [0.7 0.9], 'opex_fixed', [100e3 250e3]);
tornado(@biochar_plant_economics, b.inputs, rg, 'npv', fullfile(od, 'biochar_npv_tornado.png'), 'Biochar plant NPV sensitivity (placeholder inputs)');

% 2. Project finance with debt
pf = project_finance(b.cashflow, 0.12, 'debt', 0.6*b.inputs.capex, 'debt_rate', 0.105, 'tenor', 7);
P('PROJECT FINANCE (same plant, 60%% debt at 10.5%%, 7 yrs)\n  Debt service USD %.0f/yr, minimum DSCR %.2f\n\n', pf.debt_service, pf.min_dscr);

% 3. Gas demand (West Bengal FY2030 defaults)
g = gas_demand_scenario();
P('GAS DEMAND, WEST BENGAL FY2030 (mmscmd)   Low   Base   High\n');
P('  City gas                               %5.2f  %5.2f  %5.2f\n', g.city_gas);
P('  Anchor (fertiliser)                    %5.2f  %5.2f  %5.2f\n', g.anchor);
P('  Total                                  %5.2f  %5.2f  %5.2f\n\n', g.total);
h = figure('visible','off','position',[100 100 800 480]);
bar([g.cng; g.png; g.ci; g.anchor]', 'stacked'); set(gca,'xticklabel', g.labels);
legend({'CNG','Domestic PNG','Commercial & industrial','Fertiliser'}, 'location', 'northwest');
ylabel('mmscmd'); title('West Bengal gas demand, FY2030'); grid on;
save_figure(h, fullfile(od, 'wb_gas_demand.png'));

% 4. Feedstock land (pongamia example from the Ecopha email)
L = feedstock_land(100000, [3.5 5]);
P('FEEDSTOCK LAND: 100,000 t oil/yr at 3.5-5 t/ha -> %.0f-%.0f ha; full supply in year %d if planted over 3 years\n', ...
  min(L.hectares), max(L.hectares), L.year_full_supply);
h = figure('visible','off','position',[100 100 800 420]);
plot(L.year, 100*L.share_of_demand, '-o', 'linewidth', 2); ylim([0 110]); grid on;
xlabel('Year from first planting'); ylabel('% of demand met'); title('Plantation supply ramp (low-yield case)');
save_figure(h, fullfile(od, 'feedstock_ramp.png'));
fclose(fid); type(fullfile(od, 'examples.txt'));
