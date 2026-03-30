function [bij, bi0, b00] = newloss_sanepa()
% === IEEE 24-Node: B-coefficient estimation with stable output ===
% bij : 24x24 symmetric quadratic B-coefficient matrix
% bi0 : 24x1 linear term vector
% b00 : scalar constant term

% ------- Make results reproducible -------
rng(42,'twister');   % <== fixed seed so results don't change between runs

% ------- Bus ordering (indices 0..23) -------
bus_list = 0:23;  % 24 buses from 0 to 23
n_buses  = numel(bus_list);

% ------- Base real power (kW) per bus (spot + distributed loads) -------
% Update P_base for 24 buses
P_base = [
    0;    % 0
    64.239;    % 1
    21.8500;    % 2
    29.4975;    % 3
    19.8835;    % 4
    5.1235;     % 5 (Add real data here...)
    7.3230;     % 6
    12.0175;    % 7
    8.7310;     % 8
    104.88;    % 9
    28.5;    % 10
    3.7902;     % 11
    4.2131;     % 12
    28.5;     % 13
    6.2356;     % 14
    2.0987;     % 15
    7.4235;     % 16
    10.7392;    % 17
    5.9995;     % 18
    2.7649;     % 19
    6.9325;     % 20
    3.2348;     % 21
    1.6842;     % 22
    9.3425;     % 23
];

% Load the new line data and load data (assuming these have been pre-processed)
% Line data: (bus, bus.1, length (miles), R_total)
line_data = [
    0, 1, 0.139808, 0.001780;
    1, 2, 0.155343, 0.001978;
    2, 3, 0.186411, 0.002373;
    3, 4, 0.186411, 0.002373;
    4, 5, 0.186411, 0.002373;
    5, 6, 0.2000, 0.00250;
    6, 7, 0.2500, 0.00300;
    7, 8, 0.1800, 0.00220;
    8, 9, 0.1400, 0.00190;
    9, 10, 0.2200, 0.00260;
    10, 11, 0.1500, 0.00200;
    11, 12, 0.1700, 0.00210;
    12, 13, 0.1600, 0.00205;
    13, 14, 0.2100, 0.00250;
    14, 15, 0.1800, 0.00230;
    15, 16, 0.2000, 0.00260;
    16, 17, 0.1900, 0.00240;
    17, 18, 0.2100, 0.00270;
    18, 19, 0.2500, 0.00310;
    19, 20, 0.1600, 0.00200;
    20, 21, 0.1400, 0.00190;
    21, 22, 0.1800, 0.00220;
    22, 23, 0.1600, 0.00210;
    23, 0, 0.2200, 0.00260;  % Assuming last bus connects back to bus 0
];

% Load data: (bus, P BASE kW)
load_data = [
    0, 0.0000;
    1, 64.2390;
    2, 21.8500;
    3, 29.4975;
    4, 19.8835;
    5, 5.1235;
    6, 7.3230;
    7, 18.4920;
    8, 8.7310;
    9, 12.8476;
    10, 11.6530;
    11, 3.7902;
    12, 4.2131;
    13, 1.5604;
    14, 6.2356;
    15, 2.0987;
    16, 7.4235;
    17, 10.7392;
    18, 5.9995;
    19, 2.7649;
    20, 6.9325;
    21, 3.2348;
    22, 1.6842;
    23, 9.3425;
];

% ------- Feeder edges (A,B,len_ft,config) : use updated line_data -------
edge_tbl = {};
for k = 1:size(line_data, 1)
    a = line_data(k, 1);  % Start bus
    b = line_data(k, 2);  % End bus
    len_mile = line_data(k, 3);  % Length in miles
    R_line = line_data(k, 4);  % Resistance (ohms) for the feeder
    len_ft = len_mile * 5280;  % Convert miles to feet

    edge_tbl{end+1, 1} = a;  % Bus A
    edge_tbl{end, 2} = b;    % Bus B
    edge_tbl{end, 3} = len_ft;  % Length in feet
    edge_tbl{end, 4} = R_line;  % Resistance
end

% ------- Build graph with edge weight = R (ohm) -------
E = [];
for k = 1:size(edge_tbl, 1)
    a = edge_tbl{k, 1};
    b = edge_tbl{k, 2};
    R_line = edge_tbl{k, 4};
    i = find(bus_list == a, 1);
    j = find(bus_list == b, 1);
    if ~isempty(i) && ~isempty(j)
        E(end+1, :) = [i j R_line];
    end
end
G = graph(E(:, 1), E(:, 2), E(:, 3), n_buses);

% ------- Calculate Shared-Path Resistance Matrix Rsh -------
Rsh = zeros(n_buses);
slack_idx = find(bus_list == 0, 1);
busPathEdgeSets = cell(n_buses, 1);
for n = 1:n_buses
    if n == slack_idx
        busPathEdgeSets{n} = {};
    else
        p = shortestpath(G, slack_idx, n, 'Method', 'positive');  % Uses edge R as weight
        busPathEdgeSets{n} = arrayfun(@(k) sprintf('%d-%d', min(p(k), p(k+1)), max(p(k), p(k+1))), 1:max(0, numel(p) - 1), 'uni', false);
    end
end

% Shared-path resistance matrix Rsh(i,j) = sum of R of edges common to both paths
for i = 1:n_buses
    Ei = busPathEdgeSets{i};
    for j = i:n_buses
        Ej = busPathEdgeSets{j};
        Rij = 0;
        
        % Check if Ei or Ej is empty, and only create the map if both are not empty
        if ~isempty(Ei) && ~isempty(Ej)
            setEj = containers.Map(Ej, true(1, numel(Ej)));  % Avoid empty keys
            for t = 1:numel(Ei)
                if isKey(setEj, Ei{t})
                    uv = sscanf(Ei{t}, '%d-%d');
                    w = G.Edges.Weight(findedge(G, uv(1), uv(2)));
                    Rij = Rij + w;
                end
            end
        end
        
        Rsh(i, j) = Rij; Rsh(j, i) = Rij;
    end
end

% ------- Synthetic samples (±20%) & quadratic loss model -------
num_samples = 300;
Vln_kV = 4.16 / sqrt(3);  % kV (line-neutral)
V2 = (Vln_kV * 1e3)^2;    % V^2 scale (regression absorbs scale anyway)

P_data = zeros(num_samples, n_buses);
losses = zeros(num_samples, 1);

for k = 1:num_samples
    Pi = P_base .* (0.8 + 0.4 * rand(n_buses, 1));  % kW
    L_quad = (Pi.' * Rsh * Pi) / V2;               % quadratic (ohmic) loss surrogate
    L_lin  = 0.01 * sum(Pi);                       % tiny linear component
    L_cst  = 10;                                   % fixed loss
    P_data(k, :) = Pi.';
    losses(k) = L_quad + L_lin + L_cst;
end

% ------- Build regression matrix: [upper-tri(Pi*Pj) | Pi | 1] -------
nq = n_buses * (n_buses + 1) / 2;
X = zeros(num_samples, nq + n_buses + 1);
UT = zeros(nq, 2);
c = 0;
for i = 1:n_buses
    for j = i:n_buses
        c = c + 1;
        UT(c, :) = [i j];
    end
end
for s = 1:num_samples
    Pi = P_data(s, :).';
    q = Pi(UT(:, 1)) .* Pi(UT(:, 2));
    X(s, :) = [q.' Pi.' 1];
end
Y = losses(:);

% Robust LS with pseudoinverse
b = pinv(X) * Y;

% Unpack to bij, bi0, b00
B_quad = b(1:nq);
B_lin  = b(nq + 1:nq + n_buses);
B_cst  = b(end);

bij = zeros(n_buses);
idx = 1;
for i = 1:n_buses
    for j = i:n_buses
        bij(i, j) = B_quad(idx);
        bij(j, i) = B_quad(idx);
        idx = idx + 1;
    end
end
bi0 = B_lin;        % 24x1 column
b00 = B_cst;        % scalar

end
