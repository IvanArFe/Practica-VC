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

    %figure;
    %imshow(~mascPlaca);
    %title('mascara a aplicar');
    
    % Apliquem binarització adaptativa amb threshold perquè tenim
    % il·luminació desigual
    th = adaptthresh(imgNorm, 0.5);
    imgBinaria = imbinarize(imgNorm, th);
    imgBinaria = ~imgBinaria; % Cucs en blanc, fons en negre.
        
    % Aplicar màscares per eliminar soroll
    mascErosio = imerode(mascPlaca, strel('disk', 4)); % Eliminem vorera de la màscara
    imgBinaria(~mascErosio) = 0;

    % Detectem únicament cucs per eliminar la zona blanca.
    cucs = ~imbinarize(imgNorm, 0.45);
    imgBinaria(~cucs) = 0;
    
    % Comparem imatge filtrada i binària per veure els resultats.
    figure;
    subplot(1,2,1);
    imshow(imgFiltrada);
    title('Filtrada');

    subplot(1,2,2);
    imshow(imgBinaria);
    title('Binaria');
end
