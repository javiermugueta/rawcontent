-- table for storing cost data
CREATE TABLE MYOCICOSTS(	
    "STARTTIME" TIMESTAMP , 
	"ENDTIME" TIMESTAMP, 
	"PRICEPEROCPU" NUMBER(6,4), 
	"OFICIALOCPUQUANTITY" NUMBER(5,1), 
	"AMOUNT" NUMBER(8,4), 
	"REMARKS" VARCHAR2(160 BYTE) COLLATE "USING_NLS_COMP", 
	 PRIMARY KEY ("STARTTIME")
   )  TABLESPACE "DATA" ;
/
-- in case it already exist ...
execute DBMS_CLOUD.DROP_CREDENTIAL (credential_name => 'OCICOSTSCRED');
/
-- package stuff
-- put here your variables
CREATE OR REPLACE PACKAGE oci_cloud_cost AS 
   procedure getcosts; 
   endpoint varchar2(128) := 'https://usageapi.eu-frankfurt-1.oci.oraclecloud.com';
   method varchar2(64) := '/20200107/usage';
   userocid varchar2(128) :=  'ocid1.user.oc1..aa...q';
   tenancyocid varchar2(128) := 'ocid1.tenancy.oc1..a...a';
   privatekey varchar2(4000) := 'MIIE...TBE=';
   fingerprint varchar2(64) := 'e...1';
end oci_cloud_cost;
/
-- the logic is get the data from midnight the day before yesterday and midnight yesterday
CREATE OR REPLACE PACKAGE BODY oci_cloud_cost AS 
procedure getcosts is
        resp DBMS_CLOUD_TYPES.resp;
        mydata varchar2(32000);
        po_obj        JSON_OBJECT_T;
        li_arr        JSON_ARRAY_T;
        li_item       JSON_ELEMENT_T;
        li_obj        JSON_OBJECT_T;
        timeUsageStarted timestamp;
        timeUsageEnded timestamp;
        computedQuantity number;
        computedAmount number;
        comienzo varchar2(64);
        fin varchar2(64);
    begin
        -- creating the credential if it doesn't exist
        begin
            DBMS_CLOUD.CREATE_CREDENTIAL (credential_name => 'OCICOSTSCRED',
                user_ocid => userocid, tenancy_ocid => tenancyocid, private_key => privatekey, fingerprint => fingerprint);
            exception
                when others then
                    null;
        end;
        -- the day before yesterday
        comienzo := to_char(sysdate -2 , 'YYYY') || '-' || to_char(sysdate -2 , 'MM') || '-' || to_char(sysdate -2 , 'DD') || 'T00:00:00.000Z';
        -- yesterday
        fin := to_char(sysdate - 1, 'YYYY') || '-' || to_char(sysdate - 1, 'MM') || '-' || to_char(sysdate - 1, 'DD') || 'T00:00:00.000Z';
        --dbms_output.put_line('comienzo: ' || comienzo);
        --dbms_output.put_line('fin: ' || fin);
        -- rest call
        resp := DBMS_CLOUD.send_request(credential_name => 'OCICOSTSCRED',uri =>
            endpoint || method , method => 'POST',
            body => UTL_RAW.cast_to_raw(JSON_OBJECT(
                'granularity' value 'HOURLY',
                'tenantId' value tenancyocid,
                'timeUsageStarted' value comienzo,
                'timeUsageEnded' value fin)) );
        -- get json result
        mydata :=  DBMS_CLOUD.get_response_text(resp);
        --dbms_output.put_line('result: ' || mydata);
        po_obj := JSON_OBJECT_T.parse(mydata);
        li_arr := po_obj.get_Array('items');
        -- iterate items in json
        FOR i IN 0 .. li_arr.get_size - 1 LOOP
            li_obj := JSON_OBJECT_T(li_arr.get(i));
            timeUsageStarted := li_obj.get_Timestamp('timeUsageStarted');
            timeUsageEnded := li_obj.get_Timestamp('timeUsageEnded');
            computedQuantity := li_obj.get_Number('computedQuantity');
            computedAmount := li_obj.get_Number('computedAmount');
            --dbms_output.put_line(timeUsageStarted || ' ' || timeUsageEnded || ' ' || computedQuantity || ' ' || computedAmount);
            begin
                -- insert values in table
                insert into MYOCICOSTS values ( timeUsageStarted, timeUsageEnded , 0.2101, computedQuantity, computedAmount, null );
                commit;
            exception
                when others then
                    -- duplicates exist in json data
                    insert into MYOCICOSTS values ( systimestamp, systimestamp , 0, 0, 0, 'duplicate' );
            end;
        END LOOP;
    exception
        when others then
            raise_application_error(-20001,'An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);
    end;
end oci_cloud_cost;
/
-- drop the schedule if it already exist
BEGIN
    DBMS_SCHEDULER.DROP_JOB(JOB_NAME => 'MYOCICOSTS');
END;
/
-- create daily schedule
BEGIN
  DBMS_SCHEDULER.CREATE_JOB (
   job_name           =>  'MYOCICOSTS',
   job_type           =>  'STORED_PROCEDURE',
   job_action         =>  'ADMIN.OCI_CLOUD_COST.GETCOSTS',
   repeat_interval    =>  'FREQ=DAILY;INTERVAL=1',
   auto_drop          =>   FALSE,
   comments           =>  'my oci costs');
END;
/
-- enable checdule
BEGIN
    DBMS_SCHEDULER.ENABLE('MYOCICOSTS');
END;
/
-- check whether the schedule is ok or not
SELECT
    JOB_NAME,
    ENABLED,
    RUN_COUNT,
    REPEAT_INTERVAL,
    STATE,
    MAX_FAILURES,
    LAST_START_DATE,
    LAST_RUN_DURATION
FROM
    DBA_SCHEDULER_JOBS
WHERE
    JOB_NAME = 'MYOCICOSTS'
/
--
-- test the procedure, some data should appear in the table
--
-- cleansing ...
delete from myocicosts;
/
commit;
/
-- test
begin
     oci_cloud_cost.getcosts;
end;
/
--query
select * from myocicosts where remarks is null order by starttime asc
/