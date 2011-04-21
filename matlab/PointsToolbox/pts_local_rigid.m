function yi = pts_local_rigid(x, y, xi, idx)
% PTS_LOCAL_RIGID  Non-rigid transformation that is locally rigid between
% two sets of points with known correspondence
%
%
% This function is useful to warp points when we want distances within
% local neighbourhoods of the points to remain constant.
%
% This function is not diffeormorphic, and in general presents folding
% (i.e. overlapping of warped points).
%
% This function does not suffer from collinearity limitations as other
% warps do (e.g. thin-plate spline, elastic body spline, volume spline,
% affine transformation), so it is useful to e.g. straighten a bent artery.
%
% YI = PTS_LOCAL_RIGID(X, Y, XI, IDX)
%
%   X, Y are matrices of the same size, where each row is a point, such
%   that the transformation maps X(i, :) -> Y(i, :).
%
%   XI is a matrix of points that we want to transform. Point in XI must
%   have the same dimension as X and Y, but XI can have a different number
%   of rows.
%
%   IDX is a vector that defines the local neighbourhoods. It has one
%   element per point in XI. For example, IDX(3)==7 means that point 
%   XI(3, :) belongs to the local neighbourhood of X(7, :).

% Authors: Ramon Casero <rcasero@gmail.com>, Vicente Grau
% Copyright © 2011 University of Oxford
% Version: v0.1.0
% 
% University of Oxford means the Chancellor, Masters and Scholars of
% the University of Oxford, having an administrative office at
% Wellington Square, Oxford OX1 2JD, UK. 
%
% This file is part of Gerardus.
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details. The offer of this
% program under the terms of the License is subject to the License
% being interpreted in accordance with English Law and subject to any
% action against the University of Oxford being under the jurisdiction
% of the English Courts.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.

% check arguments
error(nargchk(4, 4, nargin, 'struct'));
error(nargoutchk(0, 1, nargout, 'struct'));

% Because this code was developed to straighten the voxels of a cardiac
% vessel branch segmentation using the central line or skeleton to define
% the warp, we are using that nomenclature in the comments below

% point dimensionality
dim = size(x, 2);
if (dim ~= size(y, 2) || dim ~= size(xi, 2))
    error('Point in X, Y and XI must have the same dimension (number of columns)')
end

% number of skeleton points
n = size(x, 1);
if (n ~= size(y, 1))
    error('X and Y must have the same number of points (rows)')
end

% number of branch points
N = size(xi, 1);
if (length(idx) ~= N)
    error('IDX must have one element per point in XI (per row)')
end

% compute rigid transformation to match the first 2 skeleton points
[~, ~, t] = procrustes(y(1:2, :), x(1:2, :), 'Scaling', false);

% map the branch points and the skeleton points onto the straightened
% skeleton
yi = xi * t.T + repmat(t.c(1, :), N, 1);
x = x * t.T + repmat(t.c(1, :), n, 1);

% create a vector saying which voxels have been straightened already
% we consider that branch points that belong to the first and second
% skeleton points have been straightened
todo = ~(idx == 1 | idx == 2);

% loop skeleton points
for I = 3:n
    % compute rigid transformation to match match the previous and current
    % skeleton points
    [~, ~, t] = procrustes(y(I-1:I, :), x(I-1:I, :), 'Scaling', false);
    
    % compute unit vectors between two points of the straight skeleton and
    % of the bent skeleton. These two points are the current and previous
    % skeleton points
    vx = x(I, :) - x(I-1, :);
    vx = vx / norm(vx);
    vy = y(I, :) - y(I-1, :);
    vy = vy / norm(vy);
    
    % compute angle from bent skeleton to straight skeleton
    theta = acos(dot(vy, vx));
    
    % compute normalized axis of rotation (note the order of vx, vy,
    % so that the rotation is correct)
    ax = cross(vy, vx);
    ax = ax / norm(ax);
    if any(isnan(ax))
        ax = [0 0 0];
    end
    
    % compute rotation matrix. We ignore the rotation matrix computed by
    % procrustes because there is an infinite number of solutions for it
    % due to rotational symmetry around the x-axis. With this way of
    % computing the rotation matrix, we make sure that the vessel points
    % are moving parallel to the plane defined by the 2 bent skeleton
    % voxels and the 2 straight skeleton voxels
    t.T = vrrotvec2mat([ax theta]);
    
    % straighten the points that haven't been straightened yet
    yi(todo, :) = yi(todo, :) * t.T + repmat(t.c(1, :), nnz(todo), 1);
    x(I:end, :) = x(I:end, :) * t.T + repmat(t.c(1, :), n-I+1, 1);
    
    % branch points that belong to the current skeleton point don't need to
    % be straightened anymore
    todo(idx == I) = false;

    % DEBUG
%     % plot points (2D)
%     hold off
%     plot(yi(:, 1), yi(:, 2), '.')
%     hold on
%     plot(x(:, 1), x(:, 2), 'r.')
%     plot(x(I, 1), x(I, 2), 'ko')
%     axis equal
%     pause
    
%     % plot points (3D)
%     hold off
%     plot3(yi(:, 1), yi(:, 2), yi(:, 3), '.')
%     hold on
%     plot3(x(:, 1), x(:, 2), x(:, 3), 'r.')
%     plot3(x(I, 1), x(I, 2), x(I, 3), 'ko')
%     axis equal
%     pause

end
