function v = unit_convert(x, from, to, varargin)
% UNIT_CONVERT  Conversions used in gas, LNG and carbon work.
%   v = unit_convert(1.5, 'mmtpa_lng', 'mmscmd')
%   Units: mmscmd, mmtpa_lng, lng_t_per_day, mmbtu_per_day, tbtu_per_year, scm_per_day,
%          tco2_per_tc (carbon to CO2), tco2_per_tbiochar (needs 'carbon_fraction')
%   Options: 'scm_per_t_lng' (default 1314, which gives 1 MMTPA = 3.6 mmscmd as used in the
%            Haldia email; engineering practice ranges about 1,310-1,390), 'mmbtu_per_scm'
%            (default 0.0353, i.e. 1,000 Btu/scf; Indian pipeline gas is closer to 0.0377).
%   All factors are approximations; state the factor you used when quoting results.
  p = inputParser; p.addParameter('scm_per_t_lng', 1314); p.addParameter('mmbtu_per_scm', 0.0353);
  p.addParameter('carbon_fraction', 0.75); p.parse(varargin{:}); o = p.Results;
  scm_per_day = struct('mmscmd', 1e6, 'scm_per_day', 1, 'mmtpa_lng', 1e6*o.scm_per_t_lng/365, ...
                       'lng_t_per_day', o.scm_per_t_lng, 'mmbtu_per_day', 1/o.mmbtu_per_scm, ...
                       'tbtu_per_year', 1e6/o.mmbtu_per_scm/365);
  if isfield(scm_per_day, from) && isfield(scm_per_day, to)
    v = x * scm_per_day.(from) / scm_per_day.(to);
  elseif strcmp(from, 'tc') && strcmp(to, 'tco2'), v = x * 44/12;
  elseif strcmp(from, 'tco2') && strcmp(to, 'tc'), v = x * 12/44;
  elseif strcmp(from, 'tbiochar') && strcmp(to, 'tco2'), v = x * o.carbon_fraction * 44/12;
  else, error('unit_convert: no conversion from %s to %s', from, to);
  end
end
