/* PDF starten */
 ods pdf file="/home/u64212633/sasuser.v94/kpi_dashboard_pumpwerk.pdf" style=journal notoc;
 
 /* Titel */
 title1 j=c font=Arial bold height=16pt "Pumpwerk GmbH – KPI-Dashboard";
 title2 j=c font=Arial height=12pt "Kunden- & Marktanalyse (Januar–April)";
 title3 j=c font=Arial height=10pt "Stand: %sysfunc(today(), date9.)";
 proc odstext; run;
 title;
 
