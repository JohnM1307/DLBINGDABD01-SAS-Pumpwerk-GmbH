/* Import Pumpe A */
proc import datafile="/home/u64212633/sasuser.v94/sensordaten_produktion_pumpwerk_pumpeA.xlsx"
    out=pumpe_a
    dbms=xlsx
    replace;
    sheet="Pumpe A"; 
run;

/* Import Pumpe B */
proc import datafile="/home/u64212633/sasuser.v94/sensordaten_produktion_pumpwerk_pumpeB.xlsx"
    out=pumpe_b
    dbms=xlsx
    replace;
    sheet="Pumpe B";
run;
/* Schritt 1: Daten von Pumpe A um eine zusätzliche Spalte erweitern */
data pumpe_a;
    set pumpe_a;
    pumpe = "A"; /* Neue Spalte "pumpe" mit Wert "A" zur Kennzeichnung */
run;

/* Schritt 2: Daten von Pumpe B um eine zusätzliche Spalte erweitern */
data pumpe_b;
    set pumpe_b;
    pumpe = "B"; /* Neue Spalte "pumpe" mit Wert "B" zur Kennzeichnung */
run;

/* Schritt 3: Zusammenführung der beiden Pumpendatensätze in eine gemeinsame Tabelle */
data sensordaten_gesamt;
    set pumpe_a pumpe_b; /* Kombiniert die Daten von Pumpe A und B */
run;
/* --------------------------------------------
   1. Verteilungsanalyse 
   → zeigt Statistiken, Histogramm & Normalverteilung
-------------------------------------------- */
proc univariate data=sensordaten_gesamt noprint;
    var 
        'Drehzahl (RPM)'n 
        'Durchflussmenge (Liter/Minute)'n 
        'Spannung (Volt)'n 
        'Motortemperatur'n;  /* die zu analysierenden Variablen */
    id Zeitstempel pumpe;     /* zur späteren Identifikation */
    histogram / normal;       /* zeigt Histogramm + Normalverteilung */
    inset n mean std min max / position=ne;  /* Statistiken ins Diagramm einfügen */
    qqplot / normal(mu=est sigma=est);       /* QQ-Plot → zeigt Normalverteilung */
run;

/* --------------------------------------------
   2. Ermittlung von IQR-basierten Grenzwerten
   → Grundlage für Ausreißererkennung
   (angepasst auf 1.0 * IQR für empfindlichere Erkennung)
-------------------------------------------- */
proc univariate data=sensordaten_gesamt noprint;
    var 
        'Drehzahl (RPM)'n 
        'Durchflussmenge (Liter/Minute)'n 
        'Spannung (Volt)'n 
        'Motortemperatur'n;
    output out=grenzen
        q1=dreh_q1 durchfluss_q1 spannung_q1 temp_q1
        q3=dreh_q3 durchfluss_q3 spannung_q3 temp_q3;
run;

/* --------------------------------------------
   3. Berechnung der IQR-Grenzen (1.0 * IQR)
-------------------------------------------- */
data grenzen_berechnet;
    set grenzen;
    dreh_iqr = dreh_q3 - dreh_q1;
    dreh_unter = dreh_q1 - 1.0 * dreh_iqr;
    dreh_ober = dreh_q3 + 1.0 * dreh_iqr;

    durchfluss_iqr = durchfluss_q3 - durchfluss_q1;
    durchfluss_unter = durchfluss_q1 - 1.0 * durchfluss_iqr;
    durchfluss_ober = durchfluss_q3 + 1.0 * durchfluss_iqr;

    spannung_iqr = spannung_q3 - spannung_q1;
    spannung_unter = spannung_q1 - 1.0 * spannung_iqr;
    spannung_ober = spannung_q3 + 1.0 * spannung_iqr;

    temp_iqr = temp_q3 - temp_q1;
    temp_unter = temp_q1 - 1.0 * temp_iqr;
    temp_ober = temp_q3 + 1.0 * temp_iqr;
run;

/* --------------------------------------------
   4. Vergleich der Originaldaten mit den IQR-Grenzen + Empfehlungen
-------------------------------------------- */
data ausreisser; 
    if _n_ = 1 then set grenzen_berechnet;  
    set sensordaten_gesamt;                
    length Anomalie Empfehlung $200;  

    if 'Drehzahl (RPM)'n < dreh_unter or 'Drehzahl (RPM)'n > dreh_ober then do;
        Anomalie = catx(', ', Anomalie, 'Drehzahl');
        Empfehlung = catx(' ', Empfehlung, 'Motorkontrolle empfohlen.');
    end;

    if 'Durchflussmenge (Liter/Minute)'n < durchfluss_unter or 'Durchflussmenge (Liter/Minute)'n > durchfluss_ober then do;
        Anomalie = catx(', ', Anomalie, 'Durchfluss');
        Empfehlung = catx(' ', Empfehlung, 'Pumpenleistung überprüfen.');
    end;

    if 'Spannung (Volt)'n < spannung_unter or 'Spannung (Volt)'n > spannung_ober then do;
        Anomalie = catx(', ', Anomalie, 'Spannung');
        Empfehlung = catx(' ', Empfehlung, 'Elektrik/Frequenzumrichter prüfen.');
    end;

    if 'Motortemperatur'n < temp_unter or 'Motortemperatur'n > temp_ober then do;
        Anomalie = catx(', ', Anomalie, 'Temperatur');
        Empfehlung = catx(' ', Empfehlung, 'Wärmeentwicklung zu hoch, Kühlsystem überprüfen.');
    end;

    if Anomalie ne '' then output;
run;

proc print data=ausreisser;
    title "Identifizierte Ausreißer mit Empfehlungen für Wartung";
run;

/* --------------------------------------------
   5. Visualisierung: Boxplots pro Pumpe
   → zeigen Ausreißer und Verteilung je Pumpe
-------------------------------------------- */
proc sgplot data=sensordaten_gesamt;
    vbox 'Drehzahl (RPM)'n / category=pumpe;
    vbox 'Durchflussmenge (Liter/Minute)'n / category=pumpe;
    vbox 'Spannung (Volt)'n / category=pumpe;
    vbox 'Motortemperatur'n / category=pumpe;
    title "Boxplots zur Ausreißererkennung pro Pumpe";
run;

/* --------------------------------------------
   6. Streudiagramm: Drehzahl vs. Durchfluss
   → zeigt mögliche Korrelation oder Muster
-------------------------------------------- */
proc sgplot data=sensordaten_gesamt;
    scatter x='Drehzahl (RPM)'n y='Durchflussmenge (Liter/Minute)'n / group=pumpe;
    title "Zusammenhang: Drehzahl vs. Durchflussmenge (Pumpe A & B)";
run;

/* --------------------------------------------
   7. Clusteranalyse: Gruppenbildung nach Sensorwerten
   → erkennt typische Betriebszustände automatisch
-------------------------------------------- */
proc fastclus data=sensordaten_gesamt maxclusters=3 out=cluster_ergebnis;
    var 
        'Drehzahl (RPM)'n 
        'Durchflussmenge (Liter/Minute)'n 
        'Spannung (Volt)'n 
        'Motortemperatur'n;
run;

proc sgplot data=cluster_ergebnis;
    scatter x='Drehzahl (RPM)'n y='Durchflussmenge (Liter/Minute)'n / group=cluster;
    title "Clusteranalyse: Betriebszustände der Pumpen";
run;

/* --------------------------------------------
   8. Liniendiagramm: Temperaturverlauf über Zeit
-------------------------------------------- */
proc sgplot data=sensordaten_gesamt;
    series x=Zeitstempel y='Motortemperatur'n / group=pumpe;
    title "Motortemperatur im Zeitverlauf (Pumpe A & B)";
run;

/* --------------------------------------------
   9. Heatmap: Häufigkeit von Drehzahl vs. Durchfluss
-------------------------------------------- */
proc sgplot data=sensordaten_gesamt;
    heatmap x='Drehzahl (RPM)'n y='Durchflussmenge (Liter/Minute)'n;
    title "Dichtekarte: Drehzahl vs. Durchflussmenge";
run;

/* --------------------------------------------
   10. Balkendiagramm: Anzahl der Anomalien pro Pumpe
-------------------------------------------- */
proc freq data=ausreisser;
    tables pumpe / out=anomalie_anzahl;
run;

proc sgplot data=anomalie_anzahl;
    vbar pumpe / response=count datalabel;
    title "Anzahl erkannter Anomalien pro Pumpe";
run;
/* Test 
/* =============================================
   SAS Projekt: Erweiterte Analyse der Pumpendaten
   Module:
   1. Frühwarnsystem (Schwellenwert + Zeitlogik)
   2. Dynamisches KPI-Dashboard
   3. Korrelation & Regression
   4. Vorhersagemodell (Maschinelles Lernen)
============================================= */


/* =============================================
   1. Frühwarnsystem
   → Meldung, wenn innerhalb 2 Stunden mehr als 2 Anomalien auftreten
============================================= */

/* Basis: vorhandene Ausreißerdaten aus vorherigem Schritt */
proc sort data=ausreisser;
    by pumpe Zeitstempel;
run;

data fruehwarnung;
    set ausreisser;
    by pumpe;
    retain count_wert letzte_zeitpunkt;

    if first.pumpe then do;
        count_wert = 0;
        letzte_zeitpunkt = .;
    end;

    delta_stunden = intck('hour', letzte_zeitpunkt, Zeitstempel);

    if . < delta_stunden <= 2 then count_wert + 1;
    else count_wert = 1;

    if count_wert >= 3 then Warnung = "FRÜHWARNUNG: Mehrere Anomalien in kurzer Zeit";

    letzte_zeitpunkt = Zeitstempel;
run;

proc print data=fruehwarnung;
    where Warnung ne '';
    title "Frühwarnsystem: Kritische Zeitfenster";
run;


/* =============================================
   2. KPI-Dashboard
   → Durchschnittswerte, Anomalien pro Woche, Auslastung
============================================= */

/* 2a. Durchschnittswerte pro Pumpe */
proc means data=sensordaten_gesamt mean maxdec=1;
    class pumpe;
    var 'Drehzahl (RPM)'n 'Spannung (Volt)'n 'Durchflussmenge (Liter/Minute)'n 'Motortemperatur'n;
    title "Durchschnittswerte je Pumpe";
run;


/* 2b. Auslastung = Summe Durchflussmenge je Pumpe */
proc means data=sensordaten_gesamt sum maxdec=0;
    class pumpe;
    var 'Durchflussmenge (Liter/Minute)'n;
    title "Pumpenauslastung (Summe Durchfluss)";
run;


/* =============================================
   3. Maschinelles Lernen / Vorhersage
============================================= */

/* Entscheidungsbaum-Modell zur Temperaturvorhersage (Regression) */
proc hpsplit data=sensordaten_gesamt seed=12345;
    class pumpe;
    model 'Motortemperatur'n = 'Drehzahl (RPM)'n 'Spannung (Volt)'n 'Durchflussmenge (Liter/Minute)'n pumpe;
    grow variance; /* <- KORREKTE Methode für Regression */
    prune costcomplexity;
    title "Vorhersage-Modell: Motortemperatur (Regressionsbaum)";
run;
/* Test 2 
/* =============================================
   SAS Projekt: Analysebericht zu Anomalien und Temperatur
   Export als kompakter PDF-Report
============================================= */

/* PDF starten – nur ausgewählte Inhalte */
ods exclude all;
ods pdf file="/home/u64212633/sasuser.v94/pumpen_analysebericht.pdf" style=journal notoc;

/* Titelseite (korrekt zentriert mit title-Statements) */
title1 j=c font=Arial bold height=16pt "Pumpwerk GmbH – Auswertungsbericht";
title2 j=c font=Arial height=12pt "Anomalien, Durchschnittswerte, Temperaturen";
title3 j=c font=Arial height=10pt "Erstellt am %sysfunc(today(), date9.)";

proc odstext;
run;

title; /* Titel zurücksetzen */

/* Durchschnittswerte nur für PDF */
proc means data=sensordaten_gesamt mean maxdec=1 nway noprint;
    class pumpe;
    var 'Drehzahl (RPM)'n 'Spannung (Volt)'n 'Durchflussmenge (Liter/Minute)'n 'Motortemperatur'n;
    output out=mittelwerte(drop=_TYPE_ _FREQ_);
run;

proc print data=mittelwerte label noobs;
    title "Durchschnittswerte der Sensoren je Pumpe";
run;

/* Temperaturverlauf visualisieren */
proc sgplot data=sensordaten_gesamt;
    series x=Zeitstempel y='Motortemperatur'n / group=pumpe;
    title "Motortemperatur im Zeitverlauf";
run;

/* Übersicht der identifizierten Ausreißer */
proc print data=ausreisser label;
    var Zeitstempel pumpe 'Drehzahl (RPM)'n 'Spannung (Volt)'n 'Durchflussmenge (Liter/Minute)'n 'Motortemperatur'n Anomalie Empfehlung;
    title "Tabelle: Identifizierte Ausreißer mit Empfehlungen";
run;

/* Berechnung der Anomalieanzahl je Pumpe */
proc freq data=ausreisser noprint;
    tables pumpe / out=anomalie_anzahl;
run;

/* Nur in PDF enthalten: Balkendiagramm */
proc sgplot data=anomalie_anzahl;
    vbar pumpe / response=count datalabel;
    title "Anzahl erkannter Anomalien je Pumpe";
run;

/* PDF beenden und Ergebnisse wieder aktivieren */
ods pdf close;
