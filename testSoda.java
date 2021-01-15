package javiermugueta.blog;

import java.util.UUID;
import java.sql.Connection;
import java.sql.DriverManager;
import oracle.soda.rdbms.OracleRDBMSClient;
import oracle.soda.OracleDatabase;
import oracle.soda.OracleCursor;
import oracle.soda.OracleCollection;
import oracle.soda.OracleDocument;
import oracle.soda.OracleException;
import java.util.Properties;
 
public class testSoda
{
  public static void main(String[] arg)
  {
      String url = "jdbc:oracle:thin:@dbpre_tp";
      Properties props = new Properties();
      props.setProperty("user", "invictus");
      props.setProperty("password", "whatIsay");
      Connection conn = null;
      try
      {
        conn = DriverManager.getConnection(url, props);
        OracleRDBMSClient cl = new OracleRDBMSClient();
        OracleDatabase db = cl.getDatabase(conn);
 
        // Configures the collection with client-assigned document keys
        //OracleDocument collMeta = cl.createMetadataBuilder().keyColumnAssignmentMethod("client").build();
        //OracleCollection col = db.admin().createCollection("mngtiq", collMeta);
        OracleCollection col = db.admin().createCollection("mngtq");
 
        // a new ticket document with fixed ticketId 
        OracleDocument doc = db.createDocumentFromString("{\"ticketId\" : \"" + "000001"  + "\", \"ref\" : \"0095454353\", \"color\" : \"r023\",  \"price\" : \"99.00\"}");
        col.insert(doc);

        // a bucnh of ticket documents with random ticketId 
        for (int i = 0; i < 1000; i++){
          String ticketId = UUID.randomUUID().toString();
          doc = db.createDocumentFromString("{\"ticketId\" : \"" + ticketId  + "\", \"ref\" : \"0095454353\", \"color\" : \"r023\",  \"price\" : \"99.00\"}");
          //OracleDocument doc = db.createDocumentFromString("123", "{ \"ref\" : \"0095454353\", \"color\" : \"r023\",  \"price\" : \"99.00\"}");
          col.insert(doc);
        }

        // Find all documents in the collection.
        OracleCursor c = null;
        try 
        {
          c = col.find().getCursor();
          OracleDocument resultDoc;
 
          while (c.hasNext())
          {
            resultDoc = c.next();
            System.out.println ("Key:         " + resultDoc.getKey());
            System.out.println ("Content:     " + resultDoc.getContentAsString());
            System.out.println ("Version:     " + resultDoc.getVersion());
            System.out.println ("Last modified: " + resultDoc.getLastModified());
            System.out.println ("Created on:    " + resultDoc.getCreatedOn());
            System.out.println ("Media:         " + resultDoc.getMediaType());
            System.out.println ("\n");
            break; // dont wanna lose my time waiting.. :-)
          }

          // search by json attribute
          OracleDocument filterSpec =db.createDocumentFromString("{ \"ticketId\" : \"000001\"}");
          c = col.find().filter(filterSpec).getCursor();
 
          while (c.hasNext()) {
              resultDoc = c.next();
              System.out.println ("Document key: " + resultDoc.getKey() + "\n" +
                        " document content: " + resultDoc.getContentAsString());
             break; // dont wanna lose my time waiting.. :-)
          }
 
        }
        finally
        {
          if (c != null) c.close();
        }
    }
    catch (OracleException e) { e.printStackTrace(); }
    catch (Exception e) { e.printStackTrace(); }
    finally 
    {
      try { if (conn != null)  conn.close(); }
      catch (Exception e) { }
    }
  }
}