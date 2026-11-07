
function MOC_NACA2D()
% MOC_NACA2D - Demonstrateur MOC stationnaire 2D pour un profil NACA 4 digits.
% MATLAB R2019b+ ; aucun toolbox requis.
%
% IMPORTANT : modele inviscide, supersonique, isentropique ET irrotationnel
% entre les chocs. Le choc est ajuste par theta-beta-M sur la branche faible.
% Le nez arrondi, le choc detache, les poches subsoniques, la vorticite et les
% gradients d'entropie crees par un choc courbe NE SONT PAS resolus.
% Il s'agit d'une approximation shock-fitting / MOC et non d'un solveur Euler
% avec choc detache exact. Ne pas utiliser pour dimensionner une aerostructure.

%% =================== PARAMETRES MODIFIABLES =============================
P.naca            = '0012';   % 0012, 2412, 4415, etc.
P.alpha_deg       = 0;      % rotation du profil autour du bord d'attaque
P.Minf            = 1.2;      % strictement supersonique
P.gamma           = 1.4;
P.R               = 287.05;   % J/(kg.K)
P.Tinf            = 288.15;   % K
P.pinf            = 101325;  % Pa
P.chord           = 1.0;     % m
P.Nx              = 480;     % stations de marche suivant x
P.Ny              = 85;      % points transversaux par cote
P.nGeometry       = 5500;    % points du profil
P.maxInitialTurn  = 0.70;    % fraction de delta_max admise au depart
P.maxCutFraction  = 0.32;    % si nez exclu > 32%% c, refuser le calcul
P.farHeight       = 0.75;    % c, limite pour une face sans choc
P.characteristics = 27;      % nombre de graines par famille
P.showLabels      = true;
%% =======================================================================

assert(P.Minf > 1.0, 'MOC stationnaire classique : il faut Minf > 1.');
assert(P.gamma > 1 && P.R > 0 && P.Tinf > 0 && P.pinf > 0);
assert(P.Nx >= 50 && P.Ny >= 12);

[body, faces] = nacaGeometry(P);
muInf = asin(1/P.Minf);
nuInf = pmAngle(P.Minf,P.gamma);
[betaPeak,deltaMax,betaLimit] = shockLimits(P.Minf,P.gamma);

xEnd = min([faces(1).X(end),faces(2).X(end)])-0.008*P.chord;
xStart = chooseCut(faces,P,xEnd,deltaMax,muInf,betaLimit);
x = linspace(xStart,xEnd,P.Nx);

fprintf('\n===== MOC / NACA %s =====\n',P.naca);
fprintf('M_inf = %.3f ; alpha = %.2f deg ; gamma = %.4f\n', ...
        P.Minf,P.alpha_deg,P.gamma);
fprintf('T_inf = %.2f K ; p_inf = %.0f Pa ; a_inf = %.2f m/s\n', ...
        P.Tinf,P.pinf,sqrt(P.gamma*P.R*P.Tinf));
fprintf('rho_inf = %.5f kg/m3 ; U_inf = %.2f m/s\n', ...
        P.pinf/(P.R*P.Tinf),P.Minf*sqrt(P.gamma*P.R*P.Tinf));
fprintf('delta_max = %.2f deg ; beta_peak = %.2f deg\n', ...
        rad2deg(deltaMax),rad2deg(betaPeak));
fprintf('Nez NON resolu : x/c < %.4f (choc detache possible).\n', ...
        xStart/P.chord);

sol = cell(1,2);
for s = 1:2
    sol{s} = marchSide(faces(s),x,P,muInf,nuInf,betaLimit);
    if sol{s}.hasShock
        label = 'shock-fitting';
        [turn0,m20,pr0,rhor0]=obliqueState(sol{s}.beta(1),P.Minf,P.gamma);
        fprintf('  Choc initial %s : beta = %.2f deg, theta = %.2f deg, M2 = %.3f\n', ...
                faces(s).name,rad2deg(sol{s}.beta(1)),rad2deg(turn0),m20);
        fprintf('  Relations RH : p2 = %.0f Pa, T2 = %.2f K, rho2/rho1 = %.4f\n', ...
                P.pinf*pr0,P.Tinf*pr0/rhor0,rhor0);
    else
        label = 'detente / champ libre';
    end
    fprintf('Face %-8s : %-22s ; stations resolues %d/%d\n', ...
            faces(s).name,label,sol{s}.last,P.Nx);
    if sol{s}.last < P.Nx
        fprintf('    Limite du solveur : %s\n',sol{s}.message);
    end
end

plotResults(P,body,sol,x,xStart,deltaMax);
end

% ========================= GEOMETRIE ====================================
function [body,faces] = nacaGeometry(P)
code = char(P.naca);
assert(numel(code)==4 && all(code>='0' & code<='9'), ...
       'Le NACA doit etre une chaine de 4 chiffres : ''0012'' ou ''2412''.');
m = str2double(code(1))/100;
p = str2double(code(2))/10;
t = str2double(code(3:4))/100;
if m > 0 && (p<=0 || p>=1)
    error('Pour une cambrure non nulle, le deuxieme chiffre doit etre 1..9.');
end

u = (1-cos(linspace(0,pi,P.nGeometry)))/2;
yt = 5*t*(0.2969*sqrt(u)-0.1260*u-0.3516*u.^2 + ...
          0.2843*u.^3-0.1036*u.^4); % trailing edge ferme

yc=zeros(size(u));dyc=zeros(size(u));
if m > 0
    a = (u <= p); b = ~a;
    yc(a)=m/p^2*(2*p*u(a)-u(a).^2);
    yc(b)=m/(1-p)^2*((1-2*p)+2*p*u(b)-u(b).^2);
    dyc(a)=2*m/p^2*(p-u(a));
    dyc(b)=2*m/(1-p)^2*(p-u(b));
end
phi = atan(dyc);

Xbase = {u-yt.*sin(phi),u+yt.*sin(phi)};
Ybase = {yc+yt.*cos(phi),yc-yt.*cos(phi)};
a = deg2rad(P.alpha_deg); ca=cos(a); sa=sin(a);
faces = struct([]);
for s=1:2
    xx = P.chord*(ca*Xbase{s}-sa*Ybase{s});
    yy = P.chord*(sa*Xbase{s}+ca*Ybase{s});
    [xx,ind] = sort(xx(:)); yy=yy(ind);
    [xx,ind] = unique(xx,'stable'); yy=yy(ind);
    faces(s).X=xx;
    faces(s).Z=(-1)^(s+1)*yy; % coordonnee exterieure z = +/- y
    faces(s).sign=(-1)^(s+1);
    if s==1, faces(s).name='superieure'; else, faces(s).name='inferieure'; end
end
% Polygone dans le repere physique, et non dans le repere de la corde.
body.X=[P.chord*(ca*Xbase{1}-sa*Ybase{1}), ...
        fliplr(P.chord*(ca*Xbase{2}-sa*Ybase{2}))];
body.Y=[P.chord*(sa*Xbase{1}+ca*Ybase{1}), ...
        fliplr(P.chord*(sa*Xbase{2}+ca*Ybase{2}))];
end

function z = wallZ(face,x)
z = interp1(face.X,face.Z,x,'pchip');
end
function slope = wallSlope(face,x,c)
h=1e-4*c;
xL=max(face.X(1)+1e-10*c,x-h);
xR=min(face.X(end)-1e-10*c,x+h);
slope=(wallZ(face,xR)-wallZ(face,xL))./(xR-xL);
end

function x0 = chooseCut(faces,P,xEnd,dmax,muInf,betaLimit)
c=P.chord;
xLow=max([faces(1).X(1),faces(2).X(1),0])+0.01*c;
xHigh=min(P.maxCutFraction*c,xEnd-0.10*c);
assert(xHigh>xLow,'Pas de portion de profil admissible pour cette incidence.');
starts=linspace(xLow,xHigh,520);
x0=NaN;
for xCand=starts
    ok=true;
    for s=1:2
        turn=atan(wallSlope(faces(s),xCand,c));
        if turn>0
            if turn >= P.maxInitialTurn*dmax || turn >= dmax
                ok=false; break;
            end
            beta=weakBeta(turn,P.Minf,P.gamma,muInf,betaLimit);
            if ~isfinite(beta)
                ok=false;break;
            end
            [~,m2]=obliqueState(beta,P.Minf,P.gamma);
            if m2 < 1.15
                ok=false;break;
            end
        end
    end
    if ok, x0=xCand;break;end
end
if isnan(x0)
    error(['Aucun point de depart supersonique admissible avant %.0f%%%% de corde. ' ...
           'Augmenter Minf, diminuer incidence/epaisseur, ou employer Euler 2D.'], ...
          100*P.maxCutFraction);
end
end

% ====================== GAZ ET CHOCS =====================================
function nu=pmAngle(M,g)
M=max(M,1);
v=sqrt(max(0,M.^2-1));
nu=sqrt((g+1)/(g-1))*atan(v*sqrt((g-1)/(g+1)))-atan(v);
end

function [bpeak,dmax,blim]=shockLimits(M,g)
mu=asin(1/M);
bpeak=fminbnd(@(b)-shockTurn(b,M,g),mu+1e-7,pi/2-1e-7);
dmax=shockTurn(bpeak,M,g);
[~,mpeak]=obliqueState(bpeak,M,g);
if mpeak <= 1.02
    blim=fzero(@(b)shockMach(b,M,g)-1.02,[mu+1e-7,bpeak]);
else
    blim=bpeak;
end
end
function m2=shockMach(b,M,g)
[~,m2]=obliqueState(b,M,g);
end
function d=shockTurn(beta,M,g)
s2=(M*sin(beta)).^2;
d=atan(2*cot(beta).*(s2-1)./(M^2*(g+cos(2*beta))+2));
end
function [d,m2,pratio,rhoratio]=obliqueState(beta,M,g)
d=shockTurn(beta,M,g);
mn=M*sin(beta);
mn2sq=(1+0.5*(g-1)*mn^2)/(g*mn^2-0.5*(g-1));
m2=sqrt(mn2sq)/sin(beta-d);
pratio=1+2*g/(g+1)*(mn^2-1);
rhoratio=(g+1)*mn^2/((g-1)*mn^2+2);
end
function b=weakBeta(d,M,g,mu,blim)
if d<=1e-12, b=mu;return;end
if shockTurn(blim,M,g) <= d
    b=NaN;return;
end
b=fzero(@(b)shockTurn(b,M,g)-d,[mu+1e-9,blim]);
end
function [b,ok,msg]=betaFromK(K,M,g,mu,blim)
% A la frontiere choc, K+ vient du domaine aval (en dessous du choc).
% theta2(beta)-nu(M2(beta)) = K+ entrant du domaine aval.
fl=@(b)shockCompatibility(b,M,g,K);
fa=fl(mu+1e-8);fb=fl(blim);
if fa>0
    b=NaN;ok=false;msg='Le choc s''affaiblit jusqu''a disparaitre.';
elseif fb<0
    b=NaN;ok=false;msg='Choc fort / poche subsonique : sortie du domaine MOC.';
else
    b=fzero(fl,[mu+1e-8,blim]);ok=true;msg='';
end
end
function val=shockCompatibility(b,M,g,K)
[d,m2]=obliqueState(b,M,g);
val=d-pmAngle(m2,g)-K;
end

% ====================== MARCHE MOC =======================================
function S=marchSide(face,x,P,muInf,nuInf,blim)
Nx=numel(x);Ny=P.Ny; c=P.chord;
eta=linspace(0,1,Ny)'.^1.12;
S.X=repmat(x,Ny,1);
S.Z=NaN(Ny,Nx);S.TH=NaN(Ny,Nx);S.NU=NaN(Ny,Nx);
S.M=NaN(Ny,Nx);S.beta=NaN(1,Nx);S.zShock=NaN(1,Nx);
S.sign=face.sign;S.hasShock=false;
S.last=1;S.message='OK'; S.x=x;
w0=wallZ(face,x(1));theta0=atan(wallSlope(face,x(1),c));
if theta0>1e-9
    S.hasShock=true;
    b0=weakBeta(theta0,P.Minf,P.gamma,muInf,blim);
    if ~isfinite(b0)
        error('Choc initial non admissible sur la face %s.',face.name);
    end
    [~,M2]=obliqueState(b0,P.Minf,P.gamma);
    dZ=max(0.3*(x(2)-x(1)),0.00015*c);
    S.zShock(1)=w0+dZ;S.beta(1)=b0;
    S.Z(:,1)=w0+dZ*eta;
    S.TH(:,1)=theta0; S.NU(:,1)=pmAngle(M2,P.gamma);
    S.M(:,1)=M2;
else
    zTop=w0+P.farHeight*c;
    S.Z(:,1)=w0+(zTop-w0)*eta;
    S.TH(:,1)=0;S.NU(:,1)=nuInf;
    S.TH(1,1)=theta0;S.NU(1,1)=nuInf-theta0;
    S.M(:,1)=invertPM(S.NU(:,1),P.gamma);
end

for i=2:Nx
    dx=x(i)-x(i-1);
    zw=wallZ(face,x(i));thw=atan(wallSlope(face,x(i),c));
    if S.hasShock
        zs=S.zShock(i-1)+dx*tan(S.beta(i-1));
        betaNew=S.beta(i-1);
        failure='';
        for it=1:3
            yy=zw+(zs-zw)*eta;
            kp=backTrace(yy,+1,i,S,dx);
            km=backTrace(yy,-1,i,S,dx);
            [betaNew,ok,failure]=betaFromK(kp(end),P.Minf,P.gamma,...
                                            muInf,blim);
            if ~ok,break;end
            zs=S.zShock(i-1)+0.5*dx*(tan(betaNew)+tan(S.beta(i-1)));
        end
        if ~ok
            S.message=failure; break;
        end
        if zs<=zw
            S.message='Le front de choc touche numeriquement la paroi.';break;
        end
        yy=zw+(zs-zw)*eta;
        kp=backTrace(yy,+1,i,S,dx);
        km=backTrace(yy,-1,i,S,dx);
        nuWall=km(1)-thw;
        [thShock,mShock]=obliqueState(betaNew,P.Minf,P.gamma);
        nuShock=pmAngle(mShock,P.gamma);
    else
        zTop=S.Z(end,1);
        if zw>=zTop
            S.message='La paroi atteint la frontiere exterieure.';break;
        end
        yy=zw+(zTop-zw)*eta;
        kp=backTrace(yy,+1,i,S,dx);
        km=backTrace(yy,-1,i,S,dx);
        nuWall=km(1)-thw;
    end

    TH=(kp+km)/2;
    NU=(km-kp)/2;
    TH(1)=thw;NU(1)=nuWall;
    if S.hasShock
        TH(end)=thShock;NU(end)=nuShock;
    else
        TH(end)=0;NU(end)=nuInf;
    end
    if any(~isfinite(NU)) || any(NU<=1e-8)
        S.message='Mach local <= 1 ou incompatibilite des caracteristiques.';
        break;
    end
    MM=invertPM(NU,P.gamma);
    if any(~isfinite(MM)) || any(abs(TH)+asin(1./MM)>pi/2-0.055)
        S.message='Une caracteristique ne peut plus etre marchee en x.';
        break;
    end
    S.Z(:,i)=yy;S.TH(:,i)=TH;S.NU(:,i)=NU;S.M(:,i)=MM;
    if S.hasShock
        S.beta(i)=betaNew;S.zShock(i)=zs;
    end
    S.last=i;
end
end

function k=backTrace(yNew,family,i,S,dx)
yOld=S.Z(:,i-1);
thOld=S.TH(:,i-1);
mOld=S.M(:,i-1);
nuOld=S.NU(:,i-1);
% Trace semi-lagrangien a deux estimations (pied de caracteristique).
yQuery=min(max(yNew,yOld(1)),yOld(end));
ang=interp1(yOld,thOld,yQuery,'linear')+ ...
    family*asin(1./interp1(yOld,mOld,yQuery,'linear'));
yFoot=yNew-dx*tan(ang);
yFoot=min(max(yFoot,yOld(1)),yOld(end));
ang2=interp1(yOld,thOld,yFoot,'linear')+ ...
     family*asin(1./interp1(yOld,mOld,yFoot,'linear'));
yFoot=yNew-0.5*dx*(tan(ang)+tan(ang2));
yFoot=min(max(yFoot,yOld(1)),yOld(end));
k=interp1(yOld,thOld-family*nuOld,yFoot,'linear');
end

function M=invertPM(nu,g)
% Table monotone rapide, sans solveur non lineaire par cellule.
persistent cachedGamma Mgrid ngrid
if isempty(cachedGamma) || cachedGamma~=g
    cachedGamma=g;
    Mgrid=linspace(1.000001,35,40000);
    ngrid=pmAngle(Mgrid,g);
end
M=interp1(ngrid,Mgrid,nu,'linear',NaN);
end

% ======================= VISUALISATION ===================================
function plotResults(P,body,sol,x,xStart,dmax)
figure('Color','w','Name','MOC 2D - NACA','Position',[70 90 1480 850]);
t=tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
ax=nexttile(t,1);hold(ax,'on');
% Le fond represente seulement l'etat uniforme NON perturbe.
xl=[min(-0.08*P.chord,min(body.X)-0.02*P.chord), ...
    1.08*P.chord];
yUpper=max([sol{1}.Z(end,sol{1}.last),0.5*P.chord]);
yLower=-max([sol{2}.Z(end,sol{2}.last),0.5*P.chord]);
yl=[max(-0.95*P.chord,yLower-0.02*P.chord), ...
    min(0.95*P.chord,yUpper+0.02*P.chord)];
patch(ax,[xl(1) xl(2) xl(2) xl(1)], ...
         [yl(1) yl(1) yl(2) yl(2)],[0.96 0.96 0.96], ...
         'EdgeColor','none','FaceAlpha',0.05);
allM=P.Minf;
for s=1:2
    S=sol{s};J=1:S.last;
    vM=S.M(:,J);
    allM=[allM;vM(:)]; %#ok<AGROW>
    surf(ax,S.X(:,J),S.sign*S.Z(:,J),zeros(size(S.M(:,J))),S.M(:,J), ...
          'EdgeColor','none','FaceColor','interp');
end
view(ax,2);axis(ax,'normal');
Mvals=allM(isfinite(allM));
lo=min([Mvals(:);P.Minf]);hi=max([Mvals(:);P.Minf]);
if hi-lo<0.02,lo=lo-0.02;hi=hi+0.02;end
caxis(ax,[lo hi]);colormap(ax,parula(256));
cb=colorbar(ax);cb.Label.String='Mach local (regions supersoniques calculees)';

% Caracteristiques en aval : deux familles sur chaque cote.
for s=1:2
    traceChars(ax,sol{s},P.characteristics);
end
for s=1:2
    S=sol{s};if S.hasShock
        J=1:S.last;
        plot(ax,x(J),S.sign*S.zShock(J),'k-','LineWidth',2.1);
    end
end
% Geometrie exacte, y compris le nez qui n'est pas dans la zone resolue.
fill(ax,body.X,body.Y,[0.19 0.22 0.27], ...
     'EdgeColor',[0.06 0.07 0.09],'LineWidth',1.25);
plot(ax,[xStart xStart],yl,':','Color',[0.5 0.19 0.15],'LineWidth',1.0);
if P.showLabels
    text(ax,0.025*P.chord,0.82*yl(2), ...
         sprintf('Nez non resolu : x/c < %.3f',xStart/P.chord), ...
         'Color',[0.55 0.12 0.10],'FontSize',10,'FontWeight','bold');
    text(ax,0.55*P.chord,0.85*yl(2), ...
         'Traits noirs : chocs ajustes (approximation MOC)', ...
         'Color',[0.12 0.12 0.12],'FontSize',10);
end
xlabel(ax,'x (m)');ylabel(ax,'y (m)');
title(ax,sprintf(['NACA %s | M_\infty = %.2f | \alpha = %.1f^\circ | ' ...
                  'C^+ (bleu), C^- (orange), choc (noir)'], ...
                  P.naca,P.Minf,P.alpha_deg));
xlim(ax,xl);ylim(ax,yl);grid(ax,'on');box(ax,'on');

ax2=nexttile(t,2);hold(ax2,'on');
cc=[0.06 0.39 0.66;0.83 0.30 0.11];
for s=1:2
    S=sol{s};I=1:S.last;
    plot(ax2,x(I)/P.chord,S.M(1,I),'Color',cc(s,:), ...
         'LineWidth',1.8,'DisplayName',['M paroi ' lower(solName(s))]);
    if S.hasShock
        plot(ax2,x(I)/P.chord,S.M(end,I),'--','Color',cc(s,:), ...
             'LineWidth',1.0,'DisplayName',['M post-choc ' lower(solName(s))]);
    end
end
plot(ax2,[x(1) x(end)]/P.chord,P.Minf*[1 1],':', ...
     'Color',[0.25 0.25 0.25],'DisplayName','M amont');
xlabel(ax2,'x / c');ylabel(ax2,'Mach');
title(ax2,sprintf('Mach parietal et post-choc | limite de virage = %.1f^\circ', ...
                  rad2deg(dmax)));
xlim(ax2,[0 1]);grid(ax2,'on');box(ax2,'on');legend(ax2,'Location','best');
end

function name=solName(s)
if s==1,name='superieure';else,name='inferieure';end
end

function traceChars(ax,S,nSeed)
if S.last<3,return;end
seeds=unique(round(linspace(2,max(3,S.last-5),nSeed)));
for family=[+1,-1]
    if family*S.sign==1, color=[0.13 0.43 0.71];
    else, color=[0.91 0.52 0.18];end
    for seed=seeds
        if seed>=S.last,continue;end
        if family==1
            z=S.Z(1,seed)+0.012*(S.Z(end,seed)-S.Z(1,seed));
        else
            z=S.Z(end,seed)-0.012*(S.Z(end,seed)-S.Z(1,seed));
        end
        xp=S.x(seed);yp=z;zz=z;
        for i=seed:(S.last-1)
            yi=S.Z(:,i);
            if zz<yi(1) || zz>yi(end),break;end
            theta=interp1(yi,S.TH(:,i),zz,'linear');
            mm=interp1(yi,S.M(:,i),zz,'linear');
            slope=tan(theta+family*asin(1/mm));
            if ~isfinite(slope) || abs(slope)>40,break;end
            znew=zz+(S.x(i+1)-S.x(i))*slope;
            if znew<S.Z(1,i+1) || znew>S.Z(end,i+1),break;end
            xp(end+1)=S.x(i+1); %#ok<AGROW>
            yp(end+1)=znew; %#ok<AGROW>
            zz=znew;
        end
        if numel(xp)>=2
            % Les familles sont inversees sur la face inferieure (repere z=-y).
            plot(ax,xp,S.sign*yp,'Color',color,'LineWidth',0.58);
        end
    end
end
end
