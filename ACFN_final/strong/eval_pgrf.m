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


function result = eval_pgrf(input, rf)

feature = reshape(input, size(input,1)*size(input,2), size(input,3));

trees = rf.mainTree;
nTrees = size(trees,1);
d = rf.mainProb;


% main tree
prob = zeros(size(feature,1),nTrees);
c = zeros(size(feature,1),nTrees);
for i = 1:nTrees
    prob(:,i) = d(forestInds(single(feature),trees{i,1}.thrs,trees{i,1}.fids,trees{i,1}.child,1), i);

end

%partial trees    
leaf2partialTree = rf.leaf2partialTree;
num_partialTree = size(rf.partialTree,1);

if(num_partialTree > 0)        
    partialTree = rf.partialTree;
    d3 = rf.subProb;
    
    for j = 1:nTrees
        idx = find(leaf2partialTree(:,j) > 0);
        k = leaf2partialTree(idx,j);
        
        for i = 1:length(idx)
            featureIdx = find(c(:,j)==idx(i));
            
            if(~isempty(featureIdx))                
                partialFeature = feature(featureIdx,:);        
                [hs, ps] = forestApply(single(partialFeature), partialTree{k,1});
                prob(featureIdx,j) = ps(:,2);                                   
            end
                            
        end
        
    end    
    
end


prob = mean(prob,2);
bgDist = 1 - reshape(prob,[size(input,1),size(input,2)]);
result = bgDist;

