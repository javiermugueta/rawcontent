package main
//
import (
	"context"
	"fmt"
	"io/ioutil"
	"strings"
	"log"
	"time"
	"github.com/oracle/oci-go-sdk/common"
	"github.com/oracle/oci-go-sdk/example/helpers"
	"github.com/oracle/oci-go-sdk/objectstorage"
)
/****************************************
main function
****************************************/
func main(){
	// wait 10 seconds
	time.Sleep( 10000000000 )
	// put here your camera snapshots
	procesa("/root/config/img/keleta.jpg", "k")
	procesa("/root/config/img/hall.jpg", "h")
	procesa("/root/config/img/placeta.jpg", "p")
}
/************************+******************
 helper function
 *******************************************/
func procesa( fichero string , i string) {
	//
	client, err := objectstorage.NewObjectStorageClientWithConfigurationProvider(common.DefaultConfigProvider())
	helpers.FatalIfError(err)
	//
	dt := time.Now()
	dir := fmt.Sprintf("%d/%d/%d/%d/", dt.Year(), dt.Month(), dt.Day(), dt.Hour())
	filename := fmt.Sprintf("%s%s-%s.jpeg", dir, i, dt.String())
	//
	content, err := ioutil.ReadFile(fichero)
	//
	L := int64(len(string(content)))
     if err != nil {
          log.Fatal(err)
     }
	 //
	req := objectstorage.PutObjectRequest{
		BucketName:              common.String("session_detail"),
		NamespaceName:           common.String("xplorawizink"),
		ObjectName:              common.String(filename),
		PutObjectBody:           ioutil.NopCloser(strings.NewReader(string(content))),
		// StorageTier:             objectstorage.PutObjectStorageTierStandard,
		ContentLength:		&L}
	// Send the request using the service client
	resp, err := client.PutObject(context.Background(), req)
	helpers.FatalIfError(err)
	// Retrieve value from the response
	fmt.Println(resp)
}

