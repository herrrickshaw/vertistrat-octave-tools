function p = payback_years(cf)
% PAYBACK_YEARS  Years until cumulative cash flow turns non-negative, interpolated within the year.
  cf = cf(:)'; t = 0:numel(cf)-1; cum = cumsum(cf);
  k = find(cum >= 0 & t > 0, 1);
  if isempty(k), p = NaN; return; end
  p = t(k-1) + (-cum(k-1)) / cf(k);
end
