lizMap.events.on({
    uicreated: function(e) {
        // --- KONFIGURACJA ---
        // Wpisz tutaj nazwę techniczną warstwy (tą z QGIS), do której ma dodawać przycisk.
        // Jeśli chcesz, aby przycisk był uniwersalny (pytał o warstwę), daj znać.
        // Na razie ustawiam na sztywno, żeby przyspieszyć pracę (Workflow: Klik -> Rysuj).
        var targetLayerName = 'pomiar'; // ZMIEŃ TO NA SWOJĄ NAZWĘ!

        // --- 1. UKRYWANIE STANDARDOWEGO PRZYCISKU EDYCJI ---
        // Ukrywamy ikonę w lewym menu (#button-edition), ale NIE wyłączamy funkcjonalności.
        // Dzięki temu "Stwórz potomny" w popupach nadal zadziała (bo panel edycji fizycznie istnieje).
        var css = `
            /* Ukryj ikonę edycji w lewym pasku */
            #map-menu #button-edition {
                display: none !important;
            }

            /* Styl nowego przycisku "Szybka Edycja" */
            #quick-edit-btn {
                position: fixed;
                bottom: 50px;
                left: 50%; /* Wyśrodkowanie */
                transform: translateX(-50%);
                z-index: 10000;
                background-color: #d9534f; /* Czerwony - wyróżniający się */
                color: white;
                border: 2px solid white;
                border-radius: 30px; /* Zaokrąglony */
                padding: 10px 25px;
                font-weight: bold;
                font-size: 14px;
                cursor: pointer;
                box-shadow: 0px 4px 10px rgba(0,0,0,0.3);
                transition: transform 0.2s, background-color 0.2s;
            }
            #quick-edit-btn:hover {
                background-color: #c9302c;
                transform: translateX(-50%) scale(1.05);
            }
            #quick-edit-btn i { margin-right: 8px; }
/* Ukrywamy oryginalną ikonę plusa i wstawiamy notatnik */
.lizmap-relation-manager .add-feature i::before, 
.btn-relation-add i::before {
    content: "\f0f6" !important; /* Kod ikony 'file-text-o' (notatnik) */
    font-family: "FontAwesome" !important;
    font-style: normal;
    font-weight: normal;
    font-size: 24px !important; /* Powiększenie samej ikony */
    color: #ffffff !important;
    display: inline-block;
    vertical-align: middle;
}

/* Stylizacja całego przycisku dodawania */
.lizmap-relation-manager .add-feature, 
.btn-relation-add {
    background-color: #2e7d32 !important; /* Ciemnozielony kolor leśny */
    border: 2px solid #1b5e20 !important;
    border-radius: 6px !important;
    padding: 8px 16px !important;
    min-height: 45px;
    box-shadow: 0 2px 5px rgba(0,0,0,0.3);
    transition: background 0.3s ease;
}

/* Zmiana tekstu obok ikony (jeśli istnieje) */
.lizmap-relation-manager .add-feature span,
.btn-relation-add span {
    font-weight: bold !important;
    font-size: 14px !important;
    margin-left: 8px;
    text-transform: uppercase;
}

/* Efekt po najechaniu - przycisk staje się bardziej jaskrawy */
.lizmap-relation-manager .add-feature:hover, 
.btn-relation-add:hover {
    background-color: #4caf50 !important;
    box-shadow: 0 4px 8px rgba(0,0,0,0.4);
    text-decoration: none;
}
        `;
        $('head').append('<style>' + css + '</style>');


        // --- 2. DODANIE NOWEGO PRZYCISKU ---
        var btnHtml = '<button id="quick-edit-btn" title="Dodaj pomiar terenowy"><i class="icon-pencil icon-white"></i> Dodaj obiekt</button>';
        $('body').append(btnHtml);


        // --- 3. LOGIKA KLIKNIĘCIA (AUTOMATYZACJA) ---
        $('#quick-edit-btn').click(function() {
            startEditionProcess(targetLayerName);
        });


        // --- 4. FUNKCJA STERUJĄCA EDYCJĄ LIZMAP ---
        function startEditionProcess(layerName) {
            // A. Sprawdź, czy panel edycji jest już otwarty. Jeśli nie - otwórz go.
            // Symulujemy kliknięcie w ukryty przycisk #button-edition
            if (!$('#edition-form').is(':visible')) {
                // Musimy użyć oryginalnego zdarzenia, aby Lizmap zainicjował moduł
                $('#button-edition').trigger('click');
            }

            // B. Czekamy chwilę, aż panel się załaduje i lista warstw wypełni
            // Lizmap potrzebuje ułamka sekundy na zbudowanie DOM panelu edycji
            var attempts = 0;
            var interval = setInterval(function() {
                attempts++;
                var layerSelect = $('#edition-layer-select');

                // Jeśli lista istnieje i ma opcje
                if (layerSelect.length > 0 && layerSelect.find('option').length > 1) {
                    clearInterval(interval);
                    
                    // C. Wybieramy warstwę
                    // Musimy znaleźć value dla naszej nazwy technicznej
                    var optionVal = layerSelect.find('option[value="' + layerName + '"]').val();
                    
                    // Jeśli nie znaleziono po nazwie prostej, szukamy po tytule lub "loc_"
                    if (!optionVal) {
                        // Iteracja po opcjach
                        layerSelect.find('option').each(function() {
                            if ($(this).text().indexOf(layerName) !== -1 || $(this).val().indexOf(layerName) !== -1) {
                                optionVal = $(this).val();
                            }
                        });
                    }

                    if (optionVal) {
                        console.log('Automatyczny wybór warstwy:', optionVal);
                        layerSelect.val(optionVal);
                        layerSelect.trigger('change'); // Ważne: informuje Lizmap o zmianie

                        // D. Czekamy na pojawienie się przycisku "Stwórz" (Draw)
                        // Po wybraniu warstwy, Lizmap ładuje narzędzia (Create, Edit, Delete)
                        setTimeout(function() {
                            activateDrawTool();
                        }, 500);

                    } else {
                        alert('Błąd: Nie znaleziono warstwy "' + layerName + '" w panelu edycji.\nUpewnij się, że masz uprawnienia do jej edycji.');
                    }
                }

                if (attempts > 20) { // Timeout po 2 sekundach (20 * 100ms)
                    clearInterval(interval);
                    console.error('Timeout: Panel edycji nie załadował się poprawnie.');
                }
            }, 100);
        }

        function activateDrawTool() {
            // Szukamy przycisku "Stwórz" / "Dodaj"
            // W Lizmap 3 przycisk ten ma zazwyczaj klasę .edition-create lub ID związane z typem geometrii
            
            // Najpierw sprawdzamy czy przycisk "Stwórz" jest dostępny (nieaktywny znaczy, że już jesteśmy w trybie tworzenia?)
            var createBtn = $('.edition-create'); // Ogólna klasa w niektórych wersjach
            
            if (createBtn.length === 0) {
                // Próba znalezienia po ID (zależy od geometrii warstwy: point, line, polygon)
                if ($('#button-create-polygon').length > 0) createBtn = $('#button-create-polygon');
                else if ($('#button-create-line').length > 0) createBtn = $('#button-create-line');
                else if ($('#button-create-point').length > 0) createBtn = $('#button-create-point');
            }

            if (createBtn.length > 0) {
                // Sprawdzamy, czy już nie jest aktywny
                if (!createBtn.hasClass('active')) {
                    createBtn.trigger('click');
                    
                    // Komunikat dla użytkownika
                    lizMap.addMessage('Tryb rysowania aktywny. Kliknij na mapie, aby dodać geometrię.', 'info', true);
                }
            } else {
                console.warn('Nie znaleziono przycisku rysowania. Sprawdź selektory DOM.');
                // Fallback: Spróbujmy kliknąć pierwszy dostępny przycisk w toolbarze edycji
                $('#edition-toolbar button').first().click();
            }
        }

        // --- 5. OBSŁUGA "STWÓRZ POTOMNY" (Relacje) ---
        // To działa automatycznie. Skoro ukryliśmy tylko ikonę w menu (#map-menu #button-edition),
        // a nie zniszczyliśmy panelu, Lizmap nadal obsłuży zdarzenie kliknięcia "Stwórz potomny" w popupie.
        // Kliknięcie w popupie wymusi otwarcie panelu edycji, co jest pożądanym zachowaniem.
        
    }
});