%% Lectura de dades 
% Carreguem les imatges del directori pertinent (WormImages)
imatges = dir(fullfile('WormImages', '*.tif'));
numImatges = length(imatges);

% Carreguem el fitxer .csv amb els resultats de classificació
fitxerCSV = readtable("WormDataA.csv");

% Comptadors globals per després calcular la precissió de classificació
cucs_tot = 0;
viusTotals = 0;
mortsTotals = 0;
viusReals_tot = 0;
mortsReals_tot = 0;

% Apliquem per a totes les imatges del directori
for i=1:numImatges
    % Carreguem cada imatge del directori
    img = imread(fullfile(imatges(i).folder, imatges(i).name));
    
    %% Preprocessat de les imatges
    % Transformem les imatges a escala de grisos per si hi ha alguna a
    % color (en cas de futures probes també).
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
    % Ens quedem amb els píxels amb intensitat superior al 20% del llindar
    % que retorna graythresh (mètode Otsu). Per obtenir un millor
    % enfocament dels cucs.
    mascPlaca = imgNorm > graythresh(imgNorm) * 0.20;
    mascPlaca = imfill(mascPlaca, 'holes');
    mascPlaca = imopen(mascPlaca, strel('disk', 10));
    
    % Apliquem binarització adaptativa amb threshold, a nivell de píxel, perquè tenim
    % il·luminació desigual
    th = adaptthresh(imgNorm, 0.65);
    imgBinaria = imbinarize(imgNorm, th);
    imgBinaria = ~imgBinaria; % Invertim la imatge -> cucs en blanc, fons en negre.
        
    % Aplicar màscares per eliminar soroll
    mascErosio = imerode(mascPlaca, strel('square', 5)); % Eliminem vorera de la màscara
    imgBinaria(~mascErosio) = 0; % Eliminiem qualsevol pixel fora de la màscara

    % Detectem únicament cucs per eliminar la zona blanca mitjançant una
    % nova màscara.
    cucs = ~imbinarize(imgNorm, 0.48);
    imgBinaria(~cucs) = 0;

    %% Apliquem post processat a les imatges per eliminar possible soroll
    % Primer apliquem una erosió lineal per cucs en diagonal i horitzonal
    imgBinaria = imerode(imgBinaria, strel('line', 2, 0));
    imgBinaria = imerode(imgBinaria, strel('line', 2, 45));

    % Reconnectem píxels molt propers (possibles cucs trencats)
    imgBinaria = bwmorph(imgBinaria, 'bridge');

    % Apliquem closing per intentar juntar píxels més separats de cucs
    % possiblement trencats. Primer de forma general i després en concret
    % linealment.
    imgBinaria = imclose(imgBinaria, strel('disk', 1)); 
    imgBinaria = imclose(imgBinaria, strel('line', 4, 45)); 
    imgBinaria = imclose(imgBinaria, strel('line', 4, 0));

    % Eliminem possible soroll restant (petits píxels)
    imgBinaria = bwareaopen(imgBinaria, 100); 
        
    %% Etiquetem cucs i extraiem característiques
    [etiquetaImg, nCucs] = bwlabel(imgBinaria);
    % Extraeiem característiques, principalment l'excentricitat per saber
    % com de recte o corbat està un cuc.
    caract = regionprops(etiquetaImg, 'BoundingBox', 'Area', 'Eccentricity', 'Perimeter');
    
    % Convertim la imatge a RGB per poder representar colors (per
    % representar boundingbox)
    if size(img, 3) == 1
        imgRGB = cat(3, img, img, img);
    else
        imgRGB = img;
    end

    % Convertim a double i tenir rang [0,1], per millor resultat de les
    % funcions
    imgRGB = im2double(imgRGB);

    % Comptadors
    cVius = 0;
    cMorts = 0;

    % Llindars
    ll_eccentricitat = 0.9962;
    ll_AreaMin = 70;
        
    % Recorrem cada cuc de la imatge
    for j = 1:nCucs
        % Extraiem l'àrea de cada cuc, si no arriba al mínim es descarta
        if caract(j).Area < ll_AreaMin
            continue;
        end
        % Extraiem la boundingbox i l'excentricitat i segons llindar es
        % classifica com a viu o mort.
        boundBox = caract(j).BoundingBox;
        exc = caract(j).Eccentricity;
      
        if exc < ll_eccentricitat %relacio < ll_relacio &&
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
    % fitxerCSV.Properties.VariableNames % Per identificar com matlab ha anomenat les columnes
    nomsComplets = fitxerCSV{:, "File_Status"};  % Accedim com a cel·la
    
    % Separem nom de l'status
    nomsFitxer = cellfun(@(s) strsplit(s, ","), nomsComplets, 'UniformOutput', false);
    nomsImatges = cellfun(@(x) x{1}, nomsFitxer, 'UniformOutput', false);  % Nom només
    
    % Cerquem la fila que coincideix amb el nom de la imatge
    idx = find(strcmp(nomsImatges, nomImg));

    % Si existeix la fila busquem els valors
    if ~isempty(idx)
        vius_reals = fitxerCSV{idx, "x_AliveWorms"};
        morts_reals = fitxerCSV{idx, "x_DeadWorms"};
        
        % Acumulem en les diferents imatges per poder realitzar el càlcul de precissió
        viusTotals = viusTotals + cVius;
        mortsTotals = mortsTotals + cMorts;
        viusReals_tot = vius_reals + viusReals_tot;
        mortsReals_tot = morts_reals + mortsReals_tot;
        
        % Printem al terminal informació sobre la imatge i la classificació
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
        cucs_tot = cucs_tot + vius_reals + morts_reals;
    end

    %% Mostrem resultats en un subplot
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
%% Càlcul de la precissió de la classificació
totals_reals = viusReals_tot + mortsReals_tot;
correctes = min(viusTotals, viusReals_tot) + min(mortsTotals, mortsReals_tot);
percentatge = (correctes / totals_reals) * 100;
fprintf("Percentatge de classificació correcta: %.2f%%\n", percentatge);