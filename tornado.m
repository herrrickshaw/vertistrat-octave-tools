function T = tornado(model, base, ranges, metric, outfile, ttl)
% TORNADO  One-at-a-time sensitivity of a scalar model output, with an optional PNG chart.
%   model   function handle taking the input struct and returning a struct
%   base    input struct; ranges: struct of [low high] values per field to vary
%   metric  name of the scalar output field, e.g. 'npv'
  f = fieldnames(ranges); n = numel(f);
  b = model(base).(metric); lo = zeros(n,1); hi = lo;
  for k = 1:n
    s = base; v = ranges.(f{k});
    s.(f{k}) = v(1); lo(k) = model(s).(metric);
    s.(f{k}) = v(2); hi(k) = model(s).(metric);
  end
  [~, idx] = sort(abs(hi - lo), 'ascend');
  T = struct('field', {f(idx)}, 'low', lo(idx), 'high', hi(idx), 'base', b);
  if nargin >= 5 && ~isempty(outfile)
    h = figure('visible', 'off', 'position', [100 100 900 520]);
    hold on;
    for k = 1:n
      plot([lo(idx(k)) hi(idx(k))] - b, [k k], 'linewidth', 14, 'color', [0.12 0.39 0.94]);
    end
    plot([0 0], [0.5 n+0.5], 'k-');
    set(gca, 'ytick', 1:n, 'yticklabel', strrep(f(idx), '_', ' '), 'fontsize', 11);
    xlabel(sprintf('Change in %s from base (%.3g)', strrep(metric,'_',' '), b)); title(ttl); grid on; box off;
    save_figure(h, outfile);
  end
end
