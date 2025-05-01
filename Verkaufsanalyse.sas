/* =============================================
   SAS Projekt: Kunden- & Marktanalyse Pumpwerk GmbH
   Ziel: Verkaufsdaten analysieren (Jan–Apr)
============================================= */

/* =============================================
   1. Datenimport aus Excel
   Datei: kundenanalyse_pumpwerk_januar-april.xlsx, Sheet: Verkaufsanalyse
============================================= */
proc import datafile="/home/u64212633/sasuser.v94/kundenanalyse_pumpwerk_januar-april.xlsx"
    out=verkaufsanalyse
    dbms=xlsx
    replace;
    sheet="Verkaufsanalyse";
run;

/* =============================================
   2. Verkaufsentwicklung über Zeit je Produkt
   → zeigt, wie sich Verkäufe über die Zeit entwickeln
   → Daten vorher nach Datum sortieren!
============================================= */

/* Sortiere Daten nach Datum für sauberen Plot */
proc sort data=verkaufsanalyse out=verkaufsanalyse_sortiert;
    by Datum;
run;

/* Liniendiagramm (Zeitreihe) je Produkt */
proc sgplot data=verkaufsanalyse_sortiert;
    series x=Datum y='Verkaufte Stückzahl'n / group=Produkt;
    title "Verkaufsentwicklung über Zeit je Produkt";
run;

/* =============================================
   3. Reklamationsrate nach Produkt und Region
============================================= */
data reklamationsraten;
    set verkaufsanalyse;
    if 'Verkaufte Stückzahl'n > 0 then Reklamationsrate = Reklamationen / 'Verkaufte Stückzahl'n;
run;

proc means data=reklamationsraten mean maxdec=3;
    class Produkt Region;
    var Reklamationsrate;
    title "Ø Reklamationsrate nach Produkt und Region";
run;

/* =============================================
   4. Zusammenhang: Bewertung ↔ Rückläufer
============================================= */
proc sgplot data=verkaufsanalyse;
    scatter x='Durchschnitliche Bewertung'n y=Rückläufer / group=Produkt;
    title "Zusammenhang: Bewertung vs. Rückläufer";
run;

proc corr data=verkaufsanalyse;
    var 'Durchschnitliche Bewertung'n Rückläufer;
    title "Korrelation: Bewertung und Rückläufer";
run;

/* =============================================
   5. Zeitreihe: Verkaufszahlen nach Produkt/Region/Vertriebsweg
============================================= */
proc means data=verkaufsanalyse nway;
    class Datum Produkt Region Vertriebsweg;
    var 'Verkaufte Stückzahl'n;
    output out=verkaufstrend sum=Summe_Verkaeufe;
run;

proc sgplot data=verkaufstrend;
    series x=Datum y=Summe_Verkaeufe / group=Produkt;
    title "Zeitreihe: Verkaufszahlen je Produkt";
run;

/* =============================================
   6. Verkäufe nach Produkt und Region
============================================= */
proc freq data=verkaufsanalyse;
    tables Produkt*Region / norow nocol nopercent;
    title "Verkäufe nach Produkt und Region";
run;

/* =============================================
   7. Bewertung & Rückläufer nach Vertriebsweg
============================================= */
proc means data=verkaufsanalyse mean maxdec=2;
    class Vertriebsweg;
    var 'Durchschnitliche Bewertung'n Rückläufer;
    title "Ø Bewertung & Rückläufer nach Vertriebsweg";
run;

proc sgplot data=verkaufsanalyse;
    vbox 'Durchschnitliche Bewertung'n / category=Vertriebsweg;
    title "Bewertungsverteilung nach Vertriebsweg";
run;

/* =============================================
   8. Korrelation Bewertung ↔ Folgekäufe
============================================= */
proc corr data=verkaufsanalyse;
    var 'Durchschnitliche Bewertung'n Folgekäufe;
    title "Korrelation: Bewertung und Folgekäufe";
run;


/* =============================================
   9. Ø Bewertung & Rückläufer je Vertriebsweg + PDF aufbauen
============================================= */
/* PDF starten */
 ods pdf file="/home/u64212633/sasuser.v94/kpi_dashboard_pumpwerk.pdf" style=journal notoc;
 
 /* Titel */
 title1 j=c font=Arial bold height=16pt "Pumpwerk GmbH – KPI-Dashboard";
 title2 j=c font=Arial height=12pt "Kunden- & Marktanalyse (Januar–April)";
 title3 j=c font=Arial height=10pt "Stand: %sysfunc(today(), date9.)";
 proc odstext; run;
 title;
 
proc means data=verkaufsanalyse mean maxdec=2 nway;
    class Vertriebsweg;
    var 'Durchschnitliche Bewertung'n Rückläufer;
    title "Ø Bewertung & Rückläufer nach Vertriebsweg";
run;


/* =============================================
   10. Gesamtverkäufe je Region (Balkendiagramm)
============================================= */
proc sql;
    create table region_summe as
    select Region, sum('Verkaufte Stückzahl'n) as Gesamt_Stueckzahl
    from verkaufsanalyse
    group by Region;
quit;

proc sgplot data=region_summe;
    vbar Region / response=Gesamt_Stueckzahl datalabel;
    title "Gesamtverkäufe je Region";
run;


/* =============================================
   11. Rücklaufquote je Produkt
============================================= */
data ruecklaufrate;
    set verkaufsanalyse;
    if 'Verkaufte Stückzahl'n > 0 then Ruecklaufquote = Rückläufer / 'Verkaufte Stückzahl'n;
run;

proc means data=ruecklaufrate mean maxdec=3 nway;
    class Produkt;
    var Ruecklaufquote;
    title "Ø Rücklaufquote pro Produkt";
run;


/* =============================================
   12. Folgekäufe je Produkt (TOP 5)
============================================= */
proc sql;
    create table folge_top5 as
    select Produkt, sum(Folgekäufe) as Gesamt_Folgekauf
    from verkaufsanalyse
    group by Produkt
    order by Gesamt_Folgekauf desc;
quit;

proc sgplot data=folge_top5(obs=5);
    vbar Produkt / response=Gesamt_Folgekauf datalabel;
    title "Top 5 Produkte mit den meisten Folgekäufen";
run;


/* =============================================
   13. Verlauf: Verkäufe über Zeit je Produkt (= Pumpe)
============================================= */

/* Vorher sortieren für sauberes Linien-Diagramm */
proc sort data=verkaufsanalyse;
    by Produkt Datum;
run;

proc sgplot data=verkaufsanalyse;
    series x=Datum y='Verkaufte Stückzahl'n / group=Produkt;
    title "Verkaufsverlauf über Zeit je Produkt";
run;


/* PDF beenden */
ods pdf close;


