%
%  Attentional Correlation Filter Network for Adaptive Visual Tracking
%
%  Jongwon Choi, 2017
%  https://sites.google.com/site/jwchoivision/  
% 
%  MATLAB code for correlation filter network
%  When you use this code for your research, please refer the below references.
%  You can't use this code for any commercial purpose without author's
%  agreement.
%  If you have any question or comment, please contact to
%  jwchoi.pil@gmail.com.
%  
% 
%
%  Reference:
%  [1] J. Choi, et al., "Attentional Correlation Filter Network for Adaptive Visual Tracking", CVPR2017
%  [2] J. Choi, et al., "Visual Tracking Using Attention-Modulated Disintegration and Integration", CVPR2016


function output = filter_validation(input, attention_vec, im, pos, window_sz, x_scale, y_scale, init_window_sz, hierarchy_vector, n_hierarchy, rf, cos_window2, salWeight, cell_size, features, interp_factor, kernel, yf, yf_cell, lambda, b_occ, padding)

subwindow = get_subwindow(im, pos, floor([window_sz(1)+cell_size*y_scale, window_sz(2)+cell_size*x_scale]));
[patch, ws, idxs] = imresize_mem(subwindow, init_window_sz, [], []);
if(size(patch,3)>1)
    patch_gray = rgb2gray(patch);
else
    patch_gray = patch;
end
z_hog = get_features(patch_gray, features, cell_size, []);

[feature, ws2, idxs2] = imresize_mem(patch, [size(z_hog,1), size(z_hog,2)], [], []);
feature = single(feature)/255;
if(size(feature,3) > 1)
    feature = cat(3, feature, RGB2Lab(feature) / 255 + 0.5);
else
    feature = gray_feature(feature);
end
z_color = feature;

if(salWeight == 0)
    saliencyMap = cos_window2;
else
    stS = evaluate_stSaliency(z_color, rf);
    stS_mask = ones(size(stS));
    if((pos(1)-window_sz(1)/(1+padding)/2) < 1)
        stS_mask( ((pos(1)-window_sz(1)/2+linspace(1,window_sz(1),size(stS,1))) < 1), : ) = 0;
    end
    if((pos(1)+window_sz(1)/(1+padding)/2) > size(im,1))
        stS_mask( ((pos(1)-window_sz(1)/2+linspace(1,window_sz(1),size(stS,1))) > size(im,1)), : ) = 0;
    end
    if((pos(2)-window_sz(2)/(1+padding)/2) < 1)
        stS_mask( :, ((pos(2)-window_sz(2)/2+linspace(1,window_sz(2),size(stS,2))) < 1) ) = 0;
    end
    if((pos(2)-window_sz(2)/(1+padding)/2) > size(im,2))
        stS_mask( :, ((pos(2)-window_sz(2)/2+linspace(1,window_sz(2),size(stS,2))) > size(im,2)) ) = 0;
    end
    
    stS = stS .* cos_window2 .* stS_mask;
    saliencyMap = (1-salWeight)*cos_window2 + salWeight*stS;
end

%attentional feature estimation
zf_color = fft2(bsxfun(@times, z_color, saliencyMap));
zf_hog = fft2(bsxfun(@times, z_hog, saliencyMap));


output = input;
[output.xScale] = deal(x_scale);
[output.yScale] = deal(y_scale);

[output.ws] = deal(ws);
[output.idxs] = deal(idxs);
[output.ws2] = deal(ws2);
[output.idxs2] = deal(idxs2);

for kk = 1:n_hierarchy
    
    for ii = 1:size(input,1)
        
        if(input(ii,1,hierarchy_vector(kk)).check > 0)

            if(attention_vec(ii, 1, kk) == 1)

                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %Forward module
                switch input(ii,1,hierarchy_vector(kk)).kernelType
                    case 'gaussian',
                        if strcmp(input(ii,1,hierarchy_vector(kk)).featureType, 'hog')
                            kzf = gaussian_correlation(zf_hog, input(ii,1,hierarchy_vector(kk)).model_xf, kernel.sigma);
                        else
                            kzf = gaussian_correlation(zf_color, input(ii,1,hierarchy_vector(kk)).model_xf, kernel.sigma);
                        end
                    case 'polynomial',
                        if strcmp(input(ii,1,hierarchy_vector(kk)).featureType, 'hog')
                            kzf = polynomial_correlation(zf_hog, input(ii,1,hierarchy_vector(kk)).model_xf, kernel.poly_a, kernel.poly_b);
                        else
                            kzf = polynomial_correlation(zf_color, input(ii,1,hierarchy_vector(kk)).model_xf, kernel.poly_a, kernel.poly_b);
                        end
                    case 'linear',
                        if strcmp(input(ii,1,hierarchy_vector(kk)).featureType, 'hog')
                            kzf = linear_correlation(zf_hog, input(ii,1,hierarchy_vector(kk)).model_xf);
                        else
                            kzf = linear_correlation(zf_color, input(ii,1,hierarchy_vector(kk)).model_xf);
                        end
                end
                response = yf .* input(ii,1,hierarchy_vector(kk)).model_dalphaf .* kzf;
                response = real(ifft2(response));

                [vert_delta, horiz_delta] = find(response == max(response(:)), 1);
                                
                output(ii,1,hierarchy_vector(kk)).confidence = exp(-sum(sum((response - yf_cell{vert_delta, horiz_delta}).^2)));
                output(ii,1,hierarchy_vector(kk)).response = response;
                
                %Delta interpolation!
                weight_sum = [0,0];
                res_sum = 0;
                for i = -2:2
                    for j = -2:2
                       
                            a = vert_delta+i;
                            b = horiz_delta+j;

                            if(a < 1)
                                a = size(response,1)+a;
                            end
                            if(b < 1)
                                b = size(response,2)+b;
                            end
                            if(a > size(response,1))
                                a = a-size(response,1);
                            end
                            if(b > size(response,2))
                                b = b-size(response,2);
                            end

                            res = response(a,b);
                            weight_sum = weight_sum + res*[i,j];
                            res_sum = res_sum + res;
                            
%                         end
                        
                    end
                end
                vert_delta = vert_delta + weight_sum(1) / res_sum;
                horiz_delta = horiz_delta + weight_sum(2) / res_sum;

                if vert_delta > size(yf,1) / 2,  %wrap around to negative half-space of vertical axis
                    vert_delta = vert_delta - size(yf,1);
                end
                if horiz_delta > size(yf,2) / 2,  %same for horizontal axis
                    horiz_delta = horiz_delta - size(yf,2);
                end
                vert_delta2 = (vert_delta-1) / init_window_sz(1) * (window_sz(1) + cell_size*y_scale);
                horiz_delta2 = (horiz_delta-1) / init_window_sz(2) * (window_sz(2) + cell_size*x_scale);

                forward_pos = pos + ...
                    round((cell_size * [vert_delta2, horiz_delta2]));
                output(ii,1,hierarchy_vector(kk)).forward_pos = forward_pos;
                
            end
            
        end
        
    end
end