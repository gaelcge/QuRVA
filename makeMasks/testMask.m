dname = '../';

fls = dir(fullfile(dname,'*.jpg'));
fls = {fls(:).name};

for k = 1:numel(fls)
    
    im = imread(fullfile(dname,fls{k}));
    
    if numel(size(im)) == 3, im = rgb2gray(im); end
    
    im(im(:) >= 0.99 * max(im(:))) = 0;
    
    tic; msk = getMask(im);toc
    
    border = imdilate(bwperim(msk),strel('disk',round(min(size(msk)) / 500)));
    
    imResult = imoverlay(im,border,'m');
    
    imwrite(imResult,fullfile(dname,'support',[fls{k} '_support.jpg']))
    
%     figure(1); imshow(imResult,[])
    
end