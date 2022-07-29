using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Microsoft.Azure.WebJobs.Host;
using Azure.Messaging.EventGrid;
using Azure.Messaging.EventGrid.SystemEvents;
using Azure.Storage.Blobs;
using Microsoft.Azure.WebJobs.Extensions.EventGrid;
using System.IO;
using System;

namespace ScanUploadedBlobFunction
{
    public static class ScanUploadedBlob
    {
        
        [FunctionName("ScanUploadedBlob")]
        public static void Run([EventGridTrigger] EventGridEvent eventGridEvent, ILogger log)
        { 
            string eventSubject = eventGridEvent.Subject.ToString();
            log.LogInformation($"EventGridEvent received: {eventSubject}");

            //
            // For event subjects that come in the form: 
            // /blobServices/default/containers/cmp96/blobs/PXL_20220727_132342821.jpg
            // 
            // Annoying way to do this, but we have to handle variable container names and the don't come through the EventGridEvent as structured data
            //
            var blobName = eventSubject[(eventSubject.LastIndexOf('/') + 1)..];
            var containerEtcName = eventSubject[(eventSubject.IndexOf("containers/") + 11)..];
            var containerName = containerEtcName[..containerEtcName.IndexOf("/")];

            log.LogDebug(eventSubject);
            log.LogDebug($"containerEtc: {containerEtcName}");
            log.LogDebug($"container: {containerName}");
            log.LogDebug($"blob: {blobName}");
            log.LogDebug(eventGridEvent.Data.ToString());

            if (eventGridEvent.TryGetSystemEventData(out object eventData))
            {
                if (eventData is StorageBlobCreatedEventData blobCreatedEventData)
                {
                    // This only works for blobs that allow anonymous access
                    //BlobClient blobClient = new BlobClient(new Uri(blobCreatedEventData.Url));

                    var connectionString = Environment.GetEnvironmentVariable("windefenderstorage");
                    log.LogDebug($"connectionString: {connectionString}");

                    var blobClient = new BlobClient(connectionString, containerName, blobName);

                    Stream blobStream = blobClient.OpenRead();

                    log.LogInformation($"C# Blob trigger ScanUploadedBlob function Processed blob Name:{blobName} Size: {blobStream.Length} Bytes");

                    var scannerHost = Environment.GetEnvironmentVariable("windowsdefender_host");
                    var scannerPort = Environment.GetEnvironmentVariable("windowsdefender_port");

                    var scanner = new ScannerProxy(log, scannerHost);
                    var scanResults = scanner.Scan(blobStream, blobName);
                    if (scanResults == null)
                    {
                        return;
                    }
                    log.LogInformation($"Scan Results - {scanResults.ToString(", ")}");
                    log.LogInformation("Handalng Scan Results");
                    var action = new Remediation(scanResults, log, blobClient.BlobContainerName);
                    action.Start();
                    log.LogInformation($"ScanUploadedBlob function done Processing blob Name:{blobName} Size: {blobStream.Length} Bytes");
                }
                else
                {
                    log.LogError($"Event data was not for Storage Blob Created. Subject: {eventSubject}");
                }
            }
            else
            {
                log.LogError($"Could not get system event data.{eventSubject}");
            }
        }
    }
}
