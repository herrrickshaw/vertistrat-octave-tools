function save_figure(h, outfile)
% SAVE_FIGURE  Write figure h to a PNG. Works in MATLAB and Octave (fltk needs a shown window,
% so the figure is made visible briefly, printed and closed).
  set(h, 'visible', 'on'); drawnow;
  print(h, outfile, '-dpng', '-r150'); close(h);
end
