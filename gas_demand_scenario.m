function r = gas_demand_scenario(s)
% GAS_DEMAND_SCENARIO  Bottom-up city gas + anchor-load demand in mmscmd for low/base/high cases.
%   Each field of s is a 1x3 vector [low base high]:
%     cng_stations, scmd_per_station, png_connections, scm_per_connection_day,
%     ci_mmscmd (commercial+industrial), anchor_mmscmd (fertiliser, power etc.)
%   Defaults reproduce the West Bengal FY2030 view in the Haldia FSRU email (2026-11-05).
  d.cng_stations           = [471 645 819];
  d.scmd_per_station       = [1330 2400 3109];
  d.png_connections        = [427000 427000 0.20*1.46e7];
  d.scm_per_connection_day = [0.073 0.23 0.23];
  d.ci_mmscmd              = [0.03 0.23 0.88];
  d.anchor_mmscmd          = [2.4 2.7 2.7];
  if nargin < 1, s = struct(); end
  f = fieldnames(s); for k = 1:numel(f), d.(f{k}) = s.(f{k}); end
  r.cng = d.cng_stations .* d.scmd_per_station / 1e6;
  r.png = d.png_connections .* d.scm_per_connection_day / 1e6;
  r.ci = d.ci_mmscmd;
  r.city_gas = r.cng + r.png + r.ci;
  r.anchor = d.anchor_mmscmd;
  r.total = r.city_gas + r.anchor;
  r.labels = {'Low','Base','High'};
  r.inputs = d;
end
