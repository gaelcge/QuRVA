% *************************************************************************
% Parameters (optional): If not included it uses the default behaviour
% varargin{1} = masterFolder (string with folder path) default: config.ini
% varargin{2} = myFiles (particular file names in a cellarray): default: files in master folder
% varargin{3} = model (object containint QDA object): default model.mat in current folder
% varargin{3} = doConsensusImages : default false
% *************************************************************************

function processFolder(varargin)

try
    
    disp('Initialization (wait).')
    hWbar = waitbar(0,'Initialization (wait).',...
        'CreateCancelBtn',...
        'setappdata(gcbf,''stop'',1)',...
        'WindowStyle','modal',...
        'Name','QuRVA');
    
    setappdata(hWbar,'stop',0);
    
    cleaning.wWbar = onCleanup(@()delete(hWbar));
    
    movegui(hWbar,'northwest')
    
    % Settings and folders
    readConfig
    
    if nargin > 0, masterFolder=varargin{1};
    else,          masterFolder = uigetdir('', 'Select folder'); end
    
    if nargin > 1, myFiles = varargin{2};
    else,          myFiles = getImageList(masterFolder); end
    
    if nargin > 2, model = varargin{3};
    else,          load('model.mat','model'); end
    
    if nargin > 3, doConsensusImages = varargin{4};
    else,          doConsensusImages = false; end
    
    logDir = masterFolder;    
    
    disp(logit(logDir, 'Creating folders . . .'))
    waitbar(0,hWbar,'Creating folders . . .')
    
    warning('Off')
    mkdir(masterFolder, 'Masks')
    mkdir(masterFolder, 'TuftImages')
    mkdir(masterFolder, 'TuftNumbers')
    mkdir(masterFolder, 'VasculatureImages')
    mkdir(masterFolder, 'VasculatureNumbers')
    mkdir(masterFolder, 'ONCenter')
    mkdir(masterFolder, 'Reports')
    warning('On')
    
    maxRadius = getDiameterFromInput;
    
    % Prepare mask and Center
    disp(logit(logDir, 'Creating Masks and centers . . .'))
    waitbar(0,hWbar,'Creating Masks and centers . . .')
    computeMaskAndCenter(masterFolder, myFiles,computeMaskAndCenterAutomatically, hWbar);
    
    myFiles = myFiles(:);
    
    outFlatMountArea     = zeros(size(myFiles));
    outBranchingPoints   = outFlatMountArea;
    outAVascularArea     = outFlatMountArea;
    outVasculatureLength = outFlatMountArea;
    outTuftArea          = outFlatMountArea;
    outTuftNumber        = outFlatMountArea;
    outEndPoints         = outFlatMountArea;
    
    if getappdata(hWbar,'stop') == 1, return, end
    
    disp(logit(logDir, 'Processing started . . .'))
    waitbar(0,hWbar,'Processing started . . .')
    
    % Do loop
    for it=1:numel(myFiles)
        try
            %Check stop signal
            if getappdata(hWbar,'stop') == 1, return, end
            
            % Verbose current Image
            disp(logit(logDir, ['Processing: ' myFiles{it}]))
            waitbar((it-1)/numel(myFiles),hWbar,sprintf('%0.0f%% Processed. Starting %s.',100*(it-1)/numel(myFiles),myFiles{it}))
            
            % Read image
            thisImage=imread(fullfile(masterFolder, myFiles{it}));
            redImage=thisImage(:,:,1);
            
            % Make 8 bits
            if strcmp(class(redImage), 'uint16')
                redImage=uint8(double(redImage)/65535*255);
            end
            
            % Load Mask and Center
            load(fullfile(masterFolder, 'Masks',    [myFiles{it} '.mat']), 'thisMask');
            load(fullfile(masterFolder, 'ONCenter', [myFiles{it} '.mat']), 'thisONCenter');
            
            [maskStats, maskNoCenter] = processMask(thisMask, redImage, thisONCenter, maxRadius);
            
            [redImage, scaleFactor] = resetScale(redImage);
            thisMask     = resetScale(thisMask);
            maskNoCenter = resetScale(maskNoCenter);
            thisONCenter = thisONCenter/scaleFactor;
            retinaDiam   = computeRetinaSize(thisMask, thisONCenter);
            
            % For Results
            outFlatMountArea(it)     = sum(thisMask(:));
            
            if doVasculature
                
                disp(logit(logDir, '  Computing vasculature . . .'))
                if getappdata(hWbar,'stop') == 1, return, end
                waitbar((it-1)/numel(myFiles),hWbar,sprintf('%0.0f%% Processed. Computing vasculature of %s.',100*(it-1)/numel(myFiles),myFiles{it}))
                
                [vesselSkelMask, brchPts, smoothVessels, endPts] = getVacularNetwork(thisMask, redImage);
                aVascZone = getAvacularZone(thisMask, vesselSkelMask, retinaDiam, thisONCenter);
                
                % Make a nice image
                if doSaveImages
                    
                    leftHalf=cat(3, redImage, redImage, redImage);
                    rightHalf=makeNiceVascularImage(redImage, aVascZone, vesselSkelMask, brchPts);
                    
                    leftHalf=imcrop(leftHalf, maskStats.BoundingBox/scaleFactor);
                    rightHalf=imcrop(rightHalf, maskStats.BoundingBox/scaleFactor);
                    
                    imwrite([leftHalf rightHalf], fullfile(masterFolder, 'VasculatureImages', myFiles{it}), 'JPG')
                    
                end % doSaveImages
                
                save(fullfile(masterFolder, 'VasculatureNumbers', [myFiles{it},'.mat']),...
                    'vesselSkelMask', 'brchPts', 'aVascZone', 'endPts','smoothVessels');
                
                disp(logit(logDir, '  Vasculature done.'))
                
                % For Results
                outBranchingPoints(it)   = sum(brchPts(:));
                outAVascularArea(it)     = sum(aVascZone(:));
                outVasculatureLength(it) = sum(vesselSkelMask(:));
                outEndPoints(it)         = sum(endPts(:));
                
            end % doVasculature
            
            % Analyze tufts
            if doTufts
                
                disp(logit(logDir, '  Computing tufts . . .'))
                if getappdata(hWbar,'stop') == 1, return, end
                waitbar((it-1)/numel(myFiles),hWbar,sprintf('%0.0f%% Processed. Computing tufts of %s.',100*(it-1)/numel(myFiles),myFiles{it}))
                
                tuftsMask = getTufts(redImage, maskNoCenter, thisMask, thisONCenter, retinaDiam, model);
                %                 tuftsMask = getTufts(overSaturate(redImage), maskNoCenter, thisMask, thisONCenter, retinaDiam, model);
                
                % *** Save Tuft Images ***
                if doSaveImages
                    
                    adjustedImage = uint8(overSaturate(redImage) * 255);
                    cropRect      = maskStats.BoundingBox/scaleFactor;
                    
                    % Build image top quadrants
                    quadNW = cat(3, uint8(tuftsMask) .* adjustedImage,adjustedImage, adjustedImage);
                    quadNE = cat(3, adjustedImage, adjustedImage, adjustedImage);
                    
                    quadNW = imoverlay(quadNW,imdilate(bwperim(thisMask & maskNoCenter),strel('disk',3)),'m');
                    
                    quadNW = imcrop(quadNW, cropRect);
                    quadNE = imcrop(quadNE, cropRect);
                    
                    resultImage = [quadNW quadNE];
                    
                    % Add consensus panel
                    if doConsensusImages
                        
                        % Create Image for all voters
                        load(fullfile(masterFolder,'TuftConsensusMasks',[myFiles{it} '.mat']),'allMasks')
                        consensusMask = sum(allMasks, 3) >= consensus.reqVotes;
                        
                        votesImageRed   = 0.5 * adjustedImage;
                        votesImageGreen = 0.5 * adjustedImage;
                        votesImageBlue  = 0.5 * adjustedImage;
                        
                        myColors = prism;
                        
                        for ii=1:size(allMasks, 3)
                            thisMask = resetScale(allMasks(:,:,ii));
                            thisObserver = bwperim(thisMask);
                            votesImageRed(  thisObserver~=0) = uint8(myColors(ii,1) * 255);
                            votesImageGreen(thisObserver~=0) = uint8(myColors(ii,2) * 255);
                            votesImageBlue( thisObserver~=0) = uint8(myColors(ii,3) * 255);
                        end
                        
                        consensusMask = resetScale(consensusMask);
                        
                        % Build image bottom quadrants
                        quadSW = imoverlay(imoverlay(imoverlay(adjustedImage, uint8(tuftsMask-consensusMask>0)*255, 'm'), uint8(tuftsMask-consensusMask<0)*255, 'y'), uint8(and(consensusMask, tuftsMask))*255, 'g');
                        quadSE = cat(3, resetScale(votesImageRed), resetScale(votesImageGreen), resetScale(votesImageBlue));
                        
                        % Crop bottom quadrants
                        quadSW = imcrop(quadSW, cropRect);
                        quadSE = imcrop(quadSE, cropRect);
                        
                        resultImage = [resultImage; quadSW quadSE];
                        
                    end
                    
                    % Save image
                    imwrite(resultImage, fullfile(masterFolder, 'TuftImages', myFiles{it}), 'JPG')
                    
                end
                
                save(fullfile(masterFolder, 'TuftNumbers', [myFiles{it} '.mat']), 'tuftsMask');
                
                % For Results
                outTuftArea(it)          = sum(tuftsMask(:));
                outTuftNumber(it)        = max(max(bwlabel(tuftsMask)));
                
                disp(logit(logDir, '  Tufts done.'))
                
            end % doTufts
            
            disp(logit(logDir, ['Done: ' myFiles{it}]))
            if getappdata(hWbar,'stop') == 1, return, end
            waitbar((it-1)/numel(myFiles),hWbar,sprintf('%0.0f%% Processed. Done %s.',100*(it-1)/numel(myFiles),myFiles{it}))
            
        catch loopException
            disp(logit(logDir, ['Error in processFolder(image ' myFiles{it} '). Message: ' loopException.message buildCallStack(loopException)]))
            waitbar((it-1)/numel(myFiles),hWbar,sprintf('%0.0f%% Processed. Error on %s.',100*(it-1)/numel(myFiles),myFiles{it}))
            continue
        end
        
    end
    
    waitbar(1,hWbar,'Saving results . . .')
    
    resultsTable                   = table;
    resultsTable.FileName          = myFiles;
    resultsTable.FlatMountArea     = outFlatMountArea;
    resultsTable.BranchingPoints   = outBranchingPoints;
    resultsTable.AVascularArea     = outAVascularArea;
    resultsTable.VasculatureLength = outVasculatureLength;
    resultsTable.TuftArea          = outTuftArea;
    resultsTable.TuftNumber        = outTuftNumber;
    resultsTable.EndPoints         = outEndPoints;
    
    add2Table(masterFolder,resultsTable);
    
catch globalException
    disp(logit(logDir, ['Error in processFolder. Message: ' globalException.message buildCallStack(globalException)]))
end

msgbox('Done','QuRVA','modal')

end


