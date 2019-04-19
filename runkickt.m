function runkickt
% runkickt.m simulates a maximum-excitation knee extension, with
%   Hill muscle model in series with elastic tendon.

% functions referred to from this script:
%   fkickt   kick simulation with tendon
%   fkicke   kick simulation with no tendon
%   fv      force-velocity curve
%   fvi     inverse of force-velocity curve
%   fl      active force-length curve
%   flp     passive force-length curve
%   ftl     tendon force-length curve
%   ftli    inverse of tendon force-length curve
%   dftdl   derivative of tendon force-length curve

% changes made by Tim van der Zee on 2019-04-19:
% 1: discrepancy in use of lopt
% when ode45 is used for the first time to simulate fkickt in the old version of this function, 
% the result is erroneuous (extremely high forces and accelerations)
% this is not due to the parameter value for tendon slack length, because running a dummy simulation first and the simulation for the 
% first tendon slack length (i.e. equal to lceopt) later resolves the issue
% I found out that this is due to a discrepancy in the use of the variable named "lceopt"
% lopt is a global variable defined in line 23 of the old version where it has meters as unit
% however, it was also used in the subfunction "fl" but here it should have been unitless (and equal to 1)
% upon changing the name of lopt in the subfunction "fl" into "lceoptrel", and defining that as 1,
% the results of this simulation change considerably
% it is now the largest tendon slack length that results in the highest angular velocity (i.e. 10*lopt)

% 2: redefining lslack when recomputing forces
% when calculating the forces (Fm1, Fm3, Fm10) in the old version, lslack was not redefined
% therfore, the latest version was used (i.e. 10*lopt)
% this is wrong, because it should be lopt, 3*lopt and 10*lopt for Fm1, Fm3 and Fm10 respectively


% first set the constants, which will be accessible to subfunctions:
%   I m g lopt ksh l1 F1 vmax Fmax rf rcm tact beta At lslack Kse;

I = 0.1832;    % moment of inertia of lower leg (kg-m^2)
m = 4.88;      % mass (kg)
g = 9.81;      % grav constant

lopt = 0.09;   % optimal muscle length in meters
Fmax = 12000;  % max isometric force (N)
vmax = 0.45;   % about 5 lopts/s max shortening vel
rf = 0.033;    % moment arm of quadriceps about knee
rcm = 0.264;   % distance b/w center of mass & joint
tact = 0.010;  % activation time constant
beta = 0.2;    % ratio of activation & deactivation constants
l1 = 0.02;     % strain of tendon's linear region
F1 = 16e6;     % stress for tendon's linear region
Kse = 1.2e9;   % linear modulus for tendon series elasticity
At = 0.000324; % tendon cross-sectional area
ksh = 0.874;   % shape parameter of tendon's toe-in exponential region

options = odeset('events', @eventkick);

% Perform a set of simulations with different tendon lengths
% using fkickt, which computes the state-derivatve based on
% a state defined as [phi; phidot; lm; a], where lm is muscle
% fiber length

% Do a simulation with tendon = 1 * lopt
lslack = 1*lopt;
[t1,y1] = ode45(@fkickt, [0 .5],[pi/2;0; lopt; 0], options);

% Do a simulation with tendon = 3 * lopt
lslack = 3*lopt;
[t3,y3] = ode45(@fkickt, [0 .5],[pi/2;0; lopt; 0], options);

% Do a simulation with tendon = 10 * lopt
lslack = 10*lopt;
[t10,y10] = ode45(@fkickt, [0 .5], [pi/2; 0; lopt; 0], options);

% And one with no tendon whatsoever
[te,ye]=ode45(@fkicke,[0 .5],[pi/2; 0; 0 ], options);

% For no tendon, have to recompute length, velocity, force
le = rf*(pi/2 - ye(:,1)) + lopt;
ve = ye(:,2)*rf/vmax;
ae = ye(:,3);
for i=1:length(le),
	Fe(i) = Fmax * fl(le(i)/lopt) * fv(ve(i)/vmax) * ae(i);
end;

% For other simulations, need to recompute force
lslack = 1*lopt;
lt = rf*(pi/2-y1(:,1)) + lopt - y1(:,3); 
Ft = ftl(lt/lslack)*At;
Fm1 = Ft;                 % muscle fiber force equals tendon force

lslack = 3*lopt;
lt = rf*(pi/2-y3(:,1)) + lopt - y3(:,3); 
Ft = ftl(lt/lslack)*At;
Fm3 = Ft;                 % muscle fiber force equals tendon force

lslack = 10*lopt;
lt = rf*(pi/2-y10(:,1)) + lopt - y10(:,3); 
Ft = ftl(lt/lslack)*At;
Fm10 = Ft;                 % muscle fiber force equals tendon force

figure(1); clf;
% Make a series of plots of the results
subplot(221); % plot angle vs time
plot(te,ye(:,1),t1,y1(:,1),t3,y3(:,1),t10,y10(:,1));  % phi vs. time
title('Phi vs. time'), xlabel('time (s)'), ylabel('Phi (rad/s)');

subplot(222); % plot angular velocity vs time
plot(te,ye(:,2),t1,y1(:,2),t3,y3(:,2),t10,y10(:,2));  % phidot vs. time
title('Phidot vs. time'), xlabel('time (s)'), ylabel('Phidot (rad/s)');

subplot(223); % plot muscle force vs time
plot(te,Fe,t1,Fm1,t3,Fm3,t10,Fm10);       % force vs. time
title('Force vs. time'), xlabel('time (s)'), ylabel('Force (N)');
legend('0 * lopt', '1 * lopt','3 * lopt','10 * lopt');

subplot(224); % plot muscle fiber length vs time
plot(te, le, t1,y1(:,3), t3, y3(:,3), t10,y10(:,3));
title('Muscle fiber length vs time'); xlabel('time (s)'); ylabel('Length (m)')

% In the second figure, plot force-velocity curve and its inverse,
% muscle force-length curve, and tendon stress-strain curve

% PUT YOUR CODE HERE TO PLOT FORCE-VELOCITY CURVE AND ITS INVERSE

% end of main function; subfunctions below

function xdot = fkicke(t,x);
% state derivative for kicking simulation with muscle excitation dynamics
% states: phi, phidot, a where phi is angle of leg, a activation

% The following parameters are assumed to be defined in the workspace:
%   I m g lopt vmax Fmax rf rcm tact beta

phi    = x(1);  % phi and phidot are states for the 
phidot = x(2);  % leg motion, with rigid body dynamics
a      = x(3);  % activation state is governed by a first-order differential equation.

% The input to the model is the excitation u, set here to maximum of 1.
u = 1; % maximum excitation
% Activation dynamics are first-order, with different activation and
% de-activation time constants.
adot = -1/tact * (beta + (1 - beta) * u) * a + 1/tact * u;

l = rf*(pi/2 - phi)/ lopt + 1;  % find normalized length as function of phi
v = rf*phidot/vmax;      % normalized shortening velocity
F = Fmax * fl(l) * fv(v) * a; % muscle force

M = F * rf;  % moment about knee is muscle force times moment arm.
Mg = - m * g * rcm *sin(phi - pi/2); % gravitational moment

phiddot = (M + Mg) / I; % second derivative of phi
xdot = [phidot; phiddot; adot];

end % fkicke

function xdot = fkickt(t,x);
% state derivative for kicking simulation
% states: [phi, phidot, lm, a] where phi is angle of leg, a activation
%         and lm muscle fiber length

% The following parameters are assumed to be defined in the workspace:
%   I m g lopt vmax Fmax rf rcm tact beta

phi    = x(1);  % phi and phidot are states for the 
phidot = x(2);  % leg motion, with rigid body dynamics
lm     = x(3);  % another state tracks muscle fiber length
a      = x(4);  % activation state is governed by a first-order differential equation.

lmt = rf*(pi/2-phi) + lslack + lopt; % length of muscle + tendon together
% where the optimal fiber length corresponds to angle phi = pi/2 if there
% were no tendon, and lslack adds the effect of tendon slack length. 
lt = lmt - lm - lslack; 

% State-derivative for muscle excitation-activation: input u, output a
u = 1; % maximum excitation
adot = -1/tact * (beta + (1 - beta) * u) * a + 1/tact * u;

% State-derivative for muscle force generation
% tendon stress from its force-length curve,
% multiplied by tendon area At to get actual force
Ft = ftl(lt/lslack)*At;
Fm = Ft;                 % muscle fiber force equals tendon force
                         % because there is no pennation in this model
                         
Fiso = Fmax*fl(lm/lopt)*a; % isometric muscle force

lmdot = -fvi(Fm/Fiso)*vmax;

if isnan(lmdot) % set velocity to zero for undefined force values
  lmdot = 0.15;
end

vmt = rf*phidot;         % muscle-tendon shortening velocity

Tm = Fm * rf;            % torque due to muscle
Mgl = - m * g * rcm *sin(phi - pi/2); % gravitational moment

phiddot = (Tm + Mgl) / I; % second derivative of phi
xdot = [phidot; phiddot; lmdot; adot];

end % fkickt

function f = fl(x)
% normalized active force-length curve for muscle fascicles
w = 0.5;
loptrel = 1;  % this is a normalized optimal length

f = 1 - ((x-loptrel)/(w*loptrel)).^2;

f(f<0) = 0; % disallow negative values

end % fl

function f = flp(x)
% normalized passive force-length curve for muscle, where
% input x is strain, l/lopt
% The curve here is cubic above x = 1,
% and zero below 1. 

f = 8*(x-1).^3;

f(x < 1) = 0; % make values zero for lengths below lopt

end % flp


function f = fv(v)
% normalized force-velocity relation
% input is normalized velocity, v/vmax

af = 0.25;  % shape parameter
f = (1 - v)./(1 + v/af);

f(f < 0) = 0; % disallow negative forces

end % fv

function v = fvi(f)
% provides inverse of force-velocity relation:
% normalized force in, normalized velocity out
c1 = -0.18713;
c2 = 0.32094;
c3 = 1.06485;
c4 = 0.1850;
v = -c1*cot(c2*f.^2 + c3*f + c4); % an approximation of the f-v curve

v(f > 1.4) = -0.15; % saturate the f-v curve at 1.4,
% with a velocity of -0.15.
v(f < 0) = 1; % Also prevent shortening faster than vmax

end % fvi

function df = dftdl(x);
% derivative of normalized force-length curve for tendon,
% where input x is strain

% The following parameters should be defined in the workspace:
%   ksh l1 F1 Kse

df(x > l1) = Kse; % linear region, stiffness is linear

% and here's the exponential region
df(x <= l1) = F1/(exp(ksh)-1) * (ksh/l1)*exp(ksh/l1*x(x <= l1));

end % dftdl 

function sigma = ftl(epsilon);
% normalized force-length curve for tendon, where
% the normalization is different from that for muscle:
% input epsilon is strain relative to slack length lslack,
% and the force is actually a stress.
% To convert to actual force, multiply by tendon cross-sectional area.
% Curve has a nonlinear toe-in region up to strain l1, and then is linear.

% ME/BME 646  Art Kuo

% The following parameters should be defined in workspace:
%   ksh l1 F1 Kse

lin = (epsilon > l1);
nonlin = (epsilon <= l1);

sigma(lin) = Kse*(epsilon(lin)-l1) + F1;  % linear region

sigma(nonlin) = F1 / (exp(ksh)-1) * (exp(ksh/l1*epsilon(nonlin)) -1); % exponential

end % ftl

function x = ftli(f);
% inverse of force-length curve for tendon, where
% input is stress, output is strain

% series elastic force-length curve is exponential in toe-in region,
% and then linear beyond a stress-strain (F1, l1)

% The following parameters should be defined in workspace:
%   ksh l1 F1 Kse

toesigma = F1;  % point beyond which tendon is linear
toestrain = l1; % strain at that point

if f > toesigma,   % linear region 
	x = (f - toesigma)/Kse + toestrain;
else           % exponential region
	x = log(f * (exp(ksh)-1) / F1 + 1) * l1/ksh;
end;

end % ftli

function [value, isterminal, direction] = eventkick(t, x)
% returns event function for kicking simulation

% Here is how event checking works:  
% At each integration step, ode45 checks to see if an
% event function passes through zero (in this case, we need
% the function to go through zero when the foot hits the
% ground).  It finds the value of the event function by calling
% eventrw, which is responsible for returning the value of the 
% event function in variable value.  isterminal should contain
% a 1 to signify that the integration should stop (otherwise it
% will keep going after value goes through zero).  Finally,
% direction should specify whether to look for event function
% going through zero with positive or negative slope, or either.

% we want to stop the simulation when phi = pi
phi = x(1);

value = phi - pi;
isterminal = 1;  % tells ode45 to stop when event occurs
direction = 0;  % tells ode45 to look for any crossing

end % eventkick

end % runkickt
