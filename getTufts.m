function [tuftsMask, brightMask, thickMask]=getTufts(varargin)
%use like getTufts(thisMask, myImage, maskNoCenter, smoothVessels)

if nargin < 3, error('Not enough input parameters.'), end

thisMask     = varargin{1};
myImage      = varargin{2}; 
maskNoCenter = varargin{3};

if nargin >= 4, smoothVessels = varargin{4}; end


%% Calculate tufts based on intensity only

brightMask = logical(getBrightTufts(myImage, thisMask)).*maskNoCenter;

thickMask  = logical(getThickTufts(myImage, thisMask)).*maskNoCenter;

tuftsMask  = brightMask.*thickMask;

%tuftsMask=bwareaopen(tuftsMask, 20);

if nargin >= 4
    tuftsMask=getTuftQC(myImage, thisMask, maskNoCenter, tuftsMask, smoothVessels);
else
    tuftsMask=getTuftQC(myImage, thisMask, maskNoCenter, tuftsMask);
end




