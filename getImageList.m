function myFiles = getImageList(masterFolder)
% Gather filenames of images in tif and jpg format, and returns a cell
% array of string

% *************************************************************************
% Copyright (C) 2018 Javier Mazzaferri and Santiago Costantino 
% <javier.mazzaferri@gmail.com>
% <santiago.costantino@umontreal.ca>
% Hopital Maisonneuve-Rosemont, 
% Centre de Recherche
% www.biophotonics.ca
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.
% *************************************************************************

myFiles = dir(fullfile(masterFolder, '*.jpg'));
myFiles = [myFiles; dir(fullfile(masterFolder, '*.tif'))];
myFiles = {myFiles(:).name};

end