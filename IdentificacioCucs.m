%% Lectura de dades 
% Carreguem les imatges del directori pertinent (WormImages)
imatges = dir(fullfile('WormImages', '*.tif'));
numImatges = length(imatges);

% Carreguem el fitxer .csv amb els resultats de classificació
fitxerCSV = readtable("WormDataA.csv");
cucs_tot = 0;
viusTotals = 0;
mortsTotals = 0;
viusReals_tot = 0;
mortsReals_tot = 0;

for i=1:numImatges
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
    %mascPlaca = imgNorm > 0.1; % píxels més brillants que 10%
    mascPlaca = imgNorm > graythresh(imgNorm) * 0.20; % píxels més brillants que 10%
    mascPlaca = imfill(mascPlaca, 'holes');
    mascPlaca = imopen(mascPlaca, strel('disk', 10));

    %figure;
    %imshow(~mascPlaca);
    %title('mascara a aplicar');
    
    % Apliquem binarització adaptativa amb threshold perquè tenim
    % il·luminació desigual
    th = adaptthresh(imgNorm, 0.65);
    imgBinaria = imbinarize(imgNorm, th);
    imgBinaria = ~imgBinaria; % Cucs en blanc, fons en negre.
        
    % Aplicar màscares per eliminar soroll
    mascErosio = imerode(mascPlaca, strel('square', 5)); % Eliminem vorera de la màscara
    imgBinaria(~mascErosio) = 0;

    % Detectem únicament cucs per eliminar la zona blanca.
    cucs = ~imbinarize(imgNorm, 0.48);
    imgBinaria(~cucs) = 0;

    %% Apliquem post processat a les imatges per eliminar possible soroll
    %imgBinaria = imerode(imgBinaria, strel('line', 1, 0));
    %imgBinaria = imerode(imgBinaria, strel('line', 1, 45));
    imgBinaria = imerode(imgBinaria, strel('disk', 1));
    imgBinaria = bwmorph(imgBinaria, 'bridge');
    imgBinaria = imclose(imgBinaria, strel('disk', 1)); % Suavitzem contorns i omplim possibles forats petits
    imgBinaria = imclose(imgBinaria, strel('line', 4, 45)); % Suavitzem contorns i omplim possibles forats petits
    imgBinaria = imclose(imgBinaria, strel('line', 4, 0)); % Suavitzem contorns i omplim possibles forats petits
    imgBinaria = bwareaopen(imgBinaria, 100); % Eliminem possible soroll restant (petits píxels)

    
    
    %% Etiquetem cucs i extraiem característiques
    [etiquetaImg, nCucs] = bwlabel(imgBinaria);
    % Extraeiem característiques, principalment l'excentricitat per saber
    % com de recte o corbat està un cuc.
    caract = regionprops(etiquetaImg, 'BoundingBox', 'Area', 'Eccentricity', 'Solidity', 'Perimeter', ...
        'PixelList');
    
    % Convertim la imatge a RGB per poder representar colors
    if size(img, 3) == 1
        imgRGB = cat(3, img, img, img);
    else
        imgRGB = img;
    end

    % Convertim a double
    imgRGB = im2double(imgRGB);

    % Comptadors
    cVius = 0;
    cMorts = 0;

    % Llindars
    ll_eccentricitat = 0.9965;
    ll_AreaMin = 110; % Valor comprovat amb caract(j).Area de cada cuc. 347
    ll_sol = 0.945;
    ll_relacio = 0.485;  % nou llindar per la distància euclidiana
    
    % Recorrem cada cuc de la imatge
    for j = 1:nCucs
        if caract(j).Area < ll_AreaMin
            continue;
        end

        boundBox = caract(j).BoundingBox;
        exc = caract(j).Eccentricity;
        sol = caract(j).Solidity;

        % Calcular relació distància euclidiana vs. longitud del cuc
        pixs = caract(j).PixelList;
        dist = sqrt(sum((pixs(1,:) - pixs(end,:)).^2));
        long = caract(j).Perimeter;
        relacio = dist / long;

        if exc < ll_eccentricitat %relacio < ll_relacio &&  %&& sol < ll_sol
            estat = 'Viu';
            color = [0, 1, 0]; % Verd
            cVius = cVius + 1;
        else
            estat = 'Mort';
            color = [1, 0, 0]; % Vermell
            cMorts = cMorts + 1;
        end
        % Representem rectangle i text
        imgRGB = insertShape(imgRGB, 'rectangle', boundBox, 'color', color*255, 'LineWidth', 1);
        imgRGB = insertText(imgRGB, [boundBox(1), boundBox(2)-15], estat, 'BoxColor', color*255, 'TextColor', 'white', 'FontSize', 14);
    end
    % Mostrem la imatge amb els cucs marcats
    figure;
    imshow(imgRGB);
    title(sprintf('Cucs vius: %d | morts: %d', cVius, cMorts));

    %% Comparem amb els resultats reals que hi ha al fitxer csv
    % Nom de la imatge actual
    nomImg = imatges(i).name;
    
    % Extraiem la columna de nom i estat
    %fitxerCSV.Properties.VariableNames % Per identificar com matlab ha
    %anomenat les columnes

    nomsAmbEstat = fitxerCSV{:, "File_Status"};  % Accedim com a cel·la
    
    % Separem noms de fitxer (ex: wormA01.tif) i status (ex: alive)
    nomsFitxer = cellfun(@(s) strsplit(s, ","), nomsAmbEstat, 'UniformOutput', false);
    nomsFitxer = cellfun(@(x) x{1}, nomsFitxer, 'UniformOutput', false);  % Nom només
    
    % Cerquem la fila que coincideix amb el nom de la imatge
    idx = find(strcmp(nomsFitxer, nomImg));

    % Si existeix la fila busquem els valors
    if ~isempty(idx)
        vius_reals = fitxerCSV{idx, "x_AliveWorms"};
        morts_reals = fitxerCSV{idx, "x_DeadWorms"};

        viusTotals = viusTotals + cVius;
        mortsTotals = mortsTotals + cMorts;
        viusReals_tot = vius_reals + viusReals_tot;
        mortsReals_tot = morts_reals + mortsReals_tot;

        fprintf("Imatge: %s:\n", nomImg);
        fprintf("Vius detectats: %d | Esperats: %d\n", cVius, vius_reals);
        fprintf("Morts detectats: %d | Esperats: %d\n", cMorts, morts_reals);
        if (cVius > cMorts)
            fprintf("Classificació -> Imatge cucs vius\n\n");
        elseif (cVius < cMorts)
            fprintf("Classificació -> Imatge cucs morts\n\n");
        else
            fprintf("Classificació -> Imatge amb iguals vius que morts\n\n");
        end
        cucs_tot = vius_reals + morts_reals;
    end

    %% Mostrem resultats
    % Comparem imatge filtrada i binària per veure els resultats.
    %{
    figure;
    subplot(2,2,1);
    imshow(imgFiltrada);
    title('Filtrada');

    subplot(2,2,2);
    imshow(imgBinaria);
    title('Binaria');

    subplot(2,2,[3,4]);
    imshow(imgRGB);
    titol = sprintf('Detectats: %d vius | %d morts\nReals: %d vius | %d morts', ...
                cVius, cMorts, vius_reals, morts_reals);
    title(titol);
    %}
    
end
totals_reals = viusReals_tot + mortsReals_tot;
correctes = min(viusTotals, viusReals_tot) + min(mortsTotals, mortsReals_tot);
percentatge = (correctes / totals_reals) * 100;
fprintf("\nPercentatge de classificació correcta: %.2f%%\n", percentatge);