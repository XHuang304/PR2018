% Main Function to Complete Phase Retrieval of Mid-frequency
%% Parameter Initialization
clear
tic

lambda = 632.8e-6;
k=2*pi/lambda;
pixNum=512;
Dim=5;
%% Phase Groundtruth
%Effective Dimension(non-zero)
EffDim=4;

%Amplitude
pupil=makepupil2017(pixNum,Dim/2,EffDim/2);
% pupil=imread('E:\2018_1\codes\SurfaceDiffraction\zjubw.jpg');
pupil=imresize(pupil,[pixNum,pixNum]);
pupil=im2double(pupil);
%Phase
zerVec=lambda*[0, 0, 0, 0,...
               0, 0, 0, 0.2];%The parameter is corresponding to the parameter of Zemax (Fringe Zernike Phase)
HalfDim = EffDim/2;
NormRadius = HalfDim;
SagTruth=generateZernike(zerVec, pixNum, HalfDim, NormRadius);
PhaseTruth = pupil.*exp(-1j*k*SagTruth);
%% Propagation
f=364;
FocalSag = generateFocal(f,Dim,pixNum);
FocalPhase = exp(1j*k*FocalSag);


% S=3;
% w=1;
% FocalPhase=generateFractalZP(S,w,pixNum,Dim/2);



ComplexToProp = PhaseTruth.*FocalPhase;
% z_prop=[236,252,284,308,567];%系列次焦点
% z_prop=[234,238,250,254,282,286,306,310];
% z_prop=[200,250,310,375,450];
% z_prop=[222,258,296,415,485];%系列亮点
% z_prop=[216,234,248,268,461];%系列暗点
z_prop=[358,370,119,123,331,403];%系列亮点
% z_prop=[358,370,376,352,382,346];%系列亮点


imgNum = numel(z_prop);
Iout = cell(1,imgNum);
% IoutMaxTotal=0;
for i = 1:imgNum
    Iout{i}=abs(ASMDiffgpu(ComplexToProp,z_prop(i),lambda,Dim)).^2;    
    Iout{i}=round(Iout{i});
%     if (max(max(Iout{i}))>IoutMaxTotal)
%         IoutMaxTotal=max(max(Iout{i}));
%     end
end
% Iout=double2grayscale(Iout);

%% Add Noise
% Iout{i}=imnoise(Iout{i},'poisson');
    
PSF=abs(ASMDiffgpu(ComplexToProp,f,lambda,Dim)).^2;
% z_prop=z_prop+(rand(1,imgNum)-0.5)*0.2;%Z shift error
% z_prop=z_prop+0.5;%Z shift error
%% Preprocession of Intensity Data
ImgMeasured = Iout;
% ImgMeasured = Iin;
% for i=1:numel(IoutExtended)
%     IoutExtended{i}=padarray(Iout{i},[(pixNum-subImgSizeRow)/2,(pixNum-subImgSizeRow)/2],min(min(Iout{i})),'both');
% end
% ImgMeasured = IoutExtended;
%% Cells Initialization for Phase Retrieval
E_zeros = cell(1,imgNum);
E_ones = cell(1,imgNum);
for ii=1:imgNum
    E_zeros{ii}=zeros(pixNum,pixNum);
    E_ones{ii}=ones(pixNum,pixNum);
end
E_Diff = E_zeros;
E_Diff_sum = E_zeros;
E_Diff_temp = E_zeros;
E_Update = E_zeros;

CostFuncTemp = zeros(1,imgNum);
%% Initial Figure
figNum=1;
figure(figNum)   % create figure for displaying the result through out the iteration
% colormap(gray)
subplot(2,2,1)
% imagesc(unwrap_phase(angle(PhaseTruth)))
imagesc(k*SagTruth.*pupil)
title('Phase Groundtruth');
axis off
axis equal
%% Initial Solve

    
% Radii=300;
% Amp=lambda/8;
% nxa=30;%ripple number across the aperture
% p=makepupil2017(pixNum,Dim/2,Dim/2);
% [sphereMidReal,rippleReal] = mixSurfaceFunc(Radii,Dim,pixNum,Amp,nxa);
% sphereMidReal=Radii-sqrt(Radii^2-(Dim/2)^2)- sphereMidReal;
% f=Radii/2;

%     %% Initializing to Ideal Lens
%     f_Init=Inf;
%     FocalSag_Init = generateFocal(f_Init,Dim,pixNum);
%     FocalPhase_Init = exp(1j*k*FocalSag_Init);
    %% Initializing to Zernike Surface
    zerVec_Init=lambda*[0, 0, 0, 0,...
                   0, 0, 0, 0];%The parameter is corresponding to the parameter of Zemax (Fringe Zernike Phase)

    Sag_Init=generateZernike(zerVec_Init, pixNum, HalfDim, NormRadius);
%     Phase_Init = pupil.*exp(-1j*k*Sag_Init);
Phase_Init = exp(-1j*k*Sag_Init);


% Pupil_Init=makepupil2017(pixNum,Dim/2,EffDim/2);
Pupil_Init=ones(pixNum,pixNum);
E_Obj_Init = Phase_Init.*Pupil_Init;
E_Obj_Result = E_Obj_Init.*FocalPhase;
%% Iteration Settings
iterNum=30;	% The number of iterations to be calculated
CostFunc = ones(1,iterNum);
E_theta_Gradient_Last_Iter=cell(1,imgNum);
for ii=1:imgNum
    E_theta_Gradient_Last_Iter{ii}=ones(pixNum,pixNum)/pixNum/pixNum;%the sum equals to one
end
E_theta_Gradient = E_zeros;
Dq_Last_Iter=E_zeros;
Dq=E_zeros;

p=1; % The counter of the loop 
CostFuncTemp(1)=norm((abs(ASMDiffgpu(E_Obj_Result,z_prop(1),lambda,Dim))-sqrt(ImgMeasured{1})),2);
CostFunc(p)=sum(CostFuncTemp);
disp([num2str(CostFunc(p)),'(',num2str(p),')']);
while p < iterNum&&(CostFunc(p)>1e-4)	% The number of iterations that will be
                                    % calculated (This method converge within
                                    % approximately 10-50 iterations).
    p = p+1;      % Increase the counter        
%     z_prop=z_prop+(rand(1,imgNum)-0.5)*0.2;%Z shift error
% 2006 Nonlinear
%% Procedure 1
    E_Diff_f = ASMDiffgpu(E_Obj_Result,f,lambda,Dim);
    E_Diff_f(E_Diff_f==0)=eps;
%% Procedure 2 3
    E_Diff{1} = ASMDiffgpu(E_Diff_f,z_prop(1)-f,lambda,Dim);
    E_Diff_sum=E_zeros;
    for imgCount = 1:imgNum        
        % Master plane
        E_Diff{imgCount} = sqrt(ImgMeasured{imgCount}).*(E_Diff{imgCount}./abs(E_Diff{imgCount}));
        % Slaves planes
        for imgCountTemp = 1:imgNum
            if imgCountTemp~=imgCount
                E_Diff_temp{imgCountTemp}=ASMDiffgpu(E_Diff{imgCount},z_prop(imgCountTemp)-z_prop(imgCount),lambda,Dim);
                E_Diff_temp{imgCountTemp} = sqrt(ImgMeasured{imgCountTemp}).*(E_Diff_temp{imgCountTemp}./abs(E_Diff_temp{imgCountTemp}))-E_Diff_temp{imgCountTemp};
                E_Diff_sum{imgCount}=E_Diff_sum{imgCount}+conj(ASMDiffgpu(E_Diff_temp{imgCountTemp},-(z_prop(imgCountTemp)-z_prop(imgCount)),lambda,Dim));
            end
        end
%         E_Diff{imgCount}=E_Diff_sum{imgCount}/(imgNum-1);
        E_Diff{imgCount}=sqrt(ImgMeasured{imgCount}).*(E_Diff{imgCount}./abs(E_Diff{imgCount}));
        E_Diff{imgCount}(isnan(E_Diff{imgCount}))=0;
        
        E_theta_Gradient{imgCount}=2*imag(E_Diff{imgCount}.*E_Diff_sum{imgCount});
        
        Dq{imgCount}=-1/2*E_theta_Gradient{imgCount}+(sum(sum(E_theta_Gradient{imgCount}.^2))/sum(sum(E_theta_Gradient_Last_Iter{imgCount}.^2)))*Dq_Last_Iter{imgCount};
        E_theta_Gradient_Last_Iter{imgCount}=E_theta_Gradient{imgCount};
        Dq_Last_Iter{imgCount}=Dq{imgCount};
%         E_Obj_Result=real(E_Obj_Result)+1j*(imag(E_Obj_Result)-0.00001*Dq);
        

        
        if imgCount<imgNum
%             E_Update{imgCount}=real(E_Diff{imgCount})+1j*(imag(E_Diff{imgCount})-0.000*Dq{imgCount});
            E_Update{imgCount}=abs(E_Diff{imgCount}).*exp(1j*(angle(E_Diff{imgCount})+0.0003*Dq{imgCount}));
%             E_Update{imgCount}=abs(E_Diff{imgCount}).*exp(1j*(angle(E_Diff{imgCount})));
            E_Diff{imgCount+1}=ASMDiffgpu(E_Update{imgCount},z_prop(imgCount+1)-z_prop(imgCount),lambda,Dim);
        else   
            
    % Inverse Diffraction
            E_Obj_Result = ASMDiffgpu(E_Diff{imgCount},-z_prop(imgCount),lambda,Dim);
        
            
        end
    % Statistics
%     CostFuncTemp(imgCount)=norm((abs(E_Diff{imgCount})-sqrt(ImgMeasured{imgCount})),2);
    end 

    %% Synthesize New Object Wavefront
    
    Phase_Obj_Result = angle(E_Obj_Result);
%     Amp_Obj_Result = abs(E_Obj_Result);
    Amp_Obj_Result = real(E_Obj_Result./exp(1j*angle(E_Obj_Result)));
    Amp_Obj_Result(Amp_Obj_Result<1e-5)=0;
    E_Obj_Result = Amp_Obj_Result.*exp(1j*Phase_Obj_Result);
%     Phase_Obj_Result = angle(E_Obj_Result).*pupil;
%     Amp_Obj_Result = abs(E_Obj_Result).*pupil;
    
    E_Diff_test = ASMDiffgpu(E_Obj_Result,z_prop(1),lambda,Dim);
%     for ii=1:imgNum;CostFuncTemp(ii)=norm((abs(E_Diff{ii})-sqrt(ImgMeasured{ii})),2);end;
    
    CostFuncTemp(1)=norm((abs(E_Diff_test)-sqrt(ImgMeasured{1})),2);
    CostFunc(p)=sum(CostFuncTemp);
%     disp([num2str(CostFunc(p)),'(',num2str(p),')']);
    
%% Plot Current Results
    figure(figNum)    
    subplot(2,2,2)								% Plot the phase levels
    imagesc(unwrap((Phase_Obj_Result-angle(FocalPhase)).*Amp_Obj_Result));
    title('Recovered Phase');
    axis equal
    axis off
    
    figure(figNum)
    subplot(2,2,3)								% Plot the phase levels
    imagesc(Amp_Obj_Result);
    title('Recovered Amplitude');
    axis equal
    axis off

    figure(figNum)
    subplot(2,2,4)					% Calculate and plot the intensity quotient as a 
    plot((1:p),CostFunc(1:p),'b.-')	    % function of the number of iterations
    axis([1 iterNum -0.01 max(CostFunc)])
    xlabel('Iteration Times')
    ylabel('Least Square Error')    
    title('Lease Square Error Curve');
    drawnow
    
    
    
end
figure(figNum)    
subplot(2,2,2)								% Plot the phase levels
imagesc(unwrap_phase((Phase_Obj_Result-angle(FocalPhase)).*Amp_Obj_Result));
title('Recovered Phase');
axis equal
axis off
    
toc
final=CostFunc(p)

% RMS=sqrt(sum(sum((unwrap((angle(E_Obj_Result)-angle(FocalPhase)).*(abs(E_Obj_Result)>1e-6)))-unwrap(angle(PhaseTruth))).^2))/pixNum^2;

function Ig=double2grayscale(Iin)
    %% Gray Scale
    GrayScale=4096;
    if iscell(Iin)
        imgNum=length(Iin);
        IoutMaxTotal=0;
        for i = 1:imgNum
            if max(max(Iin{i}))>IoutMaxTotal
                IoutMaxTotal=max(max(Iin{i}));
            end
        end
        for i = 1:imgNum
            Iin{i}=round(Iin{i}/IoutMaxTotal*GrayScale);
        end
    else
        Iin=round(Iin/max(max(Iin))*GrayScale);
    end
    Ig=Iin;
end
