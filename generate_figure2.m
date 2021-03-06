clear all;
close all;

addpath cauchy

Nsamp = 10000;
batch_size = 400;

% Nsamp = 500;
% batch_size = 10;

dt = datestr(now, 'yyyymmdd-HHMMSS'); % TODO -- include time of day

for target_model_i = 1:3

%% anisotropic Gaussian
opts_init = [];

opts_init.BatchSize = batch_size;


% make this 1 for more output
opts_init.Debug = 0;
opts_init.LeapSize = 10;
opts_init.epsilon = 1;
%opts_init.alpha = 0.1;
opts_init.beta = 0.1;
FEVAL_MAX = 5000000
opts_init.funcevals = 0;

if target_model_i == 1
    rng('default'); % make experiments repeatable

    opts_init.DataSize = 2;

    modelname = sprintf('%dD_rough', opts_init.DataSize);
    modeltitle = sprintf('%dD Rough', opts_init.DataSize);

    opts_init.E = @E_rough;
    opts_init.dEdX = @dEdX_rough;
    theta = {100, 5};

    
    opts_init.Xinit = randn( opts_init.DataSize, opts_init.BatchSize )*theta{1};
    opts_init.Xinit(:) = 0;
    %% burnin the samples
    tic();
    disp('burnin');
    opts_burnin = opts_init;
    opts_burnin.Debug = 1;
    opts_burnin.T = Nsamp*3;
    opts_burnin.FlipOnReject = 3;
    [Xloc, statesloc] = rf2vHMC( opts_burnin, [], theta{:});
    opts_init.Xinit = Xloc;
    toc()

    max_shift = 1000;
    
elseif (target_model_i == 2) | (target_model_i == 3)
    rng('default'); % make experiments repeatable

    if target_model_i == 3
        opts_init.DataSize = 100;
    elseif target_model_i == 2
        opts_init.DataSize = 2;
    end

    modelname = sprintf('%dD_Gaussian', opts_init.DataSize);
    modeltitle = sprintf('%dD Anisotropic Gaussian', opts_init.DataSize);

    opts_init.E = @E_gauss;
    opts_init.dEdX = @dEdX_gauss;
    theta = {diag(exp(linspace(log(1e-6), log(1), opts_init.DataSize)))};
    opts_init.Xinit = sqrtm(inv(theta{1}))*randn( opts_init.DataSize, opts_init.BatchSize );
    
    max_shift = 7000;
end

basedir = strcat(modelname, '_', dt, '/');
basedirfig = strcat(basedir, 'figures', '/');
mkdir(basedir);

%Initalize Options
ii = 1;
names{ii} = 'HMC \beta=1';
opts{ii} = opts_init;
opts{ii}.FlipOnReject = 0;
opts{ii}.beta = 1;
%opts{ii}.alpha = 1
%Initialize States
states{ii} = [];
% arrays to keep track of the samples
X{ii} = zeros(opts{ii}.DataSize,Nsamp);
fevals{ii} = [];

ii = ii + 1;
names{ii} = 'LAHMC \beta=1';
opts{ii} = opts_init;
opts{ii}.FlipOnReject = 3;
opts{ii}.beta = 1;
%Initialize States
states{ii} = [];
% arrays to keep track of the samples
X{ii} = zeros(opts{ii}.DataSize,Nsamp);
fevals{ii} = [];

ii = ii + 1;
names{ii} = 'HMC \beta=0.1';
opts{ii} = opts_init;
opts{ii}.FlipOnReject = 0;
%Initialize States
states{ii} = [];
% arrays to keep track of the samples
X{ii} = zeros(opts{ii}.DataSize,Nsamp);
fevals{ii} = [];

ii = ii + 1;
names{ii} = 'LAHMC \beta=0.1';
opts{ii} = opts_init;
opts{ii}.FlipOnReject = 3;
%Initialize States
states{ii} = [];
% arrays to keep track of the samples
X{ii} = zeros(opts{ii}.DataSize,Nsamp);
fevals{ii} = [];

RUN_FLAG=1;
ttt = tic();
ii=1;
    % call the sampling algorithm Nsamp times
    while (ii <=Nsamp && RUN_FLAG == 1)
        for jj = 1:length(names)
                if ii == 1 || states{jj}.funcevals < FEVAL_MAX 
                    [Xloc, statesloc] = rf2vHMC( opts{jj}, states{jj},theta{:});
                    states{jj} = statesloc;
                    if ii > 1                                        
                        X{jj} = cat(3,X{jj}, Xloc);
                    else
                        X{jj} = Xloc;
                    end
                    
                    fevals{jj}(ii,1) = states{jj}.funcevals;
                    assert(opts_init.BatchSize == size(Xloc,2));
                else
                    RUN_FLAG = 0;
                    break;
                end
        end

        %Display + Saving 
        if (mod( ii, 100 ) == 0)
            fprintf('%d / %d in %f sec (%f sec remaining)\r', ii, Nsamp, toc(ttt), toc(ttt)*Nsamp/ii - toc(ttt) );
        end
        if (mod( ii, 5000 ) == 0) || (ii == Nsamp) || RUN_FLAG == 0
            fprintf('%d / %d in %f sec (%f sec remaining)\n', ii, Nsamp, toc(ttt), toc(ttt)*Nsamp/ii - toc(ttt) );

            for jj = 1:length(names)
                fprintf( '\n%s\n', names{jj});
                %disp(states{jj})
                %disp(states{jj}.steps)
                %disp(states{jj}.steps.leap')
                fprintf( 'total %f flip fraction %f L fraction: ', states{jj}.steps.total, states{jj}.steps.flip/states{jj}.steps.total );
                for kk = 1:length(states{jj}.steps.leap)
                    fprintf( '%f ', states{jj}.steps.leap(kk) / states{jj}.steps.total );
                end
                fprintf( '\n' );
                fprintf( 'Last sample L2 %f all sample L2 %f', mean(mean(X{jj}(:,:,end).^2)),  mean(mean(mean(X{jj}.^2))));
            end

            %Calculate average fevals by taking total fevals at this point
            %and dividing it by the number of samples we have acquired
            %fprintf('calculating average fevals');
            for jj=1:length(names)
                avg_fevals{jj}=fevals{jj}(end,1)/size(X{jj},3);
            end
            [h1,h2]=plot_autocorr_samples(X, names,avg_fevals, max_shift);
             %   disp('Autocorr plot completed')
%             h2=plot_fevals(fevals, names);
              %          disp('Fevals plot completed')
            figure(h1);
            title(modeltitle);
            figure(h2);
            title(modeltitle);
            grid on
            drawnow;
            fp = strcat(basedir,'autocorr-fevals.fig');
            saveas(h1,fp);
            fp = strcat(basedir,'autocorr-steps.fig');
            saveas(h2,fp);
            save(strcat(basedir,'alldata.mat'));

            % use the export_fig util from https://sites.google.com/site/oliverwoodford/software/export_fig
            fp = strcat(basedir,'autocorr-fevals.pdf');
                export_fig( fp, h1 );
            try
                export_fig( fp, h1 );
            catch err
                fprintf( '\nExpecting export_fig\n' );
            end
        end
        ii = ii + 1;
    end
ttt = toc(ttt);

end
