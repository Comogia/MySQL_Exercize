/*********************************************
 * Corso di Basi di dati 2018/19             *
 * Esercizio Bonus 1                         *
 * Giacomo Gualandi - matricola 657814       *
 * Email - giacomo.gualandi3@studio.unibo.it *
 **********************************************/


DROP database DBSTV;
create database DBSTV; #if not exist
use DBSTV;

create table SERIE(
	Nome varchar(30), 
	Genere ENUM ('Commedy','Drama','Action','Thriller','Horror'), 
	Nazione varchar(10) NOT NULL, 
	Regista varchar(30),

	PRIMARY KEY(Nome)

) ENGINE=INNODB;

create table STAGIONE(
	NomeSerie varchar(30),
	NumeroStagione smallint,
	TotalePuntate smallint, 
	Anno year(4), 
	Stato ENUM ('PROGRAMMATA','IN SVOLGIMENTO','CONCLUSA') DEFAULT 'PROGRAMMATA',
	PRIMARY KEY(NomeSerie, NumeroStagione),
	FOREIGN KEY(NomeSerie) REFERENCES SERIE(Nome) 
		ON DELETE CASCADE

) ENGINE=INNODB;

create table PUNTATA(
	NomeSerie varchar(30), 
	NumeroStagione smallint, 
	NumeroPuntata smallint, 
	Durata smallint,
	Titolo varchar(30) DEFAULT 'Descrizione Assente',

	PRIMARY KEY(NomeSerie, NumeroStagione, NumeroPuntata),
	
#	FOREIGN KEY(NomeSerie) REFERENCES STAGIONE(NomeSerie) 
#		ON DELETE CASCADE,
	FOREIGN KEY(NomeSerie, NumeroStagione) REFERENCES STAGIONE(NomeSerie, NumeroStagione)
		ON DELETE CASCADE
) ENGINE=INNODB;

create table UTENTE(
	Email varchar(30), 
	Nome varchar(25), 
	Cognome varchar(20), 
	Annonascita year(4),

	PRIMARY KEY(Email)

) ENGINE=INNODB;

create table COMMENTO(
	Codice int AUTO_INCREMENT, 
	EmailUtente varchar(30), 
	NomeSerie varchar(30), 
	NumeroStagione smallint, 
	NumeroPuntata smallint, 
	Testo varchar(200), 
	Voto smallint CHECK((Voto is not null)and(Voto>=1)and(Voto<=10)),/* utilizzo asserzione per definire il vincolo? */
#	Data DATETIME DEFAULT CURRENT_TIMESTAMP,
	Data timestamp DEFAULT NOW(),

	PRIMARY KEY(Codice),

	FOREIGN KEY(EmailUtente) REFERENCES UTENTE(Email)
       		ON DELETE CASCADE 
		ON UPDATE CASCADE,
#	FOREIGN KEY(NomeSerie) REFERENCES PUNTATA(NomeSerie),
#	FOREIGN KEY(NomeSerie, NumeroStagione) REFERENCES PUNTATA(NomeSerie, NumeroStagione),
	FOREIGN KEY(NomeSerie, NumeroStagione, NumeroPuntata) REFERENCES PUNTATA(NomeSerie, NumeroStagione, NumeroPuntata)

) ENGINE=INNODB;

use DBSTV;

/* Creo un trigger per verificare se la stagione è in corso  */

DELIMITER |
CREATE TRIGGER AggiornaStatoStagione 
	AFTER INSERT ON PUNTATA
	FOR EACH ROW
	BEGIN 
		DECLARE countPuntate INT DEFAULT 0;
		DECLARE puntateMax INT DEFAULT 0;
		# Il cursore mi permette di assegnare ad una variabile il valore di ritorno di una select, invece che avere una tabella
		DECLARE cursoreA CURSOR FOR SELECT count(*) FROM PUNTATA WHERE ((NomeSerie=NEW.NomeSerie)AND (NumeroStagione=NEW.NumeroStagione));
		DECLARE cursoreB CURSOR FOR SELECT TotalePuntate FROM STAGIONE WHERE ((NomeSerie=NEW.NomeSerie)AND(NumeroStagione=NEW.NumeroStagione));

		OPEN cursoreA;
		FETCH cursoreA INTO countPuntate;
		CLOSE cursoreA;
		
#		CALL printf(countPuntate);

		OPEN cursoreB;
		FETCH cursoreB INTO puntateMax;
		CLOSE cursoreB;
		
#		CALL printf(puntateMax);

		IF countPuntate < puntateMax THEN 
		UPDATE STAGIONE SET STAGIONE.Stato = 'IN SVOLGIMENTO' WHERE ((NomeSerie=NEW.NomeSerie)AND(NumeroStagione=NEW.NumeroStagione));			
		ELSE UPDATE STAGIONE SET STAGIONE.Stato = 'CONCLUSA' WHERE ((NomeSerie=NEW.NomeSerie)AND(NumeroStagione=NEW.NumeroStagione));
		END IF;
	END;
|
DELIMITER ;

/* Popolamento da Files*/
LOAD DATA LOCAL INFILE '/home/giacomo/Documenti/Documenti Uni/Basi di dati/2018_19/Esercizio_bonus_1/serie.txt' INTO TABLE SERIE;
LOAD DATA LOCAL INFILE '/home/giacomo/Documenti/Documenti Uni/Basi di dati/2018_19/Esercizio_bonus_1/stagioni.txt' INTO TABLE STAGIONE SET Stato= 'PROGRAMMATA';
LOAD DATA LOCAL INFILE '/home/giacomo/Documenti/Documenti Uni/Basi di dati/2018_19/Esercizio_bonus_1/puntate.txt' INTO TABLE PUNTATA;
LOAD DATA LOCAL INFILE '/home/giacomo/Documenti/Documenti Uni/Basi di dati/2018_19/Esercizio_bonus_1/utenti.txt' INTO TABLE UTENTE;

#select * FROM SERIE;
#select * FROM STAGIONE;
#select * FROM PUNTATA;
#select * FROM UTENTE;


/* Creazione di Stored Procedures*/
DELIMITER |
CREATE PROCEDURE NuovaStagione (IN NomeSerieIn varchar(30), IN NumeroStagioneIn smallint, IN TotalePuntateIn smallint, IN AnnoIn year(4))
BEGIN
	DECLARE fine INT DEFAULT 0;
	DECLARE temp varchar(20);
	DECLARE varcheck INT DEFAULT 0;
	DECLARE cursore2 CURSOR FOR SELECT Stato FROM STAGIONE WHERE (STAGIONE.NomeSerie=NomeSerieIn);

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET fine=1;

	OPEN cursore2;

	ciclo: WHILE NOT fine DO
		FETCH cursore2 into temp;
#		CLOSE cursore2;

		IF (temp = 'IN SVOLGIMENTO' OR temp =  'PROGRAMMATA') THEN
		     SET  varcheck = 1;
#			CALL printf(varcheck);	
		END IF;
	END WHILE ciclo;

		IF varcheck != 1 THEN 
		
			/*Transazione*/
			SET AUTOCOMMIT = 0;
			START TRANSACTION;
		#	INSERT into STAGIONE (NomeSerie, NumeroStagione, TotalePuntate, Anno) VALUES(NomeSerieIn, NumeroStagioneIn, TotalePuntateIn, AnnoIn, DEFAULT);
				INSERT into STAGIONE (NomeSerie, NumeroStagione, TotalePuntate, Anno) VALUES(NomeSerieIn, NumeroStagioneIn, TotalePuntateIn, AnnoIn);
			COMMIT;
		
#			CALL printf('Insert ok!');
		ELSE

			CALL printf('[ERRORE] Esiste già una stagione in attesa/corso di svolgimento');

		END IF;
END;
|
DELIMITER ;

/*procedura b*/
/*Con un ciclo verifico che la stagione sia in svolgimento/programmata, poi con l'if eseguo le due operazioni richiste nei due casi */
DELIMITER |
CREATE PROCEDURE NuovaPuntata (IN NomeSerieIn varchar(30), IN NumeroStagioneIn smallint, IN NumeroPuntataIn smallint, IN DurataIn smallint, IN TitoloIn varchar(30))
BEGIN

	DECLARE fine2 INT DEFAULT 0;
	DECLARE temp2 varchar(30) ;
	DECLARE varConclusa INT DEFAULT 0;
	DECLARE cursore3 CURSOR FOR SELECT Stato FROM STAGIONE WHERE ((STAGIONE.NomeSerie=NomeSerieIn)AND(STAGIONE.NumeroStagione=NumeroStagioneIn));

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET fine2=1;

	OPEN cursore3;

	/* Il seguente ciclo si poteva fare anche così:
		IF (temp2 = 'CONCLUSA') THEN
			SET varConclusa=1;
		END IF;
	 */
	cycle: WHILE not fine2 DO
		FETCH cursore3 INTO temp2;
		IF (temp2 = 'IN SVOLGIMENTO' OR temp2='PROGRAMMATA')	THEN
			SET varConclusa = 0;
		ELSE 
			SET varConclusa =1;
		END IF;
	END WHILE cycle;
	CLOSE cursore3;
	
#	CALL printf(temp2);

	IF (varConclusa=0)	THEN

			/*Transazione*/
			SET AUTOCOMMIT = 0;
			START TRANSACTION;
				INSERT into PUNTATA (NomeSerie, NumeroStagione, NumeroPuntata, Durata, Titolo) VALUES(NomeSerieIn, NumeroStagioneIn, NumeroPuntataIn, DurataIn, TitoloIn);
			COMMIT;
	ELSE
		CALL printf('[ERRORE] La stagione è completa, non è possibile aggiungere puntate!');
	
	END IF;

END;

|
DELIMITER ;

/*procedura c*/
/*Eseguo un ciclo che setta una variabile ad 1 nel caso in cui sia presente un commento dell'utente, poi con due if nidificati verifico le condizioni poste*/
DELIMITER |
CREATE PROCEDURE NuovoCommento (IN EmailUtente varchar(30), IN NomeSerie varchar(30), IN NumeroStagione smallint, IN NumeroPuntata smallint, IN Testo varchar(200), IN Voto smallint)
BEGIN
	DECLARE fine3 INT DEFAULT 0; 
	DECLARE temp3 varchar(30);
	DECLARE varMailUtente varchar(30);
	DECLARE varAlreadyCommented INT DEFAULT 0; /*Utilizzo questa variabile come flag, viene settata ad 1 se l'utente ha già commentato */
	DECLARE cursore4 CURSOR FOR SELECT Stato FROM STAGIONE WHERE ((STAGIONE.NomeSerie=NomeSerie)AND(STAGIONE.NumeroStagione=NumeroStagione));

	DECLARE cursore5 CURSOR FOR SELECT EmailUtente FROM COMMENTO WHERE ((COMMENTO.NomeSerie=NomeSerie)AND(COMMENTO.NumeroStagione=NumeroStagione)AND(COMMENTO.NumeroPuntata=NumeroPuntata)AND(COMMENTO.EmailUtente=EmailUtente));

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET fine3=1;
	OPEN cursore5;
	cycle: WHILE NOT fine3 DO
		FETCH cursore5 INTO varMailUtente;
		IF varMailUtente = EmailUtente THEN
			SET varAlreadyCommented = 1;
		END IF;
	END WHILE cycle;

	OPEN cursore4;
	FETCH cursore4 INTO temp3;
	CLOSE cursore4;
	IF (temp3='IN SVOLGIMENTO'AND Voto>=1 AND Voto<=10) THEN		
		IF (varAlreadyCommented = 1) THEN
			CALL printf('[ERRORE] COMMENTO già presente per l utente');

		ELSE
			SET AUTOCOMMIT = 0;
			START TRANSACTION;
				INSERT INTO COMMENTO (EmailUtente, NomeSerie, NumeroStagione, NumeroPuntata, Testo, Voto) VALUES (EmailUtente, NomeSerie, NumeroStagione, NumeroPuntata, Testo, Voto);
			COMMIT;
		END IF;
	ELSE	
		CALL printf('[ERRORE] COMMENTO non inserito, Valori in input non validi');
	END IF;
END

|
DELIMITER ;



/*procedura d*/
/*Utilizzo due query nidificate, nella prima seleziono gli utenti che hanno fatto commenti e poi con il costrutto NOT IN faccio la differenza con quelli che sono nella tabella UTENTE; nella seconda invece rimuovo quelli che hanno fatto commenti prima del 1.1.2017 
Inizialmente avevo pensato di usare la sola query presente nei commenti, ma non funziona perchè nel test vengono inseriti commenti senza una data specificata */


DELIMITER |
CREATE PROCEDURE EliminaDatiObsoleti()
BEGIN

/*
       	#SELECT Email FROM UTENTE WHERE Email NOT IN
	DELETE FROM UTENTE WHERE Email NOT IN
		(SELECT EmailUtente FROM COMMENTO WHERE Data > 2017-01-01);
*/

	DELETE FROM UTENTE WHERE Email NOT IN
		(SELECT EmailUtente FROM COMMENTO);

	
	DELETE FROM UTENTE WHERE Email IN
		(SELECT EmailUtente FROM COMMENTO WHERE Data < '2017-01-01');


END;
|
DELIMITER ;


/* 5) Implementare le viste */
/* Vista a)*/
CREATE VIEW LISTA_SERIE_TV_CORRENTI(NomeSerie, Genere, Nazione, NumeroStagione, TotalePuntate) AS
	SELECT Nome, Genere, Nazione, NumeroStagione, TotalePuntate
	FROM STAGIONE AS ST, SERIE AS SE
        WHERE ((SE.Nome = ST.NomeSerie)AND(Stato = 'IN SVOLGIMENTO'));	


/* Vista b)*/
CREATE VIEW LISTA_SERIE_TV_CON_DURATA(NomeSerie, DurataTotale) AS
	SELECT NomeSerie, SUM(Durata)  AS DurataTotale
	FROM PUNTATA
	GROUP BY NomeSerie
	ORDER BY DurataTotale ASC;

/* Vista c)*/	
CREATE VIEW SERIE_TOP(NomeSerie, NomeRegista, VotoMedio) AS
	SELECT NomeSerie, Regista, AVG(Voto)
	FROM COMMENTO AS C, SERIE AS S
	WHERE (C.NomeSerie=S.Nome)
	GROUP BY NomeSerie
	HAVING count(*) >= 3
	ORDER BY AVG(Voto) DESC;

/* Vista d*/
CREATE VIEW SERIE_USA_LONGEVE (NomeSerie, Genere) AS
	SELECT Nome, Genere
	FROM SERIE AS SE, STAGIONE AS ST
        WHERE ((SE.Nome = ST.NomeSerie)AND(Stato = 'CONCLUSA'))	
	GROUP BY NomeSerie
	HAVING count(*) >= 3;
	

/*Procedura Print*/
DELIMITER |
CREATE PROCEDURE printf(mytext TEXT)
BEGIN
	  select mytext as ``;
END;
|
DELIMITER ;

/*Creazione nuovo utente*/
#CREATE USER utenteweb;
#CREATE USER utenteweb@localhost;
#grant SELECT on LISTA_SERIE_TV_CORRENTI, LISTA_SERIE_TV_CON_DURATA, SERIE_TOP, SERIE_USA_LONGEVE to utenteweb;  

#Esempio utilizzo
#CALL printf("The end");


