--run the alter command in sqlplus.
alter session set NLS_DATE_FORMAT='yyyy/mm/dd:hh:mi:ssam';

spool mig-1.log;
select sysdate from dual;

INSERT INTO PRIMARY_DS_TYPES ( PRIMARY_DS_TYPE_ID,  PRIMARY_DS_TYPE) SELECT ID, TYPE FROM CMS_DBS_PROD_GLOBAL.PRIMARYDSTYPE;
commit;
select 'Done insert PRIMARY_DS_TYPES' from dual;
select sysdate from dual;

INSERT INTO PRIMARY_DATASETS(PRIMARY_DS_ID, PRIMARY_DS_NAME, PRIMARY_DS_TYPE_ID, CREATION_DATE, CREATE_BY)  
SELECT PD.ID, PD.NAME, PD.TYPE, PD.CREATIONDATE, PS.DISTINGUISHEDNAME 
FROM CMS_DBS_PROD_GLOBAL.PRIMARYDATASET PD join CMS_DBS_PROD_GLOBAL.PERSON PS ON  PS.ID=PD.CREATEDBY;
commit;
select 'Done insert PRIMARY_DATASETS' from dual;
select sysdate from dual;

INSERT INTO APPLICATION_EXECUTABLES (APP_EXEC_ID, APP_NAME) SELECT ID, EXECUTABLENAME FROM CMS_DBS_PROD_GLOBAL.APPEXECUTABLE;
INSERT INTO RELEASE_VERSIONS ( RELEASE_VERSION_ID, RELEASE_VERSION ) SELECT ID, VERSION FROM CMS_DBS_PROD_GLOBAL.APPVERSION;
INSERT INTO PARAMETER_SET_HASHES ( PARAMETER_SET_HASH_ID, PSET_HASH, NAME ) SELECT ID, HASH, NAME FROM CMS_DBS_PROD_GLOBAL.QUERYABLEPARAMETERSET;

--FAKING APPLICATIONFAMILY AS OUTPUT_MODULE_LABEL(is it right?), THIS KEEPS THE UNIQUENESS
--GLOBAL_TAG is "UNKNOWN"
--APP_EXEC_ID, RELEASE_VERSION_ID, PARAMETER_SET_HASH_ID, OUTPUT_MODULE_LABEL, GLOBAL_TAG construct the uniqueness of a config.
--Need to update GLOBAL_TAG from DBS2's PROCESSEDDATASET table
INSERT INTO OUTPUT_MODULE_CONFIGS ( OUTPUT_MOD_CONFIG_ID, APP_EXEC_ID, RELEASE_VERSION_ID, PARAMETER_SET_HASH_ID, 
                                    OUTPUT_MODULE_LABEL, GLOBAL_TAG, CREATION_DATE, CREATE_BY) 
SELECT AL.ID, AL.EXECUTABLENAME, AL.APPLICATIONVERSION, AL.PARAMETERSETID, AL.APPLICATIONFAMILY, 'UNKNOWN', AL.CREATIONDATE, PS.DISTINGUISHEDNAME  
FROM CMS_DBS_PROD_GLOBAL.ALGORITHMCONFIG AL JOIN CMS_DBS_PROD_GLOBAL.PERSON PS on PS.ID=AL.CREATEDBY;
commit;
select 'Done insert OUTPUT_MODULE_CONFIGS' from dual;
select sysdate from dual;


INSERT INTO PHYSICS_GROUPS ( PHYSICS_GROUP_ID, PHYSICS_GROUP_NAME) SELECT ID, PHYSICSGROUPNAME FROM CMS_DBS_PROD_GLOBAL.PHYSICSGROUP;

--WE WILL USE THE STATUS (FROM DBS-2) TO FILL IN TYPE IN DBS-3, LATER WE CAN FIX THIS
INSERT INTO DATASET_ACCESS_TYPES (DATASET_ACCESS_TYPE_ID, DATASET_ACCESS_TYPE) SELECT ID, STATUS FROM CMS_DBS_PROD_GLOBAL.PROCDSSTATUS WHERE
STATUS in ('VALID','DELETED', 'INVALID', 'PRODUCTION', 'DEPRECATED');

--ADD a new type "UNKOWN_DBS2_TYPE" with ID=100 to map the VALID and INVALID datasets in DBS2
--INSERT INTO DATASET_ACCESS_TYPES (DATASET_ACCESS_TYPE_ID, DATASET_ACCESS_TYPE) values(100, 'UNKNOWN_DBS2_TYPE');

INSERT INTO DATA_TIERS ( DATA_TIER_ID, DATA_TIER_NAME,CREATION_DATE, CREATE_BY ) SELECT DT.ID, DT.NAME, DT.CREATIONDATE, PS.DISTINGUISHEDNAME
FROM CMS_DBS_PROD_GLOBAL.DATATIER DT join CMS_DBS_PROD_GLOBAL.PERSON PS ON  PS.ID=DT.CREATEDBY
;
INSERT INTO ACQUISITION_ERAS ( ACQUISITION_ERA_NAME ) SELECT DISTINCT AQUISITIONERA FROM CMS_DBS_PROD_GLOBAL.PROCESSEDDATASET where AQUISITIONERA IS NOT NULL;

INSERT INTO PROCESSED_DATASETS ( PROCESSED_DS_NAME ) SELECT DISTINCT NAME FROM CMS_DBS_PROD_GLOBAL.PROCESSEDDATASET;
commit;
select 'Done insert PROCESSED_DATASETS ' from dual;
select sysdate from dual;

--11/1/2011. YG
--Below Comment is not correct anymore. Left it there, just for reference to the old code.
--INSERT ALL DATASETS AS INVALID (IS_DATASET_VALID==0) and DATASET_ACCESS_TYPE="UNKNOWN_DBS2_TYPE" (DATASET_ACCESS_TYPE_ID=100)

INSERT INTO DATASETS (
	 DATASET_ID,                               
	  DATASET,
	   IS_DATASET_VALID,                         
	    PRIMARY_DS_ID,                            
	     PROCESSED_DS_ID,                          
	      DATA_TIER_ID,          
	       DATASET_ACCESS_TYPE_ID,      
	        ACQUISITION_ERA_ID,
		 PHYSICS_GROUP_ID,
		  XTCROSSSECTION,
		    CREATION_DATE,
		     CREATE_BY,
		      LAST_MODIFICATION_DATE,
		       LAST_MODIFIED_BY
	)
SELECT DS.ID, '/' || P.NAME || '/' || DS.NAME || '/' || DT.NAME, 1, P.ID, PDS.PROCESSED_DS_ID, DT.ID, DS.STATUS,
       ACQ.ACQUISITION_ERA_ID, DS.PHYSICSGROUP, DS.XTCROSSSECTION,
       DS.CREATIONDATE, PDCB.DISTINGUISHEDNAME, DS.LASTMODIFICATIONDATE, PDLM.DISTINGUISHEDNAME
       FROM CMS_DBS_PROD_GLOBAL.PROCESSEDDATASET DS
       JOIN CMS_DBS_PROD_GLOBAL.PRIMARYDATASET P
           ON P.ID=DS.PRIMARYDATASET
	   JOIN CMS_DBS_PROD_GLOBAL.DATATIER DT
	       ON DT.ID=DS.DATATIER
	       JOIN PROCESSED_DATASETS PDS
	           ON PDS.PROCESSED_DS_NAME=DS.NAME
		   LEFT OUTER JOIN ACQUISITION_ERAS ACQ
		       ON ACQ.ACQUISITION_ERA_NAME=DS.AQUISITIONERA
		       LEFT OUTER JOIN PHYSICS_GROUPS PG
		           ON DS.PHYSICSGROUP=PG.PHYSICS_GROUP_ID
			   LEFT OUTER JOIN CMS_DBS_PROD_GLOBAL.PERSON PDCB
			       ON DS.CREATEDBY=PDCB.ID
			       LEFT OUTER JOIN CMS_DBS_PROD_GLOBAL.PERSON PDLM
			           ON DS.LASTMODIFIEDBY=PDLM.ID;   

commit;
select 'Done insert DATASET' from dual;
select sysdate from dual;

--FIXME: Update global_tag.

--No needed. YG 11/1/2011
--There are no single dataset labeled as VALIDRO in DBS2 althrough VALIDRO is in the processeddsstatus.
--SET THE STATUS OF DATASETS AS VALID, IF THEY ARE MARKED AS 'VALID', 'RO', 'PRODUCTION','IMPORTED' or 'EXPORTED' IN DBS-2
--UPDATE DATASETS DS SET DS.IS_DATASET_VALID=1 WHERE DS.DATASET_ID IN (SELECT PDS.ID FROM CMS_DBS_PROD_GLOBAL.PROCESSEDDATASET PDS, CMS_DBS_PROD_GLOBAL.PROCDSSTATUS ST
--WHERE ST.ID=PDS.STATUS AND ST.STATUS in ('VALID', 'RO', 'PRODUCTION', 'IMPORTED', 'EXPORTED'));
--SET THE TYPE OF DATASETS BASED ON "STATUS" IN DBS-2, But for the dataset with 'VALID' status in DBS2, Not sure what we should set its dataset access type in dbs3 
--UPDATE DATASETS DS SET DS.DATASET_ACCESS_TYPE_ID=(SELECT DATASET_ACCESS_TYPE_ID FROM DATASET_ACCESS_TYPES WHERE DATASET_ACCESS_TYPE='PRODUCTION') 
--WHERE DS.DATASET_ID IN (SELECT PDS.ID FROM CMS_DBS_PROD_GLOBAL.PROCESSEDDATASET PDS, CMS_DBS_PROD_GLOBAL.PROCDSSTATUS ST WHERE ST.ID=PDS.STATUS AND ST.STATUS='PRODUCTION');

--UPDATE DATASETS DS SET DS.DATASET_ACCESS_TYPE_ID=(SELECT DATASET_ACCESS_TYPE_ID FROM DATASET_ACCESS_TYPES WHERE DATASET_ACCESS_TYPE='DELETED') 
--WHERE DS.DATASET_ID IN (SELECT PDS.ID FROM CMS_DBS_PROD_GLOBAL.PROCESSEDDATASET PDS, CMS_DBS_PROD_GLOBAL.PROCDSSTATUS ST WHERE ST.ID =PDS.STATUS AND ST.STATUS='DELETED');

--UPDATE DATASETS DS SET DS.DATASET_ACCESS_TYPE_ID=(SELECT DATASET_ACCESS_TYPE_ID FROM DATASET_ACCESS_TYPES WHERE DATASET_ACCESS_TYPE='DEPRECATED') 
--WHERE DS.DATASET_ID IN (SELECT PDS.ID FROM CMS_DBS_PROD_GLOBAL.PROCESSEDDATASET PDS, CMS_DBS_PROD_GLOBAL.PROCDSSTATUS ST WHERE ST.ID=PDS.STATUS AND ST.STATUS='DEPRECATED');

--UPDATE DATASETS DS SET DS.DATASET_ACCESS_TYPE_ID=(SELECT DATASET_ACCESS_TYPE_ID FROM DATASET_ACCESS_TYPES WHERE DATASET_ACCESS_TYPE='RO')
--WHERE DS.DATASET_ID IN (SELECT PDS.ID FROM CMS_DBS_PROD_GLOBAL.PROCESSEDDATASET PDS, CMS_DBS_PROD_GLOBAL.PROCDSSTATUS ST WHERE ST.ID=PDS.STATUS AND
--ST.STATUS='RO');

--UPDATE DATASETS DS SET DS.DATASET_ACCESS_TYPE_ID=(SELECT DATASET_ACCESS_TYPE_ID FROM DATASET_ACCESS_TYPES WHERE DATASET_ACCESS_TYPE='EXPORTED')
--WHERE DS.DATASET_ID IN (SELECT PDS.ID FROM CMS_DBS_PROD_GLOBAL.PROCESSEDDATASET PDS, CMS_DBS_PROD_GLOBAL.PROCDSSTATUS ST WHERE ST.ID=PDS.STATUS AND
--ST.STATUS='EXPORTED');

--UPDATE DATASETS DS SET DS.DATASET_ACCESS_TYPE_ID=(SELECT DATASET_ACCESS_TYPE_ID FROM DATASET_ACCESS_TYPES WHERE DATASET_ACCESS_TYPE='IMPORTED')
--WHERE DS.DATASET_ID IN (SELECT PDS.ID FROM CMS_DBS_PROD_GLOBAL.PROCESSEDDATASET PDS, CMS_DBS_PROD_GLOBAL.PROCDSSTATUS ST WHERE ST.ID=PDS.STATUS AND
--ST.STATUS='IMPORTED');

commit;

--set dataset_access_type='UNKNOWN_DBS2_TYPE' for datasets with status='VALID' or 'INVALID' in dbs2
--update dataset_access_types set dataset_access_type='UNKNOWN_DBS2_TYPE' where dataset_access_type='VALID';

select 'Done update DATASET' from dual;
select sysdate from dual;


INSERT INTO DATASET_PARENTS(THIS_DATASET_ID, PARENT_DATASET_ID)
SELECT  DSP.THISDATASET, DSP.ITSPARENT FROM CMS_DBS_PROD_GLOBAL.PROCDSPARENT DSP;

commit;
select 'Done inser DATASET_PARENTS' from dual;
select sysdate from dual;

--need to rethink YG
INSERT INTO DATASET_OUTPUT_MOD_CONFIGS(DS_OUTPUT_MOD_CONF_ID, DATASET_ID, OUTPUT_MOD_CONFIG_ID)
SELECT PA.ID, PA.DATASET, PA.ALGORITHM FROM CMS_DBS_PROD_GLOBAL.PROCALGO PA;

commit;
select ' Done insert DATASET_OUTPUT_MOD_CONFIGS' from dual;
select sysdate from dual;
spool off;