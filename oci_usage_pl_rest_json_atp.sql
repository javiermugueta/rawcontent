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
   userocid varchar2(128) :=  'ocid1.user.oc1..aaaaaaaaeqnv73xqbr4s3mv46wihbskl7ejybncjtslojjgt6dbvpe5htroq';
   tenancyocid varchar2(128) := 'ocid1.tenancy.oc1..aaaaaaaaeicdft76mmsryhfleu2zqsbfnvaljkbkevjpnkznnaqdbhtdadpa';
   privatekey varchar2(4000) := 'MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCgAJLhYrvtm6xvgsIJDFzqTKzvLRgromTyRUgZvMJriW3ebPE1RrcwyO7O6BBU1yYzGK4D8I1EC61g+hvy5c+dt2hDIbrcCqMmCr9ebMVgBucXIIkaskUJxHlWC6ZEO/PB2lg+rwWJi55gaJGSXcw5ElgBYeDaLdrfnki4WC6sT7iu4GtM/4Piw/UoFq5xMdmibDyLiebJlut7esX/5RSzu4cBQTP5PDbxAi87SizMM5k5DvUy1tpcXI4e51LV7XUIeimAaSPMvYOr8KiCXUeBttkw0R7vIn6QLwRAi0vt9spjVgJTqnWJVb2yL/T1/ciYm5r+Yi6uog2K35pIuMiLAgMBAAECggEAAhClKfyEvBHUyBGndcdvkY87ciYiWDnTKgn5NBUqwImNs0peU0IzjhEh0pDN2SfNCelzzCriyoczYyYx4yYn0lDHgIpNvOue5G2iFP1muhEMvXssLyiFhJVBEvpj2HXvn50KTjDNwP3eJZS5QEAuqRPoB93esYzYSieNp7ds+XNUDxoSUXiBDjOyzC+mTafG54XPlFt93eNPyjYiHkfzyJWNfhwpW09t4aucjz2joVSag0L6pGvaGmF9brxB2IKR7KcP87gmhyXeHisqjRKFXBoFaXmsPKck2K8WEv2HnDjKqlictDjczAuXW9G923cm4uvD1UbxTsxZnfuvjUdIUQKBgQDQQi6rTD+sJz8Y/9udmO4dBYKcwQFqSHIoS475VCtM5rl7cSxJJS58Ww6RYogmuJJ8agTtz5UiS9irvajl6Fw887isQgc0GwASz2hxYYFgmy8aYftnYq+c2qrhgD1BBIBzcbMprkTSb74COdpojKkCeRANMZEAm1loj75zQeKhWwKBgQDErm7V+8JBjPvbIf3hloM6E2OqiPxWWvRVXXG6SO+vUyLPYpXpOQFP6xoi3C2okFr+R+dnQp8h+bywhilQzPS2k3k5AmzB2hNqskaFpZqmGBoG5H/zEvd/WJ6xFEL3D+Eco96OV76dBjSwzZqAZMnY6qJ6q1cU1MmAnIHKkytskQKBgE7CiMXNq1Le8NTyhkreuEaPe+rubyuTxGCK2sJeW5XUuBcAIQB0qFTtVuASxGzoZrXYno6Vb9AtoP6qVoLEUoXWomO7AOBqyadTeytN9dDkP3cZ0SszPjjy1ac8iW3aVv3R5TEBMBPpoJFU8c2STKSbxj9HHJB/L9wEaMFMDHp7AoGBAIUwzxQPyqwTalcqPMBw6esBSGQrIh7kt0O75RFO5SmothEU5QosNWxGfMuQqUbWgxhh3x35asRaV+J+6Cm0sh+V3OizcK0SHkYJ9mH5FLJX7gAu60rT1FEj1Ut7uiGPWlXHzyY723SAyFvW0EMUffBsbJ1/vJf5xX9X/TkO0sBRAoGAGozyN2+pCGfkYQeDKCLhpCAN2Zesn9TYYNbJg41nwjrjNzz9/LQvqY4lc+Bwy+J3ldg56JGMbJe9IXnWguvzJGAJBkB8Q00XaFDbDazDYUYDjZx5S4VsbKh8Z4CVnITi2aDNmZUU/Y+jA4S1UBod7OgOvsuCE07W6o3VwdI3TBE=';
   fingerprint varchar2(64) := 'eb:0b:84:b2:ef:0a:85:5e:b9:eb:c8:f7:4d:b1:af:71';
   days_back number := 3; -- number of days before today to get data
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
        comienzo := to_char(sysdate - days_back , 'YYYY') || '-' || to_char(sysdate - days_back , 'MM') || '-' || to_char(sysdate - days_back , 'DD') || 'T00:00:00.000Z';
        -- yesterday
        fin := to_char(sysdate - days_back + 1, 'YYYY') || '-' || to_char(sysdate - days_back + 1, 'MM') || '-' || to_char(sysdate - days_back + 1, 'DD') || 'T00:00:00.000Z';
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
    DBMS_SCHEDULER.DROP_JOB(JOB_NAME => 'ADMIN.OCICOSTS');
END;
/
-- create daily schedule
BEGIN
  DBMS_SCHEDULER.CREATE_JOB (
   job_name           =>  'ADMIN.OCICOSTS',
   job_type           =>  'STORED_PROCEDURE',
   job_action         =>  'ADMIN.OCI_CLOUD_COST.GETCOSTS',
   repeat_interval    =>  'FREQ=DAILY;INTERVAL=1',
   auto_drop          =>   FALSE,
   comments           =>  'my oci costs');
END;
/
-- enable checdule
BEGIN
    DBMS_SCHEDULER.ENABLE('OCICOSTS');
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
    JOB_NAME = 'OCICOSTS'
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
set serveroutput on
begin
     admin.oci_cloud_cost.getcosts;
end;
/
--query
select * from myocicosts where remarks is null order by starttime asc
/