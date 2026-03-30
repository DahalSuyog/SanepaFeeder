function [bij, bi0, b00] = newloss()
% === IEEE 13-Node: B-coefficient estimation with stable output ===
% bij : 13x13 symmetric quadratic B-coefficient matrix
% bi0 : 13x1 linear term vector
% b00 : scalar constant term

% ------- Make results reproducible -------
rng(42,'twister');   % <== fixed seed so results don't change between runs

% ------- Bus ordering (indices 1..13) -------
bus_list = [650 632 633 634 645 646 671 680 684 611 652 692 675];
n_buses  = numel(bus_list);

% ------- Base real power (kW) per bus (spot + distributed loads) -------
% 634: 160+120+120 = 400
% 645: 170
% 646: 230
% 671: 3*385 + (17+66+117) = 1355
% 611: 170
% 652: 128
% 692: 170
% 675: 485+68+290 = 843
P_base = [ ...
     0;    % 650 (slack)
     0;    % 632
     0;    % 633
   400;    % 634
   170;    % 645
   230;    % 646
  1355;    % 671
     0;    % 680
     0;    % 684
   170;    % 611
   128;    % 652
   170;    % 692
   843     % 675
];

% ------- Feeder edges (A,B,len_ft,config) : ignore transformers/switches -------
edge_tbl = {
  632, 645,  500, '603';
  632, 633,  500, '602';
  633, 634,    0, 'XFM1'; % transformer -> ignore for R across this link
  645, 646,  300, '603';
  650, 632, 2000, '601';
  684, 652,  800, '607';
  632, 671, 2000, '601';
  671, 684,  300, '604';
  671, 680, 1000, '601';
  671, 692,    0, 'SW';   % switch -> ignore
  684, 611,  300, '605';
  692, 675,  500, '606';
};

% ------- Approx. positive-sequence R (ohm/mile) from config diags -------
cfgR = struct();
cfgR.c601 = mean([0.3465 0.3375 0.3414]);
cfgR.c602 = mean([0.7526 0.7475 0.7436]);
cfgR.c603 = mean([1.3294 1.3471 1.3238]); % zeros ignored
cfgR.c604 = mean([1.3238 1.3294]);        % zeros ignored
cfgR.c605 = 1.3292;
cfgR.c606 = mean([0.7982 0.7891]);
cfgR.c607 = 1.3425;

cfgRmap = containers.Map( ...
  {'601','602','603','604','605','606','607'}, ...
  [ cfgR.c601, cfgR.c602, cfgR.c603, cfgR.c604, cfgR.c605, cfgR.c606, cfgR.c607 ] ...
);

% ------- Build graph with edge weight = R (ohm) -------
E = []; edgeIds = {};
for k = 1:size(edge_tbl,1)
    a  = edge_tbl{k,1}; b = edge_tbl{k,2};
    lf = edge_tbl{k,3}; cf = edge_tbl{k,4};
    if startsWith(cf,'XFM') || strcmpi(cf,'SW'), continue; end  % no R across xfm/switch
    len_mile = lf / 5280;
    if isKey(cfgRmap, cf), R_line = cfgRmap(cf) * len_mile; else, R_line = 0; end
    i = find(bus_list==a,1); j = find(bus_list==b,1);
    if ~isempty(i) && ~isempty(j)
        E(end+1,:)    = [i j R_line]; %#ok<AGROW>
        edgeIds{end+1}= sprintf('%d-%d',min(i,j),max(i,j)); %#ok<AGROW>
    end
end
G = graph(E(:,1), E(:,2), E(:,3), n_buses);

edgeKey    = @(u,v) sprintf('%d-%d',min(u,v),max(u,v));
pathEdges  = @(pth) arrayfun(@(k) edgeKey(pth(k),pth(k+1)), 1:max(0,numel(pth)-1), 'uni', false);

% Shortest (minimum-R) paths from slack to each bus
slack_idx = find(bus_list==650,1);
busPathEdgeSets = cell(n_buses,1);
for n = 1:n_buses
    if n==slack_idx
        busPathEdgeSets{n} = {};
    else
        p = shortestpath(G, slack_idx, n,'Method','positive'); % uses edge R as weight
        busPathEdgeSets{n} = pathEdges(p);
    end
end

% Shared-path resistance matrix Rsh(i,j) = sum of R of edges common to both paths
Rsh = zeros(n_buses);
for i = 1:n_buses
    Ei = busPathEdgeSets{i};
    for j = i:n_buses
        Ej = busPathEdgeSets{j};
        if isempty(Ei) || isempty(Ej)
            Rij = 0;
        else
            Rij = 0;
            setEj = containers.Map(Ej, true(1,numel(Ej)));
            for t = 1:numel(Ei)
                if isKey(setEj, Ei{t})
                    uv = sscanf(Ei{t},'%d-%d');
                    w  = G.Edges.Weight(findedge(G,uv(1),uv(2)));
                    Rij = Rij + w;
                end
            end
        end
        Rsh(i,j) = Rij; Rsh(j,i) = Rij;
    end
end

% ------- Synthetic samples (±20%) & quadratic loss model -------
num_samples = 300;
Vln_kV = 4.16/sqrt(3);   % kV (line-neutral)
V2     = (Vln_kV*1e3)^2; % V^2 scale (regression absorbs scale anyway)

P_data = zeros(num_samples, n_buses);
losses = zeros(num_samples, 1);

for k = 1:num_samples
    Pi = P_base .* (0.8 + 0.4*rand(n_buses,1));  % kW
    L_quad = (Pi.' * Rsh * Pi) / V2;             % quadratic (ohmic) loss surrogate
    L_lin  = 0.01 * sum(Pi);                     % tiny linear component
    L_cst  = 10;                                 % fixed loss
    P_data(k,:) = Pi.';
    losses(k)   = L_quad + L_lin + L_cst;
end

% ------- Build regression matrix: [upper-tri(Pi*Pj) | Pi | 1] -------
nq = n_buses*(n_buses+1)/2;
X  = zeros(num_samples, nq + n_buses + 1);
UT = zeros(nq,2); c = 0;
for i = 1:n_buses
    for j = i:n_buses
        c = c+1; UT(c,:) = [i j];
    end
end
for s = 1:num_samples
    Pi = P_data(s,:).';
    q  = Pi(UT(:,1)) .* Pi(UT(:,2));
    X(s,:) = [q.'  Pi.'  1];
end
Y = losses(:);

% Robust LS with pseudoinverse
b = pinv(X) * Y;

% Unpack to bij, bi0, b00
B_quad = b(1:nq);
B_lin  = b(nq+1:nq+n_buses);
B_cst  = b(end);

bij = zeros(n_buses);
idx = 1;
for i = 1:n_buses
    for j = i:n_buses
        bij(i,j) = B_quad(idx);
        bij(j,i) = B_quad(idx);
        idx = idx+1;
    end
end
bi0 = B_lin;        % 13x1 column
b00 = B_cst;        % scalar

% (Optional) quick prints
% disp('B_ij (13x13):'); disp(bij);
% disp('b_i0 (13x1):');  disp(bi0);
% disp('b_00:');         disp(b00);
end
