%% Lectura de dades 
% Carreguem les imatges del directori pertinent (WormImages)
imatges = dir(fullfile('WormImages', '*.tif'));
numImatges = length(imatges);

% Carreguem el fitxer .csv amb els resultats de classificació
fitxerCSV = readtable("WormDataA.csv");


for i=1:1
    img = imread(fullfile(imatges(i).folder, imatges(i).name));

    if size(img, 3) == 3
        imgGris = im2gray(img);
    else
        imgGris = img;
    end

    % Apliquem filtre mediana per eliminar soroll
    imgFiltrada = medfilt2(imgGris, [3,3]);

    % Normalitzem la imatge a coordenades [0, 1]
    imgNorm = mat2gray(imgFiltrada);

    % Creem una màscara per eliminar la zona blanca de la placa
    mascPlaca = imgNorm > 0.1; % píxels més brillants que 10%
    mascPlaca = imfill(mascPlaca, "holes");
    mascPlaca = imopen(mascPlaca, strel('disk', 10));

    % Màscara circular per eliminar zona concreta
    [H, W] = size(imgFiltrada);
    [X, Y] = meshgrid(1:W, 1:H);
    xc = W/2; yc = H/2;
    radi = min(H, W) * 0.45;  % Ajustable segons imatge
    zonaClara = ((X - xc).^2 + (Y - yc).^2) < radi^2;

    figure;
    imshow(zonaClara);
    title("Zona a eliminar (màscara circular)");

    % Apliquem màscara a imatge filtrada
    imgMasc = imgFiltrada;
    imgMasc(~mascPlaca) = 0; % Fons negre
    
    % Apliquem binarització adaptativa amb threshold perquè tenim
    % il·luminació desigual
    th = adaptthresh(imgMasc, 0.3);
    imgBinaria = imbinarize(imgMasc, th);
    imgBinaria = ~imgBinaria;

    % Aplicar màscares per eliminar soroll
    imgBinaria(~mascPlaca) = 0;
    % Definim zona massa clara dins la màscara circular
    zonaRealmentClara = zonaClara & imgNorm > 0.70;  % només el blanc pur

    % Eliminem només aquesta zona clara
    imgBinaria(zonaRealmentClara) = 0;

    figure;
    subplot(1,2,1);
    imshow(imgFiltrada);
    title('Filtrada');

    subplot(1,2,2);
    imshow(imgBinaria);
    title('Binaria');
end
