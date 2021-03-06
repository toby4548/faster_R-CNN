%% Object Detection Using Faster R-CNN Deep Learning
% This example shows how to train an object detector using a deep learning
% technique named Faster R-CNN (Regions with Convolutional Neural
% Networks).
%
% Copyright 2016 The MathWorks, Inc.

%% Overview
% This example shows how to train a Faster R-CNN object detector for
% detecting vehicles. Faster R-CNN [1] is an extension of the R-CNN [2] and
% Fast R-CNN [3] object detection techniques. All three of these techniques
% use convolutional neural networks (CNN). The difference between them is
% how they select regions to process and how those regions are classified.
% R-CNN and Fast R-CNN use a region proposal algorithm as a pre-processing
% step before running the CNN. The proposal algorithms are typically
% techniques such as EdgeBoxes [4] or Selective Search [5], which are
% independent of the CNN. In the case of Fast R-CNN, the use of these
% techniques becomes the processing bottleneck compared to running the CNN.
% Faster R-CNN addresses this issue by implementing the region proposal
% mechanism using the CNN and thereby making region proposal a part of the
% CNN training and prediction steps.
% 
% In this example, a vehicle detector is trained using the
% |trainFasterRCNNObjectDetector| function from Computer Vision System
% Toolbox(TM). The example has the following sections:
%
% * Load the data set.
% * Design the convolutional Neural Network (CNN).
% * Configure training options.
% * Train Faster R-CNN object detector.
% * Evaluate the trained detector.
%
% Note: This example requires Computer Vision System Toolbox(TM), Image
% Processing Toolbox(TM), and Neural Network Toolbox(TM).
%
% Using a CUDA-capable NVIDIA(TM) GPU with compute capability 3.0 or higher
% is highly recommended for running this example. Use of a GPU requires
% Parallel Computing Toolbox(TM).

%% Load Dataset
% This example uses a small vehicle data set that contains 295 images. Each
% image contains 1 to 2 labeled instances of a vehicle. A small data set is
% useful for exploring the Faster R-CNN training procedure, but in
% practice, more labeled images are needed to train a robust detector.

% Load vehicle data set
data = load('stopSignsAndCars.mat', 'stopSignsAndCars');
stopSignsAndCars = data.stopSignsAndCars;

visiondata = fullfile(toolboxdir('vision'),'visiondata');
stopSignsAndCars.imageFilename = fullfile(visiondata, stopSignsAndCars.imageFilename);

% Display a summary of the ground truth data
summary(stopSignsAndCars)

stopSigns = stopSignsAndCars(:, {'imageFilename','stopSign'});


%%
% Display one of the images from the data set to understand the type of
% images it contains.



I = imread(stopSigns.imageFilename{1});
I = insertShape(I, 'Rectangle', stopSigns.stopSign{1});

figure
imshow(I)


%%
% Split the data set into a training set for training the detector, and a
% test set for evaluating the detector. Select 60% of the data for
% training. Use the rest for evaluation.

% Split data into a training and test set.
idx = floor(0.8 * height(stopSigns));
trainingData = stopSigns(1:idx,:);
testData = stopSigns(idx:end,:);

%% Create a Convolutional Neural Network (CNN)
% A CNN is the basis of the Faster R-CNN object detector. Create the CNN
% layer by layer using Neural Network Toolbox(TM) functionality.
%
% Start with the |imageInputLayer| function, which defines the type and
% size of the input layer. For classification tasks, the input size is
% typically the size of the training images. For detection tasks, the CNN
% needs to analyze smaller sections of the image, so the input size must be
% similar in size to the smallest object in the data set. In this data set
% all the objects are larger than [16 16], so select an input size of [32
% 32]. This input size is a balance between processing time and the amount
% of spatial detail the CNN needs to resolve.

% Create image input layer.
inputLayer = imageInputLayer([32 32 3]);

%%
% Next, define the middle layers of the network. The middle layers are made
% up of repeated blocks of convolutional, ReLU (rectified linear units),
% and pooling layers. These layers form the core building blocks of
% convolutional neural networks.

% Define the convolutional layer parameters.
filterSize = [3 3];
numFilters = 32;

% Create the middle layers.
middleLayers = [
                
    %convolution2dLayer(filterSize, numFilters, 'Padding', 1)   
    %reluLayer()
    convolution2dLayer(filterSize, numFilters, 'Padding', 1)  
    reluLayer() 
    maxPooling2dLayer(3, 'Stride',2)    
    
    ];
%%
% You can create a deeper network by repeating these basic layers. However,
% to avoid downsampling the data prematurely, keep the number of pooling
% layers low. Downsampling early in the network discards image information
% that is useful for learning.
% 
% The final layers of a CNN are typically composed of fully connected
% layers and a softmax loss layer. 

finalLayers = [
    
    % Add a fully connected layer with 64 output neurons. The output size
    % of this layer will be an array with a length of 64.
    fullyConnectedLayer(64)

    % Add a ReLU non-linearity.
    reluLayer()

    % Add the last fully connected layer. At this point, the network must
    % produce outputs that can be used to measure whether the input image
    % belongs to one of the object classes or background. This measurement
    % is made using the subsequent loss layers.
    fullyConnectedLayer(width(stopSigns))
    %fullyConnectedLayer(2)
    
    % Add the softmax loss layer and classification layer. 
    softmaxLayer()
    classificationLayer()
];

%%
% Combine the input, middle, and final layers.
layers = [
    inputLayer
    middleLayers
    finalLayers
    ]

layers(2).Weights = 0.0001 * randn([filterSize 3 numFilters]);

%% Configure Training Options
% |trainFasterRCNNObjectDetector| trains the detector in four steps. The first
% two steps train the region proposal and detection networks used in Faster
% R-CNN. The final two steps combine the networks from the first two steps
% such that a single network is created for detection [1]. Each training
% step can have different convergence rates, so it is beneficial to specify
% independent training options for each step. To specify the network
% training options use |trainingOptions| from Neural Network Toolbox(TM).

% Options for step 1.
optionsStage1 = trainingOptions('sgdm', ...
    'MaxEpochs', 10, ...
    'InitialLearnRate', 1e-5, ...
    'CheckpointPath', tempdir);

% Options for step 2.
optionsStage2 = trainingOptions('sgdm', ...
    'MaxEpochs', 10, ...
    'InitialLearnRate', 1e-5, ...
    'CheckpointPath', tempdir);

% Options for step 3.
optionsStage3 = trainingOptions('sgdm', ...
    'MaxEpochs', 10, ...
    'InitialLearnRate', 1e-6, ...
    'CheckpointPath', tempdir);

% Options for step 4.
optionsStage4 = trainingOptions('sgdm', ...
    'MaxEpochs', 10, ...
    'InitialLearnRate', 1e-6, ...
    'CheckpointPath', tempdir);

options = [
    optionsStage1
    optionsStage2
    optionsStage3
    optionsStage4
    ];

%%
% Here, the learning rate for the first two steps is set higher than the
% last two steps. Because the last two steps are fine-tuning steps, the
% network weights can be modified more slowly than in the first two steps.
%
% In addition, |'CheckpointPath'| is set to a temporary location for all
% the training options. This name-value pair enables the saving of
% partially trained detectors during the training process. If training is
% interrupted, such as from a power outage or system failure, you can
% resume training from the saved checkpoint.

%% Train Faster R-CNN
% Now that the CNN and training options are defined, you can train the
% detector using |trainFasterRCNNObjectDetector|.
%
% During training, image patches are extracted from the training data. The
% |'PositiveOverlapRange'| and |'NegativeOverlapRange'| name-value pairs
% control which image patches are used for training. Positive training
% samples are those that overlap with the ground truth boxes by 0.6 to 1.0,
% as measured by the bounding box intersection over union metric. Negative
% training samples are those that overlap by 0 to 0.3. The best values for
% these parameters should be chosen by testing the trained detector on a
% validation set. To choose the best values for these name-value pairs,
% test the trained detector on a validation set.
%
% For Faster R-CNN training, *the use of a parallel pool of MATLAB workers is
% highly recommended to reduce training time*. |trainFasterRCNNObjectDetector|
% automatically creates and uses a parallel pool based on your <http://www.mathworks.com/help/vision/gs/computer-vision-system-toolbox-preferences.html parallel preference settings>. Ensure that the use of
% the parallel pool is enabled prior to training.
%
% A CUDA-capable NVIDIA(TM) GPU with compute capability 3.0 or higher is
% highly recommended for training.
%
% To save time while running this example, a pretrained network is loaded
% from disk. To train the network yourself, set the |doTrainingAndEval|
% variable shown here to true.

% A trained network is loaded from disk to save time when running the
% example. Set this flag to true to train the network. 
doTrainingAndEval = true;

if doTrainingAndEval
    % Set random seed to ensure example training reproducibility.
    rng(0);
    
    % Train Faster R-CNN detector. Select a BoxPyramidScale of 1.2 to allow
    % for finer resolution for multiscale object detection.
    detector = trainFasterRCNNObjectDetector(trainingData, layers, options, ...
        'NegativeOverlapRange', [0 0.3], ...
        'PositiveOverlapRange', [0.6 1], ...
        'BoxPyramidScale', 1.2);
else
    % Load pretrained detector for the example.
    detector = data.detector;
end

%%
% To quickly verify the training, run the detector on a test image.

% Read a test image.
I = imread('highway.png');

% Run the detector.
[bboxes, scores] = detect(detector, I);

% Annotate detections in the image.
I = insertObjectAnnotation(I, 'rectangle', bboxes, scores);
figure
imshow(I)

%% Evaluate Detector Using Test Set
% Testing a single image showed promising results. To fully evaluate the
% detector, testing it on a larger set of images is recommended. Computer
% Vision System Toolbox(TM) provides object detector evaluation functions
% to measure common metrics such as average precision
% (|evaluateDetectionPrecision|) and log-average miss rates
% (|evaluateDetectionMissRate|). Here, the average precision metric is
% used. The average precision provides a single number that incorporates
% the ability of the detector to make correct classifications (precision)
% and the ability of the detector to find all relevant objects (recall).
%
% The first step for detector evaluation is to collect the detection
% results by running the detector on the test set. To avoid long evaluation
% time, the results are loaded from disk. Set the |doTrainingAndEval| flag
% from the previous section to true to execute the evaluation locally.

if doTrainingAndEval
    % Run detector on each image in the test set and collect results.
    resultsStruct = struct([]);
    for i = 1:height(testData)
        
        % Read the image.
        I = imread(testData.imageFilename{i});
        
        % Run the detector.
        [bboxes, scores, labels] = detect(detector, I);
        
        % Collect the results.
        resultsStruct(i).Boxes = bboxes;
        resultsStruct(i).Scores = scores;
        resultsStruct(i).Labels = labels;
    end
    
    % Convert the results into a table.
    results = struct2table(resultsStruct);
else
    % Load results from disk.
    results = data.results;
end

% Extract expected bounding box locations from test data.
expectedResults = testData(:, 2:end);

% Evaluate the object detector using Average Precision metric.
[ap, recall, precision] = evaluateDetectionPrecision(results, expectedResults);

%%
% The precision/recall (PR) curve highlights how precise a detector is at
% varying levels of recall. Ideally, the precision would be 1 at all recall
% levels. In this example, the average precision is 0.6. The use of
% additional layers in the network can help improve the average precision,
% but might require additional training data and longer training time.

% Plot precision/recall curve
figure
plot(recall, precision)
xlabel('Recall')
ylabel('Precision')
grid on
title(sprintf('Average Precision = %.1f', ap))

%% Summary
% This example showed how to train a vehicle detector using deep learning.
% You can follow similar steps to train detectors for traffic signs,
% pedestrians, or other objects.
%
% <matlab:helpview('vision','deepLearning') Learn more about Deep Learning for Computer Vision>.

%% References
% [1] Ren, Shaoqing, et al. "Faster R-CNN: Towards Real-Time Object
% detection with Region Proposal Networks." _Advances in Neural Information
% Processing Systems._ 2015.
%
% [2] Girshick, Ross, et al. "Rich feature hierarchies for accurate object
% detection and semantic segmentation." _Proceedings of the IEEE Conference
% on Computer Vision and Pattern Recognition._ 2014.
%
% [3] Girshick, Ross. "Fast r-cnn." _Proceedings of the IEEE International
% Conference on Computer Vision._ 2015.
%
% [4] Zitnick, C. Lawrence, and Piotr Dollar. "Edge boxes: Locating object
% proposals from edges." _Computer Vision-ECCV_ 2014. Springer
% International Publishing, 2014. 391-405.
%
% [5] Uijlings, Jasper RR, et al. "Selective search for object recognition."
% _International Journal of Computer Vision_ (2013): 154-171.

displayEndOfDemoMessage(mfilename)