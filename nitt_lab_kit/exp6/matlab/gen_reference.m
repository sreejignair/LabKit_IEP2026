% gen_reference.m  -  Experiment 6
% Produces the channel data and the double-precision reference line.
%
% Uses Field II if it is on the path; otherwise falls back to an equivalent
% synthetic generator. Either is acceptable for this experiment - state in your
% report which you used.
%
% Run this first. It writes ../data/ref_matlab.mat

clear; clc;

P.c      = 1540;        % m/s
P.f0     = 5e6;         % Hz
P.fs     = 40e6;        % Hz
P.N_CH   = 8;
P.pitch  = 0.3e-3;      % m
P.depth  = [24e-3 26e-3];
P.N_PTS  = 64;
P.scat   = [25e-3 0 1]; % [z x amplitude]
P.nsamp  = 2048;

elem = ((0:P.N_CH-1) - (P.N_CH-1)/2) * P.pitch;
zs   = linspace(P.depth(1), P.depth(2), P.N_PTS);

use_field = exist('field_init','file') == 2;
if use_field
    fprintf('using Field II\n');
    field_init(-1);
    set_field('c', P.c); set_field('fs', P.fs);
    % --- a minimal linear array; adapt the element geometry to your setup
    tx = xdc_linear_array(P.N_CH, P.pitch*0.9, 5e-3, P.pitch*0.1, 1, 1, [0 0 300]);
    rx = xdc_linear_array(P.N_CH, P.pitch*0.9, 5e-3, P.pitch*0.1, 1, 1, [0 0 300]);
    exc = sin(2*pi*P.f0*(0:1/P.fs:2/P.f0));
    xdc_excitation(tx, exc);
    xdc_impulse(tx, exc); xdc_impulse(rx, exc);
    pos = [P.scat(2) 0 P.scat(1)];
    [rf, t0] = calc_scat_multi(tx, rx, pos, P.scat(3));
    x = zeros(P.nsamp, P.N_CH);
    i0 = round(t0*P.fs) + 1;
    n  = min(size(rf,1), P.nsamp - i0);
    x(i0:i0+n-1, :) = rf(1:n, :);
    field_end;
else
    fprintf('Field II not found - using the synthetic generator\n');
    t     = (0:P.nsamp-1)'/P.fs;
    sigma = 2.0/P.f0;                       % ~2-cycle Gaussian envelope
    x     = zeros(P.nsamp, P.N_CH);
    for ch = 1:P.N_CH
        r   = hypot(elem(ch)-P.scat(2), P.scat(1));
        tau = (P.scat(1) + r)/P.c;
        x(:,ch) = P.scat(3) * exp(-((t-tau).^2)/(2*sigma^2)) .* cos(2*pi*P.f0*(t-tau));
    end
end

% --- double-precision reference beamforming, linear interpolation
y_ref = zeros(P.N_PTS,1);
for p = 1:P.N_PTS
    z = zs(p);
    r = hypot(elem, z);
    nidx = (z + r)/P.c*P.fs;
    n0 = floor(nidx); fr = nidx - n0;
    s  = zeros(1,P.N_CH);
    for ch = 1:P.N_CH
        s(ch) = x(n0(ch)+1,ch)*(1-fr(ch)) + x(n0(ch)+2,ch)*fr(ch);
    end
    apod = hanning(P.N_CH+2)'; apod = apod(2:end-1);
    y_ref(p) = sum(apod .* s);
end

save('../data/ref_matlab.mat','x','y_ref','zs','P','-v7');
fprintf('wrote ../data/ref_matlab.mat  (%d samples x %d channels, %d points)\n', ...
        size(x,1), size(x,2), P.N_PTS);
fprintf('peak of the reference line: %.6g\n', max(abs(y_ref)));
