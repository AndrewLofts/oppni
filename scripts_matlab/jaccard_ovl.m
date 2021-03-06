function J_mat = jaccard_ovl(colMat, correction)
%
% J_mat = jaccard_ovl(colMat, correction)
%
% ------------------------------------------------------------------------%
% Authors: Nathan Churchill, University of Toronto
%          email: nathan.churchill@rotman.baycrest.on.ca
%          Babak Afshin-Pour, Rotman reseach institute
%          email: bafshinpour@research.baycrest.org
% ------------------------------------------------------------------------%
% CODE_VERSION = '$Revision: 158 $';
% CODE_DATE    = '$Date: 2014-12-02 18:11:11 -0500 (Tue, 02 Dec 2014) $';
% ------------------------------------------------------------------------%

% P=#variables per vector, N=#sample vectors
[P N] = size( colMat );
% initialize conjunction matrix
J_mat = eye(N);
% fill in off-diagonals
for( i= 1:(N-1))
for( j=(i+1):N ) 

    x   = double( colMat(:,i) );
    y   = double( colMat(:,j) );

    % jaccard overlap
    warning off;
    ovl = sum( x.*y ) ./ sum( double((x+y)>0) );
    warning on;
    
    if(correction>0) 
    % adjustment factor: 
    adj = ( sum(x).^2 + sum(y).^2 )./2./length(x)./sum( double((x+y)>0) );
    % then adjust the statistic
    ovl = ovl - adj;
    end
    
    J_mat(i,j) = ovl;
    J_mat(j,i) = ovl;
end
end

% account for 0/0 overlaps
J_mat(~isfinite(J_mat)) = 0;
